# navic
NavIC Navigation App 📍🛰️
A Flutter mobile application that detects and utilizes NavIC (Navigation with Indian Constellation) - India's regional satellite navigation system.

🚀 Features
🛰️ NavIC Hardware Detection
Automatic hardware detection - Checks if your device supports NavIC/IRNSS


Real-time satellite monitoring - Detects active IRNSS satellites

Hardware capability analysis - Uses Android GNSS capabilities API

📍 Location Services
Dual-system positioning - Uses NavIC when available, falls back to GPS

Enhanced accuracy - Better precision with NavIC satellites

Confidence scoring - Shows location reliability percentage

🗺️ Mapping & Navigation
Multiple map layers - OpenStreetMap, ESRI Imagery, and more

Real-time location tracking - Live position updates

Accuracy visualization - Shows location accuracy radius

🆘 Emergency Features
Emergency sharing - Quick location sharing in emergencies

External map integration - Opens location in external maps

🔧 Technical Details
Supported Systems
NavIC/IRNSS - Indian Regional Navigation Satellite System

GPS - Global Positioning System (fallback)

GNSS Capabilities - Android 12+ hardware detection

Detection Methods
GNSS Capabilities - hasIrnss() method (Android 12+)

Satellite Monitoring - Real-time IRNSS constellation detection

Hardware Analysis - Device capability checking

📱 Usage
For Users
Open the app - Automatic hardware detection starts

Check status - See if your device supports NavIC

Get location - App uses best available positioning system

View details - See satellite count and confidence scores

For Developers
The app demonstrates:

Native Android integration with Kotlin/Java

GNSS hardware access via method channels

Real-time satellite data processing



Flutter UI Layer
    ↓
Location Service (Dart)
    ↓
Hardware Service (Method Channel)
    ↓
Native Android (Kotlin/Java)
    ↓
GNSS Hardware & Satellites
Multi-system location services


Android device with location services

Android 7.0+ (API 24+) for basic functionality

Android 12+ (API 31+) for advanced GNSS capabilities

Location permissions enabled

🎯 Use Cases
Indian users wanting NavIC-enhanced positioning

Developers learning GNSS integration

Emergency services needing reliable location

Outdoor navigation with enhanced accuracy

🔍 Detection Results
The app shows one of three states:

✅ NavIC Active - Hardware supported and satellites in use

🔵 NavIC Ready - Hardware supported, acquiring satellites

🟠 GPS Only - Using standard GPS positioning

📞 Support
This app demonstrates real NavIC hardware detection and usage. Perfect for understanding satellite navigation systems and mobile GNSS integration!

