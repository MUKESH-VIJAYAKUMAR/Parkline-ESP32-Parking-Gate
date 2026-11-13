# Parkline · Smart Parking Dashboard

A local Flask dashboard for managing registered parking users and reviewing RFID entry/exit records. The UI follows the compact sidebar and card layout used in Smart Print, with a quieter navy, teal, and mint palette.

## What is included

- **Overview** — registered drivers, cars currently inside, today's confirmed entries and exits, and recent access.
- **Parking users** — searchable, paginated driver records with vehicle plates and RFID card UIDs.
- **Access logs** — paginated entry/exit events showing card tap time separately from confirmed vehicle passage time.
- **Add user** — register a driver, plate, and RFID UID. Duplicate card UIDs are rejected.
- **Windows launcher** — `run_dashboard.bat` creates a local Python environment, installs the pinned direct dependencies when needed, and starts the dashboard in your browser.
- **ESP32 status placeholder** — clearly shows that the hardware is not connected; it does not display simulated sensor or gate readings.

The dashboard refreshes its Supabase data every 30 seconds while the browser tab is visible. It listens only on `127.0.0.1`, so it is intended for the admin computer in this phase.

## Configure your Smart Parking Supabase project

The connected Supabase integration did not grant this workspace permission to inspect project `wiyjgmwktmopddvoudsm`, so no database changes have been applied. The Flask dashboard expects the schema in [`database/schema.sql`](database/schema.sql).

1. Open the SQL Editor for your **Smart Parking** project, confirm its project reference, and run `database/schema.sql`.
2. Copy `.env.example` to `.env` in this folder.
3. In the Smart Parking project's API keys settings, create/copy a **server-side secret key** and put it in `SUPABASE_SECRET_KEY` in `.env`. Do not use a publishable key for this admin backend, share the secret key, or commit `.env`.
4. Leave the URL as `https://wiyjgmwktmopddvoudsm.supabase.co` if that is the project you intend to use.
5. Double-click `run_dashboard.bat`.

The schema enables Row Level Security and creates no anonymous or signed-in client policies. The secret key stays in the local Flask backend; it is never sent to browser JavaScript. The application is local-only and does not provide admin authentication for a publicly exposed server.

## Start from PowerShell

Requires Python 3.11 or newer (Python 3.12 recommended for the pinned Supabase client).

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
# Add the Supabase secret key to .env, then run:
.\.venv\Scripts\python.exe app.py
```

Open [http://127.0.0.1:5000](http://127.0.0.1:5000). The launcher opens it automatically.

## Data model for the ESP32 phase

`parking_users` stores the driver's name, vehicle plate, normalized RFID UID, and current inside/outside state. `parking_events` stores the access direction, granted/denied result, card tap timestamp, and (when the IR sensor confirms passage) vehicle passage timestamp.

The SQL trigger updates `parking_users.current_status` only after a granted event has a `vehicle_passed_at` timestamp. The hardware integration should therefore record the tap first, then set the passage timestamp after the IR sensor confirms that the car cleared the gate. For denied taps, keep `parking_user_id` null when the card is not registered, record the UID and set `access_status` to `DENIED`.

## Project files

- `app.py` — Flask routes, validation, and server-side Supabase client.
- `templates/index.html` — dashboard layout and user form.
- `static/css/dashboard.css` — responsive Parkline theme.
- `static/js/dashboard.js` — table rendering, search, pagination, and refresh behavior.
- `database/schema.sql` — proposed Smart Parking schema and passage-status trigger; not applied to Supabase from this workspace.
- `.env.example` — configuration template. Keep the real `.env` local.
