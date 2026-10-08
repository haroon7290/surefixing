# Status — what's here, what isn't

Written to be honest about what the codebase actually does. If something in
another file contradicts this, trust the code (and the tests-of-the-code
here), not the other file.

## Implemented end-to-end

These work across backend + mobile + (where relevant) AI service, real data
round-trips:

### Auth
- [x] Register (client / technician / supplier) with bcrypt-hashed password
- [x] Login returning a 7-day JWT
- [x] `Authorization: Bearer <jwt>` middleware on every protected route
- [x] Socket.IO handshake auth using the same JWT
- [x] Logout clears local token + disconnects socket

### Jobs (client / technician)
- [x] Client posts a job
- [x] Technicians see all pending jobs
- [x] Technician places a bid (one per tech per job; `amount > 0`)
- [x] Technician withdraws own bid (pending status only)
- [x] Client views AI-ranked bids with 0–5 score
- [x] Client accepts a bid → job becomes `in_progress`, tech assigned
- [x] Either party marks `completed` (tech only when assigned)
- [x] On completion: `completedAt` recorded, tech's `jobsCompleted` incremented
- [x] Client rates 1–5 + optional review → tech's running average updated
- [x] Self-awareness: "You bid" badge in tech's Open list; own bid hidden
      from the "Other bids" section
- [x] Real-time toast + list reload on every cross-party event
      (new job broadcast, new bid, bid withdrawn, hired, status change,
      rating)

### Tools (supplier / any renter)
- [x] Supplier adds / deletes their tools (update route exists, no UI)
- [x] Any other user can rent (by days) or buy on installment
- [x] Backend refuses self-rent / self-purchase (defensive — UI doesn't
      expose it either: suppliers have no tools-browsing tab)
- [x] Stock decrements on rent/purchase; `available=false` at 0
- [x] `Rental` document recorded for each transaction
- [x] Supplier's "Incoming rentals" tab lists all rentals/purchases on
      their tools
- [x] Real-time toast to supplier on each rent/purchase

### Messages
- [x] 1:1 chat per job between client and assigned technician
- [x] Server enforces participant-only access (admin can read)
- [x] Live append via Socket.IO; 15s poll as a fallback
- [x] Smart auto-scroll (only when already at bottom, always for own msgs)

### Notifications
- [x] Every cross-party event creates a `Notification` doc
- [x] Last 50 listed per user, newest first
- [x] Mark-as-read endpoint + UI
- [x] Live-prepend on the notifications screen via socket

### KYC
- [x] Tech/supplier submits name + ID type + ID number
- [x] Admin sees a list, can approve or reject with a reason
- [x] User's `kycStatus` updates on verdict; user gets a realtime toast
- [x] KYC screen re-fetches user on open so stale cached status refreshes

### Admin
- [x] Dashboard stats (users, jobs, tools, pending KYC counts)
- [x] Users list with role filter; self-marked "You", self-delete blocked
- [x] User deletion (hard delete)
- [x] KYC queue with approve/reject

### Platform
- [x] MongoDB persistence
- [x] Seeder with 4 roles × 5 demo accounts + 2 jobs + 3 tools
- [x] Local file uploads via multer (only wired for KYC multipart route;
      no screen actually attaches files)
- [x] AI-service HTTP call with transparent JS fallback on failure
- [x] Socket.IO room-based delivery (`user:<id>`, `role:<role>`)
- [x] Flutter runs on web (the tested target); platform folders can be
      generated for Android / iOS / Linux desktop via `flutter create`

---

## Partially implemented

### KYC image upload — backend only
- Backend route accepts `multipart/form-data` with `idFront`, `idBack`,
  `selfie` fields via multer. Files land in `backend/uploads/` and the
  filenames go into the Kyc doc.
- **Mobile `KycScreen` sends JSON with no files.** Comment in
  `kyc_screen.dart:44-47` is explicit: "Multipart image upload is out of
  scope for this MVP screen."
- Net effect: every KYC doc has empty `idFrontImage` / `idBackImage` /
  `selfieImage` strings. Admin still gets a submission and can verdict it.

### Installment purchases — record only
- Backend creates a `Rental` of type `installment` with `monthsRemaining`
  set. No scheduler, no payment processor, no recurring charge. Amount is
  stored, not collected.

### Avatars + tool images
- `User.avatar` (`string`) and `Tool.image` (`string`) fields exist in the
  schemas. No upload endpoints for them, no file picker in the UI, no
  rendering — profile shows initials, tool cards are text-only.

### User public profile
- `GET /api/users/:id` returns a technician's public data (rating, jobs, etc).
- The mobile app doesn't have a screen that consumes it — it only reads
  technician info from populated sub-documents (bids, assigned job).

### Tool PATCH endpoint
- `PATCH /api/tools/:id` exists for suppliers to edit. No mobile screen
  uses it — supplier can only delete + re-add.

### `GET /api/users/technicians`
- Endpoint exists and returns all technicians. No screen consumes it.

---

## Not implemented

Anything in this section does not exist despite mentions elsewhere.

- **Firebase** — the top-level `README.md` line 115 says to drop
  `backend/firebase.json` + flip `USE_FIREBASE=true`. There is no
  `firebase-admin` dependency, no Firebase code anywhere, no code reads
  `USE_FIREBASE`. The README claim is stale / aspirational.
- **FCM / APNS push notifications** — real-time delivery is Socket.IO
  only. Closed-app push does not exist.
- **Payment gateway** — no Stripe / PayPal / anything. Rentals and
  installment purchases record amounts but nothing charges.
- **Tests** — zero. No backend tests, no mobile widget tests, no AI
  service tests, no CI pipeline.
- **Production deployment** — no Dockerfile, no `docker-compose.yaml`,
  no reverse-proxy config, no TLS setup, no production env template.
  CORS is wide-open (`origin: '*'`).
- **Rate limiting / request throttling** — none.
- **Email** — no SMTP / Resend / SendGrid. Notifications are in-app only.
- **Search** — no free-text search on jobs or tools. Only the
  `mine=1` and `role=` filters.
- **Pagination** — `GET /api/users/me/notifications` limits to 50; every
  other list endpoint returns the full collection.
- **Admin provisioning flow** — no admin invite / promotion. Admin users
  exist only via the seeder or direct DB insert; `/api/auth/register`
  returns 403 for `role: admin`.
- **Stock return on rental end** — `/api/tools/:id/rent` decrements stock;
  there's no "return" endpoint that increments it back. Active rentals
  don't auto-close.
- **Soft delete / audit log** — user/tool delete is a hard delete. No
  history of who did what when.
- **Password reset / email verification** — no flows exist.
- **Job-cancel flow in the UI** — the `cancelled` status is in the
  `Job.STATUSES` enum and the PATCH route accepts it, but no screen
  exposes a Cancel button.
- **Pull-to-refresh is inconsistent** — client-home jobs, tools list,
  admin tabs all have `RefreshIndicator`; supplier rentals and
  notifications have it; but the tech "Open/My work" lists do (via
  `RefreshIndicator` in `_JobsListState.build`), messages screen does not
  (it uses polling + live socket append).
- **Attachments in chat** — text-only messages.

---

## Known rough edges

- `mobile/README.md` tells you to hand-edit `lib/services/api_config.dart`
  for the backend URL. That advice is outdated — `api_config.dart` now
  picks the right default per platform and honors
  `--dart-define=API_BASE_URL=...` at build time.
- `ai-service/README.md` documents the old weights (pre-skill-match).
  The current weights are in [ARCHITECTURE.md](./ARCHITECTURE.md#scoring)
  and in code (`ai-service/app/ranker.py`).
- Top-level `README.md` documents an AI weight mix that's out of sync with
  the code (see above) and mentions Firebase (see above).
- The supplier has no way to see their tools' full history — only active
  rentals on "Incoming rentals". Completed / returned rentals still
  appear (no filter).
- Messages-screen scroll: if you're NOT at the bottom and a new message
  arrives from the other side, it's appended silently (no "new messages"
  pill). You have to scroll down manually.
- `logging` (1.3.0) and `js` (0.6.7) show up as transitive Flutter
  dependencies — these are not direct choices, `flutter pub get` pulled
  them in. Safe to ignore.

---

## Changelog (high-level)

Chronological since initial commit — see `git log` for the full record.

- **Initial commit** — MVP REST backend, Flutter app, AI service, WSL install scripts.
- **start-mobile resilience** — detect Windows-side Flutter under WSL;
  auto-pick device (chrome → web on WSL → linux → first); pop Windows Chrome
  via `cmd.exe` when using `web`.
- **api_config per-platform** — web → localhost, Android emulator →
  `10.0.2.2`, override via `--dart-define`.
- **client-home refresh bug** — FAB `setState` was a no-op over a `const`
  child; fixed with a ValueKey bump.
- **cross-role bug sweep** — stale local user after profile/KYC edits
  (added `AuthService.refreshUser`), tools-list no refresh after rent/buy,
  bid amount ≤ 0 accepted, supplier KYC access.
- **Socket.IO real-time + toasts** — new `utils/realtime.js` + mobile
  `RealtimeService`, global `ScaffoldMessengerKey`, event-driven list
  refreshes for all roles, supplier "Incoming rentals" tab, AI skill
  weighting, smart-scroll messages, `DELETE /api/jobs/:id/bids/me` for
  bid cancellation.
- **Self-awareness sweep** — "You bid" badge, "Other bids" hides self,
  admin "You" badge + self-delete guard, supplier can't rent/buy own tool.
- **Auto-pick defaults to `web` on WSL** — plain `./scripts/start-mobile.sh`
  works without `TARGET=`.
