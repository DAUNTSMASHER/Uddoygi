import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static Future<String> _getPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/config.json';
  }

  static Future<void> saveSession(String uid, String email, String role) async {
    final file = File(await _getPath());
    final session = {
      'uid': uid,
      'email': email,
      'role': role,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await file.writeAsString(jsonEncode(session));
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
      await file.writeAsString(jsonEncode({}));
    }
  }

  /// ✅ Update a single field in the session JSON file
  static Future<void> setSessionField(String key, dynamic value) async {
    final file = File(await _getPath());
    Map<String, dynamic> session = {};
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        session = jsonDecode(content);
      }
    }
    session[key] = value;
    await file.writeAsString(jsonEncode(session));
  }
}
