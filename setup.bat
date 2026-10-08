@echo off
REM Per-project setup -- run this once.
REM Assumes Node.js, Python 3, MongoDB, and Flutter are already installed
REM (see WINDOWS_SETUP.md if not).

setlocal
cd /d "%~dp0"

echo ==^> Checking required tools are on PATH...
where node    >nul 2>nul || (echo MISSING: node    -- install from https://nodejs.org & set MISSING=1)
where npm     >nul 2>nul || (echo MISSING: npm     -- comes with Node.js & set MISSING=1)
where python  >nul 2>nul || (echo MISSING: python  -- install from https://www.python.org/downloads/ & set MISSING=1)
where flutter >nul 2>nul || (echo MISSING: flutter -- install from https://docs.flutter.dev/get-started/install/windows & set MISSING=1)
if defined MISSING (
  echo.
  echo Install the missing tool^(s^) above, then re-run setup.bat.
  pause
  exit /b 1
)

echo ==^> backend: npm install
cd backend
if not exist .env (
  copy .env.example .env >nul
  echo ==^> Created backend\.env from .env.example
)
call npm install --no-audit --no-fund
cd ..
echo ==^> backend ready

echo ==^> ai-service: venv + pip install
cd ai-service
if not exist venv (
  python -m venv venv
)
call venv\Scripts\activate.bat
python -m pip install --upgrade pip >nul
pip install -r requirements.txt
call venv\Scripts\deactivate.bat
cd ..
echo ==^> ai-service ready

echo ==^> mobile: flutter create ^(if needed^) + flutter pub get
cd mobile
if exist android goto skip_create
if exist ios goto skip_create
if exist web goto skip_create
if exist windows goto skip_create
flutter create --org com.fixit --project-name fixit .
:skip_create
flutter pub get
cd ..
echo ==^> mobile ready

echo.
echo ==^> All set.
echo.
echo Start the stack (one command per window):
echo   scripts\start-mongo.bat      ^(skip if MongoDB runs as a Windows service^)
echo   scripts\start-backend.bat    :4000  ^(first run auto-seeds demo data^)
echo   scripts\start-ai.bat         :5001
echo   scripts\start-mobile.bat     ^(add "chrome" or a device id as an argument^)
echo.
echo If testing on a real Android phone over USB, first run:
echo   adb reverse tcp:4000 tcp:4000
echo   adb reverse tcp:5001 tcp:5001
echo.
echo Demo logins:  client@demo.com   tech@demo.com   supplier@demo.com   admin@demo.com
echo Password:     password123
echo.
pause
