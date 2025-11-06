# RDWC EXPERT MODE - IMPLEMENTATION STATUS

**Letzte Aktualisierung:** 2025-11-06
**Version:** v8 (Database Migration)
**Status:** 70% Complete - READY FOR TESTING

---

## ✅ FERTIG (70%)

### Phase 1: Datenbank (100% ✅)
- ✅ Database Version 7 → 8
- ✅ Migration v8 erstellt (`lib/database/migrations/scripts/migration_v8.dart`)
- ✅ Tabelle `rdwc_log_fertilizers` (Nährstoffe pro Log)
- ✅ Tabelle `fertilizers` erweitert (ec_value, ppm_value)
- ✅ Tabelle `rdwc_recipes` (Rezept-System)
- ✅ Tabelle `rdwc_recipe_fertilizers` (Rezept → Dünger Mapping)

### Phase 2: Models (100% ✅)
- ✅ `RdwcLogFertilizer` Model (`lib/models/rdwc_log_fertilizer.dart`)
  - Per-Liter / Total Amount Logic
  - Conversion Methods
- ✅ `RdwcRecipe` Model (`lib/models/rdwc_recipe.dart`)
  - Recipe → Log Conversion
  - Total Amount Calculation
- ✅ `Fertilizer` Model erweitert (ec_value, ppm_value)
- ✅ `RdwcLog` Model erweitert (fertilizers list)

### Phase 3: Repository (100% ✅)
- ✅ **Fertilizer CRUD:**
  - `addFertilizerToLog()`
  - `removeFertilizerFromLog()`
  - `getLogFertilizers()`
  - `getLogWithFertilizers()`
  - `getRecentLogsWithFertilizers()`

- ✅ **Recipe CRUD:**
  - `getAllRecipes()`
  - `getRecipeById()`
  - `createRecipe()`
  - `updateRecipe()`
  - `deleteRecipe()`

- ✅ **Consumption Tracking:**
  - `getDailyConsumption()` - Täglicher Verbrauch
  - `getConsumptionStats()` - Statistiken (avg, max, min, total)

- ✅ **Drift Analysis:**
  - `getEcDriftAnalysis()` - EC Drift über Zeit
  - `getPhDriftAnalysis()` - pH Drift über Zeit

---

## ⏳ IN ARBEIT (30%)

### Phase 4: UI (Expert Mode)
**Status:** Noch nicht begonnen - NÄCHSTER SCHRITT

**Dateien zu ändern/erstellen:**

1. **`lib/screens/rdwc_addback_form_screen.dart`** (erweitern)
   - Fertilizer-Sektion hinzufügen (nur wenn Expert-Mode)
   - Dünger-Dropdown
   - Menge + Per-Liter/Total Radio Buttons
   - "Dünger hinzufügen" Button
   - Liste der hinzugefügten Dünger
   - Berechnete EC anzeigen (optional)

2. **Übersetzungen** (`lib/utils/translations.dart`)
   - Deutsch + Englisch für neue Features
   - `nutrients`, `add_fertilizer`, `per_liter`, `total_amount`, etc.

---

## 🔧 WIE DU ES TESTEN KANNST

### 1. App kompilieren
```bash
flutter pub get
flutter run
```

### 2. Migration testen
- App wird automatisch von v7 auf v8 migrieren
- Backup wird automatisch erstellt vor Migration
- Check in Settings ob Version 0.7.0 noch stimmt

### 3. Fertilizer EC-Werte hinzufügen (optional)
- Gehe zu Settings → (neues Feature: Fertilizers verwalten)
- Öffne einen Dünger
- Füge EC-Wert hinzu (z.B. 0.5 für "0.5 mS/cm pro ml")

### 4. RDWC Log mit Düngern erstellen (wenn UI fertig)
- Expert-Mode aktivieren in Settings
- RDWC System öffnen
- "Add Addback" klicken
- Dünger-Sektion sollte erscheinen
- Dünger hinzufügen
- Speichern

---

## 📝 NÄCHSTE SCHRITTE FÜR VOLLSTÄNDIGE IMPLEMENTIERUNG

### Minimal Viable Product (MVP) - PRIORITÄT 1
1. ⏳ Fertilizer-Sektion zum Addback-Screen (nur Expert-Mode)
2. ⏳ Übersetzungen hinzufügen
3. ⏳ Testing mit echten Daten

### Erweiterte Features - PRIORITÄT 2
4. ⬜ Consumption Tracking UI anzeigen (Dashboard Widget)
5. ⬜ Drift Analysis UI anzeigen (Dashboard Widget)
6. ⬜ Recipe Management Screen (Rezepte erstellen/bearbeiten)
7. ⬜ Recipe Picker im Full Change Screen

### Polishing - PRIORITÄT 3
8. ⬜ Separate Masken (Addback, Full Change, Measurement, Maintenance)
9. ⬜ Berechnete EC vs. gemessene EC Vergleich
10. ⬜ Fertilizer Form erweitern (EC/PPM Eingabe)
11. ⬜ Icons & Styling verbessern

---

## 🐛 BEKANNTE EINSCHRÄNKUNGEN

1. **EC-Berechnung ist eine Schätzung**
   - Nicht-lineare Effekte werden nicht berücksichtigt
   - Nutzer sollte immer die tatsächliche EC messen

2. **Fertilizer EC-Werte sind optional**
   - Wenn nicht angegeben: Keine Auto-Berechnung
   - Nutzer kann manuell hinzufügen

3. **Migration ist one-way**
   - Downgrade von v8 → v7 nicht unterstützt
   - Backup wird automatisch erstellt

---

## 📊 DATEI-ÜBERSICHT

### Neue Dateien (v8):
```
lib/models/
  rdwc_log_fertilizer.dart          ✅ 112 lines
  rdwc_recipe.dart                  ✅ 152 lines

lib/database/migrations/scripts/
  migration_v8.dart                 ✅ 113 lines

Dokumentation:
  RDWC_EXPERT_LOGGING_TODO.md      ✅ 1056 lines (vollständiger Plan)
  RDWC_IMPLEMENTATION_STATUS.md    📄 This file
  EXPORT_FEATURES_TODO.md           📄 (separate TODO, LOW PRIORITY)
```

### Geänderte Dateien (v8):
```
lib/database/
  database_helper.dart              ✅ Modified (v8, +tables in _createDB)

lib/database/migrations/scripts/
  all_migrations.dart               ✅ Modified (import migration_v8)

lib/models/
  fertilizer.dart                   ✅ Modified (+ecValue, +ppmValue)
  rdwc_log.dart                     ✅ Modified (+fertilizers list)

lib/repositories/
  rdwc_repository.dart              ✅ Modified (+440 lines for v8 features)
```

---

## 🚀 NEXT SESSION COMMANDS

### Wenn UI fertig werden soll:
```
"Implementiere die Fertilizer-Sektion im Addback Screen aus RDWC_IMPLEMENTATION_STATUS.md"
```

### Wenn nur testen:
```
"Ich möchte die v8 Migration testen"
```

### Wenn weiter an Features arbeiten:
```
"Implementiere Consumption Tracking UI aus RDWC_IMPLEMENTATION_STATUS.md"
```

---

**Status:** READY FOR MVP IMPLEMENTATION
**Geschätzter Aufwand für MVP:** 1-2 Stunden
**Geschätzter Aufwand für Full Features:** 4-6 Stunden
