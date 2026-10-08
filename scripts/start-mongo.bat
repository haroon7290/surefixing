@echo off
REM Starts mongod in the foreground. Close this window (or Ctrl+C) to stop.
REM If MongoDB is already running as a Windows Service, you can skip this
REM script entirely -- check with: sc query MongoDB

setlocal
if "%MONGO_DATA_DIR%"=="" set "MONGO_DATA_DIR=%USERPROFILE%\data\db"

if not exist "%MONGO_DATA_DIR%" (
  echo Creating data directory: %MONGO_DATA_DIR%
  mkdir "%MONGO_DATA_DIR%"
)

where mongod >nul 2>nul
if errorlevel 1 (
  echo.
  echo ERROR: 'mongod' was not found on PATH.
  echo Install MongoDB Community Server from:
  echo   https://www.mongodb.com/try/download/community
  echo During install, UNCHECK "Install MongoDB as a Service" if you want
  echo to control it manually with this script -- or leave it CHECKED and
  echo just skip this script, since it'll already be running in the background.
  echo.
  pause
  exit /b 1
)

echo ==^> Starting mongod with --dbpath "%MONGO_DATA_DIR%"
mongod --dbpath "%MONGO_DATA_DIR%"
