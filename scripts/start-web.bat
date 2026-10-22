@echo off
REM Opens the SureFix WEBSITE in Chrome (the same Flutter app; on a wide
REM browser window it switches to the website layout: top navigation,
REM landing page, desktop dashboards). Start the backend first.
REM
REM Usage:
REM   start-web.bat          -- Chrome on http://localhost:8080
REM   start-web.bat edge     -- Microsoft Edge instead

setlocal
cd /d "%~dp0..\mobile"

where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: 'flutter' was not found on PATH.
  pause
  exit /b 1
)

if not exist pubspec.lock (
  echo ==^> flutter pub get ^(deps missing^)
  flutter pub get
)

set DEVICE=chrome
if /i "%~1"=="edge" set DEVICE=edge

echo ==^> Opening the website in %DEVICE% on http://localhost:8080
echo     Make the window wider than 1000px to see the desktop layout.
flutter run -d %DEVICE% --web-port 8080
