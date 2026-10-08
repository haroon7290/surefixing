@echo off
REM WIPES the SureFix database and loads the demo data: 13 demo accounts,
REM jobs in every state, quotes, reviews, tools, rentals, chats, a KYC
REM submission and a report. All demo passwords are "password123".
setlocal
cd /d "%~dp0..\backend"

echo.
echo  This DELETES all users, jobs, tools, rentals and messages in the
echo  database configured in backend\.env and replaces them with demo data.
echo.
set /p CONFIRM=Type YES to continue: 
if /I not "%CONFIRM%"=="YES" (
  echo Cancelled -- nothing was changed.
  exit /b 0
)

call npm install --no-audit --no-fund --loglevel=error
call npm run seed -- --force
echo.
echo Demo logins: client@demo.com, tech@demo.com, supplier@demo.com, admin@demo.com (password123)
pause
