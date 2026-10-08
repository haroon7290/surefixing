# SureFix mobile app (Flutter)

```bash
flutter pub get
flutter run                     # pick a device
flutter run -d chrome           # web
flutter test && flutter analyze
```

Requires Flutter 3.35+ (Dart 3.9). Runs on Android, iOS, web and desktop.

## Build-time options

| Flag | Default | Purpose |
|---|---|---|
| `--dart-define=API_BASE_URL=http://host:4000` | `http://localhost:4000` | Backend URL (`10.0.2.2` for the Android emulator; `adb reverse tcp:4000 tcp:4000` for a USB phone) |
| `--dart-define=CURRENCY=$` | `Rs` | Currency symbol |
| `--dart-define=DEMO=true` | off in release | Show demo-account buttons on the login screen |

## Structure

```
lib/
├── main.dart, app.dart   bootstrap, themes, root gate, global realtime toasts
├── core/                 theme.dart (design system, light/dark), catalog.dart, format.dart
├── services/             api_client, auth (ChangeNotifier), realtime (Socket.IO), badges, settings, navigation
├── models/               user, job, tool, rental, message, app_notification, recommendation
├── widgets/              cards, match_card, pills, states (empty/error/skeleton), media, visuals, dialogs, async_list
└── screens/
    ├── shells.dart       bottom navigation per role
    ├── routes.dart       notification deep links
    ├── auth/  client/  technician/  supplier/  admin/  shared/
```

Design system: brand blue `#2F54EB` + tool orange `#FF8A00`, Plus Jakarta Sans (bundled, OFL —
see `assets/fonts/OFL.txt`), semantic palette via `context.palette`, light and dark themes.
