@echo off
rem  cyberspell toolkit -- launcher shim for the compiled build
rem  Runs dist\toolkit.ps1 regardless of execution policy or Mark-of-the-Web.
where pwsh >nul 2>nul
if %errorlevel%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0dist\toolkit.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dist\toolkit.ps1"
)
