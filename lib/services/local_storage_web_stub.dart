// lib/services/local_storage_web_stub.dart
//
// Web stub for local_storage_mobile.dart.
// These functions are never called on web (LocalStorageService uses
// shared_preferences directly), but the stub is needed so the
// conditional import compiles on web without dart:io.
// ─────────────────────────────────────────────────────────────────────────────

Future<Map<String, dynamic>?> fileGet() async => null;
Future<void> fileSet(Map<String, dynamic> data) async {}
