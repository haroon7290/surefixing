@echo off
REM Starts the Python FastAPI ranking service on :5001.
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
  pip install -r requirements.txt
) else (
  call venv\Scripts\activate.bat
)

uvicorn app.main:app --reload --port 5001
