# Project index

Parkline is the ESP32 and Flask smart-parking project. See [`README.md`](README.md) for the overview, hardware pin map, setup instructions, data model, and troubleshooting guide.

## Main files

| Path | Purpose |
| --- | --- |
| [`README.md`](README.md) | Project description, architecture, setup, wiring, and troubleshooting |
| [`docs/hardware-and-wiring.md`](docs/hardware-and-wiring.md) | Required components, ESP32 GPIO map, power, and breadboard wiring guide |
| [`app.py`](app.py) | Flask dashboard, API routes, validation, and server-side Supabase integration |
| [`requirements.txt`](requirements.txt) | Pinned Python package dependencies |
| [`.env.example`](.env.example) | Safe template for local Supabase and device configuration |
| [`database/schema.sql`](database/schema.sql) | Parking tables, indexes, row-level security, and status synchronization trigger |
| [`firmware/ParkingGate/ParkingGate.ino`](firmware/ParkingGate/ParkingGate.ino) | Main ESP32 RFID, sensor, servo, OLED, buzzer, Wi-Fi, and API sketch |
| [`firmware/ParkingGate/secrets.example.h`](firmware/ParkingGate/secrets.example.h) | Safe template for local Wi-Fi and device credentials |
| [`firmware/BuzzerTest/BuzzerTest.ino`](firmware/BuzzerTest/BuzzerTest.ino) | Standalone buzzer diagnostic sketch |
| [`Start_Smart_Parking.vbs`](Start_Smart_Parking.vbs) | Quiet Windows launcher entry point |
| [`SmartParking_Launcher/launcher.pyw`](SmartParking_Launcher/launcher.pyw) | Control Center UI, dependency setup, server health check, and browser opening |
| [`run_dashboard.bat`](run_dashboard.bat) | Console-based dashboard startup fallback |
| [`templates/index.html`](templates/index.html) | Dashboard page structure |
| [`static/css/dashboard.css`](static/css/dashboard.css) | Responsive dashboard design and styles |
| [`static/js/dashboard.js`](static/js/dashboard.js) | Dashboard navigation, live refresh, tables, search, and forms |
| [`static/parkline.svg`](static/parkline.svg) | Dashboard favicon |

## Directory layout

```text
database/                   Supabase schema
docs/                       Hardware and wiring documentation
firmware/ParkingGate/       Integrated gate firmware and local config template
firmware/BuzzerTest/        Standalone buzzer test
SmartParking_Launcher/      Windows Control Center
templates/                  Flask-rendered HTML
static/css/                 Dashboard styles
static/js/                  Dashboard behavior
```

## Local-only files

- `.env` contains the Supabase server key, Flask secret, and ESP32 device key.
- `firmware/ParkingGate/secrets.h` contains Wi-Fi credentials and the ESP32 device key.
- `.venv/` contains the local Python environment.
- `SmartParking_Launcher/logs/` is created at runtime for launcher and server logs.

These files are excluded from Git. Never commit credential files or publish the local runtime logs.
