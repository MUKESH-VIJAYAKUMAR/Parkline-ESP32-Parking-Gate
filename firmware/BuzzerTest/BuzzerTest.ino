// Standalone buzzer check for the ESP32 parking project.
// GPIO27 is the buzzer pin used by ParkingGate.ino.
// Use direct GPIO drive only with a 3.3 V, low-current buzzer.

constexpr uint8_t BUZZER_PIN = 27;

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  Serial.println("Buzzer test starting on GPIO27.");
  Serial.println("Active-buzzer test: three clear beeps.");
  for (uint8_t i = 0; i < 3; ++i) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(400);
    digitalWrite(BUZZER_PIN, LOW);
    delay(350);
  }

  Serial.println("Passive-buzzer test: 2 kHz tone for one second.");
  if (ledcAttach(BUZZER_PIN, 2000, 8)) {
    ledcWriteTone(BUZZER_PIN, 2000);
    delay(1000);
    ledcWriteTone(BUZZER_PIN, 0);
    ledcDetach(BUZZER_PIN);
    Serial.println("PWM tone test complete.");
  } else {
    Serial.println("PWM could not attach to GPIO27.");
  }

  Serial.println("Test complete. It will repeat every three seconds.");
}

void loop() {
  delay(3000);
  for (uint8_t i = 0; i < 3; ++i) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(400);
    digitalWrite(BUZZER_PIN, LOW);
    delay(350);
  }

  if (ledcAttach(BUZZER_PIN, 2000, 8)) {
    ledcWriteTone(BUZZER_PIN, 2000);
    delay(1000);
    ledcWriteTone(BUZZER_PIN, 0);
    ledcDetach(BUZZER_PIN);
  }
}
