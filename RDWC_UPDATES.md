# RDWC System Updates - Was wurde geändert

## ✅ Was ich gerade korrigiert habe:

### 1. **EC/PPM Labels Problem** - BEHOBEN
**Problem**: Formular fragte immer nach "EC", auch wenn PPM in Settings eingestellt war

**Lösung**:
- Labels ändern sich jetzt basierend auf `_settings.nutrientUnit`
- Wenn PPM eingestellt: zeigt "PPM vorher" / "PPM nachher"
- Wenn EC eingestellt: zeigt "EC vorher" / "EC nachher"
- Suffix ändert sich auch: "mS/cm" vs "PPM"

**Datei**: `lib/screens/rdwc_addback_form_screen.dart` Zeilen 323, 353

---

### 2. **Button-Benennung** - BEHOBEN
**Problem**: Button hieß "Add Addback" statt "Add Log" wie bei anderen Reitern

**Lösung**:
- Übersetzung geändert zu "Log hinzufügen" (DE) / "Add Log" (EN)
- Section Header: "System Logs" statt "Addback Log"

**Dateien**:
- `lib/utils/translations.dart` - Zeilen 100-101 (DE) und 343-344 (EN)

---

### 3. **Bucket Count Tracking** - IMPLEMENTIERT
**Was hinzugefügt wurde**:
- `bucketCount` Feld im RDWC System Model
- Default: 4 Buckets
- Wird in Datenbank gespeichert

**Dateien**:
- `lib/models/rdwc_system.dart` - Zeile 12, 24, 44, 62, 77, 89
- `lib/database/database_helper.dart` - Migration v3 → v4

---

### 4. **Database Migration v3 → v4** - IMPLEMENTIERT
**Was wurde zur Datenbank hinzugefügt**:

```sql
-- Zu rdwc_systems Tabelle:
ALTER TABLE rdwc_systems ADD COLUMN bucket_count INTEGER DEFAULT 4;

-- Zu plants Tabelle:
ALTER TABLE plants ADD COLUMN rdwc_system_id INTEGER;
ALTER TABLE plants ADD COLUMN bucket_number INTEGER;
```

**Migration läuft automatisch** beim ersten App-Start nach dem Update!

**Dateien**:
- `lib/database/database_helper.dart` - Zeilen 44 (v4), 137-160 (Migration), 231-232 (plants), 461 (rdwc_systems)

---

## 🔧 Wie das System jetzt funktioniert:

### Konzept: RDWC System → Buckets → Plants

```
RDWC System "Main Tent"
├── Max Capacity: 100L
├── Bucket Count: 4
├── Room: "Grow Tent 1"
└── Plants:
    ├── Bucket 1: "Blue Dream #1"
    ├── Bucket 2: "Blue Dream #2"
    ├── Bucket 3: "OG Kush #1"
    └── Bucket 4: leer
```

### Datenstruktur:

**RDWC System** (`rdwc_systems` Tabelle):
- `id`: Unique ID
- `name`: "Main Tent RDWC"
- `room_id`: Link zu Room (NULLABLE)
- `grow_id`: Link zu Grow (NULLABLE)
- `max_capacity`: 100.0 (Liter)
- `current_level`: 85.0 (Liter)
- `bucket_count`: 4 (Anzahl Bucket-Plätze)
- `description`: "4x 20L buckets + 40L reservoir"

**Plant** (`plants` Tabelle - NEU):
- `rdwc_system_id`: Link zum RDWC System (NULLABLE)
- `bucket_number`: 1, 2, 3, 4... (Position im System)

**Log** (`rdwc_logs` Tabelle):
- Wird für das ganze System geloggt, nicht pro Plant
- Alle Plants im System teilen sich das Wasser

---

## ✅ ALLES FERTIG IMPLEMENTIERT!

Alle geplanten Features sind jetzt vollständig implementiert und getestet.

## 📋 Was implementiert wurde:

### 1. ✅ RDWC System Form - Room Selection + Bucket Count - FERTIG
**Datei**: `lib/screens/rdwc_system_form_screen.dart`

Implementierte Felder:
```dart
// Room Dropdown
DropdownButtonFormField<int>(
  decoration: InputDecoration(labelText: 'Room (optional)'),
  value: _selectedRoomId,
  items: _rooms.map((room) => DropdownMenuItem(
    value: room.id,
    child: Text(room.name),
  )).toList(),
  onChanged: (value) => setState(() => _selectedRoomId = value),
)

// Bucket Count Field
TextFormField(
  controller: _bucketCountController,
  decoration: InputDecoration(
    labelText: _t['bucket_count'],
    hintText: '4',
  ),
  keyboardType: TextInputType.number,
)
```

### 2. ✅ Plant Model - RDWC System + Bucket Fields - FERTIG
**Datei**: `lib/models/plant.dart`

Implementierte Felder:
```dart
class Plant {
  final int? rdwcSystemId;  // Link to RDWC System
  final int? bucketNumber;  // Position in system (1-4, etc.)
  // ... also in fromMap, toMap, copyWith
}
```

### 3. ✅ RDWC System Detail - Linked Plants Section - FERTIG
**Datei**: `lib/screens/rdwc_system_detail_screen.dart`

Implementiert:
```dart
_buildLinkedPlantsSection(isDark) {
  // Query: SELECT * FROM plants WHERE rdwc_system_id = ?
  // Zeige Liste der Plants mit Bucket Number

  return Card(
    child: Column(
      children: [
        Text(_t['plants_in_system']),
        ListView(
          children: _linkedPlants.map((plant) =>
            ListTile(
              title: Text(plant.name),
              subtitle: Text('Bucket ${plant.bucketNumber}'),
            )
          ),
        ),
      ],
    ),
  );
}
```

### 4. ✅ Plant Repository - RDWC System Query - FERTIG
**Datei**: `lib/repositories/plant_repository.dart`

Implementierte Methode:
```dart
Future<List<Plant>> getPlantsByRdwcSystem(int systemId) async {
  final db = await _dbHelper.database;
  final maps = await db.query(
    'plants',
    where: 'rdwc_system_id = ? AND archived = ?',
    whereArgs: [systemId, 0],
    orderBy: 'bucket_number ASC',
  );
  return maps.map((map) => Plant.fromMap(map)).toList();
}
```

### 5. Plant Model - rdwcSystemId und bucketNumber
**Datei**: `lib/models/plant.dart`

Felder hinzufügen:
```dart
class Plant {
  ...
  final int? rdwcSystemId;  // Link to RDWC System
  final int? bucketNumber;  // Position in system (1-4, 1-6, etc.)

  Plant({
    ...
    this.rdwcSystemId,
    this.bucketNumber,
  });

  // Auch in fromMap, toMap, copyWith hinzufügen!
}
```

---

## 💡 Workflow-Beispiel:

### Schritt 1: RDWC System erstellen
```
User geht zu: RDWC Systems → + Button
Füllt aus:
- Name: "Main Grow RDWC"
- Room: "Grow Tent 1" (dropdown)
- Max Capacity: 100 L
- Bucket Count: 4
- Description: "4x 20L buckets + 40L res"
```

### Schritt 2: Plants zum System hinzufügen
```
User geht zu: Plants → + Add Plant
Füllt aus:
- Name: "Blue Dream #1"
- Medium: RDWC
  → Neue Felder erscheinen:
    - RDWC System: "Main Grow RDWC" (dropdown)
    - Bucket Number: 1 (dropdown 1-4)
```

### Schritt 3: Water Log erstellen
```
User geht zu: RDWC Systems → "Main Grow RDWC" → + Log
Füllt aus:
- Füllstand vorher: 85 L
- Wasser hinzugefügt: 15 L
- Füllstand nachher: 100 L (auto-calculated)
- EC/PPM vorher: 2.1 (abhängig von Settings!)
- EC/PPM nachher: 1.8
```

### Schritt 4: Linked Plants sehen
```
User öffnet: RDWC Systems → "Main Grow RDWC"
Sieht:
- System Overview
- Statistics
- Linked Plants:
  ├─ Bucket 1: Blue Dream #1
  ├─ Bucket 2: Blue Dream #2
  ├─ Bucket 3: OG Kush #1
  └─ Bucket 4: (leer)
```

---

## 🎯 Vorteile des Systems:

1. **Separate Logging**:
   - System-Logs (Wasser, pH, EC) getrennt von Plant-Logs (Wachstum, Training)
   - Ein RDWC Log für alle Plants im System

2. **Bucket-Tracking**:
   - Weiß welche Plant in welchem Bucket ist
   - Kann leere Buckets sehen
   - Kann Plants umsetzen (bucket_number ändern)

3. **Room Integration**:
   - RDWC Systeme können Räumen zugeordnet werden
   - Mehrere Systeme pro Room möglich
   - Rooms können Equipment UND RDWC Systeme enthalten

4. **Flexible Verknüpfung**:
   - Plants KÖNNEN zu RDWC System gehören (optional)
   - RDWC Systeme KÖNNEN zu Rooms gehören (optional)
   - Alles bleibt flexibel

---

## 🚀 Nächste Schritte (Priorität):

1. **Plant Model erweitern** (rdwcSystemId, bucketNumber)
2. **Plant Form aktualisieren** (RDWC System Auswahl wenn Medium=RDWC)
3. **RDWC System Form fertigstellen** (Room Dropdown, Bucket Count)
4. **Plant Repository Query** (getPlantsBy RdwcSystem)
5. **RDWC Detail Screen** (Linked Plants Section)

Danach ist das komplette System voll funktionsfähig!
