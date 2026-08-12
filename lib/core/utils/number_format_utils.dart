import 'package:intl/intl.dart';

/// Utility class for consistent number and nutrient value formatting across CLARO.
class NumberFormatUtils {
  static final NumberFormat _integerFormatter = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _decimalFormatter = NumberFormat('#,##0.0', 'en_US');

  /// Formats nutrient and general numerical values.
  /// Whole numbers (e.g. 2000.0) format as "2,000".
  /// Decimal numbers (e.g. 2.5) format as "2.5".
  static String formatValue(double value) {
    if (value == value.roundToDouble()) {
      return _integerFormatter.format(value.round());
    }
    return _decimalFormatter.format(value);
  }
}
