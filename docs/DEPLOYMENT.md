# Deploying SureFix (free) and updating it while it is live

| Part | Where | How it updates |
|---|---|---|
| Database | MongoDB Atlas, free M0 cluster | Data stays across deploys |
| Backend API + realtime | Render web service `surefix-api` (`render.yaml`) | Every push to `main` |
| AI service | Render web service `surefix-ai` (`render.yaml`) | Every push to `main` |
| Website | GitHub Pages (`.github/workflows/website.yml`) | Every push to `main` that changes `mobile/` |
| Android app | APK built by `.github/workflows/android.yml` | Every push to `main` that changes `mobile/`; install the new APK |

## One-time setup

1. **Atlas.** Create a free M0 cluster (AWS, Singapore or Mumbai), a database user with an
   auto-generated password, and allow access from anywhere (`0.0.0.0/0`). Copy the connection
   string, put the password in and add the database name after `.mongodb.net/`:
   `mongodb+srv://surefix:PASSWORD@cluster.xxxxx.mongodb.net/surefix?retryWrites=true&w=majority`
2. **Load data once**, from your PC: set `MONGO_URI` in `backend\.env` to that string, run
   `npm run seed -- --force` (demo data) or `npm run create-admin` (empty, your own admin) in
   `backend`, then set `.env` back to `mongodb://localhost:27017/surefix`.
3. **Render.** Sign in with GitHub → **New → Blueprint** → choose this repository → paste the
   Atlas string when it asks for `MONGO_URI` → **Apply**. It creates `surefix-api` and
   `surefix-ai`. Check `https://surefix-api.onrender.com/api/health` says `"ok": true`.
   If Render gave either service a different address, fix it in two places: the backend's
   `AI_SERVICE_URL` (Render dashboard → surefix-api → Environment) and the `API_BASE_URL`
   variable in step 4.
4. **Website.** GitHub → repository **Settings → Pages → Source: GitHub Actions**. Optional:
   **Settings → Secrets and variables → Actions → Variables** → `API_BASE_URL` (only if the
   backend address differs from `https://surefix-api.onrender.com`) and `DEMO` = `true` to show
   the demo log-in buttons. Then **Actions → Website → Run workflow**. The site is at
   `https://haroon7290.github.io/surefixing/`.
5. **Android.** **Actions → Android app → Run workflow** (it also runs on every app change).
   Open the finished run, download **surefix-apk** under *Artifacts*, unzip and install
   `app-release.apk` on the phone (allow "install unknown apps").
6. **Secure it.** The demo accounts use `password123`, which the README publishes. Log in to the
   live site as `admin@demo.com` and change the password (Account → Change password), or seed
   with `create-admin` instead. Add `SMTP_URL` (e.g. a Gmail app password) in Render so
   password-reset codes are emailed — in production they are not shown on screen.

## Firebase Authentication (sign-in and password-reset emails)

With Firebase, Google checks passwords and emails password-reset links; SureFix keeps its own
users and sessions (the app exchanges each Firebase sign-in at `POST /api/auth/firebase`).
Without it, the backend's own email + password login is used everywhere.

1. **Firebase console** (console.firebase.google.com) → **Add project** → name it `surefix`
   (Google Analytics off is fine).
2. **Build → Authentication → Get started → Sign-in method → Email/Password → Enable → Save.**
   Under **Settings → Authorized domains** add `haroon7290.github.io` (`localhost` is there
   already).
3. **Project settings (gear) → Your apps**: add a **Web** app (nickname `SureFix web`) and an
   **Android** app (package name `com.surefix.app`). The values shown (apiKey, projectId,
   messagingSenderId, appId for web and Android) are public; they go in
   `mobile/lib/core/firebase_login.dart` (or as `--dart-define`s).
4. **Project settings → Service accounts → Generate new private key.** This file is secret:
   never commit it or paste it anywhere public. On Render (surefix-api → Environment) add
   `FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT` (the whole JSON on one line). For local
   development put the same two in `backend\.env`.
5. Redeploy. On start-up the backend copies every existing account into Firebase **with its
   current password** (log line: `Firebase: N accounts copied`), so nobody has to reset.
6. Optional: **Authentication → Templates → Password reset** to change the email's sender name
   and wording.

Accounts in Firebase can't use the old login route any more (their password now lives in
Firebase), so install the new app build after switching.

## Changing things while it is live

- Work on your PC against your **local** database, test (`.\scripts\test-all.bat`), then commit
  and push to `main`. Render redeploys the backend and AI service in 2–3 minutes; the website
  rebuilds in 3–4 minutes (visitors may need a hard refresh); a new APK appears under Actions.
- Quick edits without your PC: press `.` on the GitHub repository page to open the web editor,
  edit, commit to `main`. The same deploys follow.
- Installed APKs keep running the old app until you install the new one, but they already use
  the new backend — avoid removing or renaming fields the app reads. Raise `version:` in
  `mobile/pubspec.yaml` for each APK you hand out.
- Company bank accounts, users, verifications and reports are managed in the admin screens —
  no deploy needed.
- **Never** run `npm run seed -- --force` or `reset-demo-data.bat` against the Atlas database
  once real people use it: it wipes everything.

## Free-tier limits

- Render free services **sleep after 15 minutes** without traffic; the first request then takes
  about 50 seconds. The **Keep backend awake** workflow (`.github/workflows/keep-awake.yml`) pings
  `/api/health` every 10 minutes to prevent that. GitHub sometimes runs scheduled jobs late, so
  for a guaranteed ping add a free monitor (e.g. UptimeRobot, every 5 minutes) on
  `https://surefix-api.onrender.com/api/health`. One always-on free service uses ~730 of
  Render's 750 free hours a month, so keep the AI service asleep (the backend falls back).
- **Uploaded photos** (avatars, job and tool photos, ID documents) are stored on the backend's
  disk, which Render's free plan wipes on every deploy or restart. Fine for a demo; for real use
  move uploads to object storage (e.g. Cloudinary) or a paid Render disk.
- Atlas M0 has 512 MB, plenty for a project of this size.
