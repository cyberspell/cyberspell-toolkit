# =====================================================================
#  cyberspell // toolkit
#  CheatSheet.ps1  --  searchable Windows command reference
#  Pure data + a small engine. To extend: add @('command','what it does')
#  rows to the tables below. No UI code to touch.
# =====================================================================

$script:CheatSheetData = @(
    @{
        Cat = 'Files & folders'
        Items = @(
            @('dir /a /s', 'list files incl. hidden, recursive'),
            @('dir /o-s', 'list sorted by size, largest first'),
            @('tree /f', 'folder tree including file names'),
            @('cd \ | cd ..', 'go to drive root | go up one level'),
            @('copy src dst', 'copy files (basic)'),
            @('xcopy src dst /e /h /i', 'copy folders incl. hidden and empty dirs'),
            @('robocopy src dst /mir', 'mirror a folder (the pro copier)'),
            @('robocopy src dst /z /r:1 /w:1', 'restartable copy, 1 retry, 1s wait'),
            @('robocopy src dst /copyall /b', 'copy all attributes incl. ACLs, backup mode'),
            @('move src dst', 'move or rename files and folders'),
            @('del /f /q file', 'force-delete files without prompting'),
            @('rd /s /q folder', 'delete a folder tree without prompting'),
            @('ren old new', 'rename a file or folder'),
            @('attrib -h -s file', 'strip hidden and system attributes'),
            @('type file.txt', 'print a text file to the console'),
            @('more file.txt', 'print a file one page at a time'),
            @('findstr /i /s "text" *.log', 'search text inside files, recursive'),
            @('findstr /v "text" file', 'show lines NOT containing text'),
            @('fc file1 file2', 'compare two files line by line'),
            @('where notepad', 'locate an executable on PATH'),
            @('forfiles /p C:\logs /d -30 /c "cmd /c del @file"', 'delete files older than 30 days'),
            @('mklink /d link target', 'create a directory symbolic link'),
            @('mklink /h link target', 'create a hard link to a file'),
            @('compact /c /s', 'NTFS-compress a folder tree'),
            @('expand file.cab -F:* dest', 'extract from a cabinet file'),
            @('tar -xf archive.zip', 'extract zip/tar archives (Win10 1803+)'),
            @('clip < file.txt', 'pipe a file into the clipboard'),
            @('sort file.txt /o out.txt', 'sort the lines of a text file'),
            @('fsutil file createnew f.txt 1024', 'create a file of an exact byte size'),
            @('Get-ChildItem -Recurse -Filter *.log', 'list files recursively (PS)'),
            @('Get-FileHash file -Algorithm SHA256', 'hash a file (PS)')
        )
    },
    @{
        Cat = 'Disk & filesystem'
        Items = @(
            @('chkdsk C: /f', 'fix filesystem errors (locks the volume)'),
            @('chkdsk C: /r', 'also scan and recover bad sectors (slow)'),
            @('chkdsk C: /scan', 'online scan, no downtime (NTFS)'),
            @('sfc /scannow', 'scan and repair protected system files'),
            @('sfc /verifyonly', 'check system files, change nothing'),
            @('defrag C: /o', 'optimize a drive (defrag HDD, retrim SSD)'),
            @('defrag C: /a', 'analyze fragmentation only'),
            @('diskpart', 'disk/partition shell: list disk, select, clean'),
            @('format X: /fs:ntfs /q', 'quick-format a volume as NTFS'),
            @('label X: NAME', 'set a volume label'),
            @('vol X:', 'show volume label and serial number'),
            @('fsutil dirty query C:', 'is the volume flagged dirty?'),
            @('fsutil fsinfo drives', 'list all drive letters'),
            @('fsutil volume diskfree C:', 'free/total bytes on a volume'),
            @('fsutil behavior query DisableDeleteNotify', 'is TRIM enabled? (0 = yes)'),
            @('vssadmin list shadows', 'list shadow copies / restore points'),
            @('vssadmin list shadowstorage', 'shadow-copy space usage per volume'),
            @('mountvol', 'list or assign volume mount points'),
            @('manage-bde -status', 'BitLocker status for every volume'),
            @('cipher /w:C:', 'overwrite free space (secure-ish wipe)'),
            @('cleanmgr /sageset:1', 'configure a Disk Cleanup profile'),
            @('cleanmgr /sagerun:1', 'run a saved Disk Cleanup profile'),
            @('Get-Volume', 'volumes with free space (PS)'),
            @('Get-PhysicalDisk | ft FriendlyName,HealthStatus', 'physical disk health (PS)'),
            @('Get-Disk | Get-StorageReliabilityCounter', 'SMART-style wear and temperature (PS)'),
            @('Optimize-Volume -DriveLetter C -ReTrim', 'issue TRIM to an SSD (PS)'),
            @('Repair-Volume -DriveLetter C -Scan', 'online volume scan (PS)')
        )
    },
    @{
        Cat = 'Network - core'
        Items = @(
            @('ipconfig /all', 'full adapter config incl. DHCP and DNS'),
            @('ipconfig /flushdns', 'clear the DNS resolver cache'),
            @('ipconfig /displaydns', 'show cached DNS entries'),
            @('ipconfig /release', 'release the current DHCP lease'),
            @('ipconfig /renew', 'request a fresh DHCP lease'),
            @('ipconfig /registerdns', 're-register this host in DNS'),
            @('ping -t host', 'continuous ping (Ctrl+C to stop)'),
            @('ping -n 50 host', '50 pings - quick packet-loss check'),
            @('ping -l 1472 -f host', 'MTU test: 1472 payload, do not fragment'),
            @('tracert -d host', 'trace the route, skip DNS lookups'),
            @('pathping host', 'tracert plus per-hop loss statistics'),
            @('nslookup host', 'resolve a name via the default DNS server'),
            @('nslookup host 8.8.8.8', 'resolve via a specific DNS server'),
            @('nslookup -type=mx domain', 'look up mail exchanger records'),
            @('nslookup -type=txt domain', 'look up TXT records (SPF, DKIM, DMARC)'),
            @('netstat -ano', 'all connections and listeners with PIDs'),
            @('netstat -anob', 'same, plus owning process names (admin)'),
            @('netstat -rn', 'routing table, numeric'),
            @('arp -a', 'IP-to-MAC neighbour table'),
            @('arp -d *', 'clear the ARP cache'),
            @('route print', 'the routing table'),
            @('route add 10.0.0.0 mask 255.0.0.0 192.168.1.1', 'add a static route'),
            @('getmac /v', 'MAC address per adapter, verbose'),
            @('nbtstat -n', 'local NetBIOS name table'),
            @('hostname', 'this computer''s name'),
            @('telnet host 25', 'raw TCP port test (feature must be enabled)')
        )
    },
    @{
        Cat = 'Network - netsh & shares'
        Items = @(
            @('netsh winsock reset', 'reset the Winsock catalog (reboot needed)'),
            @('netsh int ip reset', 'reset the TCP/IP stack (reboot needed)'),
            @('netsh interface show interface', 'adapter admin and link state'),
            @('netsh interface ip show config', 'IP configuration per interface'),
            @('netsh wlan show profiles', 'saved Wi-Fi networks'),
            @('netsh wlan show profile NAME key=clear', 'reveal a saved Wi-Fi password'),
            @('netsh wlan show interfaces', 'current Wi-Fi signal, channel and BSSID'),
            @('netsh wlan show wlanreport', 'generate a Wi-Fi history HTML report'),
            @('netsh wlan disconnect', 'disconnect the current Wi-Fi network'),
            @('netsh advfirewall show allprofiles', 'firewall state per profile'),
            @('netsh advfirewall firewall show rule name=all', 'dump all firewall rules'),
            @('netsh advfirewall set allprofiles state off', 'disable the firewall (testing only)'),
            @('netsh advfirewall reset', 'restore default firewall policy'),
            @('netsh int tcp show global', 'global TCP tuning parameters'),
            @('netsh trace start capture=yes', 'start a built-in packet capture'),
            @('netsh trace stop', 'stop the capture and write the ETL'),
            @('net use X: \\server\share /persistent:yes', 'map a network drive'),
            @('net use * /delete /y', 'remove all mapped drives'),
            @('net share', 'list shares hosted on this machine'),
            @('net view \\server', 'list shares on a remote host'),
            @('net session', 'who is connected to this machine'),
            @('net statistics workstation', 'workstation network statistics')
        )
    },
    @{
        Cat = 'Network - PowerShell'
        Items = @(
            @('Test-NetConnection host -Port 443', 'ping plus TCP port test in one'),
            @('Test-NetConnection host -TraceRoute', 'traceroute with object output'),
            @('Test-NetConnection -InformationLevel Detailed', 'full diagnostic detail'),
            @('Resolve-DnsName host', 'DNS lookup with record types'),
            @('Resolve-DnsName host -Server 1.1.1.1', 'query a specific resolver'),
            @('Get-NetAdapter', 'adapters with link speed and status'),
            @('Get-NetAdapter | Restart-NetAdapter', 'bounce every adapter'),
            @('Get-NetIPConfiguration -Detailed', 'IP, gateway and DNS per adapter'),
            @('Get-NetIPAddress -AddressFamily IPv4', 'all IPv4 addresses'),
            @('Get-NetTCPConnection -State Established', 'live TCP connections'),
            @('Get-DnsClientCache', 'resolver cache as objects'),
            @('Clear-DnsClientCache', 'flush DNS (PS equivalent)'),
            @('Get-NetRoute -AddressFamily IPv4', 'routing table as objects'),
            @('Get-SmbMapping', 'mapped drives, SMB view'),
            @('Get-SmbConnection', 'active SMB sessions to servers'),
            @('Get-NetFirewallProfile', 'firewall profile settings'),
            @('Invoke-WebRequest -Uri url -UseBasicParsing', 'HTTP request from PowerShell'),
            @('Get-NetConnectionProfile', 'network category (Public/Private/Domain)')
        )
    },
    @{
        Cat = 'Processes & shutdown'
        Items = @(
            @('tasklist', 'running processes'),
            @('tasklist /svc', 'processes with the services they host'),
            @('tasklist /m', 'processes with loaded modules (DLLs)'),
            @('tasklist /fi "memusage gt 200000"', 'processes using more than ~200 MB'),
            @('taskkill /im name.exe /f', 'force-kill by image name'),
            @('taskkill /pid 1234 /f /t', 'kill a PID and its child processes'),
            @('start "" app.exe', 'launch detached from the console'),
            @('start "" /b /min app.exe', 'launch minimised in the background'),
            @('Get-Process | Sort-Object CPU -Descending', 'top CPU consumers (PS)'),
            @('Get-Process name | Select-Object Path,StartTime', 'where a process runs from (PS)'),
            @('Stop-Process -Name name -Force', 'kill by name (PS)'),
            @('Get-CimInstance Win32_StartupCommand', 'startup entries (PS)'),
            @('Get-CimInstance Win32_Process | select Name,CommandLine', 'full command lines (PS)'),
            @('shutdown /r /t 0', 'restart immediately'),
            @('shutdown /s /t 0', 'shut down immediately'),
            @('shutdown /a', 'abort a pending shutdown'),
            @('shutdown /r /o', 'restart into Advanced Startup / WinRE'),
            @('shutdown /r /m \\pc /t 0', 'restart a remote machine'),
            @('shutdown /g', 'restart and reopen registered apps'),
            @('timeout /t 10 /nobreak', 'wait 10 seconds inside a script'),
            @('Restart-Computer -Force', 'restart (PS)')
        )
    },
    @{
        Cat = 'Services'
        Items = @(
            @('sc query svcname', 'current service state'),
            @('sc qc svcname', 'service config: binary path and account'),
            @('sc queryex svcname', 'state plus the hosting PID'),
            @('sc config svcname start= auto', 'set startup type (note the space)'),
            @('sc config svcname obj= ".\user" password= pw', 'change the logon account'),
            @('sc failure svcname reset= 0 actions= restart/60000', 'auto-restart the service on crash'),
            @('sc sdshow svcname', 'service security descriptor'),
            @('sc delete svcname', 'delete a service registration'),
            @('net start svcname', 'start a service'),
            @('net stop svcname', 'stop a service'),
            @('net stop spooler && net start spooler', 'the classic print-spooler bounce'),
            @('Get-Service | Where-Object Status -eq Running', 'running services (PS)'),
            @('Get-Service svc | Select-Object -Expand DependentServices', 'what depends on this service'),
            @('Restart-Service svc -Force', 'restart including dependents (PS)'),
            @('Set-Service svc -StartupType Disabled', 'disable a service (PS)'),
            @('Get-CimInstance Win32_Service | ? StartMode -eq Auto', 'auto-start services (PS)')
        )
    },
    @{
        Cat = 'System info & power'
        Items = @(
            @('systeminfo', 'OS build, boot time, patches, RAM'),
            @('systeminfo | findstr /c:"System Boot Time"', 'last boot time, one line'),
            @('winver', 'Windows version dialog'),
            @('ver', 'kernel version, one line'),
            @('whoami /all', 'user SID, groups and privileges'),
            @('set', 'all environment variables (CMD)'),
            @('echo %COMPUTERNAME%', 'print a single variable'),
            @('wmic bios get serialnumber', 'device serial / asset tag'),
            @('wmic csproduct get name,vendor', 'hardware model and vendor'),
            @('Get-ComputerInfo', 'everything as objects (slow)'),
            @('Get-CimInstance Win32_BIOS', 'BIOS incl. serial (modern way)'),
            @('Get-CimInstance Win32_PhysicalMemory', 'RAM sticks, size and speed'),
            @('Get-HotFix | Sort InstalledOn -Desc', 'installed updates, newest first'),
            @('slmgr /xpr', 'activation status popup'),
            @('slmgr /dlv', 'detailed licensing information'),
            @('slmgr /ato', 'force online activation'),
            @('w32tm /query /status', 'time source and clock offset'),
            @('w32tm /resync /force', 'force an immediate time sync'),
            @('w32tm /stripchart /computer:dc /samples:5', 'live offset against a server'),
            @('powercfg /batteryreport', 'battery health HTML report'),
            @('powercfg /energy', '60-second power/energy diagnosis'),
            @('powercfg /sleepstudy', 'modern-standby drain report'),
            @('powercfg /a', 'which sleep states are available'),
            @('powercfg /h off', 'disable hibernation, reclaim disk'),
            @('powercfg /requests', 'what is blocking sleep right now'),
            @('powercfg /lastwake', 'what woke the machine last'),
            @('Get-Uptime', 'uptime (PS 6+)')
        )
    },
    @{
        Cat = 'Drivers & hardware'
        Items = @(
            @('driverquery /v', 'installed drivers, verbose'),
            @('driverquery /si', 'signed-driver report'),
            @('pnputil /enum-drivers', 'third-party driver store contents'),
            @('pnputil /add-driver x.inf /install', 'install a driver package'),
            @('pnputil /delete-driver oem12.inf /uninstall /force', 'remove a driver package'),
            @('devmgmt.msc', 'Device Manager'),
            @('hdwwiz.exe', 'legacy Add Hardware wizard'),
            @('dxdiag /t out.txt', 'DirectX diagnostics to a text file'),
            @('msinfo32', 'System Information console'),
            @('Get-PnpDevice -Status Error', 'devices in a problem state (PS)'),
            @('Get-PnpDevice -Class Display', 'display adapters (PS)'),
            @('Get-CimInstance Win32_VideoController', 'GPU name and driver version'),
            @('Get-CimInstance Win32_PnPSignedDriver', 'all signed drivers with dates'),
            @('Get-WmiObject Win32_Battery', 'battery status (legacy)'),
            @('mdsched.exe', 'schedule a Windows memory test'),
            @('verifier /standard /all', 'enable Driver Verifier (expect BSODs)'),
            @('verifier /reset', 'turn Driver Verifier off')
        )
    },
    @{
        Cat = 'Users, groups & policy'
        Items = @(
            @('net user', 'list local accounts'),
            @('net user name', 'account details, expiry, last logon'),
            @('net user name newpass', 'set a local password'),
            @('net user name /active:yes', 'enable a local account'),
            @('net user name /domain', 'query a domain account'),
            @('net localgroup administrators', 'who holds local admin'),
            @('net localgroup administrators user /add', 'grant local admin'),
            @('net accounts', 'password and lockout policy'),
            @('net group "Domain Admins" /domain', 'domain group membership'),
            @('query user', 'logged-on users and session IDs'),
            @('logoff 2', 'log off session ID 2'),
            @('runas /user:domain\admin cmd', 'run a command as another user'),
            @('gpresult /r', 'applied Group Policy summary'),
            @('gpresult /h gp.html', 'full HTML policy report'),
            @('gpresult /scope computer /v', 'verbose computer-scope policy'),
            @('gpupdate /force', 're-apply Group Policy now'),
            @('dsregcmd /status', 'AD / Entra ID join state and PRT'),
            @('nltest /dsgetdc:domain', 'which DC answers for this domain'),
            @('nltest /sc_query:domain', 'secure-channel health to the domain'),
            @('Test-ComputerSecureChannel -Repair', 'repair a broken domain trust (PS)'),
            @('Get-LocalUser | ft Name,Enabled,LastLogon', 'local users (PS)'),
            @('Add-LocalGroupMember -Group Administrators -Member user', 'grant admin (PS)'),
            @('secedit /export /cfg pol.txt', 'export the local security policy')
        )
    },
    @{
        Cat = 'Security & permissions'
        Items = @(
            @('icacls path', 'show NTFS permissions'),
            @('icacls path /grant user:(OI)(CI)F', 'grant full control, inheritable'),
            @('icacls path /remove user', 'remove a user''s ACE'),
            @('icacls path /reset /t', 'reset ACLs to inherited, recursive'),
            @('icacls path /save acl.txt /t', 'back up ACLs of a tree'),
            @('icacls path /restore acl.txt', 'restore saved ACLs'),
            @('takeown /f path /r /d y', 'take ownership recursively'),
            @('certutil -store my', 'machine personal certificate store'),
            @('certutil -hashfile file SHA256', 'hash a file'),
            @('certutil -urlcache * delete', 'clear the certificate URL cache'),
            @('certlm.msc | certmgr.msc', 'machine | user certificate console'),
            @('auditpol /get /category:*', 'current audit policy'),
            @('manage-bde -protectors -get C:', 'BitLocker key protectors and IDs'),
            @('manage-bde -unlock C: -rp RECOVERYKEY', 'unlock a volume with a recovery key'),
            @('manage-bde -on C: -RecoveryPassword', 'enable BitLocker with a recovery password'),
            @('Get-BitLockerVolume', 'BitLocker state as objects (PS)'),
            @('Get-MpComputerStatus', 'Defender status and definitions (PS)'),
            @('Start-MpScan -ScanType QuickScan', 'run a Defender quick scan (PS)'),
            @('Update-MpSignature', 'update Defender definitions (PS)'),
            @('Get-MpThreatDetection', 'recent Defender detections (PS)'),
            @('Get-Acl path | Format-List', 'permissions as objects (PS)')
        )
    },
    @{
        Cat = 'Registry'
        Items = @(
            @('reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run"', 'machine autorun entries'),
            @('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"', 'per-user autorun entries'),
            @('reg query KEY /s', 'dump a key and everything under it'),
            @('reg query KEY /v name', 'read one value'),
            @('reg add KEY /v name /t REG_DWORD /d 1 /f', 'create or overwrite a value'),
            @('reg delete KEY /v name /f', 'delete a value without prompting'),
            @('reg export KEY file.reg', 'back up a key to a .reg file'),
            @('reg import file.reg', 'apply a .reg file'),
            @('reg save HKLM\SOFTWARE sw.hiv', 'binary hive backup'),
            @('reg load HKLM\TempHive file.hiv', 'mount an offline hive'),
            @('reg unload HKLM\TempHive', 'unmount an offline hive'),
            @('Get-ItemProperty ''HKLM:\Path''', 'read values (PS)'),
            @('Set-ItemProperty -Path ''HKCU:\Path'' -Name n -Value v', 'write a value (PS)'),
            @('New-Item -Path ''HKCU:\Path'' -Force', 'create a key (PS)'),
            @('Remove-ItemProperty -Path ''HKCU:\Path'' -Name n', 'delete a value (PS)')
        )
    },
    @{
        Cat = 'Servicing, DISM & apps'
        Items = @(
            @('Dism /Online /Cleanup-Image /CheckHealth', 'component store: quick corruption flag'),
            @('Dism /Online /Cleanup-Image /ScanHealth', 'deep scan for store corruption'),
            @('Dism /Online /Cleanup-Image /RestoreHealth', 'repair the store from Windows Update'),
            @('Dism /Online /Cleanup-Image /RestoreHealth /Source:X:\sources\install.wim', 'repair from local media'),
            @('Dism /Online /Cleanup-Image /StartComponentCleanup', 'shrink WinSxS safely'),
            @('Dism /Online /Cleanup-Image /AnalyzeComponentStore', 'how big is WinSxS really'),
            @('Dism /Online /Get-Packages', 'installed servicing packages'),
            @('Dism /Online /Get-Features /Format:Table', 'optional Windows features'),
            @('Dism /Online /Enable-Feature /FeatureName:NAME /All', 'enable a Windows feature'),
            @('Dism /Get-ImageInfo /ImageFile:install.wim', 'what editions an image contains'),
            @('Dism /Image:D:\ /Add-Driver /Driver:C:\drv /Recurse', 'inject drivers into an offline image'),
            @('winget list', 'installed applications'),
            @('winget search term', 'find a package'),
            @('winget install --id Publisher.App -e', 'install a specific package'),
            @('winget upgrade --all --include-unknown', 'update everything winget manages'),
            @('winget uninstall --id Publisher.App', 'uninstall a package'),
            @('Get-AppxPackage *name*', 'find a Store/UWP app (PS)'),
            @('Get-AppxPackage *name* | Remove-AppxPackage', 'remove a UWP app for this user'),
            @('Get-AppxPackage -AllUsers | Reset-AppxPackage', 'reset a misbehaving UWP app'),
            @('wsreset.exe', 'reset the Microsoft Store cache'),
            @('Get-Package', 'installed packages via PackageManagement'),
            @('wmic product get name,version', 'MSI-installed products (legacy)')
        )
    },
    @{
        Cat = 'Windows Update'
        Items = @(
            @('UsoClient StartScan', 'trigger an update scan'),
            @('UsoClient StartDownload', 'start downloading updates'),
            @('UsoClient StartInstall', 'start installing updates'),
            @('wuauclt /detectnow', 'legacy scan trigger (older builds)'),
            @('net stop wuauserv && net stop bits', 'stop the update services'),
            @('ren %systemroot%\SoftwareDistribution SD.old', 'rename the update cache to force a rebuild'),
            @('ren %systemroot%\system32\catroot2 cr2.old', 'reset the catalog store'),
            @('dism /online /cleanup-image /spsuperseded', 'remove superseded service-pack backups'),
            @('wusa /uninstall /kb:5001234', 'uninstall a specific update'),
            @('Get-WindowsUpdateLog', 'convert the ETL update log to readable text'),
            @('Install-Module PSWindowsUpdate', 'community module for full update control'),
            @('Get-WUList / Install-WindowsUpdate', 'list / install updates (PSWindowsUpdate)'),
            @('control update', 'open Windows Update settings')
        )
    },
    @{
        Cat = 'Boot & recovery'
        Items = @(
            @('bootrec /fixmbr', 'rewrite the master boot record (WinRE)'),
            @('bootrec /fixboot', 'write a new boot sector (WinRE)'),
            @('bootrec /rebuildbcd', 'rebuild boot entries (WinRE)'),
            @('bootrec /scanos', 'find Windows installations (WinRE)'),
            @('bcdedit /enum', 'list boot configuration entries'),
            @('bcdedit /set {default} safeboot minimal', 'force safe mode on next boot'),
            @('bcdedit /deletevalue {default} safeboot', 'undo forced safe mode'),
            @('bcdedit /set {default} bootstatuspolicy ignoreallfailures', 'stop auto-repair loops'),
            @('bcdedit /timeout 5', 'boot menu timeout in seconds'),
            @('bcdboot C:\Windows', 'rebuild boot files for an installation'),
            @('reagentc /info', 'WinRE status and image location'),
            @('reagentc /enable', 're-enable the recovery environment'),
            @('reagentc /boottore', 'boot straight into WinRE next restart'),
            @('rstrui.exe', 'launch System Restore'),
            @('systemreset -cleanpc', 'launch Reset this PC'),
            @('wbadmin get versions', 'list available system backups'),
            @('wbadmin start recovery', 'recover from a backup (see /? first)'),
            @('sfc /scannow /offbootdir=C:\ /offwindir=C:\Windows', 'repair an offline installation'),
            @('Get-ComputerRestorePoint', 'list restore points (PS)'),
            @('Checkpoint-Computer -Description "before change"', 'create a restore point (PS)')
        )
    },
    @{
        Cat = 'Events & performance'
        Items = @(
            @('wevtutil qe System /c:20 /rd:true /f:text', 'last 20 System events, readable'),
            @('wevtutil qe Application /q:"*[System[(Level=2)]]" /c:20 /f:text', 'last 20 application errors'),
            @('wevtutil el', 'list every event log'),
            @('wevtutil epl System sys.evtx', 'export a log to a file'),
            @('wevtutil cl Application', 'clear a log (careful)'),
            @('wevtutil gli System', 'log size and record counts'),
            @('Get-WinEvent -FilterHashtable @{LogName=''System'';Level=1,2} -Max 20', 'recent critical/error events (PS)'),
            @('Get-WinEvent -FilterHashtable @{LogName=''System'';Id=41}', 'find dirty shutdowns / power loss'),
            @('Get-WinEvent -FilterHashtable @{LogName=''System'';Id=1074}', 'who or what triggered a reboot'),
            @('Get-WinEvent -FilterHashtable @{LogName=''Security'';Id=4625}', 'failed logon attempts'),
            @('Get-WinEvent -ListLog * | ? RecordCount -gt 0', 'logs that actually contain data'),
            @('perfmon /rel', 'Reliability Monitor crash timeline'),
            @('perfmon /report', '60-second system diagnostics report'),
            @('resmon', 'Resource Monitor'),
            @('typeperf "\Processor(_Total)\% Processor Time" -sc 10', 'live CPU counter in the console'),
            @('logman query', 'list data-collector sets'),
            @('Get-Counter ''\Memory\Available MBytes''', 'read a perf counter (PS)')
        )
    },
    @{
        Cat = 'Printing & devices'
        Items = @(
            @('wmic printer get name,default,portname', 'installed printers (legacy)'),
            @('print /d:\\server\printer file.txt', 'send a file to a printer'),
            @('rundll32 printui.dll,PrintUIEntry /?', 'printer management CLI help'),
            @('rundll32 printui.dll,PrintUIEntry /in /n\\srv\prn', 'install a network printer'),
            @('rundll32 printui.dll,PrintUIEntry /dn /n\\srv\prn', 'remove a network printer'),
            @('printmanagement.msc', 'Print Management console'),
            @('control printers', 'the Printers folder'),
            @('net stop spooler && net start spooler', 'restart the print spooler'),
            @('del /q %systemroot%\System32\spool\PRINTERS\*', 'clear stuck print jobs (spooler stopped)'),
            @('Get-Printer | ft Name,DriverName,PrinterStatus', 'printers as objects (PS)'),
            @('Get-PrintJob -PrinterName name', 'jobs queued on a printer (PS)'),
            @('Remove-PrintJob -PrinterName name -ID 3', 'cancel one print job (PS)'),
            @('Remove-Printer -Name name', 'delete a printer (PS)'),
            @('Get-PrinterDriver', 'installed print drivers (PS)'),
            @('Set-Printer -Name name -Comment "text"', 'edit printer properties (PS)')
        )
    },
    @{
        Cat = 'Remote & sessions'
        Items = @(
            @('mstsc /v:host', 'Remote Desktop to a host'),
            @('mstsc /v:host /admin', 'RDP into the console session'),
            @('mstsc /v:host /f /multimon', 'fullscreen RDP across monitors'),
            @('qwinsta /server:host', 'sessions on a remote host'),
            @('rwinsta ID /server:host', 'reset (kill) a remote session'),
            @('quser /server:host', 'logged-on users on a remote host'),
            @('winrs -r:host cmd', 'remote shell over WinRM'),
            @('psexec \\host cmd', 'remote shell (Sysinternals)'),
            @('Enable-PSRemoting -Force', 'turn on PowerShell remoting'),
            @('Test-WSMan host', 'is WinRM reachable?'),
            @('Enter-PSSession host', 'interactive remote PowerShell'),
            @('Invoke-Command -ComputerName host -ScriptBlock { ... }', 'run code on a remote host'),
            @('Invoke-Command -FilePath script.ps1 -ComputerName a,b', 'run a script on many hosts'),
            @('New-PSSession -ComputerName host', 'reusable remote session'),
            @('Copy-Item -ToSession $s src dst', 'copy files over a PS session'),
            @('Get-WSManInstance -ResourceURI winrm/config', 'WinRM configuration')
        )
    },
    @{
        Cat = 'Scripting & console'
        Items = @(
            @('schtasks /query /fo list /v', 'all scheduled tasks, verbose'),
            @('schtasks /run /tn "name"', 'run a task right now'),
            @('schtasks /change /tn "name" /disable', 'disable a task'),
            @('schtasks /create /sc daily /st 09:00 /tn t /tr cmd.exe', 'create a daily task'),
            @('schtasks /delete /tn "name" /f', 'delete a task'),
            @('Get-ScheduledTask | ? State -eq Ready', 'tasks via PowerShell'),
            @('Start-ScheduledTask -TaskName name', 'trigger a task (PS)'),
            @('Get-ScheduledTaskInfo name', 'last run time and result (PS)'),
            @('msg * "text"', 'message all sessions on this host'),
            @('chcp 65001', 'switch the console to UTF-8'),
            @('doskey /history', 'command history for this session'),
            @('clip', 'pipe command output to the clipboard'),
            @('Get-Clipboard / Set-Clipboard', 'read/write the clipboard (PS)'),
            @('Start-Transcript -Path log.txt', 'record a PowerShell session to file'),
            @('Get-ExecutionPolicy -List', 'script execution policy per scope'),
            @('Unblock-File .\script.ps1', 'remove the Mark of the Web'),
            @('$PSVersionTable', 'which PowerShell edition and version'),
            @('Get-Command *keyword*', 'find a command by name'),
            @('Get-Help name -Examples', 'usage examples for a cmdlet'),
            @('Get-Member', 'what properties/methods an object has'),
            @('Measure-Command { ... }', 'time how long a block takes'),
            @('cmd /c command', 'run a CMD builtin from PowerShell'),
            @('Get-CimInstance Win32_OperatingSystem', 'WMI the modern, supported way'),
            @('Export-Csv out.csv -NoTypeInformation', 'write objects to CSV'),
            @('ConvertTo-Json -Depth 5', 'serialise objects to JSON')
        )
    },
    @{
        Cat = 'Virtualization & WSL'
        Items = @(
            @('wsl --list --verbose', 'installed WSL distributions and versions'),
            @('wsl --status', 'WSL version and default distro'),
            @('wsl --shutdown', 'stop all WSL VMs immediately'),
            @('wsl --update', 'update the WSL kernel'),
            @('wsl --install -d Ubuntu', 'install a distribution'),
            @('wsl --unregister Ubuntu', 'remove a distribution and its disk'),
            @('wsl --export Ubuntu backup.tar', 'back up a distribution'),
            @('wsl --import Name path backup.tar', 'restore a distribution'),
            @('bcdedit /set hypervisorlaunchtype off', 'disable Hyper-V (breaks WSL2, needs reboot)'),
            @('systeminfo | findstr /i "hyper-v"', 'is virtualization available / in use'),
            @('Get-VM', 'Hyper-V virtual machines (PS)'),
            @('Start-VM -Name vm / Stop-VM -Name vm', 'start / stop a VM (PS)'),
            @('Get-VMSwitch', 'Hyper-V virtual switches (PS)'),
            @('Checkpoint-VM -Name vm -SnapshotName s', 'snapshot a VM (PS)'),
            @('Get-WindowsOptionalFeature -Online | ? FeatureName -like ''*Hyper*''', 'Hyper-V feature state (PS)')
        )
    }
)

# ---------------------------------------------------------------------
#  Get-FuzzyScore  --  fzf-style match. Both arguments must already be
#  lowercase. Returns -1 for no match, higher is better: a literal
#  substring beats a scattered subsequence, and adjacent characters
#  score more than spread-out ones.
# ---------------------------------------------------------------------
function Get-FuzzyScore {
    param([string]$Text, [string]$Query)
    if ([string]::IsNullOrEmpty($Query)) { return 0 }
    $idx = $Text.IndexOf($Query)
    if ($idx -ge 0) { return 500 - $idx }
    $pos = 0; $score = 0; $prev = -2
    foreach ($c in $Query.ToCharArray()) {
        $found = -1
        for ($i = $pos; $i -lt $Text.Length; $i++) {
            if ($Text[$i] -eq $c) { $found = $i; break }
        }
        if ($found -lt 0) { return -1 }
        if ($found -eq $prev + 1) { $score += 6 } else { $score += 1 }
        $prev = $found
        $pos  = $found + 1
    }
    return $score
}

# ---------------------------------------------------------------------
#  Get-Fit  --  pad or truncate to an exact column width
# ---------------------------------------------------------------------
function Get-Fit {
    param([string]$Text, [int]$Width)
    if ($Width -lt 1) { return '' }
    if ($null -eq $Text) { $Text = '' }
    if ($Text.Length -le $Width) { return $Text.PadRight($Width) }
    if ($Width -le 1) { return $Text.Substring(0, $Width) }
    return ($Text.Substring(0, $Width - 1) + '~')
}

# ---------------------------------------------------------------------
#  Copy-ToClipboard  --  three routes, because no single one is reliable
#  everywhere: Set-Clipboard (PS 5.0+), clip.exe (always on Windows but
#  needs a real console), and the WinForms clipboard (needs STA).
#  Returns the name of the route that worked, or '' if none did, so the
#  caller can tell the user something useful instead of failing silently.
#
#  Note: if the toolkit runs inside a VM, a successful copy lands on the
#  VM's clipboard. Whether that reaches the host depends on the VM's own
#  clipboard sharing, which is outside the toolkit's control.
# ---------------------------------------------------------------------
function Copy-ToClipboard {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }

    try {
        Set-Clipboard -Value $Text -ErrorAction Stop
        return 'Set-Clipboard'
    } catch { }

    try {
        $null = $Text | clip.exe
        if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) { return 'clip.exe' }
    } catch { }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        [System.Windows.Forms.Clipboard]::SetText($Text)
        return 'WinForms'
    } catch { }

    return ''
}

# ---------------------------------------------------------------------
#  Write-CheatEntry  --  one "command : what it does" row (used by the
#  non-interactive listing)
# ---------------------------------------------------------------------
function Write-CheatEntry {
    param([string]$Cmd, [string]$Desc)
    $pad = 46
    if ($Cmd.Length -ge $pad) {
        Write-Host ("  " + (Paint $Cmd 'cyan'))
        Write-Host ("  " + (' ' * $pad) + (Paint $Desc 'dim'))
    } else {
        Write-Host ("  " + (Paint $Cmd.PadRight($pad) 'cyan') + (Paint $Desc 'dim'))
    }
}

# ---------------------------------------------------------------------
#  Show-CommandFinder  --  one searchable pane over every command.
#  Type to filter (space-separated terms are ANDed), arrows to move,
#  enter copies the highlighted command, esc leaves. An empty query
#  browses everything grouped by category.
#
#  Performance note: the tables are flattened into flat string arrays
#  once, and each keystroke only fills an int score array and sorts
#  indexes. No objects are created and no Sort-Object runs per key, so
#  typing stays responsive on Windows PowerShell 5.1.
# ---------------------------------------------------------------------
function Show-CommandFinder {

    # ---- flatten once ----------------------------------------------------
    $count = 0
    foreach ($c in $script:CheatSheetData) { $count += $c.Items.Count }

    $fCmd  = New-Object 'string[]' $count
    $fDesc = New-Object 'string[]' $count
    $fCat  = New-Object 'string[]' $count
    $fHay  = New-Object 'string[]' $count
    $fCmdL = New-Object 'string[]' $count

    # grouped view: one row per header plus one per command, built once
    $gTotal = $count + $script:CheatSheetData.Count
    $gHead  = New-Object 'bool[]' $gTotal
    $gRef   = New-Object 'int[]'  $gTotal
    $gCat   = New-Object 'string[]' $gTotal
    $gNum   = New-Object 'int[]'  $gTotal

    $i = 0; $g = 0
    foreach ($c in $script:CheatSheetData) {
        $gHead[$g] = $true; $gCat[$g] = $c.Cat; $gNum[$g] = $c.Items.Count; $gRef[$g] = -1
        $g++
        foreach ($e in $c.Items) {
            $fCmd[$i]  = $e[0]
            $fDesc[$i] = $e[1]
            $fCat[$i]  = $c.Cat
            $fCmdL[$i] = $e[0].ToLower()
            $fHay[$i]  = ($e[0] + ' ' + $e[1] + ' ' + $c.Cat).ToLower()
            $gHead[$g] = $false; $gRef[$g] = $i; $gCat[$g] = $c.Cat
            $g++; $i++
        }
    }
    $groups = $script:CheatSheetData.Count

    $canKey = $true
    try { if ([Console]::IsInputRedirected) { $canKey = $false } } catch { $canKey = $false }

    if (-not $canKey) {
        # No interactive console: print the grouped listing and return.
        foreach ($c in $script:CheatSheetData) {
            Write-Host ""
            Write-Host (Paint ("  -- " + $c.Cat + " --") 'magenta' -Bold)
            foreach ($e in $c.Items) { Write-CheatEntry $e[0] $e[1] }
        }
        Write-Host ""
        Write-Host (Paint "  $count commands - full docs at learn.microsoft.com" 'dim')
        return
    }

    # reusable score buffers, allocated once
    $score = New-Object 'int[]' $count
    $keep  = New-Object 'bool[]' $count

    $query = ''; $sel = 0; $offset = 0; $msg = ''
    $bolt = $script:Glyph.bolt
    $chev = $script:Glyph.arrow
    $hbar = $script:Glyph.h
    $dirty = $true

    # current result set
    $order = $null          # int[] of item indexes when filtering
    $matchCount = 0

    while ($true) {

        # ---- recompute only when the query changed -----------------------
        if ($dirty) {
            $q = $query.Trim().ToLower()
            if ($q -eq '') {
                $order = $null
                $matchCount = $count
            } else {
                $terms = @($q.Split(' ') | Where-Object { $_ -ne '' })
                $nKeep = 0
                for ($x = 0; $x -lt $count; $x++) {
                    $keep[$x] = $false; $score[$x] = 0
                    $hay = $fHay[$x]; $cmdl = $fCmdL[$x]
                    $literal = $true; $sum = 0
                    foreach ($t in $terms) {
                        $at = $hay.IndexOf($t)
                        if ($at -lt 0) { $literal = $false; break }
                        $sum += 400 - $at
                        if ($cmdl.Contains($t)) { $sum += 500 }
                    }
                    if ($literal) { $keep[$x] = $true; $score[$x] = $sum + 100000; $nKeep++ }
                }
                if ($nKeep -eq 0) {
                    # nothing matched literally: fall back to fuzzy subsequence
                    for ($x = 0; $x -lt $count; $x++) {
                        $hay = $fHay[$x]
                        $ok = $true; $sum = 0
                        foreach ($t in $terms) {
                            $sc = Get-FuzzyScore -Text $hay -Query $t
                            if ($sc -lt 0) { $ok = $false; break }
                            $sum += $sc
                        }
                        if ($ok) { $keep[$x] = $true; $score[$x] = $sum; $nKeep++ }
                    }
                }
                if ($nKeep -gt 0) {
                    $idx  = New-Object 'int[]' $nKeep
                    $keys = New-Object 'int[]' $nKeep
                    $j = 0
                    for ($x = 0; $x -lt $count; $x++) {
                        if ($keep[$x]) { $idx[$j] = $x; $keys[$j] = -$score[$x]; $j++ }
                    }
                    [Array]::Sort($keys, $idx)      # ascending on -score = best first
                    $order = $idx
                } else {
                    $order = New-Object 'int[]' 0
                }
                $matchCount = $order.Length
            }
            $dirty = $false
        }

        if ($sel -ge $matchCount) { $sel = $matchCount - 1 }
        if ($sel -lt 0) { $sel = 0 }

        # ---- geometry ---------------------------------------------------
        $w = 100; $h = 18
        try { $w = [Console]::WindowWidth - 4 } catch { }
        try { $h = [Console]::WindowHeight - 10 } catch { }
        if ($w -lt 62) { $w = 62 }
        if ($w -gt 118) { $w = 118 }
        if ($h -lt 6) { $h = 6 }
        $cmdW = 42; $catW = 20
        $descW = $w - 4 - $cmdW - $catW
        if ($descW -lt 14) { $catW = 0; $descW = $w - 4 - $cmdW }
        if ($descW -lt 10) { $descW = 10 }

        $filtering = ($null -ne $order)
        $rowTotal = $gTotal
        if ($filtering) { $rowTotal = $matchCount }

        # absolute row index of the highlighted command
        $selRow = 0
        if ($matchCount -gt 0) {
            if ($filtering) { $selRow = $sel }
            else {
                # grouped: skip header rows when mapping selection -> row
                $seen = -1
                for ($r = 0; $r -lt $gTotal; $r++) {
                    if (-not $gHead[$r]) { $seen++; if ($seen -eq $sel) { $selRow = $r; break } }
                }
            }
        }
        if ($selRow -lt $offset) { $offset = $selRow }
        if ($selRow -ge $offset + $h) { $offset = $selRow - $h + 1 }
        if ($offset -gt ($rowTotal - $h)) { $offset = $rowTotal - $h }
        if ($offset -lt 0) { $offset = 0 }

        # ---- draw ------------------------------------------------------
        #  The whole frame is assembled into one string and written with a
        #  single Write-Host. Thirty separate host writes per keystroke is
        #  what made this feel laggy in conhost.
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("  " + (Paint "$bolt command finder" 'cyan' -Bold) +
                             (Paint ("   $count commands in $groups groups") 'dim'))
        [void]$sb.AppendLine("  " + (Paint ([string]$hbar * $w) 'cyanDim'))

        $label = "$matchCount matches"
        if ($matchCount -eq 1) { $label = "1 match" }
        $pad = $w - 8 - $query.Length - $label.Length
        if ($pad -lt 1) { $pad = 1 }
        [void]$sb.AppendLine("  " + (Paint "search $chev " 'magenta' -Bold) +
                             (Paint $query 'white' -Bold) + (Paint '_' 'cyan' -Bold) +
                             (' ' * $pad) + (Paint $label 'cyanDim'))
        [void]$sb.AppendLine('')

        $drawn = 0
        if ($matchCount -eq 0) {
            [void]$sb.AppendLine((Paint "    nothing matches '$query'" 'warn'))
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine((Paint "    try a topic word: dns, bitlocker, boot, printer, wsl, acl" 'dim'))
            $drawn = 3
        } else {
            for ($r = $offset; $r -lt $rowTotal -and $drawn -lt $h; $r++) {
                if ($filtering) {
                    $item = $order[$r]
                    $isSel = ($r -eq $selRow)
                } else {
                    if ($gHead[$r]) {
                        [void]$sb.AppendLine("  " + (Paint ("-- " + $gCat[$r] + " ") 'magenta' -Bold) +
                                             (Paint ("(" + $gNum[$r] + ")") 'dim'))
                        $drawn++
                        continue
                    }
                    $item = $gRef[$r]
                    $isSel = ($r -eq $selRow)
                }
                $mark = '   '
                if ($isSel) { $mark = " $chev " }
                $cmdTxt  = Get-Fit $fCmd[$item] $cmdW
                $descTxt = Get-Fit $fDesc[$item] $descW
                if ($isSel) {
                    $line = (Paint $mark 'magenta' -Bold) + (Paint $cmdTxt 'cyan' -Bold) +
                            (Paint (' ' + $descTxt) 'text')
                } else {
                    $line = $mark + (Paint $cmdTxt 'cyanDim') + (Paint (' ' + $descTxt) 'dim')
                }
                if ($catW -gt 0 -and $filtering) {
                    $line += (Paint (' ' + (Get-Fit $fCat[$item] $catW)) 'magentaDim')
                }
                [void]$sb.AppendLine($line)
                $drawn++
            }
        }
        for ($b = $drawn; $b -lt $h; $b++) { [void]$sb.AppendLine('') }

        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("  " + (Paint ([string]$hbar * $w) 'cyanDim'))
        if ($msg -ne '') { [void]$sb.Append("  " + (Paint $msg 'ok' -Bold)) }

        Clear-Host
        Write-Host $sb.ToString()
        # Clear-Host wipes the reserved row too, so repaint it every frame.
        Set-StatusIdle -Keys $script:StatusKeys.Finder
        $msg = ''

        # ---- input -----------------------------------------------------
        $k = $null
        try { $k = [Console]::ReadKey($true) } catch { return }

        if ($k.Key -eq 'Escape') { Clear-Host; Set-StatusIdle -Keys $script:StatusKeys.Menu; return }
        elseif ($k.Key -eq 'UpArrow')   { if ($sel -gt 0) { $sel-- } }
        elseif ($k.Key -eq 'DownArrow') { if ($sel -lt $matchCount - 1) { $sel++ } }
        elseif ($k.Key -eq 'PageUp')    { $sel -= $h; if ($sel -lt 0) { $sel = 0 } }
        elseif ($k.Key -eq 'PageDown')  { $sel += $h; if ($sel -gt $matchCount - 1) { $sel = $matchCount - 1 } }
        elseif ($k.Key -eq 'Home')      { $sel = 0; $offset = 0 }
        elseif ($k.Key -eq 'End')       { $sel = $matchCount - 1 }
        elseif ($k.Key -eq 'Enter') {
            if ($matchCount -gt 0) {
                $pick = ''
                if ($filtering) { $pick = $fCmd[$order[$sel]] }
                else            { $pick = $fCmd[$gRef[$selRow]] }
                $how = Copy-ToClipboard $pick
                if ($how -ne '') {
                    $msg = "copied ($how):  $pick"
                } else {
                    $msg = "could not reach a clipboard - command: $pick"
                }
            }
        }
        elseif ($k.Key -eq 'Backspace') {
            if ($query.Length -gt 0) {
                $query = $query.Substring(0, $query.Length - 1)
                $sel = 0; $offset = 0; $dirty = $true
            }
        }
        elseif (($k.Modifiers -band [System.ConsoleModifiers]::Control) -and $k.Key -eq 'U') {
            $query = ''; $sel = 0; $offset = 0; $dirty = $true
        }
        else {
            $ch = $k.KeyChar
            if ($ch -and [int]$ch -ge 32 -and [int]$ch -le 126) {
                $query += [string]$ch
                $sel = 0; $offset = 0; $dirty = $true
            }
        }
    }
}

# ---------------------------------------------------------------------
#  Get-WinCheatSheetMenu  --  a single node that opens the finder.
#  Interactive: it runs on the main thread so it can read keys.
#  Quiet: no result line or "press any key" afterwards, because the
#  pane manages its own exit.
# ---------------------------------------------------------------------
function Get-WinCheatSheetMenu {
    $total = 0
    foreach ($c in $script:CheatSheetData) { $total += $c.Items.Count }
    @{
        Label = 'Command cheat sheet'
        Desc  = "$total commands, fuzzy search, copy with enter"
        Type  = 'action'
        Interactive = $true
        Quiet = $true
        Action = { Show-CommandFinder }
    }
}
