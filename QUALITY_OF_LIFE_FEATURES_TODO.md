# 🎯 PLANTRY - QUALITY OF LIFE FEATURES ROADMAP

**Erstellt:** 6. November 2025
**Version:** 0.8.0+3
**Status:** In Entwicklung

---

## ✅ IMPLEMENTIERT

### Feature 1: Intelligente Benachrichtigungen 🔔
**Status:** ✅ Implementiert
**Aufwand:** ~4-6 Stunden
**Version:** 0.9.0

**Was wurde implementiert:**
- Lokale Push-Benachrichtigungen (100% offline)
- Gieß-Erinnerungen basierend auf letztem Log
- Dünger-Erinnerungen mit konfigurierbaren Intervallen
- Phase-basierte Notifications (Seedling, Veg, Blüte, Ernte)
- Pro-Pflanze & globale Einstellungen
- Snooze-Funktion
- Benachrichtigungs-History

**Dependencies:**
```yaml
flutter_local_notifications: ^17.2.3
timezone: ^0.9.4
```

**Dateien:**
- `lib/services/notification_service.dart`
- `lib/models/notification_settings.dart`
- `lib/repositories/notification_repository.dart`

---

### Feature 2: Health Score & Warnungen 💚
**Status:** ✅ Implementiert
**Aufwand:** ~3-4 Stunden
**Version:** 0.9.0

**Was wurde implementiert:**
- Pflanzen-Gesundheits-Score (0-100)
- Echtzeit-Warnungen bei Anomalien
- pH/EC Trend-Analyse
- Wasserverbrauch-Monitoring
- Inaktivitäts-Warnungen
- Visuelle Health-Indikatoren

**Algorithmus-Faktoren:**
- Bewässerung-Regelmäßigkeit (30%)
- pH-Stabilität (25%)
- EC-Trends (20%)
- Foto-Dokumentation (15%)
- Log-Aktivität (10%)

**Dateien:**
- `lib/services/health_score_service.dart`
- `lib/services/warning_service.dart`
- `lib/widgets/health_score_widget.dart`

---

## 📋 GEPLANT - PRIORITÄT HOCH

### Feature 3: Foto-Timeline & Vergleich 📸
**Status:** ⬜ Geplant
**Geschätzter Aufwand:** ~3-4 Stunden
**Priorität:** Hoch
**Voraussetzungen:** Keine

**Features:**
- Vor-Nachher Slider (Swipe zwischen Fotos)
- Foto-Timeline mit Wachstums-Markern
- Zoom-Funktion für Trichome/Details
- Größen-Messung im Foto (mit Referenz-Objekt)
- Auto-Tagging: "Blattschaden", "Blüte", "Keimling", etc.
- Timelapse-Generator (alle Fotos → Video)
  - Speed anpassbar
  - Export als MP4 (lokal)
- Galerie-Modi:
  - Kalender-Ansicht
  - Nur Blüten-Fotos
  - Side-by-Side Vergleich

**Technische Details:**
```dart
Dependencies:
  video_player: ^2.8.0      # Timelapse abspielen
  image: ^4.1.0             # Foto-Manipulation

Neue Dateien:
  lib/widgets/photo/photo_timeline_widget.dart
  lib/widgets/photo/photo_comparison_widget.dart
  lib/widgets/photo/timelapse_generator.dart
  lib/screens/photo_timeline_screen.dart
```

**UI-Mockup:**
```
┌─────────────────────────────┐
│  📸 Foto-Timeline           │
├─────────────────────────────┤
│ [Slider: Tag 1 ←→ Tag 90]   │
│                             │
│  ┌─────────────────────┐   │
│  │    [Foto]           │   │
│  │  Tag 45 - Blüte     │   │
│  │  Höhe: 85cm         │   │
│  └─────────────────────┘   │
│                             │
│ [◀ Vorher] [Nachher ▶]     │
│ [🎬 Timelapse erstellen]   │
└─────────────────────────────┘
```

---

### Feature 4: Grow-Kalender 📅
**Status:** ⬜ Geplant
**Geschätzter Aufwand:** ~4-5 Stunden
**Priorität:** Hoch
**Voraussetzungen:** Keine

**Features:**
- Visueller Monats-/Wochen-Kalender
- Alle geplanten Tasks anzeigen
- Gieß-/Dünger-Termine
- Phasen-Übergänge markiert
- Multi-Grow Übersicht
- Drag & Drop für Task-Verschiebung
- Export als ICS (iCal-Format)

**Kalender-Events:**
```dart
💧 Bewässerung fällig
🌿 Düngen empfohlen
📸 Wöchentliches Foto
✂️ Defoliation-Zeit
🌱 Keimung Tag X
🌾 Ernte-Countdown
🔄 RDWC Reservoir-Wechsel
```

**UI-Mockup:**
```
   November 2025
┌──────────────────────┐
│ Mo Di Mi Do Fr Sa So │
│          1  2  3     │
│ 💧      💧 📸        │
│                      │
│  4  5  6  7  8  9 10 │
│ 💧 🌿    💧         │
└──────────────────────┘

Heute's Tasks:
  💧 Cannabis #1 gießen
  📸 Wöchentliches Foto

Diese Woche:
  🌿 Düngen (in 2 Tagen)
  ✂️ Defoliation (in 4 Tagen)
```

**Technische Details:**
```dart
Dependencies:
  table_calendar: ^3.0.9

Neue Dateien:
  lib/models/calendar_event.dart
  lib/services/calendar_service.dart
  lib/screens/grow_calendar_screen.dart
  lib/widgets/calendar_widget.dart
```

---

### Feature 5: Routine-Checklisten ✅
**Status:** ⬜ Geplant
**Geschätzter Aufwand:** ~2-3 Stunden
**Priorität:** Hoch
**Voraussetzungen:** Feature 1 (Benachrichtigungen)

**Features:**
- Vordefinierte Routinen
- Benutzerdefinierte Checklisten
- Tägliche/Wöchentliche/Monatliche Wiederholungen
- Erinnerungen für Checklisten
- Fortschritts-Tracking
- Streak-System

**Routine-Typen:**
```dart
✅ Tägliche Routine (Morgens):
  □ Temperatur/Luftfeuchtigkeit checken
  □ Pflanzen auf Schädlinge prüfen
  □ Wasserstand RDWC checken
  □ Lichtzyklus kontrollieren

✅ Wöchentliche Routine:
  □ Fotos machen (alle Pflanzen)
  □ Defoliation prüfen
  □ RDWC Reservoir wechseln
  □ Luftfilter reinigen

✅ Phasen-Checkliste (Blüte-Start):
  □ 12/12 Lichtzyklus aktiviert?
  □ Blüte-Dünger gewechselt?
  □ Letztes Topping gemacht?
  □ Platz für Stretch berechnet?
```

**UI-Mockup:**
```
┌───────────────────────────┐
│ Tägliche Routine 🌅       │
│ Letzte Ausführung: Heute  │
│ Streak: 🔥 47 Tage        │
├───────────────────────────┤
│ ☑ Temperatur: 24°C ✓      │
│ ☑ Luftfeuchtigkeit: 65% ✓ │
│ □ Schädlinge-Check        │
│ □ RDWC Füllstand          │
├───────────────────────────┤
│ Fortschritt: ██████░░ 75% │
│ [Routine abschließen]     │
└───────────────────────────┘
```

**Technische Details:**
```dart
Neue Dateien:
  lib/models/routine.dart
  lib/models/checklist_item.dart
  lib/repositories/routine_repository.dart
  lib/screens/routines_screen.dart
  lib/widgets/routine_checklist_widget.dart

Database Migration:
  CREATE TABLE routines (...)
  CREATE TABLE checklist_items (...)
  CREATE TABLE routine_completions (...)
```

---

## 📋 GEPLANT - PRIORITÄT MITTEL

### Feature 6: Kosten-Tracking & ROI 💰
**Status:** ⬜ Geplant
**Geschätzter Aufwand:** ~3-4 Stunden
**Priorität:** Mittel

**Features:**
- Kosten pro Grow tracken
  - Strom (kWh × Preis)
  - Wasser
  - Nährstoffe/Dünger
  - Seeds/Klone
  - Equipment (anteilig)
- Stromverbrauch-Kalkulator
- Kosten pro Gramm
- ROI-Analyse
- Vergleiche zwischen Grows
- Budget-Warnungen

**Kostenarten:**
```dart
⚡ Strom:
  - LED 240W × 18h/Tag
  - Lüfter 50W × 24h
  - Abluft 100W × 24h
  → Täglich: 7.92 kWh
  → Monatlich: ~71€

💧 Wasser: geschätzt oder manuell

🌿 Nährstoffe:
  - Aus Hardware-Liste oder manuell
  - Automatisch aus verwendeten Dünger-Logs

🌱 Sonstiges:
  - Seeds/Klone
  - Erde/Medium
  - Equipment (Abschreibung)
```

**ROI-Berechnung:**
```
Grow #3:
  Kosten: 130€
  Ertrag: 180g
  → 0.72€/g

Vergleich zu Grow #2:
  ✅ 15% günstiger
  ✅ 22% mehr Ertrag
  🏆 Beste Kosten-Effizienz!
```

**Technische Details:**
```dart
Neue Dateien:
  lib/models/grow_costs.dart
  lib/models/electricity_device.dart
  lib/services/cost_tracking_service.dart
  lib/screens/cost_analysis_screen.dart
  lib/widgets/cost_breakdown_widget.dart

Database Migration:
  CREATE TABLE grow_costs (...)
  CREATE TABLE electricity_devices (...)
```

---

### Feature 7: Trend-Analysen & Insights 📊
**Status:** ⬜ Geplant
**Geschätzter Aufwand:** ~4-5 Stunden
**Priorität:** Mittel
**Voraussetzungen:** Feature 2 (Health Score)

**Features:**
- Automatische Trend-Erkennung
- Vorhersagen basierend auf Verlauf
- Vergleiche zwischen Grows
- Best-Practice Empfehlungen
- ML-basierte Optimierungs-Vorschläge

**Analysen:**
```dart
📈 Trend-Vorhersagen:
  "Bei diesem Tempo: Ernte in ~14 Tagen"
  "Durchschnittlicher Ertrag wird ~120g sein"
  "Blüte dauert länger als vorherige Grows"

🔍 Anomalie-Erkennung:
  ⚠️ "pH-Wert schwankt stark! (6.5 → 5.2 → 6.8)"
  ⚠️ "Wasserverbrauch plötzlich -50%"
  ⚠️ "EC steigt konstant → Salzaufbau?"

🎯 Vergleiche:
  📊 "Diese Pflanze vs. letzte (gleiche Sorte)"
  📊 "Grow #3 war 20% effizienter"
  📊 "Beste Ernte war mit diesem Dünger-Mix"

💡 Empfehlungen:
  "Basierend auf erfolgreichen Grows:
   → pH optimal bei 5.8-6.0
   → Gießen alle 2.3 Tage
   → Dünger-Reduktion in Woche 7"
```

**Technische Details:**
```dart
Neue Dateien:
  lib/services/analytics_service.dart
  lib/services/prediction_service.dart
  lib/models/trend_analysis.dart
  lib/models/insight.dart
  lib/screens/insights_screen.dart
  lib/widgets/trend_chart_widget.dart
```

---

### Feature 8: Templates & Quick-Actions 🎯
**Status:** ⬜ Geplant
**Geschätzter Aufwand:** ~2-3 Stunden
**Priorität:** Mittel

**Features:**
- Log-Vorlagen speichern
- Ein-Klick-Aktionen
- Workflow-Automation
- Favoriten-System
- Bulk-Operationen

**Vorlagen:**
```dart
📋 Log-Vorlagen:
  "Standard Bewässerung"
  → Wasser: 2L
  → pH: 6.0
  → EC: 1.4
  → [Speichern]

  "Blüte-Dünger Mix"
  → Bloom A: 4ml/L
  → Bloom B: 4ml/L
  → PK Boost: 1ml/L
  → [Als Standard speichern]

🎯 Quick Actions:
  "Morgendliche Routine"
  → Temperatur loggen
  → Foto aufnehmen
  → Gieß-Status checken
  → ✅ Fertig!

  "Wöchentlicher Check"
  → RDWC Werte messen
  → Alle Pflanzen fotografieren
  → Reservoir-Wechsel loggen
  → ✅ Fertig!
```

**Technische Details:**
```dart
Neue Dateien:
  lib/models/log_template.dart
  lib/models/quick_action.dart
  lib/repositories/template_repository.dart
  lib/services/quick_action_service.dart
  lib/screens/templates_screen.dart
```

---

## 📋 GEPLANT - PRIORITÄT NIEDRIG

### Feature 9: Widget-Dashboard 📱
**Status:** ⬜ Geplant
**Geschätzter Aufwand:** ~5-6 Stunden
**Priorität:** Niedrig

**Features:**
- Anpassbares Dashboard
- Widgets frei positionierbar
- Größe anpassbar
- Verschiedene Widget-Typen
- Presets (Anfänger/Experte)

**Widget-Typen:**
```dart
📊 Verfügbare Widgets:
  - Nächstes Gießen
  - Gesamt-Ertrag
  - Letzte Fotos
  - Temperatur/Luftfeuchtigkeit
  - Phase-Countdown
  - Health Score
  - Kommende Tasks
  - Streak-Counter
  - Quick-Actions
```

---

### Feature 10: Bulk-Operationen 🔄
**Status:** ⬜ Geplant
**Geschätzter Aufwand:** ~2-3 Stunden
**Priorität:** Niedrig

**Features:**
- Multi-Select für Pflanzen
- Batch-Logs erstellen
- Alle gleichzeitig gießen/düngen
- Batch-Foto-Upload
- Export mehrerer Grows

**UI:**
```dart
✅ Multi-Select:
  ☑ Cannabis #1
  ☑ Cannabis #2
  ☑ Cannabis #3

  [Alle gießen]
  [Alle fotografieren]
  [Gleicher Log für alle]
```

---

## 🚀 BONUS-FEATURES (Zukunft)

### Gamification 🎮
- Achievements & Badges
- Level-System
- Streak-Tracking
- Leaderboards (lokal)

### Erweiterte RDWC Features ⚙️
- System-Optimierungs-Assistent
- Auto-Berechnungen
- Wechsel-Planer
- System-Health Monitoring

### Hardware-Integration 🛠️
- Sensor-Widget (schnell loggen)
- Equipment-Wartungsplaner
- Betriebsstunden-Tracking
- Filter-Wechsel-Erinnerungen

### UX Improvements 👆
- Swipe-Gesten
- Sprach-Input (offline!)
- Dark/Light Themes pro Phase
- 3D Touch Quick Actions

---

## 📝 NOTIZEN

### Entwicklungs-Prinzipien:
- ✅ **100% Offline** - Keine Internet-Abhängigkeit
- ✅ **Privacy First** - Alle Daten bleiben lokal
- ✅ **Performance** - Schnell & ressourcenschonend
- ✅ **Einfach** - Intuitive Bedienung
- ✅ **Modular** - Features einzeln an/abschaltbar

### Test-Strategie:
- Unit Tests für Services
- Widget Tests für UI-Komponenten
- Integration Tests für Workflows
- Performance Tests für große Datenmengen

---

**Letzte Aktualisierung:** 6. November 2025
**Nächstes Review:** Nach Feature 2 Implementierung
