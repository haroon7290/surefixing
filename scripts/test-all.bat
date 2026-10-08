@echo off
REM Runs every test suite: backend (needs MongoDB running on localhost:27017),
REM AI service, and the Flutter app. Exit code is non-zero if anything fails.
setlocal
set FAILED=0

echo ==^> Backend tests ^(MongoDB must be running^)
cd /d "%~dp0..\backend"
call npm install --no-audit --no-fund --loglevel=error
call npm test
if errorlevel 1 set FAILED=1

echo.
echo ==^> AI service tests
cd /d "%~dp0..\ai-service"
if not exist venv python -m venv venv
call venv\Scripts\activate.bat
pip install -q -r requirements-dev.txt
python -m pytest -q
if errorlevel 1 set FAILED=1
call venv\Scripts\deactivate.bat

echo.
echo ==^> Flutter analyze + tests
cd /d "%~dp0..\mobile"
call flutter pub get
call flutter analyze
if errorlevel 1 set FAILED=1
call flutter test
if errorlevel 1 set FAILED=1

echo.
if "%FAILED%"=="1" (
  echo ==^> SOME TESTS FAILED -- scroll up for details.
  exit /b 1
)
echo ==^> ALL TESTS PASSED
