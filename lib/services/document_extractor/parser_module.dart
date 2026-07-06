// lib/services/document_extractor/parser_module.dart
//
// Parser Module — layout-aware field extraction from OCR text.
//
// Handles:
//  - Provider/merchant detection (PayPal, Western Union, bKash, Nagad, etc.)
//  - Document type classification
//  - Date / time extraction
//  - Reference / transaction ID extraction
//  - Sender / receiver name extraction
//  - Payment status detection
//  - Payment method detection
//  - Exchange rate / payout currency extraction
//  - Provider-specific rules (PayPal, Western Union, generic)

import 'ocr_module.dart';
import 'extractor_schema.dart';

// ── Provider detection ────────────────────────────────────────────────────────

class _ProviderRule {
  final String name;
  final RegExp pattern;
  final DocumentType docType;
  const _ProviderRule(this.name, this.pattern, this.docType);
}

final _providerRules = [
  _ProviderRule('PayPal',        RegExp(r'paypal',          caseSensitive: false), DocumentType.paymentConfirmation),
  _ProviderRule('Western Union', RegExp(r'western\s*union', caseSensitive: false), DocumentType.transferSlip),
  _ProviderRule('MoneyGram',     RegExp(r'moneygram',       caseSensitive: false), DocumentType.transferSlip),
  _ProviderRule('bKash',         RegExp(r'bkash',           caseSensitive: false), DocumentType.paymentConfirmation),
  _ProviderRule('Nagad',         RegExp(r'nagad',           caseSensitive: false), DocumentType.paymentConfirmation),
  _ProviderRule('Rocket',        RegExp(r'rocket|dbbl',     caseSensitive: false), DocumentType.paymentConfirmation),
  _ProviderRule('Stripe',        RegExp(r'stripe',          caseSensitive: false), DocumentType.paymentConfirmation),
  _ProviderRule('Wise',          RegExp(r'\bwise\b|transferwise', caseSensitive: false), DocumentType.transferSlip),
  _ProviderRule('Remitly',       RegExp(r'remitly',         caseSensitive: false), DocumentType.transferSlip),
  _ProviderRule('WorldRemit',    RegExp(r'worldremit',      caseSensitive: false), DocumentType.transferSlip),
  _ProviderRule('Bank',          RegExp(r'bank\s*(transfer|receipt|statement|slip)', caseSensitive: false), DocumentType.transferSlip),
];

// ── Document type keywords ────────────────────────────────────────────────────
final _invoiceKeywords    = RegExp(r'\binvoice\b|\binv\s*#|\bbill\b|\bproforma\b', caseSensitive: false);
final _receiptKeywords    = RegExp(r'\breceipt\b|\bpurchase\b|\bsale\s*receipt\b', caseSensitive: false);
final _transferKeywords   = RegExp(r'\btransfer\b|\bremittance\b|\bsent\b|\bmtcn\b|\bwire\b', caseSensitive: false);
final _confirmKeywords    = RegExp(r'\bconfirm(ation)?\b|\bpayment\s*confirm\b|\bsuccessful\b|\bcompleted\b', caseSensitive: false);

// ── Date patterns (ordered by specificity) ───────────────────────────────────
final _datePatterns = [
  // ISO: 2025-07-15, 2025/07/15
  RegExp(r'\b(\d{4})[-/\.](\d{1,2})[-/\.](\d{1,2})\b'),
  // DMY: 15/07/2025, 15-07-2025, 15.07.2025
  RegExp(r'\b(\d{1,2})[-/\.](\d{1,2})[-/\.](\d{4})\b'),
  // Month name: 15 July 2025, July 15, 2025, 15 Jul 2025
  RegExp(r'\b(\d{1,2})\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{4})\b', caseSensitive: false),
  RegExp(r'\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{1,2})[,\s]+(\d{4})\b', caseSensitive: false),
  // Compact: 20250715
  RegExp(r'\b(20\d{2})(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\b'),
];

// ── Time pattern ──────────────────────────────────────────────────────────────
final _timePattern = RegExp(r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM|am|pm)?\b');

// ── Reference / transaction ID patterns ──────────────────────────────────────
final _refPatterns = [
  RegExp(r'(?:transaction\s*id|txn\s*id|txn#?|trx\s*id|trx#?)[:\s#]*([A-Z0-9\-]{6,32})', caseSensitive: false),
  RegExp(r'(?:reference\s*(?:no|number|#)?|ref\s*(?:no|#)?)[:\s]*([A-Z0-9\-]{4,32})', caseSensitive: false),
  RegExp(r'(?:order\s*(?:id|no|#)|order)[:\s#]*([A-Z0-9\-]{4,32})', caseSensitive: false),
  RegExp(r'(?:payment\s*id)[:\s#]*([A-Z0-9\-]{4,32})', caseSensitive: false),
];

// ── MTCN (Western Union) ──────────────────────────────────────────────────────
final _mtcnPattern = RegExp(r'(?:MTCN|Money\s*Transfer\s*Control\s*Number)[:\s#]*(\d{8,12})', caseSensitive: false);

// ── Invoice number ────────────────────────────────────────────────────────────
final _invoiceNoPattern = RegExp(r'(?:invoice\s*(?:no|number|#)|inv\s*#?)[:\s]*([A-Z0-9\-\/]{2,24})', caseSensitive: false);

// ── Status detection ──────────────────────────────────────────────────────────
String? _detectStatus(String text) {
  final t = text.toLowerCase();
  if (RegExp(r'\bpaid\b|\bpayment\s*successful\b|\bsuccessfully\s*paid\b|\bpayment\s*complete\b').hasMatch(t)) return 'paid';
  if (RegExp(r'\bcompleted?\b|\bsuccessful\b|\bapproved\b|\bconfirmed?\b').hasMatch(t)) return 'completed';
  if (RegExp(r'\bpending\b|\bprocessing\b|\bin\s*progress\b').hasMatch(t)) return 'pending';
  if (RegExp(r'\bfailed?\b|\bdeclined?\b|\brejected?\b|\bcancelled?\b').hasMatch(t)) return 'failed';
  return null;
}

// ── Payment method detection ──────────────────────────────────────────────────
String? _detectMethod(String text) {
  final t = text.toLowerCase();
  if (t.contains('bkash')) { return 'Mobile Banking (bKash)'; }
  if (t.contains('nagad')) { return 'Mobile Banking (Nagad)'; }
  if (t.contains('rocket') || t.contains('dbbl')) { return 'Mobile Banking (Rocket)'; }
  if (t.contains('paypal')) { return 'PayPal'; }
  if (t.contains('visa') || t.contains('mastercard') ||
      t.contains('credit card') || t.contains('debit card') ||
      t.contains('card')) { return 'Card'; }
  if (t.contains('bank transfer') || t.contains('wire') ||
      t.contains('neft') || t.contains('rtgs') ||
      t.contains('swift') || t.contains('ach')) { return 'Bank Transfer'; }
  if (t.contains('cheque') || t.contains('check')) { return 'Cheque'; }
  if (t.contains('cash')) { return 'Cash'; }
  if (t.contains('western union') || t.contains('moneygram') ||
      t.contains('wise') || t.contains('remitly')) { return 'Wire Transfer'; }
  return null;
}

// ── Currency detection ────────────────────────────────────────────────────────
String? _detectCurrency(String text) {
  final t = text.toUpperCase();
  if (t.contains('BDT') || t.contains('TAKA') || t.contains('৳')) return 'BDT';
  if (t.contains('USD') || t.contains('US DOLLAR'))               return 'USD';
  if (t.contains('EUR') || t.contains('EURO') || t.contains('€')) return 'EUR';
  if (t.contains('GBP') || t.contains('POUND') || t.contains('£')) return 'GBP';
  if (t.contains('AED') || t.contains('DIRHAM'))                  return 'AED';
  if (t.contains('SGD'))                                           return 'SGD';
  if (t.contains('CNY') || t.contains('YUAN'))                    return 'CNY';
  if (t.contains('JPY') || t.contains('YEN') || t.contains('¥')) return 'JPY';
  // Symbol-only fallback
  if (text.contains(r'$'))  return 'USD';
  return null;
}

// ── Exchange rate extraction ──────────────────────────────────────────────────
String? _detectExchangeRate(String text) {
  final m = RegExp(r'(?:exchange\s*rate|rate|1\s*[A-Z]{3}\s*=)[:\s]*([\d.,]+)\s*([A-Z]{3})?', caseSensitive: false).firstMatch(text);
  if (m != null) return m.group(0)?.trim();
  return null;
}

// ── Name extraction ───────────────────────────────────────────────────────────
// Looks for "From: Name", "To: Name", "Sender: Name", "Receiver: Name" patterns
String? _extractName(String text, List<String> prefixes) {
  for (final prefix in prefixes) {
    final pat = RegExp('(?:$prefix)[:\\s]+([A-Z][a-zA-Z\\s\\.]{2,40})', caseSensitive: false);
    final m = pat.firstMatch(text);
    if (m != null) {
      final name = m.group(1)?.trim() ?? '';
      if (name.isNotEmpty && !name.toLowerCase().contains('account') &&
          !name.toLowerCase().contains('number')) {
        return name;
      }
    }
  }
  return null;
}

// ── Month name → number ───────────────────────────────────────────────────────
int _monthNum(String name) {
  const months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,  'may': 5,  'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };
  return months[name.toLowerCase().substring(0, 3)] ?? 1;
}

// ── Main parser ───────────────────────────────────────────────────────────────
class ParsedFields {
  final DocumentType documentType;
  final String? provider;
  final String? senderName;
  final String? receiverName;
  final String? transactionId;
  final String? referenceNumber;
  final String? mtcn;
  final String? invoiceNumber;
  final String? date;
  final String? time;
  final String? currency;
  final String? paymentMethod;
  final String? status;
  final String? exchangeRate;
  final String? payoutCurrency;

  const ParsedFields({
    required this.documentType,
    this.provider,
    this.senderName,
    this.receiverName,
    this.transactionId,
    this.referenceNumber,
    this.mtcn,
    this.invoiceNumber,
    this.date,
    this.time,
    this.currency,
    this.paymentMethod,
    this.status,
    this.exchangeRate,
    this.payoutCurrency,
  });
}

class ParserModule {
  /// Parse all non-amount fields from OCR blocks.
  static ParsedFields parse(List<OcrBlock> blocks) {
    final fullText = blocks.map((b) => b.text).join('\n');

    // ── Provider & document type ──────────────────────────────────────────
    String? provider;
    DocumentType docType = DocumentType.unknown;

    for (final rule in _providerRules) {
      if (rule.pattern.hasMatch(fullText)) {
        provider = rule.name;
        docType  = rule.docType;
        break;
      }
    }

    // Refine doc type if provider not found
    if (docType == DocumentType.unknown) {
      if (_invoiceKeywords.hasMatch(fullText)) {
        docType = DocumentType.invoice;
      } else if (_receiptKeywords.hasMatch(fullText)) {
        docType = DocumentType.receipt;
      } else if (_transferKeywords.hasMatch(fullText)) {
        docType = DocumentType.transferSlip;
      } else if (_confirmKeywords.hasMatch(fullText)) {
        docType = DocumentType.paymentConfirmation;
      }
    }

    // ── Date ──────────────────────────────────────────────────────────────
    String? date;
    for (final pat in _datePatterns) {
      final m = pat.firstMatch(fullText);
      if (m != null) {
        try {
          final p = pat.pattern;
          final DateTime dt;
          if (p.startsWith(r'\b(\d{4})')) {
            dt = DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
          } else if (p.contains('Jan') && p.startsWith(r'\b(\d{1,2})')) {
            dt = DateTime(int.parse(m.group(3)!), _monthNum(m.group(2)!), int.parse(m.group(1)!));
          } else if (p.contains('Jan')) {
            dt = DateTime(int.parse(m.group(3)!), _monthNum(m.group(1)!), int.parse(m.group(2)!));
          } else if (p.startsWith(r'\b(20')) {
            dt = DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
          } else {
            dt = DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
          }
          if (dt.year >= 2000 && dt.year <= 2100) {
            date = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            break;
          }
        } catch (_) {}
      }
    }

    // ── Time ──────────────────────────────────────────────────────────────
    String? time;
    final tm = _timePattern.firstMatch(fullText);
    if (tm != null) {
      time = tm.group(0)?.trim();
    }

    // ── Reference / transaction ID ────────────────────────────────────────
    String? transactionId;
    String? referenceNumber;
    for (final pat in _refPatterns) {
      final m = pat.firstMatch(fullText);
      if (m != null) {
        final val = m.group(1)?.trim() ?? '';
        if (val.isNotEmpty) {
          if (pat.pattern.toLowerCase().contains('transaction') ||
              pat.pattern.toLowerCase().contains('txn') ||
              pat.pattern.toLowerCase().contains('trx')) {
            transactionId ??= val;
          } else {
            referenceNumber ??= val;
          }
        }
      }
    }

    // ── MTCN ──────────────────────────────────────────────────────────────
    String? mtcn;
    final mtcnM = _mtcnPattern.firstMatch(fullText);
    if (mtcnM != null) mtcn = mtcnM.group(1)?.trim();

    // ── Invoice number ────────────────────────────────────────────────────
    String? invoiceNumber;
    final invM = _invoiceNoPattern.firstMatch(fullText);
    if (invM != null) invoiceNumber = invM.group(1)?.trim();

    // ── Currency ──────────────────────────────────────────────────────────
    final currency = _detectCurrency(fullText);

    // ── Payment method ────────────────────────────────────────────────────
    final paymentMethod = _detectMethod(fullText);

    // ── Status ────────────────────────────────────────────────────────────
    final status = _detectStatus(fullText);

    // ── Exchange rate ─────────────────────────────────────────────────────
    final exchangeRate = _detectExchangeRate(fullText);

    // ── Payout currency (for transfer slips with dual currencies) ─────────
    String? payoutCurrency;
    final dualCurrPat = RegExp(r'(?:receive[sd]?|payout|delivered)[:\s]+(?:[A-Z]{3}|[\$€£৳¥])', caseSensitive: false);
    final dcm = dualCurrPat.firstMatch(fullText);
    if (dcm != null) {
      payoutCurrency = _detectCurrency(dcm.group(0) ?? '');
      if (payoutCurrency == currency) payoutCurrency = null;
    }

    // ── Sender / receiver names ───────────────────────────────────────────
    final senderName = _extractName(fullText, [
      'from', 'sender', 'sent by', 'payer', 'remitter', 'paid by',
    ]);
    final receiverName = _extractName(fullText, [
      'to', 'receiver', 'recipient', 'beneficiary', 'payee', 'received by',
    ]);

    return ParsedFields(
      documentType:   docType,
      provider:       provider,
      senderName:     senderName,
      receiverName:   receiverName,
      transactionId:  transactionId,
      referenceNumber: referenceNumber,
      mtcn:           mtcn,
      invoiceNumber:  invoiceNumber,
      date:           date,
      time:           time,
      currency:       currency,
      paymentMethod:  paymentMethod,
      status:         status,
      exchangeRate:   exchangeRate,
      payoutCurrency: payoutCurrency,
    );
  }
}
