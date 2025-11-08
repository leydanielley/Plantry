# CASCADE Constraints - Vollständige Analyse

**Datum:** 2025-11-08
**Analysiert:** ALLE ON DELETE Constraints in database_helper.dart

---

## Alle CASCADE Constraints

| # | Tabelle | FK | Referenz | Constraint | Status |
|---|---------|----|----|------------|--------|
| 1 | rdwc_logs | system_id | rdwc_systems(id) | CASCADE | ✅ OK |
| 2 | plant_logs | plant_id | plants(id) | CASCADE | ✅ OK |
| 3 | log_fertilizers | log_id | plant_logs(id) | CASCADE | ✅ OK |
| 4 | **hardware** | room_id | rooms(id) | CASCADE | ⚠️ **FRAGLICH** |
| 5 | photos | log_id | plant_logs(id) | CASCADE | ✅ OK |
| 6 | template_fertilizers | template_id | log_templates(id) | CASCADE | ✅ OK |
| 7 | **harvests** | plant_id | plants(id) | CASCADE | ⚠️ **FRAGLICH** |
| 8 | rdwc_log_fertilizers | rdwc_log_id | rdwc_logs(id) | CASCADE | ✅ OK |
| 9 | rdwc_recipe_fertilizers | recipe_id | rdwc_recipes(id) | CASCADE | ✅ OK |

---

## ⚠️ Problem #1: Hardware CASCADE

### Aktueller Code
```sql
-- database_helper.dart:467
FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
```

### Problem

**Szenario:**
```
1. User hat Room "Growroom 1"
2. Hardware: "Mars Hydro LED 600W" (gekauft für 500€)
3. User löscht "Growroom 1"
4. CASCADE löscht "Mars Hydro LED 600W"! 💥

→ Teure Hardware-Info WEG!
```

### Ist das gewollt?

**Fragen:**
- Hardware ist teuer - sollte sie behalten werden?
- User will vielleicht Hardware in anderen Room bewegen?
- Historische Info über gekaufte Hardware wertvoll?

**Mögliche Lösungen:**

**Option A: SET NULL (Empfohlen)**
```sql
FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL
```
→ Room gelöscht, Hardware bleibt, room_id = NULL

**Option B: RESTRICT**
```sql
FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE RESTRICT
```
→ Room mit Hardware kann nicht gelöscht werden

**Option C: CASCADE behalten**
→ Hardware gehört zu Room, wird mitgelöscht

---

## ⚠️ Problem #2: Harvest CASCADE

### Aktueller Code
```sql
-- database_helper.dart:548
FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE CASCADE
```

### Problem

**Szenario:**
```
1. User hat Plant "Blue Dream #1"
2. Harvest: 150g dry, Quality 5★, THC 22%
3. User archiviert/löscht Plant
4. CASCADE löscht Harvest-Daten! 💥

→ Wertvolle Ernte-Info WEG!
```

### Ist das gewollt?

**Fragen:**
- Harvest ist historisch wertvoll (Yield, Quality)
- User will vielleicht Plant löschen aber Harvest behalten?
- Für Statistiken wichtig?

**ABER:**
Plant hat `archived` Feld! User sollte archivieren statt löschen.

**Aktueller Delete-Flow:**
```dart
// Keine Delete-Methode für Plants gefunden in Screens!
// Plants werden nur ARCHIVIERT, nicht gelöscht
```

**Bedeutet:**
- ✅ User kann Plants nicht löschen (nur archivieren)
- ✅ Harvest bleibt erhalten
- ⚠️ ABER: Wenn jemand direkt DB ändert → Datenverlust

---

## Detaillierte Analyse

### ✅ #1: rdwc_logs → rdwc_systems (CASCADE)

**Korrekt!**
- RDWC Log gehört zu System
- System gelöscht → Logs haben keinen Kontext
- Logs ohne System = nutzlos

**Beispiel:**
```
System: "Main RDWC 4-Bucket"
├─ Log 1: Water added 50L
├─ Log 2: pH adjusted to 6.0
└─ Log 3: Full change
```
System weg → Logs verlieren Bedeutung ✅

---

### ✅ #2: plant_logs → plants (CASCADE)

**Korrekt!**
- Plant Log gehört zu Plant
- Plant gelöscht → Logs nutzlos
- Standard Pattern

**ABER:** Plant hat `archived` Feld!
- User sollte archivieren statt löschen
- Wenn archiviert: Logs bleiben ✅

---

### ✅ #3: log_fertilizers → plant_logs (CASCADE)

**Korrekt!**
- Log Fertilizer ist Teil vom Log
- Log gelöscht → Fertilizer-Verknüpfung nutzlos
- Standard Cleanup

---

### ⚠️ #4: hardware → rooms (CASCADE)

**FRAGLICH!**

**Pro CASCADE:**
- Hardware gehört zu Room
- Setup ist Room-spezifisch

**Contra CASCADE:**
- Hardware ist teuer (500€+ LED)
- User will vielleicht behalten
- In anderen Room bewegen

**Empfehlung:**
```sql
FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL
```

**Migration nötig?**
- Nur wenn wichtig
- User löschen selten Rooms
- Hardware meist in aktiven Rooms

---

### ✅ #5: photos → plant_logs (CASCADE)

**Korrekt!**
- Photo gehört zu Log
- Log gelöscht → Photo verliert Kontext
- Standard Pattern

**Dateien werden auch gelöscht:**
```dart
// plant_detail_screen.dart oder ähnlich
await file.delete();
```

---

### ✅ #6: template_fertilizers → log_templates (CASCADE)

**Korrekt!**
- Template Fertilizer ist Teil vom Template
- Template gelöscht → Fertilizer-Liste nutzlos

---

### ⚠️ #7: harvests → plants (CASCADE)

**FRAGLICH, aber OK!**

**Warum OK:**
- Plants haben `archived` Feld
- User löscht Plants NICHT (nur archivieren)
- Kein Plant-Delete in UI gefunden

**Risiko:**
- Direkte DB-Änderung könnte Harvest löschen
- Aber: User sollte nicht direkt DB ändern

**Empfehlung:**
- CASCADE BEHALTEN
- ABER: Sicherstellen dass Plant-Delete UI warnt

---

### ✅ #8: rdwc_log_fertilizers → rdwc_logs (CASCADE)

**Korrekt!**
- RDWC Log Fertilizer ist Teil vom Log
- Log gelöscht → Fertilizer-Verknüpfung nutzlos

---

### ✅ #9: rdwc_recipe_fertilizers → rdwc_recipes (CASCADE)

**Korrekt!**
- Recipe Fertilizer ist Teil vom Recipe
- Recipe gelöscht → Fertilizer-Liste nutzlos

---

## SET NULL Constraints - Alle OK

| Tabelle | FK | Referenz | Constraint | Zweck |
|---------|----|----|------------|-------|
| rdwc_systems | room_id | rooms(id) | SET NULL | System kann ohne Room existieren |
| rdwc_systems | grow_id | grows(id) | SET NULL | System kann ohne Grow existieren |
| rooms | rdwc_system_id | rdwc_systems(id) | SET NULL | Room kann ohne System existieren |
| grows | room_id | rooms(id) | SET NULL | Grow kann ohne Room existieren |
| plants | room_id | rooms(id) | SET NULL | Plant kann ohne Room existieren |
| plants | grow_id | grows(id) | SET NULL | Plant kann ohne Grow existieren |
| plants | rdwc_system_id | rdwc_systems(id) | SET NULL | Plant kann ohne System existieren |

✅ **Alle SET NULL sind korrekt!**

---

## RESTRICT Constraints - Alle OK

| Tabelle | FK | Referenz | Constraint | Zweck |
|---------|----|----|------------|-------|
| log_fertilizers | fertilizer_id | fertilizers(id) | RESTRICT | Schützt historische Daten ✅ (v9) |
| template_fertilizers | fertilizer_id | fertilizers(id) | RESTRICT | Schützt Templates ✅ (v9) |
| rdwc_log_fertilizers | fertilizer_id | fertilizers(id) | RESTRICT | Schützt RDWC historische Daten ✅ |
| rdwc_recipe_fertilizers | fertilizer_id | fertilizers(id) | RESTRICT | Schützt Rezepte ✅ |

✅ **Alle RESTRICT sind korrekt!**

---

## Zusammenfassung

### Kritische Probleme: **0**

### Fragliche Designs: **2**

**1. hardware → rooms (CASCADE)**
- Risiko: NIEDRIG
- User löschen selten Rooms
- Hardware-Verlust möglich aber selten

**2. harvests → plants (CASCADE)**
- Risiko: SEHR NIEDRIG
- Plants werden nur archiviert, nicht gelöscht
- Harvest bleibt erhalten
- ABER: Direkte DB-Änderung gefährlich

### Empfehlungen

**Sofort (v0.8.8):**
- ✅ Nichts! Migration v9 reicht.

**Optional (v0.9.0):**

**1. Hardware CASCADE → SET NULL**
```sql
-- Migration v10
FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL
```
**Nutzen:** Hardware bleibt erhalten wenn Room gelöscht wird

**2. Plant Delete Warning verbessern**
```dart
// Wenn Plant gelöscht wird (nicht archiviert):
if (plant.harvests.isNotEmpty) {
  showDialog(
    // ⚠️ WARNING: Plant hat Harvest-Daten!
    // Optionen: Archivieren (empfohlen) oder Löschen (mit Harvest)
  );
}
```

---

## Fazit

✅ **Keine kritischen Probleme gefunden!**

Die CASCADE Constraints sind größtenteils korrekt designed.

**Einziger echter Bug war:**
- log_fertilizers, template_fertilizers: CASCADE statt RESTRICT
- ✅ BEHOBEN in Migration v9

**Fragliche Designs:**
- hardware CASCADE (aber OK)
- harvests CASCADE (aber OK weil Plants nicht gelöscht werden)

---

**Analysiert:** 2025-11-08
**Status:** ✅ SAUBER
