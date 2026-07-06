import 'dart:math';
import 'package:intl/intl.dart';

class FinanceUtils {
  FinanceUtils._();

  static const int defaultPrecision = 2;

  static double round(double value, [int precision = defaultPrecision]) {
    final mod = pow(10, precision).toDouble();
    return (value * mod).round() / mod;
  }

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

  static double sum(Iterable<double> values) {
    return values.fold(0.0, (prev, element) => round(prev + element));
  }

  static String format(double amount, {String symbol = '৳'}) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: symbol,
      decimalDigits: 0,
    );
    return fmt.format(round(amount));
  }

  static double grossMargin(double revenue, double costOfGoodsSold) {
    if (revenue <= 0) return 0.0;
    return round(((revenue - costOfGoodsSold) / revenue) * 100);
  }

  static double netProfitMargin(double revenue, double totalCosts) {
    if (revenue <= 0) return 0.0;
    return round(((revenue - totalCosts) / revenue) * 100);
  }

  static double costPlusPrice(double cost, double marginPercent) {
    return round(cost / (1 - (marginPercent / 100)));
  }

  static double sellingPriceFromCost(double cost, double markupPercent) {
    return round(cost * (1 + markupPercent / 100));
  }

  static double contributionMargin(double sellingPrice, double variableCost) {
    if (sellingPrice <= 0) return 0.0;
    return round(((sellingPrice - variableCost) / sellingPrice) * 100);
  }

  static double breakEvenUnits(double fixedCosts, double sellingPrice, double variableCostPerUnit) {
    final contribution = sellingPrice - variableCostPerUnit;
    if (contribution <= 0) return double.infinity;
    return (fixedCosts / contribution).ceilToDouble();
  }
}
