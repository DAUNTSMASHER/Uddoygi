// lib/services/local_storage_service.dart
//
// Cross-platform local storage:
//   • Web:    uses shared_preferences (localStorage under the hood)
//   • Mobile: uses a JSON file in the app documents directory
//
// All public methods are identical on both platforms.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_rules.dart';

// Mobile-only imports — guarded by kIsWeb checks at runtime
// (dart:io and path_provider are not available on web)
import 'local_storage_mobile.dart'
    if (dart.library.html) 'local_storage_web_stub.dart' as mobile_storage;

class LocalStorageService {
  static const _kSession = 'uddyogi_session';

  // ── Read raw JSON map ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getSession() async {
    if (kIsWeb) {
      return _webGet();
    } else {
      return mobile_storage.fileGet();
    }
  }

  // ── Write raw JSON map ─────────────────────────────────────────────────────
  static Future<void> _setAll(Map<String, dynamic> data) async {
    if (kIsWeb) {
      await _webSet(data);
    } else {
      await mobile_storage.fileSet(data);
    }
  }

  // ── Save session (uid + email + role), preserving companyId ───────────────
  static Future<void> saveSession(String uid, String email, String role) async {
    final existing = await getSession() ?? {};
    existing.addAll({
      'uid':       uid,
      'email':     email,
      'role':      role,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _setAll(existing);
  }

  // ── Clear session but keep companyId ──────────────────────────────────────
  static Future<void> clearSession() async {
    final existing = await getSession() ?? {};
    final companyId = existing['companyId'];
    final next = <String, dynamic>{};
    if (companyId != null) next['companyId'] = companyId;
    await _setAll(next);
  }

  // ── Update a single field ─────────────────────────────────────────────────
  static Future<void> setSessionField(String key, dynamic value) async {
    final session = await getSession() ?? {};
    session[key] = value;
    await _setAll(session);
  }

  // ── Company ID helpers ────────────────────────────────────────────────────
  static Future<void> saveCompanyId(String companyId) =>
      setSessionField('companyId', companyId);

  static Future<String?> getSavedCompanyId() async {
    final session = await getSession();
    final val = session?['companyId'];
    if (val is String && val.isNotEmpty) return val;
    return null;
  }

  static Future<void> clearCompanyId() => setSessionField('companyId', '');

  // ── Centralised logout ────────────────────────────────────────────────────
  static Future<void> performLogout() async {
    AppRules.instance.clearSession();
    await clearSession();
    await FirebaseAuth.instance.signOut();
  }

  // ── Web implementation (shared_preferences / localStorage) ────────────────
  static Future<Map<String, dynamic>?> _webGet() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _webSet(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSession, jsonEncode(data));
  }
}
