# Home Security System

A comprehensive home security solution developed using ESP32 microcontroller and Flutter mobile application.

## Features

### Hardware Components
- ESP32 microcontroller
- HC-SR04 ultrasonic distance sensor
- LCD display
- LEDs
- Buzzer
- Relay
- RFID card reader

### Main Features
1. **Motion Detection System**
   - Motion detection with 50cm distance threshold
   - Authentication required within 5 seconds
   - Status notifications on LCD display

2. **Access Control System**
   - RFID card access
   - PIN code verification
   - 10-second authorization period
   - Authorized/unauthorized access control

3. **Flutter Mobile Application**
   - Real-time system status monitoring
   - RFID card management (add/remove)
   - Instant notification system
   - System settings management

## Installation

### Hardware Setup
1. Connect ESP32 according to the schematic
2. Connect sensors and other components
3. Upload ESP32 code

### Mobile App Setup
1. Install Flutter
2. Install project dependencies:
   ```bash
   flutter pub get
   ```
3. Build and run the application:
   ```bash
   flutter run
   ```

## Project Structure
- `/esp32_code` - ESP32 firmware code
- `/lib` - Flutter application code
- `/assets` - Application assets and resources

## Requirements
- Flutter SDK
- Arduino IDE
- ESP32 Board Manager
- Required Arduino libraries

## License
This project is licensed under the MIT License.

## Contact
For questions and suggestions, please open an issue on GitHub.
