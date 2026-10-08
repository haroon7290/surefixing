# FixIt Documentation

This folder is the single source of truth for what's actually in this repo.
The top-level `README.md` is a quick-start; everything else lives here.

## Index

| File | What it covers |
|---|---|
| [INSTALLATION.md](./INSTALLATION.md) | Prereqs per OS, install steps, environment vars, troubleshooting |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Component diagram, data model, REST API, Socket.IO events, request/response flows |
| [USER_GUIDE.md](./USER_GUIDE.md) | Step-by-step walkthrough for each of the four roles |
| [STATUS.md](./STATUS.md) | What's implemented, what's stubbed, what isn't here despite anything else saying otherwise |

## Honesty notes

A few things you'll see referenced in the codebase or the top-level README that
**do not actually work**:

- **Firebase**: The top-level README says "drop your credentials in
  `backend/firebase.json` and flip `USE_FIREBASE=true` in `.env`". There is
  **no Firebase code anywhere in the codebase**. No `firebase-admin` SDK,
  no FCM, no `USE_FIREBASE` checks. The env var sits unread. See
  [STATUS.md](./STATUS.md#not-implemented).
- **Payments**: `Rental` documents are created on rent/purchase, but no
  payment gateway is integrated. Money never moves.
- **KYC images**: The backend route accepts `multipart/form-data` with
  `idFront`/`idBack`/`selfie` files via multer. The mobile screen sends
  `application/json` with no files. KYC submissions therefore always have
  empty image fields.
- **Tool / avatar images**: Schema fields exist (`Tool.image`, `User.avatar`).
  No upload UI, no rendering.
- **Push notifications**: There is **no FCM/APNS**. Real-time push is over
  Socket.IO and only works while the app is open and connected.

If you find anything in the docs below that doesn't match the code, that's a
bug in the docs — file an issue or fix it.
