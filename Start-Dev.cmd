@echo off
rem  cyberspell toolkit -- dev launcher shim
rem  Runs Start-Dev.ps1 regardless of execution policy or Mark-of-the-Web.
rem  Prefers PowerShell 7 (pwsh) when installed, falls back to Windows PowerShell.
where pwsh >nul 2>nul
if %errorlevel%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Dev.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Dev.ps1"
)
