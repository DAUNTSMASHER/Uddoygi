// lib/services/app_rules.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// APP-LEVEL RULE ENGINE  (runs alongside Firebase/Firestore rules)
//
// TWO LAYERS OF RULES:
//   Layer 1 — Firebase rules (server-side, deployed in Firebase Console):
//     • companies/{id}  → allow read if isActive == true
//     • everything else → allow read, write if request.auth != null
//
//   Layer 2 — AppRules (client-side, enforced HERE before any Firestore call):
//     • Company isolation : user can ONLY access their own companyId
//     • Role-based access : each role has a defined set of allowed collections
//     • Action control    : read / write / delete per collection per role
//     • Screen guard      : widgets check permission before rendering
//
// BOTH layers must pass for data to flow.
// AppRules runs first — if it denies, the request never reaches Firestore.
//
// USAGE:
//   // Load once at login (call from main.dart _handleLogin)
//   AppRules.instance.loadSession(uid: uid, companyId: cid, role: role);
//
//   // Check anywhere in the app
//   if (AppRules.instance.canRead('invoices'))  { ... }
//   if (AppRules.instance.canWrite('employees')) { ... }
//   AppRules.instance.assertRead('invoices');    // throws AppRulesDeniedException
//
//   // In widgets — wrap with AppRulesGuard (see app_rules_guard.dart)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';

// ── Permission levels ─────────────────────────────────────────
enum AppPermission { read, write, delete }

// ── Access denied exception ───────────────────────────────────
class AppRulesDeniedException implements Exception {
  final String message;
  const AppRulesDeniedException(this.message);
  @override
  String toString() => message;
}

// ─────────────────────────────────────────────────────────────
// ROLE POLICY  — what each role can read / write / delete
// ─────────────────────────────────────────────────────────────
class _RolePolicy {
  final Set<String> readable;
  final Set<String> writable;
  final Set<String> deletable;
  const _RolePolicy({
    required this.readable,
    required this.writable,
    this.deletable = const {},
  });
}

// All collections — used by admin (full access)
const _all = {
  'users', 'notifications', 'messages', 'notices', 'complaints',
  'alerts', 'alert_dispatch', 'welfare', 'welfare_requests', 'welfare_schemes',
  'employees', 'payrolls', 'salaries', 'leaves', 'leave_requests',
  'shifts', 'benefits', 'attendance', 'loans', 'loan_requests',
  'taxes', 'procurements', 'applicants', 'promotions', 'recommendation',
  'hr_documents', 'marketing_incentives', 'punishments',
  'invoices', 'payment_slips', 'cash_flow', 'expenses', 'ledger',
  'budgets', 'budget', 'accounts', 'targets',
  'customers', 'products', 'product_prices', 'campaigns', 'tasks',
  'qc_reports', 'address_validations',
  'work_orders', 'work_order_tracking', 'tracking_index',
  'daily_production', 'purchase_orders', 'stocks',
  'rnd_requests', 'rnd_projects', 'rnd_updates', 'rnd_milestones', 'rnd_scores',
  'company_profile', 'smtp_config',
};

// Role → policy table
const Map<String, _RolePolicy> _policies = {

  'admin': _RolePolicy(readable: _all, writable: _all, deletable: _all),

  'hr': _RolePolicy(
    readable: {
      'employees', 'payrolls', 'salaries', 'leaves', 'leave_requests',
      'shifts', 'benefits', 'attendance', 'loans', 'loan_requests',
      'taxes', 'procurements', 'applicants', 'promotions', 'recommendation',
      'hr_documents', 'marketing_incentives', 'punishments',
      'cash_flow', 'expenses', 'budgets', 'budget', 'accounts', 'targets',
      'ledger', 'payment_slips', 'invoices',
      'notifications', 'notices', 'welfare', 'welfare_requests',
      'welfare_schemes', 'complaints', 'messages', 'alerts', 'alert_dispatch',
      'company_profile', 'users', 'tasks',
    },
    writable: {
      'employees', 'payrolls', 'salaries', 'leaves', 'leave_requests',
      'shifts', 'benefits', 'attendance', 'loans', 'loan_requests',
      'taxes', 'procurements', 'applicants', 'promotions', 'recommendation',
      'hr_documents', 'marketing_incentives', 'punishments',
      'cash_flow', 'expenses', 'budgets', 'budget', 'accounts', 'targets',
      'ledger', 'payment_slips', 'invoices',
      'notifications', 'notices', 'welfare', 'welfare_requests',
      'welfare_schemes', 'complaints', 'messages', 'alerts', 'alert_dispatch',
      'company_profile',
    },
    deletable: {
      'leaves', 'leave_requests', 'loan_requests',
      'welfare_requests', 'applicants', 'notices',
    },
  ),

  'factory': _RolePolicy(
    readable: {
      'work_orders', 'work_order_tracking', 'tracking_index',
      'daily_production', 'purchase_orders', 'stocks',
      'qc_reports', 'rnd_requests', 'tasks',
      'notifications', 'messages', 'complaints', 'alerts',
      'employees', 'users',
    },
    writable: {
      'work_orders', 'work_order_tracking', 'tracking_index',
      'daily_production', 'purchase_orders', 'stocks',
      'qc_reports', 'rnd_requests', 'tasks',
      'notifications', 'messages', 'complaints', 'alerts',
    },
    deletable: {'tasks', 'rnd_requests'},
  ),

  'marketing': _RolePolicy(
    readable: {
      'customers', 'products', 'product_prices', 'campaigns', 'tasks',
      'invoices', 'payment_slips', 'qc_reports', 'address_validations',
      'work_orders', 'rnd_requests',
      'notifications', 'messages', 'complaints', 'alerts',
      'employees', 'users',
    },
    writable: {
      'customers', 'products', 'product_prices', 'campaigns', 'tasks',
      'invoices', 'payment_slips', 'qc_reports', 'address_validations',
      'work_orders', 'rnd_requests',
      'notifications', 'messages', 'complaints', 'alerts',
    },
    deletable: {'tasks', 'campaigns'},
  ),

  'rnd': _RolePolicy(
    readable: {
      'rnd_requests', 'rnd_projects', 'rnd_updates', 'rnd_milestones',
      'rnd_scores', 'tasks',
      'notifications', 'messages', 'complaints', 'alerts',
      'employees', 'users',
    },
    writable: {
      'rnd_requests', 'rnd_projects', 'rnd_updates', 'rnd_milestones',
      'rnd_scores', 'tasks',
      'notifications', 'messages', 'complaints', 'alerts',
    },
    deletable: {'rnd_updates', 'tasks'},
  ),
};

// ─────────────────────────────────────────────────────────────
// SCREEN ACCESS MAP
// Maps screen/feature names → roles that may access them.
// ─────────────────────────────────────────────────────────────
const Map<String, Set<String>> _screenAccess = {
  'admin_dashboard':     {'admin'},
  'admin_settings':      {'admin'},
  'company_profile':     {'admin'},
  'all_employees':       {'admin', 'hr'},
  'payroll':             {'admin', 'hr'},
  'roi_dashboard':       {'admin', 'hr'},
  'hr_dashboard':        {'admin', 'hr'},
  'attendance':          {'admin', 'hr'},
  'leave_management':    {'admin', 'hr'},
  'loan_management':     {'admin', 'hr'},
  'recruitment':         {'admin', 'hr'},
  'factory_dashboard':   {'admin', 'factory'},
  'work_orders':         {'admin', 'factory', 'marketing'},
  'production':          {'admin', 'factory'},
  'purchase_orders':     {'admin', 'factory', 'hr'},
  'stocks':              {'admin', 'factory'},
  'marketing_dashboard': {'admin', 'marketing'},
  'customers':           {'admin', 'marketing'},
  'invoices':            {'admin', 'marketing', 'hr'},
  'payment_slips':       {'admin', 'marketing', 'hr'},
  'campaigns':           {'admin', 'marketing'},
  'rnd_dashboard':       {'admin', 'rnd'},
  'rnd_projects':        {'admin', 'rnd', 'factory'},
  'rnd_requests':        {'admin', 'rnd', 'factory', 'marketing'},
};

// ─────────────────────────────────────────────────────────────
// APP RULES ENGINE  (singleton)
// ─────────────────────────────────────────────────────────────
class AppRules {
  AppRules._();
  static final instance = AppRules._();

  String _uid       = '';
  String _companyId = '';
  String _role      = '';
  bool   _loaded    = false;

  String get uid       => _uid;
  String get companyId => _companyId;
  String get role      => _role;
  bool   get isLoaded  => _loaded;
  bool   get isAdmin   => _role == 'admin';
  bool   get isHr      => _role == 'hr';

  // ── Load session once at login ────────────────────────────
  void loadSession({
    required String uid,
    required String companyId,
    required String role,
  }) {
    _uid       = uid;
    _companyId = companyId;
    _role      = role.toLowerCase().trim();
    _loaded    = true;
    debugPrint('[AppRules] loaded — uid=$uid cid=$companyId role=$_role');
  }

  // ── Clear at logout ───────────────────────────────────────
  void clearSession() {
    _uid = _companyId = _role = '';
    _loaded = false;
    debugPrint('[AppRules] cleared');
  }

  // ─────────────────────────────────────────────────────────
  // RULE 1 — COMPANY ISOLATION
  // A user can only access data for their own companyId.
  // ─────────────────────────────────────────────────────────
  bool belongsToCompany(String companyId) =>
      _loaded && _companyId == companyId;

  void assertCompany(String companyId) {
    if (!belongsToCompany(companyId)) {
      throw AppRulesDeniedException(
          'Access denied: you do not belong to company $companyId.');
    }
  }

  // ─────────────────────────────────────────────────────────
  // RULE 2 — COLLECTION PERMISSIONS
  // ─────────────────────────────────────────────────────────
  bool canRead(String collection) {
    if (!_loaded) return false;
    if (collection == 'users') return true; // own user doc always readable
    return _policies[_role]?.readable.contains(collection) ?? false;
  }

  bool canWrite(String collection) {
    if (!_loaded) return false;
    if (collection == 'users') return true;
    return _policies[_role]?.writable.contains(collection) ?? false;
  }

  bool canDelete(String collection) {
    if (!_loaded) return false;
    return _policies[_role]?.deletable.contains(collection) ?? false;
  }

  bool can(String collection, AppPermission permission) {
    switch (permission) {
      case AppPermission.read:   return canRead(collection);
      case AppPermission.write:  return canWrite(collection);
      case AppPermission.delete: return canDelete(collection);
    }
  }

  void assertRead(String collection) {
    if (!_loaded) throw const AppRulesDeniedException('Not signed in.');
    if (!canRead(collection)) {
      throw AppRulesDeniedException(
          'Access denied: role "$_role" cannot read "$collection".');
    }
  }

  void assertWrite(String collection) {
    if (!_loaded) throw const AppRulesDeniedException('Not signed in.');
    if (!canWrite(collection)) {
      throw AppRulesDeniedException(
          'Access denied: role "$_role" cannot write to "$collection".');
    }
  }

  void assertDelete(String collection) {
    if (!_loaded) throw const AppRulesDeniedException('Not signed in.');
    if (!canDelete(collection)) {
      throw AppRulesDeniedException(
          'Access denied: role "$_role" cannot delete from "$collection".');
    }
  }

  // ─────────────────────────────────────────────────────────
  // RULE 3 — SCREEN ACCESS
  // ─────────────────────────────────────────────────────────
  bool canAccessScreen(String screenName) {
    if (!_loaded) return false;
    final allowed = _screenAccess[screenName];
    return allowed == null || allowed.contains(_role);
  }

  // ─────────────────────────────────────────────────────────
  // UTILITY
  // ─────────────────────────────────────────────────────────
  static bool isValidCompanyIdFormat(String id) {
    final t = id.trim();
    return t.length == 8 && int.tryParse(t) != null;
  }

  @override
  String toString() =>
      'AppRules(uid=$_uid, cid=$_companyId, role=$_role, loaded=$_loaded)';
}
