# Home Security System

A comprehensive home security solution developed using ESP32 microcontroller and Flutter mobile application. This system provides real-time monitoring, motion detection, and access control features for your home security needs.

## Table of Contents
- [Features](#features)
- [System Architecture](#system-architecture)
- [Hardware Setup](#hardware-setup)
- [Software Installation](#software-installation)
- [Mobile App Usage Guide](#mobile-app-usage-guide)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Features

### Hardware Components
- ESP32 microcontroller
- HC-SR04 ultrasonic distance sensor
- LCD display (16x2)
- Status LEDs (Red, Green, Yellow)
- Buzzer for alerts
- Relay for additional security devices
- RFID card reader (MFRC522)

### Main Features
1. **Motion Detection System**
   - Precise motion detection with 50cm distance threshold
   - Configurable detection range
   - Authentication required within 5 seconds
   - Real-time status notifications on LCD display
   - Automatic alarm triggering

2. **Access Control System**
   - RFID card access with secure authentication
   - PIN code verification system
   - 10-second authorization period
   - Authorized/unauthorized access control
   - Access logs with timestamp
   - Multiple user support

3. **Flutter Mobile Application**
   - Real-time system status monitoring
   - RFID card management (add/remove/disable)
   - User-friendly interface
   - Push notification system
   - System settings management
   - Access history and logs
   - Remote system control

## System Architecture

```
                   ┌─────────────────┐
                   │   Flutter App   │
                   └────────┬────────┘
                           │
                           │ HTTPS/WebSocket
                           │
                   ┌───────▼────────┐
                   │   ESP32 Core   │
                   └───┬───────┬────┘
           ┌───────────┘       └──────────┐
           │                              │
   ┌───────▼─────┐               ┌───────▼─────┐
   │   Sensors   │               │   Control    │
   │  (HC-SR04)  │               │   Outputs   │
   └─────────────┘               └─────────────┘
```

## Hardware Setup

### Components List
1. ESP32 Development Board
2. HC-SR04 Ultrasonic Sensor
3. 16x2 LCD Display
4. MFRC522 RFID Reader
5. LEDs (Red, Green, Yellow)
6. Buzzer
7. Relay Module
8. Jumper Wires
9. Breadboard/PCB

### Wiring Diagram
- ESP32 Pin Connections:
  - GPIO21 -> LCD SDA
  - GPIO22 -> LCD SCL
  - GPIO5  -> RFID SDA
  - GPIO18 -> RFID SCK
  - GPIO23 -> RFID MOSI
  - GPIO19 -> RFID MISO
  - GPIO4  -> HC-SR04 TRIG
  - GPIO2  -> HC-SR04 ECHO

## Software Installation

### Prerequisites
- Flutter SDK (2.5.0 or higher)
- Arduino IDE (2.0.0 or higher)
- ESP32 Board Manager
- Required Arduino Libraries:
  - `MFRC522`
  - `LiquidCrystal_I2C`
  - `ArduinoJson`
  - `WebSocketsServer`

### ESP32 Setup
1. Install Arduino IDE
2. Add ESP32 board support
3. Install required libraries
4. Upload the code from `/esp32_code` folder

### Mobile App Setup
1. Install Flutter SDK
2. Clone this repository:
   ```bash
   git clone https://github.com/Gurtdereli/Home-Security-System.git
   ```
3. Install dependencies:
   ```bash
   cd Home-Security-System
   flutter pub get
   ```
4. Build and run the application:
   ```bash
   flutter run
   ```

## Mobile App Usage Guide

### First Time Setup
1. Launch the app
2. Connect to ESP32:
   - Go to Settings
   - Enter ESP32's IP address
   - Test connection

### Main Features

#### Dashboard
- Real-time status monitoring
- Quick actions:
  - Arm/Disarm system
  - View current status
  - Check last events

#### RFID Card Management
1. Adding a new card:
   - Go to "Cards" section
   - Click "Add New Card"
   - Scan the card on RFID reader
   - Enter card details
   - Save

2. Managing existing cards:
   - View all cards
   - Enable/Disable cards
   - Delete cards
   - View card usage history

#### Notifications
- Configure notification preferences:
  - Motion detection alerts
  - Unauthorized access attempts
  - System status changes
  - Low battery warnings

#### Settings
- System Configuration:
  - Detection range
  - Alarm duration
  - Authorization timeout
  - LCD display options
- Network Settings:
  - WiFi configuration
  - IP address settings
- User Preferences:
  - Theme selection
  - Language settings
  - Notification preferences

## Configuration

### ESP32 Configuration
Edit `config.h` in ESP32 code:
```cpp
#define WIFI_SSID "Your_SSID"
#define WIFI_PASSWORD "Your_Password"
#define MOTION_THRESHOLD 50  // Distance in cm
#define AUTH_TIMEOUT 5000    // Time in milliseconds
```

### App Configuration
Edit `lib/config/app_config.dart`:
```dart
class AppConfig {
  static const String defaultServerIP = '192.168.1.100';
  static const int defaultServerPort = 80;
  static const int connectionTimeout = 5000;
}
```

## Troubleshooting

### Common Issues
1. Connection Problems
   - Verify ESP32 IP address
   - Check WiFi connection
   - Ensure proper port forwarding

2. Sensor Issues
   - Check wiring connections
   - Verify power supply
   - Calibrate sensors if needed

3. App Problems
   - Clear app cache
   - Update to latest version
   - Check system requirements

## Contributing
1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Contact
For questions and suggestions, please open an issue on GitHub.
