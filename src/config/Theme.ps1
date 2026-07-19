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
        [Parameter(Mandatory)][string]$Text,
        [string]$Color = 'text',
        [switch]$Bold
    )
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

# ---------------------------------------------------------------------
#  Show-Banner  --  framed cyberpunk header
# ---------------------------------------------------------------------
function Show-Banner {
    $g = $script:Glyph
    $w = [Math]::Max(60, [Math]::Min($script:UI.Width, 100))
    $inner = $w - 2

    $top = "$($g.tl)$([string]$g.h * $inner)$($g.tr)"
    $bot = "$($g.bl)$([string]$g.h * $inner)$($g.br)"

    # Title line:  ' ⚡ C Y B E R S P E L L                 v0.1.0 '
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
