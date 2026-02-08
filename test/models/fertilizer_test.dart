import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/models/fertilizer.dart';

/// ✅ CRITICAL: Tests for bugs we just fixed
void main() {
  group('Fertilizer NPK Parser', () {
    test('handles invalid NPK format gracefully', () {
      final fert = Fertilizer(name: 'Test', npk: 'abc-def-ghi');
      expect(fert.nValue, 0.0);
      expect(fert.pValue, 0.0);
      expect(fert.kValue, 0.0);
    });

    test('parses valid NPK correctly', () {
      final fert = Fertilizer(name: 'Test', npk: '10-20-30');
      expect(fert.nValue, 10.0);
      expect(fert.pValue, 20.0);
      expect(fert.kValue, 30.0);
    });

    test('handles empty NPK', () {
      final fert = Fertilizer(name: 'Test', npk: '');
      expect(fert.nValue, 0.0);
      expect(fert.pValue, 0.0);
      expect(fert.kValue, 0.0);
    });

    test('handles null NPK', () {
      final fert = Fertilizer(name: 'Test', npk: null);
      expect(fert.nValue, 0.0);
      expect(fert.pValue, 0.0);
      expect(fert.kValue, 0.0);
    });

    test('handles incomplete NPK (only N)', () {
      final fert = Fertilizer(name: 'Test', npk: '10');
      expect(fert.nValue, 10.0);
      expect(fert.pValue, 0.0);
      expect(fert.kValue, 0.0);
    });
  });
}
