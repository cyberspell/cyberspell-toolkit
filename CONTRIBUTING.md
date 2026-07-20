# Contributing

Thanks for the interest! Cyberspell Toolkit is deliberately easy to extend.

## The one concept you need

The entire menu is **data**: every category and command is a hashtable node, rendered by
a generic engine. You never touch UI code. The full node schema and worked examples live
in the README section *"Add a category or a command"*, read that first.

## Ground rules

1. **Compatibility:** everything must run on Windows PowerShell 5.1 **and** 7+.
   No classes, no ternary, no `??`, no `$PSStyle`; use `[char]0xNNNN` for non-ASCII.
2. **Safety model:** read-only diagnostics run without prompts. Anything that changes
   state gets `Confirm = $true`, a clear `Warning`, and `Admin = $true` if it needs
   elevation. When in doubt, gate it.
3. **No closures:** never use `GetNewClosure()` - carry data in the node and receive it
   via `param($n)` in the action.
4. **Interactive actions:** if your action prompts mid-run (`Read-Host`), mark the node
   `Interactive = $true` so the cancel-key watcher doesn't eat keystrokes.
5. **Output:** write through `Paint` / `Write-Kv` for themed lines; plain
   cmdlet/exe output is fine as-is.

## Workflow

```powershell
.\Start-Dev.ps1          # run from modular src/ while developing
.\build\Compile.ps1      # regenerate dist\toolkit.ps1 before committing
.\dist\toolkit.ps1       # sanity-check the compiled artifact
```

Commit the regenerated `dist/toolkit.ps1` with your change. it's the file the one-liner
serves and is committed on purpose.

## Pull requests

Keep them focused (one category or fix per PR), describe what you tested and on which
PowerShell version, and never include secrets, tenant names, or client-specific paths,
this repo is public.