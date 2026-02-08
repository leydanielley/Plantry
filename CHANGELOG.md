# Changelog

All notable changes to Plantry will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.20.69] - 2026-02-08

### Open Source Release

#### Added
- Open source under MIT License
- Support/Donate button in settings (PayPal)
- Developer info, GitHub link, and license info in About section
- CONTRIBUTING.md with contribution guidelines
- GitHub issue and PR templates
- CODEOWNERS for protected files

#### Changed
- App is now completely free (was paid during beta)
- Privacy Policy contact changed to GitHub Issues
- Comprehensive .gitignore for open source

#### Technical
- Build Number: 69
- Database Version: 37 (stable, unchanged)
- New dependency: url_launcher for external links

---

## [1.0.0] - 2025-11-24

### 🎉 First Production Release

This is the first stable production release of Plantry, ready for the Google Play Store!

### ✨ New Features

#### Complete Internationalization (i18n)
- **Full bilingual support**: German and English languages
- **Dynamic language switching**: Change language on-the-fly in settings
- **884 translation keys**: Every UI element properly translated
- **No more hardcoded strings**: All user-facing text uses translation system
- Fixed 9 critical UI elements that showed mixed languages

### 🐛 Critical Bug Fixes (Sprint 1)

#### Database & Data Integrity
- **Fix #1**: Phase changes now correctly update vegDate, bloomDate, and harvestDate
- **Fix #2**: Standardized foreign key CASCADE rules (Migration v36)
  - Prevents orphaned data when deleting rooms/grows/plants
  - Ensures referential integrity across all tables
- **Fix #3**: Added delete validation for rooms and grows
  - Prevents deletion of rooms with active plants
  - Prevents deletion of grows with active plants
- **Fix #4**: Duplicate log prevention at repository layer
  - Prevents creating multiple logs for same plant on same timestamp
- **Fix #5**: RDWC bucket uniqueness validation
  - Ensures each bucket can only be assigned to one plant per system
- **Fix #6**: Added missing database indexes for performance
  - plant_id, grow_id, room_id indexes for faster queries
  - Significant performance improvement for large databases
- **Fix #7**: Added SchemaRegistry definitions for v36 and v37
  - Proper schema documentation and migration tracking

#### Stability & Recovery
- **CRITICAL**: Removed false positive recovery warnings
  - App no longer shows unnecessary "Database corrupted" messages
  - Fixed recovery detection logic to only trigger on actual issues
- **Database fix**: Multiple logs per day now work correctly
  - Fixed constraint that prevented logging multiple times daily

### 🔧 Technical Improvements

#### Code Quality
- **Test cleanup**: Fixed all test failures caused by Sprint 1 changes
- **Database schema**: Stable at v37 with comprehensive migration history
- **Error handling**: Improved error messages and user feedback
- **Performance**: Added strategic indexes for faster queries
- **Validation**: Repository-level validation prevents data corruption

#### Architecture
- **Clean separation**: UI, business logic, and data layers properly separated
- **Type safety**: All enums and models properly validated
- **Transaction safety**: All multi-step operations use database transactions

### 📊 Technical Details
- **Build Number**: 49 (Google Play)
- **Database Version**: 37
- **Supported Android**: 5.0 Lollipop (API 21) to Android 15 (API 35)
- **APK Size**: ~62MB (optimized with R8 shrinking)
- **Architecture Support**: ARM32, ARM64, x86, x86_64

### 📱 Compatibility
- **Device Support**: 99%+ of all Android devices
- **Tablet Support**: Full support for all screen sizes
- **Offline Mode**: 100% offline functionality
- **Languages**: German (de), English (en)

### 🎯 Quality Metrics
- Flutter Analyze: ✅ 0 errors, 2 minor style suggestions
- All Critical Tests: ✅ Passing
- Database Migrations: ✅ v1 → v37 fully tested
- Production Build: ✅ Successful

---

## [0.9.1] - 2025-11-09

### 🐛 Critical Data Loss Bugs Fixed
- **FIXED**: RDWC Full Change logs could not be saved (database constraint violation)
  - Root cause: `RdwcLogType.fullChange` incorrectly converted to database format
  - Fixed: Explicit enum-to-database conversion with switch-case for all log types

- **FIXED**: All RDWC logs disappeared when updating an existing log with fertilizers
  - Root cause: Old fertilizers not deleted before inserting new ones in updateLog()
  - Fixed: `rdwc_repository.dart:293-300` now properly clears old fertilizer entries

- **FIXED**: RDWC logs could not be loaded from database (deserialization error)
  - Root cause: `RdwcLog.fromMap()` used incorrect enum parsing
  - Fixed: Explicit database-to-enum conversion for all log types

- **FIXED**: Fertilizer amount types not saved correctly
  - Root cause: `FertilizerAmountType` enum conversion logic was incomplete
  - Fixed: Both `toMap()` and `fromMap()` now use explicit switch-case conversion

- **FIXED**: PlantLog phase change actions incorrectly saved
  - Root cause: `ActionType.phaseChange` conversion used fragile string replacement
  - Fixed: Explicit switch-case conversion for all action types

### 🔧 Technical Improvements
- **Added 13 unit tests** verifying all enum serialization fixes
- **Tested roundtrip serialization** (save → load) for all affected models
- **Fixed syntax error** in `i_fertilizer_repository.dart` (prevented compilation)

### 📊 Testing
- All tests passed: 13/13 ✅
- Flutter analyze: No errors
- Production build: Successful
- App tested on Android emulator: All RDWC features working

### 📱 Technical Details
- Build Number: 16 (Google Play)
- Database Version: 11
- Fixed Models: RdwcLog, RdwcLogFertilizer, PlantLog
- All RDWC log types now fully functional: addback, fullChange, maintenance, measurement

---

## [0.9.0] - 2025-11-08

### 🐛 Critical Bug Fixes
- **FIXED**: 10 async setState bugs that could cause "setState after dispose" crashes
  - add_grow_screen.dart: Added mounted check in _loadRooms()
  - edit_grow_screen.dart: Added mounted check in _loadRooms()
  - grow_detail_screen.dart: Added mounted check in _loadPlants()
  - hardware_list_screen.dart: Added mounted check in _loadHardware()
  - settings_screen.dart: Fixed 8 methods with incorrect mounted check pattern
    - _loadSettings(), _changeLanguage(), _toggleDarkMode(), _toggleExpertMode()
    - _changeNutrientUnit(), _changePpmScale(), _changeTemperatureUnit()
    - _changeLengthUnit(), _changeVolumeUnit()
  - All mounted checks now BEFORE setState (previously some were after)

### ✨ RDWC Improvements
- **NEW**: RDWC Log Edit/Delete functionality
  - Click log tiles to edit existing logs
  - Long-press log tiles to delete with confirmation
  - All log types supported (addback, full change, measurement, maintenance)
  - Fertilizer data correctly loaded when editing
  - Proper cleanup of dynamically created controllers

### 🔒 Error Handling Improvements
- **IMPROVED**: hardware_list_screen.dart now shows user feedback on toggle errors
- **IMPROVED**: All async operations now properly check if widget is mounted
- **IMPROVED**: Better memory management with proper controller disposal

### 📊 Code Quality
- **Code Audit**: Comprehensive code quality check performed
- **Memory Leaks**: All TextEditingController properly disposed
- **Null Safety**: No force-unwrap operators found
- **Error Handling**: All repository methods have proper error handling
- Flutter analyze: ✅ No issues found

### 📱 Technical
- Build Number: 14 (Google Play)
- Database Version: 10 (Phase History System)
- Overall Code Quality: 85/100 → 95/100
- All bugs found and fixed during systematic code review

---

## [0.8.5] - 2025-11-07

### 🐛 Critical Bug Fixes
- **FIXED**: Boot screen hang during database migration v7→v8
  - Added error handling in BackupService for non-existent tables during migration
  - App now starts successfully in ~93ms
- **FIXED**: Build failure with flutter_local_notifications
  - Enabled core library desugaring for Java 8+ API support
  - Added desugar_jdk_libs dependency

### ✨ Improvements
- Enhanced backup service to gracefully handle missing tables
- Added RDWC tables to backup/restore configuration
- Improved migration stability and error handling

### 📱 Device Compatibility (NEW!)
- **Maximum Device Support**: Now supports 99%+ of all Android devices
- **Architecture Support**: ARM32, ARM64, x86, x86_64 (all CPU types)
- **Tablet Support**: Full support for tablets including Xiaomi, Samsung, Huawei
- **Screen Sizes**: Small phones to large tablets (all supported)
- **MinSDK**: Android 5.0 Lollipop (2014) - 11 years of devices!
- **TargetSDK**: Android 14 for best compatibility
- **Camera**: Optional (tablets without camera can use the app)
- **MultiDex**: Enabled for older devices

### 📱 Technical
- Build Number: 5
- Database Version: 8 (RDWC Expert Mode)
- All features tested and verified working
- APK Size: 61.6MB (optimized with tree-shaking)

---

## [0.9.0] - 2025-11-06

### 🎉 Major Features

#### Intelligente Benachrichtigungen (100% Offline) 🔔
- **Gieß-Erinnerungen**: Automatische Benachrichtigungen basierend auf letztem Log-Eintrag
- **Dünger-Erinnerungen**: Konfigurierbare Intervalle für Nährstoffgaben
- **Foto-Erinnerungen**: Wöchentliche Erinnerung für Wachstums-Dokumentation
- **Ernte-Countdown**: Benachrichtigung 3 Tage vor geschätzter Ernte
- **Individuelle Einstellungen**: Pro Pflanze oder global konfigurierbar
- **Test-Funktion**: Benachrichtigungen testen mit einem Klick

#### Health Score & Warnungs-System 💚
- **Pflanzen-Gesundheits-Score (0-100)**: Intelligente Bewertung basierend auf 5 Faktoren
  - Bewässerung-Regelmäßigkeit (30%)
  - pH-Stabilität (25%)
  - Nährstoff-Gesundheit/EC-Trends (20%)
  - Foto-Dokumentation (15%)
  - Log-Aktivität (10%)
- **Echtzeit-Warnungen**: Automatische Erkennung von Problemen
  - pH/EC außerhalb des optimalen Bereichs
  - Lange keine Bewässerung
  - EC steigt kontinuierlich (Salzaufbau)
  - Unregelmäßige Pflege
- **Intelligente Empfehlungen**: Konkrete Verbesserungsvorschläge
- **Visuelle Indikatoren**: Farbcodierte Health-Level (Exzellent → Kritisch)
- **Faktor-Breakdown**: Detaillierte Ansicht aller Score-Komponenten

### ✨ Improvements
- **Neue Berechtigungen**: POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM (Android 13+)
- **Notification Settings Screen**: Eigener Screen für alle Benachrichtigungs-Einstellungen
- **Health Score Widget**: Wiederverwendbare Komponente für Pflanzen-Details
- **Erweiterte Übersetzungen**: 50+ neue Übersetzungs-Keys (DE + EN)

### 📋 Documentation
- **QUALITY_OF_LIFE_FEATURES_TODO.md**: Roadmap für 8 weitere geplante Features
- **Dokumentations-Cleanup**: 9 alte/veraltete .md Dateien entfernt

### 🐛 Bug Fixes
- Alle Flutter analyze Warnings behoben (0 Issues)
- Code-Qualität verbessert

### 📱 Technical
- Dependencies: flutter_local_notifications ^17.2.4, timezone ^0.9.4
- Build Number: 4
- Alle Features 100% offline funktionsfähig

---

## [0.8.0] - 2025-01-06

### 🎉 Major Features

#### Advanced RDWC Logging (Hydro Buddy Style)
- **Individual Fertilizer Tracking**: Log ml amounts and see PPM/EC contribution per fertilizer
- **Real-time Calculations**: See individual and total nutrient contributions as you type
- **Expandable Log Entries**: Tap logs to view detailed nutrient breakdown with visual indicators

#### 4 Specialized Log Types
- **Quick Measurement**: Fast logging for daily checks (water level, pH, EC)
- **Water Addback**: Track refills with water consumption and nutrients
- **Full Reservoir Change**: Document complete water changes with old/new values and cleaning checklist
- **Maintenance**: System upkeep checklist (pumps, filters, tubes, airstones)

### ✨ Improvements
- **Dynamic Forms**: Forms adapt to show only relevant fields for each log type
- **Modern UI Components**: Replaced deprecated radio buttons with SegmentedButton
- **Better Visual Hierarchy**: Icons and colors for each log type
- **Enhanced Detail View**: Professional fertilizer breakdown with color-coded bars

### 🐛 Bug Fixes
- Fixed all Flutter deprecation warnings
- Cleaned up unused variables
- Improved code quality and maintainability

### 📱 Technical
- Flutter SDK: 3.9.2
- Build Number: 2
- All existing features remain available

---

## [0.7.0] - 2024-12-XX

### Initial Play Store Release
- Plant tracking and journal
- RDWC system management
- Photo documentation
- Export/Import functionality
- Multi-language support (EN/DE)
- Expert mode with advanced features
