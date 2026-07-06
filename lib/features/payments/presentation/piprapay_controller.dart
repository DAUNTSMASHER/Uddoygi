// lib/features/payments/presentation/piprapay_controller.dart
//
// Lightweight ChangeNotifier-style controller (matches the project's existing
// StatefulWidget + setState pattern — no extra state-management package needed).
// Screens can use this directly or wrap in an InheritedWidget if needed.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../data/piprapay_repository.dart';
import '../domain/models/beneficiary_model.dart';
import '../domain/models/money_source_model.dart';
import '../domain/models/payment_settings_model.dart';
import '../domain/models/pipra_txn_model.dart';

class PipraPayController extends ChangeNotifier {
  final PipraPayRepository _repo;

  PipraPayController({required String cid})
      : _repo = PipraPayRepository(cid: cid);

  // ── State ─────────────────────────────────────────────────────────────────
  bool   _loading = false;
  String _error   = '';

  bool   get loading => _loading;
  String get error   => _error;

  void _setLoading(bool v) { _loading = v; notifyListeners(); }
  void _setError(String e) { _error   = e; notifyListeners(); }
  void clearError()        { _error   = ''; notifyListeners(); }

  // ── Settings ──────────────────────────────────────────────────────────────
  Stream<PaymentSettingsModel> watchSettings() => _repo.watchSettings();

  Future<void> saveSettings(PaymentSettingsModel s) async {
    _setLoading(true);
    try {
      await _repo.saveSettings(s);
      _setError('');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> testConnection(String url) async {
    _setLoading(true);
    try {
      final ok = await _repo.testConnection(url);
      _setError('');
      return ok;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Money Sources ─────────────────────────────────────────────────────────
  Stream<List<MoneySourceModel>> watchMoneySources() =>
      _repo.watchMoneySources();

  Future<void> addMoneySource(MoneySourceModel src) async {
    _setLoading(true);
    try {
      await _repo.addMoneySource(src);
      _setError('');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateMoneySource(MoneySourceModel src) async {
    _setLoading(true);
    try {
      await _repo.updateMoneySource(src);
      _setError('');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteMoneySource(String id) async {
    _setLoading(true);
    try {
      await _repo.deleteMoneySource(id);
      _setError('');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ── Beneficiaries ─────────────────────────────────────────────────────────
  Stream<List<BeneficiaryModel>> watchBeneficiaries() =>
      _repo.watchBeneficiaries();

  Future<void> addBeneficiary(BeneficiaryModel b) async {
    _setLoading(true);
    try {
      await _repo.addBeneficiary(b);
      _setError('');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateBeneficiary(BeneficiaryModel b) async {
    _setLoading(true);
    try {
      await _repo.updateBeneficiary(b);
      _setError('');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteBeneficiary(String id) async {
    _setLoading(true);
    try {
      await _repo.deleteBeneficiary(id);
      _setError('');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ── Transactions ──────────────────────────────────────────────────────────
  Stream<List<PipraTxnModel>> watchTransactions({int limit = 50}) =>
      _repo.watchTransactions(limit: limit);

  Future<InitiatePaymentResult> initiatePayment({
    required BeneficiaryModel     beneficiary,
    required double               amount,
    required PaymentSettingsModel settings,
    String notes = '',
  }) async {
    _setLoading(true);
    try {
      final result = await _repo.initiatePayment(
        beneficiary: beneficiary,
        amount:      amount,
        settings:    settings,
        notes:       notes,
      );
      _setError('');
      return result;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<PipraTxnModel> verifyAndUpdate(
      String orderId, String ppId, PaymentSettingsModel settings) async {
    _setLoading(true);
    try {
      final txn = await _repo.verifyAndUpdate(orderId, ppId, settings);
      _setError('');
      return txn;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
