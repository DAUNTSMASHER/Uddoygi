// lib/services/document_extractor/currency_converter.dart
//
// Live currency conversion using the free open.er-api.com endpoint.
// Rates are cached in-memory for 1 hour to avoid hammering the API.
//
// Usage:
//   final result = await CurrencyConverter.convert(
//     amount:   49.99,
//     from:     'USD',
//     to:       'BDT',
//   );
//   print(result.convertedAmount);  // e.g. 5498.90
//   print(result.rate);             // e.g. 110.00
//   print(result.rateDate);         // e.g. "2025-07-15"

import 'dart:convert';
import 'package:http/http.dart' as http;

// ── Result model ──────────────────────────────────────────────────────────────
class ConversionResult {
  final double originalAmount;
  final String fromCurrency;
  final double convertedAmount;
  final String toCurrency;
  final double rate;
  final String? rateDate;
  final bool   isLive;   // false = fallback static rate was used

  const ConversionResult({
    required this.originalAmount,
    required this.fromCurrency,
    required this.convertedAmount,
    required this.toCurrency,
    required this.rate,
    this.rateDate,
    this.isLive = true,
  });

  /// Returns a human-readable summary, e.g. "USD 49.99 → BDT 5,498.90 (rate: 110.00)"
  String get summary {
    final fmt = _fmtNum(convertedAmount);
    final r   = rate.toStringAsFixed(4);
    final live = isLive ? '' : ' [fallback rate]';
    return '$fromCurrency ${_fmtNum(originalAmount)} → $toCurrency $fmt (rate: $r)$live';
  }

  static String _fmtNum(double n) {
    if (n >= 1000) {
      return n.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return n.toStringAsFixed(2);
  }
}

// ── Static fallback rates (relative to USD, updated 2025-07) ─────────────────
// Used only when the live API is unreachable.
const _fallbackRatesFromUsd = <String, double>{
  'USD': 1.0,
  'BDT': 110.0,
  'EUR': 0.92,
  'GBP': 0.79,
  'AED': 3.67,
  'SGD': 1.35,
  'CNY': 7.25,
  'JPY': 157.0,
  'INR': 83.5,
  'CAD': 1.36,
  'AUD': 1.53,
  'CHF': 0.90,
  'MYR': 4.72,
  'THB': 36.5,
  'SAR': 3.75,
  'QAR': 3.64,
  'KWD': 0.31,
  'OMR': 0.385,
  'PKR': 278.0,
  'LKR': 305.0,
  'NPR': 133.0,
};

// ── In-memory cache ───────────────────────────────────────────────────────────
class _RateCache {
  final Map<String, double> rates; // all rates relative to base
  final String base;
  final DateTime fetchedAt;
  final String? rateDate;

  const _RateCache({
    required this.rates,
    required this.base,
    required this.fetchedAt,
    this.rateDate,
  });

  bool get isStale =>
      DateTime.now().difference(fetchedAt) > const Duration(hours: 1);
}

// ── Main converter ────────────────────────────────────────────────────────────
class CurrencyConverter {
  static _RateCache? _cache;

  // ── Fetch live rates (base = USD) ─────────────────────────────────────────
  static Future<_RateCache?> _fetchRates() async {
    // Use open.er-api.com — free, no key required, HTTPS
    const url = 'https://open.er-api.com/v6/latest/USD';
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        if (json['result'] == 'success') {
          final rawRates = json['rates'] as Map<String, dynamic>;
          final rates = rawRates.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          );
          final rateDate = json['time_last_update_utc'] as String?;
          return _RateCache(
            rates:     rates,
            base:      'USD',
            fetchedAt: DateTime.now(),
            rateDate:  rateDate,
          );
        }
      }
    } catch (_) {
      // Network error — fall through to fallback
    }
    return null;
  }

  // ── Get rate: from → to ───────────────────────────────────────────────────
  static Future<({double rate, String? rateDate, bool isLive})> _getRate(
    String from,
    String to,
  ) async {
    from = from.toUpperCase().trim();
    to   = to.toUpperCase().trim();

    if (from == to) return (rate: 1.0, rateDate: null, isLive: true);

    // Refresh cache if stale or absent
    if (_cache == null || _cache!.isStale) {
      _cache = await _fetchRates();
    }

    if (_cache != null) {
      final rates = _cache!.rates;
      // Both currencies relative to USD
      final fromRate = rates[from] ?? _fallbackRatesFromUsd[from];
      final toRate   = rates[to]   ?? _fallbackRatesFromUsd[to];

      if (fromRate != null && toRate != null && fromRate > 0) {
        final rate = toRate / fromRate;
        return (rate: rate, rateDate: _cache!.rateDate, isLive: true);
      }
    }

    // Fallback to static rates
    final fromFallback = _fallbackRatesFromUsd[from];
    final toFallback   = _fallbackRatesFromUsd[to];
    if (fromFallback != null && toFallback != null && fromFallback > 0) {
      return (rate: toFallback / fromFallback, rateDate: null, isLive: false);
    }

    // Last resort: 1:1 (unknown currency pair)
    return (rate: 1.0, rateDate: null, isLive: false);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Convert [amount] from [from] currency to [to] currency.
  /// Always returns a result — falls back to static rates if network fails.
  static Future<ConversionResult> convert({
    required double amount,
    required String from,
    required String to,
  }) async {
    final (:rate, :rateDate, :isLive) = await _getRate(from, to);
    return ConversionResult(
      originalAmount:  amount,
      fromCurrency:    from.toUpperCase(),
      convertedAmount: double.parse((amount * rate).toStringAsFixed(2)),
      toCurrency:      to.toUpperCase(),
      rate:            double.parse(rate.toStringAsFixed(6)),
      rateDate:        rateDate,
      isLive:          isLive,
    );
  }

  /// Returns true if [from] and [to] are the same currency (no conversion needed).
  static bool isSameCurrency(String from, String to) =>
      from.toUpperCase().trim() == to.toUpperCase().trim();

  /// Force-refresh the rate cache (call when user explicitly requests a refresh).
  static Future<void> refreshRates() async {
    _cache = await _fetchRates();
  }

  /// Normalise a currency code from a symbol or abbreviation.
  /// e.g. "$" → "USD", "£" → "GBP", "৳" → "BDT"
  static String normaliseCurrency(String raw) {
    final t = raw.trim();
    const map = {
      r'$':    'USD',
      'US\$':  'USD',
      'USD':   'USD',
      '€':     'EUR',
      'EUR':   'EUR',
      '£':     'GBP',
      'GBP':   'GBP',
      '¥':     'JPY',
      'JPY':   'JPY',
      'CNY':   'CNY',
      '৳':     'BDT',
      'BDT':   'BDT',
      'TK':    'BDT',
      'TAKA':  'BDT',
      'AED':   'AED',
      'DH':    'AED',
      'SGD':   'SGD',
      'S\$':   'SGD',
      'INR':   'INR',
      '₹':     'INR',
      'CAD':   'CAD',
      'C\$':   'CAD',
      'AUD':   'AUD',
      'A\$':   'AUD',
      'CHF':   'CHF',
      'MYR':   'MYR',
      'RM':    'MYR',
      'THB':   'THB',
      '฿':     'THB',
      'SAR':   'SAR',
      'SR':    'SAR',
      'QAR':   'QAR',
      'KWD':   'KWD',
      'OMR':   'OMR',
      'PKR':   'PKR',
      'RS':    'PKR',
      'LKR':   'LKR',
      'NPR':   'NPR',
    };
    return map[t.toUpperCase()] ?? map[t] ?? t.toUpperCase();
  }
}
