import 'package:flutter_test/flutter_test.dart';
import 'package:claro/core/utils/number_format_utils.dart';

void main() {
  group('NumberFormatUtils Tests', () {
    test('formats whole numbers without decimal places and with comma separators', () {
      expect(NumberFormatUtils.formatValue(2000.0), '2,000');
      expect(NumberFormatUtils.formatValue(0.0), '0');
      expect(NumberFormatUtils.formatValue(150.0), '150');
      expect(NumberFormatUtils.formatValue(1000000.0), '1,000,000');
    });

    test('formats decimal numbers with one decimal place', () {
      expect(NumberFormatUtils.formatValue(2.5), '2.5');
      expect(NumberFormatUtils.formatValue(1.11), '1.1');
      expect(NumberFormatUtils.formatValue(4.44), '4.4');
      expect(NumberFormatUtils.formatValue(1234.56), '1,234.6');
    });
  });
}
