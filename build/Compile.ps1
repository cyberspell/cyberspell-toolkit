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
    'src\modules\windows\CheatSheet.ps1',
    'src\main.ps1'
)

# --- Single source of truth for the version ------------------------------
#  The version lives ONLY in src\main.ps1 ($script:App.Version).
#  This build reads it and syncs everywhere else automatically.
$mainRaw = Get-Content -Raw (Join-Path $repo 'src\main.ps1')
$vMatch  = [regex]::Match($mainRaw, "Version\s*=\s*'(\d+\.\d+\.\d+)'")
if (-not $vMatch.Success) { throw 'Could not read Version from src\main.ps1' }
$version = $vMatch.Groups[1].Value

# Keep the README version badge honest - no manual edits, no drift.
$readmePath = Join-Path $repo 'README.md'
if (Test-Path $readmePath) {
    $readme  = Get-Content -Raw $readmePath
    $updated = $readme -replace 'version-\d+\.\d+\.\d+-00f0ff', "version-$version-00f0ff"
    if ($updated -ne $readme) {
        [System.IO.File]::WriteAllText($readmePath, $updated, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Synced: README version badge -> v$version"
    }
}

$distDir = Join-Path $repo 'dist'
if (-not (Test-Path $distDir)) { $null = New-Item -ItemType Directory -Path $distDir -Force }
$outFile = Join-Path $distDir 'toolkit.ps1'

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# =====================================================================')
[void]$sb.AppendLine("#  Cyberspell Toolkit v$version  --  compiled build (do not edit; edit src/ instead)")
[void]$sb.AppendLine("#  built: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine('#  cyberspell // https://github.com/cyberspell/cyberspell-toolkit')
[void]$sb.AppendLine('#  created with <3 by JP (https://jp.cyberspell.cloud) - for all my fellow IT engineers')
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
# --- Sanity gate ---------------------------------------------------------
#  A missing helper is NOT a parse error: the build "succeeds" and then
#  explodes at runtime the first time that code path runs. So check that
#  every function the toolkit relies on is actually defined, exactly once.
$tk = $null; $pe = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($outFile, [ref]$tk, [ref]$pe)
if ($pe -and $pe.Count) {
    Write-Host ""
    Write-Host "BUILD FAILED: $($pe.Count) parse error(s) in the compiled output:"
    $pe | Select-Object -First 5 | ForEach-Object {
        Write-Host ("  line {0}: {1}" -f $_.Extent.StartLineNumber, $_.Message)
    }
    exit 1
}

$internal = @(
    'Paint', 'Get-VisibleLength', 'Show-Banner',
    'Get-ScreenSize', 'Enable-StatusBar', 'Disable-StatusBar', 'Write-StatusBar',
    'Set-StatusIdle', 'Set-StatusBusy',
    'Enable-VirtualTerminal', 'Test-Admin', 'Get-EnvInfo', 'Get-LogPath', 'Write-Log',
    'Get-ActivityFrame', 'Format-Duration', 'Confirm-Action', 'Invoke-Native',
    'Test-ActionCancellable', 'Get-RunnerPreamble', 'Invoke-Task', 'Initialize-Environment',
    'Read-SingleKey', 'Write-Rule', 'Show-Status', 'Show-Breadcrumb', 'Show-Footer',
    'Show-MenuScreen', 'Wait-AnyKey', 'Write-Kv', 'Show-ActionHeader',
    'New-KeyMap', 'Invoke-Action', 'Start-Menu', 'Show-Goodbye',
    'Test-PendingReboot', 'Show-PendingRebootReport',
    'Get-FuzzyScore', 'Get-Fit', 'Copy-ToClipboard', 'Write-CheatEntry', 'Show-CommandFinder',
    'Get-WindowsMenu', 'Get-WinCheatSheetMenu', 'Get-WinQuickLaunchMenu',
    'Get-MenuTree', 'Get-AboutNode', 'New-ComingSoonNode', 'Start-App'
)

$defCount = @{}
foreach ($f in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    if ($defCount.ContainsKey($f.Name)) { $defCount[$f.Name] = $defCount[$f.Name] + 1 }
    else { $defCount[$f.Name] = 1 }
}

$missing = @()
$dupes   = @()
foreach ($n in $internal) {
    if (-not $defCount.ContainsKey($n)) { $missing += $n }
    elseif ($defCount[$n] -gt 1) { $dupes += ("{0} (x{1})" -f $n, $defCount[$n]) }
}

if ($missing.Count -gt 0 -or $dupes.Count -gt 0) {
    Write-Host ""
    if ($missing.Count -gt 0) {
        Write-Host "BUILD FAILED: required function(s) called but never defined:"
        foreach ($n in $missing) { Write-Host ("  missing: {0}" -f $n) }
    }
    if ($dupes.Count -gt 0) {
        Write-Host "BUILD FAILED: function(s) defined more than once:"
        foreach ($n in $dupes) { Write-Host ("  duplicate: {0}" -f $n) }
    }
    Write-Host ""
    Write-Host "  A source file is probably missing an edit, or a function was"
    Write-Host "  removed while its callers stayed behind. Fix src/ and rebuild."
    exit 1
}

Write-Host ("Checked: {0} functions defined, all {1} required helpers present" -f $defCount.Count, $internal.Count)
Write-Host "Built: $outFile  (v$version)"
Write-Host "Size : $([math]::Round((Get-Item $outFile).Length / 1KB, 1)) KB  ($lines lines)"
