// =============================================
// GROWLOG - Unit Converter Utility
// =============================================

import '../models/app_settings.dart';

class UnitConverter {
  /// Convert EC to PPM using the specified scale
  /// EC (mS/cm) * scale = PPM
  /// @param ec - EC value in mS/cm
  /// @param scale - PPM scale to use (500, 700, or 640)
  static double ecToPpm(double ec, PpmScale scale) {
    return ec * scale.conversionFactor;
  }

  /// Convert PPM to EC using the specified scale
  /// PPM / scale = EC (mS/cm)
  /// @param ppm - PPM value
  /// @param scale - PPM scale to use (500, 700, or 640)
  static double ppmToEc(double ppm, PpmScale scale) {
    return ppm / scale.conversionFactor;
  }

  /// Format nutrient value based on user preference
  /// @param value - The EC value stored in database (always in EC/mS/cm)
  /// @param unit - User's preferred unit (EC or PPM)
  /// @param scale - PPM scale to use when converting (500, 700, or 640)
  /// @param decimals - Number of decimal places (default: 1)
  /// @param showScale - Whether to show the scale in PPM display (default: true)
  static String formatNutrient(
    double value,
    NutrientUnit unit,
    PpmScale scale, {
    int decimals = 1,
    bool showScale = true,
  }) {
    if (unit == NutrientUnit.ppm) {
      final ppm = ecToPpm(value, scale);
      if (showScale) {
        return '${ppm.toStringAsFixed(0)} PPM (${scale.scaleLabel})';
      }
      return '${ppm.toStringAsFixed(0)} PPM';
    }
    return '${value.toStringAsFixed(decimals)} EC';
  }

  /// Convert Celsius to Fahrenheit
  /// F = (C × 9/5) + 32
  static double celsiusToFahrenheit(double celsius) {
    return (celsius * 9 / 5) + 32;
  }

  /// Convert Fahrenheit to Celsius
  /// C = (F - 32) × 5/9
  static double fahrenheitToCelsius(double fahrenheit) {
    return (fahrenheit - 32) * 5 / 9;
  }

  /// Format temperature based on user preference
  /// @param value - The temperature value stored in database (always in Celsius)
  /// @param unit - User's preferred unit
  /// @param decimals - Number of decimal places (default: 1)
  static String formatTemperature(double value, TemperatureUnit unit, {int decimals = 1}) {
    if (unit == TemperatureUnit.fahrenheit) {
      final fahrenheit = celsiusToFahrenheit(value);
      return '${fahrenheit.toStringAsFixed(decimals)}°F';
    }
    return '${value.toStringAsFixed(decimals)}°C';
  }

  /// Convert centimeters to inches
  /// 1 cm = 0.393701 inches
  static double cmToInch(double cm) {
    return cm * 0.393701;
  }

  /// Convert inches to centimeters
  /// 1 inch = 2.54 cm
  static double inchToCm(double inch) {
    return inch * 2.54;
  }

  /// Format length based on user preference
  /// @param value - The length value stored in database (always in cm)
  /// @param unit - User's preferred unit
  /// @param decimals - Number of decimal places (default: 1)
  static String formatLength(double value, LengthUnit unit, {int decimals = 1}) {
    if (unit == LengthUnit.inch) {
      final inch = cmToInch(value);
      return '${inch.toStringAsFixed(decimals)} in';
    }
    return '${value.toStringAsFixed(decimals)} cm';
  }

  /// Convert liters to gallons (US)
  /// 1 liter = 0.264172 gallons
  static double literToGallon(double liter) {
    return liter * 0.264172;
  }

  /// Convert gallons (US) to liters
  /// 1 gallon = 3.78541 liters
  static double gallonToLiter(double gallon) {
    return gallon * 3.78541;
  }

  /// Format volume based on user preference
  /// @param value - The volume value stored in database (always in liters)
  /// @param unit - User's preferred unit
  /// @param decimals - Number of decimal places (default: 1)
  static String formatVolume(double value, VolumeUnit unit, {int decimals = 1}) {
    if (unit == VolumeUnit.gallon) {
      final gallon = literToGallon(value);
      return '${gallon.toStringAsFixed(decimals)} gal';
    }
    return '${value.toStringAsFixed(decimals)} L';
  }

  /// Get unit suffix for nutrient display
  static String getNutrientUnitSuffix(NutrientUnit unit, {PpmScale? scale, bool showScale = false}) {
    if (unit == NutrientUnit.ppm && scale != null && showScale) {
      return 'PPM (${scale.scaleLabel})';
    }
    return unit == NutrientUnit.ppm ? 'PPM' : 'mS/cm';
  }

  /// Get unit suffix for temperature display
  static String getTemperatureUnitSuffix(TemperatureUnit unit) {
    return unit == TemperatureUnit.fahrenheit ? '°F' : '°C';
  }

  /// Get unit suffix for length display
  static String getLengthUnitSuffix(LengthUnit unit) {
    return unit == LengthUnit.inch ? 'in' : 'cm';
  }

  /// Get unit suffix for volume display
  static String getVolumeUnitSuffix(VolumeUnit unit) {
    return unit == VolumeUnit.gallon ? 'gal' : 'L';
  }
}
