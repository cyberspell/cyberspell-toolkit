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
    Show-Footer -IsRoot:$IsRoot
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
