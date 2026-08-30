@echo off
REM Wrapper: startet gh-sync.ps1
setlocal
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%gh-sync.ps1"
pause
endlocal
