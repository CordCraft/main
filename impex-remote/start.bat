@echo off
REM Double-click this file on Windows to start the Impex web remote.
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is not installed. Get it from https://nodejs.org (LTS), then run this file again.
  pause
  exit /b 1
)
if not exist node_modules call npm install
echo.
echo Starting... open the address below on your iPhone (same Wi-Fi as the TV).
echo.
call npm start
pause
