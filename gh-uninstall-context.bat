@echo off
REM Wrapper: startet gh-uninstall-context.ps1
setlocal
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%gh-uninstall-context.ps1"
endlocal
