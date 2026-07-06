// lib/services/local_storage_mobile.dart
//
// Mobile-only implementation of session storage using a JSON file.
// This file is only imported on non-web platforms.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> _getPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/config.json';
}

/// Read session from file. Returns null if file doesn't exist or is empty.
Future<Map<String, dynamic>?> fileGet() async {
  try {
    final file = File(await _getPath());
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    if (content.isEmpty) return null;
    return jsonDecode(content) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// Write session to file.
Future<void> fileSet(Map<String, dynamic> data) async {
  try {
    final file = File(await _getPath());
    await file.writeAsString(jsonEncode(data));
  } catch (_) {}
}
