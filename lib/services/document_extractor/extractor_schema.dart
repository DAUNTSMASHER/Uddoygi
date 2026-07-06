// lib/services/document_extractor/extractor_schema.dart
//
// Data models for the document extraction pipeline.
// All fields are nullable — never guessed, only set when found.

// ── Detected amount candidate ─────────────────────────────────────────────────
class DetectedAmount {
  final String label;
  final String text;
  final double value;
  final String currency;
  final double confidence;

  const DetectedAmount({
    required this.label,
    required this.text,
    required this.value,
    required this.currency,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'text': text,
        'value': value,
        'currency': currency,
        'confidence': confidence,
      };
}

// ── Typed amount with confidence ──────────────────────────────────────────────
class AmountField {
  final double value;
  final String currency;
  final String text;
  final double confidence;

  const AmountField({
    required this.value,
    required this.currency,
    required this.text,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'value': value,
        'currency': currency,
        'text': text,
        'confidence': confidence,
      };
}

// ── Document type enum ────────────────────────────────────────────────────────
enum DocumentType {
  receipt,
  invoice,
  paymentConfirmation,
  transferSlip,
  unknown,
}

extension DocumentTypeExt on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.receipt:            return 'receipt';
      case DocumentType.invoice:            return 'invoice';
      case DocumentType.paymentConfirmation: return 'payment_confirmation';
      case DocumentType.transferSlip:       return 'transfer_slip';
      case DocumentType.unknown:            return 'unknown';
    }
  }
}

// ── Full extraction result ────────────────────────────────────────────────────
class ExtractionResult {
  final DocumentType documentType;
  final String? providerOrMerchant;
  /// The specific company / merchant the payment was made TO (extracted from
  /// "You paid [Company]", "Payment to [Company]", "Merchant: [Name]", etc.)
  final String? referenceCompany;
  final String? senderName;
  final String? receiverName;
  final String? transactionId;
  final String? referenceNumber;
  final String? mtcn;
  final String? invoiceNumber;
  final String? date;
  final String? time;
  final String? currency;
  final AmountField? actualAmountPaid;
  final AmountField? subtotal;
  final AmountField? fee;
  final AmountField? tax;
  final AmountField? discount;
  final AmountField? totalBeforeFee;
  final AmountField? totalAfterFee;
  final String? exchangeRate;
  final String? payoutCurrency;
  final AmountField? payoutAmount;
  final String? paymentMethod;
  final String? status;
  final List<DetectedAmount> rawDetectedAmounts;
  final List<String> notes;
  final double confidenceOverall;

  // ── Convenience getters ───────────────────────────────────────────────────
  double get bestAmount => actualAmountPaid?.value ?? 0.0;
  String get bestCurrency => actualAmountPaid?.currency ?? currency ?? 'BDT';

  const ExtractionResult({
    required this.documentType,
    this.providerOrMerchant,
    this.referenceCompany,
    this.senderName,
    this.receiverName,
    this.transactionId,
    this.referenceNumber,
    this.mtcn,
    this.invoiceNumber,
    this.date,
    this.time,
    this.currency,
    this.actualAmountPaid,
    this.subtotal,
    this.fee,
    this.tax,
    this.discount,
    this.totalBeforeFee,
    this.totalAfterFee,
    this.exchangeRate,
    this.payoutCurrency,
    this.payoutAmount,
    this.paymentMethod,
    this.status,
    required this.rawDetectedAmounts,
    required this.notes,
    required this.confidenceOverall,
  });

  Map<String, dynamic> toJson() => {
        'document_type':        documentType.label,
        'provider_or_merchant': providerOrMerchant,
        'reference_company':    referenceCompany,
        'sender_name':          senderName,
        'receiver_name':        receiverName,
        'transaction_id':       transactionId,
        'reference_number':     referenceNumber,
        'mtcn':                 mtcn,
        'invoice_number':       invoiceNumber,
        'date':                 date,
        'time':                 time,
        'currency':             currency,
        'actual_amount_paid':   actualAmountPaid?.toJson(),
        'subtotal':             subtotal?.toJson(),
        'fee':                  fee?.toJson(),
        'tax':                  tax?.toJson(),
        'discount':             discount?.toJson(),
        'total_before_fee':     totalBeforeFee?.toJson(),
        'total_after_fee':      totalAfterFee?.toJson(),
        'exchange_rate':        exchangeRate,
        'payout_currency':      payoutCurrency,
        'payout_amount':        payoutAmount?.toJson(),
        'payment_method':       paymentMethod,
        'status':               status,
        'raw_detected_amounts': rawDetectedAmounts.map((a) => a.toJson()).toList(),
        'notes':                notes,
        'confidence_overall':   confidenceOverall,
      };
}
