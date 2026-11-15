# Parkline hardware and wiring guide

This guide records the components and GPIO assignments used by the current `firmware/ParkingGate/ParkingGate.ino` sketch. Use the GPIO labels printed on the ESP32 board; the breadboard hole numbers depend on how the board is positioned.

## Required components

| Qty. | Component | Role / requirement |
| ---: | --- | --- |
| 1 | ESP32 development board | Wi-Fi, RFID authorization requests, sensor processing, and gate control |
| 1 | USB data cable | Programming and powering the ESP32 logic |
| 1 | Solderless breadboard | Distributes 3.3 V, ground, and signal connections |
| 1 | MFRC522 / RC522 reader | Reads the driver's RFID card or tag; use 3.3 V power and logic |
| 2 | Digital IR obstacle sensors | Approach detection and passage confirmation; outputs must be ESP32-safe (no more than 3.3 V) |
| 1 | Servo motor | Moves the barrier arm; use a separate regulated 5 V supply sized for the servo |
| 1 | I²C SSD1306 OLED display, 128 × 64 | Shows RFID prompts, gate status, and driver messages |
| 1 | Passive piezo buzzer | Gives the short access and vehicle-detection tones used by the sketch |
| 1 | Regulated 5 V supply for the servo | Supplies motor current without loading the ESP32 3.3 V rail |
| As needed | Jumper wires and RFID cards | Connections and user cards for testing |

The current sketch is configured for a **passive** buzzer (`BUZZER_IS_ACTIVE = false`). If the buzzer is an active module or has three pins, check its labels and ratings before wiring; use its signal/input pin for GPIO 27 and keep any module power within its rated voltage.

## ESP32 GPIO map

| Device | Device pin | ESP32 connection | Notes |
| --- | --- | --- | --- |
| RC522 | SDA / SS | GPIO 5 | Chip-select for SPI; this pin is often labelled `SDA` on the RC522 board |
| RC522 | SCK | GPIO 18 | SPI clock |
| RC522 | MOSI | GPIO 23 | SPI controller-to-reader data |
| RC522 | MISO | GPIO 19 | SPI reader-to-controller data |
| RC522 | RST | GPIO 22 | Reader reset |
| RC522 | 3.3V / VCC | ESP32 3V3 rail | Never connect the RC522 VCC to 5 V |
| RC522 | GND | Common ground | Shared with the ESP32 |
| RC522 | IRQ | Not connected | Not used by this sketch |
| Approach IR sensor | OUT / DO | GPIO 33 | First sensor; starts the vehicle/RFID flow |
| Approach IR sensor | VCC | Module-rated supply | Use 3.3 V when supported; ensure OUT is at most 3.3 V |
| Approach IR sensor | GND | Common ground | Shared with the ESP32 |
| Passage IR sensor | OUT / DO | GPIO 32 | Second sensor, beyond the gate; confirms vehicle passage |
| Passage IR sensor | VCC | Module-rated supply | Use 3.3 V when supported; ensure OUT is at most 3.3 V |
| Passage IR sensor | GND | Common ground | Shared with the ESP32 |
| Servo | Signal (orange/yellow on many servos) | GPIO 25 | Verify the wire labels for your servo model |
| Servo | V+ (often red) | External regulated 5 V | Do not power the motor from the ESP32 3V3 pin or a GPIO |
| Servo | GND (often brown/black) | Common ground | Connect external supply GND to ESP32 GND |
| OLED | SDA | GPIO 21 | I²C data |
| OLED | SCL | GPIO 26 | I²C clock; the sketch explicitly uses GPIO 26 |
| OLED | VCC | ESP32 3V3 rail | Use 3.3 V logic; check the display module's rating |
| OLED | GND | Common ground | Shared with the ESP32 |
| Buzzer | Signal / positive | GPIO 27 | Firmware generates the passive buzzer tone here |
| Buzzer | GND / negative | Common ground | For a two-wire piezo buzzer |

The firmware expects both IR sensors to report detection as **LOW** (`IR_DETECTED_LEVEL = LOW`). The OLED setup scans I²C addresses `0x3C` and `0x3D`.

## Power and breadboard layout

1. Unplug the ESP32 USB cable and disconnect the servo supply before changing wiring.
2. Place the ESP32 across the breadboard's center gap so its two pin rows are on separate terminal strips.
3. Run the ESP32 **3V3** pin to the breadboard's positive logic rail and **GND** to its ground rail. Power the RC522 and OLED from the 3.3 V rail. Power each IR module only within its printed rating, and verify its output voltage before connecting it to an ESP32 GPIO.
4. Connect the servo's signal wire to GPIO 25. Connect servo V+ to the separate regulated 5 V supply. Connect the external supply ground to the breadboard ground rail so the servo and ESP32 share a ground reference. Do not join the supply's 5 V output to the 3.3 V rail.
5. Connect each signal wire to the GPIO in the table above. On a standard breadboard, use an open hole in the same connected five-hole terminal strip as the corresponding ESP32 pin. The center trench separates the two sides; power rails may also be split partway along their length.
6. Check every VCC, GND, and signal wire against the table before reconnecting power. Breadboard row labels vary with orientation, so this guide intentionally identifies ESP32 GPIOs rather than fixed hole coordinates.

## Physical sensor order

Place the sensors in the direction the car travels:

```text
Vehicle approach  →  GPIO 33 approach IR  →  RFID reader / gate  →  GPIO 32 passage IR  →  Parking area
```

The approach sensor prompts the driver to tap a registered card. After authorization, the servo opens. The passage sensor confirms that the vehicle has passed; the gate then closes and the dashboard records the confirmed passage. Do not swap GPIO 32 and GPIO 33 unless you also update the firmware configuration.

## Pin mapping for code changes

The GPIO values are defined near the top of `firmware/ParkingGate/ParkingGate.ino`:

```cpp
RFID_SS_PIN   = 5;
RFID_RST_PIN  = 22;
IR_ENTRY_PIN  = 33;
IR_EXIT_PIN   = 32;
SERVO_PIN     = 25;
OLED_SDA_PIN  = 21;
OLED_SCL_PIN  = 26;
BUZZER_PIN    = 27;
```

The SPI pins are started as `SPI.begin(18, 19, 23, RFID_SS_PIN)`, which sets SCK, MISO, MOSI, and SS in that order. Keep this table and the sketch pin definitions in sync if the wiring changes.
