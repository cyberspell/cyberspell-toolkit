# =====================================================================
#  Compile.ps1  --  Build the single-file release
#  Concatenates the modular source into dist\toolkit.ps1 with a
#  Start-App call appended, so it runs when loaded via irm | iex.
#  Run:  .\build\Compile.ps1
# =====================================================================
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$loadOrder = @(
    'src\config\Theme.ps1',
    'src\core\Utils.ps1',
    'src\core\UI.ps1',
    'src\core\Menu.ps1',
    'src\modules\windows\Windows.ps1',
    'src\main.ps1'
)

$distDir = Join-Path $repo 'dist'
if (-not (Test-Path $distDir)) { $null = New-Item -ItemType Directory -Path $distDir -Force }
$outFile = Join-Path $distDir 'toolkit.ps1'

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# =====================================================================')
[void]$sb.AppendLine('#  Cyberspell Toolkit  --  compiled build (do not edit; edit src/ instead)')
[void]$sb.AppendLine("#  built: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine('#  cyberspell // https://github.com/cyberspell/cyberspell-toolkit')
[void]$sb.AppendLine('# =====================================================================')
[void]$sb.AppendLine('')

foreach ($rel in $loadOrder) {
    $path = Join-Path $repo $rel
    if (-not (Test-Path $path)) { throw "Missing source file: $rel" }
    [void]$sb.AppendLine("# ----- $rel -----")
    [void]$sb.AppendLine((Get-Content -Raw -Path $path))
    [void]$sb.AppendLine('')
}

# Entry call so `irm ... | iex` launches the TUI automatically.
[void]$sb.AppendLine('Start-App')

# Write UTF-8 WITHOUT BOM (a BOM can break `irm | iex`).
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outFile, $sb.ToString(), $enc)

$lines = ($sb.ToString() -split "`n").Count
Write-Host "Built: $outFile"
Write-Host "Size : $([math]::Round((Get-Item $outFile).Length / 1KB, 1)) KB  ($lines lines)"
