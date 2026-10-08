# Running FixIt natively on Windows (no WSL, no VM)

This project originally shipped with WSL/Linux scripts. This copy has been
converted to run directly on Windows using your existing Flutter + Android
SDK setup — no virtual machine, no WSL required.

The stack is 4 pieces, each in its own terminal window:

| Process | Tech | Port |
|---|---|---|
| MongoDB | mongod | 27017 |
| Backend | Node + Express + Socket.IO | 4000 |
| AI service | Python + FastAPI | 5001 |
| Mobile app | Flutter | n/a |

---

## 1. Install what's missing

You already have **Flutter + the Android SDK** working (confirmed by
`flutter doctor`). You still need these three, if not already installed:

| Tool | Download | Notes |
|---|---|---|
| **Node.js LTS** | https://nodejs.org | Just run the installer, defaults are fine. Includes npm. |
| **Python 3.10+** | https://www.python.org/downloads/ | ⚠️ On the first installer screen, check **"Add python.exe to PATH"** — easy to miss. |
| **MongoDB Community Server** | https://www.mongodb.com/try/download/community | During install you'll be asked to "Install MongoDB as a Service" — see note below. |

**MongoDB service question:** if you check "Install as a Service", MongoDB
starts automatically in the background whenever Windows boots, and you can
skip `scripts\start-mongo.bat` entirely (just verify with `sc query MongoDB`).
If you leave it unchecked, run `scripts\start-mongo.bat` yourself each time.
Given your 8GB RAM, unchecked is a reasonable choice — it means MongoDB isn't
sitting in memory when you're not working on this project.

Open a **new** Command Prompt after each install so PATH updates take effect,
then verify:
```
node -v
python --version
mongod --version
flutter --version
```

---

## 2. One-time project setup

From the project's root folder in Command Prompt:
```
setup.bat
```
This installs backend npm packages, creates the Python venv for the AI
service, and runs `flutter pub get` for the mobile app. It's safe to re-run.

---

## 3. Run the stack

Open **4 separate Command Prompt windows**, one command in each:

```
scripts\start-mongo.bat
```
```
scripts\start-backend.bat
```
```
scripts\start-ai.bat
```
```
scripts\start-mobile.bat
```

(Skip the mongo window if you installed MongoDB as a Windows service.)

`start-mobile.bat` with no arguments lets Flutter prompt you for a device.
To target something specific:
```
scripts\start-mobile.bat chrome
scripts\start-mobile.bat 9cc2d0df   REM your phone's device id from `flutter devices`
```

---

## 4. Testing on your real Android phone (not an emulator)

Your phone connects over USB, which means `10.0.2.2` (the emulator-only
trick) won't reach your PC. Instead, use **adb reverse** — it's simpler than
finding your PC's LAN IP and doesn't break when your IP changes:

```
adb reverse tcp:4000 tcp:4000
```

Run this once each time you plug the phone in, **before** launching the app.
`api_config.dart` already defaults to `localhost:4000`, which this reverse
tunnel quietly redirects to your PC. No code edits needed.

If `adb` isn't recognized, it's inside your Android SDK's `platform-tools`
folder (e.g. `C:\Users\ATECH\AppData\Local\Android\Sdk\platform-tools`) — add
that to PATH, or run it with the full path.

---

## 5. Demo logins

After the backend's first run seeds the database:

| Role | Email | Password |
|---|---|---|
| Client | client@demo.com | password123 |
| Technician | tech@demo.com | password123 |
| Supplier | supplier@demo.com | password123 |
| Admin | admin@demo.com | password123 |

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `'node'/'python'/'mongod'/'flutter' is not recognized` | That tool isn't on PATH — reinstall and check the PATH checkbox, or open a new terminal window. |
| Backend logs `MongoServerError` / connection refused | MongoDB isn't running — start `scripts\start-mongo.bat` or check the Windows service. |
| App can't reach the backend on your phone | Re-run `adb reverse tcp:4000 tcp:4000` — this doesn't persist across USB disconnects. |
| `npm run seed` fails | Same as above — mongod must be running first. |
| Port already in use (4000 / 5001 / 27017) | Something else is using that port — close the other process, or change `PORT` in `backend/.env`. |
