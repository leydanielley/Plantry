// =============================================
// GROWLOG - DBF Import Service (HydroBuddy Format)
// =============================================

import 'dart:io';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/services/raw_dbf_parser.dart';

class DbfImportService {
  /// Parse HydroBuddy DBF file and return list of Fertilizers
  static Future<List<Fertilizer>> importFromDbf(File file) async {
    try {
      AppLogger.info(
        'DbfImportService',
        'Starting DBF import from: ${file.path}',
      );

      // Use our custom raw parser instead of the buggy dbf_reader package
      final records = await RawDbfParser.parse(file);

      AppLogger.info(
        'DbfImportService',
        'Found ${records.length} records in DBF',
      );

      final List<Fertilizer> fertilizers = [];
      int skippedEmpty = 0;
      int skippedDisabled = 0;

      for (int i = 0; i < records.length; i++) {
        try {
          final record = records[i];

          // Debug: Log first 10 records to see structure
          if (i < 10) {
            AppLogger.debug(
              'DbfImportService',
              'Record $i: NAME="${record['NAME']}" FORMULA="${record['FORMULA']}"',
            );
          }

          final fertilizer = _parseFertilizerFromRecord(record);

          if (fertilizer != null) {
            fertilizers.add(fertilizer);
            if (i < 5) {
              AppLogger.debug(
                'DbfImportService',
                'Parsed: ${fertilizer.name} | ppmValue: ${fertilizer.ppmValue}',
              );
            }
          } else {
            // Track why it was skipped
            final name = record['FORMULA'] ?? '';
            final formula = record['NAME'] ?? '';
            if (name.isEmpty) {
              skippedEmpty++;
            } else if (name.startsWith('*') || formula.startsWith('*')) {
              skippedDisabled++;
            }
          }
        } catch (e) {
          AppLogger.error(
            'DbfImportService',
            'Error parsing record ${i + 1}',
            e,
          );
          // Continue with next record
        }
      }

      AppLogger.info(
        'DbfImportService',
        'Successfully parsed ${fertilizers.length} fertilizers',
      );
      AppLogger.info(
        'DbfImportService',
        'Skipped: $skippedEmpty empty, $skippedDisabled disabled',
      );
      return fertilizers;
    } catch (e) {
      AppLogger.error('DbfImportService', 'Error reading DBF file', e);
      rethrow;
    }
  }

  /// Parse a single DBF record into a Fertilizer object
  static Fertilizer? _parseFertilizerFromRecord(Map<String, String> record) {
    try {
      // HydroBuddy DBF structure (confirmed from source code):
      // - NAME field = Substance name (e.g. "Potassium Sulfate")
      // - FORMULA field = Chemical formula (e.g. "K2SO4")

      final readableName = record['NAME'] ?? '';
      final chemicalFormula = record['FORMULA'] ?? '';

      // Build NPK string from N+P+K values (parse first for logging)
      final nNo3 = _parseDouble(record['N (NO3-)']) ?? 0.0;
      final nNh4 = _parseDouble(record['N (NH4+)']) ?? 0.0;
      final totalN = nNo3 + nNh4;
      final p = _parseDouble(record['P']) ?? 0.0;
      final k = _parseDouble(record['K']) ?? 0.0;
      final mg = _parseDouble(record['MG']) ?? 0.0;
      final ca = _parseDouble(record['CA']) ?? 0.0;
      final s = _parseDouble(record['S']) ?? 0.0;
      final nutrientCount = [
        nNo3,
        nNh4,
        p,
        k,
        mg,
        ca,
        s,
      ].where((v) => v > 0).length;

      // Debug: Log nutrient data for ALL entries
      // AppLogger.debug('DbfImportService', '  -> "$readableName": NPK=$totalN-$p-$k, nutrients=$nutrientCount');

      // Skip if empty or starts with * (disabled in HydroBuddy)
      if (readableName.isEmpty) {
        AppLogger.debug(
          'DbfImportService',
          '  -> SKIP: Empty name (formula="$chemicalFormula")',
        );
        return null; // Skip empty names
      }

      if (readableName.startsWith('*') || chemicalFormula.startsWith('*')) {
        AppLogger.debug(
          'DbfImportService',
          '  -> SKIP: Disabled "$readableName"',
        );
        return null; // Skip disabled substances
      }

      // Create NPK string (e.g. "13-0-38")
      final npkString = totalN > 0 || p > 0 || k > 0
          ? '${totalN.toStringAsFixed(0)}-${p.toStringAsFixed(0)}-${k.toStringAsFixed(0)}'
          : null;

      // Determine type
      String? type;
      final isLiquid = _parseBool(record['ISLIQUID']);
      if (isLiquid == true) {
        type = 'Liquid';
      } else if (totalN > 0 || p > 0 || k > 0) {
        type = 'Fertilizer';
      } else {
        type = 'Supplement';
      }

      // Calculate ppm value per ml/g
      // Formula: For solids (powder/salt): % × 10 = ppm per gram
      //          For liquids: % × density × 10 = ppm per ml
      final density = _parseDouble(record['DENSITY']) ?? 1.0;
      final ppmPerUnit = _calculateTotalPpm(
        nNo3: nNo3,
        nNh4: nNh4,
        p: p,
        k: k,
        mg: mg,
        ca: ca,
        s: s,
        isLiquid: isLiquid ?? false,
        density: density,
      );

      // Debug logging for nutrient values
      AppLogger.debug(
        'DbfImportService',
        '$readableName: N=$totalN P=$p K=$k Mg=$mg Ca=$ca S=$s | nutrients=$nutrientCount | ppm=$ppmPerUnit',
      );

      return Fertilizer(
        name: readableName, // Use the readable name from FORMULA field
        brand: 'HydroBuddy', // Mark as imported from HydroBuddy
        npk: npkString,
        type: type,
        formula: chemicalFormula, // Use the chemical formula from NAME field
        source: record['SOURCE'],
        purity: _parseDouble(record['PURITY']),
        isLiquid: isLiquid,
        density: _parseDouble(record['DENSITY']),
        ppmValue: ppmPerUnit > 0
            ? ppmPerUnit
            : null, // Auto-calculated ppm per ml/g
        // Macronutrients
        nNO3: nNo3 > 0 ? nNo3 : null,
        nNH4: nNh4 > 0 ? nNh4 : null,
        p: p > 0 ? p : null,
        k: k > 0 ? k : null,
        mg: _parseDouble(record['MG']),
        ca: _parseDouble(record['CA']),
        s: _parseDouble(record['S']),
        // Micronutrients
        b: _parseDouble(record['B']),
        fe: _parseDouble(record['FE']),
        zn: _parseDouble(record['ZN']),
        cu: _parseDouble(record['CU']),
        mn: _parseDouble(record['MN']),
        mo: _parseDouble(record['MO']),
        na: _parseDouble(record['NA']),
        si: _parseDouble(record['SI']),
        cl: _parseDouble(record['CL']),
      );
    } catch (e) {
      AppLogger.error('DbfImportService', 'Error parsing fertilizer record', e);
      return null;
    }
  }

  /// Helper: Parse double from string
  static double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  /// Helper: Parse boolean from string
  static bool? _parseBool(String? value) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase().trim();
    if (lower == 'true' || lower == '1' || lower == 'yes' || lower == 't') {
      return true;
    }
    if (lower == 'false' || lower == '0' || lower == 'no' || lower == 'f') {
      return false;
    }
    return null;
  }

  /// Calculate total ppm contribution per ml (liquid) or per gram (solid)
  ///
  /// Formula:
  /// - Solids: percentage × 10 = ppm per gram
  /// - Liquids: percentage × density × 10 = ppm per ml
  ///
  /// Sums up all major nutrients (N, P, K, Mg, Ca, S) to give total nutrient load
  static double _calculateTotalPpm({
    required double nNo3,
    required double nNh4,
    required double p,
    required double k,
    required double mg,
    required double ca,
    required double s,
    required bool isLiquid,
    required double density,
  }) {
    final totalN = nNo3 + nNh4;

    // Sum of all major nutrients as percentages
    final totalPercentage = totalN + p + k + mg + ca + s;

    if (totalPercentage <= 0) return 0;

    // Convert to ppm per unit
    if (isLiquid) {
      // ppm per ml = percentage × density × 10
      return totalPercentage * density * 10;
    } else {
      // ppm per gram = percentage × 10
      return totalPercentage * 10;
    }
  }
}
