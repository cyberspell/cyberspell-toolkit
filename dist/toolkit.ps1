# =====================================================================
#  Cyberspell Toolkit v0.1.2  --  compiled build (do not edit; edit src/ instead)
#  built: 2026-08-09 11:18:02
#  cyberspell // https://github.com/cyberspell/cyberspell-toolkit
#  created with <3 by JP (https://jp.cyberspell.cloud) - for all my fellow IT engineers
# =====================================================================

# ----- src\config\Theme.ps1 -----
# =====================================================================
#  Theme.ps1  --  Cyberpunk look & feel (colors, glyphs, banner)
#  cyberspell // toolkit
#  Compatible with Windows PowerShell 5.1 and PowerShell 7+
# =====================================================================

# ESC char (use [char]27 for 5.1 compatibility -- backtick-e is 7+ only)
$script:ESC = [char]27

# UI state. Ansi is refined at startup by Initialize-Environment (Utils.ps1).
if (-not $script:UI) {
    $script:UI = @{
        Ansi  = $true          # emit truecolor escape sequences
        Width = 78             # content width; refreshed at runtime
    }
}

# ---- Palette (truecolor "R;G;B") ------------------------------------
$script:Palette = @{
    cyan       = '0;240;255'     # primary
    cyanDim    = '0;150;170'
    magenta    = '255;45;160'    # accent
    magentaDim = '170;40;120'
    text       = '220;225;235'
    dim        = '120;125;145'
    ok         = '60;235;140'    # success / green
    warn       = '255;190;70'    # warning / amber
    err        = '255;80;100'    # error / red
    white      = '245;247;252'
}

# ---- Box-drawing glyphs (rounded) -----------------------------------
$script:Glyph = @{
    tl = [char]0x256D; tr = [char]0x256E     # rounded corners  (top L/R)
    bl = [char]0x2570; br = [char]0x256F     #                  (btm L/R)
    h  = [char]0x2500; v  = [char]0x2502     # horizontal / vertical
    lt = [char]0x251C; rt = [char]0x2524     # tee left / right
    dot   = [char]0x25CF                     # filled circle status dot
    arrow = [char]0x203A                     # breadcrumb chevron
    bolt  = [char]0x26A1                     # lightning
}

# ---------------------------------------------------------------------
#  Paint  --  wrap text in a truecolor SGR sequence (or pass through)
# ---------------------------------------------------------------------
function Paint {
    param(
        # AllowEmptyString matters: a mandatory [string] rejects '' outright,
        # which would throw from any caller that paints a computed or padded
        # value that happens to be empty.
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Color = 'text',
        [switch]$Bold
    )
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    if (-not $script:UI.Ansi) { return $Text }
    $rgb = $script:Palette[$Color]
    if (-not $rgb) { $rgb = $script:Palette['text'] }
    $b = if ($Bold) { '1;' } else { '' }
    return "$script:ESC[${b}38;2;${rgb}m$Text$script:ESC[0m"
}

# Visible length of a string with ANSI stripped (for padding math)
function Get-VisibleLength {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    $stripped = [regex]::Replace($Text, "$script:ESC\[[0-9;]*m", '')
    return $stripped.Length
}

# =====================================================================
#  SCREEN ENGINE
#  A single row at the bottom of the window is reserved with a terminal
#  scrolling region (DECSTBM). Everything the toolkit or a native tool
#  prints scrolls ABOVE it, so the status line can never be overwritten
#  and never bleeds into command output. All of it is pure ANSI, with no
#  cursor-position queries, so it behaves the same on Windows Terminal,
#  Cursor save/restore uses ESC 7 / ESC 8 (DECSC/DECRC) rather than
#  CSI s / CSI u: the CSI pair is a non-standard SCO variant that several
#  terminals ignore, which would strand the cursor on the reserved row and
#  send every following line of output there.
#  legacy conhost with VT enabled, and Unix terminals.
#  If ANSI is unavailable the whole layer turns into no-ops and the UI
#  falls back to printing an inline footer.
# =====================================================================
$script:Screen = @{
    Enabled = $false
    Rows    = 0
    Cols    = 0
    Keys    = ''          # remembered idle hint, so any caller can restore it
}

function Get-ScreenSize {
    $r = 24; $c = 80
    try { $r = [Console]::WindowHeight; $c = [Console]::WindowWidth } catch { }
    if ($r -lt 1) { $r = 24 }
    if ($c -lt 1) { $c = 80 }
    return @{ Rows = $r; Cols = $c }
}

function Enable-StatusBar {
    if (-not $script:UI.Ansi) { return $false }
    $sz = Get-ScreenSize
    if ($sz.Rows -lt 10) { return $false }      # too short to give a row away
    $script:Screen.Rows = $sz.Rows
    $script:Screen.Cols = $sz.Cols
    $e = $script:ESC
    # scrolling region = row 1 .. second-to-last row
    Write-Host ($e + '[1;' + ($sz.Rows - 1) + 'r') -NoNewline
    Write-Host ($e + '[H') -NoNewline
    $script:Screen.Enabled = $true
    return $true
}

function Disable-StatusBar {
    if (-not $script:Screen.Enabled) { return }
    $e = $script:ESC
    $r = $script:Screen.Rows
    # Clear the reserved row, release the region, and only THEN restore the
    # cursor. Order matters: resetting the scrolling region homes the cursor
    # to row 1 (DECSTBM does this by definition), so restoring first would be
    # undone and everything printed afterwards - including the shell prompt
    # we hand back to - would start at the top of the screen.
    Write-Host ($e + '7' + $e + '[' + $r + ';1H' + $e + '[2K' + $e + '[r' + $e + '8') -NoNewline
    $script:Screen.Enabled = $false
}

# Both arguments are already painted; visible width is measured with
# Get-VisibleLength so ANSI codes do not break the padding.
function Write-StatusBar {
    param([string]$Left = '', [string]$Right = '')
    if (-not $script:Screen.Enabled) { return }

    # A resized window must not strand the bar on a row that no longer exists.
    $sz = Get-ScreenSize
    if ($sz.Rows -ne $script:Screen.Rows -or $sz.Cols -ne $script:Screen.Cols) {
        $script:Screen.Rows = $sz.Rows
        $script:Screen.Cols = $sz.Cols
        if ($sz.Rows -lt 10) { Disable-StatusBar; return }
        Write-Host ($script:ESC + '[1;' + ($sz.Rows - 1) + 'r') -NoNewline
    }

    $rows = $script:Screen.Rows
    $cols = $script:Screen.Cols
    $lv = Get-VisibleLength $Left
    $rv = Get-VisibleLength $Right
    # On a narrow window the key hints matter more than the branding, so the
    # right-hand side is dropped first. Dropping rather than truncating keeps
    # the line from wrapping, which would push the reserved row off-screen.
    if (($cols - 2 - $lv - $rv) -lt 1) { $Right = ''; $rv = 0 }
    if (($cols - 2 - $lv) -lt 1)       { $Left  = ''; $lv = 0 }
    $gap = $cols - 2 - $lv - $rv
    if ($gap -lt 1) { $gap = 1 }
    $e = $script:ESC
    $body = ' ' + $Left + (' ' * $gap) + $Right + ' '
    Write-Host ($e + '7' + $e + '[' + $rows + ';1H' + $e + '[2K' + $body + $e + '8') -NoNewline
}

# ---------------------------------------------------------------------
#  Show-Banner  --  framed cyberpunk header
# ---------------------------------------------------------------------
function Show-Banner {
    $g = $script:Glyph
    $w = [Math]::Max(60, [Math]::Min($script:UI.Width, 100))
    $inner = $w - 2

    $top = "$($g.tl)$([string]$g.h * $inner)$($g.tr)"
    $bot = "$($g.bl)$([string]$g.h * $inner)$($g.br)"

    # Title line:  ' <bolt> C Y B E R S P E L L                 v<version> '
    $bannerTitle = $script:App.Banner
    if (-not $bannerTitle) { $bannerTitle = $script:App.Name }
    $name    = ($bannerTitle.ToUpper().ToCharArray() -join ' ')
    $left    = " $($g.bolt) $name"
    $right   = "v$($script:App.Version) "
    $padTitle = $inner - $left.Length - $right.Length
    if ($padTitle -lt 1) { $padTitle = 1 }
    $titleRaw = "$left$([string]' ' * $padTitle)$right"

    # Subtitle line
    $subRaw = " // $($script:App.Tagline)"
    $subRaw = $subRaw.PadRight($inner)

    Write-Host ""
    Write-Host (Paint $top 'cyan')
    Write-Host (Paint $g.v 'cyan') -NoNewline
    Write-Host (Paint $titleRaw 'cyan' -Bold) -NoNewline
    Write-Host (Paint $g.v 'cyan')
    Write-Host (Paint $g.v 'cyan') -NoNewline
    Write-Host (Paint $subRaw 'magenta') -NoNewline
    Write-Host (Paint $g.v 'cyan')
    Write-Host (Paint $bot 'cyan')
}


# ----- src\core\Utils.ps1 -----
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


# ----- src\core\UI.ps1 -----
# =====================================================================
#  UI.ps1  --  Screen rendering primitives + input
#  cyberspell // toolkit
# =====================================================================

# ---------------------------------------------------------------------
#  Read-SingleKey  --  robust key input (single keypress, host fallback)
#  Returns: 'BACK' | 'ESC' | 'ENTER' | 'R' | <upper char> | typed line
# ---------------------------------------------------------------------
function Read-SingleKey {
    param([switch]$Line)   # -Line forces line input (for >9 item menus)
    if (-not $Line) {
        try {
            if (-not [Console]::IsInputRedirected) {
                $k = [Console]::ReadKey($true)
                switch ($k.Key) {
                    'Backspace' { return 'BACK' }
                    'LeftArrow' { return 'BACK' }
                    'Escape'    { return 'ESC' }
                    'Enter'     { return 'ENTER' }
                    'F5'        { return 'R' }
                    default {
                        if ($k.KeyChar) { return ([string]$k.KeyChar).ToUpper() }
                        return ''
                    }
                }
            }
        } catch { }
    }
    $ln = (Read-Host).Trim()
    if ($ln -eq '') { return 'ENTER' }
    return $ln.ToUpper()
}

# ---------------------------------------------------------------------
#  Write-Rule  --  faint horizontal divider
# ---------------------------------------------------------------------
function Write-Rule {
    param([string]$Color = 'cyanDim')
    $w = [Math]::Max(60, [Math]::Min($script:UI.Width, 100))
    Write-Host ("  " + (Paint ([string]$script:Glyph.h * ($w - 2)) $Color))
}

# ---------------------------------------------------------------------
#  Show-Status  --  elevation badge + host facts
# ---------------------------------------------------------------------
function Show-Status {
    $e = $script:Env
    if ($e.Admin) {
        $badge = Paint "$($script:Glyph.dot) ADMIN" 'ok' -Bold
    } else {
        $badge = Paint "$($script:Glyph.dot) STANDARD" 'warn' -Bold
    }
    $sep  = Paint '   ' 'dim'
    $hostLbl = Paint "host " 'dim'; $hostVal = Paint $e.Host 'cyanDim'
    $os   = Paint $e.OS 'dim'
    $ps   = Paint "PS $($e.PSVer)" 'dim'
    Write-Host ("  $badge$sep$hostLbl$hostVal$sep$os$sep$ps")
}

# ---------------------------------------------------------------------
#  Show-Breadcrumb  --  root > Windows > Network
# ---------------------------------------------------------------------
function Show-Breadcrumb {
    param([string[]]$Path)
    $chev = Paint " $($script:Glyph.arrow) " 'dim'
    $parts = @()
    for ($i = 0; $i -lt $Path.Count; $i++) {
        if ($i -eq $Path.Count - 1) {
            $parts += (Paint $Path[$i] 'cyan' -Bold)
        } elseif ($i -eq 0) {
            $parts += (Paint $Path[$i] 'magenta')
        } else {
            $parts += (Paint $Path[$i] 'dim')
        }
    }
    Write-Host ("  " + ($parts -join $chev))
}

# =====================================================================
#  STATUS STATES
#  Every screen in the toolkit sets one of these, so the bottom row
#  always says what the current keys are. Set-StatusIdle remembers the
#  hint, so anything that temporarily shows a busy state can restore the
#  previous one without knowing what it was.
# =====================================================================
$script:StatusKeys = @{
    Root   = '[1-9/a-z] select    [r] refresh    [q] quit'
    Menu   = '[1-9/a-z] select    [b] back    [r] refresh    [q] quit'
    Action = '[any key] continue'
    Finder = 'type to filter    [up/dn] move    [enter] copy    [esc] back'
    Prompt = '[left/right] choose    [enter] confirm    [y/n] decide'
}

function Set-StatusIdle {
    param([string]$Keys)
    if ($PSBoundParameters.ContainsKey('Keys') -and $Keys -ne '') {
        $script:Screen.Keys = $Keys
    }
    $brand = "$($script:App.Name) v$($script:App.Version)"
    Write-StatusBar -Left (Paint $script:Screen.Keys 'dim') -Right (Paint $brand 'magentaDim')
}

function Set-StatusBusy {
    param([int]$Pos, [long]$Ms, [string]$Label = 'RUNNING')
    $bar = Get-ActivityFrame -Pos $Pos -Width 18
    $left = (Paint '[' 'magenta' -Bold) + $bar + (Paint ']' 'magenta' -Bold) +
            (Paint ("  $Label  ") 'magenta' -Bold) + (Paint (Format-Duration $Ms) 'cyan' -Bold)
    Write-StatusBar -Left $left -Right (Paint '[esc] stop task' 'warn' -Bold)
}

# ---------------------------------------------------------------------
#  Show-Footer  --  keybind hints
# ---------------------------------------------------------------------
function Show-Footer {
    param([switch]$IsRoot)
    $k = { param($x) Paint $x 'cyan' -Bold }
    $t = { param($x) Paint $x 'dim' }
    $bits = @()
    if (-not $IsRoot) { $bits += "$(& $k '[B]') $(& $t 'back')" }
    $bits += "$(& $k '[R]') $(& $t 'refresh')"
    $bits += "$(& $k '[Q]') $(& $t 'quit')"
    Write-Host ("  " + ($bits -join (Paint '    ' 'dim')))
}

# ---------------------------------------------------------------------
#  Show-MenuScreen  --  full frame for one menu node
#  $KeyMap = ordered array of [PSCustomObject]@{ Key; Node }
# ---------------------------------------------------------------------
function Show-MenuScreen {
    param(
        [Parameter(Mandatory)]$Node,
        [Parameter(Mandatory)][string[]]$Path,
        [Parameter(Mandatory)]$KeyMap,
        [switch]$IsRoot
    )
    Clear-Host
    Show-Banner
    Show-Status
    Write-Host ""
    Show-Breadcrumb -Path $Path
    Write-Rule
    Write-Host ""

    # Alignment: pad labels to the widest in this menu
    $maxLabel = 12
    foreach ($row in $KeyMap) {
        if ($row.Node.Label.Length -gt $maxLabel) { $maxLabel = $row.Node.Label.Length }
    }

    foreach ($row in $KeyMap) {
        $n     = $row.Node
        $keyTx = Paint ("[{0}]" -f $row.Key) 'cyan' -Bold
        $label = Paint ($n.Label.PadRight($maxLabel + 2)) 'white'
        $desc  = if ($n.Desc) { Paint $n.Desc 'dim' } else { '' }

        $suffix = ''
        if ($n.Type -eq 'menu') {
            $suffix = Paint "  $($script:Glyph.arrow)" 'magenta'
        } elseif ($n.Admin -and -not $script:Env.Admin) {
            $suffix = Paint "  (needs admin)" 'warn'
        }
        Write-Host ("  $keyTx  $label$desc$suffix")
    }

    Write-Host ""
    Write-Rule
    if ($script:Screen.Enabled) {
        $keys = $script:StatusKeys.Menu
        if ($IsRoot) { $keys = $script:StatusKeys.Root }
        Set-StatusIdle -Keys $keys
    } else {
        Show-Footer -IsRoot:$IsRoot
    }
    Write-Host ""
    $prompt = Paint "  $($script:Glyph.arrow) select" 'cyan' -Bold
    Write-Host "$prompt " -NoNewline
}

# ---------------------------------------------------------------------
#  Wait-AnyKey  --  pause after an action
# ---------------------------------------------------------------------
function Wait-AnyKey {
    Write-Host ""
    Write-Host (Paint "  $($script:Glyph.arrow) press any key to continue" 'dim')
    [void](Read-SingleKey)
}

# ---------------------------------------------------------------------
#  Write-Kv  --  aligned "key : value" line for summary screens
# ---------------------------------------------------------------------
function Write-Kv {
    param([string]$Key, $Value, [string]$ValueColor = 'white')
    Write-Host ("  " + (Paint ($Key.PadRight(18)) 'cyanDim') + (Paint ([string]$Value) $ValueColor))
}

# ---------------------------------------------------------------------
#  Show-ActionHeader  --  small banner shown while an action runs
# ---------------------------------------------------------------------
function Show-ActionHeader {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host ("  " + (Paint "$($script:Glyph.bolt) $Title" 'cyan' -Bold))
    Write-Rule
    Write-Host ""
}


# ----- src\core\Menu.ps1 -----
# =====================================================================
#  Menu.ps1  --  Data-driven navigation engine
#  cyberspell // toolkit
# =====================================================================

# Single-key pool for item selection: digits 1-9, then letters
# EXCLUDING B / Q / R (reserved for Back / Quit / Refresh).
$script:KeyPool = @('1','2','3','4','5','6','7','8','9') + `
    (65..90 | ForEach-Object { [string][char]$_ } | Where-Object { $_ -notin @('B', 'Q', 'R') })

# ---------------------------------------------------------------------
#  New-KeyMap  --  assign selection keys to a node's items
# ---------------------------------------------------------------------
function New-KeyMap {
    param([Parameter(Mandatory)]$Node)
    $map = @()
    $i = 0
    foreach ($item in $Node.Items) {
        if ($i -ge $script:KeyPool.Count) { break }
        $map += [PSCustomObject]@{ Key = $script:KeyPool[$i]; Node = $item }
        $i++
    }
    return $map
}

# ---------------------------------------------------------------------
#  Invoke-Action  --  admin-gate, confirm, run, report, pause
# ---------------------------------------------------------------------
function Invoke-Action {
    param([Parameter(Mandatory)]$Node)

    if ($Node.Admin -and -not $script:Env.Admin) {
        Show-ActionHeader $Node.Label
        Write-Host (Paint "  This task requires an elevated (Administrator) session." 'warn' -Bold)
        Write-Host ""
        Write-Host (Paint "  Close this window, start PowerShell as Administrator," 'dim')
        Write-Host (Paint "  then load the toolkit again." 'dim')
        Set-StatusIdle -Keys $script:StatusKeys.Action
    Wait-AnyKey
        return
    }

    if ($Node.Confirm) {
        Show-ActionHeader $Node.Label
        if ($Node.Warning) { Write-Host (Paint "  ! $($Node.Warning)" 'warn') ; Write-Host "" }
        if (-not (Confirm-Action "Run this task now?")) {
            Write-Host (Paint "  cancelled." 'dim')
            Wait-AnyKey
            return
        }
        Write-Host ""
    } else {
        Show-ActionHeader $Node.Label
    }


    $r = Invoke-Task -Name $Node.Label -Action $Node.Action -Node $Node

    # Quiet nodes are self-contained panes: they draw their own screen and
    # handle their own exit, so a result line and a pause would be noise.
    if ($Node.Quiet -and $r.Success -and -not $r.Cancelled) { return }

    Write-Host ""
    if ($r.Cancelled) {
        Write-Host (Paint ("  [!] stopped by user after {0}" -f (Format-Duration $r.Ms)) 'warn' -Bold)
    } elseif (-not $r.Success) {
        Write-Host (Paint "  [x] finished with errors (see message above)" 'err' -Bold)
    } elseif ($r.ExitCode -ne 0) {
        Write-Host (Paint ("  [!] completed in {0} (exit code {1})" -f (Format-Duration $r.Ms), $r.ExitCode) 'warn' -Bold)
    } else {
        Write-Host (Paint "  [ok] completed in $(Format-Duration $r.Ms)" 'ok' -Bold)
    }
    Wait-AnyKey
}

# ---------------------------------------------------------------------
#  Start-Menu  --  main interactive loop
# ---------------------------------------------------------------------
function Start-Menu {
    param([Parameter(Mandatory)]$Root)

    $stack  = @($Root)
    $labels = @($Root.Label)

    while ($true) {
        $current = $stack[-1]
        $isRoot  = ($stack.Count -eq 1)
        $keymap  = New-KeyMap -Node $current

        Show-MenuScreen -Node $current -Path $labels -KeyMap $keymap -IsRoot:$isRoot
        $choice = Read-SingleKey

        switch ($choice) {
            'Q'    { if (Confirm-Action "Quit Cyberspell Toolkit?") { Show-Goodbye; return } }
            'ESC'  { if (Confirm-Action "Quit Cyberspell Toolkit?") { Show-Goodbye; return } }
            'R'    { continue }          # redraw
            'ENTER'{ continue }          # redraw
            'BACK' {
                if (-not $isRoot) {
                    $stack  = @($stack[0..($stack.Count - 2)])
                    $labels = @($labels[0..($labels.Count - 2)])
                }
            }
            'B' {
                if (-not $isRoot) {
                    $stack  = @($stack[0..($stack.Count - 2)])
                    $labels = @($labels[0..($labels.Count - 2)])
                }
            }
            default {
                $hit = $keymap | Where-Object { $_.Key -eq $choice } | Select-Object -First 1
                if ($hit) {
                    $node = $hit.Node
                    if ($node.Type -eq 'menu') {
                        $stack  += $node
                        $labels += $node.Label
                    } elseif ($node.Type -eq 'action') {
                        Invoke-Action -Node $node
                    }
                }
                # unknown key -> loop redraws
            }
        }
    }
}

# ---------------------------------------------------------------------
#  Show-Goodbye
# ---------------------------------------------------------------------
function Show-Goodbye {
    # Hand the terminal back BEFORE the farewell. With the reserved row
    # released first, everything below is ordinary output and the shell
    # prompt lands underneath it. Releasing it afterwards would home the
    # cursor and the prompt would be drawn over these lines.
    Disable-StatusBar
    Clear-Host
    Write-Host ""
    Write-Host ("  " + (Paint "$($script:Glyph.bolt) cyberspell toolkit " 'cyan' -Bold) + (Paint "// session closed" 'magenta'))
    Write-Host ("  " + (Paint "logs: $(Get-LogPath)" 'dim'))
    Write-Host ""
    Write-Host ("  " + (Paint "created with $([char]0x2665) by $($script:App.Author)" 'magenta') + (Paint " - for all my fellow IT engineers" 'dim'))
    Write-Host ""
}


# ----- src\modules\windows\Windows.ps1 -----
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
        Label = 'Disk & storage'; Desc = 'temp cleanup, space, health, chkdsk'; Type = 'menu'
        Items = @(
            @{
                Label = 'Clear user TEMP'; Desc = 'purge %TEMP% for the current user'; Type = 'action'
                Confirm = $true
                Warning = 'Deletes the contents of your user TEMP folder. Files locked by running apps are skipped automatically, and the toolkit''s own log folder is preserved.'
                Action = {
                    $t = $env:TEMP
                    if (-not $t -or -not (Test-Path $t)) {
                        Write-Host (Paint "  TEMP folder not found." 'err'); return
                    }
                    $before = (Get-ChildItem $t -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
                    Get-ChildItem $t -Force -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -ne 'cyberspell' } |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    $after = (Get-ChildItem $t -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($null -eq $before) { $before = 0 }
                    if ($null -eq $after)  { $after = 0 }
                    $freed = [math]::Max(0, [math]::Round(($before - $after) / 1MB, 1))
                    Write-Kv 'path'  $t 'cyanDim'
                    Write-Kv 'freed' ("{0} MB" -f $freed) 'ok'
                    Write-Host ""
                    Write-Host (Paint "  Locked files were skipped - that is normal and safe." 'dim')
                }
            },
            @{
                Label = 'Clear system TEMP'; Desc = 'purge C:\Windows\Temp (machine-wide)'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Deletes the contents of C:\Windows\Temp. Files in use by Windows or services are skipped automatically.'
                Action = {
                    $t = Join-Path $env:SystemRoot 'Temp'
                    if (-not (Test-Path $t)) {
                        Write-Host (Paint "  $t not found." 'err'); return
                    }
                    $before = (Get-ChildItem $t -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
                    Get-ChildItem $t -Force -ErrorAction SilentlyContinue |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    $after = (Get-ChildItem $t -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($null -eq $before) { $before = 0 }
                    if ($null -eq $after)  { $after = 0 }
                    $freed = [math]::Max(0, [math]::Round(($before - $after) / 1MB, 1))
                    Write-Kv 'path'  $t 'cyanDim'
                    Write-Kv 'freed' ("{0} MB" -f $freed) 'ok'
                    Write-Host ""
                    Write-Host (Paint "  Locked files were skipped - that is normal and safe." 'dim')
                }
            },
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
                Action = { Invoke-Native 'chkdsk.exe' @('C:') }
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
                Action = { Invoke-Native 'sfc.exe' @('/verifyonly') }
            },
            @{
                Label = 'SFC scan & repair'; Desc = 'sfc /scannow'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Scans and repairs protected system files. Can take 10-30 minutes - do not close the window.'
                Action = { Invoke-Native 'sfc.exe' @('/scannow') }
            },
            @{
                Label = 'DISM check health'; Desc = 'quick component-store flag check'; Type = 'action'
                Admin = $true
                Action = { Invoke-Native 'dism.exe' @('/online', '/cleanup-image', '/checkhealth') }
            },
            @{
                Label = 'DISM scan health'; Desc = 'deeper scan (read-only, slower)'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Read-only but can take 10-20 minutes.'
                Action = { Invoke-Native 'dism.exe' @('/online', '/cleanup-image', '/scanhealth') }
            },
            @{
                Label = 'DISM restore health'; Desc = 'repair the component store'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Repairs the Windows image, downloading files from Windows Update if needed. Can take a LONG time. Typical order: run this, then SFC /scannow.'
                Action = { Invoke-Native 'dism.exe' @('/online', '/cleanup-image', '/restorehealth') }
            },
            @{
                Label = 'Component store cleanup'; Desc = 'reclaim WinSxS space'; Type = 'action'
                Admin = $true; Confirm = $true
                Warning = 'Cleans up superseded components. Safe, but can take a while and older updates can no longer be uninstalled.'
                Action = { Invoke-Native 'dism.exe' @('/online', '/cleanup-image', '/startcomponentcleanup') }
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
        Label = 'Enterprise & identity'; Desc = 'domain, Entra ID join, GPO, time, Intune'; Type = 'menu'
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
                Action = { Invoke-Native 'gpupdate.exe' @('/force') }
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
                    Invoke-Native 'mdmdiagnosticstool.exe' @('-area', 'DeviceEnrollment;DeviceProvisioning;Autopilot', '-zip', $zip)
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
            (Get-WinCheatSheetMenu),
            (Get-WinQuickLaunchMenu)
        )
    }
}


# ----- src\modules\windows\CheatSheet.ps1 -----
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


# ----- src\main.ps1 -----
# =====================================================================
#  main.ps1  --  App metadata, root menu, entrypoint
#  cyberspell // toolkit
#
#  This file DEFINES the app but does NOT auto-run it, so it is safe to
#  dot-source. Start-App is invoked by Start-Dev.ps1 (dev) and appended
#  by build/Compile.ps1 (release single-file).
# =====================================================================

# ---- Application metadata (edit these to rebrand) -------------------
$script:App = @{
    Name    = 'Cyberspell Toolkit'
    Banner  = 'Cyberspell'                # big banner title (spaced caps)
    Tagline = 'endpoint troubleshooting toolkit'
    Brand   = 'cyberspell'
    Author  = 'JP'
    Site    = 'https://jp.cyberspell.cloud'
    Version = '0.1.2'
    Repo    = 'https://github.com/cyberspell/cyberspell-toolkit'
}

# ---- About screen ---------------------------------------------------
function Get-AboutNode {
    @{
        Label = 'About'; Desc = 'version, links, disclaimer'; Type = 'action'
        Action = {
            Write-Kv 'Name'     "$($script:App.Name)  v$($script:App.Version)"
            Write-Kv 'Author'   "$($script:App.Author)  ($($script:App.Site))"
            Write-Kv 'By'       $script:App.Brand
            Write-Kv 'Repo'     $script:App.Repo
            Write-Kv 'Logs'     (Get-LogPath)
            Write-Kv 'Host'     "$($script:Env.Host)  ($($script:Env.OS))"
            Write-Kv 'Elevated' $(if ($script:Env.Admin) { 'yes' } else { 'no' }) $(if ($script:Env.Admin) { 'ok' } else { 'warn' })
            Write-Host ""
            Write-Host (Paint "  A menu-driven wrapper around standard Windows" 'dim')
            Write-Host (Paint "  troubleshooting commands. Read-only tasks are safe;" 'dim')
            Write-Host (Paint "  state-changing tasks always ask for confirmation." 'dim')
            Write-Host ""
            Write-Host ("  " + (Paint "created with $([char]0x2665) by $($script:App.Author)" 'magenta' -Bold) + (Paint " - for all my fellow IT engineers" 'dim'))
        }
    }
}

# ---- Coming-soon placeholder (for OSes not yet built) ---------------
function New-ComingSoonNode {
    param([string]$Label, [string]$Desc)
    @{
        Label = $Label; Desc = $Desc; Type = 'action'
        Action = {
            Write-Host (Paint "  $Label support is planned but not yet implemented." 'warn' -Bold)
            Write-Host ""
            Write-Host (Paint "  The toolkit is Windows-first for now. The menu engine" 'dim')
            Write-Host (Paint "  is OS-agnostic, so adding this branch later is just a" 'dim')
            Write-Host (Paint "  matter of dropping in a new module." 'dim')
        }
    }
}

# ---- Root menu tree -------------------------------------------------
function Get-MenuTree {
    @{
        Label = 'home'; Type = 'menu'
        Items = @(
            (Get-WindowsMenu),
            (New-ComingSoonNode -Label 'Linux'  -Desc 'planned'),
            (New-ComingSoonNode -Label 'macOS'  -Desc 'planned'),
            (Get-AboutNode)
        )
    }
}

# ---- Entrypoint -----------------------------------------------------
function Start-App {
    Initialize-Environment
    try {
        $root = Get-MenuTree
        Start-Menu -Root $root
    } finally {
        # Always hand the terminal back exactly as we found it: clear the
        # reserved row and release the scrolling region, even if something
        # threw on the way out.
        Disable-StatusBar
    }
}


Start-App
