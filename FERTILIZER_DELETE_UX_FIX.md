# Fertilizer DELETE UX Improvement

**Datum:** 2025-11-08
**Version:** 0.8.7+12
**Issue:** Benutzerfreundliche Fehlermeldung bei Fertilizer Delete

---

## Problem

**Vorher:**
Wenn ein Dünger in RDWC Rezepten oder Logs verwendet wird und der User versucht ihn zu löschen, zeigt die App:

```
Error deleting: SqliteException(19): FOREIGN KEY constraint failed
```

**User-Perspektive:**
- ❌ Technische Fehlermeldung verwirrend
- ❌ User weiß nicht, was zu tun ist
- ❌ Keine Information WO der Dünger verwendet wird

---

## Lösung

**Jetzt:**
Die App prüft VORHER ob der Dünger in Verwendung ist und zeigt eine benutzerfreundliche Warnung:

```
⚠️ Kann nicht gelöscht werden

Dieser Dünger wird verwendet in:
• 2 Rezepte
• 5 RDWC Logs
• 3 Pflanzen-Logs

Entferne ihn zuerst aus allen Rezepten und Logs.
```

**User-Perspektive:**
- ✅ Verständliche Meldung
- ✅ Zeigt konkret WO der Dünger verwendet wird
- ✅ Klare Anleitung was zu tun ist

---

## Implementierung

### 1. FertilizerRepository erweitert

**Neue Methoden:**

```dart
/// Prüft ob Dünger in Verwendung ist (Rezepte, Logs, etc.)
Future<bool> isInUse(int id) async {
  final db = await _dbHelper.database;

  // Check RDWC recipes
  final recipeCount = Sqflite.firstIntValue(...) ?? 0;

  // Check RDWC logs
  final rdwcLogCount = Sqflite.firstIntValue(...) ?? 0;

  // Check plant logs
  final plantLogCount = Sqflite.firstIntValue(...) ?? 0;

  return (recipeCount + rdwcLogCount + plantLogCount) > 0;
}

/// Gibt detaillierte Nutzungs-Statistik zurück
Future<Map<String, int>> getUsageDetails(int id) async {
  return {
    'recipes': ...,
    'rdwc_logs': ...,
    'plant_logs': ...,
  };
}
```

**Dateien geändert:**
- `lib/repositories/fertilizer_repository.dart`

---

### 2. FertilizerListScreen Delete-Logik verbessert

**Neue Logik:**

```dart
Future<void> _deleteFertilizer(Fertilizer fertilizer) async {
  // 1. Prüfe VORHER ob in Verwendung
  final isInUse = await _fertilizerRepo.isInUse(fertilizer.id!);

  if (isInUse) {
    // Zeige benutzerfreundliche Warnung
    final usage = await _fertilizerRepo.getUsageDetails(fertilizer.id!);

    showDialog(
      // Orange Warning Icon
      // Details wo verwendet
      // "Entferne ihn zuerst..."
    );
    return;
  }

  // 2. Nicht in Verwendung - normale Lösch-Bestätigung
  final confirm = await showDialog<bool>(...);

  if (confirm == true) {
    await _fertilizerRepo.delete(fertilizer.id!);
  }
}
```

**Dateien geändert:**
- `lib/screens/fertilizer_list_screen.dart`

---

### 3. Übersetzungen hinzugefügt

**Neue Keys:**

| Key | Deutsch | English |
|-----|---------|---------|
| `cannot_delete` | Kann nicht gelöscht werden | Cannot be deleted |
| `fertilizer_in_use_message` | Dieser Dünger wird verwendet in: | This fertilizer is used in: |
| `fertilizer_remove_first` | Entferne ihn zuerst aus allen Rezepten und Logs. | Remove it from all recipes and logs first. |
| `plant_logs` | Pflanzen-Logs | Plant Logs |
| `unexpected_error` | Unerwarteter Fehler | Unexpected error |

**Dateien geändert:**
- `lib/utils/translations.dart`

---

## Technische Details

### Datenbank Constraints

Die `ON DELETE RESTRICT` Constraints bleiben unverändert:

```sql
-- RDWC Recipe Fertilizers
FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT

-- RDWC Log Fertilizers
FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
```

**Warum?**
- ✅ Datenintegrität bleibt gewährleistet
- ✅ Verhindert versehentliches Löschen von Rezept-Komponenten
- ✅ Historische Logs bleiben konsistent

**Neu:**
- ✅ App prüft VORHER ob DELETE möglich ist
- ✅ User bekommt hilfreiche Warnung STATT SQL Exception

---

## User Flow

### Szenario 1: Dünger ist in Verwendung

1. User klickt auf "Löschen" bei Fertilizer "BioBizz Bloom"
2. App prüft: `isInUse(fertilizerId)` → `true`
3. App lädt Details: `getUsageDetails(fertilizerId)`
   ```
   {
     'recipes': 2,
     'rdwc_logs': 5,
     'plant_logs': 0
   }
   ```
4. App zeigt Warning Dialog:
   ```
   ⚠️ Kann nicht gelöscht werden

   Dieser Dünger wird verwendet in:
   • 2 Rezepte
   • 5 RDWC Logs

   Entferne ihn zuerst aus allen Rezepten und Logs.

   [OK]
   ```
5. User klickt OK → kein Delete

---

### Szenario 2: Dünger ist NICHT in Verwendung

1. User klickt auf "Löschen" bei Fertilizer "Test Dünger"
2. App prüft: `isInUse(fertilizerId)` → `false`
3. App zeigt normale Lösch-Bestätigung:
   ```
   Dünger löschen

   Wirklich löschen "Test Dünger"?

   [Abbrechen] [Löschen]
   ```
4. User klickt Löschen → Delete erfolgreich

---

## Testing

### Test 1: DELETE mit Rezept-Verwendung
**Setup:**
- Erstelle RDWC Rezept mit Fertilizer "Flora Grow"
- Versuche "Flora Grow" zu löschen

**Erwartet:**
- ✅ Warning Dialog erscheint
- ✅ Zeigt "1 Rezepte"
- ✅ Fertilizer wird NICHT gelöscht

**Status:** ✅ Funktioniert

---

### Test 2: DELETE ohne Verwendung
**Setup:**
- Erstelle Fertilizer "Test" (nicht verwendet)
- Versuche zu löschen

**Erwartet:**
- ✅ Normale Bestätigung erscheint
- ✅ Nach Bestätigung wird gelöscht

**Status:** ✅ Funktioniert

---

### Test 3: DELETE mit RDWC Log Verwendung
**Setup:**
- Erstelle RDWC System
- Füge Log mit Fertilizer "Flora Bloom" hinzu
- Versuche "Flora Bloom" zu löschen

**Erwartet:**
- ✅ Warning Dialog zeigt "1 RDWC Logs"

**Status:** ✅ Funktioniert

---

### Test 4: DELETE mit Plant Log Verwendung
**Setup:**
- Füge Plant Log mit Fertilizer "BioBizz Grow" hinzu
- Versuche zu löschen

**Erwartet:**
- ✅ Warning Dialog zeigt "1 Pflanzen-Logs"

**Status:** ✅ Funktioniert

---

## Code Quality

### Flutter Analyze
```bash
flutter analyze --no-fatal-infos
```

**Ergebnis:** ✅ No issues found!

---

### Mounted Checks
Alle async gaps haben korrekte mounted checks:

```dart
// Nach isInUse check
if (!mounted) return;

// Nach getUsageDetails
if (!mounted) return;

// Nach Delete Dialog
if (!mounted) return;
```

**Status:** ✅ Keine BuildContext warnings

---

## Migration Notes

**Breaking Changes:** Keine

**Database Changes:** Keine

**Dependencies:** Keine neuen

**Compatibility:** Voll rückwärtskompatibel

---

## Zukünftige Verbesserungen (Optional)

### 1. Zeige Rezept-Namen statt Anzahl
```
Dieser Dünger wird verwendet in:
• Rezept: "RDWC Bloom Week 5"
• Rezept: "Veg Grow A+B"
• 3 RDWC Logs
```

**Aufwand:** ~1 Stunde

---

### 2. "Rezepte anzeigen" Button
```
[Rezepte anzeigen] [OK]
```
→ Navigiert zur Rezept-Liste mit Filter

**Aufwand:** ~2 Stunden

---

### 3. Batch-Delete für ungenutzte Fertilizer
```
Dünger-Verwaltung
[Ungenutzte löschen]
```

**Aufwand:** ~3 Stunden

---

## Fazit

✅ **UX deutlich verbessert**
- User bekommt hilfreiche statt technische Fehlermeldungen
- Zeigt konkret wo Fertilizer verwendet wird
- Klare Anleitung was zu tun ist

✅ **Technisch sauber**
- Keine Breaking Changes
- Datenintegrität bleibt gewahrt
- Keine Flutter Analyze Warnings

✅ **Production Ready**
- Vollständig getestet
- Übersetzungen für DE + EN
- Keine Regressions

---

**Implementiert:** 2025-11-08
**Getestet:** 2025-11-08
**Release:** v0.8.8 (geplant)
