# Installation

| Process | Tech | Port |
|---|---|---|
| MongoDB | mongod 6+ | 27017 |
| Backend | Node.js 18+ (22 recommended) | 4000 |
| AI service | Python 3.10 – 3.13 | 5001 |
| Mobile app | Flutter 3.35 (Dart 3.9) | — |

The AI service is optional at runtime — if it's down the backend uses its built-in fallback
scorer (responses say `"engine": "fallback"`).

## Windows (native)

Follow **[WINDOWS_SETUP.md](../WINDOWS_SETUP.md)**: install Node, Python, MongoDB and Flutter,
run `setup.bat`, then the four `scripts\start-*.bat`.

## macOS / Linux

```bash
# MongoDB: brew install mongodb-community@7  (or run `docker run -d -p 27017:27017 mongo:7`)
cd backend && cp .env.example .env && npm install && npm run dev        # :4000
cd ai-service && python3 -m venv venv && . venv/bin/activate \
  && pip install -r requirements.txt && uvicorn app.main:app --reload --port 5001
cd mobile && flutter pub get && flutter run
```

## Docker (backend + AI + MongoDB)

```bash
docker compose up --build                                  # :4000, :5001, :27017
docker compose exec backend npm run seed -- --force         # optional demo data
docker compose down                                         # stop (add -v to delete data)
```

Set `JWT_SECRET` (and `NODE_ENV=production`) in your shell or a `.env` next to
`docker-compose.yml` for anything public. Uploads and Mongo data live in named volumes.

## Backend environment (`backend/.env`)

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `4000` | HTTP + Socket.IO port |
| `MONGO_URI` | `mongodb://localhost:27017/fixit` | Database (name kept from v1) |
| `JWT_SECRET` | `change_me…` | **Change it.** Production refuses to start with the default |
| `JWT_EXPIRES_IN` | `7d` | Token lifetime |
| `AI_SERVICE_URL` | `http://localhost:5001` | Python AI service |
| `AI_TIMEOUT_MS` | `2500` | Wait this long before using the fallback |
| `UPLOAD_DIR` | `uploads` | Where photos are stored |
| `CORS_ORIGINS` | `*` | Comma-separated allowed browser origins |
| `RATE_LIMIT_MAX` / `AUTH_RATE_LIMIT_MAX` | `1000` / `30` | Requests per 15 min per IP (API / login+register) |
| `NODE_ENV` | `development` | `production` hides internal error messages |

Useful commands (in `backend/`): `npm run dev` · `npm test` · `npm run seed` (only seeds an
empty DB) · `npm run seed -- --force` (wipes + reseeds) · `npm run create-admin`.

## Mobile app

| Setting | How |
|---|---|
| Backend URL | `--dart-define=API_BASE_URL=http://<host>:4000` (default `http://localhost:4000`) |
| Android emulator | `--dart-define=API_BASE_URL=http://10.0.2.2:4000` |
| Real phone over USB | `adb reverse tcp:4000 tcp:4000` once per connection (keeps `localhost`) |
| Currency symbol | `--dart-define=CURRENCY=$` (default `Rs`) |
| Demo login buttons in release builds | `--dart-define=DEMO=true` (always shown in debug) |

**Release APK**: `flutter build apk --release --dart-define=API_BASE_URL=http://<your-server>:4000`.
The Android manifest includes the INTERNET permission and allows cleartext HTTP so a local
`http://` backend works; remove `android:usesCleartextTraffic` once your API is on HTTPS.
iOS includes camera/photo-library usage strings and allows local-network HTTP.

**Web**: `flutter run -d chrome`, or `flutter build web --release` and serve `build/web`.

## Tests

```bash
cd backend && npm test                 # needs MongoDB on localhost:27017 (or MONGO_URL_TEST=...)
cd ai-service && pip install -r requirements-dev.txt && pytest
cd mobile && flutter analyze && flutter test
```

On Windows: `scripts\test-all.bat`. CI runs the same on every push.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Backend exits with `Mongo connection failed` | Start MongoDB (`scripts\start-mongo.bat` or the Windows service) |
| `Cannot find module 'helmet'` (or similar) after updating | Run `setup.bat` or `npm install` in `backend/` (the start script now does this automatically) |
| App says "Can't reach SureFix" | Backend not running, wrong `API_BASE_URL`, or phone needs `adb reverse tcp:4000 tcp:4000` |
| Smart Match says "Offline engine" | The AI service isn't running — results still work via the fallback; start `scripts\start-ai.bat` |
| "Too many attempts" on login | Rate limit (30 per 15 min per IP); wait or raise `AUTH_RATE_LIMIT_MAX` |
| Port in use | Change `PORT` in `backend/.env`, or stop the other process |
