# Running SureFix natively on Windows

No WSL or VM needed. The stack is four processes, each in its own Command Prompt window:

| Process | Tech | Port |
|---|---|---|
| MongoDB | mongod | 27017 |
| Backend | Node + Express + Socket.IO | 4000 |
| AI service | Python + FastAPI | 5001 |
| App / website | Flutter | 8080 (website) |

---

## Already running an earlier version? (upgrading)

The data format changed in v3 (escrow wallet, job stages), so old data does not carry over.

1. Pull the new code: `git pull`.
2. Run `.\setup.bat` once (installs new backend packages and refreshes Flutter packages).
3. Run `.\scripts\reset-demo-data.bat` once. It **deletes everything in the database** and
   loads the new demo data; it asks you to type `YES` first. (`start-backend.bat` warns you if
   it finds data from the old version.)
4. On your phone, uninstall the old SureFix app first: the app id changed, so the new build
   installs as a separate app.
5. Start everything as usual.

> In **PowerShell**, scripts need the `.\` prefix (`.\setup.bat`, `.\scripts\start-backend.bat`).
> In the classic Command Prompt you can leave it out.

---

## 1. Install what's missing

| Tool | Download | Notes |
|---|---|---|
| **Node.js LTS** | https://nodejs.org | Defaults are fine. Includes npm. |
| **Python 3.10+** | https://www.python.org/downloads/ | ⚠️ Tick **"Add python.exe to PATH"** on the first screen. |
| **MongoDB Community Server** | https://www.mongodb.com/try/download/community | "Install as a Service" = starts with Windows (then skip `start-mongo.bat`). |
| **Flutter 3.35+** | https://docs.flutter.dev/get-started/install/windows | Plus Android Studio / SDK for phones and emulators. |

Open a **new** Command Prompt and check:
```
node -v
python --version
mongod --version
flutter --version
```

## 2. One-time project setup

From the project folder:
```
setup.bat
```
Creates `backend\.env`, installs backend packages, creates the Python venv for the AI service
and runs `flutter pub get`. Safe to re-run.

## 3. Run the stack

One command per window:
```
scripts\start-mongo.bat        (skip if MongoDB is a Windows service)
scripts\start-backend.bat
scripts\start-ai.bat
scripts\start-mobile.bat       (phone or emulator)
scripts\start-web.bat          (the website in Chrome)
```

On a brand-new empty database the backend seeds demo data automatically. Check it's alive:
<http://localhost:4000/api/health> · AI docs: <http://localhost:5001/docs>.

## 4. The website

`scripts\start-web.bat` opens SureFix in Chrome at <http://localhost:8080> (`start-web.bat edge`
for Edge). It is the same Flutter app: in a window **wider than 1000 px** it shows the website
layout — a public landing page, technician directory and tool market for visitors, and a
sidebar web app after logging in. Make the window narrow and it turns into the phone layout.

To publish it, build static files and upload `mobile\build\web` to any web host:
```
cd mobile
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com
```
The backend must be reachable from the visitor's browser at that address.

## 5. Real Android phone over USB

```
adb reverse tcp:4000 tcp:4000
```
Run it each time you plug the phone in, before launching the app. (`adb` lives in your Android
SDK's `platform-tools` folder.) Alternatively use your PC's Wi-Fi IP:
`flutter run --dart-define=API_BASE_URL=http://192.168.x.x:4000`.

Building an APK to install on other phones:
```
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.x.x:4000
```

## 6. Demo logins

Password `password123` for all (the log-in screen also has one-tap demo buttons):

| Role | Email |
|---|---|
| Client | client@demo.com |
| Technician | tech@demo.com |
| Supplier | supplier@demo.com |
| Admin | admin@demo.com |

More accounts are listed in [docs/USER_GUIDE.md](docs/USER_GUIDE.md).

## 7. Run all tests

```
scripts\test-all.bat
```
Backend (needs MongoDB running), AI service and Flutter.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `'node'/'python'/'mongod'/'flutter' is not recognized` | Not on PATH — reinstall with the PATH option, or open a new window. |
| Backend: `Mongo connection failed` | Start `scripts\start-mongo.bat` or the MongoDB Windows service. |
| Backend: `Cannot find module …` | Run `setup.bat` (or `npm install` in `backend`). |
| App: "Can't reach SureFix" on a phone | Re-run `adb reverse tcp:4000 tcp:4000` (it resets when unplugged). |
| Smart Match says "Built-in engine" | Start `scripts\start-ai.bat` — results still work meanwhile. |
| Backend warns about data from an older version | Run `scripts\reset-demo-data.bat` once. |
| Forgot-password code never arrives | No email server is set: the code is shown on screen and printed in the backend window. Set `SMTP_URL` in `backend\.env` for real emails. |
| "Your wallet balance is too low" | Wallet → **Add money**: send money to a listed account, enter the transaction ID, and an admin approves it (demo admin: `admin@demo.com` → Payments). Or choose cash. |
| `setup.bat` is not recognized (PowerShell) | Type `.\setup.bat`. |
| `npm run seed` says the database already has users | That's the safety guard. Use `scripts\reset-demo-data.bat` to wipe and reseed. |
| Port 4000 / 5001 / 27017 already in use | Close the other process or change `PORT` in `backend\.env`. |
