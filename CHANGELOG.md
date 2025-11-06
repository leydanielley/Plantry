# Changelog

All notable changes to Plantry will be documented in this file.

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
