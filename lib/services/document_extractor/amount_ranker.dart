// lib/services/document_extractor/amount_ranker.dart
//
// Amount Ranking / Scoring Module
//
// Scans OCR text for all numeric values, scores each candidate based on:
//  - Proximity to high-priority keywords (Total, Paid, Amount Sent, etc.)
//  - Proximity to low-priority keywords (Fee, Tax, Discount, Subtotal, etc.)
//  - Currency symbol presence
//  - Visual position (lower on page = more likely to be a total)
//  - Magnitude plausibility (very small or very large values penalized)
//
// Returns a ranked list of DetectedAmount candidates.

import 'ocr_module.dart';
import 'extractor_schema.dart';

// ── Keyword tables ────────────────────────────────────────────────────────────

// High-priority: these labels strongly suggest the FINAL paid amount
const _highPriorityKeywords = [
  'total paid',
  'amount paid',
  'you paid',
  'total amount paid',
  'grand total',
  'total charged',
  'total cost',
  'amount sent',
  'you sent',
  'total to pay',
  'total payable',
  'net amount',
  'net payable',
  'payment amount',
  'received',
  'amount received',
  'total received',
  'paid',
  'total',
  'payment',
  'invoice total',
  'balance due',
  'amount due',
  'due',
  // Payment slip / bank slip / marketing slip
  'transaction amount',
  'transfer amount',
  'remittance amount',
  'deposit amount',
  'amount in figures',
  'amount in words',
  'credited',
  'credited to',
  'amount credited',
  'payment slip',
  'slip amount',
  'remitted',
  'amount remitted',
];

// Medium-priority: these are totals but may include fees
const _mediumPriorityKeywords = [
  'subtotal',
  'sub total',
  'sub-total',
  'amount',
  'transfer amount',
  'send amount',
  'principal',
];

// Low-priority: these are component amounts, not the final total
const _lowPriorityKeywords = [
  'fee',
  'service fee',
  'transfer fee',
  'transaction fee',
  'charge',
  'charges',
  'tax',
  'vat',
  'gst',
  'discount',
  'unit price',
  'price per unit',
  'qty',
  'quantity',
  'rate',
  'exchange rate',
  'balance',
  'available balance',
  'previous balance',
  'opening balance',
  'closing balance',
];

// ── Amount pattern ────────────────────────────────────────────────────────────
// Matches all real-world number formats found on payment slips:
//   US:       1,234.56  /  $1,234.56  /  USD 1234.56
//   European: 1.234,56  /  €1.234,56  /  EUR 1.234,56
//   Space sep: 1 234,56 (French/Russian)
//   Plain:    49.99  /  49,99  /  4999
//   With code after: 49.99 USD  /  49,99 EUR
final _amountPattern = RegExp(
  r'(?:'
    // Optional leading currency symbol or code
    r'(?:USD|EUR|GBP|AED|SGD|CNY|JPY|CAD|AUD|CHF|INR|MYR|THB|SAR|QAR|KWD|OMR|PKR|LKR|NPR|BDT|'
    r'[\$€£¥৳₹]|S\$|A\$|C\$|HK\$|NZ\$|R\$|RM|SR|DH)\s*'
  r')?'
  // The number itself — handles US, EU, space-separated, plain
  r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[,\.]\d{1,2})?'
  r'|\d+[,\.]\d{1,2}'
  r'|\d{3,})'
  // Optional trailing currency code
  r'(?:\s*(?:USD|EUR|GBP|AED|SGD|CNY|JPY|CAD|AUD|CHF|INR|MYR|THB|SAR|QAR|KWD|OMR|PKR|LKR|NPR|BDT|Taka|taka))?',
  caseSensitive: false,
);

// ── Currency patterns ─────────────────────────────────────────────────────────
String _detectCurrencyNear(String context) {
  final c = context.toUpperCase();
  // Prioritise explicit codes before symbols to avoid '$' matching SGD/CAD etc.
  if (c.contains('BDT') || c.contains('TAKA') || c.contains('৳'))  return 'BDT';
  if (c.contains('USD') || c.contains('US DOLLAR'))                  return 'USD';
  if (c.contains('EUR') || c.contains('EURO') || c.contains('€'))   return 'EUR';
  if (c.contains('GBP') || c.contains('POUND') || c.contains('£'))  return 'GBP';
  if (c.contains('AED') || c.contains('DIRHAM'))                     return 'AED';
  if (c.contains('SGD') || c.contains('S\$'))                        return 'SGD';
  if (c.contains('CAD') || c.contains('C\$'))                        return 'CAD';
  if (c.contains('AUD') || c.contains('A\$'))                        return 'AUD';
  if (c.contains('CHF') || c.contains('FRANC'))                      return 'CHF';
  if (c.contains('INR') || c.contains('RUPEE') || c.contains('₹'))  return 'INR';
  if (c.contains('MYR') || c.contains(' RM '))                       return 'MYR';
  if (c.contains('THB') || c.contains('BAHT') || c.contains('฿'))   return 'THB';
  if (c.contains('SAR') || c.contains('RIYAL'))                      return 'SAR';
  if (c.contains('QAR'))                                              return 'QAR';
  if (c.contains('KWD') || c.contains('DINAR'))                      return 'KWD';
  if (c.contains('OMR'))                                              return 'OMR';
  if (c.contains('PKR'))                                              return 'PKR';
  if (c.contains('LKR'))                                              return 'LKR';
  if (c.contains('NPR'))                                              return 'NPR';
  if (c.contains('CNY') || c.contains('YUAN'))                       return 'CNY';
  if (c.contains('JPY') || c.contains('YEN') || c.contains('¥'))    return 'JPY';
  // Generic dollar sign — assume USD only if no other dollar currency matched
  if (context.contains(r'$'))                                         return 'USD';
  return '';
}

// ── Scoring ───────────────────────────────────────────────────────────────────

/// Score a label string against keyword tables.
/// Returns a value in [-1.0, 1.0] where:
///   1.0 = very likely the final paid amount
///  -1.0 = very likely a component (fee/tax/discount)
double _scoreLabel(String label) {
  final l = label.toLowerCase();

  for (final kw in _highPriorityKeywords) {
    if (l.contains(kw)) {
      // Exact or near-exact match gets higher score
      if (l == kw || l.trim() == kw) return 1.0;
      return 0.85;
    }
  }
  for (final kw in _mediumPriorityKeywords) {
    if (l.contains(kw)) return 0.45;
  }
  for (final kw in _lowPriorityKeywords) {
    if (l.contains(kw)) return -0.6;
  }
  return 0.1; // unlabeled amount — neutral
}

/// Score based on vertical position (0.0 = top, 1.0 = bottom of document).
/// Totals tend to appear near the bottom.
double _scorePosition(int blockIndex, int totalBlocks) {
  if (totalBlocks <= 1) return 0.5;
  final relPos = blockIndex / (totalBlocks - 1);
  // Prefer bottom 40% of document
  if (relPos >= 0.6) return 0.3;
  if (relPos >= 0.4) return 0.1;
  return 0.0;
}

/// Score based on magnitude plausibility.
/// Very small (<0.01) or astronomically large (>1B) values are suspicious.
double _scoreMagnitude(double value) {
  if (value <= 0) return -1.0;
  if (value < 0.01) return -0.5;
  if (value > 1e9) return -0.3;
  return 0.0;
}

// ── Main ranking function ─────────────────────────────────────────────────────

/// Score for how well a candidate matches the expected amount (e.g. invoice total).
/// When submitting a marketing payment slip, we pass the invoice total so the
/// extractor prefers the amount that matches it.
double _scoreExpectedMatch(double value, double? expectedAmount) {
  if (expectedAmount == null || expectedAmount <= 0) return 0.0;
  final diff = (value - expectedAmount).abs();
  final pctDiff = expectedAmount > 0 ? (diff / expectedAmount) : 1.0;
  if (pctDiff < 0.001) return 0.35;  // Exact or near-exact (e.g. rounding)
  if (pctDiff < 0.005) return 0.30;  // Within 0.5%
  if (pctDiff < 0.02)  return 0.22;  // Within 2%
  if (pctDiff < 0.05)  return 0.12;  // Within 5%
  return 0.0;
}

/// Scan all OCR blocks and return ranked amount candidates.
/// [expectedAmount] Optional invoice/slip total hint (e.g. from marketing);
/// when provided, candidates matching this value are boosted for exact slip recognition.
List<DetectedAmount> rankAmounts(
  List<OcrBlock> blocks,
  String defaultCurrency, {
  double? expectedAmount,
}) {
  final candidates = <_Candidate>[];

  for (int i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    final text  = block.text;

    // Get context: current line + 1 line above + 1 line below
    final prevText = i > 0 ? blocks[i - 1].text : '';
    final nextText = i < blocks.length - 1 ? blocks[i + 1].text : '';
    final context  = '$prevText $text $nextText';

    // Find all numeric values in this block
    for (final m in _amountPattern.allMatches(text)) {
      final rawCapture = m.group(1) ?? '';
      final value = _parseRankerAmount(rawCapture);
      if (value == null || value <= 0) continue;

      // Detect currency from surrounding context
      final currency = _detectCurrencyNear(context).isNotEmpty
          ? _detectCurrencyNear(context)
          : defaultCurrency;

      // Extract label: text before the number on the same line
      final beforeNum = text.substring(0, m.start).trim();
      final label = beforeNum.isNotEmpty ? beforeNum : _inferLabel(context);

      // Score
      final labelScore    = _scoreLabel(label.isNotEmpty ? label : context);
      final posScore      = _scorePosition(i, blocks.length);
      final magScore      = _scoreMagnitude(value);
      final hasCurrSymbol = _detectCurrencyNear(text).isNotEmpty ? 0.1 : 0.0;
      final expectedScore = _scoreExpectedMatch(value, expectedAmount);

      // When expectedAmount is provided, give it significant weight so the
      // slip amount matching the invoice is selected
      final totalScore = (labelScore * 0.55) +
                         (posScore   * 0.12) +
                         (magScore   * 0.08) +
                         hasCurrSymbol +
                         expectedScore;

      candidates.add(_Candidate(
        label:    label.isNotEmpty ? label : '(unlabeled)',
        text:     m.group(0) ?? rawCapture,
        value:    value,
        currency: currency,
        score:    totalScore.clamp(-1.0, 1.0),
        blockIdx: i,
      ));
    }
  }

  // Deduplicate: keep highest-scored candidate per unique value
  final seen = <double, _Candidate>{};
  for (final c in candidates) {
    final existing = seen[c.value];
    if (existing == null || c.score > existing.score) {
      seen[c.value] = c;
    }
  }

  // Sort by score descending
  final sorted = seen.values.toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  // Convert to DetectedAmount with normalized confidence [0,1]
  return sorted.map((c) {
    final conf = ((c.score + 1.0) / 2.0).clamp(0.0, 1.0);
    return DetectedAmount(
      label:      c.label,
      text:       c.text,
      value:      c.value,
      currency:   c.currency,
      confidence: double.parse(conf.toStringAsFixed(2)),
    );
  }).toList();
}

/// Try to infer a label from surrounding context when the line has no label.
String _inferLabel(String context) {
  final lower = context.toLowerCase();
  for (final kw in [..._highPriorityKeywords, ..._mediumPriorityKeywords]) {
    if (lower.contains(kw)) return kw;
  }
  for (final kw in _lowPriorityKeywords) {
    if (lower.contains(kw)) return kw;
  }
  return '';
}

// ── Amount string normaliser ──────────────────────────────────────────────────
// Handles US (1,234.56), European (1.234,56), space-separated (1 234,56), plain.
double? _parseRankerAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  final hasComma = s.contains(',');
  final hasDot   = s.contains('.');

  if (hasComma && hasDot) {
    final lastComma = s.lastIndexOf(',');
    final lastDot   = s.lastIndexOf('.');
    if (lastComma > lastDot) {
      // European: 1.234,56
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // US: 1,234.56
      s = s.replaceAll(',', '');
    }
  } else if (hasComma) {
    final parts = s.split(',');
    if (parts.length == 2 && parts[1].length <= 2) {
      s = s.replaceAll(',', '.'); // "49,99" → 49.99
    } else {
      s = s.replaceAll(',', ''); // "1,234" → 1234
    }
  } else {
    s = s.replaceAll(' ', ''); // remove space thousands separator
  }

  return double.tryParse(s);
}

// ── Internal candidate model ──────────────────────────────────────────────────
class _Candidate {
  final String label;
  final String text;
  final double value;
  final String currency;
  final double score;
  final int    blockIdx;

  const _Candidate({
    required this.label,
    required this.text,
    required this.value,
    required this.currency,
    required this.score,
    required this.blockIdx,
  });
}
