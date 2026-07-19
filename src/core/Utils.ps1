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
#  Confirm-Action  --  Y/N prompt (default No unless -DefaultYes)
# ---------------------------------------------------------------------
function Confirm-Action {
    param([string]$Prompt = 'Proceed?', [switch]$DefaultYes)
    $hint = if ($DefaultYes) { '[Y/n]' } else { '[y/N]' }
    Write-Host ""
    Write-Host (Paint "  ? $Prompt $hint " 'warn' -Bold) -NoNewline
    $ans = (Read-Host).Trim().ToLower()
    if ([string]::IsNullOrEmpty($ans)) { return [bool]$DefaultYes }
    return ($ans -eq 'y' -or $ans -eq 'yes')
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
             'Get-LogPath', 'Write-Log', 'Test-PendingReboot', 'Show-PendingRebootReport')
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
                Start-Sleep -Milliseconds 80
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
}
