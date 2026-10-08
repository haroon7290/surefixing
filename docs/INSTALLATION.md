# Installation

The stack is four processes:

| Process | Tech | Default port |
|---|---|---|
| MongoDB | mongod 6+ | 27017 |
| Backend | Node 18+ + Express + Socket.IO | 4000 |
| AI service | Python 3.10+ + FastAPI | 5001 |
| Mobile | Flutter 3.13+ (web / desktop / Android / iOS) | n/a |

The mobile app talks to the backend over HTTP + WebSocket. The backend talks
to MongoDB and (optionally) the AI service. If the AI service is down, the
backend falls back to a built-in JS scoring function and keeps working.

---

## 1. System prerequisites

### Windows (native — this copy of the project)

See **[`WINDOWS_SETUP.md`](../WINDOWS_SETUP.md)** at the project root for the
full walkthrough. Short version — install via official installers:
- Node.js LTS — https://nodejs.org/
- Python 3.10+ — https://www.python.org/downloads/ (check "Add to PATH")
- MongoDB Community Server — https://www.mongodb.com/try/download/community
- Flutter + Android SDK — https://docs.flutter.dev/get-started/install/windows

Then run `setup.bat` from the project root in Command Prompt.

### macOS

```bash
brew install node@20 python@3.11 mongodb-community@7
brew install --cask flutter            # or follow https://flutter.dev/docs/get-started/install/macos
```

### Ubuntu / WSL2

This copy of the project ships with Windows `.bat` scripts, not the original
`.sh` scripts. If you specifically want to run under WSL/Linux instead of
native Windows, install Node 20, Python 3, MongoDB 7, and Flutter via your
distro's package manager or an official installer, then adapt `setup.bat`'s
steps to shell commands (`npm install`, `python3 -m venv venv`, `flutter pub get`).

---

## 2. Per-project setup

```bat
setup.bat
```

`setup.bat` does:

- Copies `backend/.env.example` → `backend/.env` (if missing).
- `npm install` in `backend/`.
- Creates `ai-service/venv` and `pip install -r requirements.txt`.
- Runs `flutter create --org com.fixit --project-name fixit .` in `mobile/`
  if platform folders are missing (web/android/ios/linux). Then `flutter pub get`.

It's safe to re-run.

### Environment variables

All in `backend/.env` (copied from `.env.example`):

| Var | Default | What |
|---|---|---|
| `PORT` | `4000` | Express HTTP + Socket.IO listen port |
| `MONGO_URI` | `mongodb://localhost:27017/fixit` | Mongo connection string |
| `JWT_SECRET` | `change_me_to_a_long_random_string` | **Change this in production**; HMAC-SHA256 secret for JWTs |
| `JWT_EXPIRES_IN` | `7d` | jsonwebtoken expiresIn format |
| `AI_SERVICE_URL` | `http://localhost:5001` | Where the AI ranker lives |
| `UPLOAD_DIR` | `uploads` | Multer destination (relative to `backend/`) |
| `USE_FIREBASE` | `false` | **Currently unused** — see [STATUS.md](./STATUS.md) |

---

## 3. Run the stack

Four Command Prompt windows, four scripts:

```bat
scripts\start-mongo.bat        :: Window 1 — mongod (skip if it runs as a Windows service)
scripts\start-backend.bat      :: Window 2 — backend on :4000 (auto-seeds on first run if DB is empty)
scripts\start-ai.bat           :: Window 3 — AI service on :5001
scripts\start-mobile.bat       :: Window 4 — Flutter app
```

`start-backend.bat`:
- Runs `npm install` if `node_modules` is missing.
- Detects an empty `users` collection and auto-runs `npm run seed`. Seed data
  documented in [USER_GUIDE.md](./USER_GUIDE.md#demo-data).

`start-mobile.bat`:
- Runs `flutter pub get` if `pubspec.lock` is missing.
- With no argument, lets Flutter prompt you to choose a device.
- Pass `chrome` or a device id (from `flutter devices`) as an argument to
  target it directly, e.g. `scripts\start-mobile.bat chrome`.

---

## 4. Mobile baseUrl

`mobile/lib/services/api_config.dart` defaults to `http://localhost:4000`
for every platform. That's correct as-is for web and Windows desktop.

**Real Android device over USB:** `localhost` on the phone doesn't reach
your PC by default. Run this once per USB connection, before launching the
app:
```bat
adb reverse tcp:4000 tcp:4000
```
This makes the phone's `localhost:4000` transparently forward to your PC —
no IP address to find or hardcode, and no code changes needed.

If the backend lives on a different machine entirely (not your dev PC), skip
adb reverse and build with:

```bat
cd mobile
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000
```

`API_BASE_URL` overrides everything.

---

## 5. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `'flutter'/'node'/'python'/'mongod' is not recognized` | Not on PATH — reinstall checking the PATH option, or open a new Command Prompt window. |
| Web shows blank page | First load downloads CanvasKit (~5 MB). Wait, then `Ctrl+Shift+R`. If still blank, open DevTools Console — likely a stale service worker. |
| App on phone can't reach backend | Re-run `adb reverse tcp:4000 tcp:4000` — this doesn't persist across USB unplug/replug. |
| `MongoServerError: Authentication failed` | `MONGO_URI` points to a remote DB requiring auth — add credentials, or run a local mongod. |
| Real-time toasts don't appear | Backend not running, or socket auth failed (token mismatch — log out + log back in). Verify in browser DevTools → Network → WS frames. |
| `npm run seed` fails | mongod isn't running, or `MONGO_URI` wrong. |
| Mobile shows old data after login as different user | `AuthService` caches in SharedPreferences. Logout uses `pushAndRemoveUntil` so this shouldn't happen — if it does, clear browser storage. |

---

## 6. Demo credentials

After seeding, these accounts exist (password is `password123` for all):

| Role | Email |
|---|---|
| Client | `client@demo.com` |
| Technician | `tech@demo.com` |
| Technician | `tech2@demo.com` |
| Supplier | `supplier@demo.com` |
| Admin | `admin@demo.com` |

Two demo jobs and three demo tools are also seeded — see
[`backend/src/utils/seed.js`](../backend/src/utils/seed.js) for exact values.
