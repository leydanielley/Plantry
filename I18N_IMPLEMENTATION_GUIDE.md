# SYSTEMATIC I18N IMPLEMENTATION GUIDE

## Overview

This guide shows how to systematically extract all ~300 hardcoded German strings from the Plantry application.

## Strategy

1. **Add all translations to translations.dart first**
2. **Update each screen file systematically**
3. **Test each file after changes**

## Translation Keys Added (22 validation messages)

✅ Already added to translations.dart:
- `error_invalid_ph`, `error_ph_range`
- `error_invalid_ec`, `error_ec_range`
- `error_invalid_temperature`, `error_temperature_range`
- `error_invalid_humidity`, `error_humidity_range`
- `error_invalid_water_amount`, `error_water_amount_positive`
- `error_invalid_email`, `error_invalid_npk`
- `error_invalid_number`, `error_invalid_integer`
- `error_value_min`, `error_value_max`, `error_value_range`
- `error_field_required`
- `error_log_before_seed`, `error_log_before_phase`
- `error_log_future`, `error_log_before_seed_short`
- `warning_log_old`

## Remaining Strings to Extract (By Priority)

### HIGH PRIORITY: Form Screens (161 strings)

#### add_log_screen.dart (35 strings)
- Dialog titles: "Phase wählen", "Dünger hinzufügen", etc.
- Form labels: "Aktion", "Wasser", "Dünger", "pH & EC Werte", "Umgebung"
- Field labels: "Menge (Liter)", "pH In", "EC In", "Temperatur (°C)", "Luftfeuchte (%)"
- Hints: "Beobachtungen, Änderungen, etc..."
- Info text: "Massen-Log Modus", "Dieser Log wird für X Pflanzen gespeichert"
- Phase descriptions: "Keimling / Sämling", "Vegetatives Wachstum", etc.
- Button labels: "Log speichern", "Hinzufügen", "Abbrechen"

#### edit_plant_screen.dart (30 strings)
- Dialog titles: "⚠️ Warnung", "Achtung: Logs werden gelöscht!", "Pflanze löschen?"
- Form section headers: "Basis Info", "Genetik", "Grow Setup", "Container Info"
- Field labels: "Name *", "Strain", "Breeder", "Geschlecht"
- Button labels: "Änderungen speichern", "Pflanze löschen"
- Warning messages: "Wachstumsdatum kann nicht vor dem Keimdatum liegen!", etc.
- Info text: "Diese Pflanze hat X Log-Einträge", "X Logs werden GELÖSCHT!"

#### edit_log_screen.dart (23 strings)
Similar pattern to add_log_screen.dart

#### add_plant_screen.dart (16 strings)
Key translations needed:
```
'plant_form_title': 'Neue Pflanze'
'plant_form_section_basic': 'Grundinformationen'
'plant_form_section_genetics': 'Genetik'
'plant_form_section_grow': 'Grow Setup'
'plant_form_section_container': 'Container Info (optional)'
'plant_form_name_label': 'Name *'
'plant_form_name_hint': 'z.B. Wedding Cake'
'plant_form_name_error': 'Bitte Namen eingeben'
'plant_form_quantity_label': 'Anzahl'
'plant_form_quantity_hint': '1-50'
'plant_form_quantity_helper': 'Wie viele Pflanzen erstellen?'
'plant_form_quantity_error': 'Zahl zwischen 1-50'
'plant_form_strain_label': 'Strain'
'plant_form_strain_hint': 'z.B. Wedding Cake'
'plant_form_breeder_label': 'Breeder'
'plant_form_breeder_hint': 'z.B. Barney\'s Farm'
'plant_form_gender_label': 'Geschlecht'
'plant_form_medium_label': 'Medium'
'plant_form_phase_label': 'Phase'
'plant_form_grow_label': 'Grow (optional)'
'plant_form_grow_label_preset': 'Grow (vorgegeben)'
'plant_form_grow_helper': 'Mehrere Pflanzen zu einem Grow zusammenfassen'
'plant_form_grow_helper_preset': 'Diese Pflanze wird diesem Grow zugeordnet'
'plant_form_grow_none': 'Kein Grow'
'plant_form_rdwc_system_label': 'RDWC System *'
'plant_form_rdwc_system_helper': 'Wähle das RDWC System für diese Pflanze'
'plant_form_rdwc_system_none': 'Kein System'
'plant_form_rdwc_system_error': 'RDWC System erforderlich'
'plant_form_bucket_label': 'Bucket Nummer *'
'plant_form_bucket_helper': '{occupied}/{total} Buckets belegt'
'plant_form_bucket_select': 'Wähle Bucket'
'plant_form_bucket_error': 'Bucket Nummer erforderlich'
'plant_form_bucket_info': 'Automatische Verteilung:\nBuckets {buckets} werden verwendet'
'plant_form_room_label': 'Raum (optional)'
'plant_form_room_none': 'Kein Raum'
'plant_form_system_size_label': 'System Größe (Liter)'
'plant_form_system_size_hint': 'z.B. 100'
'plant_form_system_size_helper': 'Gesamtgröße des Hydro-Systems (DWC/Hydro)'
'plant_form_container_size_label': 'Topfgröße (Liter)'
'plant_form_container_size_hint': 'z.B. 11'
'plant_form_container_size_helper': 'Aktueller Topf'
'plant_form_rdwc_system_info': 'System-Größe wird vom RDWC System übernommen'
'plant_form_seed_date_label': 'Seed-Datum'
'plant_form_seed_date_not_set': 'Nicht gesetzt (wird auf Erstellungszeitpunkt gesetzt)'
'plant_form_seed_date_reset': 'Datum zurücksetzen'
'plant_form_seed_date_tip': 'Tipp: Setze ein Datum für genaueres Day-Tracking'
'plant_form_button_save': 'Pflanze(n) erstellen'
'dialog_create_grow_title': 'Neuen Grow erstellen'
'dialog_create_grow_name_label': 'Name *'
'dialog_create_grow_name_hint': 'z.B. Winter Grow 2025'
'dialog_create_grow_description_label': 'Beschreibung (optional)'
'dialog_create_grow_description_hint': 'z.B. 5x Wedding Cake'
'dialog_create_grow_button_cancel': 'Abbrechen'
'dialog_create_grow_button_create': 'Erstellen'
'button_create_new_grow': 'Neuen Grow erstellen'
'error_buckets_full': 'Nur {available} freie Buckets verfügbar, aber {requested} Plants gewählt!'
```

### MEDIUM PRIORITY: Detail & List Screens (81 strings)

#### plant_detail_screen.dart (16 strings)
#### grow_detail_screen.dart (9 strings)
#### rdwc_system_detail_screen.dart (11 strings)
#### room_detail_screen.dart (5 strings)
#### harvest_detail_screen.dart (6 strings)

### LOW PRIORITY: Other Screens (54 strings)

## Implementation Steps

### Phase 1: Add ALL translations to translations.dart

Add translations in logical groups:

```dart
// ✅ AUDIT FIX: i18n extraction - Add Plant Screen
'plant_form_title': 'Neue Pflanze',
'plant_form_section_basic': 'Grundinformationen',
// ... (all strings from above list)

// ✅ AUDIT FIX: i18n extraction - Edit Plant Screen
'edit_plant_title': 'Pflanze bearbeiten',
// ...

// ✅ AUDIT FIX: i18n extraction - Add Log Screen
'add_log_title': 'Log für {plant}',
// ...
```

### Phase 2: Update Each Screen File

For each screen, follow this pattern:

#### 1. Import translations helper
```dart
import '../utils/translations.dart';
```

#### 2. Add translations variable
```dart
late final AppTranslations _t;
```

#### 3. Initialize in initState()
```dart
@override
void initState() {
  super.initState();
  _t = AppTranslations(Localizations.localeOf(context).languageCode);
}
```

#### 4. Replace all hardcoded strings
```dart
// Before:
Text('Neue Pflanze')

// After:
Text(_t['plant_form_title'])
```

```dart
// Before:
labelText: 'Name *'

// After:
labelText: _t['plant_form_name_label']
```

```dart
// Before:
return 'Bitte Namen eingeben';

// After:
return _t['plant_form_name_error'];
```

### Phase 3: Testing

After each file:
1. Hot reload the app
2. Test all forms and dialogs
3. Switch language in settings
4. Verify all translations appear correctly

## Translation Key Naming Convention

Use hierarchical, descriptive keys:

**Format:** `[screen]_[element]_[type]`

**Examples:**
- Screen titles: `add_plant_title`, `edit_log_title`
- Section headers: `plant_form_section_basic`, `log_form_section_water`
- Form labels: `plant_form_name_label`, `log_form_ph_in_label`
- Form hints: `plant_form_name_hint`, `log_form_quantity_hint`
- Helper text: `plant_form_grow_helper`, `log_form_bucket_helper`
- Error messages: `plant_form_name_error`, `error_buckets_full`
- Button labels: `button_save_plant`, `button_create_grow`
- Dialog titles: `dialog_create_grow_title`, `dialog_delete_plant_title`
- Dialog content: `dialog_delete_plant_message`, `dialog_warning_message`
- Info messages: `info_rdwc_system_size`, `info_automatic_bucket_distribution`

## Complete Example: add_plant_screen.dart

### Before (with hardcoded strings):
```dart
Text('Neue Pflanze')
labelText: 'Name *'
hintText: 'z.B. Wedding Cake'
return 'Bitte Namen eingeben';
```

### After (with translations):
```dart
Text(_t['plant_form_title'])
labelText: _t['plant_form_name_label']
hintText: _t['plant_form_name_hint']
return _t['plant_form_name_error'];
```

## Files Status

### ✅ Completed
- translations.dart - Added 22 validation message keys

### 📝 Needs Translation Keys Added
- ALL remaining files (add keys first, then update files)

### 🔄 Needs Source Updates
- add_plant_screen.dart (16 strings)
- edit_plant_screen.dart (30 strings)
- add_log_screen.dart (35 strings)
- edit_log_screen.dart (23 strings)
- (... 31 more files)

## Estimated Effort

- **Adding all translation keys:** 2-3 hours
- **Updating all source files:** 4-6 hours
- **Testing:** 2 hours
- **Total:** 8-11 hours of focused work

## Next Steps

1. ✅ **DONE:** Add validation message translations
2. **TODO:** Add all ~275 remaining translation keys to translations.dart
3. **TODO:** Update each source file systematically (start with HIGH priority)
4. **TODO:** Test each file after changes
5. **TODO:** Final QA: Test all screens in both DE and EN

## Notes

- Use comment `// ✅ AUDIT FIX: i18n extraction` above each translated block
- Keep translations grouped by screen/feature
- Test frequently - don't wait until all files are done
- Prioritize HIGH priority files first (forms, edit screens)
