// lib/features/payments/data/piprapay_repository.dart
//
// Single source of truth for all PipraPay + Firestore operations.
// Combines remote API calls (via PipraPayRemoteDataSource) with
// local Firestore persistence (via DB.colSync).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/beneficiary_model.dart';
import '../domain/models/money_source_model.dart';
import '../domain/models/payment_settings_model.dart';
import '../domain/models/pipra_txn_model.dart';
import 'piprapay_remote_datasource.dart';

class PipraPayRepository {
  final String cid;

  PipraPayRepository({required this.cid});

  // ── Settings ──────────────────────────────────────────────────────────────
  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      DB.colSync(cid, C.paymentSettings).doc('piprapay');

  Stream<PaymentSettingsModel> watchSettings() =>
      _settingsRef.snapshots().map((s) => s.exists
          ? PaymentSettingsModel.fromMap(s.data()!)
          : const PaymentSettingsModel());

  Future<PaymentSettingsModel> getSettings() async {
    final s = await _settingsRef.get();
    return s.exists
        ? PaymentSettingsModel.fromMap(s.data()!)
        : const PaymentSettingsModel();
  }

  Future<void> saveSettings(PaymentSettingsModel settings) =>
      _settingsRef.set(settings.toMap(), SetOptions(merge: true));

  Future<bool> testConnection(String backendBaseUrl) async {
    final ds = PipraPayRemoteDataSource(
        backendBaseUrl: backendBaseUrl, mockMode: backendBaseUrl.isEmpty);
    final ok = await ds.ping();
    await _settingsRef.set({
      'connectionStatus': ok ? 'connected' : 'disconnected',
      'lastVerifiedAt':   FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ok;
  }

  // ── Money Sources ─────────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _sourcesCol =>
      DB.colSync(cid, C.moneySources);

  Stream<List<MoneySourceModel>> watchMoneySources() =>
      _sourcesCol.orderBy('isDefault', descending: true).snapshots().map(
            (s) => s.docs.map(MoneySourceModel.fromDoc).toList(),
          );

  Future<void> addMoneySource(MoneySourceModel src) async {
    final batch = DB.firestore.batch();
    if (src.isDefault) {
      // Clear existing default
      final existing = await _sourcesCol
          .where('isDefault', isEqualTo: true)
          .get();
      for (final d in existing.docs) {
        batch.update(d.reference, {'isDefault': false});
      }
    }
    final ref = _sourcesCol.doc();
    batch.set(ref, {...src.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  Future<void> updateMoneySource(MoneySourceModel src) async {
    final batch = DB.firestore.batch();
    if (src.isDefault) {
      final existing = await _sourcesCol
          .where('isDefault', isEqualTo: true)
          .get();
      for (final d in existing.docs) {
        if (d.id != src.id) batch.update(d.reference, {'isDefault': false});
      }
    }
    batch.update(_sourcesCol.doc(src.id), src.toMap());
    await batch.commit();
  }

  Future<void> deleteMoneySource(String id) =>
      _sourcesCol.doc(id).delete();

  // ── Beneficiaries ─────────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _benCol =>
      DB.colSync(cid, C.beneficiaries);

  Stream<List<BeneficiaryModel>> watchBeneficiaries() =>
      _benCol.orderBy('name').snapshots().map(
            (s) => s.docs.map(BeneficiaryModel.fromDoc).toList(),
          );

  Future<void> addBeneficiary(BeneficiaryModel b) => _benCol.add(
        {...b.toMap(), 'createdAt': FieldValue.serverTimestamp()},
      );

  Future<void> updateBeneficiary(BeneficiaryModel b) =>
      _benCol.doc(b.id).update(b.toMap());

  Future<void> deleteBeneficiary(String id) => _benCol.doc(id).delete();

  // ── Transactions ──────────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _txnCol =>
      DB.colSync(cid, C.pipraTxns);

  Stream<List<PipraTxnModel>> watchTransactions({int limit = 50}) =>
      _txnCol
          .orderBy('initiatedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(PipraTxnModel.fromDoc).toList());

  Future<List<PipraTxnModel>> getTransactions({
    DateTime? from,
    DateTime? to,
    TxnStatus? status,
    int limit = 100,
  }) async {
    Query<Map<String, dynamic>> q =
        _txnCol.orderBy('initiatedAt', descending: true);
    if (from != null) {
      q = q.where('initiatedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('initiatedAt',
          isLessThanOrEqualTo: Timestamp.fromDate(to));
    }
    if (status != null) {
      q = q.where('status', isEqualTo: status.name);
    }
    final snap = await q.limit(limit).get();
    return snap.docs.map(PipraTxnModel.fromDoc).toList();
  }

  // ── Initiate Payment ──────────────────────────────────────────────────────
  /// Creates a local Firestore record, then calls the backend to get a
  /// PipraPay checkout URL. Returns the checkout URL.
  Future<InitiatePaymentResult> initiatePayment({
    required BeneficiaryModel beneficiary,
    required double           amount,
    required PaymentSettingsModel settings,
    String notes = '',
  }) async {
    final orderId = const Uuid().v4();

    // 1. Persist pending transaction locally
    final txnRef = _txnCol.doc(orderId);
    final txn = PipraTxnModel(
      id:              orderId,
      beneficiaryId:   beneficiary.id,
      beneficiaryName: beneficiary.name,
      emailOrMobile:   beneficiary.emailOrMobile,
      amount:          amount,
      currency:        settings.currency,
      notes:           notes,
      isSandbox:       settings.sandboxMode,
      status:          TxnStatus.pending,
      metadata:        {'order_id': orderId},
    );
    await txnRef.set(txn.toMap());

    // 2. Call backend
    final ds = PipraPayRemoteDataSource(
      backendBaseUrl: settings.backendBaseUrl,
      mockMode:       settings.backendBaseUrl.isEmpty,
    );

    try {
      final result = await ds.createCharge(
        orderId:       orderId,
        fullName:      beneficiary.name,
        emailOrMobile: beneficiary.emailOrMobile,
        amount:        amount,
        currency:      settings.currency,
        redirectUrl:   settings.defaultRedirectUrl.isNotEmpty
            ? settings.defaultRedirectUrl
            : 'https://yourapp.com/payment/success',
        cancelUrl:     settings.defaultCancelUrl.isNotEmpty
            ? settings.defaultCancelUrl
            : 'https://yourapp.com/payment/cancel',
        webhookUrl:    settings.defaultWebhookUrl.isNotEmpty
            ? settings.defaultWebhookUrl
            : 'https://yourserver.com/api/piprapay/webhook',
        metadata:      {'order_id': orderId},
      );

      // 3. Update with invoice_id
      await txnRef.update({
        'invoiceId': result.invoiceId,
        'ppId':      result.ppId,
        'status':    TxnStatus.processing.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return InitiatePaymentResult(
        orderId:     orderId,
        checkoutUrl: result.checkoutUrl,
        invoiceId:   result.invoiceId,
      );
    } catch (e) {
      await txnRef.update({
        'status':    TxnStatus.failed.name,
        'notes':     'Charge creation failed: $e',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      rethrow;
    }
  }

  // ── Verify & Update ───────────────────────────────────────────────────────
  Future<PipraTxnModel> verifyAndUpdate(
      String orderId, String ppId, PaymentSettingsModel settings) async {
    final ds = PipraPayRemoteDataSource(
      backendBaseUrl: settings.backendBaseUrl,
      mockMode:       settings.backendBaseUrl.isEmpty,
    );

    final result = await ds.verifyPayment(ppId);
    final status = TxnStatusX.fromString(result.status);

    await _txnCol.doc(orderId).update({
      'ppId':          ppId,
      'status':        status.name,
      'fee':           double.tryParse(result.fee) ?? 0,
      'total':         result.total.toDouble(),
      'paymentMethod': result.paymentMethod,
      'senderNumber':  result.senderNumber,
      'transactionId': result.transactionId,
      'paidAt':        status == TxnStatus.paid
          ? FieldValue.serverTimestamp()
          : null,
      'updatedAt':     FieldValue.serverTimestamp(),
    });

    final snap = await _txnCol.doc(orderId).get();
    return PipraTxnModel.fromDoc(snap);
  }
}

class InitiatePaymentResult {
  final String orderId;
  final String checkoutUrl;
  final String invoiceId;
  const InitiatePaymentResult({
    required this.orderId,
    required this.checkoutUrl,
    required this.invoiceId,
  });
}
