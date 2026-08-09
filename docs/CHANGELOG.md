# Changelog

All notable changes to Cyberspell Toolkit are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com); versions follow SemVer.

## [0.1.2] — 2026-08-04

### Added
- **Command finder** — a new Windows entry holding 407 commands across 20 groups (files,
  disk, network, services, registry, DISM/servicing, Windows Update, boot & recovery,
  events, printing, remoting, scripting, virtualization/WSL and more), each with a
  one-line description. It opens as a single fzf-style pane: type to filter, arrows to
  move, `Enter` copies the highlighted command to the clipboard, `Esc` leaves. Matching
  is literal-first with a fuzzy fallback, so `dns` returns only DNS commands while
  `ipcfg` still finds `ipconfig`. With an empty query the whole list browses grouped by
  category. Lives in its own source file, `src/modules/windows/CheatSheet.ps1`.
- **Live output from console tools** — `sfc`, `dism`, `chkdsk`, `gpupdate` and the MDM
  diagnostics collector now run through a new `Invoke-Native` helper that leaves their
  output completely unredirected. They print live to the console exactly as they do at a
  prompt, including in-place progress such as "Verification 42% complete". Previously
  these were piped, and tools that buffer when their output is captured showed nothing at
  all until they finished.
- **Persistent status line** — the bottom row of the window is now reserved with a
  terminal scrolling region (DECSTBM) and owned by a small screen engine. It always shows
  the keys available on the current screen, and during a task it becomes a neon scanner
  with live elapsed time and a stop hint, returning to the key hints the moment the task
  ends. Because output scrolls in the region above it, the line can never be overwritten
  by output and can never bleed into it - including against tools like `sfc` that redraw
  with carriage returns. Cursor save/restore uses `ESC 7`/`ESC 8` rather than the SCO
  `CSI s`/`CSI u` pair, which some terminals ignore; ignoring it would strand the cursor
  on the reserved row and send all following output there. The whole layer degrades to
  no-ops without ANSI, falling back to the previous inline footer.
- **Yes/No confirmation selector** — confirmations now highlight **Yes** by default.
  Arrow keys (or Tab) move the selection and `Enter` accepts it; `y` and `n` still decide
  instantly and `Esc` cancels. Applies everywhere confirmations are used.
- **Readable durations** — elapsed times are formatted as `3.2s` or `3m 49s` instead of
  raw milliseconds.
- **TEMP cleanup** — Disk & storage gains "Clear user TEMP" and "Clear system TEMP"
  (elevated), both confirmation-gated, reporting how much was freed. Locked files are
  skipped and the toolkit's own log folder is preserved.
- **Single-source versioning** — the version now lives only in `src/main.ps1`. The build
  reads it, stamps the compiled header, and syncs the README badge automatically.

### Fixed
- `Paint` threw when handed an empty string, because a mandatory `[string]` parameter
  rejects `''`. Any caller painting a computed or padded value that happened to be empty
  would fail. It now accepts empty strings and returns early.
- The command finder no longer assigns to `$matches`, which is a PowerShell automatic
  variable that any `-match` operation can overwrite.
- The finder's clipboard copy now tries `Set-Clipboard`, then `clip.exe`, then the
  WinForms clipboard, and reports which route succeeded instead of failing quietly.

### Build
- The compiler now fails the build if a required internal function is called but never
  defined, or is defined more than once. A missing helper is not a parse error, so a build
  could previously succeed and then break at runtime the first time that code path ran.

### Removed
- Kerberos ticket list/purge actions (out of scope for now).

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
