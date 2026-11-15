#include <HTTPClient.h>
#include <MFRC522.h>
#include <SPI.h>
#include <WiFi.h>

#include "secrets.h"

// RC522: SDA/SS=GPIO5, SCK=18, MOSI=23, MISO=19, RST=22, IRQ unconnected.
constexpr uint8_t RFID_SS_PIN = 5;
constexpr uint8_t RFID_RST_PIN = 22;

// Two digital IR sensor outputs. The tested modules detect an object with LOW.
constexpr uint8_t IR_ENTRY_PIN = 32;
constexpr uint8_t IR_EXIT_PIN = 33;

// Servo signal only. Power the servo from its regulated 5 V supply and share GND.
constexpr uint8_t SERVO_PIN = 25;
constexpr int IR_DETECTED_LEVEL = LOW;

constexpr int SERVO_FREQUENCY = 50;
constexpr int SERVO_RESOLUTION = 16;
constexpr int SERVO_PERIOD_US = 20000;
constexpr int SERVO_CLOSED_US = 1000;
constexpr int SERVO_OPEN_US = 2000;
constexpr int GATE_OPEN_ANGLE = 90;
constexpr unsigned long GATE_TIMEOUT_MS = 15000;
constexpr unsigned long HEARTBEAT_INTERVAL_MS = 1000;
constexpr unsigned long WIFI_RETRY_INTERVAL_MS = 10000;
constexpr unsigned long CARD_COOLDOWN_MS = 1200;

MFRC522 reader(RFID_SS_PIN, RFID_RST_PIN);

bool gateOpen = false;
bool sensorsArmed = false;
bool previousEntryDetected = false;
bool previousExitDetected = false;
unsigned long gateOpenedAt = 0;
unsigned long lastHeartbeatAt = 0;
unsigned long lastWifiRetryAt = 0;
unsigned long lastCardAt = 0;
String activeEventId;

bool isDetected(uint8_t pin) {
  return digitalRead(pin) == IR_DETECTED_LEVEL;
}

uint32_t pulseToDuty(int pulseUs) {
  return static_cast<uint32_t>(static_cast<uint64_t>(pulseUs) * 65535 / SERVO_PERIOD_US);
}

void setServoAngle(int angle) {
  angle = constrain(angle, 0, 180);
  const int pulseUs = map(angle, 0, 180, SERVO_CLOSED_US, SERVO_OPEN_US);
  ledcWrite(SERVO_PIN, pulseToDuty(pulseUs));
}

String jsonStringValue(const String& json, const char* key) {
  const String marker = String("\"") + key + "\"";
  int start = json.indexOf(marker);
  if (start < 0) return "";
  start = json.indexOf(':', start + marker.length());
  if (start < 0) return "";
  start = json.indexOf('"', start + 1);
  if (start < 0) return "";
  const int end = json.indexOf('"', start + 1);
  if (end < 0) return "";
  return json.substring(start + 1, end);
}

bool jsonTrueValue(const String& json, const char* key) {
  const String marker = String("\"") + key + "\"";
  int start = json.indexOf(marker);
  if (start < 0) return false;
  start = json.indexOf(':', start + marker.length());
  if (start < 0) return false;
  start++;
  while (start < static_cast<int>(json.length()) && json[start] == ' ') start++;
  return json.substring(start, start + 4) == "true";
}

bool postJson(const char* path, const String& body, String& responseBody) {
  if (WiFi.status() != WL_CONNECTED) return false;

  WiFiClient client;
  HTTPClient http;
  http.setConnectTimeout(2500);
  http.setTimeout(2500);
  const String url = String(SERVER_BASE_URL) + path;
  if (!http.begin(client, url)) return false;

  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Key", DEVICE_API_KEY);
  const int statusCode = http.POST(body);
  if (statusCode > 0) responseBody = http.getString();
  http.end();
  return statusCode >= 200 && statusCode < 300;
}

void connectToWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting to Wi-Fi");
  const unsigned long startedAt = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startedAt < 20000) {
    Serial.print('.');
    delay(400);
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Wi-Fi connected. ESP32 IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("Wi-Fi is not connected yet. The gate will stay closed until the server can authorize a card.");
  }
}

void closeGate() {
  setServoAngle(0);
  gateOpen = false;
  sensorsArmed = false;
  Serial.println("Gate closed.");
}

void openGate(const String& eventId, bool entryDetected, bool exitDetected) {
  activeEventId = eventId;
  setServoAngle(GATE_OPEN_ANGLE);
  gateOpen = true;
  gateOpenedAt = millis();
  sensorsArmed = !entryDetected && !exitDetected;
  Serial.println("Registered card approved. Gate open.");
  Serial.println(sensorsArmed ? "IR sensors armed; drive through." : "Clear both IR sensors, then drive through.");
}

String readCardUid() {
  String uid;
  for (byte index = 0; index < reader.uid.size; index++) {
    if (reader.uid.uidByte[index] < 0x10) uid += '0';
    uid += String(reader.uid.uidByte[index], HEX);
  }
  uid.toUpperCase();
  return uid;
}

void handleCardTap(bool entryDetected, bool exitDetected) {
  const String cardUid = readCardUid();
  Serial.print("Card UID: ");
  Serial.println(cardUid);

  String response;
  const String body = String("{\"card_uid\":\"") + cardUid + "\"}";
  if (!postJson("/api/device/card-tap", body, response)) {
    Serial.println("Server did not save/authorize this card. Gate remains closed.");
  } else if (jsonTrueValue(response, "authorized")) {
    const String eventId = jsonStringValue(response, "event_id");
    if (eventId.length() == 36) {
      Serial.print("Access granted for ");
      Serial.println(jsonStringValue(response, "user_name"));
      Serial.print("Direction: ");
      Serial.println(jsonStringValue(response, "direction"));
      openGate(eventId, entryDetected, exitDetected);
    } else {
      Serial.println("Server reply did not include a valid event ID. Gate remains closed.");
    }
  } else {
    Serial.println("Access denied. Register this RFID UID in the dashboard first.");
  }

  reader.PICC_HaltA();
  reader.PCD_StopCrypto1();
  lastCardAt = millis();
}

void confirmVehiclePassage() {
  // Close immediately once the car reaches an IR sensor, then persist the passage.
  closeGate();
  if (activeEventId.isEmpty()) return;

  const String body = String("{\"event_id\":\"") + activeEventId + "\"}";
  String response;
  bool saved = false;
  for (int attempt = 0; attempt < 2 && !saved; attempt++) {
    saved = postJson("/api/device/passage", body, response);
    if (!saved) delay(250);
  }
  Serial.println(saved ? "Vehicle passage time saved to Supabase." : "Passage could not reach the server; check Wi-Fi and dashboard server.");
  activeEventId = "";
}

void sendHeartbeat(bool entryDetected, bool exitDetected) {
  if (millis() - lastHeartbeatAt < HEARTBEAT_INTERVAL_MS) return;
  lastHeartbeatAt = millis();

  String response;
  const String body = String("{\"gate_open\":") + (gateOpen ? "true" : "false") +
    ",\"ir_entry_detected\":" + (entryDetected ? "true" : "false") +
    ",\"ir_exit_detected\":" + (exitDetected ? "true" : "false") +
    ",\"wifi_rssi\":" + String(WiFi.status() == WL_CONNECTED ? WiFi.RSSI() : -127) + "}";
  if (!postJson("/api/device/heartbeat", body, response) && WiFi.status() == WL_CONNECTED) {
    Serial.println("Dashboard heartbeat failed. Check the computer IP, firewall, and device key.");
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(IR_ENTRY_PIN, INPUT);
  pinMode(IR_EXIT_PIN, INPUT);

  if (!ledcAttach(SERVO_PIN, SERVO_FREQUENCY, SERVO_RESOLUTION)) {
    Serial.println("Servo PWM setup failed.");
    while (true) delay(1000);
  }
  setServoAngle(0);

  SPI.begin(18, 19, 23, RFID_SS_PIN);
  reader.PCD_Init();
  delay(50);
  Serial.println("RC522 initialized.");
  reader.PCD_DumpVersionToSerial();

  connectToWifi();
  previousEntryDetected = isDetected(IR_ENTRY_PIN);
  previousExitDetected = isDetected(IR_EXIT_PIN);
  Serial.println("Smart Parking gate ready. Tap a registered RFID card.");
}

void loop() {
  const bool entryDetected = isDetected(IR_ENTRY_PIN);
  const bool exitDetected = isDetected(IR_EXIT_PIN);

  if (entryDetected != previousEntryDetected || exitDetected != previousExitDetected) {
    Serial.print("Entry IR: ");
    Serial.print(entryDetected ? "DETECTED" : "CLEAR");
    Serial.print(" | Exit IR: ");
    Serial.println(exitDetected ? "DETECTED" : "CLEAR");
    previousEntryDetected = entryDetected;
    previousExitDetected = exitDetected;
  }

  if (!gateOpen && millis() - lastCardAt >= CARD_COOLDOWN_MS &&
      reader.PICC_IsNewCardPresent() && reader.PICC_ReadCardSerial()) {
    handleCardTap(entryDetected, exitDetected);
  }

  if (gateOpen) {
    if (!sensorsArmed && !entryDetected && !exitDetected) {
      sensorsArmed = true;
      Serial.println("IR sensors clear and armed.");
    }
    if (sensorsArmed && (entryDetected || exitDetected)) {
      Serial.println("Vehicle detected at IR sensor.");
      confirmVehiclePassage();
    } else if (millis() - gateOpenedAt >= GATE_TIMEOUT_MS) {
      Serial.println("Safety timeout: closing gate. No vehicle passage was recorded.");
      closeGate();
      activeEventId = "";
    }
  }

  if (WiFi.status() != WL_CONNECTED && millis() - lastWifiRetryAt >= WIFI_RETRY_INTERVAL_MS) {
    lastWifiRetryAt = millis();
    WiFi.reconnect();
  }

  sendHeartbeat(entryDetected, exitDetected);
  delay(20);
}
