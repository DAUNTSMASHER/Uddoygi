// lib/core/utils/finance_utils.dart
//
// Centralized Financial Math Utilities.
// Standardizes rounding, precision, and multi-currency conversions
// to avoid common floating-point errors in JavaScript/Dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:intl/intl.dart';

class FinanceUtils {
  FinanceUtils._();

  /// Standard precision for financial calculations (2 decimal places)
  static const int defaultPrecision = 2;

  /// Rounds a double to a specific precision to avoid 0.9999999999999 errors.
  /// Example: round(0.1 + 0.2) -> 0.3
  static double round(double value, [int precision = defaultPrecision]) {
    final mod = pow(10, precision).toDouble();
    return (value * mod).round() / mod;
  }

  /// Safely converts dynamic Firestore values to rounded doubles.
  static double toDouble(dynamic v, [int precision = defaultPrecision]) {
    if (v == null) return 0.0;
    double val = 0.0;
    if (v is num) {
      val = v.toDouble();
    } else if (v is String) {
      val = double.tryParse(v.replaceAll(',', '')) ?? 0.0;
    }
    return round(val, precision);
  }

  /// Calculates a sum of doubles with precision guarding at each step.
  static double sum(Iterable<double> values) {
    return values.fold(0.0, (prev, element) => round(prev + element));
  }

  /// Formats currency for UI with locale-aware symbols.
  static String format(double amount, {String symbol = '৳'}) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: symbol,
      decimalDigits: 0, // ERPs often use whole numbers for BDT
    );
    return fmt.format(round(amount));
  }
}
