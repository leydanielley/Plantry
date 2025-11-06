# Measurement Units Feature - Implementation Guide

## Overview
The Measurement Units feature allows users to customize their preferred units for displaying measurements throughout the GrowLog app. This makes the app more user-friendly for international users with different measurement preferences.

## What Was Added

### 1. **Unit Types Supported**
Four categories of measurement units:
- **Nutrient Measurement**: EC (mS/cm) ↔ PPM (Parts Per Million)
- **Temperature**: Celsius (°C) ↔ Fahrenheit (°F)
- **Length**: Centimeters (cm) ↔ Inches (in)
- **Volume**: Liters (L) ↔ Gallons (gal)

### 2. **Files Modified**

#### Models (`lib/models/app_settings.dart`)
- Added enums: `NutrientUnit`, `TemperatureUnit`, `LengthUnit`, `VolumeUnit`
- Added fields to `AppSettings` class for each unit preference
- Updated `fromMap()`, `toMap()`, and `copyWith()` methods
- **Default values**: EC, Celsius, cm, Liters

#### Repository (`lib/repositories/settings_repository.dart`)
- Added keys for storing unit preferences in SharedPreferences
- Added individual setter methods for each unit type
- Updated `getSettings()` to load unit preferences
- Updated `saveSettings()` to persist all unit preferences

#### Translations (`lib/utils/translations.dart`)
- Added German and English translations for:
  - Measurement Units section header and description
  - Each unit type label
  - Individual unit option labels

#### Settings Screen (`lib/screens/settings_screen.dart`)
- Added toggle methods for each unit type
- Added new "Measurement Units" section with SegmentedButtons
- Each unit type has its own ListTile with appropriate icon
- Real-time switching between units

#### Utility (`lib/utils/unit_converter.dart`) - **NEW FILE**
- Conversion functions for all unit types
- Format functions for displaying values with proper units
- Suffix helper functions for unit labels

### 3. **Data Storage**
All measurements are **stored in the database in metric/standard units**:
- EC values stored as **EC (mS/cm)**
- Temperature stored as **Celsius**
- Length stored as **centimeters**
- Volume stored as **liters**

The conversion happens **only during display**, ensuring data consistency.

## How to Use in Your Code

### Accessing User Preferences

```dart
// In any screen with BuildContext
final appState = GrowLogApp.of(context);
final settings = appState?.settings;

if (settings != null) {
  final nutrientUnit = settings.nutrientUnit;
  final tempUnit = settings.temperatureUnit;
  final lengthUnit = settings.lengthUnit;
  final volumeUnit = settings.volumeUnit;
}
```

### Converting and Displaying Values

```dart
import '../utils/unit_converter.dart';
import '../models/app_settings.dart';

// Example: Display EC/PPM value
double ecValue = 1.8; // From database (always in EC)
String formatted = UnitConverter.formatNutrient(
  ecValue,
  settings.nutrientUnit,
  decimals: 1,
);
// Output: "1.8 EC" or "900 PPM" depending on user preference

// Example: Display temperature
double tempValue = 24.0; // From database (always in Celsius)
String formatted = UnitConverter.formatTemperature(
  tempValue,
  settings.temperatureUnit,
  decimals: 1,
);
// Output: "24.0°C" or "75.2°F" depending on user preference

// Example: Display volume
double volumeValue = 5.0; // From database (always in liters)
String formatted = UnitConverter.formatVolume(
  volumeValue,
  settings.volumeUnit,
  decimals: 1,
);
// Output: "5.0 L" or "1.3 gal" depending on user preference

// Example: Display length
double heightValue = 45.0; // From database (always in cm)
String formatted = UnitConverter.formatLength(
  heightValue,
  settings.lengthUnit,
  decimals: 1,
);
// Output: "45.0 cm" or "17.7 in" depending on user preference
```

### Manual Conversion

```dart
// Convert EC to PPM (if needed)
double ppm = UnitConverter.ecToPpm(1.8); // Returns 900

// Convert PPM to EC
double ec = UnitConverter.ppmToEc(900); // Returns 1.8

// Convert Celsius to Fahrenheit
double f = UnitConverter.celsiusToFahrenheit(24.0); // Returns 75.2

// Convert liters to gallons
double gal = UnitConverter.literToGallon(5.0); // Returns 1.32

// Convert cm to inches
double inch = UnitConverter.cmToInch(45.0); // Returns 17.7
```

## Conversion Formulas

### EC ↔ PPM
- **EC to PPM**: `PPM = EC × 500` (using 500 scale, common for hydroponics)
- **PPM to EC**: `EC = PPM / 500`

### Temperature
- **Celsius to Fahrenheit**: `°F = (°C × 9/5) + 32`
- **Fahrenheit to Celsius**: `°C = (°F - 32) × 5/9`

### Length
- **cm to inches**: `inch = cm × 0.393701`
- **inches to cm**: `cm = inch × 2.54`

### Volume
- **Liters to Gallons (US)**: `gal = L × 0.264172`
- **Gallons to Liters**: `L = gal × 3.78541`

## Where to Apply Unit Conversions

You should apply unit conversions in these screens/widgets:

1. **Plant Log Screen** - Display EC, temperature, water amount
2. **Plant Details Screen** - Display container sizes, system sizes
3. **Log Entry Form** - Input fields with unit labels
4. **Statistics/Charts** - Axis labels and data points
5. **Harvest Records** - Yield amounts
6. **Export/Reports** - All measurement values

## Example: Updating Plant Log Display

```dart
// Before (showing raw database values)
Text('EC: ${log.ecIn} mS/cm')
Text('Temperature: ${log.temperature}°C')
Text('Water: ${log.waterAmount} L')

// After (respecting user preferences)
final settings = GrowLogApp.of(context)?.settings;
Text(UnitConverter.formatNutrient(log.ecIn ?? 0, settings!.nutrientUnit))
Text(UnitConverter.formatTemperature(log.temperature ?? 0, settings.temperatureUnit))
Text(UnitConverter.formatVolume(log.waterAmount ?? 0, settings.volumeUnit))
```

## Testing

To test the feature:
1. Run the app: `flutter run`
2. Navigate to Settings screen
3. Scroll to "Measurement Units" section
4. Toggle between different units (EC/PPM, °C/°F, cm/inch, L/gal)
5. Navigate to screens that display measurements
6. Verify values are converted correctly

## Future Enhancements

Consider adding:
- **More PPM scales**: 500 (default), 640, 700 scales
- **Imperial gallons**: In addition to US gallons
- **Height in feet**: For very tall plants
- **Weight units**: kg/lbs for harvest tracking
- **Pressure units**: For CO2 systems (bar/psi)
- **Light units**: Different scales for light intensity

## Notes

- All database values remain in metric/standard units
- Conversion only happens during display
- Settings persist across app restarts
- Default units are metric (EC, °C, cm, L)
- Unit preferences are user-specific (no multi-user support yet)
