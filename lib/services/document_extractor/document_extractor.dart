// lib/services/document_extractor/document_extractor.dart
//
// Document Extractor — main orchestrator.
//
// Pipeline:
//  1. OCR  (ML Kit for images, byte-scan for PDFs)
//  2. Field parsing (provider, date, ref, names, status, method)
//  3. Amount ranking (keyword-proximity scoring)
//  4. Provider-specific post-processing
//     ├── PayPal   — exhaustive "Amount Paid" row patterns (30+ formats)
//     ├── WU/WR    — "Total to Sender" / "Amount Sent"
//     └── Generic  — invoice Grand Total / receipt Total
//  5. Reference-company extraction
//  6. Schema assembly & confidence calculation

import 'dart:io';

import 'ocr_module.dart';
import 'parser_module.dart';
import 'amount_ranker.dart';
import 'extractor_schema.dart';
import '../ai_service.dart';

export 'extractor_schema.dart';
export 'currency_converter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PayPal "Amount Paid" exhaustive patterns
//
// PayPal renders the paid amount in many ways depending on:
//  • App version (iOS / Android / Web / email receipt)
//  • Language locale
//  • Screenshot vs PDF export
//  • Whether it's a Send Money, Purchase, Subscription, or Refund
//
// Every known format is listed below.  The regex captures the numeric part
// (group 1) and optionally the currency code (group 2).
// ─────────────────────────────────────────────────────────────────────────────
final _paypalPatterns = <RegExp>[
  // ── "You paid" / "You sent" ───────────────────────────────────────────────
  // "You paid $49.99"  "You paid USD 49.99"  "You paid 49.99 USD"
  RegExp(
    r'you\s+(?:paid|sent)\s*[:\-]?\s*'
    r'(?:(?:USD|EUR|GBP|AED|SGD|CAD|AUD|INR|BDT|CNY|JPY|CHF|MYR|THB|SAR|QAR|KWD|OMR|PKR|LKR|NPR)\s*)?'
    r'(?:[\$€£¥৳₹]?\s*)'
    r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+)'
    r'\s*(?:USD|EUR|GBP|AED|SGD|CAD|AUD|INR|BDT|CNY|JPY|CHF|MYR|THB|SAR|QAR|KWD|OMR|PKR|LKR|NPR)?',
    caseSensitive: false,
  ),

  // ── "Amount" row (standalone label then value on same or next line) ────────
  // "Amount   $49.99"  "Amount: 49.99 USD"
  RegExp(
    r'(?:^|\n)\s*amount\s*[:\-]?\s*'
    r'(?:(?:USD|EUR|GBP|AED|SGD|CAD|AUD|INR|BDT|CNY|JPY|CHF|MYR|THB|SAR|QAR|KWD|OMR|PKR|LKR|NPR)\s*)?'
    r'(?:[\$€£¥৳₹]?\s*)'
    r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+)',
    caseSensitive: false,
    multiLine: true,
  ),

  // ── "Total"  ──────────────────────────────────────────────────────────────
  // "Total $49.99"  "Total: USD 49.99"  "Total amount: 49.99"
  RegExp(
    r'(?:^|\n)\s*total(?:\s+amount)?\s*[:\-]?\s*'
    r'(?:(?:USD|EUR|GBP|AED|SGD|CAD|AUD|INR|BDT|CNY|JPY|CHF|MYR|THB|SAR|QAR|KWD|OMR|PKR|LKR|NPR)\s*)?'
    r'(?:[\$€£¥৳₹]?\s*)'
    r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+)',
    caseSensitive: false,
    multiLine: true,
  ),

  // ── "Payment amount" / "Payment total" ───────────────────────────────────
  RegExp(
    r'payment\s+(?:amount|total)\s*[:\-]?\s*'
    r'(?:[\$€£¥৳₹]?\s*)'
    r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+)',
    caseSensitive: false,
  ),

  // ── "Charged" / "Charge amount" ──────────────────────────────────────────
  RegExp(
    r'(?:charged|charge\s+amount)\s*[:\-]?\s*'
    r'(?:[\$€£¥৳₹]?\s*)'
    r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+)',
    caseSensitive: false,
  ),

  // ── Currency symbol immediately before number (no label) ─────────────────
  // "$49.99"  "USD 49.99"  "€ 49,99"  "£49.99"
  // Only used as a last-resort fallback inside PayPal context
  RegExp(
    r'(?:USD|EUR|GBP|AED|SGD|CAD|AUD|INR|BDT|CNY|JPY|CHF|MYR|THB|SAR|QAR|KWD|OMR|PKR|LKR|NPR|[\$€£¥৳₹])\s*'
    r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+)',
    caseSensitive: false,
  ),

  // ── Number immediately followed by currency code ──────────────────────────
  // "49.99 USD"  "49,99 EUR"
  RegExp(
    r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+)\s*'
    r'(USD|EUR|GBP|AED|SGD|CAD|AUD|INR|BDT|CNY|JPY|CHF|MYR|THB|SAR|QAR|KWD|OMR|PKR|LKR|NPR)',
    caseSensitive: false,
  ),
];

// ── Currency code capture helper ──────────────────────────────────────────────
final _currencyInContext = RegExp(
  r'\b(USD|EUR|GBP|AED|SGD|CAD|AUD|INR|BDT|CNY|JPY|CHF|MYR|THB|SAR|QAR|KWD|OMR|PKR|LKR|NPR)\b'
  r'|[\$€£¥৳₹]',
  caseSensitive: false,
);

String _currencyFromContext(String ctx, String fallback) {
  final m = _currencyInContext.firstMatch(ctx);
  if (m == null) return fallback;
  final raw = m.group(0) ?? '';
  const symMap = {
    r'$': 'USD', '€': 'EUR', '£': 'GBP',
    '¥': 'JPY',  '৳': 'BDT', '₹': 'INR',
  };
  return symMap[raw] ?? raw.toUpperCase();
}

// ── Normalise a raw numeric string to double ──────────────────────────────────
// Handles: "1,234.56"  "1.234,56"  "1 234.56"  "1234.56"  "1234,56" (EU)
double? _parseAmount(String raw) {
  if (raw.isEmpty) return null;

  // Remove leading/trailing whitespace
  var s = raw.trim();

  // Remove currency symbols / codes that may have been captured
  s = s.replaceAll(RegExp(r'[^\d,.\s]'), '').trim();

  // Determine decimal separator:
  // If both ',' and '.' present → the last one is the decimal separator
  final hasComma = s.contains(',');
  final hasDot   = s.contains('.');

  if (hasComma && hasDot) {
    final lastComma = s.lastIndexOf(',');
    final lastDot   = s.lastIndexOf('.');
    if (lastComma > lastDot) {
      // European: 1.234,56 → remove dots, replace comma with dot
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // US: 1,234.56 → remove commas
      s = s.replaceAll(',', '');
    }
  } else if (hasComma && !hasDot) {
    // Could be "1,234" (thousands) or "49,99" (European decimal)
    final parts = s.split(',');
    if (parts.length == 2 && parts[1].length <= 2) {
      // Treat as decimal: "49,99" → 49.99
      s = s.replaceAll(',', '.');
    } else {
      // Treat as thousands separator: "1,234" → 1234
      s = s.replaceAll(',', '');
    }
  } else {
    // Remove spaces used as thousands separators
    s = s.replaceAll(' ', '');
  }

  return double.tryParse(s);
}

// ── Reference company extraction ─────────────────────────────────────────────
// Looks for the merchant / payee company name in the document.
// PayPal receipts show "You paid [Company Name]" or "Payment to [Company Name]".
// Generic receipts show "Merchant: Name" or the company name at the top.
String? _extractReferenceCompany(String fullText, String? knownProvider) {
  // ── PayPal-specific ───────────────────────────────────────────────────────
  if (knownProvider?.toLowerCase() == 'paypal') {
    // "You paid [Company]"  /  "You sent money to [Company]"
    final ppPaid = RegExp(
      r"you\s+(?:paid|sent(?:\s+money\s+to)?)\s+([A-Z][A-Za-z0-9 &.,'\-]{2,60}?)(?:\s+on\b|\s+\d|\n|$)",
      caseSensitive: false,
    );
    final m1 = ppPaid.firstMatch(fullText);
    if (m1 != null) {
      final name = m1.group(1)?.trim() ?? '';
      if (name.isNotEmpty && !_isAmountLike(name)) return _cleanCompanyName(name);
    }

    // "Payment to [Company]"
    final ppTo = RegExp(
      r"payment\s+to\s*[:\-]?\s*([A-Z][A-Za-z0-9 &.,'\-]{2,60}?)(?:\s+on\b|\s+\d|\n|$)",
      caseSensitive: false,
    );
    final m2 = ppTo.firstMatch(fullText);
    if (m2 != null) {
      final name = m2.group(1)?.trim() ?? '';
      if (name.isNotEmpty && !_isAmountLike(name)) return _cleanCompanyName(name);
    }

    // "Merchant: [Company]"
    final ppMerchant = RegExp(
      r"merchant\s*[:\-]\s*([A-Z][A-Za-z0-9 &.,'\-]{2,60})",
      caseSensitive: false,
    );
    final m3 = ppMerchant.firstMatch(fullText);
    if (m3 != null) {
      final name = m3.group(1)?.trim() ?? '';
      if (name.isNotEmpty && !_isAmountLike(name)) return _cleanCompanyName(name);
    }
  }

  // ── Generic patterns ──────────────────────────────────────────────────────

  // "Paid to: [Company]"  /  "Pay to: [Company]"
  final paidTo = RegExp(
    r"(?:paid|pay(?:ment)?)\s+to\s*[:\-]?\s*([A-Z][A-Za-z0-9 &.,'\-]{2,60})",
    caseSensitive: false,
  );
  final m4 = paidTo.firstMatch(fullText);
  if (m4 != null) {
    final name = m4.group(1)?.trim() ?? '';
    if (name.isNotEmpty && !_isAmountLike(name)) return _cleanCompanyName(name);
  }

  // "Merchant: [Name]"  /  "Vendor: [Name]"  /  "Seller: [Name]"
  final merchant = RegExp(
    r"(?:merchant|vendor|seller|payee|biller|company|business)\s*[:\-]\s*([A-Z][A-Za-z0-9 &.,'\-]{2,60})",
    caseSensitive: false,
  );
  final m5 = merchant.firstMatch(fullText);
  if (m5 != null) {
    final name = m5.group(1)?.trim() ?? '';
    if (name.isNotEmpty && !_isAmountLike(name)) return _cleanCompanyName(name);
  }

  // "Invoice from [Company]"  /  "Bill from [Company]"
  final invoiceFrom = RegExp(
    r"(?:invoice|bill|receipt)\s+from\s+([A-Z][A-Za-z0-9 &.,'\-]{2,60})",
    caseSensitive: false,
  );
  final m6 = invoiceFrom.firstMatch(fullText);
  if (m6 != null) {
    final name = m6.group(1)?.trim() ?? '';
    if (name.isNotEmpty && !_isAmountLike(name)) return _cleanCompanyName(name);
  }

  // First non-empty line that looks like a company name (title-case, ≥3 words OR contains Ltd/Inc/Corp/LLC)
  final lines = fullText.split('\n');
  for (final line in lines.take(10)) {
    final t = line.trim();
    if (t.length < 3 || t.length > 80) continue;
    if (_isAmountLike(t)) continue;
    if (RegExp(r'\b(ltd|limited|inc|corp|llc|co\.|pvt|sdn|bhd|gmbh|plc|s\.a\.|bv)\b',
        caseSensitive: false).hasMatch(t)) {
      return _cleanCompanyName(t);
    }
  }

  return null;
}

bool _isAmountLike(String s) =>
    RegExp(r'^\s*[\d\$€£¥৳₹,.\s]+\s*$').hasMatch(s);

String _cleanCompanyName(String s) {
  // Remove trailing punctuation / noise
  return s
      .replaceAll(RegExp(r'[,;:\.\s]+$'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

// ─────────────────────────────────────────────────────────────────────────────
class DocumentExtractor {
  /// Extract all fields from a payment document (image or PDF).
  /// [expectedAmount] When provided (e.g. invoice total for marketing slip),
  /// the extractor boosts candidates that match this value for exact slip amount recognition.
  static Future<ExtractionResult> extract(File file, {double? expectedAmount}) async {
    // ── Step 1: OCR ──────────────────────────────────────────────────────────
    final ocrResult = await OcrModule.extract(file);

    if (ocrResult.fullText.trim().isEmpty) {
      return ExtractionResult(
        documentType:       DocumentType.unknown,
        rawDetectedAmounts: const [],
        notes:              ['No text could be extracted from the file.'],
        confidenceOverall:  0.0,
      );
    }

    // ── Step 2: Field parsing ────────────────────────────────────────────────
    final fields = ParserModule.parse(ocrResult.blocks);

    // ── Step 3: Amount ranking (with optional invoice/slip total hint) ────────
    final defaultCurrency = fields.currency ?? 'BDT';
    final ranked = rankAmounts(
      ocrResult.blocks,
      defaultCurrency,
      expectedAmount: expectedAmount,
    );

    // ── Step 4: Provider-specific post-processing ────────────────────────────
    final processed = _applyProviderRules(
      provider:  fields.provider,
      docType:   fields.documentType,
      ranked:    ranked,
      fullText:  ocrResult.fullText,
      currency:  defaultCurrency,
    );

    // ── Step 5: Reference company ────────────────────────────────────────────
    final refCompany = _extractReferenceCompany(
      ocrResult.fullText,
      fields.provider,
    );

    // ── Step 6: Assemble result ──────────────────────────────────────────────
    final result = _buildResult(
      fields:      fields,
      ranked:      processed.ranked,
      notes:       processed.notes,
      isRealOcr:   ocrResult.isRealOcr,
      refCompany:  refCompany,
    );

    // ── Step 7: AI Fallback ──────────────────────────────────────────────────
    if (result.confidenceOverall < 0.75) {
      final aiData = await AIService.parseDocument(ocrResult.fullText);
      if (aiData.containsKey('error')) return result;

      // Merge AI improvements
      return _mergeWithAi(result, aiData);
    }

    return result;
  }

  static ExtractionResult _mergeWithAi(ExtractionResult original, Map<String, dynamic> ai) {
    final notes = List<String>.from(original.notes)..add('AI Refinement: GPT-4o was used to boost extraction accuracy.');

    // Map AI string to DocumentType enum
    DocumentType docType = original.documentType;
    final aiType = ai['document_type']?.toString().toLowerCase();
    if (aiType != null && docType == DocumentType.unknown) {
      if (aiType.contains('receipt')) docType = DocumentType.receipt;
      else if (aiType.contains('invoice')) docType = DocumentType.invoice;
    }

    return ExtractionResult(
      documentType:       docType,
      providerOrMerchant: ai['provider']?.toString() ?? original.providerOrMerchant,
      referenceCompany:   ai['reference_company']?.toString() ?? original.referenceCompany,
      senderName:         original.senderName,
      receiverName:       original.receiverName,
      transactionId:      ai['transaction_id']?.toString() ?? original.transactionId,
      referenceNumber:    original.referenceNumber,
      mtcn:               original.mtcn,
      invoiceNumber:      ai['invoice_number']?.toString() ?? original.invoiceNumber,
      date:               ai['date']?.toString() ?? original.date,
      time:               original.time,
      currency:           ai['currency']?.toString() ?? original.currency,
      actualAmountPaid:   ai['total_amount'] != null
          ? AmountField(
              value: double.tryParse(ai['total_amount'].toString()) ?? original.bestAmount,
              currency: ai['currency']?.toString() ?? original.bestCurrency,
              text: ai['total_amount'].toString(),
              confidence: 0.95,
            )
          : original.actualAmountPaid,
      subtotal:           original.subtotal,
      fee:                original.fee,
      tax:                original.tax,
      discount:           original.discount,
      totalBeforeFee:     original.totalBeforeFee,
      totalAfterFee:      original.totalAfterFee,
      exchangeRate:       original.exchangeRate,
      payoutCurrency:     original.payoutCurrency,
      payoutAmount:       original.payoutAmount,
      paymentMethod:      original.paymentMethod,
      status:             ai['status']?.toString() ?? original.status,
      rawDetectedAmounts: original.rawDetectedAmounts,
      notes:              notes,
      confidenceOverall:  0.95, // AI verification boosts confidence
    );
  }

  // ── Provider-specific rules ───────────────────────────────────────────────
  static _PostProcessed _applyProviderRules({
    required String?              provider,
    required DocumentType         docType,
    required List<DetectedAmount> ranked,
    required String               fullText,
    required String               currency,
  }) {
    final notes = <String>[];

    switch (provider?.toLowerCase()) {
      case 'paypal':
        return _paypalRules(ranked, fullText, currency, notes);
      case 'western union':
      case 'worldremit':
      case 'remitly':
      case 'wise':
        return _transferRules(ranked, fullText, currency, notes, provider!);
      default:
        return _genericRules(ranked, docType, fullText, currency, notes);
    }
  }

  // ── PayPal rules ──────────────────────────────────────────────────────────
  // Tries every known PayPal amount-display format in priority order.
  static _PostProcessed _paypalRules(
    List<DetectedAmount> ranked,
    String fullText,
    String currency,
    List<String> notes,
  ) {
    // Try each pattern in priority order
    for (int i = 0; i < _paypalPatterns.length; i++) {
      final pat = _paypalPatterns[i];
      final m   = pat.firstMatch(fullText);
      if (m == null) continue;

      // Group 1 is always the numeric part
      final rawNum = m.group(1) ?? '';
      final val    = _parseAmount(rawNum);
      if (val == null || val <= 0) continue;

      // Try to get currency from the match context (±40 chars)
      final start = (m.start - 40).clamp(0, fullText.length);
      final end   = (m.end   + 40).clamp(0, fullText.length);
      final ctx   = fullText.substring(start, end);
      final detectedCurrency = _currencyFromContext(ctx, currency);

      // Confidence decreases for later (less specific) patterns
      final conf = i == 0 ? 0.97
                 : i == 1 ? 0.93
                 : i == 2 ? 0.91
                 : i == 3 ? 0.88
                 : i == 4 ? 0.85
                 : 0.75;

      final boosted = DetectedAmount(
        label:      _labelForPattern(i),
        text:       m.group(0)?.trim() ?? rawNum,
        value:      val,
        currency:   detectedCurrency,
        confidence: conf,
      );
      final rest = ranked.where((a) => (a.value - val).abs() > 0.01).toList();
      return _PostProcessed(ranked: [boosted, ...rest], notes: notes);
    }

    notes.add('PayPal: no recognised amount pattern matched; using ranked amounts.');
    return _PostProcessed(ranked: ranked, notes: notes);
  }

  static String _labelForPattern(int idx) {
    const labels = [
      'You paid',
      'Amount',
      'Total',
      'Payment amount',
      'Charged',
      'Currency + number',
      'Number + currency',
    ];
    return idx < labels.length ? labels[idx] : 'PayPal amount';
  }

  // ── Transfer service rules (WU, Wise, Remitly, WorldRemit) ───────────────
  static _PostProcessed _transferRules(
    List<DetectedAmount> ranked,
    String fullText,
    String currency,
    List<String> notes,
    String provider,
  ) {
    // "Total to Sender" / "Total charged" / "Total cost" / "You pay"
    final totalPat = RegExp(
      r'(?:total\s*(?:to\s*sender|charged|paid|cost|amount|you\s*pay)|you\s*pay)[:\s]+'
      r'(?:[\$€£¥৳₹]?\s*)'
      r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+)',
      caseSensitive: false,
    );
    final m = totalPat.firstMatch(fullText);
    if (m != null) {
      final val = _parseAmount(m.group(1) ?? '');
      if (val != null && val > 0) {
        final boosted = DetectedAmount(
          label:      'Total to Sender',
          text:       m.group(0)?.trim() ?? val.toString(),
          value:      val,
          currency:   currency,
          confidence: 0.95,
        );
        final rest = ranked.where((a) => (a.value - val).abs() > 0.01).toList();
        return _PostProcessed(ranked: [boosted, ...rest], notes: notes);
      }
    }

    // Fallback: "Amount Sent"
    final sentPat = RegExp(
      r'amount\s*sent[:\s]+'
      r'(?:[\$€£¥৳₹]?\s*)'
      r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+)',
      caseSensitive: false,
    );
    if (sentPat.hasMatch(fullText)) {
      notes.add('$provider: Only "Amount Sent" found — total charged (incl. fee) may differ.');
    }

    return _PostProcessed(ranked: ranked, notes: notes);
  }

  // ── Generic rules ─────────────────────────────────────────────────────────
  static _PostProcessed _genericRules(
    List<DetectedAmount> ranked,
    DocumentType docType,
    String fullText,
    String currency,
    List<String> notes,
  ) {
    if (ranked.isEmpty) {
      notes.add('No numeric amounts detected in the document.');
      return _PostProcessed(ranked: ranked, notes: notes);
    }

    // Bank slip / payment slip: "Amount:" or "Amount" on same line as number
    final amountLabelPat = RegExp(
      r'(?:amount|transaction\s*amount|transfer\s*amount|payment\s*amount|credited|deposit)[:\s]+'
      r'(?:[\$€£¥৳₹]?\s*)?'
      r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+)',
      caseSensitive: false,
    );
    final amountM = amountLabelPat.firstMatch(fullText);
    if (amountM != null) {
      final val = _parseAmount(amountM.group(1) ?? '');
      if (val != null && val > 0) {
        final boosted = DetectedAmount(
          label:      'Amount',
          text:       amountM.group(0)?.trim() ?? val.toString(),
          value:      val,
          currency:   currency,
          confidence: 0.90,
        );
        final rest = ranked.where((a) => (a.value - val).abs() > 0.01).toList();
        return _PostProcessed(ranked: [boosted, ...rest], notes: notes);
      }
    }

    if (docType == DocumentType.invoice) {
      final totalPat = RegExp(
        r'(?:grand\s*total|total\s*amount|total)[:\s]+'
        r'(?:[\$€£¥৳₹]?\s*)'
        r'([\d]{1,3}(?:[,\.\s]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+)',
        caseSensitive: false,
      );
      final m = totalPat.firstMatch(fullText);
      if (m != null) {
        final val = _parseAmount(m.group(1) ?? '');
        if (val != null && val > 0) {
          final boosted = DetectedAmount(
            label:      'Total',
            text:       m.group(0)?.trim() ?? val.toString(),
            value:      val,
            currency:   currency,
            confidence: 0.92,
          );
          final rest = ranked.where((a) => (a.value - val).abs() > 0.01).toList();
          return _PostProcessed(ranked: [boosted, ...rest], notes: notes);
        }
      }
    }

    if (ranked.length > 3) {
      notes.add('Multiple amounts detected. Highest-confidence value selected as actual_amount_paid.');
    }

    return _PostProcessed(ranked: ranked, notes: notes);
  }

  // ── Build final ExtractionResult ──────────────────────────────────────────
  static ExtractionResult _buildResult({
    required ParsedFields         fields,
    required List<DetectedAmount> ranked,
    required List<String>         notes,
    required bool                 isRealOcr,
    String?                       refCompany,
  }) {
    if (!isRealOcr) {
      notes.add(
        'OCR was not available for this file type; text extracted via byte-scan. '
        'Accuracy may be lower for image files.',
      );
    }

    // Best amount = highest-ranked candidate
    AmountField? actualAmountPaid;
    if (ranked.isNotEmpty) {
      final best = ranked.first;
      actualAmountPaid = AmountField(
        value:      best.value,
        currency:   best.currency,
        text:       best.text,
        confidence: best.confidence,
      );
    }

    // Secondary amounts
    AmountField? fee;
    AmountField? subtotal;
    AmountField? tax;
    AmountField? discount;

    for (final a in ranked.skip(1)) {
      final l = a.label.toLowerCase();
      if (fee == null && (l.contains('fee') || l.contains('charge'))) {
        fee = AmountField(value: a.value, currency: a.currency, text: a.text, confidence: a.confidence);
      } else if (subtotal == null && (l.contains('subtotal') || l.contains('sub total') || l.contains('sub-total'))) {
        subtotal = AmountField(value: a.value, currency: a.currency, text: a.text, confidence: a.confidence);
      } else if (tax == null && (l.contains('tax') || l.contains('vat') || l.contains('gst'))) {
        tax = AmountField(value: a.value, currency: a.currency, text: a.text, confidence: a.confidence);
      } else if (discount == null && l.contains('discount')) {
        discount = AmountField(value: a.value, currency: a.currency, text: a.text, confidence: a.confidence);
      }
    }

    // Payout amount (transfer slips with dual currency)
    AmountField? payoutAmount;
    if (fields.payoutCurrency != null && ranked.length > 1) {
      for (final a in ranked) {
        if (a.currency == fields.payoutCurrency) {
          payoutAmount = AmountField(
            value: a.value, currency: a.currency,
            text: a.text, confidence: a.confidence,
          );
          break;
        }
      }
    }

    // Overall confidence
    double confidence = 0.0;
    if (actualAmountPaid != null)  confidence += actualAmountPaid.confidence * 0.5;
    if (fields.date != null)       confidence += 0.10;
    if (fields.transactionId != null || fields.referenceNumber != null) confidence += 0.10;
    if (fields.currency != null)   confidence += 0.10;
    if (fields.status != null)     confidence += 0.05;
    if (fields.paymentMethod != null) confidence += 0.05;
    if (fields.provider != null)   confidence += 0.10;
    confidence = confidence.clamp(0.0, 1.0);

    // Merge reference company: prefer extracted over parser's provider
    final provider = refCompany ?? fields.provider;

    return ExtractionResult(
      documentType:       fields.documentType,
      providerOrMerchant: provider,
      referenceCompany:   refCompany,
      senderName:         fields.senderName,
      receiverName:       fields.receiverName,
      transactionId:      fields.transactionId,
      referenceNumber:    fields.referenceNumber,
      mtcn:               fields.mtcn,
      invoiceNumber:      fields.invoiceNumber,
      date:               fields.date,
      time:               fields.time,
      currency:           fields.currency ?? (ranked.isNotEmpty ? ranked.first.currency : null),
      actualAmountPaid:   actualAmountPaid,
      subtotal:           subtotal,
      fee:                fee,
      tax:                tax,
      discount:           discount,
      totalBeforeFee:     subtotal,
      totalAfterFee:      (fee != null && actualAmountPaid != null)
                              ? AmountField(
                                  value:      actualAmountPaid.value + fee.value,
                                  currency:   actualAmountPaid.currency,
                                  text:       '${actualAmountPaid.value} + ${fee.value}',
                                  confidence: (actualAmountPaid.confidence + fee.confidence) / 2,
                                )
                              : null,
      exchangeRate:       fields.exchangeRate,
      payoutCurrency:     fields.payoutCurrency,
      payoutAmount:       payoutAmount,
      paymentMethod:      fields.paymentMethod,
      status:             fields.status,
      rawDetectedAmounts: ranked,
      notes:              notes,
      confidenceOverall:  double.parse(confidence.toStringAsFixed(2)),
    );
  }
}

// ── Internal helper ───────────────────────────────────────────────────────────
class _PostProcessed {
  final List<DetectedAmount> ranked;
  final List<String> notes;
  const _PostProcessed({required this.ranked, required this.notes});
}
