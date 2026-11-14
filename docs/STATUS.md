# Status — what is implemented, what is not

An honest inventory. If anything here disagrees with the code, the code wins — please fix
the doc.

## Implemented end to end (v3)

**Accounts & security** — register / log in (bcrypt, JWT), change password, **password reset
by 6-digit code** (emailed with SMTP, shown on screen without it), profile and avatar,
technician professional profile with **portfolio**, identity verification with document
photos and admin review, suspend / reactivate (enforced on login, every request and live
sockets), **safe account deletion** by admins, helmet, CORS allow-list, rate limiting,
validation on every write, image-only uploads.

**Jobs** — open jobs and direct requests; AI category and urgency suggestions with a **price
estimate** learned from completed jobs; photos, budget, preferred date; quotes with ETA and
message; AI-ranked quotes with reasons; **hire with wallet (escrow) or cash**; **progress
stages** (hired → on the way → working → finished) reported by the technician; work report
with photos; **client confirmation** releases the payment, with an automatic window after
which the technician may close the job; cancel before work starts (refund, no penalty);
technician withdrawal (refund, job reopens); ratings and reviews; activity log; search,
filters and sorting; contact details only after hire; technicians never see competitors'
prices.

**Wallet & payments** — balance with a full ledger; **deposits by bank / mobile-wallet
transfer** (the user submits the amount, transaction ID and an optional screenshot; an admin
approves or rejects; duplicate transaction IDs refused; a deposit can't be approved twice);
**withdrawals by request** (amount set aside at once, admin pays out and approves, or rejects
and the money returns); admin-managed company accounts; escrow
hold, release and refund for jobs and rentals; platform fee on release; atomic debits that
cannot overdraw; live balance updates; admin ledger and revenue reporting.

**Locations & near-me search** — users, jobs and tools have a map point (GPS, a map pin or one
of ~70 named areas) with a 2dsphere index; technician directory, tool market and job market
search within a radius or sort nearest first, with distances on every card; technicians set
how far they travel (*Travels to me* filter); exact coordinates never leave the server; filter
panel on the website and a filter sheet on phones.

**AI** — Naive Bayes classifier over 12 trades, urgency detection, explainable 8-factor
ranking for Smart Match and quotes (proximity from real distance), responsiveness measured from real quote times, an
in-process JavaScript fallback kept identical by a parity test.

**Tools & rentals** — listings with photos, deposit, condition, stock and installment terms;
search, filters, sorting; rental requests with dates, pickup or delivery and a payment
choice; supplier approve (atomic stock reservation) / decline / mark returned; **late fees**
taken from the deposit; **installment plans** paid monthly from the wallet or recorded as
cash; renter cancel; reviews; favourites.

**Communication** — job chat between a client and each technician, tool chat between a
customer and the supplier, inbox with unread counts, read receipts, typing indicator, photo
messages; notifications that open the right screen; realtime updates for every cross-party
event; online presence.

**Admin** — overview with revenue, escrow and 7-day charts; users (search, suspend, delete);
verification queue; reports queue; **dispute resolution** on any job in progress (refund or
release); all jobs and tools; payments ledger; AI engine status.

**App & website** — one Flutter codebase. Phones: bottom tab bar, dashboards per role, light
and dark themes, first-launch introduction. Wide windows: a public marketing site (landing
page with a live AI estimate box, directories, how it works, help, terms, privacy) and a
sidebar web app for every role, two-pane messages, addresses for jobs, tools and technicians.

**Engineering** — 92 backend tests (real MongoDB), 34 AI tests, 43 app tests (every screen
rendered at phone and desktop size), GitHub Actions CI, Dockerfiles and docker-compose,
Windows scripts that keep dependencies in sync and detect old data, rich demo seed,
analyzer-clean Flutter code.

## Not implemented (known limitations)

- **Payment gateway** — money moves by manual bank / mobile-wallet transfer, checked by an
  admin. Nothing is charged automatically and payouts are sent by hand.
- **Push notifications when the app is closed** — delivery is Socket.IO only (works while
  the app is open). FCM / APNs would be the next step.
- **Automatic job closing** — after the confirmation window the technician can close the job
  with one tap; nothing closes it on a timer.
- **Maps** — the map picker needs internet for OpenStreetMap tiles and distances are straight
  lines, not driving routes. Areas cover 10 cities; elsewhere users pick a spot on the map.
- **Installment reminders** — due dates are not scheduled; the buyer pays or the supplier
  records each month.
- **File storage** — uploads live on the backend's disk (`backend/uploads`); production would
  use object storage.
- **Scale** — recommendation scores every active technician per request (fine for thousands).
- **Languages** — English only; prices in rupees.

## Upgrading from v2

The data format changed (job stages and payments, the activity log, rentals), so **old data
does not carry over**:

1. Pull, then run `.\setup.bat`.
2. Run `.\scripts\reset-demo-data.bat` once. It wipes the database and loads the v3 demo data.
   (`start-backend.bat` warns you if it finds old data.)
3. The default database name is now `surefix`. If your `backend\.env` still says `fixit`,
   either leave it (after the reset it is fine) or change it.
4. The Android app id changed to `com.surefix.app`, so the phone installs it as a new app —
   uninstall the old "SureFix" first.

## Changelog

- **v3.2** — Near-me search: location from GPS, a map pin or an area list; distances on every
  technician, tool and job card; radius, *Travels to me*, rating, price, urgency and budget
  filters in a new filter panel (website) and filter sheet (phone); nearest-first sorting;
  technicians' travel range; job and shop locations; distance-aware Smart Match and quote
  ranking. **Run `.\scripts\reset-demo-data.bat` once** so the demo accounts get locations.

- **v3.1** — Navigation fixes: working account menu and Account link on the website; attached
  phone tab bar (taps no longer land on tabs); hidden tabs can't take focus; Android and
  browser back return to Home; no double-opened pages; mouse-draggable rows and wrapping
  filters on the website. New payments: deposits by transaction ID and withdrawals by request,
  both approved by an admin; company accounts managed in the app; the sandbox top-up is gone.

- **v3.0** — Rebuilt app and website on a new design system (ink + safety orange,
  Bricolage Grotesque, Phosphor icons, new brand mark). Escrow wallet with ledger and fees;
  job stages with client confirmation; cash or wallet when hiring and renting; late fees;
  installment payments; password reset; favourites; portfolio; price estimates;
  testimonials; admin disputes, payments ledger and safe user deletion. Backend rules moved
  into services; legacy endpoints removed.
- **v2.2** — Tool handover details (pickup / delivery addresses, phones on approval);
  customer ↔ supplier chat per tool.
- **v2.1** — Website layout for wide screens; signed-out read access.
- **v2.0** — SureFix rebrand; AI Smart Match and explainable ranking; direct requests; rental
  requests; chat with read receipts; reports; admin analytics; security hardening; Docker; CI.
- **v1.0** — MVP: jobs with bids, AI-ranked bids, tools rent / buy, per-job chat, KYC.
