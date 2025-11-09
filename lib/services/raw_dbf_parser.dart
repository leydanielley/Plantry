// =============================================
// GROWLOG - Raw DBF Parser (Manual Binary Reading)
// =============================================

import 'dart:io';
import 'dart:typed_data';
import '../utils/app_logger.dart';

class RawDbfParser {
  /// Parse DBF file manually by reading bytes
  static Future<List<Map<String, String>>> parse(File file) async {
    try {
      final bytes = await file.readAsBytes();
      AppLogger.info('RawDbfParser', 'Read ${bytes.length} bytes from DBF');

      // Read basic header info
      final recordCount = ByteData.view(bytes.buffer).getUint32(4, Endian.little);
      final headerLength = ByteData.view(bytes.buffer).getUint16(8, Endian.little);
      final recordLength = ByteData.view(bytes.buffer).getUint16(10, Endian.little);

      AppLogger.info('RawDbfParser', 'Record count: $recordCount');
      AppLogger.info('RawDbfParser', 'Record length: $recordLength');
      AppLogger.info('RawDbfParser', 'Header length: $headerLength');

      // Debug: Show first record marker and first 40 bytes of first record
      if (headerLength < bytes.length) {
        final firstRecordMarker = bytes[headerLength];
        AppLogger.debug('RawDbfParser', 'First record marker at $headerLength: 0x${firstRecordMarker.toRadixString(16).padLeft(2, '0')}');
        if (headerLength + 40 <= bytes.length) {
          final preview = String.fromCharCodes(bytes.sublist(headerLength + 1, headerLength + 41));
          AppLogger.debug('RawDbfParser', 'First 40 bytes of data: "$preview"');
        }
      }

      // Use hardcoded HydroBuddy field structure
      // Dynamic header parsing doesn't work for this proprietary DBF format
      final fields = _getHydroBuddyFields();
      AppLogger.info('RawDbfParser', 'Using hardcoded HydroBuddy structure (${fields.length} fields)');

      // Calculate total field size for validation
      int totalFieldSize = fields.fold(0, (sum, field) => sum + field.length);
      AppLogger.debug('RawDbfParser', 'Total field size: $totalFieldSize bytes (record size: ${recordLength - 1} bytes)');

      for (int i = 0; i < 5 && i < fields.length; i++) {
        AppLogger.debug('RawDbfParser', 'Field $i: ${fields[i].name} (${fields[i].type}, len=${fields[i].length})');
      }

      // Read records
      final records = <Map<String, String>>[];
      int offset = headerLength;

      for (int i = 0; i < recordCount; i++) {
        if (offset >= bytes.length) break;

        // Check for deleted record marker (0x2A = *)
        final deleteFlag = bytes[offset];
        if (deleteFlag == 0x2A) {
          offset += recordLength;
          continue;
        }

        // Skip record marker (0x20 = space for active records, 0x0D = terminator)
        if (deleteFlag == 0x0D) break; // End of records
        offset++;

        final record = <String, String>{};
        for (final field in fields) {
          if (offset + field.length > bytes.length) break;

          final fieldBytes = bytes.sublist(offset, offset + field.length);
          final value = String.fromCharCodes(fieldBytes).trim();
          record[field.name] = value;
          offset += field.length;
        }

        records.add(record);

        // Log first 3 records for debugging
        if (i < 3) {
          AppLogger.debug('RawDbfParser', 'Record $i: ${record['NAME']}');
        }
      }

      AppLogger.info('RawDbfParser', 'Successfully parsed ${records.length} records');
      return records;
    } catch (e) {
      AppLogger.error('RawDbfParser', 'Error parsing DBF', e);
      rethrow;
    }
  }

  /// Get hardcoded HydroBuddy field structure
  /// Record length is 681 bytes total (680 + 1 byte record marker)
  static List<_DbfField> _getHydroBuddyFields() {
    return [
      _DbfField(name: 'NAME', type: 'C', length: 80, decimals: 0),
      _DbfField(name: 'FORMULA', type: 'C', length: 80, decimals: 0),
      _DbfField(name: 'SOURCE', type: 'C', length: 119, decimals: 0),
      _DbfField(name: 'PURITY', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'N (NO3-)', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'N (NH4+)', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'P', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'K', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'MG', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'CA', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'S', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'B', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'FE', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'ZN', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'MN', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'CU', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'MO', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'NA', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'SI', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'CL', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'ISLIQUID', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'DENSITY', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'COST', type: 'N', length: 19, decimals: 8),
      _DbfField(name: 'CONCTYPE', type: 'C', length: 2, decimals: 0),
    ];
    // Total: 80 + 80 + 119 + (19 × 20) + 2 = 661 bytes (19 bytes padding/reserved)
  }

  static _DbfHeader _parseHeader(Uint8List bytes) {
    // Read header structure
    final recordCount = ByteData.view(bytes.buffer).getUint32(4, Endian.little);
    final headerLength = ByteData.view(bytes.buffer).getUint16(8, Endian.little);
    final recordLength = ByteData.view(bytes.buffer).getUint16(10, Endian.little);

    // Check for DBMS signature at byte 32 (like "DB850US0")
    // If present, field descriptors start at byte 64, otherwise at byte 32
    int fieldDescriptorStart = 32;
    final signature = String.fromCharCodes(bytes.sublist(32, 40));
    if (signature.startsWith('DB')) {
      fieldDescriptorStart = 64;
      AppLogger.debug('RawDbfParser', 'DBMS signature found: $signature, fields start at 64');
    }

    // Parse field descriptors (each is 32 bytes)
    // Field descriptors end with 0x0D terminator
    final fields = <_DbfField>[];
    int offset = fieldDescriptorStart;

    while (offset < headerLength - 1) {
      // Check for field terminator (0x0D)
      if (bytes[offset] == 0x0D) {
        AppLogger.debug('RawDbfParser', 'Found field terminator at offset $offset');
        break;
      }

      // Standard dBase field descriptor structure:
      // Bytes 0-10: Field name (11 bytes, null-terminated)
      final fieldNameBytes = bytes.sublist(offset, offset + 11);
      final fieldName = String.fromCharCodes(
        fieldNameBytes.where((b) => b != 0),
      ).trim();

      if (fieldName.isEmpty) {
        AppLogger.debug('RawDbfParser', 'Empty field name at offset $offset, skipping');
        offset += 32;
        continue;
      }

      // Byte 11: Field type (C=Character, N=Numeric, L=Logical, D=Date)
      final fieldType = String.fromCharCode(bytes[offset + 11]);
      // Byte 16: Field length
      final fieldLength = bytes[offset + 16];
      // Byte 17: Decimal count
      final fieldDecimals = bytes[offset + 17];

      fields.add(_DbfField(
        name: fieldName,
        type: fieldType,
        length: fieldLength,
        decimals: fieldDecimals,
      ));

      AppLogger.debug('RawDbfParser', 'Field: $fieldName ($fieldType, len=$fieldLength, dec=$fieldDecimals)');

      offset += 32;
    }

    return _DbfHeader(
      recordCount: recordCount,
      headerLength: headerLength,
      recordLength: recordLength,
      fields: fields,
    );
  }
}

class _DbfHeader {
  final int recordCount;
  final int headerLength;
  final int recordLength;
  final List<_DbfField> fields;

  _DbfHeader({
    required this.recordCount,
    required this.headerLength,
    required this.recordLength,
    required this.fields,
  });
}

class _DbfField {
  final String name;
  final String type; // C=Character, N=Numeric, L=Logical, D=Date
  final int length;
  final int decimals;

  _DbfField({
    required this.name,
    required this.type,
    required this.length,
    required this.decimals,
  });
}
