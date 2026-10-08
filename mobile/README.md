# FixIt Mobile App

Flutter app for clients, technicians, suppliers, and admins.

## Setup

First time — generate the Android/iOS/web platform folders (this won't overwrite `lib/`
or `pubspec.yaml`):

```bash
flutter create --org com.fixit --project-name fixit .
flutter pub get
```

Subsequent runs just need `flutter pub get` when dependencies change.

## Run

Make sure the backend (`:4000`) and AI service (`:5001`) are running first.

```bash
flutter run
```

### Picking the backend URL

`lib/services/api_config.dart` auto-picks per platform — no edit needed for
the common cases:

| Target                | Auto-picked baseUrl                    |
| --------------------- | -------------------------------------- |
| iOS simulator         | `http://localhost:4000`                |
| Android emulator      | `http://10.0.2.2:4000`                 |
| Web / Linux desktop   | `http://localhost:4000`                |

For a physical device on your LAN (or a different host entirely), override
at build time:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000
```

## Demo login

- Client:     `client@demo.com / password123`
- Technician: `tech@demo.com / password123`
- Supplier:   `supplier@demo.com / password123`
- Admin:      `admin@demo.com / password123`
