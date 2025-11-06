# Expert Mode - Implementation Guide

## Overview
Expert Mode is a new setting that allows users to access advanced features and options throughout the Plantry app. It's disabled by default and can be toggled in the Settings screen.

## What Was Added

### 1. **Settings Model** (`lib/models/app_settings.dart`)
- Added `isExpertMode` boolean field (default: `false`)
- Updated `fromMap()`, `toMap()`, and `copyWith()` methods

### 2. **Settings Repository** (`lib/repositories/settings_repository.dart`)
- Added `setExpertMode()` method to persist the setting
- Updated `getSettings()` and `saveSettings()` to handle expert mode

### 3. **Settings Screen** (`lib/screens/settings_screen.dart`)
- Added Expert Mode toggle switch with icon
- Added `_toggleExpertMode()` method
- Expert mode status shown in Debug Info section

### 4. **Translations** (`lib/utils/translations.dart`)
Added translations for both German and English:
- `expert_mode`: "Expertenmodus" / "Expert Mode"
- `expert_mode_desc`: "Erweiterte Funktionen und Optionen anzeigen" / "Show advanced features and options"
- `expert_mode_enabled`: "Expertenmodus aktiviert 🔧" / "Expert Mode enabled 🔧"
- `expert_mode_disabled`: "Expertenmodus deaktiviert" / "Expert Mode disabled"

### 5. **Main App** (`lib/main.dart`)
- Added `settings` getter to `GrowLogAppState` for easy access

## How to Use Expert Mode in Your Code

### Method 1: Access from Context (Recommended)
```dart
// In any screen or widget with BuildContext
final appState = GrowLogApp.of(context);
if (appState != null && appState.settings.isExpertMode) {
  // Show advanced feature
  return AdvancedWidget();
} else {
  // Show normal feature
  return NormalWidget();
}
```

### Method 2: Load Settings Directly
```dart
// If you need to check expert mode without context
final settings = await SettingsRepository().getSettings();
if (settings.isExpertMode) {
  // Show expert feature
}
```

### Example Use Cases

#### 1. Conditional UI Elements
```dart
// Show extra button only in expert mode
if (GrowLogApp.of(context)?.settings.isExpertMode ?? false) {
  ElevatedButton(
    onPressed: _advancedFunction,
    child: Text('Advanced Settings'),
  ),
}
```

#### 2. Menu Items
```dart
// Add expert menu items
PopupMenuButton(
  itemBuilder: (context) {
    final isExpert = GrowLogApp.of(context)?.settings.isExpertMode ?? false;

    return [
      PopupMenuItem(child: Text('Normal Option')),
      if (isExpert)
        PopupMenuItem(child: Text('Expert Option')),
      if (isExpert)
        PopupMenuItem(child: Text('Debug Data')),
    ];
  },
)
```

#### 3. Advanced Settings Sections
```dart
Column(
  children: [
    // Always visible
    BasicSettingsWidget(),

    // Only visible in expert mode
    if (GrowLogApp.of(context)?.settings.isExpertMode ?? false)
      AdvancedSettingsWidget(),
  ],
)
```

#### 4. Feature Flags
```dart
// Use expert mode as a feature flag
final canExport = GrowLogApp.of(context)?.settings.isExpertMode ?? false;

if (canExport) {
  IconButton(
    icon: Icon(Icons.download),
    onPressed: _exportAdvancedData,
  ),
}
```

## Best Practices

1. **Always provide null safety**: Use `?? false` when checking expert mode
2. **Don't hide critical features**: Only use expert mode for truly advanced features
3. **Document expert features**: Add tooltips or help text for expert-only features
4. **Graceful degradation**: App should work perfectly with expert mode OFF
5. **User education**: Consider adding info dialogs explaining expert features

## Ideas for Expert Mode Features

Here are some suggestions for features that could be gated behind Expert Mode:

- **Advanced Statistics**: Detailed growth analytics, charts, and reports
- **Bulk Operations**: Batch edit/delete multiple plants
- **Import/Export Options**: CSV exports, advanced backup formats
- **Developer Tools**: Database inspection, debug logs viewer
- **Advanced Filters**: Complex search queries, saved filter presets
- **Custom Fields**: User-defined metadata for plants
- **API Access**: Export data to external services
- **Experimental Features**: Beta features not ready for all users
- **Hardware Controls**: Direct hardware integration settings
- **Formula Editor**: Custom nutrient calculation formulas

## Testing

To test Expert Mode:
1. Run the app: `flutter run`
2. Navigate to Settings screen
3. Find "Expertenmodus" / "Expert Mode" section
4. Toggle the switch ON
5. Verify success message appears
6. Check Debug Info section shows "Expert Mode: Enabled"
7. Navigate through app to see expert features

## Future Enhancements

Consider adding:
- Confirmation dialog when enabling expert mode (warning about complexity)
- Password/PIN protection for expert mode
- Different expert levels (Basic, Advanced, Developer)
- Usage analytics to see which expert features are most used
