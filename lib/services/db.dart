// lib/services/db.dart
//
// Central Firestore path helper — multi-tenant structure.
//
// NEW DATABASE STRUCTURE:
//   companies/{companyId}                    ← company registry (login/lookup)
//   data/{companyId}/users/{uid}             ← all business data lives here
//   data/{companyId}/invoices/{id}
//   data/{companyId}/payrolls/{id}
//   ... (every collection is a subcollection under data/{companyId})
//
// USAGE (anywhere in the app):
//   final col = DB.colSync(_cid, 'invoices');          // CollectionReference
//   final doc = await DB.doc('invoices', id);       // DocumentReference
//   final fs  = DB.firestore;                        // raw FirebaseFirestore
//
// The companyId is read from LocalStorageService automatically.
// No file needs to know the companyId — DB handles it.
// ─────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import 'local_storage_service.dart';

class DB {
  DB._();

  // ── Raw Firestore instance ────────────────────────────────
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  // ── Root path: data/{companyId} ───────────────────────────
  // Returns the DocumentReference that is the root for all
  // company-scoped data.

  static Future<DocumentReference<Map<String, dynamic>>> _root() async {
    final cid = await LocalStorageService.getSavedCompanyId();
    return firestore.collection('data').doc(cid ?? '');
  }

  // ── Synchronous root (use only when companyId is guaranteed cached) ──
  static DocumentReference<Map<String, dynamic>> _rootSync(String companyId) {
    return firestore.collection('data').doc(companyId);
  }

  // ─────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────

  /// Returns a CollectionReference scoped to the current company.
  /// Usage:  final col = DB.colSync(_cid, 'invoices');
  static Future<CollectionReference<Map<String, dynamic>>> col(
      String collectionName) async {
    final root = await _root();
    return root.collection(collectionName);
  }

  /// Returns a DocumentReference scoped to the current company.
  /// Usage:  final ref = await DB.doc('invoices', invoiceId);
  static Future<DocumentReference<Map<String, dynamic>>> doc(
      String collectionName, String docId) async {
    final root = await _root();
    final effDocId = docId.isEmpty ? 'default_doc' : docId;
    return root.collection(collectionName).doc(effDocId);
  }

  /// Returns a new auto-ID DocumentReference (for .add() equivalent).
  /// Usage:  final ref = await DB.newDoc('notifications');
  static Future<DocumentReference<Map<String, dynamic>>> newDoc(
      String collectionName) async {
    final root = await _root();
    return root.collection(collectionName).doc();
  }

  /// Returns a subcollection reference.
  /// Usage:  final sub = await DB.subCol('loans', loanId, 'repayments');
  static Future<CollectionReference<Map<String, dynamic>>> subCol(
      String parentCol, String parentId, String subColName) async {
    final root = await _root();
    final effParentId = parentId.isEmpty ? 'default_parent' : parentId;
    return root.collection(parentCol).doc(effParentId).collection(subColName);
  }

  /// Returns a subcollection document reference.
  /// Usage:  final ref = await DB.subDoc('loans', loanId, 'repayments', repId);
  static Future<DocumentReference<Map<String, dynamic>>> subDoc(
      String parentCol, String parentId, String subColName,
      String subDocId) async {
    final root = await _root();
    final effParentId = parentId.isEmpty ? 'default_parent' : parentId;
    final effSubDocId = subDocId.isEmpty ? 'default_subdoc' : subDocId;
    return root
        .collection(parentCol)
        .doc(effParentId)
        .collection(subColName)
        .doc(effSubDocId);
  }

  // ── Synchronous versions (when companyId is already known) ──

  /// Synchronous col — use when you already have the companyId.
  static CollectionReference<Map<String, dynamic>> colSync(
      String companyId, String collectionName) {
    return _rootSync(companyId).collection(collectionName);
  }

  /// Synchronous doc — use when you already have the companyId.
  static DocumentReference<Map<String, dynamic>> docSync(
      String companyId, String collectionName, String docId) {
    final effDocId = docId.isEmpty ? 'default_doc' : docId;
    return _rootSync(companyId).collection(collectionName).doc(effDocId);
  }

  /// Synchronous subcollection — company-scoped.
  /// Usage: DB.subColSync(_cid, 'loans', loanId, 'repayments')
  /// Path:  data/{cid}/{parentCol}/{parentId}/{subColName}
  static CollectionReference<Map<String, dynamic>> subColSync(
      String companyId, String parentCol, String parentId, String subColName) {
    final effParentId = parentId.isEmpty ? 'default_parent' : parentId;
    return _rootSync(companyId)
        .collection(parentCol)
        .doc(effParentId)
        .collection(subColName);
  }

  // ── Special collections that are NOT company-scoped ──────
  // These live at the root of Firestore (not under data/{companyId})
  // because they are used for login/lookup before companyId is known.

  /// companies/{companyId} — company registry (login screen lookup)
  static CollectionReference<Map<String, dynamic>> get companiesCol =>
      firestore.collection('companies');

  static DocumentReference<Map<String, dynamic>> companyDoc(
          String companyId) {
    return firestore.collection('companies').doc(companyId);
  }

  // ── users subcollections (presence/FCM — also root-scoped) ──
  // FCM tokens and device presence are keyed by Firebase Auth UID
  // and need to be accessible before company context is loaded.

  /// users/{uid}/fcmTokens/{token}
  static CollectionReference<Map<String, dynamic>> fcmTokensCol(String uid) {
    final effUid = uid.isEmpty ? 'default_uid' : uid;
    return firestore.collection('users').doc(effUid).collection('fcmTokens');
  }

  /// users/{uid}/devices/{deviceId}
  static CollectionReference<Map<String, dynamic>> devicesCol(String uid) {
    final effUid = uid.isEmpty ? 'default_uid' : uid;
    return firestore.collection('users').doc(effUid).collection('devices');
  }

  // ── Convenience: stream a collection ─────────────────────
  /// Returns a Stream of QuerySnapshot for a company-scoped collection.
  /// Usage:  DB.stream('invoices').listen(...)
  static Stream<QuerySnapshot<Map<String, dynamic>>> stream(
      String collectionName,
      {Query<Map<String, dynamic>> Function(
              CollectionReference<Map<String, dynamic>>)?
          query}) async* {
    final c = await col(collectionName);
    yield* (query != null ? query(c) : c).snapshots();
  }

  // ── Path string helpers (for debugging / logging) ─────────
  static Future<String> pathOf(String collectionName) async {
    final cid = await LocalStorageService.getSavedCompanyId();
    return 'data/$cid/$collectionName';
  }
}

// ─────────────────────────────────────────────────────────────
// COLLECTION NAME CONSTANTS
// Use these everywhere instead of raw strings to avoid typos.
// ─────────────────────────────────────────────────────────────
class C {
  C._();

  // Core
  static const users              = 'users';
  static const notifications      = 'notifications';
  static const messages           = 'messages';
  static const notices            = 'notices';
  static const complaints         = 'complaints';
  static const alerts             = 'alerts';
  static const alertDispatch      = 'alert_dispatch';
  static const welfare            = 'welfare';
  static const welfareRequests    = 'welfare_requests';
  static const welfareSchemes     = 'welfare_schemes';

  // HR
  static const employees          = 'employees';
  static const payrolls           = 'payrolls';
  static const salaries           = 'salaries';
  static const leaves             = 'leaves';
  static const leaveRequests      = 'leave_requests';
  static const shifts             = 'shifts';
  static const benefits           = 'benefits';
  static const attendance         = 'attendance';
  static const loans              = 'loans';
  static const loanRequests       = 'loan_requests';
  static const taxes              = 'taxes';
  static const procurements       = 'procurements';
  static const applicants         = 'applicants';
  static const promotions         = 'promotions';
  static const recommendation     = 'recommendation';
  static const hrDocuments        = 'hr_documents';
  static const marketingIncentives = 'marketing_incentives';
  static const punishments        = 'punishments';

  // Finance
  static const invoices           = 'invoices';
  static const paymentSlips       = 'payment_slips';
  static const cashFlow           = 'cash_flow';
  static const expenses           = 'expenses';
  static const ledger             = 'ledger';
  static const budgets            = 'budgets';
  static const budget             = 'budget';
  static const accounts           = 'accounts';
  static const targets            = 'targets';

  // Marketing
  static const customers          = 'customers';
  static const products           = 'products';
  static const productPrices      = 'product_prices';
  static const campaigns          = 'campaigns';
  static const tasks              = 'tasks';
  static const qcReports          = 'qc_reports';
  static const addressValidations = 'address_validations';

  // Factory
  static const workOrders         = 'work_orders';
  static const workOrderTracking  = 'work_order_tracking';
  static const trackingIndex      = 'tracking_index';
  static const dailyProduction    = 'daily_production';
  static const purchaseOrders     = 'purchase_orders';
  static const stocks             = 'stocks';
  static const suppliers          = 'suppliers';

  // R&D
  static const rndRequests        = 'rnd_requests';
  static const rndProjects        = 'rnd_projects';
  static const rndUpdates         = 'rnd_updates';
  static const rndMilestones      = 'rnd_milestones';
  static const rndScores          = 'rnd_scores';

  // Company profile (company-scoped singleton)
  static const companyProfile     = 'company_profile';

  // Subcollection names
  static const comments           = 'comments';
  static const replies            = 'replies';
  static const repayments         = 'repayments';
  static const metrics            = 'metrics';
  static const logs               = 'logs';
  static const fcmTokens          = 'fcmTokens';
  static const devices            = 'devices';
  static const records            = 'records';

  // PipraPay / Payments (company-scoped)
  static const paymentSettings    = 'payment_settings';
  static const moneySources       = 'money_sources';
  static const beneficiaries      = 'beneficiaries';
  static const pipraTxns          = 'pipra_transactions';

  // SMTP (root-level, not company-scoped)
  static const smtpConfig         = 'smtp_config';

  // Tax & Calculations (company-scoped singleton)
  static const taxConfig          = 'tax_config';
}
