# Plantry - Professional Plant Tracking App

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-brightgreen.svg)](https://play.google.com/store)

**100% Offline. 100% Private. Open Source.**

Your data stays on your device. No cloud, no servers, no tracking.

---

## Features

- **Grow Rooms & Tents** - Manage multiple grow environments
- **Plant Tracking** - Track plants from seedling to harvest
- **Nutrient Documentation** - Log pH, EC, PPM values
- **Growth Phases** - Document every stage of growth
- **Harvest Logging** - Record yields with weight and notes
- **Photo Documentation** - Capture growth with timestamped photos
- **Expert Mode** - Advanced features for RDWC, DWC, Hydro, Soil, Coco, Aero
- **Health Score** - Intelligent plant health monitoring (0-100)
- **Notifications** - Offline reminders for watering, feeding, photos
- **Multi-Language** - German & English
- **Dark Mode** - Full dark mode support
- **Backup & Restore** - Export/import your data as ZIP

## Tech Stack

- **Framework:** Flutter 3.x / Dart
- **Database:** SQLite (local, offline)
- **State Management:** Provider
- **Architecture:** Clean Architecture with Repository pattern & DI

## Installation

### From Google Play Store
Coming soon.

### Build from Source

```bash
# Prerequisites: Flutter SDK 3.x, Android SDK

git clone https://github.com/leydanielley/Plantry.git
cd Plantry
flutter pub get
flutter run
```

#### Release Build
```bash
flutter build apk --release
flutter build appbundle --release   # For Play Store
```

## Project Structure

```
lib/
├── config/          # App configuration
├── database/        # SQLite schema & migrations
├── di/              # Dependency injection
├── models/          # Data models
├── providers/       # State management
├── repositories/    # Data access layer
├── screens/         # UI screens
├── services/        # Business logic
├── utils/           # Utilities, translations, helpers
└── widgets/         # Reusable UI components
```

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Note:** This is a portfolio project. All pull requests require approval.

## Privacy & Security

- No network connections - works completely offline
- No analytics or tracking
- No cloud services
- All data stored locally on your device
- Open source - verify it yourself

## License

MIT License - see [LICENSE](LICENSE)

## Author

**Daniel Ley**
- Portfolio project during IT Systems Integration apprenticeship (2025-2027)
- GitHub: [@leydanielley](https://github.com/leydanielley)

## Disclaimer

This app is for educational and legal cultivation purposes only.
Users are responsible for complying with local laws and regulations.

---

**Made with Flutter for the growing community**
