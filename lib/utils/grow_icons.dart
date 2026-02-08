import 'package:flutter/widgets.dart';

/// 🌿 Custom Cannabis Growing Icons
///
/// Icon Font generiert für Growlogger9000
class GrowIcons {
  GrowIcons._();

  static const _kFontFam = 'GrowIcons';
  static const String? _kFontPkg = null;

  // Cannabis Plant Icons
  static const IconData cannabis = IconData(
    0xe800,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
  static const IconData seedling = IconData(
    0xe801,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
  static const IconData leaf = IconData(
    0xe802,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );

  // Growing Equipment
  static const IconData growLight = IconData(
    0xe803,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
  static const IconData growTent = IconData(
    0xe804,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
  static const IconData ventilation = IconData(
    0xe805,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );

  // Nutrients & Care
  static const IconData bottle = IconData(
    0xe806,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
  static const IconData dropper = IconData(
    0xe807,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
  static const IconData nutrients = IconData(
    0xe808,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );

  // Harvest
  static const IconData scissors = IconData(
    0xe809,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
  static const IconData jar = IconData(
    0xe810,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
  static const IconData scale = IconData(
    0xe811,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
}

/// Fallback: Unicode Cannabis Symbols
class CannabisSymbols {
  static const String leaf = '🌿';
  static const String seedling = '🌱';
  static const String herb = '🌿';
  static const String sun = '☀️';
  static const String droplet = '💧';
  static const String flask = '⚗️';
  static const String basket = '🧺';
  static const String scissors = '✂️';
}
