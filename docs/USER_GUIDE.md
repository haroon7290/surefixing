# User Guide

SureFix has four roles. Clients, technicians and suppliers sign up from the app
(**Create an account** → pick a role); admin accounts are created with
`npm run create-admin` in `backend/`.

The first launch shows a short onboarding. After login each role gets its own bottom
navigation; **Account** is always the last tab (profile, verification, notifications,
theme, password, logout).

> **Demo data:** run `scripts\reset-demo-data.bat` (wipes the database!). Every demo
> account uses the password `password123`; debug builds show one-tap demo buttons on the
> login screen.

| Demo account | Who |
|---|---|
| `client@demo.com` | Sara Khan (Lahore) — open jobs with quotes, an AC job in progress with chat, completed + reviewed jobs, an active drill rental |
| `client2@demo.com` | Bilal Ahmed (Karachi) — a direct request to Ahmad, a rental and an installment request, a report |
| `tech@demo.com` | Ahmad Raza — electrician & plumber, verified, 12 reviews, one direct request |
| `tech3@demo.com` | Usman Ali — AC specialist, hired on Sara's AC job |
| `tech2/4/5/6/7/8@demo.com` | Carpenter, painter (KYC pending), plumber, cleaner, a brand-new electrician, a busy locksmith |
| `supplier@demo.com` | ToolCo Rentals — 8 tools, pending requests, an overdue rental |
| `admin@demo.com` | Admin — pending KYC, an open report |

---

## Client

### Find a technician with Smart Match (AI)
1. **Home → "Describe your problem…"** (or tap a suggestion such as *AC not cooling*).
2. Write the problem in your own words, check your city and tap **Find the best technicians**.
3. SureFix shows what it understood — the trade (with AI confidence), how urgent it sounds
   and the words it picked up on. If it guessed wrong, tap the right trade and it re-ranks.
4. Each technician gets a **match %** with reasons (✓ specialisation, rating, completed jobs,
   response time, city, ID verified) and cautions (ⓘ new on SureFix, outside your city,
   currently busy).
5. **Request** sends the job privately to that technician; *Prefer to compare quotes?* posts
   it to everyone.

### Post a job
- **Post a job** (home or My jobs). As you describe the problem, the AI suggests the
  category and urgency — tap **Apply** (it applies automatically until you pick yourself).
- Add a budget (optional), preferred date, city, address (only shared with the technician you
  hire) and up to 5 photos.

### Compare quotes and hire
- **My jobs → the job.** Quotes are **ranked by the AI**: skills, reviews, reliability,
  response time, distance and price. Each shows the price, when they can start, their
  message, reasons and cautions such as *17 % over your budget*.
- **Ask** opens a chat with that technician before you hire. **Hire** accepts the quote;
  the others are declined automatically and you can now see each other's phone numbers.
- A direct request shows *Waiting for … to respond*. If they decline, tap
  **Open to all technicians**.

### During and after the job
- Chat from the job or the **Messages** tab (photos, read receipts ✓✓, typing indicator).
- **Mark as completed**, then rate 1–5 ★ with a review. The **Activity** timeline shows every
  step. Cancel any time before completion from the ⋮ menu (with a reason).
- Report a technician from the ⋮ menu or their profile (🚩).

### Technicians directory
**Home → All technicians** or tap a service tile. Search, filter (available now, verified,
trade), sort (top rated, most jobs, lowest rate). Profiles show stats, about, skills, the star
breakdown and every review, with **Request** at the bottom.

### Rent or buy tools
- **Tools** tab: search, filter by category / in stock / installments, sort by price or rating.
- **Rent**: choose dates, pickup or delivery, add a note — the sheet shows days × price,
  deposit and the total. The supplier approves before anything is reserved.
- **Installments**: request a monthly plan where offered.
- **My rentals** (receipt icon on the Tools tab, or Account): cancel pending requests, see
  days left / overdue, and review a tool once it's returned.

---

## Technician

- **Home**: availability switch (turn off when fully booked — you'll rank lower in Smart Match),
  earnings, active jobs, quotes awaiting reply, rating; prompts to get verified and complete
  your profile; **direct requests**; jobs matching your skills.
- **Find work**: open jobs with search and filters (my skills, my city, urgent / emergency,
  trade, highest budget). New jobs arrive live (*N new jobs — tap to refresh*).
- **Job detail**: client, details (address appears after you're hired), how many other quotes
  and the lowest. **Send a quote** (price — pre-filled with the budget — start day, message),
  **Decline** a direct request, **Withdraw** a pending quote, **Chat** with the client, and
  **Mark as completed** once hired.
- **My jobs**: Requests · Quoted · Active · Completed.
- **Account → Edit profile**: photo, headline, about, skills (the biggest factor in AI
  ranking), hourly rate, years of experience, availability. **Identity verification** adds the
  verified badge.

How you're ranked: skills match, Bayesian-smoothed rating, completed-vs-hired jobs, how fast
you usually quote, experience, distance, availability and verification (plus price on quotes).

---

## Supplier

- **Home**: rental revenue, tools listed, new requests, items out on rent, **overdue returns**,
  and requests waiting for you with Approve / Decline buttons.
- **My tools**: grid of your listings with stock. **Add tool** / tap to edit: up to 4 photos,
  category, condition, pickup city, price per day, deposit, sale price, installments (months ×
  monthly), stock, and *Listed in the marketplace*. Delete from the editor (blocked while a
  rental is active).
- **Requests**: Pending (approve reserves one unit of stock; decline with a reason) · Active
  (**Mark returned** puts it back in stock; installment plans → **Mark fully paid**) · History.

---

## Admin

- **Overview**: users, jobs, completed job value, rental value, KYC to review, open reports,
  average technician rating, suspended accounts; 7-day charts for new jobs and sign-ups; jobs by
  status, users by role, most requested services; AI engine online/fallback.
- **Users**: search by name/email/phone/city, filter by role or suspended. Tap a user to
  suspend (logs them out immediately), reactivate or delete.
- **Verify**: KYC queue with ID front/back and selfie (tap to zoom). Approve, or reject with a
  reason the user sees.
- **Reports**: open reports with reason and details. Dismiss, resolve, or resolve and suspend
  the reported user. The reporter is notified.
- **Account → All jobs / All tools** for oversight; tool listings can be removed.

---

## Everyone

- **Notifications** (bell on dashboards, or Account): grouped by day, unread highlighted,
  **Mark all read**, and tapping one opens the related job, rental or tool.
- **Realtime**: quotes, hires, status changes, rentals and messages arrive instantly with a
  toast; a *Reconnecting…* banner appears if the live connection drops.
- **Theme**: Account → Theme → light / system / dark.
