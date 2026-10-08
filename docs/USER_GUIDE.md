# User Guide

The app has four roles. The role is chosen at registration (admin can't be
self-registered — see [Admin](#admin)).

After login, the app routes to the role-specific home screen. The drawer
(hamburger menu) is shared and contains: **Profile**, **Notifications**,
**KYC verification** (technicians + suppliers only), and **Log out**.

A toast (snackbar) appears for every action that succeeds or fails, and for
every relevant cross-role event delivered over Socket.IO in real time.

---

## Demo data

After `npm run seed` (auto-run by `start-backend.sh` on first launch with an
empty DB), these accounts exist. Password is `password123` for all.

| Role | Email | Notes |
|---|---|---|
| Client | `client@demo.com` | Sara Client |
| Technician | `tech@demo.com` | Ahmad Tech — plumbing/electrical, KYC approved, rating 4.6 |
| Technician | `tech2@demo.com` | Noor Fix — carpentry, KYC approved, rating 4.1 |
| Supplier | `supplier@demo.com` | ToolCo — owns the seeded tools |
| Admin | `admin@demo.com` | — |

Plus 2 jobs ("Fix leaking kitchen sink" with 2 bids, "Install ceiling fan"
with no bids) and 3 tools (Bosch drill, pipe-wrench set, tile cutter).

---

## Common to all roles

### Login / Register

- `LoginScreen` (`mobile/lib/screens/auth/login_screen.dart`) — email +
  password. Demo email/password are pre-filled to speed up testing.
- "Create an account" → `RegisterScreen`. Pick role (client / technician /
  supplier — admin is not in the segmented control).

### Profile

- `ProfileScreen` (drawer → Profile). Edit name, phone, bio. Technicians also
  edit `skills` (comma-separated).
- Technicians additionally see: rating + count, jobs completed/assigned, avg
  response, current KYC status.
- Save → PATCH `/api/users/me` → local `User` is refreshed via
  `AuthService.refreshUser()` so the drawer header updates immediately.

### Notifications

- Drawer → Notifications. Lists the last 50, newest first.
- Live-prepends new notifications via the `notification` Socket.IO event.
- Tap a notification → marks read on the server + reloads.

### KYC verification (technician + supplier only)

- Drawer → KYC verification. Enter full name, ID type
  (CNIC / passport / driver_license), ID number.
- Submission goes to `POST /api/kyc` and sets `user.kycStatus = pending`.
- The screen also re-fetches the user on open so any admin verdict that
  arrived while you were away is reflected.
- **Image upload is not implemented in this screen** — the form sends JSON
  only. Admin still gets a submission to review (without images).

### Logout

Drawer → Log out. Disconnects the realtime socket and `pushAndRemoveUntil`
back to the login screen.

---

## Client

Home: `ClientHome` with two bottom-nav tabs.

### Tab 1 — My jobs

- Lists all jobs you've posted, newest first. Empty state explains how to
  post one.
- FAB "Post job" → `PostJobScreen`:
  - Title (required)
  - Description (required)
  - Category dropdown: plumbing / electrical / carpentry / painting /
    appliance / general
  - Budget ($) — optional, accepts 0
  - Location / address — optional
  - Submit → POST `/api/jobs`. List refreshes via key bump on return.

- Tap a job → `JobDetailClient`:
  - Job summary + status chip + budget.
  - **Bids** section — AI-ranked. Each card shows the technician's name,
    AI score (0–5), bid amount, ETA in days, message, rating with count.
    `Accept bid` button on each (only when job is `pending`). Accepted bid
    gets a green chip.
  - When job is `in_progress`: `Mark completed` button.
  - When job is `completed` and not yet rated: `Rate & review` (1–5 stars
    + optional review).
  - When a tech is assigned: chat icon in the app bar → `MessagesScreen`.

### Real-time events you receive

- New bid arrives → toast "New bid on your job — Ahmad bid 75". List reloads.
- Bid withdrawn → toast "Bid withdrawn". List reloads.
- Status update from the assigned tech → toast.

### Tab 2 — Rent / Buy tools

- `ToolsListScreen` — all tools from all suppliers.
- Each card: name, description, rent $/day, buy $ (with installments if
  configured), Rent / Buy buttons.
- **Rent**: dialog asks for days. POST `/api/tools/:id/rent` → snackbar with
  total cost. Stock decrements server-side.
- **Buy on installments**: shown only if `installmentMonths > 0`. Confirm
  dialog shows months × monthly. POST `/api/tools/:id/purchase`.

---

## Technician

Home: `TechHome` with two bottom-nav tabs.

### Tab 1 — Open jobs

- All jobs in `pending` status (across all clients).
- Each job card shows: title, description (2 lines), status chip, budget,
  number of bids. **A small "You bid" badge appears if you've already bid
  on this job** — you can still tap in to view, withdraw, or watch others.
- Tap → `TechJobDetail`.

### Tab 2 — My work

- Jobs where you're the assigned technician.
- Same card layout. Tap → `TechJobDetail`.

### Job detail (`TechJobDetail`)

- Top: status chip, budget, description, location, "Posted by".
- **If pending and you haven't bid**: `Place bid` button → dialog
  (amount, ETA days, message). Backend rejects amount ≤ 0.
- **If you have a bid**: indigo "Your bid" card with status chip. While the
  bid is `pending`, a `Cancel bid` button appears. Cancelling fires
  `DELETE /api/jobs/:id/bids/me` and notifies the client.
- **Other bids on this job (N)** — lists every bid except yours, with
  technician name, ETA, amount.
- **If you're the assigned tech and job is `in_progress`**: `Mark completed`
  button → PATCH `/api/jobs/:id/status` with `completed`.
- **If you're the assigned tech**: chat icon → `MessagesScreen`.

### Real-time events you receive

- Any client posts a job → toast "New job posted: …", Open-jobs tab reloads.
- A client accepts your bid → toast "Bid accepted", My-work tab reloads.
- A client (or anyone) changes a job's status while it's yours → toast.
- A client rates your job → toast "New 5★ rating".

---

## Supplier

Home: `SupplierHome` with two bottom-nav tabs.

### Tab 1 — My tools

- Lists tools you own (`GET /api/tools?mine=1`).
- Each row: name, "Rent $X/day · Buy $Y · stock N", red trash icon to delete.
- Delete asks for confirmation, then `DELETE /api/tools/:id` and reloads
  with a snackbar.
- FAB "Add tool" → `AddToolScreen`:
  - Name (required)
  - Description
  - Category: power / hand / measurement / plumbing / electrical / general
  - Rent price per day, purchase price
  - Installment months (0 = no installment plan), monthly amount
  - Stock
  - Submit → POST `/api/tools`. List refreshes on return.

### Tab 2 — Rentals

- `_IncomingRentalsTab` — every rental + installment-purchase against your
  tools (`GET /api/tools/me/incoming`).
- Each row shows: tool name, renter name, type (rent / installment), days /
  months, total cost, timestamp, status.

### Real-time events you receive

- Anyone rents one of your tools → toast "Tool rented" (and the same goes
  for installment purchases). The rentals tab key bumps so it reloads with
  the new entry visible.

### Notes

- The tools-browsing screen (`ToolsListScreen`) is **not** mounted in the
  supplier home — suppliers don't browse other suppliers' tools in this
  build. The backend defends self-rent / self-purchase regardless.
- KYC link is in the drawer for suppliers (same flow as technicians).

---

## Admin

Home: `AdminHome` with three bottom-nav tabs.

### Tab 1 — Dashboard

- Four stat cards: total Users, total Jobs, total Tools, pending KYC count.
- `RefreshIndicator` re-fetches via `GET /api/admin/stats`.

### Tab 2 — Users

- `SegmentedButton` filter: All / Clients / Techs / Suppliers (admins are
  in "All" only).
- For each user: avatar with initial, name, email, role, KYC status, red
  trash icon. **Your own row** shows a "You" badge instead of the trash icon
  — the API also rejects DELETE on your own id.
- Delete → confirmation → `DELETE /api/admin/users/:id`.

### Tab 3 — KYC review

- All KYC submissions from `GET /api/admin/kyc`, newest first, populated
  with user info.
- Each card: full name, status chip, user name + role, ID type + number.
- For `pending` status: **Reject** (asks for reason) and **Approve** buttons.
- Verdict → `POST /api/admin/kyc/:id/verify` updates KYC + user, notifies the
  submitter.

### Notes

- Admin accounts can **only be created by the seeder** (`backend/src/utils/seed.js`)
  or by inserting directly into Mongo. The `/api/auth/register` route returns
  403 for `role: admin`.
- Admin **does not** have a KYC link in the drawer (the drawer only shows
  KYC for technicians and suppliers).

---

## Cross-role flows worth seeing

Open two browser windows side-by-side (one regular, one private) and log in
as two different roles to watch real-time push:

1. **Client posts a job → all techs get a toast.**
2. **Tech bids → only that client gets the toast + the bids panel reloads.**
3. **Client accepts → only the winning tech gets the toast + their My-work tab reloads.**
4. **Either marks complete → the other gets a toast.**
5. **Client rates → tech gets a toast.**
6. **Client/tech rents/buys a tool → only that tool's supplier gets a toast and their Rentals tab reloads.**
7. **Either side messages → the other side's chat appends without waiting (the 15-second poll is just a safety net).**
8. **Admin approves/rejects KYC → that user gets a toast and their KYC screen status updates on next open.**
