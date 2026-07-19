# Changelog

All notable changes to Cyberspell Toolkit are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com); versions follow SemVer.

The version stays at **0.1.0** through local testing. It only moves once the first
public release is tagged.

## [0.1.0] — Unreleased (baseline)

### Added
- Data-driven menu engine: categories/commands are hashtable nodes rendered by a
  generic navigation loop — extending the toolkit means adding nodes, not UI code.
- Cyberpunk truecolor TUI (neon cyan/magenta) with VT auto-detection and graceful
  plain-text fallback; single-keypress navigation with `Read-Host` fallback.
- Compatibility with Windows PowerShell 5.1 and PowerShell 7+.
- Safety model: read-only tasks run freely; state-changing tasks are gated behind
  elevation checks, confirmation prompts, and explicit warnings; all actions are
  logged with timing to `%TEMP%\cyberspell\`, and errors never crash the menu.
- Ten Windows categories: Network & connectivity (incl. Resets & repairs submenu),
  System & performance, Disk & storage, Windows Update, System repair (SFC/DISM),
  Hardware & drivers, Printers, Accounts & access, Apps & Office, Quick launch.
- Build pipeline (`build/Compile.ps1`) compiling modular `src/` into a single-file
  `dist/toolkit.ps1` (UTF-8, no BOM) for `irm | iex` loading.
- Repo scaffolding: README, MIT license, publishing guide (`docs/publishing.md`).
