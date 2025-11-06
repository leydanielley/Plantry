# PLANTRY - RDWC EXPERT MODE LOGGING - TODO

**Status:** Geplant, nicht begonnen
**Erstellt:** 2025-11-06
**Geschätzte Zeit:** 3-4 Stunden
**Risiko:** Mittel (Datenbank-Schema ändern, Migration erforderlich)

---

## 🎯 ZIEL

Im Expert-Modus sollen RDWC-Logs detaillierte Nährstoff-Information tracken:

### Nährstoff-Logging:
- ✅ pH vorher/nachher (existiert bereits)
- ✅ EC/PPM vorher/nachher (existiert bereits)
- ⬜ **Welche Dünger wurden hinzugefügt?** (NEU)
- ⬜ **Wie viel von jedem Dünger?** (NEU)
- ⬜ **Eingabe pro Liter ODER Gesamtmenge** (NEU)
- ⬜ **Auto-Berechnung der finalen EC/PPM** (NEU)

### Verbrauchs-Tracking:
- ⬜ **Wasserverbrauch pro Tag tracken** (NEU)
- ⬜ **EC-Drift über Zeit anzeigen** (NEU)
- ⬜ **pH-Drift über Zeit anzeigen** (NEU)
- ⬜ **Durchschnittsverbrauch berechnen** (NEU)

### Bessere UI-Masken:
- ⬜ **Addback-Maske logischer gestalten** (NEU)
- ⬜ **FullChange-Maske mit Rezept-Funktion** (NEU)
- ⬜ **Measurement-Maske vereinfachen** (NEU)
- ⬜ **Kontext-spezifische Felder** (NEU)

---

## 📊 AKTUELLE SITUATION

### RdwcLog Model (lib/models/rdwc_log.dart)

**Vorhanden:**
```dart
final double? ecBefore;    // EC vor Addback
final double? ecAfter;     // EC nach Addback
final double? phBefore;    // pH vor Addback
final double? phAfter;     // pH nach Addback
```

**Problem:** Keine Information über:
- Welche Dünger wurden verwendet?
- Wie viel von jedem Dünger?
- Berechnung basierend auf Volumen

---

## 🗄️ DATENBANK-ÄNDERUNGEN

### Neue Tabelle: rdwc_log_fertilizers

Ähnlich wie `log_fertilizers` für plant_logs, aber für RDWC:

```sql
CREATE TABLE rdwc_log_fertilizers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  rdwc_log_id INTEGER NOT NULL,
  fertilizer_id INTEGER NOT NULL,
  amount REAL NOT NULL,              -- Menge des Düngers
  amount_type TEXT NOT NULL,         -- 'PER_LITER' oder 'TOTAL'
  -- Wenn PER_LITER: amount * levelAfter = Gesamtmenge
  -- Wenn TOTAL: amount ist direkt die Gesamtmenge
  created_at TEXT NOT NULL,
  FOREIGN KEY (rdwc_log_id) REFERENCES rdwc_logs(id) ON DELETE CASCADE,
  FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
);
```

### Migration (lib/database/database_helper.dart)

```dart
// Version erhöhen von 7 auf 8
static const int _databaseVersion = 8;

// In _onCreate: Tabelle erstellen
// In _onUpgrade: Migration für Version 7 → 8
```

**Status:** ⬜ Nicht begonnen

---

## 📝 NEUE MODELS

### 1. RdwcLogFertilizer Model

**Datei:** `lib/models/rdwc_log_fertilizer.dart`

```dart
enum FertilizerAmountType {
  perLiter,   // Menge pro Liter (z.B. 2ml/L)
  total,      // Gesamtmenge (z.B. 100ml für 50L)
}

class RdwcLogFertilizer {
  final int? id;
  final int rdwcLogId;
  final int fertilizerId;
  final double amount;                    // Menge
  final FertilizerAmountType amountType;  // Pro Liter oder Total
  final DateTime createdAt;

  // Wenn perLiter: Gesamtmenge = amount * systemVolume
  double getTotalAmount(double systemVolume) {
    if (amountType == FertilizerAmountType.perLiter) {
      return amount * systemVolume;
    }
    return amount;
  }

  // Wenn total: Pro Liter = amount / systemVolume
  double getPerLiterAmount(double systemVolume) {
    if (amountType == FertilizerAmountType.total) {
      return amount / systemVolume;
    }
    return amount;
  }
}
```

**Status:** ⬜ Nicht begonnen

---

### 2. RdwcLog Model erweitern

**Datei:** `lib/models/rdwc_log.dart`

```dart
class RdwcLog {
  // ... existing fields ...

  // NEU: Dünger-Liste (wird separat geladen)
  List<RdwcLogFertilizer>? fertilizers;

  // NEU: Berechnung der erwarteten EC/PPM basierend auf Düngern
  double? get calculatedEc {
    if (fertilizers == null || fertilizers!.isEmpty) return null;
    // Basierend auf Dünger-EC-Werten berechnen
    // Benötigt: EC-Wert pro Dünger in fertilizers Tabelle
  }
}
```

**Status:** ⬜ Nicht begonnen

---

### 3. Fertilizer Model erweitern

**Datei:** `lib/models/fertilizer.dart`

**Problem:** Fertilizer-Model hat aktuell KEIN EC/PPM-Wert!

**Lösung:** Fertilizer Tabelle erweitern:

```sql
-- Migration: Spalten zur fertilizers Tabelle hinzufügen
ALTER TABLE fertilizers ADD COLUMN ec_value REAL;  -- EC-Wert pro ml/g
ALTER TABLE fertilizers ADD COLUMN ppm_value REAL; -- PPM-Wert pro ml/g
```

```dart
class Fertilizer {
  // ... existing fields ...
  final double? ecValue;   // EC pro ml/g (optional)
  final double? ppmValue;  // PPM pro ml/g (optional)
}
```

**Status:** ⬜ Nicht begonnen

---

## 🔧 REPOSITORY-ÄNDERUNGEN

### RdwcRepository erweitern

**Datei:** `lib/repositories/rdwc_repository.dart`

**Neue Methoden:**

```dart
// Dünger zu RDWC-Log hinzufügen
Future<void> addFertilizerToLog(RdwcLogFertilizer fertilizer);

// Dünger von RDWC-Log entfernen
Future<void> removeFertilizerFromLog(int id);

// Alle Dünger eines Logs laden
Future<List<RdwcLogFertilizer>> getLogFertilizers(int rdwcLogId);

// Log MIT Düngern laden
Future<RdwcLog> getLogWithFertilizers(int logId);
```

**Status:** ⬜ Nicht begonnen

---

## 🎨 UI-ÄNDERUNGEN

### 1. RDWC Addback Form Screen erweitern

**Datei:** `lib/screens/rdwc_addback_form_screen.dart`

**Nur im Expert-Modus anzeigen:**

```dart
// Nach pH/EC Sektion:
if (_settings.isExpertMode) {
  // Neue Sektion: Nährstoffe
  _buildFertilizerSection(),
}
```

#### Nährstoff-Sektion UI:

```
┌─────────────────────────────────────┐
│ 🧪 NÄHRSTOFFE (Expert Mode)         │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Dünger 1: [Dropdown ▼]         │ │
│ │ Menge: [____] ml                │ │
│ │ ○ Pro Liter  ● Gesamtmenge     │ │
│ │ = 50L × 2ml/L = 100ml total    │ │
│ │            [X Entfernen]        │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Dünger 2: [Dropdown ▼]         │ │
│ │ Menge: [____] ml                │ │
│ │ ● Pro Liter  ○ Gesamtmenge     │ │
│ │ = 50L × 1.5ml/L = 75ml total   │ │
│ │            [X Entfernen]        │ │
│ └─────────────────────────────────┘ │
│                                     │
│ [+ Dünger hinzufügen]               │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Berechnete EC: 1.8 mS/cm       │ │
│ │ (basierend auf Düngern)        │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Features:**
- Mehrere Dünger hinzufügen
- Dropdown zur Auswahl aus `fertilizers` Tabelle
- Radio-Buttons: "Pro Liter" / "Gesamtmenge"
- Live-Berechnung der Gesamtmenge
- Automatische EC-Berechnung (wenn Dünger EC-Werte haben)
- Entfernen-Button pro Dünger

**Status:** ⬜ Nicht begonnen

---

### 2. RDWC System Detail Screen erweitern

**Datei:** `lib/screens/rdwc_system_detail_screen.dart`

**Log-Anzeige erweitern:**

Wenn Expert-Mode aktiv und Dünger vorhanden:

```
┌───────────────────────────────────┐
│ 15. Nov 14:30                     │
│ 💧 Addback: +10.0 L               │
│ pH: 6.2 → 6.0                     │
│ EC: 1.4 → 1.8 mS/cm               │
│                                   │
│ 🧪 Nährstoffe:                    │
│   • Flora Micro: 2ml/L (100ml)    │
│   • Flora Grow: 1.5ml/L (75ml)    │
│   • Flora Bloom: 2ml/L (100ml)    │
│                                   │
│ 📝 Week 3 of bloom               │
└───────────────────────────────────┘
```

**Status:** ⬜ Nicht begonnen

---

## 🧮 BERECHNUNGS-LOGIK

### EC/PPM Auto-Berechnung

**Voraussetzung:** Dünger müssen EC/PPM-Werte haben

**Formel:**

```dart
double calculateTotalEc(List<RdwcLogFertilizer> fertilizers, double systemVolume) {
  double totalEc = 0.0;

  for (var fert in fertilizers) {
    // Gesamtmenge des Düngers
    double totalAmount = fert.getTotalAmount(systemVolume);

    // EC-Beitrag dieses Düngers
    double fertEc = fertilizer.ecValue * totalAmount;

    // Auf Systemvolumen verteilt
    totalEc += fertEc / systemVolume;
  }

  return totalEc;
}
```

**Hinweis:** Dies ist eine Vereinfachung. Tatsächliche EC-Berechnung ist komplexer (nicht-linear).

**Status:** ⬜ Nicht begonnen

---

## 📋 IMPLEMENTIERUNGS-SCHRITTE

### Phase 1: Datenbank (60 Min)

- ⬜ 1. Database Version von 7 auf 8 erhöhen
- ⬜ 2. `rdwc_log_fertilizers` Tabelle erstellen
- ⬜ 3. `fertilizers` Tabelle erweitern (ec_value, ppm_value)
- ⬜ 4. Migration für Version 7 → 8 implementieren
- ⬜ 5. Testen: App aktualisieren, Daten bleiben erhalten

### Phase 2: Models (45 Min)

- ⬜ 6. `RdwcLogFertilizer` Model erstellen
- ⬜ 7. `FertilizerAmountType` Enum erstellen
- ⬜ 8. `RdwcLog` Model erweitern (fertilizers List)
- ⬜ 9. `Fertilizer` Model erweitern (ecValue, ppmValue)
- ⬜ 10. Berechnungs-Methoden implementieren

### Phase 3: Repository (45 Min)

- ⬜ 11. RdwcRepository erweitern
- ⬜ 12. `addFertilizerToLog()` implementieren
- ⬜ 13. `removeFertilizerFromLog()` implementieren
- ⬜ 14. `getLogFertilizers()` implementieren
- ⬜ 15. `getLogWithFertilizers()` implementieren

### Phase 4: UI - Addback Form (90 Min)

- ⬜ 16. Nährstoff-Sektion UI erstellen (nur Expert-Mode)
- ⬜ 17. Dünger-Dropdown implementieren
- ⬜ 18. Mengen-Eingabe + Radio-Buttons
- ⬜ 19. Live-Berechnung Gesamt/Pro-Liter
- ⬜ 20. "Dünger hinzufügen" Button
- ⬜ 21. "Entfernen" Button pro Dünger
- ⬜ 22. Auto-EC-Berechnung anzeigen
- ⬜ 23. Save-Logik erweitern (Dünger mit speichern)

### Phase 5: UI - Detail Screen (30 Min)

- ⬜ 24. Log-Anzeige erweitern
- ⬜ 25. Dünger-Liste in Log-Cards anzeigen
- ⬜ 26. Format: "Name: Xml/L (Yml total)"

### Phase 6: Dünger-Verwaltung erweitern (30 Min)

- ⬜ 27. Fertilizer-Form erweitern (EC/PPM-Werte)
- ⬜ 28. Optional: EC/PPM können leer bleiben
- ⬜ 29. Hinweis: "Für RDWC-Berechnungen erforderlich"

### Phase 7: Übersetzungen (15 Min)

- ⬜ 30. Deutsche Übersetzungen
- ⬜ 31. Englische Übersetzungen

### Phase 8: Testing (30 Min)

- ⬜ 32. Dünger mit EC-Werten anlegen
- ⬜ 33. RDWC-Log mit Düngern erstellen
- ⬜ 34. Pro Liter vs. Gesamtmenge testen
- ⬜ 35. Auto-Berechnung prüfen
- ⬜ 36. Detail-Anzeige testen
- ⬜ 37. Migration von Version 7 → 8 testen

---

## 🎨 DETAILLIERTES UI-DESIGN

### Dünger-Item Widget

```dart
Widget _buildFertilizerItem(
  int index,
  RdwcLogFertilizer fertilizer,
  double systemVolume,
) {
  return Card(
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        children: [
          // Dünger-Auswahl
          DropdownButtonFormField<int>(
            value: fertilizer.fertilizerId,
            decoration: InputDecoration(
              labelText: 'Dünger ${index + 1}',
              prefixIcon: Icon(Icons.science),
            ),
            items: _availableFertilizers.map((f) {
              return DropdownMenuItem(
                value: f.id,
                child: Text(f.name),
              );
            }).toList(),
            onChanged: (value) {
              // Update fertilizer
            },
          ),

          SizedBox(height: 12),

          // Mengen-Eingabe
          TextFormField(
            initialValue: fertilizer.amount.toString(),
            decoration: InputDecoration(
              labelText: 'Menge',
              suffixText: 'ml',
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              // Update amount
            },
          ),

          SizedBox(height: 12),

          // Radio: Pro Liter / Gesamtmenge
          Row(
            children: [
              Expanded(
                child: RadioListTile<FertilizerAmountType>(
                  title: Text('Pro Liter'),
                  value: FertilizerAmountType.perLiter,
                  groupValue: fertilizer.amountType,
                  onChanged: (value) {
                    // Update type
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<FertilizerAmountType>(
                  title: Text('Gesamtmenge'),
                  value: FertilizerAmountType.total,
                  groupValue: fertilizer.amountType,
                  onChanged: (value) {
                    // Update type
                  },
                ),
              ),
            ],
          ),

          // Berechnung anzeigen
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              fertilizer.amountType == FertilizerAmountType.perLiter
                ? '= ${systemVolume}L × ${fertilizer.amount}ml/L = ${fertilizer.getTotalAmount(systemVolume)}ml total'
                : '= ${fertilizer.amount}ml ÷ ${systemVolume}L = ${fertilizer.getPerLiterAmount(systemVolume).toStringAsFixed(2)}ml/L',
              style: TextStyle(fontSize: 12),
            ),
          ),

          SizedBox(height: 8),

          // Entfernen-Button
          TextButton.icon(
            onPressed: () {
              // Remove fertilizer
            },
            icon: Icon(Icons.delete, color: Colors.red),
            label: Text('Entfernen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ),
  );
}
```

---

## 🗃️ DATENBANK-MIGRATION

### Migration Code (database_helper.dart)

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  AppLogger.info('DatabaseHelper', 'Upgrading from v$oldVersion to v$newVersion');

  // Migration 7 → 8: RDWC Fertilizer Logging
  if (oldVersion < 8) {
    AppLogger.info('DatabaseHelper', 'Running migration 7 → 8');

    // 1. Create rdwc_log_fertilizers table
    await db.execute('''
      CREATE TABLE rdwc_log_fertilizers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rdwc_log_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        amount_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (rdwc_log_id) REFERENCES rdwc_logs(id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
      )
    ''');

    // 2. Add EC/PPM columns to fertilizers
    await db.execute('ALTER TABLE fertilizers ADD COLUMN ec_value REAL');
    await db.execute('ALTER TABLE fertilizers ADD COLUMN ppm_value REAL');

    AppLogger.info('DatabaseHelper', 'Migration 7 → 8 complete');
  }
}
```

**Status:** ⬜ Nicht begonnen

---

## 📊 BEISPIEL-SZENARIEN

### Szenario 1: Pro Liter Eingabe

**Benutzer-Eingabe:**
- System: 50L aktuell
- Dünger: Flora Micro
- Menge: 2 ml
- Typ: **Pro Liter**

**Berechnung:**
- Total: 2ml/L × 50L = **100ml Gesamtmenge**

**Anzeige im Log:**
```
🧪 Flora Micro: 2ml/L (100ml total)
```

---

### Szenario 2: Gesamtmenge Eingabe

**Benutzer-Eingabe:**
- System: 50L aktuell
- Dünger: Flora Grow
- Menge: 75 ml
- Typ: **Gesamtmenge**

**Berechnung:**
- Pro Liter: 75ml ÷ 50L = **1.5ml/L**

**Anzeige im Log:**
```
🧪 Flora Grow: 1.5ml/L (75ml total)
```

---

### Szenario 3: Mehrere Dünger + EC-Berechnung

**Benutzer-Eingabe:**
- System: 50L aktuell
- Dünger 1: Flora Micro (EC: 0.5/ml) → 2ml/L
- Dünger 2: Flora Grow (EC: 0.4/ml) → 1.5ml/L
- Dünger 3: Flora Bloom (EC: 0.6/ml) → 2ml/L

**EC-Berechnung:**
```
Flora Micro: 2ml/L × 0.5 = 1.0 EC
Flora Grow:  1.5ml/L × 0.4 = 0.6 EC
Flora Bloom: 2ml/L × 0.6 = 1.2 EC
────────────────────────────────────
Total EC:                   2.8 mS/cm
```

**Anzeige:**
```
┌─────────────────────────────────┐
│ Berechnete EC: 2.8 mS/cm       │
│ (basierend auf Düngern)        │
└─────────────────────────────────┘
```

---

## ⚠️ WICHTIGE HINWEISE

### Rückwärtskompatibilität

- ✅ Alte RDWC-Logs ohne Dünger funktionieren weiterhin
- ✅ Migration fügt nur neue Spalten/Tabellen hinzu
- ✅ Keine Daten gehen verloren

### Expert-Modus

- ✅ Dünger-Logging nur im Expert-Modus sichtbar
- ✅ Normal-Modus: pH/EC vorher/nachher wie bisher
- ✅ Expert-Modus: + Detaillierte Dünger-Information

### EC-Berechnung

- ⚠️ EC-Berechnung ist eine **Schätzung**
- ⚠️ Reale EC hängt von vielen Faktoren ab
- ⚠️ Nutzer sollte immer die tatsächliche EC messen
- ✅ Berechnete EC als **Hinweis/Vergleich** anzeigen

### Dünger-EC-Werte

- ℹ️ Optional: Dünger können ohne EC-Werte angelegt werden
- ℹ️ Wenn keine EC-Werte: Keine Auto-Berechnung
- ℹ️ Nutzer kann EC-Werte später hinzufügen

---

## 📈 VERBRAUCHS-TRACKING & DRIFT-ANALYSE

### Wasserverbrauch pro Tag

**Berechnung:**
```dart
// In RdwcRepository
Future<Map<String, double>> getConsumptionStats(int systemId, {int days = 7}) async {
  final logs = await getLogsForSystem(systemId, limit: days);

  // Berechne täglichen Verbrauch
  Map<String, double> dailyConsumption = {};

  for (int i = 0; i < logs.length - 1; i++) {
    final current = logs[i];
    final previous = logs[i + 1];

    // Zeit zwischen Logs
    final timeDiff = current.logDate.difference(previous.logDate);
    final days = timeDiff.inHours / 24.0;

    // Wasserverbrauch
    final consumed = current.waterConsumed ?? 0;
    final perDay = consumed / days;

    final dateKey = current.logDate.toIso8601String().split('T')[0];
    dailyConsumption[dateKey] = perDay;
  }

  return dailyConsumption;
}

// Durchschnittsverbrauch
double getAverageConsumption(Map<String, double> daily) {
  if (daily.isEmpty) return 0.0;
  final total = daily.values.reduce((a, b) => a + b);
  return total / daily.length;
}
```

**UI-Anzeige im Detail Screen:**
```
┌─────────────────────────────────────┐
│ 📊 VERBRAUCH (7 Tage)              │
├─────────────────────────────────────┤
│ Durchschnitt: 12.5 L/Tag           │
│ Gesamt: 87.5 L                     │
│                                    │
│ Mo: ▓▓▓▓▓▓▓▓▓░ 10.2 L              │
│ Di: ▓▓▓▓▓▓▓▓▓▓▓ 13.5 L             │
│ Mi: ▓▓▓▓▓▓▓▓▓▓ 12.8 L              │
│ Do: ▓▓▓▓▓▓▓▓▓▓▓▓ 15.1 L            │
│ Fr: ▓▓▓▓▓▓▓▓░ 9.7 L                │
│ Sa: ▓▓▓▓▓▓▓▓▓▓▓▓▓ 16.3 L           │
│ So: ▓▓▓▓▓▓▓▓▓ 11.9 L               │
└─────────────────────────────────────┘
```

**Status:** ⬜ Nicht begonnen

---

### EC/pH Drift-Analyse

**Berechnung:**
```dart
// EC Drift über Zeit
class DriftAnalysis {
  final double averageDrift;      // Durchschnittliche Änderung pro Tag
  final double maxDrift;           // Maximale Änderung
  final double minDrift;           // Minimale Änderung
  final String trend;              // "increasing", "decreasing", "stable"

  DriftAnalysis({
    required this.averageDrift,
    required this.maxDrift,
    required this.minDrift,
    required this.trend,
  });
}

Future<DriftAnalysis> getEcDrift(int systemId, {int days = 7}) async {
  final logs = await getLogsForSystem(systemId, limit: days);

  List<double> drifts = [];

  for (var log in logs) {
    if (log.ecDrift != null) {
      drifts.add(log.ecDrift!);
    }
  }

  if (drifts.isEmpty) {
    return DriftAnalysis(
      averageDrift: 0.0,
      maxDrift: 0.0,
      minDrift: 0.0,
      trend: 'no_data',
    );
  }

  final avg = drifts.reduce((a, b) => a + b) / drifts.length;
  final max = drifts.reduce((a, b) => a > b ? a : b);
  final min = drifts.reduce((a, b) => a < b ? a : b);

  String trend;
  if (avg > 0.1) {
    trend = 'increasing';
  } else if (avg < -0.1) {
    trend = 'decreasing';
  } else {
    trend = 'stable';
  }

  return DriftAnalysis(
    averageDrift: avg,
    maxDrift: max,
    minDrift: min,
    trend: trend,
  );
}
```

**UI-Anzeige:**
```
┌─────────────────────────────────────┐
│ 📈 EC DRIFT (7 Tage)               │
├─────────────────────────────────────┤
│ Durchschnitt: +0.15 mS/cm/Tag      │
│ Trend: ↗ Steigend                  │
│                                    │
│ Max: +0.4 mS/cm                    │
│ Min: -0.1 mS/cm                    │
│                                    │
│ ⚠ EC steigt kontinuierlich!        │
│ → Pflanzen nehmen weniger          │
│    Nährstoffe auf als Wasser       │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 📉 pH DRIFT (7 Tage)               │
├─────────────────────────────────────┤
│ Durchschnitt: -0.2 pH/Tag          │
│ Trend: ↘ Fallend                   │
│                                    │
│ Max: +0.1 pH                       │
│ Min: -0.5 pH                       │
│                                    │
│ ℹ pH fällt leicht                  │
│ → Normal in Blütephase             │
└─────────────────────────────────────┘
```

**Status:** ⬜ Nicht begonnen

---

## 🎨 VERBESSERTE UI-MASKEN

### Problem mit aktuellen Masken:

**Aktuell (rdwc_addback_form_screen.dart):**
- ❌ Alle Log-Typen in einem Formular
- ❌ Viele unnötige Felder je nach Typ
- ❌ Verwirrend für Nutzer
- ❌ Keine Kontext-spezifische Hilfe

**Beispiel:**
- Bei "Measurement" braucht man KEIN "Water Added"
- Bei "Full Change" braucht man ANDERE Felder als bei "Addback"
- Bei "Maintenance" sind pH/EC optional

---

### Lösung: Separate Masken pro Log-Typ

#### 1. Addback-Maske (rdwc_addback_screen.dart)

**Fokus:** Wasser nachfüllen + Nährstoffe anpassen

```
┌─────────────────────────────────────┐
│ ← Water Addback                    │
├─────────────────────────────────────┤
│                                    │
│ 💧 WASSER                          │
│ Aktueller Stand: 42.3 L            │
│ Nachfüllen: [____] L               │
│ → Neuer Stand: 52.3 L              │
│                                    │
│ ⚗ MESSUNGEN (vorher)               │
│ pH:  [____]   EC: [____] mS/cm     │
│                                    │
│ 🧪 NÄHRSTOFFE (Expert-Modus)       │
│ [+ Dünger hinzufügen]              │
│                                    │
│ ⚗ MESSUNGEN (nachher)              │
│ pH:  [____]   EC: [____] mS/cm     │
│                                    │
│ 📝 NOTIZEN                         │
│ [________________]                 │
│                                    │
│ [  SPEICHERN  ]                    │
└─────────────────────────────────────┘
```

**Logik:**
- Wassermenge ist PFLICHT
- pH/EC vorher optional
- pH/EC nachher PFLICHT
- Berechnet automatisch: waterConsumed

**Status:** ⬜ Nicht begonnen

---

#### 2. Full Change-Maske (rdwc_fullchange_screen.dart)

**Fokus:** Kompletter Wasserwechsel mit Rezept

```
┌─────────────────────────────────────┐
│ ← Full Reservoir Change            │
├─────────────────────────────────────┤
│                                    │
│ 💧 WASSER                          │
│ Altes Volumen: 48.5 L              │
│ Neues Volumen: [____] L            │
│                                    │
│ ⚗ ALTE WERTE (vor Wechsel)         │
│ pH:  [____]   EC: [____] mS/cm     │
│                                    │
│ 🧪 REZEPT (Expert-Modus)           │
│ ┌───────────────────────────────┐  │
│ │ □ Rezept verwenden            │  │
│ │ Vorlage: [Bloom Week 3 ▼]    │  │
│ │                               │  │
│ │ Oder manuell:                 │  │
│ │ Flora Micro: 2ml/L            │  │
│ │ Flora Grow:  1ml/L            │  │
│ │ Flora Bloom: 2ml/L            │  │
│ └───────────────────────────────┘  │
│                                    │
│ ⚗ NEUE WERTE (nach Wechsel)        │
│ pH:  [____]   EC: [____] mS/cm     │
│ Berechnet: 1.8 mS/cm ✓             │
│                                    │
│ 📝 NOTIZEN                         │
│ [________________]                 │
│                                    │
│ [  SPEICHERN  ]                    │
└─────────────────────────────────────┘
```

**Features:**
- Rezept-System (gespeicherte Dünger-Kombinationen)
- Auto-fill aus Rezept
- Berechnung der erwarteten EC
- Vergleich: Berechnet vs. Gemessen

**Status:** ⬜ Nicht begonnen

---

#### 3. Measurement-Maske (rdwc_measurement_screen.dart)

**Fokus:** Schnelle Messung ohne Änderungen

```
┌─────────────────────────────────────┐
│ ← Quick Measurement                │
├─────────────────────────────────────┤
│                                    │
│ 💧 WASSERSTAND                     │
│ Aktuell: [____] L                  │
│                                    │
│ ⚗ MESSUNGEN                        │
│ pH:  [____]                        │
│ EC:  [____] mS/cm                  │
│ Temp: [____] °C (optional)         │
│                                    │
│ 📝 NOTIZEN                         │
│ [________________]                 │
│                                    │
│ [  SPEICHERN  ]                    │
└─────────────────────────────────────┘
```

**Logik:**
- Nur aktuelle Werte
- Kein "vorher/nachher"
- Schnellste Eingabe
- Für tägliche Checks

**Status:** ⬜ Nicht begonnen

---

#### 4. Maintenance-Maske (rdwc_maintenance_screen.dart)

**Fokus:** Wartung dokumentieren

```
┌─────────────────────────────────────┐
│ ← System Maintenance               │
├─────────────────────────────────────┤
│                                    │
│ 🔧 WARTUNGSARBEITEN                │
│ ☑ Pumpe gereinigt                  │
│ ☑ Filter gewechselt                │
│ ☑ Schläuche geprüft                │
│ ☑ Luftsteine gereinigt             │
│ □ Chiller gewartet                 │
│                                    │
│ 💧 WASSERSTAND (optional)          │
│ Vor Wartung:  [____] L             │
│ Nach Wartung: [____] L             │
│                                    │
│ ⚗ MESSUNGEN (optional)             │
│ pH:  [____]   EC: [____] mS/cm     │
│                                    │
│ 📝 DETAILS                         │
│ [________________________________] │
│ [________________________________] │
│                                    │
│ [  SPEICHERN  ]                    │
└─────────────────────────────────────┘
```

**Features:**
- Checkliste für häufige Wartungen
- Wasser/pH/EC optional
- Fokus auf Dokumentation

**Status:** ⬜ Nicht begonnen

---

### Navigation zu den Masken

**RDWC Detail Screen:**

```
┌─────────────────────────────────────┐
│ Main System - 50L                  │
├─────────────────────────────────────┤
│ 💧 48.5 L (97%)                    │
│ pH: 6.2  EC: 1.4 mS/cm             │
│                                    │
│ SCHNELL-AKTIONEN:                  │
│ ┌────────┐ ┌────────┐ ┌────────┐  │
│ │   💧   │ │   🔄   │ │   📊   │  │
│ │Addback │ │ Change │ │ Messen │  │
│ └────────┘ └────────┘ └────────┘  │
│                                    │
│ ┌────────┐                         │
│ │   🔧   │                         │
│ │Wartung │                         │
│ └────────┘                         │
└─────────────────────────────────────┘
```

**Status:** ⬜ Nicht begonnen

---

### Rezept-System (Expert-Modus)

**Neue Datei:** `lib/models/rdwc_recipe.dart`

```dart
class RdwcRecipe {
  final int? id;
  final String name;                       // "Bloom Week 3"
  final String? description;
  final List<RecipeFertilizer> fertilizers;
  final double? targetEc;                  // Ziel-EC
  final double? targetPh;                  // Ziel-pH
  final DateTime createdAt;

  // Rezept auf System-Volumen anwenden
  List<RdwcLogFertilizer> applyToVolume(double volumeLiters) {
    return fertilizers.map((f) {
      return RdwcLogFertilizer(
        fertilizerId: f.fertilizerId,
        amount: f.mlPerLiter,
        amountType: FertilizerAmountType.perLiter,
      );
    }).toList();
  }
}

class RecipeFertilizer {
  final int fertilizerId;
  final double mlPerLiter;
}
```

**Neue Tabelle: rdwc_recipes**
```sql
CREATE TABLE rdwc_recipes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  description TEXT,
  target_ec REAL,
  target_ph REAL,
  created_at TEXT NOT NULL
);

CREATE TABLE rdwc_recipe_fertilizers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  recipe_id INTEGER NOT NULL,
  fertilizer_id INTEGER NOT NULL,
  ml_per_liter REAL NOT NULL,
  FOREIGN KEY (recipe_id) REFERENCES rdwc_recipes(id) ON DELETE CASCADE,
  FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
);
```

**Status:** ⬜ Nicht begonnen

---

## 📝 ÜBERSETZUNGEN

### Deutsch

```dart
'nutrients': 'Nährstoffe',
'add_fertilizer': 'Dünger hinzufügen',
'remove_fertilizer': 'Dünger entfernen',
'fertilizer': 'Dünger',
'amount': 'Menge',
'per_liter': 'Pro Liter',
'total_amount': 'Gesamtmenge',
'calculated_ec': 'Berechnete EC',
'based_on_fertilizers': 'basierend auf Düngern',
'ec_value': 'EC-Wert',
'ppm_value': 'PPM-Wert',
'ec_per_ml': 'EC pro ml',
'ppm_per_ml': 'PPM pro ml',
'fertilizer_ec_info': 'Optional: Für automatische EC-Berechnung in RDWC',
```

### English

```dart
'nutrients': 'Nutrients',
'add_fertilizer': 'Add Fertilizer',
'remove_fertilizer': 'Remove Fertilizer',
'fertilizer': 'Fertilizer',
'amount': 'Amount',
'per_liter': 'Per Liter',
'total_amount': 'Total Amount',
'calculated_ec': 'Calculated EC',
'based_on_fertilizers': 'based on fertilizers',
'ec_value': 'EC Value',
'ppm_value': 'PPM Value',
'ec_per_ml': 'EC per ml',
'ppm_per_ml': 'PPM per ml',
'fertilizer_ec_info': 'Optional: For automatic EC calculation in RDWC',
```

**Status:** ⬜ Nicht begonnen

---

## 🚀 NÄCHSTE SCHRITTE

**In nächster Session:**
```
"Implementiere RDWC_EXPERT_LOGGING_TODO.md"
```

**Oder schrittweise:**
```
"Starte mit Phase 1 (Datenbank) aus RDWC_EXPERT_LOGGING_TODO.md"
```

---

## 🔗 ABHÄNGIGKEITEN

**Diese Features bauen aufeinander auf:**

1. ✅ Fertilizers Tabelle (existiert)
2. ✅ RDWC System (existiert)
3. ✅ RDWC Logs (existiert)
4. ⬜ **Fertilizer EC-Werte** (neu)
5. ⬜ **RDWC Log Fertilizers** (neu)
6. ⬜ **Expert-Mode UI** (neu)

**Optional später:**
- ⬜ Dünger-Templates für RDWC
- ⬜ Feeding-Schedule-Import
- ⬜ EC-Verlauf-Diagramme
- ⬜ Automatische Dünger-Empfehlungen

---

**Letzte Aktualisierung:** 2025-11-06
**Status:** Bereit zur Implementierung
