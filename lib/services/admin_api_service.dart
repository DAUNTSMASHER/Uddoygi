import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Android emulator uses 10.0.2.2 to reach your Mac.
/// iOS simulator / Web / macOS desktop use localhost.
String _baseUrl() {
  if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
    return 'http://10.0.2.2:8082';
  }
  return 'http://localhost:8082';
}

Future<void> adminSetPassword({
  String? uid,
  String? email,
  required String newPassword,
}) async {
  final resp = await http.post(
    Uri.parse('${_baseUrl()}/setPassword'),
    headers: {
      'Content-Type': 'application/json',
      'x-admin-token': 'supersecret123', // dev only
    },
    body: jsonEncode({
      if (uid != null) 'uid': uid,
      if (email != null) 'email': email,
      'newPassword': newPassword,
    }),
  );

  if (resp.statusCode != 200) {
    throw Exception('Admin API failed: ${resp.statusCode} ${resp.body}');
  }
}
