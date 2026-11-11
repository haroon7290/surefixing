# SureFix app and website (Flutter)

```bash
flutter pub get
flutter run                               # pick a device
flutter run -d chrome --web-port 8080     # the website (window wider than 1000 px)
flutter analyze && flutter test
```

Requires Flutter 3.35+ (Dart 3.9). Targets Android, iOS, web and Windows from one codebase.

## Build-time options

| Flag | Default | Purpose |
|---|---|---|
| `--dart-define=API_BASE_URL=http://host:4000` | `http://localhost:4000` | Backend address (`10.0.2.2` for the Android emulator; `adb reverse tcp:4000 tcp:4000` for a USB phone) |
| `--dart-define=DEMO=false` | `true` | Hide the one-tap demo accounts on the log-in screen |

## Structure

```
lib/
├── main.dart · app.dart · routes.dart   start-up, root gate, realtime toasts, addressable pages
├── kit.dart          the one import a screen needs (tokens, components, models, services)
├── core/             theme · api · session · realtime · nav · format · catalog · responsive
├── models/           user · job · tool (+ rental) · chat · wallet · json
├── ui/               the component library: brand, buttons, inputs, cards, pills, states,
│                     media, sheets, charts, page scaffolding, icons
└── features/
    ├── shell/        sections per role, floating dock (phone), web frame + sidebar (wide)
    ├── site/         public website: header, footer, landing, how it works, help, legal
    ├── auth/         introduction, log in, sign up, password reset
    ├── home/         customer, technician and supplier dashboards
    ├── jobs/         post a job, job page (all roles), lists, Smart Match
    ├── technicians/  directory and profile
    ├── tools/        market, tool page, inventory, tool form
    ├── rentals/      rentals, orders, rental page
    ├── wallet/       wallet, ledger, top-up, the "how will you pay" sheet
    ├── chat/         inbox and conversation
    ├── account/      account, profile, verification, notifications, saved, report
    └── admin/        overview, users, verification, reports, jobs, tools, payments
test/
├── fake_api.dart     a stand-in backend that answers every endpoint
└── app_test.dart     models, components, every screen at phone + desktop size, key flows
```

## Design system

- **Identity**: ink `#14161B` and safety orange `#FF5A1F` on warm paper `#F6F3EE`; blue is
  reserved for the verified seal. The mark is a hex nut with a tick (`ui/brand.dart`).
- **Type**: Bricolage Grotesque for headings and numbers, Plus Jakarta Sans for text. Both
  are bundled under the SIL Open Font License (`assets/fonts/OFL-*.txt`).
- **Icons**: Phosphor, referenced by meaning through `ui/icons.dart`.
- **Tokens**: colours via `context.colors` (`AppColors`, light and dark), text via
  `context.text`, radii in `R`, spacers in `Gap`, tones (`Tone.success`, …) for pills and
  notices. Screens never hard-code colours.
- **Layout**: `AppPage` + `PageList` give every screen its frame: an app bar on phones, a
  large heading and centred content on wide windows. `TwoCol` and `AutoGrid` handle columns.
- **Data**: `AsyncView` loads, shows a skeleton, an error with retry, and reloads on the
  realtime events you list.
