# Cyberspell Toolkit

```
 ⚡ C Y B E R S P E L L
 // endpoint troubleshooting toolkit
```

A single-command, terminal-based (TUI) toolkit for **Windows endpoint troubleshooting** —
from everyday checks to deeper diagnostics — that wraps the CMD/PowerShell commands you
already run by hand into a clean, categorized, keyboard-driven menu.

Windows is the focus today. Linux and macOS branches are stubbed in and planned.

> **Status:** pre-release (v0.1.0). Engine, theming, and eleven Windows categories working;
> stabilizing locally before the first public release.

---

## Run it (the one-liner)

Launch it anywhere — one line, nothing to install:

```powershell
irm https://cyberspell.cloud/toolkit | iex
```

That downloads the compiled single-file build and runs it in memory. Read-only diagnostics
work in any session; run from an **Administrator** PowerShell/Terminal to unlock the
state-changing repair tasks.

Direct-from-GitHub fallback (always available, pinnable to a release tag):

```powershell
irm https://raw.githubusercontent.com/cyberspell/cyberspell-toolkit/main/dist/toolkit.ps1 | iex
```

---

## Run it locally (development)

No build step needed while hacking on it — the dev launcher dot-sources the modular source
in the right order and starts the app:

```powershell
# from the repo root, in PowerShell 5.1 or 7+
.\Start-Dev.ps1

# or, if execution policy complains (e.g. files extracted from a downloaded zip):
.\Start-Dev.cmd
```

To produce/refresh the single-file build that the one-liner serves:

```powershell
.\build\Compile.ps1        # writes dist\toolkit.ps1 (UTF-8, no BOM)
```

---

## Compatibility

- **PowerShell:** Windows PowerShell **5.1** and **PowerShell 7+**. No classes, no ternary /
  null-coalescing, no `$PSStyle` — runs on a stock Windows box out of the box.
- **Colors:** 24-bit truecolor ANSI. Virtual-terminal support is auto-detected and enabled
  (Windows Terminal & PS7 already have it; legacy 5.1 conhost is switched on via a small
  kernel32 call). If the terminal can't do ANSI, output **degrades gracefully to plain
  text** — it never prints raw escape codes.
- **Keys:** single-keypress navigation where supported, with a `Read-Host` fallback when
  input is redirected.

---

## What's inside (current menu)

```
home
├── Windows — endpoint diagnostics & fixes
│   ├── Network & connectivity  · triage, ipconfig, ping/traceroute, DNS, Wi-Fi,
│   │                            connections, port test, firewall — plus a Resets & repairs
│   │                            submenu (flush DNS, DHCP renew, TCP/IP & winsock reset)
│   ├── System & performance    · summary, top CPU/memory, startup programs, uptime,
│   │                            pending reboot, system errors, BSOD history, kill process
│   ├── Disk & storage          · drive space, SMART, TRIM, largest folders, CHKDSK, cleanup
│   ├── Windows Update          · service status, recent updates, WU component reset
│   ├── System repair           · SFC verify/repair, DISM check/scan/restore,
│   │                            component cleanup, restore points
│   ├── Hardware & drivers      · problem devices, display adapters, recent drivers
│   ├── Printers                · status, queue, spooler restart, clear stuck queue, remove
│   ├── Accounts & access       · session, local users, admins group, failed logons
│   ├── Apps & Office           · installed apps, Outlook OST/profiles/scanpst/navpane,
│   │                            Office quick repair, OneDrive reset, Teams cache clear
│   ├── Enterprise & identity   · dsregcmd join/PRT status, DC & secure channel, GPO,
│   │                            Kerberos, time sync, Intune sync & MDM diagnostics
│   └── Quick launch            · 20 consoles & tools, each with field tips (Event IDs,
│   │                            hidden-device tricks, wait-chain analysis, ...)
├── Linux — planned
├── macOS — planned
└── About — version, links, disclaimer
```

Navigation: number/letter keys select an item; **[B]** back, **[R]** refresh, **[Q]** quit.
While a task is running, **[ESC]** (or **X**) stops it and returns to the menu — long
operations like SFC, DISM, or folder scans no longer hold you hostage. (Tasks that
prompt for input run uninterrupted so your typing is never stolen.)
(Those three letters are reserved, so selectable items are keyed `1`–`9` then `A`–`Z`
skipping `B`, `Q`, `R`.)

---

## Architecture

Two ideas keep this maintainable as the command library grows:

**1. Modular source, compiled to one file.**
You develop against small files under `src/`. A build step concatenates them, in a fixed
load order, into a single self-contained `dist/toolkit.ps1` — that's the file the
`irm | iex` one-liner runs. (Same model WinUtil uses.)

```
src/
├── config/Theme.ps1          # palette, glyphs, banner, Paint() color helper
├── core/Utils.ps1            # env detection, admin check, logging, safe task runner
├── core/UI.ps1               # key input, menu rendering, status/breadcrumb/footer
├── core/Menu.ps1             # key mapping + the navigation loop
├── modules/windows/Windows.ps1   # the Windows category tree
└── main.ps1                  # app metadata, About, root tree, Start-App entrypoint
build/Compile.ps1             # concatenates the above → dist/toolkit.ps1
docs/CHANGELOG.md             # version history
Start-Dev.ps1 / Start-Dev.cmd # dev launcher (.cmd variant bypasses execution policy)
Run-Toolkit.cmd               # runs the compiled dist build, bypasses execution policy
dist/toolkit.ps1              # compiled single-file build (committed; served by the one-liner)
```

**2. The menu is data, not code.**
Every category and command is a **node** (a hashtable). A generic engine renders and
navigates them. Adding functionality means adding nodes — you don't touch the UI or the
loop.

---

## Add a category or a command

A node is just a hashtable. Two kinds:

**A submenu** (`Type = 'menu'`) holds child nodes in `Items`:

```powershell
@{
    Label = 'Network & connectivity'
    Desc  = 'connectivity & DNS'
    Type  = 'menu'
    Items = @( <# action or menu nodes #> )
}
```

**An action** (`Type = 'action'`) runs a scriptblock:

```powershell
# Safe, read-only → no confirmation needed
@{
    Label  = 'Flush DNS cache'
    Desc   = 'clear resolver cache (safe)'
    Type   = 'action'
    Action = { ipconfig /flushdns }
}

# State-changing → gate it with Admin + Confirm + a Warning
@{
    Label   = 'Winsock reset'
    Desc    = 'reset network stack'
    Type    = 'action'
    Admin   = $true      # requires elevation; shows "(needs admin)" and blocks if not elevated
    Confirm = $true      # prompts y/N before running
    Warning = 'Resets the Winsock catalog. A RESTART is required afterward.'
    Action  = {
        netsh winsock reset
        Write-Host (Paint "  Winsock reset. Restart to complete." 'warn')
    }
}
```

### Node fields

| Field | Type | Purpose |
|-------|------|---------|
| `Label` | string | Menu text (required) |
| `Desc` | string | Short description shown beside the label |
| `Type` | `'menu'` \| `'action'` | Branch or runnable command (required) |
| `Items` | node[] | Children — **menu nodes only** |
| `Action` | scriptblock | What runs — **action nodes only** |
| `Admin` | bool | Requires elevation; tagged in the menu and blocked if not elevated |
| `Confirm` | bool | Prompt y/N before running |
| `Warning` | string | Shown before the confirm prompt for risky operations |

**Convention:** read-only diagnostics run without a prompt (safe to explore); anything that
changes system state gets `Confirm`, a `Warning`, and `Admin` where elevation is required.

To wire a new category into the app, add its node to the tree assembled in
`src/main.ps1` (`Get-MenuTree`) / `src/modules/windows/Windows.ps1` (`Get-WindowsMenu`),
then run `Compile.ps1`.

### Helpers you can use inside an `Action`

- `Paint <text> <color>` — colorize output (`cyan`, `magenta`, `ok`, `warn`, `err`,
  `dim`, …), with automatic plain-text fallback.
- `Write-Kv <key> <value>` — aligned `key : value` lines.
- `Invoke-Task` — run a command safely (never throws, times it, logs it).
- `Write-Log` — append to the session log at `%TEMP%\cyberspell\log-yyyyMMdd.log`.

---

## Safety model

- Read-only by default; anything that modifies the system is explicitly flagged and
  confirmed.
- Admin-only tasks are blocked (not silently failed) when the session isn't elevated.
- Every action is logged with timing to `%TEMP%\cyberspell\`.
- Actions run through a wrapper that captures errors instead of crashing the menu.

---

## Roadmap

- Broaden the Windows library further: event-log deep dives, service management,
  BitLocker, memory diagnostics, and Exchange-relay / SMTP test tasks.
- Self-elevation for `irm | iex` sessions (relaunch elevated, WinUtil-style).
- Linux and macOS category trees.

---

## "The file is not digitally signed" / execution policy errors

You'll only ever see this when running the **files** locally — never with the one-liner.
`irm <url> | iex` executes the script from memory, so execution policy is not consulted
at all; that's the supported way to launch the toolkit.

If you're running the repo files directly (development, or a downloaded copy) and get
blocked, the cause is usually the **Mark of the Web**: files extracted from a
browser-downloaded zip are tagged as "remote", and the common `RemoteSigned` policy
refuses unsigned remote-tagged scripts. Three clean fixes, pick one:

```powershell
# 1. Remove the mark once (from the repo root) — permanent fix for that copy:
Get-ChildItem -Recurse | Unblock-File

# 2. Or use the launcher shims, which bypass policy for just that process:
.\Start-Dev.cmd        # dev run (modular src/)
.\Run-Toolkit.cmd      # run the compiled dist build

# 3. Or clone with git instead of downloading a zip — git-written files
#    never carry the Mark of the Web:
git clone https://github.com/cyberspell/cyberspell-toolkit.git
```

Don't lower machine-wide policy for this; none of the above touches your system settings.

---

## License & disclaimer

MIT — see [LICENSE](LICENSE).

Cyberspell Toolkit runs standard Windows administrative commands. Use it on systems you're
responsible for. Review what an action does before confirming it, especially the ones
marked as requiring a restart or elevation. No warranty.

*a [cyberspell](https://jp.cyberspell.cloud) project*
