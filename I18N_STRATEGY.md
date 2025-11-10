# 🌍 Internationalization (i18n) Strategy

## Current Status

**Translations File:** `lib/utils/translations.dart` (824 lines)
**Estimated Hardcoded Strings:** ~500 across 40+ screens
**Current Coverage:** ~60% (critical UI strings translated)

---

## ✅ Already Translated (Good Examples)

### Navigation & Common Actions
- ✅ All navigation items (Dashboard, Pflanzen, Grows, etc.)
- ✅ Common actions (Speichern, Löschen, Bearbeiten, Abbrechen)
- ✅ Phases (Keimling, Wachstum, Blüte, Ernte)
- ✅ Settings & Notifications
- ✅ Error messages & validation

### Well-Translated Screens
- ✅ `dashboard_screen.dart` - Uses `_t['welcome']`, `_t['overview']`
- ✅ `plants_screen.dart` - Uses `_t['plants']`, `_t['add_plant']`
- ✅ `settings_screen.dart` - Fully translated

---

## ❌ Common Hardcoded String Patterns

### 1. Button Labels
```dart
// ❌ BAD
ElevatedButton(
  child: Text('Save Changes'),  // Hardcoded English
)

// ✅ GOOD
ElevatedButton(
  child: Text(_t['save']),  // Uses translation
)
```

### 2. Dialog Messages
```dart
// ❌ BAD
AlertDialog(
  title: Text('Are you sure?'),
  content: Text('This action cannot be undone'),
)

// ✅ GOOD
AlertDialog(
  title: Text(_t['confirm_delete_title']),
  content: Text(_t['confirm_delete_message']),
)
```

### 3. Helper Text & Hints
```dart
// ❌ BAD
TextFormField(
  decoration: InputDecoration(
    labelText: 'Enter your name',
    hintText: 'John Doe',
  ),
)

// ✅ GOOD
TextFormField(
  decoration: InputDecoration(
    labelText: _t['name_label'],
    hintText: _t['name_hint'],
  ),
)
```

### 4. Error Messages
```dart
// ❌ BAD
throw Exception('Failed to load data');

// ✅ GOOD
throw Exception(_t['error_loading_data']);
```

---

## 🛠️ Migration Strategy

### Phase 1: Critical UI Strings (HIGH PRIORITY)
**Target:** Error messages, confirmation dialogs, validation messages
**Effort:** 2-3 hours
**Impact:** User-facing errors properly localized

**Example Files to Migrate:**
- `lib/utils/app_messages.dart` - Error/success messages
- `lib/utils/validators.dart` - Validation error messages
- All `AlertDialog` content across screens

### Phase 2: Screen Titles & Labels (MEDIUM PRIORITY)
**Target:** Screen titles, section headers, button labels
**Effort:** 3-4 hours
**Impact:** Consistent terminology across app

**Example Files to Migrate:**
- `lib/screens/add_*.dart` - Form labels
- `lib/screens/edit_*.dart` - Form labels
- All `AppBar` titles

### Phase 3: Helper Text & Descriptions (LOW PRIORITY)
**Target:** Placeholder text, help tooltips, descriptions
**Effort:** 2-3 hours
**Impact:** Better UX for non-German users

---

## 📋 Migration Checklist

### Step 1: Find Hardcoded Strings
```bash
# Find screens with hardcoded strings
grep -r "Text('.*')" lib/screens/*.dart | grep -v "_t\[" | wc -l

# Find specific patterns
grep -r "AlertDialog" lib/screens/*.dart | grep -A5 "title: Text"
```

### Step 2: Add to translations.dart
```dart
'de': {
  // ... existing translations

  // Add new keys (use descriptive names)
  'confirm_delete_title': 'Wirklich löschen?',
  'confirm_delete_message': 'Diese Aktion kann nicht rückgängig gemacht werden',
  'error_loading_data': 'Fehler beim Laden der Daten',
},

'en': {
  // Add English translations
  'confirm_delete_title': 'Delete confirmation',
  'confirm_delete_message': 'This action cannot be undone',
  'error_loading_data': 'Failed to load data',
},
```

### Step 3: Update Screen Code
```dart
// Before
AlertDialog(
  title: Text('Wirklich löschen?'),
  content: Text('Diese Aktion kann nicht rückgängig gemacht werden'),
)

// After
AlertDialog(
  title: Text(_t['confirm_delete_title']),
  content: Text(_t['confirm_delete_message']),
)
```

### Step 4: Verify
```bash
# Ensure _t is defined in widget
# Check that translation key exists
flutter analyze
flutter test
```

---

## 🎯 Best Practices

### 1. Naming Conventions
```dart
// ✅ GOOD - Descriptive, hierarchical
_t['plant_form_name_label']
_t['plant_form_name_hint']
_t['plant_form_name_error_empty']

// ❌ BAD - Too generic
_t['name']
_t['error']
_t['message']
```

### 2. Pluralization
```dart
// Use separate keys for singular/plural
'plant': 'Pflanze',
'plants': 'Pflanzen',
'plant_count': '{count} Pflanzen',  // With placeholder
```

### 3. Dynamic Content
```dart
// Use string interpolation for dynamic content
_t['greeting'].replaceAll('{name}', userName)

// Translation:
'greeting': 'Willkommen, {name}!'
```

### 4. Reusability
```dart
// Create reusable translations for common phrases
'required': 'Pflichtfeld',
'optional': 'Optional',
'no_data': 'Keine Daten verfügbar',
'loading': 'Lädt...',
```

---

## 🚀 Quick Wins (15 minutes each)

### 1. Migrate app_messages.dart
**File:** `lib/utils/app_messages.dart`
**Strings:** ~20 hardcoded error/success messages
**Impact:** All error messages localized

### 2. Migrate validators.dart
**File:** `lib/utils/validators.dart`
**Strings:** ~15 validation error messages
**Impact:** Form validation properly localized

### 3. Migrate Empty States
**Files:** All `_buildEmptyState()` methods
**Strings:** ~20 (2 per screen × 10 screens)
**Impact:** Consistent empty state messages

---

## 📊 Estimated Effort

| Task | Strings | Effort | Priority |
|------|---------|--------|----------|
| app_messages.dart | ~20 | 15 min | HIGH |
| validators.dart | ~15 | 15 min | HIGH |
| Empty states | ~20 | 20 min | MEDIUM |
| AlertDialogs | ~50 | 1 hour | HIGH |
| Form labels | ~100 | 2 hours | MEDIUM |
| Helper text | ~150 | 2 hours | LOW |
| Descriptions | ~145 | 2 hours | LOW |
| **TOTAL** | **~500** | **8 hours** | - |

---

## 🔧 Tooling (Optional Enhancement)

### Create i18n Helper Script
```dart
// tools/extract_strings.dart
// Automatically finds hardcoded strings and suggests translations
void main() {
  final files = Directory('lib/screens').listSync();
  for (var file in files) {
    // Find Text('...') patterns
    // Suggest translation keys
    // Generate translation file entries
  }
}
```

---

## ✅ Phase 3 Completion Note

**Status:** Strategy documented, ready for implementation
**Next Steps:**
1. Start with HIGH priority tasks (app_messages, validators)
2. Migrate in small batches (1-2 files at a time)
3. Test after each batch

**Recommendation:** Tackle this incrementally over next sprint
- Day 1: app_messages.dart + validators.dart (30 min)
- Day 2: AlertDialogs (1 hour)
- Day 3: Form labels (2 hours)
- Day 4: Remaining strings (4 hours)

---

**Created:** 2025-01-10
**By:** Claude Code (Sonnet 4.5)
**Status:** Strategy documented, ready for systematic migration
