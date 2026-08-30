@echo off
REM Wrapper: startet den grafischen Repo-Picker
setlocal
set SCRIPT_DIR=%~dp0
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT_DIR%gh-pick.ps1"
endlocal
