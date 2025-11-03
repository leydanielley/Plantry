# GrowLog - Plant Growing Journal

**Version:** 0.7.0
**Privacy-First:** 100% Offline Plant Tracking

---

## Overview

GrowLog is a private plant growing journal and log tracking application built with Flutter. All data is stored locally on your device with no cloud services, analytics, or tracking.

## Features

- 🌱 **Plant Management** - Track multiple plants with detailed profiles
- 📊 **Growth Logs** - Record daily observations, watering, feeding, and notes
- 📷 **Photo Gallery** - Document growth with photos
- 🏠 **Room & Grow Management** - Organize plants by location and grow cycles
- 💧 **Fertilizer Tracking** - Track nutrients and feeding schedules
- 🔧 **Hardware Management** - Catalog your growing equipment
- 🌾 **Harvest Tracking** - Record yields, drying, curing, and quality
- 💾 **Backup & Restore** - Export/import your data as ZIP files
- 🎨 **Dark Mode** - Full dark mode support
- 🔒 **100% Private** - All data stays on your device

## Technical Details

- **Framework:** Flutter 3.9.2+
- **Database:** SQLite (sqflite)
- **Version:** 0.7.0
- **Database Version:** 2
- **Architecture:** Clean architecture with Repository pattern, Dependency Injection, and Provider state management

## Privacy & Security

✅ **No network connections** - App works completely offline
✅ **No analytics or tracking**
✅ **No cloud services**
✅ **Local-only data storage**
✅ **Full user control over data**

See [SECURITY_AUDIT_REPORT.md](SECURITY_AUDIT_REPORT.md) for detailed security audit results.

## Database Migrations

The app includes an automatic migration system that preserves your data when updating from the App Store or Play Store. See migration documentation in `lib/database/migrations/` for details.

## Building

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK (Android)
flutter build apk --release

# Build iOS app
flutter build ios --release
```

## Project Structure

```
lib/
├── database/         # Database schema and migrations
├── models/           # Data models
├── repositories/     # Data access layer
├── providers/        # State management
├── screens/          # UI screens
├── widgets/          # Reusable UI components
├── services/         # Business logic services
├── utils/            # Utilities and helpers
└── di/               # Dependency injection setup
```

## License

Private project - All rights reserved

---

**Built with Flutter ❤️**
