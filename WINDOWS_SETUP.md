# Running SureFix natively on Windows

No WSL or VM needed. The stack is four processes, each in its own Command Prompt window:

| Process | Tech | Port |
|---|---|---|
| MongoDB | mongod | 27017 |
| Backend | Node + Express + Socket.IO | 4000 |
| AI service | Python + FastAPI | 5001 |
| Mobile app | Flutter | — |

---

## Already running the previous version? (upgrading)

1. Pull the new code.
2. Run `setup.bat` once (installs the new backend packages and refreshes Flutter packages).
   The start scripts also install missing packages automatically from now on.
3. Start everything as usual. **Your existing data keeps working** — same database (`fixit`),
   new fields have defaults.
4. Optional: `scripts\reset-demo-data.bat` loads the much richer v2 demo data. It **deletes
   everything in the database first** and asks you to type `YES`.

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
scripts\start-mobile.bat       (or: scripts\start-mobile.bat chrome)
```

On a brand-new empty database the backend seeds demo data automatically. Check it's alive:
<http://localhost:4000/api/health> · AI docs: <http://localhost:5001/docs>.

## 4. Real Android phone over USB

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

## 5. Demo logins

Password `password123` for all (debug builds also show one-tap demo buttons):

| Role | Email |
|---|---|
| Client | client@demo.com |
| Technician | tech@demo.com |
| Supplier | supplier@demo.com |
| Admin | admin@demo.com |

More accounts are listed in [docs/USER_GUIDE.md](docs/USER_GUIDE.md).

## 6. Run all tests

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
| Smart Match shows "Offline engine" | Start `scripts\start-ai.bat` — results still work meanwhile. |
| `npm run seed` says the database already has users | That's the safety guard. Use `scripts\reset-demo-data.bat` to wipe and reseed. |
| Port 4000 / 5001 / 27017 already in use | Close the other process or change `PORT` in `backend\.env`. |
