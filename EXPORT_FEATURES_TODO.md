# PLANTRY - ERWEITERTE EXPORT-FUNKTIONEN - TODO

**Status:** Geplant, nicht begonnen
**Erstellt:** 2025-11-06
**Geschätzte Zeit:** 2-4 Stunden
**Risiko:** Niedrig (nur Lese-Operationen, keine DB-Änderungen)

---

## 📦 BENÖTIGTE PACKAGES

```yaml
# Zu pubspec.yaml hinzufügen:
excel: ^4.0.3           # Excel-Export (.xlsx)
encrypt: ^5.0.3         # AES-Verschlüsselung
csv: ^6.0.0            # CSV-Export
```

**Status:** ⬜ Nicht begonnen

---

## 🏗️ ARCHITEKTUR

### Neue Dateien zu erstellen:

```
lib/models/
  └── export_options.dart              ⬜ Konfigurationsmodell für Export-Optionen

lib/services/
  ├── backup_service.dart              ✅ Existiert bereits (erweitern)
  ├── export_json_service.dart         ⬜ JSON-Export Service
  ├── export_csv_service.dart          ⬜ CSV-Export Service
  ├── export_excel_service.dart        ⬜ Excel-Export Service
  └── encryption_service.dart          ⬜ AES-256 Verschlüsselung

lib/screens/
  └── export_options_screen.dart       ⬜ UI für Export-Optionen Auswahl

lib/utils/
  └── file_utils.dart                  ⬜ Hilfs-Funktionen für Dateisystem
```

---

## ✅ FEATURE-LISTE

### 1. ZUSÄTZLICHE EXPORT-FORMATE

#### 1.1 JSON-Export (ohne ZIP)
- ⬜ Nur data.json exportieren
- ⬜ Für Entwickler/Poweruser
- ⬜ Keine Fotos
- ⬜ Schneller Export
- **Datei:** `lib/services/export_json_service.dart`

#### 1.2 CSV-Export
- ⬜ Jede Tabelle als separate CSV-Datei
- ⬜ Excel-kompatibel
- ⬜ UTF-8 mit BOM
- ⬜ Alle Tabellen in einem Ordner
- ⬜ ZIP-Container für alle CSVs
- **Datei:** `lib/services/export_csv_service.dart`
- **Tabellen:** rooms, grows, plants, plant_logs, fertilizers, log_fertilizers, hardware, photos, harvests, app_settings

#### 1.3 Excel-Export (.xlsx)
- ⬜ Multi-Sheet Excel-Datei
- ⬜ Ein Sheet pro Tabelle
- ⬜ Formatierte Spaltenüberschriften
- ⬜ Auto-Width für Spalten
- ⬜ Datum-Formatierung
- **Datei:** `lib/services/export_excel_service.dart`
- **Package:** excel ^4.0.3

---

### 2. SELEKTIVER EXPORT

#### 2.1 Pflanzen-Filter
- ⬜ Multi-Select UI für Pflanzen
- ⬜ "Alle auswählen" / "Alle abwählen"
- ⬜ Nur ausgewählte Pflanzen + zugehörige Logs exportieren
- ⬜ Foreign-Key-Beziehungen beachten
- **Datei:** `lib/models/export_options.dart` (plantIds: List<int>)

#### 2.2 Datumsbereich-Filter
- ⬜ Von-Datum Auswahl
- ⬜ Bis-Datum Auswahl
- ⬜ Nur Logs im Zeitraum exportieren
- ⬜ Zugehörige Pflanzen/Fotos mitnehmen
- **Datei:** `lib/models/export_options.dart` (startDate, endDate)

#### 2.3 Foto-Filter
- ⬜ Checkbox "Fotos einschließen" (Ja/Nein)
- ⬜ Bei Nein: Nur Metadaten, keine Bilddateien
- ⬜ Reduziert Dateigröße erheblich
- **Datei:** `lib/models/export_options.dart` (includePhotos: bool)

---

### 3. EXPORT-OPTIONEN

#### 3.1 Foto-Kompression
- ⬜ Option "Original" (keine Kompression)
- ⬜ Option "Komprimiert" (80% Qualität)
- ⬜ Option "Stark komprimiert" (60% Qualität)
- ⬜ Nutzt flutter_image_compress (bereits vorhanden)
- ⬜ Zeigt geschätzte Dateigröße an
- **Datei:** `lib/models/export_options.dart` (photoCompression: enum)

#### 3.2 Verschlüsselung
- ⬜ Checkbox "Backup verschlüsseln"
- ⬜ Passwort-Eingabe (min. 8 Zeichen)
- ⬜ Passwort-Bestätigung
- ⬜ AES-256 Verschlüsselung
- ⬜ Passwort wird NICHT gespeichert
- ⬜ Hinweis: "Passwort nicht vergessen!"
- ⬜ Verschlüsselte .enc Datei
- **Datei:** `lib/services/encryption_service.dart`
- **Package:** encrypt ^5.0.3
- **Algorithmus:** AES-256-CBC

---

### 4. SPEICHERORT-OPTIONEN

#### 4.1 App-Verzeichnis (Standard)
- ✅ Existiert bereits
- `/data/data/com.example.plantry/files/`

#### 4.2 Downloads-Ordner
- ⬜ Öffentlich zugänglich
- ⬜ `/storage/emulated/0/Download/Plantry/`
- ⬜ Nutzer kann Datei direkt finden
- ⬜ Keine Storage-Permission ab Android 10+

#### 4.3 Benutzer wählt Ordner
- ⬜ Nutzt file_picker (bereits vorhanden)
- ⬜ Speichern-Dialog öffnen
- ⬜ Nutzer wählt Zielordner
- ⬜ Funktioniert auf Android & iOS

#### 4.4 Externes USB-Laufwerk (OTG)
- ⬜ Erkennung von USB-Laufwerken
- ⬜ Ordner-Auswahl auf USB
- ⬜ Nur Android (iOS hat kein OTG)
- ⬜ Zeigt Fehler wenn kein USB angeschlossen

---

## 🎨 UI-DESIGN

### Export-Optionen Screen

```
┌─────────────────────────────────┐
│  ← Export-Optionen             │
├─────────────────────────────────┤
│                                 │
│ 📦 EXPORT-FORMAT                │
│ ○ ZIP mit JSON + Fotos (Standard)│
│ ○ JSON einzeln                  │
│ ○ CSV-Dateien                   │
│ ○ Excel (.xlsx)                 │
│                                 │
│ 🔍 FILTER                       │
│ □ Nur bestimmte Pflanzen        │
│   → [Pflanzen auswählen ›]      │
│ □ Nur Zeitraum                  │
│   Von: [___] Bis: [___]         │
│                                 │
│ 📷 FOTOS                        │
│ ☑ Fotos einschließen            │
│ Kompression: ○ Original         │
│              ● Komprimiert      │
│              ○ Stark komprimiert│
│                                 │
│ 🔒 SICHERHEIT                   │
│ □ Backup verschlüsseln          │
│   Passwort: [__________]        │
│   Bestätigen: [__________]      │
│                                 │
│ 💾 SPEICHERORT                  │
│ ○ App-Ordner                    │
│ ○ Downloads                     │
│ ● Benutzerdefiniert             │
│ ○ USB-Laufwerk (OTG)            │
│                                 │
│ ┌─────────────────────────────┐ │
│ │   [  EXPORT STARTEN  ]      │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

---

## 📝 IMPLEMENTIERUNGS-SCHRITTE

### Phase 1: Grundlagen (30 Min)
- ⬜ 1. Packages zu pubspec.yaml hinzufügen
- ⬜ 2. `flutter pub get` ausführen
- ⬜ 3. ExportOptions Model erstellen
- ⬜ 4. File Utils Helper erstellen

### Phase 2: Export-Services (90 Min)
- ⬜ 5. JSON-Export Service implementieren
- ⬜ 6. CSV-Export Service implementieren
- ⬜ 7. Excel-Export Service implementieren
- ⬜ 8. Encryption Service implementieren

### Phase 3: Filter & Optionen (45 Min)
- ⬜ 9. Pflanzen-Filter Logik
- ⬜ 10. Datumsbereich-Filter Logik
- ⬜ 11. Foto-Kompression implementieren
- ⬜ 12. Speicherort-Auswahl implementieren

### Phase 4: UI (60 Min)
- ⬜ 13. Export-Optionen Screen UI erstellen
- ⬜ 14. Pflanzen-Auswahl Dialog erstellen
- ⬜ 15. Datumsbereich-Picker integrieren
- ⬜ 16. Verschlüsselungs-Dialog erstellen

### Phase 5: Integration (30 Min)
- ⬜ 17. BackupService erweitern
- ⬜ 18. Settings Screen anpassen
- ⬜ 19. Übersetzungen hinzufügen (DE + EN)
- ⬜ 20. Navigation verknüpfen

### Phase 6: Testing (15 Min)
- ⬜ 21. JSON-Export testen
- ⬜ 22. CSV-Export testen
- ⬜ 23. Excel-Export testen
- ⬜ 24. Verschlüsselung testen
- ⬜ 25. Alle Speicherorte testen

---

## 🔧 TECHNISCHE DETAILS

### ExportOptions Model

```dart
class ExportOptions {
  final ExportFormat format;           // ZIP, JSON, CSV, EXCEL
  final List<int>? plantIds;           // null = alle
  final DateTime? startDate;           // null = kein Filter
  final DateTime? endDate;             // null = kein Filter
  final bool includePhotos;            // true = Fotos einschließen
  final PhotoCompression compression;  // ORIGINAL, COMPRESSED, HIGHLY_COMPRESSED
  final bool encrypt;                  // true = verschlüsseln
  final String? password;              // null = keine Verschlüsselung
  final StorageLocation location;      // APP_DIR, DOWNLOADS, CUSTOM, USB
  final String? customPath;            // bei CUSTOM
}

enum ExportFormat { zip, json, csv, excel }
enum PhotoCompression { original, compressed, highlyCompressed }
enum StorageLocation { appDir, downloads, custom, usb }
```

### Verschlüsselung

```dart
// AES-256-CBC
// Key Derivation: PBKDF2 mit 10000 Iterationen
// Salt: 16 Byte zufällig
// IV: 16 Byte zufällig
// Format: [Salt(16)][IV(16)][EncryptedData]
```

### CSV-Format

```csv
# plants.csv
id,name,strain,room_id,grow_id,phase,germination_date,created_at,updated_at
1,"Blue Dream","Sativa",1,1,"flowering","2024-01-15T10:00:00.000","2024-01-15T10:00:00.000","2024-01-15T10:00:00.000"
```

### Excel-Format

```
Sheet 1: Plants
Sheet 2: Logs
Sheet 3: Fertilizers
Sheet 4: Photos
Sheet 5: Rooms
Sheet 6: Grows
Sheet 7: Hardware
Sheet 8: Harvests
```

---

## ⚠️ WICHTIGE HINWEISE

### Sicherheit
- ✅ Alle Operationen nur LESEN aus DB (keine Änderungen)
- ✅ Passwörter werden NIEMALS gespeichert
- ✅ Verschlüsselung ist optional
- ✅ Nutzer wird gewarnt: "Passwort nicht vergessen!"

### Performance
- Bei vielen Fotos kann Export lange dauern
- Loading-Dialog mit Fortschrittsanzeige zeigen
- Foto-Kompression kann Zeit sparen
- Excel-Export ist langsamer als CSV

### Kompatibilität
- CSV: UTF-8 mit BOM (Excel-kompatibel)
- Excel: .xlsx Format (Office 2007+)
- JSON: Standard JSON (UTF-8)
- ZIP: Standard ZIP-Format

### Fehlerbehandlung
- Nicht genug Speicherplatz → Fehler anzeigen
- USB-Laufwerk nicht verfügbar → Fehler anzeigen
- Verschlüsselung: Passwort zu kurz → Warnung
- Keine Pflanzen ausgewählt → Warnung

---

## 📊 GESCHÄTZTE DATEIGRÖSSEN

**Beispiel: 10 Pflanzen, 100 Logs, 50 Fotos**

| Format | Mit Fotos | Ohne Fotos | Verschlüsselt |
|--------|-----------|------------|---------------|
| ZIP    | ~15 MB    | ~50 KB     | +10%          |
| JSON   | -         | ~30 KB     | +10%          |
| CSV    | ~2 MB     | ~40 KB     | +10%          |
| Excel  | ~2 MB     | ~60 KB     | +10%          |

*Fotos: ~200-300 KB pro Foto (komprimiert)*

---

## 🚀 NÄCHSTE SCHRITTE

1. **In nächster Session:** Referenziere diese Datei
2. **Befehl:** "Implementiere die Features aus EXPORT_FEATURES_TODO.md"
3. **Oder schrittweise:** "Starte mit Phase 1 aus EXPORT_FEATURES_TODO.md"

---

## 📝 NOTIZEN

- Alle Features sind OFFLINE (keine Netzwerk-Operationen)
- Keine neuen Permissions erforderlich
- Rückwärtskompatibel (alte Backups funktionieren weiter)
- Import bleibt unverändert (nur ZIP-Import)

---

**Letzte Aktualisierung:** 2025-11-06
**Status:** Bereit zur Implementierung
