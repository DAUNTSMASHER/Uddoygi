// lib/features/payments/data/piprapay_remote_datasource.dart
//
// All PipraPay API calls go through your Node.js backend.
// The Flutter client NEVER holds the PipraPay API key.
//
// Backend endpoints expected:
//   POST /api/piprapay/create-charge
//   POST /api/piprapay/verify-payment
//   GET  /api/piprapay/transaction/:ppId
//   GET  /api/piprapay/ping          ← connection test
//
// In mock mode (backendBaseUrl is empty) all methods return simulated responses.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class PipraPayRemoteDataSource {
  final String backendBaseUrl;
  final bool   mockMode;

  const PipraPayRemoteDataSource({
    required this.backendBaseUrl,
    this.mockMode = true,
  });

  // ── Headers ──────────────────────────────────────────────────────────────
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        // Add your backend auth token here if needed:
        // 'Authorization': 'Bearer $backendToken',
      };

  // ── Create Charge ─────────────────────────────────────────────────────────
  /// Initiates a payment. Returns the PipraPay checkout URL + invoice_id.
  Future<CreateChargeResult> createCharge({
    required String orderId,
    required String fullName,
    required String emailOrMobile,
    required double amount,
    required String currency,
    required String redirectUrl,
    required String cancelUrl,
    required String webhookUrl,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (mockMode) return _mockCreateCharge(orderId, amount, currency);

    final uri  = Uri.parse('$backendBaseUrl/api/piprapay/create-charge');
    final body = jsonEncode({
      'orderId':       orderId,
      'fullName':      fullName,
      'emailOrMobile': emailOrMobile,
      'amount':        amount.toStringAsFixed(2),
      'currency':      currency,
      'redirectUrl':   redirectUrl,
      'cancelUrl':     cancelUrl,
      'webhookUrl':    webhookUrl,
      'metadata':      {...metadata, 'order_id': orderId},
    });

    final resp = await http.post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      throw PipraPayException(
          'create-charge failed: ${resp.statusCode} ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return CreateChargeResult(
      checkoutUrl: json['checkoutUrl'] as String? ?? '',
      invoiceId:   json['invoiceId']   as String? ?? '',
      ppId:        json['ppId']        as String? ?? '',
    );
  }

  // ── Verify Payment ────────────────────────────────────────────────────────
  /// Verifies a transaction by pp_id. Returns full payment details.
  Future<VerifyPaymentResult> verifyPayment(String ppId) async {
    if (mockMode) return _mockVerifyPayment(ppId);

    final uri  = Uri.parse('$backendBaseUrl/api/piprapay/verify-payment');
    final body = jsonEncode({'ppId': ppId});

    final resp = await http.post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      throw PipraPayException(
          'verify-payment failed: ${resp.statusCode} ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return VerifyPaymentResult.fromJson(json);
  }

  // ── Fetch Transaction Status ──────────────────────────────────────────────
  Future<VerifyPaymentResult> fetchTransactionStatus(String ppId) async {
    if (mockMode) return _mockVerifyPayment(ppId);

    final uri  = Uri.parse('$backendBaseUrl/api/piprapay/transaction/$ppId');
    final resp = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw PipraPayException(
          'fetch-status failed: ${resp.statusCode} ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return VerifyPaymentResult.fromJson(json);
  }

  // ── Ping / Connection Test ────────────────────────────────────────────────
  Future<bool> ping() async {
    if (mockMode) return true;
    try {
      final uri  = Uri.parse('$backendBaseUrl/api/piprapay/ping');
      final resp = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Mock helpers ──────────────────────────────────────────────────────────
  CreateChargeResult _mockCreateCharge(
      String orderId, double amount, String currency) {
    final fakeId = const Uuid().v4().substring(0, 8).toUpperCase();
    return CreateChargeResult(
      checkoutUrl: 'https://sandbox.piprapay.com/mock/$fakeId',
      invoiceId:   'INV-$fakeId',
      ppId:        '',
    );
  }

  VerifyPaymentResult _mockVerifyPayment(String ppId) => VerifyPaymentResult(
        ppId:          ppId.isEmpty ? 'MOCK-${const Uuid().v4().substring(0, 6)}' : ppId,
        status:        'completed',
        amount:        '0',
        fee:           '0',
        total:         0,
        currency:      'BDT',
        paymentMethod: 'Mock bKash',
        customerName:  'Mock User',
        emailOrMobile: 'mock@example.com',
        senderNumber:  '01700000000',
        transactionId: 'MOCK-TXN',
        date:          DateTime.now().toIso8601String(),
        metadata:      {},
      );
}

// ── Result types ──────────────────────────────────────────────────────────────
class CreateChargeResult {
  final String checkoutUrl;
  final String invoiceId;
  final String ppId;
  const CreateChargeResult({
    required this.checkoutUrl,
    required this.invoiceId,
    required this.ppId,
  });
}

class VerifyPaymentResult {
  final String ppId;
  final String status;
  final String amount;
  final String fee;
  final num    total;
  final String currency;
  final String paymentMethod;
  final String customerName;
  final String emailOrMobile;
  final String senderNumber;
  final String transactionId;
  final String date;
  final Map<String, dynamic> metadata;

  const VerifyPaymentResult({
    required this.ppId,
    required this.status,
    required this.amount,
    required this.fee,
    required this.total,
    required this.currency,
    required this.paymentMethod,
    required this.customerName,
    required this.emailOrMobile,
    required this.senderNumber,
    required this.transactionId,
    required this.date,
    required this.metadata,
  });

  factory VerifyPaymentResult.fromJson(Map<String, dynamic> j) =>
      VerifyPaymentResult(
        ppId:          j['pp_id']                   as String? ?? '',
        status:        j['status']                  as String? ?? 'pending',
        amount:        (j['amount'] ?? '0').toString(),
        fee:           (j['fee']    ?? '0').toString(),
        total:         j['total']   as num?         ?? 0,
        currency:      j['currency']                as String? ?? 'BDT',
        paymentMethod: j['payment_method']          as String? ?? '',
        customerName:  j['customer_name']           as String? ?? '',
        emailOrMobile: j['customer_email_mobile']   as String? ?? '',
        senderNumber:  j['sender_number']           as String? ?? '',
        transactionId: j['transaction_id']          as String? ?? '',
        date:          j['date']                    as String? ?? '',
        metadata:      (j['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
      );
}

class PipraPayException implements Exception {
  final String message;
  const PipraPayException(this.message);
  @override
  String toString() => 'PipraPayException: $message';
}
