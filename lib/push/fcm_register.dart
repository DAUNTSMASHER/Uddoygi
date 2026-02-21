// lib/push/fcm_register.dart
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

Future<void> _claimTokenForUser(String uid, String token) async {
  // FCM tokens live at root users/{uid}/fcmTokens — NOT company-scoped.
  // This allows push delivery even before company context is loaded.

  // 1) Remove from any other user's subcollection
  final qSub = await DB.firestore.collectionGroup('fcmTokens')
      .where('token', isEqualTo: token)
      .get();
  for (final d in qSub.docs) {
    final parent = d.reference.parent.parent;
    if (parent == null || parent.id == uid) continue;
    try { await d.reference.delete(); } catch (_) {}
  }

  // 2) Ensure it is present for THIS user (root-level, not company-scoped)
  await DB.fcmTokensCol(uid).doc(token).set({
    'token':     token,
    'platform':  Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other',
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> registerForPushNotifications() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final fm = FirebaseMessaging.instance;
  try { await fm.requestPermission(alert: true, badge: true, sound: true); } catch (_) {}

  var token = await fm.getToken();
  if (token == null || token.trim().isEmpty) {
    await Future.delayed(const Duration(milliseconds: 500));
    token = await fm.getToken();
  }
  if (token == null || token.trim().isEmpty) return;

  await _claimTokenForUser(user.uid, token);

  // Keep token fresh
  fm.onTokenRefresh.listen((newT) async {
    if (newT.trim().isEmpty) return;
    await _claimTokenForUser(user.uid, newT);
  });
}
