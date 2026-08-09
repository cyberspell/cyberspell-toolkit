# =====================================================================
#  Utils.ps1  --  Environment, elevation, logging, safe task runner
#  cyberspell // toolkit
# =====================================================================

# ---------------------------------------------------------------------
#  Enable-VirtualTerminal  --  turn on ANSI/VT for legacy conhost (5.1)
#  Returns $true if VT is (or was made) available, else $false.
# ---------------------------------------------------------------------
function Enable-VirtualTerminal {
    # Windows Terminal / VS Code / modern hosts already have VT on.
    if ($env:WT_SESSION -or $env:TERM_PROGRAM) { return $true }
    # PowerShell 7+ enables VT by default.
    if ($PSVersionTable.PSVersion.Major -ge 6) { return $true }

    # Windows PowerShell 5.1 on legacy conhost: enable via P/Invoke.
    try {
        if (-not ('VtHelper.Native' -as [type])) {
            Add-Type -Namespace VtHelper -Name Native -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError=true)]
public static extern System.IntPtr GetStdHandle(int nStdHandle);
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError=true)]
public static extern bool GetConsoleMode(System.IntPtr hConsoleHandle, out uint lpMode);
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError=true)]
public static extern bool SetConsoleMode(System.IntPtr hConsoleHandle, uint dwMode);
'@ -ErrorAction Stop
        }
        $STDOUT = -11
        $ENABLE_VT = 0x0004
        $h = [VtHelper.Native]::GetStdHandle($STDOUT)
        $mode = 0
        if ([VtHelper.Native]::GetConsoleMode($h, [ref]$mode)) {
            $null = [VtHelper.Native]::SetConsoleMode($h, ($mode -bor $ENABLE_VT))
            return $true
        }
    } catch { }
    return $false
}

# ---------------------------------------------------------------------
#  Test-Admin  --  is the current session elevated?
# ---------------------------------------------------------------------
function Test-Admin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $pr = New-Object Security.Principal.WindowsPrincipal($id)
        return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false   # non-Windows or restricted -> treat as standard
    }
}

# ---------------------------------------------------------------------
#  Get-EnvInfo  --  gather host facts once (cached in $script:Env)
# ---------------------------------------------------------------------
function Get-EnvInfo {
    $osCaption = $null
    try {
        $osCaption = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).Caption
    } catch {
        $osCaption = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    }
    if ($osCaption) { $osCaption = ($osCaption -replace 'Microsoft ', '').Trim() }

    [PSCustomObject]@{
        Host    = $env:COMPUTERNAME  ; # $null on non-Windows -> filled below
        User    = $env:USERNAME
        OS      = $osCaption
        PSVer   = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
        Edition = $PSVersionTable.PSEdition
        Admin   = (Test-Admin)
    }
}

# ---------------------------------------------------------------------
#  Logging
# ---------------------------------------------------------------------
function Get-LogPath {
    $base = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    $dir  = Join-Path $base 'cyberspell'
    if (-not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    return Join-Path $dir ("log-{0:yyyyMMdd}.log" -f (Get-Date))
}

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    try {
        $line = "{0:HH:mm:ss} [{1}] {2}" -f (Get-Date), $Level, $Message
        Add-Content -Path (Get-LogPath) -Value $line -ErrorAction SilentlyContinue
    } catch { }
}

# ---------------------------------------------------------------------
#  Get-ActivityFrame  --  one frame of the neon scanner shown while a
#  task is still silent. A bright cyan core with a glow that fades
#  through cyan into magenta, over a dim track.
# ---------------------------------------------------------------------
function Get-ActivityFrame {
    param([int]$Pos, [int]$Width = 22)
    $core = [char]0x2588   # full block
    $g3   = [char]0x2593   # dark shade
    $g2   = [char]0x2592   # medium shade
    $g1   = [char]0x2591   # light shade
    $out = ''
    for ($i = 0; $i -lt $Width; $i++) {
        $d = $Pos - $i
        if ($d -lt 0) { $d = -$d }
        if ($d -eq 0) {
            $out += (Paint ([string]$core) 'cyan' -Bold)
        } elseif ($d -eq 1) {
            $out += (Paint ([string]$g3) 'cyan')
        } elseif ($d -eq 2) {
            $out += (Paint ([string]$g2) 'cyanDim')
        } elseif ($d -eq 3) {
            $out += (Paint ([string]$g1) 'magentaDim')
        } else {
            $out += (Paint ([string]$g1) 'dim')
        }
    }
    return $out
}

# ---------------------------------------------------------------------
#  Format-Duration  --  readable elapsed time: "500 ms", "3.2s",
#  "3m 49s". Used by the activity bar and the task result line.
# ---------------------------------------------------------------------
function Format-Duration {
    param([long]$Ms)
    if ($Ms -lt 1000) { return ("{0} ms" -f $Ms) }
    $totalSec = [int][math]::Round($Ms / 1000.0, 0)
    if ($totalSec -lt 60) { return ("{0:N1}s" -f ($Ms / 1000.0)) }
    $m = [int][math]::Floor($totalSec / 60)
    $s = [int]($totalSec % 60)
    return ("{0}m {1:d2}s" -f $m, $s)
}

# ---------------------------------------------------------------------
#  Confirm-Action  --  Yes/No selector, Yes highlighted by default.
#    left / right / up / down / tab  move the selection
#    enter                           accepts what is highlighted
#    y / n                           decide instantly
#    esc                             no
#  Redraws in place with a carriage return, so it works in legacy
#  conhost as well as Windows Terminal. Falls back to Read-Host when
#  console input is redirected.
# ---------------------------------------------------------------------
function Confirm-Action {
    param([string]$Prompt = 'Proceed?', [switch]$DefaultNo)

    $sel = 0                          # 0 = Yes, 1 = No
    if ($DefaultNo) { $sel = 1 }

    $canKey = $true
    try { if ([Console]::IsInputRedirected) { $canKey = $false } } catch { $canKey = $false }

    if (-not $canKey) {
        Write-Host ""
        $hint = '[Y/n]'
        if ($DefaultNo) { $hint = '[y/N]' }
        Write-Host (Paint "  ? $Prompt $hint " 'warn' -Bold) -NoNewline
        $ans = (Read-Host).Trim().ToLower()
        if ([string]::IsNullOrEmpty($ans)) { return (-not $DefaultNo) }
        return ($ans -eq 'y' -or $ans -eq 'yes')
    }

    Write-Host ""
    Set-StatusIdle -Keys $script:StatusKeys.Prompt
    $decided = $false
    $result  = (-not $DefaultNo)

    while (-not $decided) {
        $yesCell = '  Yes  '
        $noCell  = '  No   '
        if ($sel -eq 0) { $yesCell = '[ Yes ]' } else { $noCell = '[ No  ]' }

        $yesPaint = Paint $yesCell 'dim'
        $noPaint  = Paint $noCell  'dim'
        if ($sel -eq 0) { $yesPaint = Paint $yesCell 'cyan' -Bold }
        else            { $noPaint  = Paint $noCell  'magenta' -Bold }

        $line = "`r" + (Paint "  ? $Prompt   " 'warn' -Bold) + $yesPaint + '  ' + $noPaint +
                (Paint '    arrows or y/n, enter confirms' 'dim')
        Write-Host $line -NoNewline

        $k = $null
        try { $k = [Console]::ReadKey($true) } catch { $decided = $true; break }
        $ch = ([string]$k.KeyChar).ToLower()

        if ($ch -eq 'y')                 { $sel = 0; $result = $true;  $decided = $true }
        elseif ($ch -eq 'n')             { $sel = 1; $result = $false; $decided = $true }
        elseif ($k.Key -eq 'Enter')      { $result = ($sel -eq 0);     $decided = $true }
        elseif ($k.Key -eq 'Escape')     { $sel = 1; $result = $false; $decided = $true }
        elseif ($k.Key -eq 'LeftArrow' -or $k.Key -eq 'UpArrow')    { $sel = 0 }
        elseif ($k.Key -eq 'RightArrow' -or $k.Key -eq 'DownArrow') { $sel = 1 }
        elseif ($k.Key -eq 'Tab')        { if ($sel -eq 0) { $sel = 1 } else { $sel = 0 } }
        # anything else: ignore and keep waiting
    }

    # Repaint the final state so the scrollback shows what was chosen.
    $yesCell = '  Yes  '; $noCell = '  No   '
    if ($result) { $yesCell = '[ Yes ]' } else { $noCell = '[ No  ]' }
    $yesPaint = Paint $yesCell 'dim'; $noPaint = Paint $noCell 'dim'
    if ($result) { $yesPaint = Paint $yesCell 'ok' -Bold } else { $noPaint = Paint $noCell 'magenta' -Bold }
    Write-Host ("`r" + (Paint "  ? $Prompt   " 'warn' -Bold) + $yesPaint + '  ' + $noPaint + (' ' * 34))
    return $result
}

# ---------------------------------------------------------------------
#  Invoke-Native  --  run a console tool with NOTHING redirected.
#  Its output goes straight to the console, live and byte for byte,
#  including in-place progress like "Verification 42% complete".
#  This matters because sfc, dism and chkdsk buffer their output (or
#  print nothing at all) when it is captured by a PowerShell pipeline,
#  so these tools must never be piped.
#  Sets $LASTEXITCODE; deliberately returns nothing so no stray value
#  is printed after the tool's own output.
# ---------------------------------------------------------------------
function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [string[]]$Arguments = @()
    )
    if (-not (Get-Command $Exe -ErrorAction SilentlyContinue)) {
        Write-Host (Paint "  '$Exe' was not found on this system." 'err' -Bold)
        $global:LASTEXITCODE = 1
        return
    }
    $p = $null
    try {
        if ($Arguments -and $Arguments.Count -gt 0) {
            $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
        } else {
            $p = Start-Process -FilePath $Exe -NoNewWindow -Wait -PassThru
        }
    } catch {
        Write-Host (Paint "  Could not start '$Exe': $($_.Exception.Message)" 'err')
        $global:LASTEXITCODE = 1
        return
    }
    if ($p) { $global:LASTEXITCODE = $p.ExitCode }
}

# ---------------------------------------------------------------------
#  Invoke-Task  --  run a command scriptblock safely, with logging
#  Returns a result object; never throws to the caller.
# ---------------------------------------------------------------------
# ---------------------------------------------------------------------
#  Test-ActionCancellable  --  can this node run on the cancellable path?
#  Interactive nodes (they prompt mid-run) and redirected-input sessions
#  must use the synchronous path.
# ---------------------------------------------------------------------
function Test-ActionCancellable {
    param($Node)
    if ($Node -and $Node.Interactive) { return $false }
    try { if ([Console]::IsInputRedirected) { return $false } } catch { return $false }
    return $true
}

# ---------------------------------------------------------------------
#  Get-RunnerPreamble  --  script injected into the action runspace so
#  helper functions and theme variables exist there too. Built once,
#  from the live function definitions (always in sync with the source).
# ---------------------------------------------------------------------
function Get-RunnerPreamble {
    if ($script:RunnerPreamble) { return $script:RunnerPreamble }
    $fns = @('Paint', 'Get-VisibleLength', 'Write-Kv', 'Write-Rule',
             'Get-LogPath', 'Write-Log', 'Test-PendingReboot', 'Show-PendingRebootReport',
             'Invoke-Native', 'Format-Duration', 'Get-ActivityFrame')
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('$script:ESC     = $__cspRun.Vars.ESC')
    [void]$sb.AppendLine('$script:UI      = $__cspRun.Vars.UI')
    [void]$sb.AppendLine('$script:Palette = $__cspRun.Vars.Palette')
    [void]$sb.AppendLine('$script:Glyph   = $__cspRun.Vars.Glyph')
    [void]$sb.AppendLine('$script:Env     = $__cspRun.Vars.Env')
    [void]$sb.AppendLine('$script:App     = $__cspRun.Vars.App')
    foreach ($f in $fns) {
        $fi = Get-Item ("function:\" + $f) -ErrorAction SilentlyContinue
        if ($fi) { [void]$sb.AppendLine("function $f { $($fi.Definition) }") }
    }
    $script:RunnerPreamble = $sb.ToString()
    return $script:RunnerPreamble
}

# ---------------------------------------------------------------------
#  Invoke-Task  --  safe task runner.
#  Cancellable path: the action runs in a runspace that SHARES this
#  console host (output streams live), while this thread watches the
#  keyboard for ESC / X and can stop the task and return to the menu.
#  Synchronous path: interactive actions + redirected input.
#  Never throws; logs; returns a result object.
# ---------------------------------------------------------------------
function Invoke-Task {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action,
        $Node = $null
    )
    Write-Log "TASK START: $Name"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $ok = $true; $err = $null; $cancelled = $false; $exit = 0

    if (-not (Test-ActionCancellable $Node)) {
        # ---- synchronous path -----------------------------------------
        $global:LASTEXITCODE = 0
        try {
            # Stream everything the action emits straight to the host.
            & $Action $Node | Out-Host
        } catch {
            $ok = $false; $err = $_
            Write-Host ""
            Write-Host (Paint "  [x] Error: $($_.Exception.Message)" 'err' -Bold)
            Write-Log "TASK ERROR: $Name -> $($_.Exception.Message)" 'ERROR'
        }
        $exit = $global:LASTEXITCODE
    } else {
        # ---- cancellable path -----------------------------------------
        $t0 = Get-Date
        $rs = $null; $ps = $null
        try {
            $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($Host)
            $rs.Open()
            $payload = @{
                ActionText = $Action.ToString()
                Node       = $Node
                Vars       = @{
                    ESC = $script:ESC; UI = $script:UI; Palette = $script:Palette
                    Glyph = $script:Glyph; Env = $script:Env; App = $script:App
                }
            }
            $rs.SessionStateProxy.SetVariable('__cspRun', $payload)
            $ps = [PowerShell]::Create()
            $ps.Runspace = $rs
            $body = (Get-RunnerPreamble) + "`n" +
                    '$__act = [scriptblock]::Create($__cspRun.ActionText)' + "`n" +
                    '& $__act $__cspRun.Node | Out-Host' + "`n" +
                    '$global:LASTEXITCODE'
            [void]$ps.AddScript($body)
            $h = $ps.BeginInvoke()

            # -- activity: the reserved bottom row shows a scanner and the
            #    elapsed time for as long as the task actually runs. It sits
            #    outside the scrolling region, so it cannot be overwritten by
            #    the task's output and cannot bleed into it - which is what
            #    an in-line indicator could never guarantee, especially
            #    against tools like sfc that redraw with carriage returns.
            $barSeq = @()
            for ($i = 0; $i -lt 18; $i++) { $barSeq += $i }
            for ($i = 16; $i -gt 0; $i--) { $barSeq += $i }
            $fi = 0
            Set-StatusBusy -Pos 0 -Ms 0

            $pollKeys = $true
            while (-not $h.IsCompleted) {
                if ($pollKeys) {
                    try {
                        while ([Console]::KeyAvailable) {
                            $k = [Console]::ReadKey($true)
                            if ($k.Key -eq 'Escape' -or $k.KeyChar -eq 'x' -or $k.KeyChar -eq 'X') {
                                $cancelled = $true; break
                            }
                        }
                    } catch { $pollKeys = $false }
                }
                if ($cancelled) { break }
                $fi++
                Set-StatusBusy -Pos $barSeq[$fi % $barSeq.Count] -Ms $sw.ElapsedMilliseconds
                Start-Sleep -Milliseconds 110
            }

            if ($cancelled) {
                Write-Host ""
                Write-Host (Paint "  [!] stop requested - terminating task..." 'warn' -Bold)
                [void]$ps.BeginStop($null, $null)
                $deadline = (Get-Date).AddSeconds(3)
                while ((Get-Date) -lt $deadline -and $ps.InvocationStateInfo.State -eq 'Running') {
                    Start-Sleep -Milliseconds 100
                }
                # Best-effort: also kill native child processes the task started
                # (ping.exe, tracert.exe, dism.exe, ...) so nothing keeps running.
                try {
                    $kids = Get-CimInstance Win32_Process -Filter "ParentProcessId=$PID" -ErrorAction Stop
                    foreach ($kp in $kids) {
                        if ($kp.CreationDate -and $kp.CreationDate -gt $t0) {
                            Stop-Process -Id $kp.ProcessId -Force -ErrorAction SilentlyContinue
                        }
                    }
                } catch { }
                Write-Log "TASK CANCELLED: $Name" 'WARN'
            } else {
                try {
                    $out = $ps.EndInvoke($h)
                    if ($out -and $out.Count -gt 0) {
                        $last = $out[$out.Count - 1]
                        if ($last -is [int]) { $exit = $last }
                    }
                } catch {
                    $ok = $false; $err = $_
                    Write-Host ""
                    Write-Host (Paint "  [x] Error: $($_.Exception.Message)" 'err' -Bold)
                    Write-Log "TASK ERROR: $Name -> $($_.Exception.Message)" 'ERROR'
                }
                if ($ps.Streams.Error.Count -gt 0) {
                    foreach ($e in $ps.Streams.Error) {
                        Write-Host (Paint "  [x] $($e.ToString())" 'err')
                    }
                }
            }
        } catch {
            # Runner infrastructure failed -> fall back to synchronous execution.
            Write-Log "RUNNER FALLBACK: $Name -> $($_.Exception.Message)" 'WARN'
            $global:LASTEXITCODE = 0
            try {
                & $Action $Node | Out-Host
            } catch {
                $ok = $false; $err = $_
                Write-Host ""
                Write-Host (Paint "  [x] Error: $($_.Exception.Message)" 'err' -Bold)
                Write-Log "TASK ERROR: $Name -> $($_.Exception.Message)" 'ERROR'
            }
            $exit = $global:LASTEXITCODE
        } finally {
            if ($ps) { try { $ps.Dispose() } catch { } }
            if ($rs) { try { $rs.Dispose() } catch { } }
        }
    }

    $sw.Stop()
    # The busy state belongs to the task; hand the row back the moment it ends
    # so the bar can never be left frozen on "RUNNING".
    Set-StatusIdle
    Write-Log ("TASK END: {0} ({1} ms, ok={2}, exit={3}, cancelled={4})" -f $Name, $sw.ElapsedMilliseconds, $ok, $exit, $cancelled)
    return [PSCustomObject]@{
        Name      = $Name
        Success   = $ok
        Error     = $err
        Ms        = $sw.ElapsedMilliseconds
        ExitCode  = $exit
        Cancelled = $cancelled
    }
}

# ---------------------------------------------------------------------
#  Initialize-Environment  --  called once at startup
# ---------------------------------------------------------------------
function Initialize-Environment {
    $script:UI.Ansi = Enable-VirtualTerminal
    try {
        $wsWidth = $Host.UI.RawUI.WindowSize.Width
        if ($wsWidth -and $wsWidth -gt 40) { $script:UI.Width = [Math]::Min($wsWidth - 2, 100) }
    } catch { }
    $script:Env = Get-EnvInfo
    if (-not $script:Env.Host) { $script:Env.Host = [System.Net.Dns]::GetHostName() }
    Write-Log "===== Cyberspell Toolkit v$($script:App.Version) started (Admin=$($script:Env.Admin), PS=$($script:Env.PSVer)) ====="
    # Reserve the bottom row for the status line (no-op without ANSI).
    $null = Enable-StatusBar
}
