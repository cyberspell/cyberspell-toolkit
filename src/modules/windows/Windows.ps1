# =====================================================================
#  Windows.ps1  --  Windows endpoint troubleshooting category tree
#  cyberspell // toolkit
#
#  Categories follow the "Windows Guide" structure:
#    Network & connectivity / System & performance / Disk & storage /
#    Windows Update / System repair / Hardware & drivers / Printers /
#    Accounts & access / Apps & Office / Quick launch
#
#  Each command node is a hashtable:
#    Label   - display name
#    Desc    - one-line description (dim)
#    Type    - 'action'
#    Admin   - $true if the task needs elevation
#    Confirm - $true to prompt before running (state-changing tasks)
#    Warning - text shown before the confirm prompt
#    Action  - scriptblock that does the work
#
#  Read-only diagnostics need no Confirm. Anything that changes state
#  gets Confirm + a Warning, and Admin where elevation is required.
# =====================================================================

# --- shared helper: pending-reboot detection -------------------------
function Test-PendingReboot {
    $reasons = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $reasons += 'Component-Based Servicing'
    }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $reasons += 'Windows Update'
    }
    $pfro = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
                -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
    if ($pfro) { $reasons += 'Pending file-rename operations' }
    return [PSCustomObject]@{ Pending = ($reasons.Count -gt 0); Reasons = $reasons }
}

# --- shared helper: pending-reboot action body -----------------------
function Show-PendingRebootReport {
    $r = Test-PendingReboot
    if ($r.Pending) {
        Write-Host (Paint "  YES - a reboot is pending." 'warn' -Bold)
        Write-Host ""
        foreach ($x in $r.Reasons) { Write-Host (Paint "    - $x" 'dim') }
    } else {
        Write-Host (Paint "  No pending reboot detected." 'ok' -Bold)
    }
}

# =====================================================================
#  1. NETWORK & CONNECTIVITY
# =====================================================================
function Get-WinNetworkMenu {
    @{
        Label = 'Network & connectivity'; Desc = 'triage, DNS, Wi-Fi, VPN/RDP checks'; Type = 'menu'
        Items = @(
            @{
                Label = 'Connectivity triage'; Desc = 'IP > gateway > internet > DNS, in order'; Type = 'action'
                Action = {
                    # -- 1/4: IPv4 address (APIPA = DHCP unreachable) ----------
                    Write-Host (Paint "  [1/4] IPv4 address" 'cyan' -Bold)
                    $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                        Where-Object { $_.IPAddress -ne '127.0.0.1' })
                    if ($ips.Count -eq 0) {
                        Write-Host (Paint "    no IPv4 address on any adapter" 'err' -Bold)
                    } else {
                        foreach ($ip in $ips) {
                            if ($ip.IPAddress -like '169.254.*') {
                                Write-Host (Paint "    $($ip.InterfaceAlias): $($ip.IPAddress)   <- APIPA: DHCP server not reachable" 'err' -Bold)
                            } else {
                                Write-Host (Paint "    $($ip.InterfaceAlias): $($ip.IPAddress)" 'ok')
                            }
                        }
                    }
                    # -- 2/4: default gateway ----------------------------------
                    Write-Host ""
                    Write-Host (Paint "  [2/4] Default gateway" 'cyan' -Bold)
                    $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                           Sort-Object RouteMetric | Select-Object -First 1).NextHop
                    if ($gw) {
                        if (Test-Connection -ComputerName $gw -Count 2 -Quiet -ErrorAction SilentlyContinue) {
                            Write-Host (Paint "    $gw  reachable" 'ok')
                        } else {
                            Write-Host (Paint "    $gw  not answering ping (may just block ICMP)" 'warn')
                        }
                    } else {
                        Write-Host (Paint "    no default gateway configured" 'err' -Bold)
                    }
                    # -- 3/4: internet by raw IP -------------------------------
                    Write-Host ""
                    Write-Host (Paint "  [3/4] Internet (by IP, bypasses DNS)" 'cyan' -Bold)
                    if (Test-Connection -ComputerName '8.8.8.8' -Count 2 -Quiet -ErrorAction SilentlyContinue) {
                        Write-Host (Paint "    8.8.8.8  reachable" 'ok')
                    } else {
                        Write-Host (Paint "    8.8.8.8  unreachable - no internet path" 'err' -Bold)
                    }
                    # -- 4/4: DNS resolution -----------------------------------
                    Write-Host ""
                    Write-Host (Paint "  [4/4] DNS resolution" 'cyan' -Bold)
                    try {
                        $a = [System.Net.Dns]::GetHostAddresses('google.com') | Select-Object -First 1
                        Write-Host (Paint "    google.com -> $($a.IPAddressToString)" 'ok')
                    } catch {
                        Write-Host (Paint "    cannot resolve google.com - DNS problem (try: DNS servers / flush cache)" 'err' -Bold)
                    }
                }
            },
            @{
                Label = 'IP configuration'; Desc = 'full ipconfig /all'; Type = 'action'
                Action = { ipconfig /all }
            },
            @{
                Label = 'Active adapters'; Desc = 'NICs that are up'; Type = 'action'
                Action = {
                    Get-NetAdapter -ErrorAction SilentlyContinue |
                        Where-Object Status -eq 'Up' |
                        Format-Table Name, InterfaceDescription, LinkSpeed, MacAddress -AutoSize
                }
            },
            @{
                Label = 'Ping test'; Desc = 'reachability + latency'; Type = 'action'; Interactive = $true
                Action = {
                    $target = (Read-Host "  Host or IP to ping (default 8.8.8.8)").Trim()
                    if ([string]::IsNullOrEmpty($target)) { $target = '8.8.8.8' }
                    Write-Host ""
                    Write-Host (Paint "  pinging $target ..." 'dim')
                    Write-Host ""
                    Test-Connection -ComputerName $target -Count 4 -ErrorAction SilentlyContinue |
                        Format-Table -AutoSize | Out-Host
                }
            },
            @{
                Label = 'Traceroute'; Desc = 'path to a host (tracert -d)'; Type = 'action'; Interactive = $true
                Action = {
                    $target = (Read-Host "  Host or IP to trace (default 8.8.8.8)").Trim()
                    if ([string]::IsNullOrEmpty($target)) { $target = '8.8.8.8' }
                    Write-Host ""
                    tracert -d $target
                }
            },
            @{
                Label = 'DNS servers'; Desc = 'configured resolvers per NIC'; Type = 'action'
                Action = {
                    Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                        Where-Object { $_.ServerAddresses } |
                        Format-Table InterfaceAlias, @{n='DNS Servers';e={$_.ServerAddresses -join ', '}} -AutoSize
                }
            },
            @{
                Label = 'DNS lookup test'; Desc = 'resolve via local DNS vs 8.8.8.8'; Type = 'action'; Interactive = $true
                Action = {
                    $h = (Read-Host "  Name to resolve (default google.com)").Trim()
                    if ([string]::IsNullOrEmpty($h)) { $h = 'google.com' }
                    Write-Host ""
                    if (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue) {
                        Write-Host (Paint "  via local resolver:" 'cyan' -Bold)
                        Resolve-DnsName $h -Type A -ErrorAction SilentlyContinue |
                            Format-Table Name, Type, IPAddress -AutoSize | Out-Host
                        Write-Host (Paint "  via 8.8.8.8 (bypasses local DNS):" 'cyan' -Bold)
                        Resolve-DnsName $h -Type A -Server 8.8.8.8 -ErrorAction SilentlyContinue |
                            Format-Table Name, Type, IPAddress -AutoSize | Out-Host
                    } else {
                        nslookup $h
                        Write-Host ""
                        nslookup $h 8.8.8.8
                    }
                    Write-Host (Paint "  If local fails but 8.8.8.8 works, the configured DNS server is the problem." 'dim')
                }
            },
            @{
                Label = 'Wi-Fi status'; Desc = 'signal, channel, speed (netsh wlan)'; Type = 'action'
                Action = { netsh wlan show interfaces }
            },
            @{
                Label = 'Wi-Fi profiles'; Desc = 'saved wireless networks'; Type = 'action'
                Action = { netsh wlan show profiles }
            },
            @{
                Label = 'Established connections'; Desc = 'active TCP + owning process'; Type = 'action'
                Action = {
                    Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
                        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort,
                            @{n='Process';e={ (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName }} |
                        Sort-Object RemoteAddress |
                        Format-Table -AutoSize
                }
            },
            @{
                Label = 'Mapped network drives'; Desc = 'net use - drive letters to shares'; Type = 'action'
                Action = { net use }
            },
            @{
                Label = 'Port test'; Desc = 'is a TCP port open? (RDP=3389, SMB=445)'; Type = 'action'; Interactive = $true
                Action = {
                    $h = (Read-Host "  Host or IP").Trim()
                    if ([string]::IsNullOrEmpty($h)) { Write-Host (Paint "  cancelled - no host given." 'dim'); return }
                    $p = (Read-Host "  Port (default 3389)").Trim()
                    if ([string]::IsNullOrEmpty($p)) { $p = '3389' }
                    Write-Host ""
                    Write-Host (Paint "  testing $h : $p ..." 'dim')
                    Test-NetConnection -ComputerName $h -Port ([int]$p) -WarningAction SilentlyContinue |
                        Format-List ComputerName, RemoteAddress, RemotePort, PingSucceeded, TcpTestSucceeded | Out-Host
                }
            },
            @{
                Label = 'Firewall status'; Desc = 'state of all firewall profiles'; Type = 'action'
                Action = { netsh advfirewall show allprofiles state }
            },
            (Get-WinNetworkRepairMenu)
        )
    }
}

# --- Network: resets & repairs (state-changing) ----------------------
function Get-WinNetworkRepairMenu {
    @{
        Label = 'Resets & repairs'; Desc = 'DNS flush, DHCP renew, stack resets'; Type = 'menu'
        Items = @(
            @{
                Label = 'Flush DNS cache'; Desc = 'clear resolver cache (safe)'; Type = 'action'
                Action = { ipconfig /flushdns }
            },
            @{
                Label = 'Release & renew DHCP'; Desc = 'get a fresh IP lease'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Drops the current IP for a moment. If you are on this machine via RDP or a remote tool, you WILL likely be disconnected.'
                Action = {
                    ipconfig /release
                    Write-Host ""
                    ipconfig /renew
                }
            },
            @{
                Label = 'Disable firewall (all profiles)'; Desc = 'TEMPORARY test only'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Turns Windows Firewall OFF on all profiles. For quick isolation tests ONLY - re-enable it immediately after (next item).'
                Action = {
                    netsh advfirewall set allprofiles state off
                    Write-Host ""
                    Write-Host (Paint "  Firewall is OFF. Re-enable it as soon as the test is done." 'err' -Bold)
                }
            },
            @{
                Label = 'Enable firewall (all profiles)'; Desc = 'turn protection back on'; Type = 'action'
                Admin = $true; Confirm = $true
                Action = {
                    netsh advfirewall set allprofiles state on
                    Write-Host ""
                    Write-Host (Paint "  Firewall re-enabled on all profiles." 'ok' -Bold)
                }
            },
            @{
                Label = 'TCP/IP stack reset'; Desc = 'netsh int ip reset'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Resets the TCP/IP stack to defaults (removes static IP settings). A RESTART is required afterward.'
                Action = {
                    netsh int ip reset
                    Write-Host ""
                    Write-Host (Paint "  TCP/IP reset. Restart the machine to complete." 'warn')
                }
            },
            @{
                Label = 'Winsock reset'; Desc = 'reset network stack'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Resets the Winsock catalog. A RESTART is required afterward.'
                Action = {
                    netsh winsock reset
                    Write-Host ""
                    Write-Host (Paint "  Winsock reset. Restart the machine to complete." 'warn')
                }
            }
        )
    }
}

# =====================================================================
#  2. SYSTEM & PERFORMANCE
# =====================================================================
function Get-WinSystemMenu {
    @{
        Label = 'System & performance'; Desc = 'summary, processes, startup, crashes'; Type = 'menu'
        Items = @(
            @{
                Label = 'System summary'; Desc = 'OS, model, RAM, uptime'; Type = 'action'
                Action = {
                    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
                    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
                    $up = $null
                    if ($os) { $up = (Get-Date) - $os.LastBootUpTime }
                    Write-Kv 'Computer'    $env:COMPUTERNAME
                    Write-Kv 'User'        "$env:USERDOMAIN\$env:USERNAME"
                    if ($os) {
                        Write-Kv 'OS'          ($os.Caption -replace 'Microsoft ', '')
                        Write-Kv 'Version'     "$($os.Version)  (build $($os.BuildNumber))"
                        Write-Kv 'Installed'   $os.InstallDate
                        Write-Kv 'Last boot'   $os.LastBootUpTime
                    }
                    if ($up) { Write-Kv 'Uptime' ("{0}d {1}h {2}m" -f $up.Days, $up.Hours, $up.Minutes) }
                    if ($cs) {
                        Write-Kv 'Manufacturer' $cs.Manufacturer
                        Write-Kv 'Model'        $cs.Model
                        Write-Kv 'RAM'          ("{0} GB" -f [math]::Round($cs.TotalPhysicalMemory / 1GB, 1))
                        Write-Kv 'CPU cores'    "$($cs.NumberOfLogicalProcessors) logical"
                    }
                    if ($bios) { Write-Kv 'Serial' $bios.SerialNumber }
                }
            },
            @{
                Label = 'Top CPU processes'; Desc = 'busiest 15 by CPU time'; Type = 'action'
                Action = {
                    Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 `
                        Name, Id,
                        @{n='CPU(s)';e={ [math]::Round($_.CPU, 1) }},
                        @{n='WS(MB)';e={ [math]::Round($_.WorkingSet64 / 1MB, 1) }} |
                        Format-Table -AutoSize
                }
            },
            @{
                Label = 'Top memory processes'; Desc = 'biggest 15 by working set'; Type = 'action'
                Action = {
                    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 `
                        Name, Id,
                        @{n='WS(MB)';e={ [math]::Round($_.WorkingSet64 / 1MB, 1) }},
                        @{n='CPU(s)';e={ [math]::Round($_.CPU, 1) }} |
                        Format-Table -AutoSize
                }
            },
            @{
                Label = 'Memory usage'; Desc = 'physical RAM in use'; Type = 'action'
                Action = {
                    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                    if ($os) {
                        $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1KB)
                        $freeMB  = [math]::Round($os.FreePhysicalMemory / 1KB)
                        $usedMB  = $totalMB - $freeMB
                        $pct     = 0
                        if ($totalMB) { $pct = [math]::Round(($usedMB / $totalMB) * 100) }
                        $col = 'ok'
                        if ($pct -ge 90) { $col = 'err' } elseif ($pct -ge 75) { $col = 'warn' }
                        Write-Kv 'Total'  "$totalMB MB"
                        Write-Kv 'Used'   "$usedMB MB  ($pct%)" $col
                        Write-Kv 'Free'   "$freeMB MB"
                    }
                }
            },
            @{
                Label = 'Startup programs'; Desc = 'what launches at logon'; Type = 'action'
                Action = {
                    Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
                        Select-Object Name, User, Location, Command |
                        Format-Table -AutoSize -Wrap
                }
            },
            @{
                Label = 'Uptime / last boot'; Desc = 'how long since restart'; Type = 'action'
                Action = {
                    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                    if ($os) {
                        $up = (Get-Date) - $os.LastBootUpTime
                        Write-Kv 'Last boot' $os.LastBootUpTime
                        Write-Kv 'Uptime'    ("{0}d {1}h {2}m {3}s" -f $up.Days, $up.Hours, $up.Minutes, $up.Seconds)
                    }
                }
            },
            @{
                Label = 'Pending reboot?'; Desc = 'check reboot-required flags'; Type = 'action'
                Action = { Show-PendingRebootReport }
            },
            @{
                Label = 'Recent system errors'; Desc = 'last 20 critical/error events'; Type = 'action'
                Action = {
                    try {
                        Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2 } -MaxEvents 20 -ErrorAction Stop |
                            Select-Object TimeCreated, Id, ProviderName,
                                @{n='Message';e={ ($_.Message -split "`n")[0] }} |
                            Format-Table -AutoSize -Wrap
                    } catch {
                        Write-Host (Paint "  Could not read System log: $($_.Exception.Message)" 'warn')
                    }
                }
            },
            @{
                Label = 'Crash / BSOD history'; Desc = 'bugchecks, dirty shutdowns, minidumps'; Type = 'action'
                Action = {
                    Write-Host (Paint "  Crash-related events (Kernel-Power 41, BugCheck 1001, unexpected shutdown 6008):" 'cyan' -Bold)
                    try {
                        Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41, 1001, 6008 } -MaxEvents 15 -ErrorAction Stop |
                            Select-Object TimeCreated, Id, ProviderName,
                                @{n='Summary';e={ ($_.Message -split "`n")[0] }} |
                            Format-Table -AutoSize -Wrap | Out-Host
                    } catch {
                        Write-Host (Paint "    none found - no recorded crashes. good sign." 'ok')
                    }
                    Write-Host ""
                    Write-Host (Paint "  Minidump files ($env:SystemRoot\Minidump):" 'cyan' -Bold)
                    $md = @(Get-ChildItem "$env:SystemRoot\Minidump" -Filter *.dmp -ErrorAction SilentlyContinue |
                            Sort-Object LastWriteTime -Descending)
                    if ($md.Count -gt 0) {
                        $md | Select-Object Name, LastWriteTime,
                            @{n='Size(KB)';e={ [math]::Round($_.Length / 1KB) }} |
                            Format-Table -AutoSize | Out-Host
                    } else {
                        Write-Host (Paint "    no minidump files present." 'ok')
                    }
                }
            },
            @{
                Label = 'Kill a process'; Desc = 'end a hung program by name or PID'; Type = 'action'; Interactive = $true
                Action = {
                    $q = (Read-Host "  Process name or PID (blank = cancel)").Trim()
                    if ([string]::IsNullOrEmpty($q)) { Write-Host (Paint "  cancelled." 'dim'); return }
                    $procs = @()
                    if ($q -match '^\d+$') {
                        $procs = @(Get-Process -Id ([int]$q) -ErrorAction SilentlyContinue)
                    } else {
                        $procs = @(Get-Process -Name $q -ErrorAction SilentlyContinue)
                    }
                    if ($procs.Count -eq 0) { Write-Host (Paint "  no matching process found." 'warn'); return }
                    Write-Host ""
                    $procs | Select-Object Id, Name, @{n='WS(MB)';e={ [math]::Round($_.WorkingSet64 / 1MB, 1) }} |
                        Format-Table -AutoSize | Out-Host
                    if (Confirm-Action "Force-kill $($procs.Count) process(es) above?") {
                        $procs | Stop-Process -Force -ErrorAction Continue
                        Write-Host (Paint "  kill signal sent." 'ok')
                    } else {
                        Write-Host (Paint "  cancelled." 'dim')
                    }
                }
            },
            @{
                Label = 'Restart Windows Explorer'; Desc = 'fix frozen taskbar / desktop'; Type = 'action'
                Confirm = $true
                Warning = 'Explorer windows will close and the desktop will briefly disappear, then reload.'
                Action = {
                    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
                        Start-Process explorer.exe
                    }
                    Write-Host (Paint "  Explorer restarted." 'ok')
                }
            }
        )
    }
}

# =====================================================================
#  3. DISK & STORAGE
# =====================================================================
function Get-WinDiskMenu {
    @{
        Label = 'Disk & storage'; Desc = 'space, health, cleanup, chkdsk'; Type = 'menu'
        Items = @(
            @{
                Label = 'Drive space'; Desc = 'free space per volume'; Type = 'action'
                Action = {
                    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue |
                        Select-Object DeviceID,
                            @{n='Size(GB)';e={ [math]::Round($_.Size / 1GB, 1) }},
                            @{n='Free(GB)';e={ [math]::Round($_.FreeSpace / 1GB, 1) }},
                            @{n='Free%';e={ if ($_.Size) { [math]::Round(($_.FreeSpace / $_.Size) * 100) } else { 0 } }} |
                        Format-Table -AutoSize
                }
            },
            @{
                Label = 'Disk health'; Desc = 'physical disk SMART status'; Type = 'action'
                Action = {
                    Get-PhysicalDisk -ErrorAction SilentlyContinue |
                        Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus,
                            @{n='Size(GB)';e={ [math]::Round($_.Size / 1GB) }} |
                        Format-Table -AutoSize
                }
            },
            @{
                Label = 'SSD TRIM status'; Desc = 'fsutil DisableDeleteNotify'; Type = 'action'
                Admin = $true
                Action = {
                    fsutil behavior query DisableDeleteNotify
                    Write-Host ""
                    Write-Host (Paint "  DisableDeleteNotify = 0 means TRIM is ENABLED (good for SSDs)." 'dim')
                }
            },
            @{
                Label = 'Largest folders on C:'; Desc = 'top-level usage (can take a while)'; Type = 'action'
                Action = {
                    Write-Host (Paint "  scanning C:\ top-level folders ..." 'dim')
                    Write-Host ""
                    Get-ChildItem -LiteralPath 'C:\' -Directory -Force -ErrorAction SilentlyContinue |
                        ForEach-Object {
                            $sum = (Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                                    Measure-Object -Property Length -Sum).Sum
                            [PSCustomObject]@{ Folder = $_.FullName; 'Size(GB)' = [math]::Round(($sum / 1GB), 2) }
                        } | Sort-Object 'Size(GB)' -Descending | Select-Object -First 12 |
                        Format-Table -AutoSize | Out-Host
                }
            },
            @{
                Label = 'CHKDSK scan (read-only)'; Desc = 'inspect C: without repairing'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Read-only scan of C:. Makes NO changes but can take several minutes.'
                Action = { chkdsk C: }
            },
            @{
                Label = 'Disk Cleanup (launch)'; Desc = 'open the cleanmgr utility'; Type = 'action'
                Action = {
                    Start-Process cleanmgr.exe
                    Write-Host (Paint "  Disk Cleanup launched in a separate window." 'ok')
                }
            }
        )
    }
}

# =====================================================================
#  4. WINDOWS UPDATE
# =====================================================================
function Get-WinUpdateMenu {
    @{
        Label = 'Windows Update'; Desc = 'services, history, component reset'; Type = 'menu'
        Items = @(
            @{
                Label = 'Update service status'; Desc = 'wuauserv, BITS, etc.'; Type = 'action'
                Action = {
                    Get-Service wuauserv, bits, cryptsvc, msiserver -ErrorAction SilentlyContinue |
                        Format-Table Name, DisplayName, Status, StartType -AutoSize
                }
            },
            @{
                Label = 'Recently installed updates'; Desc = 'last 15 hotfixes'; Type = 'action'
                Action = {
                    Get-HotFix -ErrorAction SilentlyContinue |
                        Sort-Object InstalledOn -Descending | Select-Object -First 15 `
                            HotFixID, Description, InstalledOn |
                        Format-Table -AutoSize
                }
            },
            @{
                Label = 'Pending reboot?'; Desc = 'reboot required by updates'; Type = 'action'
                Action = { Show-PendingRebootReport }
            },
            @{
                Label = 'Reset Windows Update components'; Desc = 'the classic fix for stuck updates'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Stops update services and renames SoftwareDistribution + catroot2. Update history display will reset and the next check for updates will take longer while caches rebuild.'
                Action = {
                    $svcs = @('wuauserv', 'bits', 'cryptsvc', 'msiserver')
                    Write-Host (Paint "  stopping update services ..." 'dim')
                    foreach ($s in $svcs) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }

                    $stamp = Get-Date -Format 'yyyyMMddHHmmss'
                    $sd = Join-Path $env:SystemRoot 'SoftwareDistribution'
                    $cr = Join-Path $env:SystemRoot 'System32\catroot2'
                    if (Test-Path $sd) {
                        Rename-Item -Path $sd -NewName "SoftwareDistribution.$stamp.old" -ErrorAction Continue
                        Write-Host (Paint "  renamed SoftwareDistribution -> SoftwareDistribution.$stamp.old" 'ok')
                    }
                    if (Test-Path $cr) {
                        Rename-Item -Path $cr -NewName "catroot2.$stamp.old" -ErrorAction Continue
                        Write-Host (Paint "  renamed catroot2 -> catroot2.$stamp.old" 'ok')
                    }

                    Write-Host (Paint "  starting update services ..." 'dim')
                    foreach ($s in $svcs) { Start-Service -Name $s -ErrorAction SilentlyContinue }
                    Write-Host ""
                    Get-Service wuauserv, bits, cryptsvc, msiserver -ErrorAction SilentlyContinue |
                        Format-Table Name, Status -AutoSize | Out-Host
                    Write-Host (Paint "  Done. Run Windows Update again; the renamed .old folders can be deleted later to reclaim space." 'dim')
                }
            }
        )
    }
}

# =====================================================================
#  5. SYSTEM REPAIR  (SFC / DISM / restore)
# =====================================================================
function Get-WinRepairMenu {
    @{
        Label = 'System repair'; Desc = 'SFC, DISM, restore points'; Type = 'menu'
        Items = @(
            @{
                Label = 'SFC verify (no repair)'; Desc = 'check system files, change nothing'; Type = 'action'
                Admin = $true
                Action = { sfc /verifyonly }
            },
            @{
                Label = 'SFC scan & repair'; Desc = 'sfc /scannow'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Scans and repairs protected system files. Can take 10-30 minutes - do not close the window.'
                Action = { sfc /scannow }
            },
            @{
                Label = 'DISM check health'; Desc = 'quick component-store flag check'; Type = 'action'
                Admin = $true
                Action = { dism /online /cleanup-image /checkhealth }
            },
            @{
                Label = 'DISM scan health'; Desc = 'deeper scan (read-only, slower)'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Read-only but can take 10-20 minutes.'
                Action = { dism /online /cleanup-image /scanhealth }
            },
            @{
                Label = 'DISM restore health'; Desc = 'repair the component store'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Repairs the Windows image, downloading files from Windows Update if needed. Can take a LONG time. Typical order: run this, then SFC /scannow.'
                Action = { dism /online /cleanup-image /restorehealth }
            },
            @{
                Label = 'Component store cleanup'; Desc = 'reclaim WinSxS space'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Cleans up superseded components. Safe, but can take a while and older updates can no longer be uninstalled.'
                Action = { dism /online /cleanup-image /startcomponentcleanup }
            },
            @{
                Label = 'List restore points'; Desc = 'available System Restore snapshots'; Type = 'action'
                Admin = $true
                Action = {
                    try {
                        $rp = @(Get-CimInstance -Namespace 'root\default' -ClassName SystemRestore -ErrorAction Stop)
                        if ($rp.Count -eq 0) {
                            Write-Host (Paint "  No restore points found (System Restore may be disabled)." 'warn')
                        } else {
                            $rp | ForEach-Object {
                                $when = $_.CreationTime
                                try { $when = [Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) } catch { }
                                [PSCustomObject]@{ Created = $when; Sequence = $_.SequenceNumber; Description = $_.Description }
                            } | Sort-Object Sequence -Descending | Format-Table -AutoSize | Out-Host
                        }
                    } catch {
                        Write-Host (Paint "  Could not query restore points: $($_.Exception.Message)" 'warn')
                    }
                }
            },
            @{
                Label = 'Open System Restore'; Desc = 'launch rstrui to roll back'; Type = 'action'
                Action = {
                    Start-Process rstrui.exe
                    Write-Host (Paint "  System Restore launched in a separate window." 'ok')
                }
            }
        )
    }
}

# =====================================================================
#  6. HARDWARE & DRIVERS  (display, docking, devices)
# =====================================================================
function Get-WinHardwareMenu {
    @{
        Label = 'Hardware & drivers'; Desc = 'problem devices, display, driver ages'; Type = 'menu'
        Items = @(
            @{
                Label = 'Problem devices'; Desc = 'devices with driver/config errors'; Type = 'action'
                Action = {
                    $codeMap = @{
                        1  = 'not configured';        3  = 'driver corrupt / low resources'
                        10 = 'device cannot start';   12 = 'resource conflict'
                        14 = 'restart required';      18 = 'reinstall drivers'
                        22 = 'device is disabled';    24 = 'not present / hardware moved'
                        28 = 'no driver installed';   31 = 'driver load failed'
                        37 = 'driver init failed';    39 = 'driver missing or corrupt'
                        43 = 'stopped (reported a problem)'; 45 = 'not currently connected'
                    }
                    $bad = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
                             Where-Object { $_.ConfigManagerErrorCode -ne 0 })
                    if ($bad.Count -eq 0) {
                        Write-Host (Paint "  All present devices report healthy. (Docking/display issues may still be cable or firmware.)" 'ok' -Bold)
                    } else {
                        $bad | ForEach-Object {
                            $c = [int]$_.ConfigManagerErrorCode
                            $meaning = $codeMap[$c]
                            if (-not $meaning) { $meaning = "error code $c" }
                            [PSCustomObject]@{ Device = $_.Name; Code = $c; Meaning = $meaning }
                        } | Sort-Object Code | Format-Table -AutoSize -Wrap | Out-Host
                        Write-Host (Paint "  Tip: for code 28/39, reinstall the driver from Device Manager or vendor tools." 'dim')
                    }
                }
            },
            @{
                Label = 'Display adapters & monitors'; Desc = 'GPUs, drivers, attached screens'; Type = 'action'
                Action = {
                    Write-Host (Paint "  Video adapters:" 'cyan' -Bold)
                    Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                        Select-Object Name, DriverVersion,
                            @{n='DriverDate';e={ '{0:yyyy-MM-dd}' -f $_.DriverDate }},
                            @{n='Resolution';e={ "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)" }},
                            Status |
                        Format-Table -AutoSize | Out-Host
                    Write-Host (Paint "  Monitors detected:" 'cyan' -Bold)
                    $mons = @(Get-CimInstance -Namespace 'root\wmi' -ClassName WmiMonitorID -ErrorAction SilentlyContinue)
                    if ($mons.Count -gt 0) {
                        $mons | ForEach-Object {
                            $name = ''
                            if ($_.UserFriendlyName) {
                                $name = -join ($_.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
                            }
                            $serial = ''
                            if ($_.SerialNumberID) {
                                $serial = -join ($_.SerialNumberID | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
                            }
                            [PSCustomObject]@{ Monitor = $name; Serial = $serial }
                        } | Format-Table -AutoSize | Out-Host
                    } else {
                        Write-Host (Paint "    could not enumerate monitors (some adapters do not expose EDID)." 'dim')
                    }
                    Write-Host (Paint "  Tip: Win+Ctrl+Shift+B restarts the graphics driver without a reboot." 'dim')
                }
            },
            @{
                Label = 'Recently updated drivers'; Desc = 'newest 25 by date (slow)'; Type = 'action'
                Action = {
                    Write-Host (Paint "  querying signed drivers - this one is slow ..." 'dim')
                    Write-Host ""
                    Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
                        Where-Object { $_.DriverDate } |
                        Sort-Object DriverDate -Descending | Select-Object -First 25 `
                            DeviceName, DriverVersion,
                            @{n='DriverDate';e={ '{0:yyyy-MM-dd}' -f $_.DriverDate }},
                            Manufacturer |
                        Format-Table -AutoSize
                }
            }
        )
    }
}

# =====================================================================
#  7. PRINTERS
# =====================================================================
function Get-WinPrinterMenu {
    @{
        Label = 'Printers'; Desc = 'status, queues, spooler fixes'; Type = 'menu'
        Items = @(
            @{
                Label = 'Printers & status'; Desc = 'installed printers + default'; Type = 'action'
                Action = {
                    Get-Printer -ErrorAction SilentlyContinue |
                        Sort-Object Name |
                        Format-Table Name, DriverName, PortName, PrinterStatus, Shared -AutoSize | Out-Host
                    $def = Get-CimInstance Win32_Printer -Filter 'Default=TRUE' -ErrorAction SilentlyContinue
                    if ($def) { Write-Host (Paint "  Default printer: $($def.Name)" 'cyan' -Bold) }
                }
            },
            @{
                Label = 'Print queue jobs'; Desc = 'stuck or pending jobs, all printers'; Type = 'action'
                Action = {
                    $jobs = @()
                    $printers = @(Get-Printer -ErrorAction SilentlyContinue)
                    foreach ($p in $printers) {
                        $jobs += @(Get-PrintJob -PrinterName $p.Name -ErrorAction SilentlyContinue)
                    }
                    if ($jobs.Count -eq 0) {
                        Write-Host (Paint "  No jobs queued on any printer." 'ok' -Bold)
                    } else {
                        $jobs | Select-Object PrinterName, Id, DocumentName, JobStatus, SubmittedTime |
                            Format-Table -AutoSize -Wrap | Out-Host
                    }
                }
            },
            @{
                Label = 'Restart Print Spooler'; Desc = 'first fix for most printer issues'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Restarts the Spooler service. Jobs currently printing may be interrupted.'
                Action = {
                    Restart-Service -Name Spooler -Force -ErrorAction Stop
                    Start-Sleep -Seconds 1
                    Get-Service -Name Spooler | Format-Table Name, Status, StartType -AutoSize | Out-Host
                    Write-Host (Paint "  Spooler restarted." 'ok')
                }
            },
            @{
                Label = 'Clear stuck print queue'; Desc = 'purge ALL spooled jobs'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Stops the Spooler and DELETES every queued print job on this machine, then restarts the Spooler.'
                Action = {
                    Stop-Service -Name Spooler -Force -ErrorAction Stop
                    $spool = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
                    $files = @(Get-ChildItem -Path $spool -File -ErrorAction SilentlyContinue)
                    if ($files.Count -gt 0) {
                        $files | Remove-Item -Force -ErrorAction SilentlyContinue
                    }
                    Start-Service -Name Spooler
                    Write-Host (Paint "  removed $($files.Count) spooled file(s); Spooler is back up." 'ok')
                }
            },
            @{
                Label = 'Remove a printer'; Desc = 'delete a printer by name'; Type = 'action'; Interactive = $true
                Admin = $true
                Action = {
                    Write-Host (Paint "  Installed printers:" 'cyan' -Bold)
                    Get-Printer -ErrorAction SilentlyContinue | Sort-Object Name |
                        Format-Table Name, DriverName, PortName -AutoSize | Out-Host
                    $n = (Read-Host "  Exact printer name to remove (blank = cancel)").Trim()
                    if ([string]::IsNullOrEmpty($n)) { Write-Host (Paint "  cancelled." 'dim'); return }
                    if (Confirm-Action "Remove printer '$n'?") {
                        Remove-Printer -Name $n -ErrorAction Stop
                        Write-Host (Paint "  printer '$n' removed." 'ok')
                    } else {
                        Write-Host (Paint "  cancelled." 'dim')
                    }
                }
            }
        )
    }
}

# =====================================================================
#  8. ACCOUNTS & ACCESS
# =====================================================================
function Get-WinAccountsMenu {
    @{
        Label = 'Accounts & access'; Desc = 'sessions, local users, lockouts'; Type = 'menu'
        Items = @(
            @{
                Label = 'Current session'; Desc = 'whoami /all - identity, groups, privs'; Type = 'action'
                Action = { whoami /all }
            },
            @{
                Label = 'Local users'; Desc = 'accounts on this machine'; Type = 'action'
                Action = { net user }
            },
            @{
                Label = 'Local Administrators group'; Desc = 'who has admin on this box'; Type = 'action'
                Action = { net localgroup Administrators }
            },
            @{
                Label = 'Account details'; Desc = 'net user <name> - status, expiry, logon'; Type = 'action'; Interactive = $true
                Action = {
                    $n = (Read-Host "  Username (blank = current user)").Trim()
                    if ([string]::IsNullOrEmpty($n)) { $n = $env:USERNAME }
                    Write-Host ""
                    net user $n
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host ""
                        Write-Host (Paint "  Not found locally. For a DOMAIN account, check on the DC or run: net user $n /domain" 'dim')
                    }
                }
            },
            @{
                Label = 'Recent failed logons'; Desc = 'Security log 4625 events'; Type = 'action'
                Admin = $true
                Action = {
                    try {
                        $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625 } -MaxEvents 15 -ErrorAction Stop)
                        $ev | ForEach-Object {
                            $u = ''; $ip = ''
                            try {
                                $u  = $_.Properties[5].Value
                                $ip = $_.Properties[19].Value
                            } catch { }
                            [PSCustomObject]@{ Time = $_.TimeCreated; User = $u; SourceIP = $ip }
                        } | Format-Table -AutoSize | Out-Host
                        Write-Host (Paint "  Repeated failures from one source can explain account lockouts." 'dim')
                    } catch {
                        Write-Host (Paint "  No failed-logon events found in the Security log." 'ok')
                    }
                }
            }
        )
    }
}

# =====================================================================
#  9. APPS & OFFICE
# =====================================================================
function Get-WinAppsMenu {
    @{
        Label = 'Apps & Office'; Desc = 'installed apps, Outlook data files'; Type = 'menu'
        Items = @(
            @{
                Label = 'Installed applications'; Desc = 'from registry (fast + accurate)'; Type = 'action'
                Action = {
                    $paths = @(
                        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
                    )
                    $apps = Get-ItemProperty $paths -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName } |
                        Sort-Object DisplayName -Unique |
                        Select-Object DisplayName, DisplayVersion, Publisher
                    $apps | Format-Table -AutoSize -Wrap | Out-Host
                    Write-Host (Paint "  $(@($apps).Count) applications found." 'cyan' -Bold)
                }
            },
            @{
                Label = 'Outlook data file sizes'; Desc = 'OST/PST sizes vs the 50 GB limit'; Type = 'action'
                Action = {
                    $dirs = @(
                        (Join-Path $env:LOCALAPPDATA 'Microsoft\Outlook'),
                        (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Outlook Files')
                    )
                    $found = 0
                    foreach ($d in $dirs) {
                        if (-not (Test-Path $d)) { continue }
                        $files = @(Get-ChildItem -Path $d -Include *.ost, *.pst -Recurse -File -ErrorAction SilentlyContinue)
                        foreach ($f in $files) {
                            $found++
                            $gb = [math]::Round($f.Length / 1GB, 2)
                            $col = 'ok'
                            if ($gb -ge 45) { $col = 'err' } elseif ($gb -ge 25) { $col = 'warn' }
                            Write-Kv $f.Name "$gb GB  ($($f.DirectoryName))" $col
                        }
                    }
                    if ($found -eq 0) {
                        Write-Host (Paint "  No OST/PST files found in the default locations." 'dim')
                    } else {
                        Write-Host ""
                        Write-Host (Paint "  Default OST limit is 50 GB - files near it cause sync issues and hangs." 'dim')
                    }
                }
            },
            @{
                Label = 'Start Outlook in safe mode'; Desc = 'outlook /safe - bypass add-ins'; Type = 'action'
                Action = {
                    Start-Process outlook.exe -ArgumentList '/safe'
                    Write-Host (Paint "  Outlook starting in safe mode. If the problem is gone, a COM add-in is the suspect (File > Options > Add-Ins)." 'ok')
                }
            },
            @{
                Label = 'Outlook: reset navigation pane'; Desc = 'outlook /resetnavpane - fixes startup crashes'; Type = 'action'
                Confirm = $true
                Warning = 'Resets the folder-pane layout (favorites/pane customizations are lost). Classic fix for "Cannot start Microsoft Outlook" loops.'
                Action = {
                    Start-Process outlook.exe -ArgumentList '/resetnavpane'
                    Write-Host (Paint "  Outlook starting with a fresh navigation pane." 'ok')
                }
            },
            @{
                Label = 'Outlook: list mail profiles'; Desc = 'profiles in the registry (Office 16.0)'; Type = 'action'
                Action = {
                    $p = 'HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles'
                    if (Test-Path $p) {
                        $names = (Get-ChildItem $p -ErrorAction SilentlyContinue).PSChildName
                        if ($names) { foreach ($n in $names) { Write-Kv 'profile' $n 'cyanDim' } }
                        else { Write-Host (Paint "  No profiles found." 'dim') }
                        Write-Host ""
                        Write-Host (Paint "  Corrupt profile suspected? Create a NEW one via Control Panel > Mail (32-bit)," 'dim')
                        Write-Host (Paint "  set it as default, and test - do not delete the old one until mail flows." 'dim')
                    } else {
                        Write-Host (Paint "  No Office 16.0 profile key - different Office version or no Outlook setup." 'warn')
                    }
                }
            },
            @{
                Label = 'Scanpst (Inbox Repair) locator'; Desc = 'find the OST/PST repair tool'; Type = 'action'
                Action = {
                    $candidates = @(
                        "$env:ProgramFiles\Microsoft Office\root\Office16\SCANPST.EXE",
                        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\SCANPST.EXE"
                    )
                    $found = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
                    if ($found) {
                        Write-Kv 'scanpst' $found 'ok'
                        Write-Host ""
                        Write-Host (Paint "  Close Outlook first. Run scanpst against the PST/OST (see 'Outlook data files' for paths)." 'dim')
                        Write-Host (Paint "  Repeat until it reports no errors; for OST files, deleting + resync is often faster." 'dim')
                    } else {
                        Write-Host (Paint "  SCANPST.EXE not found in the usual Click-to-Run paths." 'warn')
                    }
                }
            },
            @{
                Label = 'Office quick repair'; Desc = 'Click-to-Run repair without reinstall'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Runs the Office Quick Repair (offline, keeps settings). Close Office apps first. If Quick fails, use Online Repair from Programs & Features.'
                Action = {
                    $c2r = "$env:ProgramFiles\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe"
                    if (-not (Test-Path $c2r)) { $c2r = "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe" }
                    if (Test-Path $c2r) {
                        Start-Process $c2r -ArgumentList 'scenario=Repair', 'platform=x64', 'culture=en-us', 'RepairType=QuickRepair', 'DisplayLevel=True'
                        Write-Host (Paint "  Quick Repair launched - follow the Office window." 'ok')
                    } else {
                        Write-Host (Paint "  OfficeC2RClient.exe not found - MSI-based Office? Repair via Programs & Features." 'warn')
                    }
                }
            },
            @{
                Label = 'OneDrive reset'; Desc = 'onedrive /reset - fixes stuck sync'; Type = 'action'
                Confirm = $true
                Warning = 'Restarts OneDrive and rebuilds its sync state. Files are NOT deleted, but a full re-scan runs (can take a while on big libraries).'
                Action = {
                    $od = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
                    if (-not (Test-Path $od)) { $od = "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe" }
                    if (Test-Path $od) {
                        Start-Process $od -ArgumentList '/reset'
                        Write-Host (Paint "  Reset issued. If the icon does not return in ~2 minutes, start OneDrive manually." 'ok')
                    } else {
                        Write-Host (Paint "  OneDrive.exe not found in the usual locations." 'warn')
                    }
                }
            },
            @{
                Label = 'Teams (new) cache clear'; Desc = 'kill ms-teams + clear LocalCache'; Type = 'action'
                Confirm = $true
                Warning = 'Closes Teams and clears its local cache. You stay signed in via SSO in most cases, but custom backgrounds/settings may reset.'
                Action = {
                    Get-Process ms-teams -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    $cache = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache"
                    if (Test-Path $cache) {
                        Remove-Item "$cache\*" -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Host (Paint "  Teams cache cleared. Start Teams again and let it rebuild." 'ok')
                    } else {
                        Write-Host (Paint "  New-Teams cache folder not found (classic Teams? -> %AppData%\Microsoft\Teams)." 'warn')
                    }
                }
            }
        )
    }
}

# =====================================================================
#  10. QUICK LAUNCH  (open the usual consoles, with field tips)
# =====================================================================
function Get-WinQuickLaunchMenu {
    # One SHARED action for every launcher. The node itself carries the
    # data (LaunchExe / LaunchArgs / Tips) and arrives as $n.
    # No GetNewClosure() here on purpose: closures live in their own
    # module scope and lose sight of script-scoped functions like Paint
    # when the toolkit is started via -File (Run-Toolkit.cmd).
    $launch = {
        param($n)
        if ($n.Tips -and $n.Tips.Count -gt 0) {
            foreach ($t in $n.Tips) { Write-Host (Paint "  - $t" 'dim') }
            Write-Host ""
        }
        if ($n.LaunchArgs -and $n.LaunchArgs.Count -gt 0) {
            Start-Process $n.LaunchExe -ArgumentList $n.LaunchArgs
        } else {
            Start-Process $n.LaunchExe
        }
        Write-Host (Paint "  $($n.Label) launched in a separate window." 'ok')
    }

    function New-Launcher {
        param([string]$Label, [string]$Desc, [string]$Exe, [string[]]$ArgList, [string[]]$Tips)
        return @{
            Label = $Label; Desc = $Desc; Type = 'action'; Interactive = $true
            LaunchExe = $Exe; LaunchArgs = $ArgList; Tips = $Tips; Action = $launch
        }
    }

    @{
        Label = 'Quick launch'; Desc = 'open the usual consoles & tools (with tips)'; Type = 'menu'
        Items = @(
            (New-Launcher 'Device Manager' 'devmgmt.msc' 'devmgmt.msc' @() @(
                'View > Show hidden devices reveals ghost/removed hardware',
                'Yellow bang: Properties > General shows the error code (10, 28, 43...)',
                'Right-click > Uninstall device + Scan for hardware changes = clean re-detect'
            )),
            (New-Launcher 'Event Viewer' 'eventvwr.msc' 'eventvwr.msc' @() @(
                'System log IDs: 41 Kernel-Power (dirty shutdown), 6008 unexpected shutdown, 1074 who rebooted, 7031/7034 service crashes',
                'Filter Current Log > Event ID cuts the noise fast',
                'Custom Views > Administrative Events = all errors/warnings in one list'
            )),
            (New-Launcher 'Services' 'services.msc' 'services.msc' @() @(
                'Check Startup Type before blaming a service (Manual vs Automatic)',
                'Printing broken? restart "Print Spooler"',
                'cmd: sc qc <name> shows config, sc queryex <name> shows the PID'
            )),
            (New-Launcher 'Task Manager' 'taskmgr' 'taskmgr.exe' @() @(
                'Startup tab: disable high-impact entries for slow boots',
                'Details > right-click a column header > Select columns > Command line',
                'Performance > CPU: current vs base speed exposes throttling'
            )),
            (New-Launcher 'Resource Monitor' 'resmon' 'resmon.exe' @() @(
                'CPU tab > Analyze Wait Chain shows what a hung app is waiting on',
                'Disk tab > sort by Response Time; sustained >100 ms = storage pain',
                'Network tab: which process talks to which remote IP'
            )),
            (New-Launcher 'Reliability Monitor' 'crash & stability timeline' 'perfmon.exe' @('/rel') @(
                'The fastest crash timeline in Windows - one column per day',
                'Click a day > View technical details for the crash bucket',
                'Pair the date with Event Viewer System log for root cause'
            )),
            (New-Launcher 'Disk Management' 'diskmgmt.msc' 'diskmgmt.msc' @() @(
                'RAW filesystem = damage; try chkdsk before formatting anything',
                'Disk shows Offline? right-click the disk number > Online',
                'Action > Attach VHD mounts virtual disks'
            )),
            (New-Launcher 'Network Connections' 'ncpa.cpl' 'ncpa.cpl' @() @(
                'Disable + Enable the adapter = fastest interface reset there is',
                'Status > Details = live DHCP lease, DNS, and gateway info'
            )),
            (New-Launcher 'Programs & Features' 'appwiz.cpl' 'appwiz.cpl' @() @(
                'Sort by "Installed On" when something broke recently',
                'Turn Windows features on or off lives in the left pane'
            )),
            (New-Launcher 'Printers folder' 'control printers' 'control.exe' @('printers') @(
                'Select nothing, then File > Server Properties > Drivers to remove bad drivers',
                'Double-click a printer to see and clear its queue'
            )),
            (New-Launcher 'System Configuration' 'msconfig' 'msconfig.exe' @() @(
                'Boot > Safe boot (Minimal) for clean-boot troubleshooting - UNTICK it afterwards',
                'Services > Hide all Microsoft services = clean third-party list'
            )),
            (New-Launcher 'Credential Manager' 'stored Windows credentials' 'control.exe' @('/name', 'Microsoft.CredentialManager') @(
                'Stale entries after a password change cause endless auth prompts',
                'Remove the Windows credential for the affected server/O365, then retry'
            )),
            (New-Launcher 'Registry Editor' 'regedit' 'regedit.exe' @() @(
                'File > Export the key BEFORE touching anything',
                'Favorites menu bookmarks deep keys you revisit',
                'HKCU = per-user settings, HKLM = machine-wide'
            )),
            (New-Launcher 'Task Scheduler' 'taskschd.msc' 'taskschd.msc' @() @(
                'Task Scheduler Library > Microsoft > Windows hides most built-ins',
                'Last Run Result 0x0 = success; anything else, check the action path/account'
            )),
            (New-Launcher 'System Information' 'msinfo32' 'msinfo32.exe' @() @(
                'File > Export a .txt for vendor tickets',
                'Components > Problem Devices = quick broken-hardware list'
            )),
            (New-Launcher 'DirectX Diagnostics' 'dxdiag - GPU & driver info' 'dxdiag.exe' @() @(
                'Display tab shows GPU driver version/date for graphics issues',
                '"Save All Information" produces a full report for remote diagnosis'
            )),
            (New-Launcher 'Computer Management' 'compmgmt.msc - all-in-one' 'compmgmt.msc' @() @(
                'Local Users and Groups, Shares, Event Viewer, Device Manager in one console',
                'Shared Folders > Open Files shows who has a file locked'
            )),
            (New-Launcher 'Group Policy Editor' 'gpedit.msc' 'gpedit.msc' @() @(
                'Not included in Windows Home editions',
                'Computer vs User Configuration matters - wrong side = no effect',
                'cmd: gpresult /h report.html shows what actually applied'
            )),
            (New-Launcher 'Memory Diagnostic' 'mdsched - RAM test' 'mdsched.exe' @() @(
                'Schedules a RAM test at the next reboot',
                'Results: Event Viewer > System > source "MemoryDiagnostics-Results"'
            )),
            (New-Launcher 'Firewall (advanced)' 'wf.msc' 'wf.msc' @() @(
                'Monitoring node shows the ACTIVE profile and effective rules',
                'cmd: netsh advfirewall show allprofiles for a quick state check'
            ))
        )
    }
}

# =====================================================================
#  11. ENTERPRISE & IDENTITY  (domain / Entra / Intune-joined endpoints)
# =====================================================================
function Get-WinIdentityMenu {
    @{
        Label = 'Enterprise & identity'; Desc = 'domain, Entra ID join, GPO, Kerberos, Intune'; Type = 'menu'
        Items = @(
            @{
                Label = 'Device join status (dsregcmd)'; Desc = 'AD / Entra ID / hybrid join + PRT state'; Type = 'action'
                Action = {
                    $raw = dsregcmd /status 2>$null
                    if (-not $raw) { Write-Host (Paint "  dsregcmd returned nothing - not supported on this build?" 'err'); return }
                    $want = @('AzureAdJoined', 'EnterpriseJoined', 'DomainJoined', 'DomainName',
                              'DeviceId', 'TenantName', 'TenantId', 'AzureAdPrt', 'AzureAdPrtUpdateTime',
                              'WamDefaultSet', 'WorkplaceJoined')
                    foreach ($k in $want) {
                        $line = $raw | Select-String -Pattern ("^\s*" + $k + "\s:\s") | Select-Object -First 1
                        if ($line) {
                            $v = ($line.ToString() -split ':', 2)[1].Trim()
                            $col = 'text'
                            if ($v -eq 'YES') { $col = 'ok' }
                            if ($v -eq 'NO')  { $col = 'dim' }
                            if ($k -eq 'AzureAdPrt' -and $v -eq 'NO') { $col = 'err' }
                            Write-Kv $k $v $col
                        }
                    }
                    Write-Host ""
                    Write-Host (Paint "  AzureAdPrt = NO on an Entra-joined device -> SSO is broken;" 'dim')
                    Write-Host (Paint "  lock/unlock or reboot refreshes it. Full detail: dsregcmd /status" 'dim')
                }
            },
            @{
                Label = 'Domain controller check'; Desc = 'which DC answers + secure channel state'; Type = 'action'
                Action = {
                    if (-not $env:USERDNSDOMAIN) {
                        Write-Host (Paint "  This machine is not domain-joined (no USERDNSDOMAIN)." 'warn')
                        Write-Host (Paint "  Entra-only device? use 'Device join status' instead." 'dim')
                        return
                    }
                    Write-Host (Paint "  [1/2] Locating a domain controller (nltest)" 'cyan' -Bold)
                    nltest /dsgetdc:$env:USERDNSDOMAIN
                    Write-Host ""
                    Write-Host (Paint "  [2/2] Secure channel to the domain (nltest /sc_query)" 'cyan' -Bold)
                    nltest /sc_query:$env:USERDNSDOMAIN
                    Write-Host ""
                    Write-Host (Paint "  Broken secure channel = 'trust relationship' errors at logon." 'dim')
                    Write-Host (Paint "  Fix (elevated): Test-ComputerSecureChannel -Repair -Credential (Get-Credential)" 'dim')
                }
            },
            @{
                Label = 'Group Policy summary'; Desc = 'gpresult /r - what actually applied'; Type = 'action'
                Action = {
                    gpresult /r
                    Write-Host ""
                    Write-Host (Paint "  Computer-scope details need an elevated session." 'dim')
                    Write-Host (Paint "  Full HTML report: gpresult /h C:\temp\gp.html" 'dim')
                }
            },
            @{
                Label = 'Force Group Policy update'; Desc = 'gpupdate /force'; Type = 'action'
                Confirm = $true
                Warning = 'Re-applies all computer and user policies now. Some policies may prompt for logoff/reboot (you can answer N).'
                Action = { gpupdate /force }
            },
            @{
                Label = 'Kerberos tickets'; Desc = 'klist - current ticket cache'; Type = 'action'
                Action = {
                    klist
                    Write-Host ""
                    Write-Host (Paint "  No krbtgt ticket on a domain network = auth problems." 'dim')
                }
            },
            @{
                Label = 'Purge Kerberos tickets'; Desc = 'klist purge - fixes stale-auth weirdness'; Type = 'action'
                Confirm = $true
                Warning = 'Clears the Kerberos ticket cache for this logon session. Access to shares/apps re-authenticates on next use; lock/unlock afterwards helps.'
                Action = {
                    klist purge
                    Write-Host (Paint "  Ticket cache purged. Lock/unlock the session (Win+L) to refresh cleanly." 'ok')
                }
            },
            @{
                Label = 'Time sync status'; Desc = 'w32tm - skew breaks Kerberos (>5 min)'; Type = 'action'
                Action = {
                    w32tm /query /status
                    Write-Host ""
                    Write-Host (Paint "  Kerberos tolerates ~5 minutes of skew - beyond that, logons and shares fail." 'dim')
                }
            },
            @{
                Label = 'Force time resync'; Desc = 'w32tm /resync'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Forces an immediate sync against the configured time source.'
                Action = { w32tm /resync }
            },
            @{
                Label = 'Intune/MDM sync trigger'; Desc = 'nudge policy sync via scheduled task'; Type = 'action'
                Action = {
                    $task = Get-ScheduledTask -TaskPath '\Microsoft\Windows\EnterpriseMgmt\*' -ErrorAction SilentlyContinue |
                        Where-Object { $_.TaskName -like '*Schedule #3*' } | Select-Object -First 1
                    if ($task) {
                        $task | Start-ScheduledTask
                        Write-Host (Paint "  Intune sync task triggered ($($task.TaskName))." 'ok')
                        Write-Host (Paint "  Check result in Company Portal or Settings > Accounts > Access work or school > Info > Sync." 'dim')
                    } else {
                        Write-Host (Paint "  No Intune enrollment task found - device may not be MDM-enrolled." 'warn')
                    }
                }
            },
            @{
                Label = 'MDM diagnostics report'; Desc = 'mdmdiagnosticstool -> zip on Desktop (slow)'; Type = 'action'
                Confirm = $true
                Warning = 'Collects enrollment/Autopilot/policy diagnostics into a zip on your Desktop. Takes a minute or two.'
                Action = {
                    $zip = Join-Path ([Environment]::GetFolderPath('Desktop')) ("MDMDiag-{0:yyyyMMdd-HHmm}.zip" -f (Get-Date))
                    mdmdiagnosticstool.exe -area 'DeviceEnrollment;DeviceProvisioning;Autopilot' -zip $zip
                    if (Test-Path $zip) {
                        Write-Host (Paint "  Report written: $zip" 'ok' -Bold)
                    } else {
                        Write-Host (Paint "  Tool finished but no zip found - check output above." 'warn')
                    }
                    Write-Host (Paint "  Intune app-install logs live at: C:\ProgramData\Microsoft\IntuneManagementExtension\Logs" 'dim')
                }
            }
        )
    }
}

# =====================================================================
#  Get-WindowsMenu  --  assemble the Windows branch
# =====================================================================
function Get-WindowsMenu {
    @{
        Label = 'Windows'; Desc = 'endpoint diagnostics & fixes'; Type = 'menu'
        Items = @(
            (Get-WinNetworkMenu),
            (Get-WinSystemMenu),
            (Get-WinDiskMenu),
            (Get-WinUpdateMenu),
            (Get-WinRepairMenu),
            (Get-WinHardwareMenu),
            (Get-WinPrinterMenu),
            (Get-WinAccountsMenu),
            (Get-WinAppsMenu),
            (Get-WinIdentityMenu),
            (Get-WinQuickLaunchMenu)
        )
    }
}
