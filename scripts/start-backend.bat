@echo off
REM Starts the Node backend on :4000. On first run against an empty DB it
REM also seeds demo data.
setlocal
cd /d "%~dp0..\backend"

where node >nul 2>nul
if errorlevel 1 (
  echo ERROR: 'node' was not found on PATH. Install Node.js LTS from https://nodejs.org
  pause
  exit /b 1
)

if not exist node_modules (
  echo ==^> Dependencies missing; running npm install
  call npm install --no-audit --no-fund
)

if not exist .env (
  copy .env.example .env >nul
  echo ==^> Created backend\.env from .env.example
)

echo ==^> Checking whether the database needs seeding...
node -e "const m=require('mongoose');m.connect(process.env.MONGO_URI||'mongodb://localhost:27017/fixit').then(async()=>{const c=await m.connection.db.collection('users').countDocuments();process.exit(c===0?0:1);}).catch(()=>process.exit(2));"
if %ERRORLEVEL%==0 (
  echo ==^> Empty database detected -- seeding demo data
  call npm run seed
) else if %ERRORLEVEL%==2 (
  echo ==^> Could not reach MongoDB. Make sure start-mongo.bat is running
  echo     ^(or the MongoDB service is started^) before continuing.
)

call npm run dev
