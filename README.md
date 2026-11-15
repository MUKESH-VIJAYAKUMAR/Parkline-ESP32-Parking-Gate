# Parkline · Smart Parking Dashboard

A local Flask dashboard for managing registered parking users and reviewing RFID entry/exit records. The UI follows the compact sidebar and card layout used in Smart Print, with a quieter navy, teal, and mint palette.

## What is included

- **Overview** — registered drivers, cars currently inside, today's confirmed entries and exits, and recent access.
- **Parking users** — searchable, paginated driver records with vehicle plates and RFID card UIDs.
- **Access logs** — paginated entry/exit events showing card tap time separately from confirmed vehicle passage time.
- **Add user** — register a driver, plate, and RFID UID. Duplicate card UIDs are rejected.
- **Windows Control Center** — `Start_Smart_Parking.vbs` opens a quiet Smart Print-style launcher with status, start/stop, and open-dashboard controls. It prepares Python packages in the background, checks that Flask is responding, then opens the UI. `run_dashboard.bat` remains available as a console fallback.
- **ESP32 gate integration** — authenticated RFID checks, card-tap records, IR-confirmed passage records, gate/sensor heartbeat status, and a closed-gate timeout.

The gate and IR state poll from the local Flask process every 250 ms, recent access refreshes every second, and database counters refresh every 5 seconds. Access logs refresh every second while open; parking users refresh every 5 seconds. This keeps sensor animation responsive without repeatedly querying all dashboard counts.

## Project index

Use [`INDEX.md`](INDEX.md) as the file and folder map. Start with this README for setup, Supabase status, and dashboard operation.

## Supabase setup

The Smart Parking Supabase project is `wiyjgmwktmopddvoudsm`. A read-only connection check from this Flask project reached `parking_users` and `parking_events`; both currently contain zero rows. The app uses the existing tables and schema and does not expose the server-side Supabase key to the browser or ESP32.

This computer already has its local connection configured. `.env` and `.venv` are ignored by Git; keep the secret key local and never put it in browser code or commit it.

For a fresh clone, copy `.env.example` to `.env`, set the project URL and server-side secret key, and start the dashboard. For a different Supabase project, confirm its project reference and run [`database/schema.sql`](database/schema.sql) in that project's SQL Editor before connecting it.

The schema enables Row Level Security and creates no anonymous or signed-in client policies. The Supabase secret stays in the local Flask backend. The ESP32 uses a separate random device key to authenticate its three API calls.

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

## Connect the ESP32

The integrated sketch is [`firmware/ParkingGate/ParkingGate.ino`](firmware/ParkingGate/ParkingGate.ino). It uses the confirmed wiring: RC522 on GPIO 5/18/19/22/23, first/approach IR on GPIO33, second/beyond-gate IR on GPIO32, servo signal on GPIO25, OLED SDA/SCL on GPIO21/26, and buzzer signal on GPIO27. Only the first/approach sensor on GPIO33 starts an RFID session; GPIO32 is used to confirm the vehicle has passed the gate. A car arriving at GPIO33 prompts for RFID with a fast double beep. A server-approved card opens the gate, shows “You can go now” and a thank-you animation, and gives one short beep. After the approach sensor clears, GPIO32 triggers another fast double beep, closes the gate, records passage, and displays “Next vehicle come forward.” The live dashboard phase and sensor readings poll independently of Supabase summary counts. Upload the sketch after firmware changes for the board to use them. Wi-Fi, HTTP, SPI, and the ESP32 PWM driver come with the ESP32 Arduino board package; the sketch needs the MFRC522, Adafruit SSD1306, and Adafruit GFX Arduino libraries.

1. Open `firmware/ParkingGate/secrets.h` and set `WIFI_SSID` and `WIFI_PASSWORD` to a 2.4 GHz Wi-Fi network that the ESP32 and this computer can both reach. The local file already contains this computer's current server address and the matching device key. `secrets.h` is ignored by Git.
2. If this computer's IPv4 address changes, replace `SERVER_BASE_URL` with `http://<computer IPv4>:5000`. Find it with `ipconfig` in Command Prompt. Do not use `127.0.0.1` in the ESP32 sketch.
3. For ESP32 network access, set `PARKING_HOST=0.0.0.0` in `.env` and allow Python through Windows Firewall on the private network. Start the dashboard with [`Start_Smart_Parking.vbs`](Start_Smart_Parking.vbs), then upload `ParkingGate.ino` from Arduino IDE.
4. Add the driver, vehicle plate, and exact card UID in **Parking users** before testing a card. The firmware prints each UID in the Serial Monitor. Unknown or inactive cards are recorded as denied and never open the gate.

After a valid tap, the backend stores the card tap time and direction. The firmware then waits for the vehicle to clear the first IR and reach the second before it closes the gate and marks passage time; Supabase then updates the user's inside/outside status. If the car does not cross within 15 seconds, the gate closes and no passage is counted. The OLED is scanned at startup at 0x3C and 0x3D.

## Folder contents

See [`INDEX.md`](INDEX.md) for the project map and the role of each file.
