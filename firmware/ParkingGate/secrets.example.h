#pragma once

// Copy this file to secrets.h and set these values on the computer that runs Flask.
// Keep secrets.h out of Git. ESP32 WROOM boards require a 2.4 GHz Wi-Fi network.
#define WIFI_SSID "YOUR_2_4_GHZ_WIFI_NAME"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Use the computer's current IPv4 address from ipconfig, not 127.0.0.1.
#define SERVER_BASE_URL "http://YOUR_COMPUTER_LAN_IP:5000"

// Must match ESP32_API_KEY in the Flask project's local .env file.
#define DEVICE_API_KEY "PASTE_THE_LOCAL_DEVICE_KEY_HERE"
