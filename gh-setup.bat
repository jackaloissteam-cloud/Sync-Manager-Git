@echo off
REM Wrapper: startet gh-setup.ps1
setlocal
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%gh-setup.ps1"
pause
endlocal
