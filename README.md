# Plantry – Professional Plant Cultivation Tracker

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-brightgreen.svg)](https://play.google.com/store/apps/details?id=com.plantry.growlog)
[![Downloads](https://img.shields.io/badge/Downloads-10%2B-orange.svg)](https://play.google.com/store/apps/details?id=com.plantry.growlog)

**100% Offline. 100% Private. No accounts. No tracking. Open Source.**

Your data stays on your device – always.

---

## 📲 Download

<a href="https://play.google.com/store/apps/details?id=com.plantry.growlog">
  <img src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" height="50" alt="Get it on Google Play"/>
</a>

---

## 📸 Screenshots

<p float="left">
  <img src="https://play-lh.googleusercontent.com/sdlbEmzIw3ourKRJUitqaH5aeaJtxjzP61rlzpVJ-FB4Lj2MWFOPxZvbeeL7X5YSeWSQES4iWnjZ2g7BfjnGug=w526-h296" width="260"/>
  <img src="https://play-lh.googleusercontent.com/YUxDvrAgtwLCkCLu9mpbf-vsWu6A7t35YIm7zQ_9RAdCq4eGeGeH4yiT-Iko2uz3EXXWfqGVSIN0pbOe3Pt8UA=w526-h296" width="260"/>
  <img src="https://play-lh.googleusercontent.com/zhdWYapJvMYDfUOYN39tf6vItER1wzVvGT9xxmTV_AgcegMBzkmQHsceV_5JP04SgYxWJD19H5IUc5Q3F_5G=w526-h296" width="260"/>
  <img src="https://play-lh.googleusercontent.com/UYAEBbSbbWF7iVRsrp-cW4gnRUH180opuVco0FZWawgu014ZL4lZcs8Mg9oMNmV-g_ZvB8i6pZhWKEcgIRJu=w526-h296" width="260"/>
</p>

---

## ✨ Features

| Category | Details |
|---|---|
| 🌱 **Plant Management** | Profiles, strain tracking, growth stages (germ → veg → flower → harvest) |
| 📖 **Grow Journal** | Daily logs, pH/EC/temp/humidity, watering & feeding, photo per entry |
| 🏠 **Room Management** | Multiple grow rooms, equipment, irrigation system, medium & nutrients |
| 🌾 **Harvest Tracking** | Yield, dry weight, drying & curing, quality rating |
| 💡 **Expert Mode** | RDWC, DWC, Hydro, Soil, Coco, Aero – advanced system tracking |
| 📊 **Health Score** | Intelligent 0–100 plant health monitoring |
| 🔔 **Notifications** | Offline reminders for watering, feeding, photos |
| 💾 **Backup & Restore** | Full export/import as ZIP – photos included |
| 🌍 **Multi-Language** | German & English |
| 🎨 **Dark Mode** | Full dark mode support |

---

## 🔐 Privacy & Security

- ✅ No user accounts required
- ✅ No internet connection needed
- ✅ No advertising or tracking
- ✅ No analytics or telemetry
- ✅ All data stored locally via SQLite
- ✅ Open source – verify it yourself

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x / Dart |
| Database | SQLite (local, offline-first) |
| State Management | Provider |
| Architecture | Clean Architecture, Repository Pattern, Dependency Injection |

---

## 🚀 Build from Source

**Prerequisites:** Flutter SDK 3.x, Android SDK

```bash
git clone https://github.com/leydanielley/Plantry.git
cd Plantry
flutter pub get
flutter run
```

**Release build:**

```bash
flutter build apk --release
flutter build appbundle --release   # For Play Store
```

---

## 📁 Project Structure

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

---

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

> **Note:** This is a portfolio project. All pull requests require approval.

---

## 📄 License

MIT License – see [LICENSE](LICENSE)

---

## 👤 Author

**Daniel Ley**
- IT Systems Integration Specialist (Fachinformatiker Systemintegration) – GFN Köln, 2025–2027
- Business: Daniel Ley Tech Services
- GitHub: [@leydanielley](https://github.com/leydanielley)
- Contact: ley.daniel.ley@gmail.com

---

## ⚖️ Disclaimer

Plantry is designed for legal plant cultivation activities only.
Users are responsible for ensuring their use complies with all applicable local laws and regulations.

---

*Plantry – Grow smarter, stay private.* 🌱
