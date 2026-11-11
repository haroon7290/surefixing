@echo off
REM Starts the Flutter app.
REM
REM Usage:
REM   start-mobile.bat            -- lets Flutter prompt you to pick a device
REM   start-mobile.bat chrome     -- runs in Chrome (web)
REM   start-mobile.bat <deviceid> -- runs on a specific device (see `flutter devices`)
REM
REM If you're running on a REAL Android phone over USB (not an emulator),
REM the backend at localhost won't be reachable from the phone by default.
REM Run this first (once per USB connection), with adb on PATH (it ships
REM inside the Android SDK platform-tools):
REM   adb reverse tcp:4000 tcp:4000
REM This makes "localhost:4000" on the PHONE point back to your PC, so no
REM IP address juggling is needed.

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

if exist android goto skip_create
if exist ios goto skip_create
if exist web goto skip_create
if exist windows goto skip_create
echo ==^> flutter create ^(platform folders missing^)
flutter create --org com.surefix --project-name surefix --platforms=android,ios,web,windows .
:skip_create

if "%~1"=="" (
  echo ==^> flutter run ^(pick a device if prompted^)
  flutter run
) else (
  echo ==^> flutter run -d %~1
  flutter run -d %~1
)
