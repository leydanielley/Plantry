// =============================================
// GROWLOG - App Settings Model
// =============================================

/// Measurement unit types
enum NutrientUnit { ec, ppm }
enum PpmScale {
  scale500,  // USA Standard (Hanna) - EC × 500
  scale700,  // Europa Standard (Eutech) - EC × 700
  scale640,  // Truncheon - EC × 640
}
enum TemperatureUnit { celsius, fahrenheit }
enum LengthUnit { cm, inch }
enum VolumeUnit { liter, gallon }

class AppSettings {
  final String language;      // 'de' oder 'en'
  final bool isDarkMode;
  final bool isExpertMode;

  // Measurement units
  final NutrientUnit nutrientUnit;
  final PpmScale ppmScale;
  final TemperatureUnit temperatureUnit;
  final LengthUnit lengthUnit;
  final VolumeUnit volumeUnit;

  AppSettings({
    this.language = 'de',
    this.isDarkMode = false,
    this.isExpertMode = false,
    this.nutrientUnit = NutrientUnit.ec,
    this.ppmScale = PpmScale.scale700,  // Europa Standard
    this.temperatureUnit = TemperatureUnit.celsius,
    this.lengthUnit = LengthUnit.cm,
    this.volumeUnit = VolumeUnit.liter,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      language: map['language'] as String? ?? 'de',
      isDarkMode: (map['is_dark_mode'] as int?) == 1,
      isExpertMode: (map['is_expert_mode'] as int?) == 1,
      nutrientUnit: NutrientUnit.values.byName(
        map['nutrient_unit'] as String? ?? 'ec'
      ),
      ppmScale: PpmScale.values.byName(
        map['ppm_scale'] as String? ?? 'scale700'
      ),
      temperatureUnit: TemperatureUnit.values.byName(
        map['temperature_unit'] as String? ?? 'celsius'
      ),
      lengthUnit: LengthUnit.values.byName(
        map['length_unit'] as String? ?? 'cm'
      ),
      volumeUnit: VolumeUnit.values.byName(
        map['volume_unit'] as String? ?? 'liter'
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'language': language,
      'is_dark_mode': isDarkMode ? 1 : 0,
      'is_expert_mode': isExpertMode ? 1 : 0,
      'nutrient_unit': nutrientUnit.name,
      'ppm_scale': ppmScale.name,
      'temperature_unit': temperatureUnit.name,
      'length_unit': lengthUnit.name,
      'volume_unit': volumeUnit.name,
    };
  }

  AppSettings copyWith({
    String? language,
    bool? isDarkMode,
    bool? isExpertMode,
    NutrientUnit? nutrientUnit,
    PpmScale? ppmScale,
    TemperatureUnit? temperatureUnit,
    LengthUnit? lengthUnit,
    VolumeUnit? volumeUnit,
  }) {
    return AppSettings(
      language: language ?? this.language,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isExpertMode: isExpertMode ?? this.isExpertMode,
      nutrientUnit: nutrientUnit ?? this.nutrientUnit,
      ppmScale: ppmScale ?? this.ppmScale,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      lengthUnit: lengthUnit ?? this.lengthUnit,
      volumeUnit: volumeUnit ?? this.volumeUnit,
    );
  }
}

/// Extension for PPM Scale display names
extension PpmScaleExtension on PpmScale {
  // ✅ AUDIT FIX: Extract PPM conversion factor constants
  static const int _conversionFactor500 = 500;
  static const int _conversionFactor700 = 700;
  static const int _conversionFactor640 = 640;

  String get displayName {
    switch (this) {
      case PpmScale.scale500:
        return '$_conversionFactor500 (USA/Hanna)';
      case PpmScale.scale700:
        return '$_conversionFactor700 (EU/Eutech)';
      case PpmScale.scale640:
        return '$_conversionFactor640 (Truncheon)';
    }
  }

  int get conversionFactor {
    switch (this) {
      case PpmScale.scale500:
        return _conversionFactor500;
      case PpmScale.scale700:
        return _conversionFactor700;
      case PpmScale.scale640:
        return _conversionFactor640;
    }
  }

  String get scaleLabel {
    switch (this) {
      case PpmScale.scale500:
        return '$_conversionFactor500';
      case PpmScale.scale700:
        return '$_conversionFactor700';
      case PpmScale.scale640:
        return '$_conversionFactor640';
    }
  }
}
