# Parkline · Smart Parking Dashboard

A responsive Flutter dashboard for the RFID smart parking project. It shows parking users, their linked vehicle and RFID card, gate state, and card tap / confirmed passage times.

## Run locally

Requires a current stable Flutter SDK with Dart 3.13.4 or newer.

```powershell
flutter pub get
flutter run -d chrome
```

You can also open it as a Windows desktop app with `flutter run -d windows`.

## Dashboard pages

- **Overview** — registered users, vehicles inside, entry / exit totals, activity chart, gate and sensor status, recent access, and new users.
- **Parking users** — searchable user, vehicle plate, card UID, and inside / outside records.
- **Access logs** — searchable-by-direction event history with separate card tap and vehicle passage times.

Use **Add user** to register a name, vehicle plate, and RFID UID. This UI pass uses sample data in memory, so new records reset when the app is closed. Supabase persistence and live ESP32 status will be connected in the next integration phase; the `DEMO DATA` labels identify the current sample content.

## Project structure

- `lib/models/` — parking user and access event models
- `lib/data/` — demo records used by the UI prototype
- `lib/screens/` — responsive overview, user list, and access history
- `lib/widgets/` — reusable cards, status badges, event tables, and registration form

The gate state shown here is sample data. A physical controller should only report an entry or exit after the vehicle passage sensor confirms the vehicle has cleared the gate path.
