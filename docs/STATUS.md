# Status — what's implemented, what isn't

An honest inventory. If anything here disagrees with the code, the code wins — please fix
the doc.

## Implemented end-to-end (v2)

**Accounts & security** — register/login (bcrypt, JWT), change password, profile + avatar
upload, technician professional profile, KYC with document photos and admin review, suspend /
reactivate (enforced on login, every request and live sockets), helmet, CORS allow-list, rate
limiting, validation on every write, field whitelists, image-only uploads.

**Jobs** — open jobs and direct requests, AI category/urgency suggestions, photos, urgency,
preferred date, budget, city; quotes with ETA and message; withdraw / decline; AI-ranked quotes
with reasons; hire (others auto-declined, agreed price stored); enforced status machine;
cancellation with reason; completion counted once; ratings and reviews; activity timeline;
search/filter/sort/pagination; contact details only after hire.

**AI** — Naive Bayes classifier (≈ 89 % on a held-out set, 12 categories), urgency detection,
explainable 8-factor ranking with urgency-aware weights for Smart Match and quotes,
responsiveness measured from real quote times, Bayesian rating smoothing, in-process JS
fallback with a parity test.

**Tools & rentals** — listings with photos, deposit, condition, stock, installments; search,
filters, sorting; rental requests with date ranges and pickup/delivery; supplier approve
(atomic stock reservation) / decline / mark returned / complete; renter cancel; overdue
detection; tool reviews; safe deletion.

**Communication** — job chat threads between a client and each technician (before and after
hiring), inbox with unread counts, read receipts, typing indicator, photo messages; in-app
notifications with deep links, unread badge and mark-all-read; realtime updates for every
cross-party event; online presence.

**Admin** — analytics dashboard with charts, user management, KYC queue, reports queue,
job/tool oversight, AI engine status.

**Engineering** — 54 backend tests (real MongoDB), 34 AI tests, 13 Flutter tests, GitHub
Actions CI, Dockerfiles + docker-compose, Windows scripts that keep dependencies in sync,
rich demo seed, analyzer-clean Flutter code, light/dark design system.

## Not implemented (known limitations)

- **Payments** — prices, deposits and installment plans are recorded but no money moves
  (no payment gateway). Installments are marked "fully paid" by the supplier manually.
- **Push notifications when the app is closed** — realtime delivery is Socket.IO only (works
  while the app is open). FCM/APNs would be the next step.
- **Email** — no SMTP: no email verification or self-service password reset (users can change
  their password while logged in; admins can create admin accounts with `create-admin`).
- **Maps / distance** — proximity uses city matching, not GPS distance.
- **File storage** — uploads are stored on the backend's disk (`backend/uploads`); for
  production use object storage (S3, Cloudinary…).
- **Scale** — technician recommendation scores all active technicians per request (fine for
  thousands; would need pre-filtering/indexing beyond that).

## Upgrading from v1

- Existing data works: new fields have defaults and the database is still `fixit`.
- Legacy rentals keep their status (`active` / `returned` / `completed`) and can be returned
  normally; new rentals start as `requested`.
- Run `setup.bat` (or just the start scripts — they now install new dependencies
  automatically).
- Chat messages no longer create notification entries (they have their own unread badge).

## Changelog

- **v2.0** — SureFix rebrand and redesign; AI Smart Match and explainable ranking; direct
  requests; rental request workflow; chat threads with read receipts/typing/photos; reports;
  admin analytics and suspension; security hardening; Express 5; Docker; CI; test suites.
- **v1.0** — MVP: jobs with bids, AI-ranked bids (weighted score), tools rent/buy, per-job chat,
  KYC, admin basics, Socket.IO toasts.
