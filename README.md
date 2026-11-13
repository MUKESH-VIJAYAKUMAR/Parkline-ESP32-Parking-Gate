# Parkline · Smart Parking Dashboard

A local Flask dashboard for managing registered parking users and reviewing RFID entry/exit records. The UI follows the compact sidebar and card layout used in Smart Print, with a quieter navy, teal, and mint palette.

## What is included

- **Overview** — registered drivers, cars currently inside, today's confirmed entries and exits, and recent access.
- **Parking users** — searchable, paginated driver records with vehicle plates and RFID card UIDs.
- **Access logs** — paginated entry/exit events showing card tap time separately from confirmed vehicle passage time.
- **Add user** — register a driver, plate, and RFID UID. Duplicate card UIDs are rejected.
- **Windows Control Center** — `Start_Smart_Parking.vbs` opens a quiet Smart Print-style launcher with status, start/stop, and open-dashboard controls. It prepares Python packages in the background, checks that Flask is responding, then opens the UI. `run_dashboard.bat` remains available as a console fallback.
- **ESP32 status placeholder** — clearly shows that the hardware is not connected; it does not display simulated sensor or gate readings.

The dashboard refreshes its Supabase data every 30 seconds while the browser tab is visible. It listens only on `127.0.0.1`, so it is intended for the admin computer in this phase.

## Project index

Use [`INDEX.md`](INDEX.md) as the file and folder map. Start with this README for setup, Supabase status, and dashboard operation.

## Supabase setup

The Smart Parking Supabase project is `wiyjgmwktmopddvoudsm`. Its `parking_users` and `parking_events` tables have been created and verified. A live read from this Flask project's Python environment reached both tables; each currently contains zero rows. Row Level Security is enabled, and the dashboard uses a server-side secret key.

This computer already has its local connection configured. `.env` and `.venv` are ignored by Git; keep the secret key local and never put it in browser code or commit it.

For a fresh clone, copy `.env.example` to `.env`, set the project URL and server-side secret key, and start the dashboard. For a different Supabase project, confirm its project reference and run [`database/schema.sql`](database/schema.sql) in that project's SQL Editor before connecting it.

The schema enables Row Level Security and creates no anonymous or signed-in client policies. The secret key stays in the local Flask backend; it is never sent to browser JavaScript. The application is local-only and does not provide admin authentication for a publicly exposed server.

## Start the dashboard

Double-click [`Start_Smart_Parking.vbs`](Start_Smart_Parking.vbs) to open the Control Center without a command prompt. Choose **Start dashboard**; the launcher prepares `.venv` and dependencies as needed, starts Flask, waits for it to respond, and opens the UI. Use [`run_dashboard.bat`](run_dashboard.bat) if you want a console window.

To start from PowerShell after the environment is set up:

```powershell
.\.venv\Scripts\python.exe app.py
```

Open [http://127.0.0.1:5000](http://127.0.0.1:5000). The launcher opens it automatically.

## Data model for the ESP32 phase

`parking_users` stores the driver's name, vehicle plate, normalized RFID UID, and current inside/outside state. `parking_events` stores the access direction, granted/denied result, card tap timestamp, and (when the IR sensor confirms passage) vehicle passage timestamp.

The SQL trigger updates `parking_users.current_status` only after a granted event has a `vehicle_passed_at` timestamp. The hardware integration should therefore record the tap first, then set the passage timestamp after the IR sensor confirms that the car cleared the gate. For denied taps, keep `parking_user_id` null when the card is not registered, record the UID and set `access_status` to `DENIED`.

## Folder contents

See [`INDEX.md`](INDEX.md) for the project map and the role of each file.
