# =====================================================================
#  Menu.ps1  --  Data-driven navigation engine
#  cyberspell // toolkit
# =====================================================================

# Single-key pool for item selection: digits 1-9, then letters
# EXCLUDING B / Q / R (reserved for Back / Quit / Refresh).
$script:KeyPool = @('1','2','3','4','5','6','7','8','9') + `
    ([char[]]('A'..'Z') | Where-Object { $_ -notin @('B','Q','R') } | ForEach-Object { [string]$_ })

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

    if (Test-ActionCancellable $Node) {
        Write-Host (Paint "  press [esc] at any time to stop this task and go back" 'dim')
        Write-Host ""
    }

    $r = Invoke-Task -Name $Node.Label -Action $Node.Action -Node $Node
    Write-Host ""
    if ($r.Cancelled) {
        Write-Host (Paint ("  [!] stopped by user after {0} ms" -f $r.Ms) 'warn' -Bold)
    } elseif (-not $r.Success) {
        Write-Host (Paint "  [x] finished with errors (see message above)" 'err' -Bold)
    } elseif ($r.ExitCode -ne 0) {
        Write-Host (Paint ("  [!] completed in {0} ms (exit code {1})" -f $r.Ms, $r.ExitCode) 'warn' -Bold)
    } else {
        Write-Host (Paint "  [ok] completed in $($r.Ms) ms" 'ok' -Bold)
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
    Clear-Host
    Write-Host ""
    Write-Host ("  " + (Paint "$($script:Glyph.bolt) cyberspell toolkit " 'cyan' -Bold) + (Paint "// session closed" 'magenta'))
    Write-Host ("  " + (Paint "logs: $(Get-LogPath)" 'dim'))
    Write-Host ""
    Write-Host ("  " + (Paint "created with $([char]0x2665) by $($script:App.Author)" 'magenta') + (Paint " - for all my fellow IT engineers" 'dim'))
    Write-Host ""
}