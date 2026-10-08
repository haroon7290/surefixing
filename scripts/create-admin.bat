@echo off
REM Starts the Node backend on :4000.
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
  node -e "const fs=require('fs');const crypto=require('crypto');const p='.env';let c=fs.readFileSync(p,'utf8');c=c.replace(/JWT_SECRET=.*/,'JWT_SECRET='+crypto.randomBytes(48).toString('hex'));fs.writeFileSync(p,c);console.log('==^> Generated a random JWT_SECRET in backend\\.env');"
)

echo ==^> Checking whether the database has any users yet...
node -e "const m=require('mongoose');m.connect(process.env.MONGO_URI||'mongodb://localhost:27017/fixit').then(async()=>{const c=await m.connection.db.collection('users').countDocuments();process.exit(c===0?0:1);}).catch(()=>process.exit(2));"
if %ERRORLEVEL%==0 (
  echo ==^> Database is empty -- no user accounts exist yet.
  echo     Create your admin account with:
  echo         npm run create-admin
  echo     ^(Everyone else signs up normally from the app's "Create an account" screen.^)
) else if %ERRORLEVEL%==2 (
  echo ==^> Could not reach MongoDB. Make sure start-mongo.bat is running
  echo     ^(or the MongoDB service is started^) before continuing.
)

call npm run dev