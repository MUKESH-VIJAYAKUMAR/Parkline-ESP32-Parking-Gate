# Smart Parking Project Index

Parkline is a Flask dashboard for registering RFID users and viewing parking entry and exit events.

## Main files

| Path | Purpose |
| --- | --- |
| [`README.md`](README.md) | Setup, Supabase status, and dashboard operation |
| [`Start_Smart_Parking.vbs`](Start_Smart_Parking.vbs) | Opens the quiet desktop Control Center |
| [`SmartParking_Launcher/launcher.pyw`](SmartParking_Launcher/launcher.pyw) | Start/stop UI, dependency setup, health check, and browser opening |
| [`run_dashboard.bat`](run_dashboard.bat) | Console fallback for starting Flask |
| [`app.py`](app.py) | Flask routes, validation, and server-side Supabase access |
| [`requirements.txt`](requirements.txt) | Pinned Python dependencies |
| [`.env.example`](.env.example) | Safe local configuration template |
| [`database/schema.sql`](database/schema.sql) | Parking tables, indexes, RLS, and status trigger |
| [`firmware/ParkingGate/ParkingGate.ino`](firmware/ParkingGate/ParkingGate.ino) | ESP32 RFID, servo, IR sensors, Wi-Fi, and dashboard API integration |
| [`firmware/ParkingGate/secrets.example.h`](firmware/ParkingGate/secrets.example.h) | Safe Wi-Fi/device-key configuration template |
| [`templates/index.html`](templates/index.html) | Dashboard page entry point |
| [`static/css/dashboard.css`](static/css/dashboard.css) | Dashboard styling and responsive layout |
| [`static/js/dashboard.js`](static/js/dashboard.js) | Search, pagination, refresh, and UI behavior |
| [`static/parkline.svg`](static/parkline.svg) | Browser icon |

## Directory layout

```text
database/          SQL schema
firmware/ParkingGate/  ESP32 sketch and local configuration template
templates/         Flask HTML templates
static/css/        Dashboard styles
static/js/         Dashboard behavior
SmartParking_Launcher/ Desktop launcher and local logs
```

## Local-only files

- `.env` stores the local Supabase server key and is ignored by Git.
- `firmware/ParkingGate/secrets.h` stores Wi-Fi and device API credentials and is ignored by Git.
- `.venv/` stores the local Python environment and is ignored by Git.
- `.git/` stores repository history and remote configuration; keep it intact.

Start with `README.md` for setup instructions. The dashboard's web entry page is `templates/index.html`.
