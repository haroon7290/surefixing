# FixIt — Home Repair Services & Tool Rental Marketplace

A mobile marketplace app connecting **clients**, **technicians**, **suppliers**, and **admins** for home-repair jobs and tool rentals.

## Architecture

```
talha/
├── backend/       Node + Express + Socket.IO + MongoDB (port 4000)
├── ai-service/    Python FastAPI technician-ranking microservice (port 5001)
├── mobile/        Flutter app (web tested; Android/iOS/Linux platform folders generated on first setup)
├── scripts/       install + start helpers
└── docs/          full documentation — read this folder
```

The Flutter app talks to the backend over HTTP (REST) and WebSocket (Socket.IO
push for real-time toasts and live list updates). The backend calls the Python
AI service to rank technicians; if the AI service is down, an in-process JS
fallback runs the same scoring formula.

> **Full documentation lives in [`docs/`](./docs/)** —
> [installation](./docs/INSTALLATION.md),
> [architecture](./docs/ARCHITECTURE.md),
> [user guide](./docs/USER_GUIDE.md),
> [status (what's done / stubbed / missing)](./docs/STATUS.md).

## Roles

- **Client** — posts jobs, reviews bids, hires, rents tools, chats
- **Technician** — browses jobs, places bids, manages assigned work, gets AI-ranked
- **Supplier** — lists tools for rent or installment purchase
- **Admin** — manages users, verifies KYC, monitors the platform

## Quick start (native Windows — no WSL, no VM)

**Full walkthrough: [`WINDOWS_SETUP.md`](./WINDOWS_SETUP.md)** — read that
first if this is your first run. Short version:

```bat
:: 1. Install Node.js LTS, Python 3.10+, and MongoDB Community Server
::    (see WINDOWS_SETUP.md for links). Flutter + Android SDK: see
::    docs/INSTALLATION.md if not already set up.

:: 2. One-time project setup
setup.bat

:: 3. Start the 4 services, each in its own Command Prompt window:
scripts\start-mongo.bat        :: skip if MongoDB runs as a Windows service
scripts\start-backend.bat      :: :4000 (auto-seeds demo data on first run)
scripts\start-ai.bat           :: :5001 (Python FastAPI)
scripts\start-mobile.bat       :: Flutter — add "chrome" or a device id as an argument
```

Testing on a real Android phone over USB (not an emulator)? Run this once
per USB connection, before launching the app:
```bat
adb reverse tcp:4000 tcp:4000
```

Demo logins created by the seed:

| Role       | Email              | Password    |
| ---------- | ------------------ | ----------- |
| Client     | client@demo.com    | password123 |
| Technician | tech@demo.com      | password123 |
| Supplier   | supplier@demo.com  | password123 |
| Admin      | admin@demo.com     | password123 |

## Prerequisites

| Tool    | Version   | Notes                                                   |
| ------- | --------- | ------------------------------------------------------- |
| Node.js | ≥ 18      | `node -v`                                               |
| npm     | ≥ 9       | bundled with Node                                       |
| Python  | ≥ 3.10    | `python --version`                                      |
| MongoDB | ≥ 6       | local daemon, or a Mongo Atlas URI                      |
| Flutter | ≥ 3.13    | `flutter doctor` must pass                              |

See [`WINDOWS_SETUP.md`](./WINDOWS_SETUP.md) for install links and details.

## Picking a Flutter run target

```bat
scripts\start-mobile.bat            :: no arg — Flutter prompts you to pick a device
scripts\start-mobile.bat chrome     :: run in Chrome (web)
scripts\start-mobile.bat <id>       :: any device id from `flutter devices`
```

`mobile/lib/services/api_config.dart` defaults to `http://localhost:4000` for
every platform. On web/Windows-desktop that's already correct. On a real
Android phone over USB, run `adb reverse tcp:4000 tcp:4000` once per USB
connection so the phone's `localhost` reaches your PC. Override entirely with
`flutter run --dart-define=API_BASE_URL=http://<host>:4000`.

## Key API endpoints

| Method | Path                           | Description                            |
| ------ | ------------------------------ | -------------------------------------- |
| POST   | `/api/auth/register`           | Sign up (role in body)                 |
| POST   | `/api/auth/login`              | Returns JWT                            |
| GET    | `/api/jobs`                    | List jobs (filters by status/role)     |
| POST   | `/api/jobs`                    | Create job (client only)               |
| POST   | `/api/jobs/:id/bids`           | Place bid (technician only)            |
| POST   | `/api/jobs/:id/accept/:bidId`  | Accept a bid (client only)             |
| PATCH  | `/api/jobs/:id/status`         | Update status                          |
| GET    | `/api/jobs/:id/ranked-bids`    | AI-ranked bid list                     |
| GET    | `/api/tools`                   | List tools                             |
| POST   | `/api/tools`                   | Create tool (supplier only)            |
| POST   | `/api/tools/:id/rent`          | Rent a tool                            |
| GET    | `/api/messages/:jobId`         | Fetch chat history                     |
| POST   | `/api/messages/:jobId`         | Send a message                         |
| POST   | `/api/kyc`                     | Submit KYC                             |
| GET    | `/api/admin/users`             | List users (admin)                     |
| POST   | `/api/admin/kyc/:id/verify`    | Approve/reject KYC (admin)             |

All protected routes require an `Authorization: Bearer <JWT>` header.

## Notes & tradeoffs

For the full inventory of what works, what's stubbed, and what's missing
despite mentions elsewhere, read [`docs/STATUS.md`](./docs/STATUS.md). Highlights:

- **No Firebase**. Auth + push + uploads use MongoDB / JWT / multer / Socket.IO.
  The `USE_FIREBASE` env var is not read anywhere.
- **No payment gateway**. `Rental` records are created with amounts; no money moves.
- **AI ranking** is a deterministic weighted score (rating 0.40, completion 0.25,
  skill match 0.15, response 0.10, experience 0.10) — implemented in
  `ai-service/app/ranker.py` with an identical JS fallback in
  `backend/src/utils/ai.js`.
