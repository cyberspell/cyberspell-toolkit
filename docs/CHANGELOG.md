# Changelog

All notable changes to Cyberspell Toolkit are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com); versions follow SemVer.

## [0.1.1] — 2026-07-19

Release polish. This is the tagged first-release build.

### Added
- Authorship & credits: About screen and quit screen now sign off with
  "created with ♥ by JP — for all my fellow IT engineers"; author header in the
  compiled build; README author section, badges, and footer.
- Standard project files: SECURITY.md, CONTRIBUTING.md.

### Fixed
- Corrected author site domain (jp.cyberspell.cloud).

## [0.1.0] — 2026-07-19

First public release. 🚀
Live at `irm https://cyberspell.cloud/toolkit | iex`.

### Engine
- Data-driven menu tree: every category/command is a hashtable node rendered by a
  generic navigation engine — extending the toolkit means adding nodes, not UI code.
- Cyberpunk truecolor TUI (neon cyan/magenta) with VT auto-detection and graceful
  plain-text fallback; single-keypress navigation with automatic `Read-Host` fallback.
- **Cancellable tasks:** press ESC (or X) during a running task to stop it and return
  to the menu — actions run in a console-sharing runspace with live output while the
  keyboard is watched; cancelled native child processes are cleaned up best-effort.
- Compatible with Windows PowerShell 5.1 and PowerShell 7+.
- Safety model: read-only tasks run freely; state-changing tasks are gated behind
  elevation checks, confirmation prompts, and explicit warnings; every action is logged
  with timing to `%TEMP%\cyberspell\`; errors never crash the menu.

### Windows content (11 categories, 95 actions)
- **Network & connectivity** — connectivity triage (IP→gateway→internet→DNS), ipconfig,
  adapters, ping/traceroute, DNS servers + lookup tests, Wi-Fi, connections, port test,
  firewall status, and a Resets & repairs submenu (flush DNS, DHCP renew, firewall
  toggle, TCP/IP + Winsock resets).
- **System & performance** — summary, top CPU/memory, memory usage, startup programs,
  uptime, pending reboot, recent errors, BSOD/minidump history, kill process,
  restart Explorer.
- **Disk & storage** — drive space, SMART health, TRIM status, largest folders,
  read-only CHKDSK, Disk Cleanup.
- **Windows Update** — service status, recent hotfixes, pending reboot, full WU
  component reset (SoftwareDistribution/catroot2).
- **System repair** — SFC verify/repair, DISM check/scan/restore health, component
  cleanup, restore points, System Restore launcher.
- **Hardware & drivers** — problem devices with decoded error codes, display
  adapters/monitors, recent drivers.
- **Printers** — status, queues, spooler restart, stuck-queue purge, printer removal.
- **Accounts & access** — whoami, local users/admins, account details, failed logons.
- **Apps & Office** — installed apps, Outlook OST/PST sizes vs limits, safe mode,
  navpane reset, profile listing, scanpst locator, Office Quick Repair, OneDrive reset,
  Teams (new) cache clear.
- **Enterprise & identity** — dsregcmd join/PRT status, DC + secure channel checks,
  gpresult/gpupdate, Kerberos list/purge, time sync status/resync, Intune sync trigger,
  MDM diagnostics report.
- **Quick launch** — 20 admin consoles/tools, each with practical field tips
  (Event Viewer crash IDs, hidden devices, wait-chain analysis, and more).

### Distribution
- Build pipeline compiling modular `src/` into a single-file `dist/toolkit.ps1`
  (UTF-8, no BOM) for `irm | iex` loading.
- Cloudflare Worker loader on `cyberspell.cloud/toolkit` (+ `/kit` alias) with edge
  caching; raw-GitHub fallback URL; execution-policy-proof `.cmd` launcher shims for
  local runs.