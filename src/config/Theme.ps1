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
