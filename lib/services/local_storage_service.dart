import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'app_rules.dart';

class LocalStorageService {
  static Future<String> _getPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/config.json';
  }

  static Future<void> saveSession(String uid, String email, String role) async {
    final file = File(await _getPath());
    // Preserve existing fields (e.g. companyId) when saving session
    Map<String, dynamic> existing = {};
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        try { existing = jsonDecode(content); } catch (_) {}
      }
    }
    existing.addAll({
      'uid': uid,
      'email': email,
      'role': role,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await file.writeAsString(jsonEncode(existing));
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final file = File(await _getPath());
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return content.isNotEmpty ? jsonDecode(content) : null;
  }

  static Future<void> clearSession() async {
    final file = File(await _getPath());
    if (await file.exists()) {
      // Keep companyId across logouts so user doesn't retype it
      final existing = await getSession() ?? {};
      final companyId = existing['companyId'];
      final next = <String, dynamic>{};
      if (companyId != null) next['companyId'] = companyId;
      await file.writeAsString(jsonEncode(next));
    }
  }

  /// Update a single field in the session JSON file.
  static Future<void> setSessionField(String key, dynamic value) async {
    final file = File(await _getPath());
    Map<String, dynamic> session = {};
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        try { session = jsonDecode(content); } catch (_) {}
      }
    }
    session[key] = value;
    await file.writeAsString(jsonEncode(session));
  }

  // ── Company ID helpers ─────────────────────────────────────

  /// Persist the company ID locally so users don't retype it.
  static Future<void> saveCompanyId(String companyId) =>
      setSessionField('companyId', companyId);

  /// Read the locally stored company ID (null if never saved).
  static Future<String?> getSavedCompanyId() async {
    final session = await getSession();
    final val = session?['companyId'];
    if (val is String && val.isNotEmpty) return val;
    return null;
  }

  /// Remove only the company ID (e.g. user wants to switch company).
  static Future<void> clearCompanyId() => setSessionField('companyId', '');

  // ── Centralised logout ─────────────────────────────────────
  //
  // Always call this instead of calling signOut() + clearSession() manually.
  // Order matters:
  //   1. clearSession()  — wipe local credentials first so no stale reads
  //   2. signOut()       — revoke Firebase Auth token (triggers authStateChanges)
  //
  // DevicePresence.stop() is intentionally NOT called here because it needs
  // to write to Firestore while the user is still authenticated.
  // Callers that want to mark the device offline should call
  //   DevicePresence.instance.stop()  BEFORE calling AppLogout.perform().
  static Future<void> performLogout() async {
    AppRules.instance.clearSession(); // clear app-level rules first
    await clearSession();             // clear local storage
    await FirebaseAuth.instance.signOut(); // revoke Firebase token last
  }
}
