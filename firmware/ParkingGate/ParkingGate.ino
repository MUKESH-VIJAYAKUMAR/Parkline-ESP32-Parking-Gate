#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <HTTPClient.h>
#include <MFRC522.h>
#include <SPI.h>
#include <Wire.h>
#include <WiFi.h>
#include <cstring>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>

#include "secrets.h"

// RC522 wiring: SS=GPIO5, SCK=18, MOSI=23, MISO=19, RST=22. IRQ is unused.
constexpr uint8_t RFID_SS_PIN = 5;
constexpr uint8_t RFID_RST_PIN = 22;

// GPIO33 is the first (approach/entry) sensor; GPIO32 is beyond the gate.
// Both tested digital modules report detection as LOW.
constexpr uint8_t IR_ENTRY_PIN = 33;
constexpr uint8_t IR_EXIT_PIN = 32;

// Servo signal only. Use a regulated 5 V supply for servo power and share GND.
constexpr uint8_t SERVO_PIN = 25;

// I2C OLED and buzzer.
constexpr uint8_t OLED_SDA_PIN = 21;
constexpr uint8_t OLED_SCL_PIN = 26;
constexpr uint8_t BUZZER_PIN = 27;
constexpr uint8_t OLED_ADDRESS_1 = 0x3C;
constexpr uint8_t OLED_ADDRESS_2 = 0x3D;
// The sample test produced a PWM tone, so this buzzer is operated as a passive piezo.
constexpr bool BUZZER_IS_ACTIVE = false;
constexpr int IR_DETECTED_LEVEL = LOW;

constexpr int SERVO_FREQUENCY = 50;
constexpr int SERVO_RESOLUTION = 16;
constexpr int SERVO_PERIOD_US = 20000;
constexpr int SERVO_CLOSED_US = 1000;
constexpr int SERVO_OPEN_US = 2000;
constexpr int GATE_OPEN_ANGLE = 90;
constexpr unsigned long GATE_TIMEOUT_MS = 15000;
constexpr unsigned long HEARTBEAT_INTERVAL_MS = 5000;
constexpr unsigned long WIFI_RETRY_INTERVAL_MS = 10000;
constexpr unsigned long CARD_COOLDOWN_MS = 1200;
constexpr unsigned long DISPLAY_REFRESH_MS = 100;

constexpr unsigned long WELCOME_SCREEN_MS = 2400;
constexpr unsigned long SHORT_MESSAGE_MS = 2200;
constexpr unsigned long VEHICLE_WAIT_TIMEOUT_MS = 30000;
constexpr unsigned long ACCESS_BEEP_MS = 180;

MFRC522 reader(RFID_SS_PIN, RFID_RST_PIN);
Adafruit_SSD1306 display(128, 64, &Wire, -1);

enum SensorSide : uint8_t { SENSOR_NONE, SENSOR_ENTRY, SENSOR_EXIT };
enum BuzzerPattern : uint8_t {
  BUZZER_OFF,
  BUZZER_TEST_TONE,
  BUZZER_ACCESS_BEEP,
  BUZZER_DOUBLE_BEEP
};
enum ScreenNotice : uint8_t {
  NOTICE_IDLE,
  NOTICE_TAP_RFID,
  NOTICE_CHECKING,
  NOTICE_WELCOME,
  NOTICE_DENIED,
  NOTICE_SERVER_ERROR,
  NOTICE_HARDWARE_ERROR,
  NOTICE_PASSAGE_START,
  NOTICE_NEXT_CAR,
  NOTICE_TIMEOUT
};

bool displayReady = false;
bool buzzerReady = false;
bool servoReady = false;
bool wifiWasConnected = false;
uint8_t oledAddress = 0;
bool gateOpen = false;
bool passageStarted = false;
bool vehicleWaiting = false;
bool previousEntryDetected = false;
bool previousExitDetected = false;
bool heartbeatStateKnown = false;
bool lastReportedGateOpen = false;
bool lastReportedEntryDetected = false;
bool lastReportedExitDetected = false;
bool lastReportedVehicleWaiting = false;
bool lastReportedPassageStarted = false;
bool passageSavePending = false;
bool diagnosticServoOpen = false;
bool authorizationPending = false;

SensorSide firstPassageSensor = SENSOR_NONE;
BuzzerPattern buzzerPattern = BUZZER_OFF;
ScreenNotice screenNotice = NOTICE_IDLE;

unsigned long gateOpenedAt = 0;
unsigned long lastHeartbeatAt = 0;
unsigned long lastWifiRetryAt = 0;
unsigned long lastCardAt = 0;
unsigned long lastDisplayAt = 0;
unsigned long buzzerStepDueAt = 0;
unsigned long noticeStartedAt = 0;
unsigned long noticeExpiresAt = 0;
unsigned long diagnosticServoCloseAt = 0;
unsigned long vehicleWaitStartedAt = 0;
uint8_t buzzerStep = 0;
uint8_t queuedDoubleBeeps = 0;
uint8_t queuedAccessBeeps = 0;

String activeEventId;
String pendingPassageEventId;
String activeUserName;
String activeDirection;

enum NetworkJobType : uint8_t { NETWORK_CARD_AUTH, NETWORK_HEARTBEAT, NETWORK_PASSAGE };

struct NetworkJob {
  NetworkJobType type;
  uint32_t createdAt;
  bool gateOpen;
  bool entryDetected;
  bool exitDetected;
  bool vehicleWaiting;
  bool passageStarted;
  int16_t wifiRssi;
  char phase[24];
  char cardUid[21];
  char eventId[37];
};

struct AuthorizationResult {
  int16_t statusCode;
  bool authorized;
  char eventId[37];
  char userName[64];
  char direction[24];
};

char lastReportedPhase[24] = "";

QueueHandle_t networkQueue = nullptr;
QueueHandle_t authorizationResultQueue = nullptr;
TaskHandle_t networkTask = nullptr;

bool isDetected(uint8_t pin) {
  return digitalRead(pin) == IR_DETECTED_LEVEL;
}

bool sensorSideDetected(SensorSide side, bool entryDetected, bool exitDetected) {
  if (side == SENSOR_ENTRY) return entryDetected;
  if (side == SENSOR_EXIT) return exitDetected;
  return false;
}

uint32_t pulseToDuty(int pulseUs) {
  return static_cast<uint32_t>(static_cast<uint64_t>(pulseUs) * 65535 / SERVO_PERIOD_US);
}

void setServoAngle(int angle) {
  if (!servoReady) return;
  angle = constrain(angle, 0, 180);
  const int pulseUs = map(angle, 0, 180, SERVO_CLOSED_US, SERVO_OPEN_US);
  ledcWrite(SERVO_PIN, pulseToDuty(pulseUs));
}

void buzzerToneOn() {
  if (!buzzerReady) return;
  if (BUZZER_IS_ACTIVE) digitalWrite(BUZZER_PIN, HIGH);
  else ledcWriteTone(BUZZER_PIN, 2000);
}

void buzzerToneOff() {
  if (!buzzerReady) return;
  if (BUZZER_IS_ACTIVE) digitalWrite(BUZZER_PIN, LOW);
  else ledcWriteTone(BUZZER_PIN, 0);
}

void beginDoubleBeep() {
  buzzerPattern = BUZZER_DOUBLE_BEEP;
  buzzerStep = 0;
  buzzerToneOn();
  buzzerStepDueAt = millis() + 110;
}

void startCardBeep() {
  if (!buzzerReady) return;
  buzzerPattern = BUZZER_TEST_TONE;
  buzzerStep = 0;
  queuedDoubleBeeps = 0;
  queuedAccessBeeps = 0;
  buzzerToneOn();
  buzzerStepDueAt = millis() + 2000;
}

void startAccessBeep() {
  if (!buzzerReady) return;
  if (buzzerPattern != BUZZER_OFF) {
    if (queuedAccessBeeps < 4) queuedAccessBeeps++;
    return;
  }
  buzzerPattern = BUZZER_ACCESS_BEEP;
  buzzerStep = 0;
  buzzerToneOn();
  buzzerStepDueAt = millis() + ACCESS_BEEP_MS;
}

void startNextBuzzerPattern() {
  buzzerPattern = BUZZER_OFF;
  buzzerToneOff();
  if (queuedAccessBeeps > 0) {
    queuedAccessBeeps--;
    startAccessBeep();
  } else if (queuedDoubleBeeps > 0) {
    queuedDoubleBeeps--;
    beginDoubleBeep();
  }
}

void startDoubleBeep() {
  if (!buzzerReady) return;
  // Keep confirmation tones distinct when two sensor events arrive close together.
  if (buzzerPattern != BUZZER_OFF) {
    if (queuedDoubleBeeps < 4) queuedDoubleBeeps++;
    return;
  }
  beginDoubleBeep();
}

void updateBuzzer() {
  if (buzzerPattern == BUZZER_OFF || millis() < buzzerStepDueAt) return;

  if (buzzerPattern == BUZZER_TEST_TONE || buzzerPattern == BUZZER_ACCESS_BEEP) {
    startNextBuzzerPattern();
    return;
  }

  // Two short tones with a short silent gap.
  if (buzzerStep == 0) {
    buzzerToneOff();
    buzzerStep = 1;
    buzzerStepDueAt = millis() + 90;
  } else if (buzzerStep == 1) {
    buzzerToneOn();
    buzzerStep = 2;
    buzzerStepDueAt = millis() + 110;
  } else if (buzzerStep == 2) {
    buzzerToneOff();
    buzzerStep = 3;
    buzzerStepDueAt = millis() + 90;
  } else {
    startNextBuzzerPattern();
  }
}

void setScreenNotice(ScreenNotice notice, unsigned long durationMs = 0) {
  screenNotice = notice;
  noticeStartedAt = millis();
  noticeExpiresAt = durationMs == 0 ? 0 : noticeStartedAt + durationMs;
}

void drawCenteredText(const String& text, int16_t y, uint8_t size = 1) {
  display.setTextSize(size);
  int16_t x1, y1;
  uint16_t width, height;
  display.getTextBounds(text.c_str(), 0, y, &x1, &y1, &width, &height);
  const int16_t x = width >= display.width() ? 0 : (display.width() - width) / 2;
  display.setCursor(x, y);
  display.print(text);
}

void drawSparkle(int16_t x, int16_t y, bool visible) {
  if (!visible) return;
  display.drawFastVLine(x, y - 3, 7, SSD1306_WHITE);
  display.drawFastHLine(x - 3, y, 7, SSD1306_WHITE);
}

void drawWelcomeFace(int16_t centerX, int16_t centerY, uint8_t frame) {
  display.fillCircle(centerX, centerY, 10, SSD1306_WHITE);
  display.drawCircle(centerX, centerY, 10, SSD1306_WHITE);

  if (frame == 3) {
    display.drawFastHLine(centerX - 5, centerY - 2, 3, SSD1306_BLACK);
    display.drawFastHLine(centerX + 2, centerY - 2, 3, SSD1306_BLACK);
  } else {
    display.fillCircle(centerX - 4, centerY - 2, 1, SSD1306_BLACK);
    display.fillCircle(centerX + 4, centerY - 2, 1, SSD1306_BLACK);
  }

  display.drawLine(centerX - 4, centerY + 3, centerX - 2, centerY + 5, SSD1306_BLACK);
  display.drawLine(centerX - 2, centerY + 5, centerX + 2, centerY + 5, SSD1306_BLACK);
  display.drawLine(centerX + 2, centerY + 5, centerX + 4, centerY + 3, SSD1306_BLACK);
}

void renderWelcomeScreen() {
  const uint8_t frame = static_cast<uint8_t>((millis() - noticeStartedAt) / 180 % 4);
  const int16_t bounce = (frame == 1 || frame == 2) ? 1 : 0;

  drawCenteredText("YOU CAN GO NOW", 1);
  String welcome = String("Thank you, ") + activeUserName;
  if (welcome.length() > 21) welcome = welcome.substring(0, 21);
  drawCenteredText(welcome, 14);
  drawCenteredText(activeDirection, 25);
  drawWelcomeFace(64, 48 - bounce, frame);
  drawSparkle(38, 44, frame == 0 || frame == 2);
  drawSparkle(90, 44, frame == 1 || frame == 3);
}

void renderDisplay() {
  if (!displayReady || millis() - lastDisplayAt < DISPLAY_REFRESH_MS) return;
  lastDisplayAt = millis();

  if (noticeExpiresAt != 0 && millis() >= noticeExpiresAt) {
    screenNotice = vehicleWaiting && !gateOpen ? NOTICE_TAP_RFID : NOTICE_IDLE;
    noticeExpiresAt = 0;
  }

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  switch (screenNotice) {
    case NOTICE_TAP_RFID:
      drawCenteredText("CAR DETECTED", 12);
      drawCenteredText("Tap your RFID", 32);
      break;
    case NOTICE_CHECKING:
      drawCenteredText("CARD READ", 12);
      drawCenteredText("Checking access...", 32);
      break;
    case NOTICE_WELCOME:
      renderWelcomeScreen();
      break;
    case NOTICE_DENIED:
      drawCenteredText("CARD NOT RECOGNIZED", 12);
      drawCenteredText("Please register", 30);
      drawCenteredText("this card first", 42);
      break;
    case NOTICE_SERVER_ERROR:
      drawCenteredText("SERVER OFFLINE", 14);
      drawCenteredText("Please try again", 32);
      break;
    case NOTICE_HARDWARE_ERROR:
      drawCenteredText("GATE UNAVAILABLE", 14);
      drawCenteredText("Check servo wiring", 32);
      break;
    case NOTICE_PASSAGE_START:
      drawCenteredText("CAR DETECTED", 12);
      drawCenteredText("Continue through", 30);
      drawCenteredText("the gate", 42);
      break;
    case NOTICE_NEXT_CAR:
      drawCenteredText("THANK YOU!", 4);
      drawCenteredText("Next vehicle", 24);
      drawCenteredText("come forward", 40);
      break;
    case NOTICE_TIMEOUT:
      drawCenteredText("GATE CLOSED", 14);
      drawCenteredText("Tap your ID again", 32);
      break;
    case NOTICE_IDLE:
    default:
      drawCenteredText("SMART PARKING", 8);
      if (gateOpen) {
        drawCenteredText("GATE OPEN", 27);
        drawCenteredText("Drive through", 43);
      } else {
        drawCenteredText("NEXT VEHICLE", 25);
        drawCenteredText("Come forward", 41);
      }
      break;
  }

  display.display();
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

uint8_t findOledAddress() {
  bool foundAnyI2cDevice = false;
  Serial.println("Scanning I2C bus for the OLED...");
  for (uint8_t address = 0x08; address <= 0x77; address++) {
    Wire.beginTransmission(address);
    if (Wire.endTransmission() != 0) continue;

    foundAnyI2cDevice = true;
    Serial.print("I2C device found at 0x");
    Serial.println(address, HEX);
    if (address == OLED_ADDRESS_1 || address == OLED_ADDRESS_2) return address;
  }

  Serial.println(foundAnyI2cDevice
    ? "I2C devices responded, but no OLED was found at 0x3C or 0x3D."
    : "No I2C device responded. Check OLED VCC, GND, SDA=GPIO21 and SCL=GPIO26.");
  return 0;
}

int postJsonRequest(const char* path, const String& body, String& responseBody,
                    uint16_t timeoutMs) {
  if (WiFi.status() != WL_CONNECTED) return -1000;

  WiFiClient client;
  HTTPClient http;
  http.setConnectTimeout(timeoutMs);
  http.setTimeout(timeoutMs);
  const String url = String(SERVER_BASE_URL) + path;
  if (!http.begin(client, url)) return -1001;

  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Key", DEVICE_API_KEY);
  const int statusCode = http.POST(body);
  if (statusCode > 0) responseBody = http.getString();
  http.end();
  return statusCode;
}

void printHttpFailure(const char* action, int statusCode) {
  Serial.print(action);
  if (statusCode > 0) {
    Serial.print(" failed with HTTP ");
    Serial.print(statusCode);
    if (statusCode == 401) Serial.println(" (device key rejected).");
    else if (statusCode == 404) Serial.println(" (server route not found).");
    else Serial.println(" (server rejected the request).");
  } else {
    Serial.print(" could not connect (HTTPClient code ");
    Serial.print(statusCode);
    Serial.println("). Check server IP, Wi-Fi, and Private-network firewall.");
  }
}

void connectToWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.println("Wi-Fi connection started in background; hardware is ready while it connects.");
}

void networkWorker(void* parameter) {
  NetworkJob job;
  unsigned long lastNetworkWarningAt = 0;

  for (;;) {
    if (xQueueReceive(networkQueue, &job, portMAX_DELAY) != pdTRUE) continue;

    // Old sensor snapshots are not useful to the live dashboard. Passage events are retained.
    if (job.type == NETWORK_HEARTBEAT && millis() - job.createdAt > 3000) continue;

    String response;
    int statusCode = -1000;
    if (job.type == NETWORK_CARD_AUTH) {
      const String body = String("{\"card_uid\":\"") + job.cardUid + "\"}";
      statusCode = postJsonRequest("/api/device/card-tap", body, response, 1400);

      AuthorizationResult result{};
      result.statusCode = static_cast<int16_t>(statusCode);
      if (statusCode >= 200 && statusCode < 300) {
        result.authorized = jsonTrueValue(response, "authorized");
        jsonStringValue(response, "event_id").toCharArray(result.eventId, sizeof(result.eventId));
        jsonStringValue(response, "user_name").toCharArray(result.userName, sizeof(result.userName));
        jsonStringValue(response, "direction").toCharArray(result.direction, sizeof(result.direction));
      }

      if (authorizationResultQueue != nullptr &&
          xQueueSend(authorizationResultQueue, &result, pdMS_TO_TICKS(100)) != pdTRUE) {
        Serial.println("Card authorization result queue is full.");
      }
      continue;
    }

    if (job.type == NETWORK_HEARTBEAT) {
      const String body = String("{\"gate_open\":") + (job.gateOpen ? "true" : "false") +
        ",\"ir_entry_detected\":" + (job.entryDetected ? "true" : "false") +
        ",\"ir_exit_detected\":" + (job.exitDetected ? "true" : "false") +
        ",\"vehicle_waiting\":" + (job.vehicleWaiting ? "true" : "false") +
        ",\"passage_started\":" + (job.passageStarted ? "true" : "false") +
        ",\"phase\":\"" + job.phase + "\"" +
        ",\"wifi_rssi\":" + String(job.wifiRssi) + "}";
      statusCode = postJsonRequest("/api/device/heartbeat", body, response, 900);
    } else {
      const String body = String("{\"event_id\":\"") + job.eventId + "\"}";
      for (uint8_t attempt = 0; attempt < 2; attempt++) {
        statusCode = postJsonRequest("/api/device/passage", body, response, 900);
        if (statusCode >= 200 && statusCode < 300) break;
        if (attempt == 0) vTaskDelay(pdMS_TO_TICKS(250));
      }

      if (statusCode >= 200 && statusCode < 300) {
        Serial.println("Vehicle passage time saved to Supabase.");
      } else {
        Serial.print("Vehicle passage upload failed (HTTPClient code ");
        Serial.print(statusCode);
        Serial.println("). Gate and IR monitoring remain responsive.");
      }
      continue;
    }

    if ((statusCode < 200 || statusCode >= 300) && WiFi.status() == WL_CONNECTED &&
        millis() - lastNetworkWarningAt >= 15000) {
      lastNetworkWarningAt = millis();
      Serial.print("Dashboard heartbeat unavailable (HTTPClient code ");
      Serial.print(statusCode);
      Serial.println("). Gate and sensor monitoring continue.");
    }
  }
}

bool queuePassageUpload(const String& eventId) {
  if (networkQueue == nullptr || eventId.length() != 36) return false;
  NetworkJob job{};
  job.type = NETWORK_PASSAGE;
  job.createdAt = millis();
  eventId.toCharArray(job.eventId, sizeof(job.eventId));
  return xQueueSend(networkQueue, &job, 0) == pdTRUE;
}

void monitorWifi() {
  const bool connected = WiFi.status() == WL_CONNECTED;
  if (connected && !wifiWasConnected) {
    wifiWasConnected = true;
    Serial.print("Wi-Fi connected. ESP32 IP: ");
    Serial.println(WiFi.localIP());
  } else if (!connected && wifiWasConnected) {
    wifiWasConnected = false;
    Serial.println("Wi-Fi disconnected. Hardware remains active; dashboard authorization is unavailable.");
  }

  if (!connected && millis() - lastWifiRetryAt >= WIFI_RETRY_INTERVAL_MS) {
    lastWifiRetryAt = millis();
    WiFi.reconnect();
  }
}

void printHardwareStatus(bool entryDetected, bool exitDetected) {
  Serial.print("Hardware status | OLED: ");
  Serial.print(displayReady ? "READY" : "NOT FOUND");
  Serial.print(" | Servo PWM: ");
  Serial.print(servoReady ? "READY" : "FAILED");
  Serial.print(" | Buzzer PWM: ");
  Serial.print(buzzerReady ? "READY" : "FAILED");
  Serial.print(" | Wi-Fi: ");
  Serial.print(WiFi.status() == WL_CONNECTED ? "CONNECTED" : "OFFLINE");
  Serial.print(" | Entry IR: ");
  Serial.print(entryDetected ? "DETECTED" : "CLEAR");
  Serial.print(" | Exit IR: ");
  Serial.println(exitDetected ? "DETECTED" : "CLEAR");
  Serial.println("RC522 version details are printed during startup above.");
}

void startServoDiagnostic() {
  if (!servoReady) {
    Serial.println("Servo test unavailable: LEDC did not attach to GPIO25.");
    return;
  }
  setServoAngle(GATE_OPEN_ANGLE);
  diagnosticServoOpen = true;
  diagnosticServoCloseAt = millis() + 2000;
  Serial.println("Servo test: gate-open position for 2 seconds, then close.");
}

void processSerialCommands(bool entryDetected, bool exitDetected) {
  while (Serial.available() > 0) {
    const char command = static_cast<char>(tolower(Serial.read()));
    if (command == '\r' || command == '\n' || command == ' ') continue;

    switch (command) {
      case 't':
        activeUserName = "Hardware test";
        activeDirection = "COMPONENT CHECK";
        if (displayReady) setScreenNotice(NOTICE_WELCOME, WELCOME_SCREEN_MS);
        else Serial.println("OLED test skipped: display was not detected at startup.");
        if (buzzerReady) startCardBeep();
        else Serial.println("Buzzer test skipped: PWM was not initialized.");
        startServoDiagnostic();
        Serial.println("Full hardware test started. The IR sensors remain live.");
        break;
      case 'b':
        if (buzzerReady) {
          startCardBeep();
          Serial.println("Buzzer test: 2-second tone.");
        } else {
          Serial.println("Buzzer test unavailable: PWM was not initialized.");
        }
        break;
      case 'o':
        startServoDiagnostic();
        break;
      case 'c':
        if (servoReady) {
          setServoAngle(0);
          diagnosticServoOpen = false;
          Serial.println("Servo moved to the configured closed position.");
        } else {
          Serial.println("Servo test unavailable: PWM was not initialized.");
        }
        break;
      case 'd':
        if (displayReady) {
          activeUserName = "Parking User";
          activeDirection = "DISPLAY TEST";
          setScreenNotice(NOTICE_WELCOME, WELCOME_SCREEN_MS);
          Serial.println("OLED welcome animation test started.");
        } else {
          Serial.println("OLED test unavailable: no display at 0x3C or 0x3D.");
        }
        break;
      case 's':
        printHardwareStatus(entryDetected, exitDetected);
        break;
      case '?':
        Serial.println("USB diagnostics: t=all components, b=buzzer, o=servo open/auto-close, c=servo close, d=OLED, s=status.");
        break;
      default:
        break;
    }
  }
}

void closeGate() {
  setServoAngle(0);
  gateOpen = false;
  passageStarted = false;
  vehicleWaiting = false;
  firstPassageSensor = SENSOR_NONE;
  Serial.println("Gate closed.");
}

bool openGate(const String& eventId, bool entryDetected, bool exitDetected) {
  if (!servoReady) {
    Serial.println("Access was authorized, but servo PWM is unavailable. Gate remains closed.");
    setScreenNotice(NOTICE_HARDWARE_ERROR, SHORT_MESSAGE_MS);
    return false;
  }
  activeEventId = eventId;
  setServoAngle(GATE_OPEN_ANGLE);
  gateOpen = true;
  gateOpenedAt = millis();
  passageStarted = !sensorSideDetected(firstPassageSensor, entryDetected, exitDetected);
  vehicleWaiting = false;
  Serial.println("Registered card approved. Gate open.");
  Serial.println(passageStarted
    ? "Approach sensor is clear; waiting for the sensor beyond the gate."
    : "Waiting for the vehicle to clear its approach sensor.");
  return true;
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

void handleCardTap() {
  const String cardUid = readCardUid();
  Serial.print("Card UID: ");
  Serial.println(cardUid);

  if (networkQueue == nullptr || authorizationResultQueue == nullptr) {
    Serial.println("Authorization service unavailable. Gate remains closed.");
    setScreenNotice(NOTICE_SERVER_ERROR, SHORT_MESSAGE_MS);
  } else {
    NetworkJob job{};
    job.type = NETWORK_CARD_AUTH;
    job.createdAt = millis();
    cardUid.toCharArray(job.cardUid, sizeof(job.cardUid));
    if (xQueueSendToFront(networkQueue, &job, 0) == pdTRUE) {
      authorizationPending = true;
      setScreenNotice(NOTICE_CHECKING);
      Serial.println("Checking card access in background; sensors remain live.");
    } else {
      Serial.println("Authorization queue is busy. Tap the card again shortly.");
      setScreenNotice(NOTICE_SERVER_ERROR, SHORT_MESSAGE_MS);
    }
  }

  reader.PICC_HaltA();
  reader.PCD_StopCrypto1();
  lastCardAt = millis();
}

void processAuthorizationResults(bool entryDetected, bool exitDetected) {
  if (authorizationResultQueue == nullptr) return;

  AuthorizationResult result{};
  while (xQueueReceive(authorizationResultQueue, &result, 0) == pdTRUE) {
    authorizationPending = false;
    if (!vehicleWaiting || millis() - vehicleWaitStartedAt > VEHICLE_WAIT_TIMEOUT_MS) {
      Serial.println("Card reply arrived after the vehicle wait ended. Gate remains closed.");
      continue;
    }
    if (result.statusCode < 200 || result.statusCode >= 300) {
      printHttpFailure("Card authorization request", result.statusCode);
      Serial.println("Gate remains closed.");
      setScreenNotice(NOTICE_SERVER_ERROR, SHORT_MESSAGE_MS);
      continue;
    }

    if (!result.authorized) {
      Serial.println("Access denied. Register this RFID UID in the dashboard first.");
      setScreenNotice(NOTICE_DENIED, SHORT_MESSAGE_MS);
      continue;
    }

    const String eventId = String(result.eventId);
    if (eventId.length() != 36) {
      Serial.println("Server reply did not include a valid event ID. Gate remains closed.");
      setScreenNotice(NOTICE_SERVER_ERROR, SHORT_MESSAGE_MS);
      continue;
    }

    activeUserName = result.userName[0] == '\0' ? "Driver" : String(result.userName);
    activeDirection = result.direction[0] == '\0' ? "PARKING ACCESS" : String(result.direction);
    activeDirection.toUpperCase();
    Serial.print("Access granted for ");
    Serial.println(activeUserName);
    Serial.print("Direction: ");
    Serial.println(activeDirection);
    if (openGate(eventId, entryDetected, exitDetected)) {
      startAccessBeep();
      setScreenNotice(NOTICE_WELCOME, WELCOME_SCREEN_MS);
    }
  }
}

void confirmVehiclePassage() {
  // The second sensor marks the end of the vehicle crossing.
  closeGate();
  if (!activeEventId.isEmpty()) {
    pendingPassageEventId = activeEventId;
    passageSavePending = true;
  }
  activeEventId = "";
  vehicleWaiting = false;
  passageStarted = false;
  firstPassageSensor = SENSOR_NONE;
  setScreenNotice(NOTICE_NEXT_CAR, SHORT_MESSAGE_MS);
}

void sendPendingPassage() {
  if (!passageSavePending) return;
  if (queuePassageUpload(pendingPassageEventId)) {
    pendingPassageEventId = "";
    passageSavePending = false;
  }
}

const char* dashboardPhaseName() {
  if (!servoReady) return "HARDWARE_ERROR";
  if (authorizationPending) return "CHECKING_ACCESS";
  if (gateOpen && passageStarted) return "PASSING";
  if (gateOpen) return "GATE_OPEN";
  if (vehicleWaiting) return "TAP_RFID";
  if (screenNotice == NOTICE_NEXT_CAR) return "NEXT_CAR";
  return "WAITING_FOR_CAR";
}

void sendHeartbeat(bool entryDetected, bool exitDetected) {
  if (networkQueue == nullptr) return;
  const unsigned long now = millis();
  const char* phase = dashboardPhaseName();
  const bool stateChanged = !heartbeatStateKnown || gateOpen != lastReportedGateOpen ||
    entryDetected != lastReportedEntryDetected || exitDetected != lastReportedExitDetected ||
    vehicleWaiting != lastReportedVehicleWaiting || passageStarted != lastReportedPassageStarted ||
    strcmp(phase, lastReportedPhase) != 0;
  if (now - lastHeartbeatAt < 150) return;
  if (!stateChanged && now - lastHeartbeatAt < HEARTBEAT_INTERVAL_MS) return;

  NetworkJob job{};
  job.type = NETWORK_HEARTBEAT;
  job.createdAt = now;
  job.gateOpen = gateOpen;
  job.entryDetected = entryDetected;
  job.exitDetected = exitDetected;
  job.vehicleWaiting = vehicleWaiting;
  job.passageStarted = passageStarted;
  job.wifiRssi = WiFi.status() == WL_CONNECTED ? WiFi.RSSI() : -127;
  strncpy(job.phase, phase, sizeof(job.phase) - 1);
  if (xQueueSend(networkQueue, &job, 0) != pdTRUE) return;

  lastHeartbeatAt = now;
  heartbeatStateKnown = true;
  lastReportedGateOpen = gateOpen;
  lastReportedEntryDetected = entryDetected;
  lastReportedExitDetected = exitDetected;
  lastReportedVehicleWaiting = vehicleWaiting;
  lastReportedPassageStarted = passageStarted;
  strncpy(lastReportedPhase, phase, sizeof(lastReportedPhase) - 1);
}

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(IR_ENTRY_PIN, INPUT);
  pinMode(IR_EXIT_PIN, INPUT);

  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  oledAddress = findOledAddress();
  displayReady = oledAddress != 0 && display.begin(SSD1306_SWITCHCAPVCC, oledAddress);
  if (displayReady) {
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    drawCenteredText("SMART PARKING", 18);
    drawCenteredText("Starting...", 36);
    display.display();
    Serial.print("OLED initialized at 0x");
    Serial.print(oledAddress, HEX);
    Serial.println(". SDA=GPIO21, SCL=GPIO26.");
  } else {
    Serial.println("OLED initialization failed. Check 3.3V, GND, GPIO21 SDA, GPIO26 SCL, and the display module.");
  }

  if (BUZZER_IS_ACTIVE) {
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);
    buzzerReady = true;
    Serial.println("Active buzzer ready on GPIO27 (HIGH=beep).");
  } else {
    buzzerReady = ledcAttach(BUZZER_PIN, 2000, 8);
    Serial.println(buzzerReady
      ? "Passive buzzer PWM ready on GPIO27."
      : "Buzzer PWM setup failed; other functions will continue.");
  }

  servoReady = ledcAttach(SERVO_PIN, SERVO_FREQUENCY, SERVO_RESOLUTION);
  if (servoReady) {
    setServoAngle(0);
    Serial.println("Servo PWM ready on GPIO25 at 50 Hz. Gate starts closed.");
  } else {
    Serial.println("Servo PWM setup failed on GPIO25. RFID, display, buzzer and IR checks will continue; the gate stays closed.");
    setScreenNotice(NOTICE_HARDWARE_ERROR);
  }

  SPI.begin(18, 19, 23, RFID_SS_PIN);
  reader.PCD_Init();
  delay(50);
  Serial.println("RC522 initialized.");
  reader.PCD_DumpVersionToSerial();

  networkQueue = xQueueCreate(8, sizeof(NetworkJob));
  authorizationResultQueue = xQueueCreate(2, sizeof(AuthorizationResult));
  if (networkQueue != nullptr && authorizationResultQueue != nullptr) {
    const BaseType_t taskCreated = xTaskCreatePinnedToCore(
      networkWorker, "ParkingNet", 8192, nullptr, 1, &networkTask, 0);
    if (taskCreated != pdPASS) {
      vQueueDelete(networkQueue);
      vQueueDelete(authorizationResultQueue);
      networkQueue = nullptr;
      authorizationResultQueue = nullptr;
      Serial.println("Network worker unavailable. Gate and sensors still run; dashboard updates are disabled.");
    }
  } else {
    if (networkQueue != nullptr) vQueueDelete(networkQueue);
    if (authorizationResultQueue != nullptr) vQueueDelete(authorizationResultQueue);
    networkQueue = nullptr;
    authorizationResultQueue = nullptr;
    Serial.println("Network queue unavailable. Gate and sensors still run; dashboard updates are disabled.");
  }

  connectToWifi();
  previousEntryDetected = isDetected(IR_ENTRY_PIN);
  previousExitDetected = isDetected(IR_EXIT_PIN);
  if (servoReady && previousEntryDetected) {
    vehicleWaiting = true;
    vehicleWaitStartedAt = millis();
    firstPassageSensor = SENSOR_ENTRY;
    startDoubleBeep();
    setScreenNotice(NOTICE_TAP_RFID);
    Serial.println("Vehicle already present at entry IR GPIO33; tap a registered RFID card.");
  } else {
    setScreenNotice(servoReady ? NOTICE_IDLE : NOTICE_HARDWARE_ERROR);
  }
  Serial.println("Smart Parking gate ready. Tap a registered RFID card.");
  Serial.println("USB hardware checks: send ? in Serial Monitor for commands.");
}

void loop() {
  const bool entryDetected = isDetected(IR_ENTRY_PIN);
  const bool exitDetected = isDetected(IR_EXIT_PIN);
  const bool entryRising = entryDetected && !previousEntryDetected;

  processSerialCommands(entryDetected, exitDetected);
  processAuthorizationResults(entryDetected, exitDetected);
  if (diagnosticServoOpen && millis() >= diagnosticServoCloseAt) {
    setServoAngle(0);
    diagnosticServoOpen = false;
    Serial.println("Servo test complete; returned to closed position.");
  }

  if (entryDetected != previousEntryDetected || exitDetected != previousExitDetected) {
    Serial.print("Entry IR: ");
    Serial.print(entryDetected ? "DETECTED" : "CLEAR");
    Serial.print(" | Exit IR: ");
    Serial.println(exitDetected ? "DETECTED" : "CLEAR");
  }

  // GPIO33 is the approach sensor. GPIO32 is only used to confirm the car
  // has passed the gate; it must never start a new RFID session by itself.
  if (servoReady && !gateOpen && !vehicleWaiting && entryRising) {
    vehicleWaiting = true;
    vehicleWaitStartedAt = millis();
    firstPassageSensor = SENSOR_ENTRY;
    startDoubleBeep();
    setScreenNotice(NOTICE_TAP_RFID);
    Serial.println("Entry IR GPIO33 detected a vehicle: fast double beep; tap your RFID.");
  }

  if (!gateOpen && vehicleWaiting && !authorizationPending &&
      millis() - vehicleWaitStartedAt >= VEHICLE_WAIT_TIMEOUT_MS) {
    vehicleWaiting = false;
    firstPassageSensor = SENSOR_NONE;
    setScreenNotice(NOTICE_IDLE);
    Serial.println("Vehicle wait expired; waiting for the next approach IR trigger.");
  }

  if (!gateOpen && vehicleWaiting && !authorizationPending &&
      millis() - lastCardAt >= CARD_COOLDOWN_MS &&
      reader.PICC_IsNewCardPresent() && reader.PICC_ReadCardSerial()) {
    handleCardTap();
  }

  if (gateOpen) {
    const SensorSide endSensor = firstPassageSensor == SENSOR_ENTRY ? SENSOR_EXIT : SENSOR_ENTRY;
    const bool approachDetected = sensorSideDetected(firstPassageSensor, entryDetected, exitDetected);
    const bool endSensorDetected = sensorSideDetected(endSensor, entryDetected, exitDetected);

    if (!passageStarted && !approachDetected) {
      passageStarted = true;
      Serial.println("Vehicle cleared its first IR sensor; waiting for the second IR.");
    }

    // Trigger on level after the first sensor clears; this also catches a long vehicle
    // that reaches the second sensor before it has fully cleared the first.
    if (passageStarted && endSensorDetected) {
      startDoubleBeep();
      Serial.println("Second IR detected the vehicle. Double beep and closing the gate.");
      confirmVehiclePassage();
    }

    if (gateOpen && millis() - gateOpenedAt >= GATE_TIMEOUT_MS) {
      Serial.println("Safety timeout: closing gate. No vehicle passage was recorded.");
      closeGate();
      activeEventId = "";
      setScreenNotice(NOTICE_TIMEOUT, SHORT_MESSAGE_MS);
    }
  }

  monitorWifi();
  sendHeartbeat(entryDetected, exitDetected);
  updateBuzzer();
  sendPendingPassage();
  renderDisplay();

  previousEntryDetected = entryDetected;
  previousExitDetected = exitDetected;
  delay(10);
}
