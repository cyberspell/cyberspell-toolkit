# =====================================================================
#  Start-Dev.ps1  --  Local development launcher
#  Dot-sources the modular source files in order, then starts the app.
#  Use this while developing:   .\Start-Dev.ps1
# =====================================================================
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$loadOrder = @(
    'src\config\Theme.ps1',
    'src\core\Utils.ps1',
    'src\core\UI.ps1',
    'src\core\Menu.ps1',
    'src\modules\windows\Windows.ps1',
    'src\main.ps1'
)

foreach ($rel in $loadOrder) {
    $path = Join-Path $here $rel
    if (-not (Test-Path $path)) { throw "Missing source file: $rel" }
    . $path
}

Start-App
