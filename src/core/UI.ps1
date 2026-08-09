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
