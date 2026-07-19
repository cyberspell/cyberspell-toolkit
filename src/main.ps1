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
    Version = '0.1.0'
    Repo    = 'https://github.com/cyberspell/cyberspell-toolkit'
}

# ---- About screen ---------------------------------------------------
function Get-AboutNode {
    @{
        Label = 'About'; Desc = 'version, links, disclaimer'; Type = 'action'
        Action = {
            Write-Kv 'Name'     "$($script:App.Name)  v$($script:App.Version)"
            Write-Kv 'By'       $script:App.Brand
            Write-Kv 'Repo'     $script:App.Repo
            Write-Kv 'Logs'     (Get-LogPath)
            Write-Kv 'Host'     "$($script:Env.Host)  ($($script:Env.OS))"
            Write-Kv 'Elevated' $(if ($script:Env.Admin) { 'yes' } else { 'no' }) $(if ($script:Env.Admin) { 'ok' } else { 'warn' })
            Write-Host ""
            Write-Host (Paint "  A menu-driven wrapper around standard Windows" 'dim')
            Write-Host (Paint "  troubleshooting commands. Read-only tasks are safe;" 'dim')
            Write-Host (Paint "  state-changing tasks always ask for confirmation." 'dim')
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
    $root = Get-MenuTree
    Start-Menu -Root $root
}
