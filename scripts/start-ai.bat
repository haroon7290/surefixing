@echo off
REM Starts the SureFix AI service (FastAPI) on :5001. API docs: http://localhost:5001/docs
setlocal
cd /d "%~dp0..\ai-service"

where python >nul 2>nul
if errorlevel 1 (
  echo ERROR: 'python' was not found on PATH. Install Python 3.10+ from https://www.python.org/downloads/
  echo IMPORTANT: during install, check "Add python.exe to PATH".
  pause
  exit /b 1
)

if not exist venv (
  echo ==^> venv missing; creating it
  python -m venv venv
  call venv\Scripts\activate.bat
  python -m pip install --upgrade pip >nul
) else (
  call venv\Scripts\activate.bat
)

REM Always sync requirements (quick when already installed) so a git pull
REM that adds a package doesn't break startup.
echo ==^> Checking AI service dependencies...
pip install -q -r requirements.txt

uvicorn app.main:app --reload --port 5001
