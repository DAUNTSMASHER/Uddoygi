// lib/push/fcm_register.dart
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> _claimTokenForUser(String uid, String token) async {
  final db = FirebaseFirestore.instance;

  // 1) Remove from any other user's top-level array
  final qArr = await db.collection('users')
      .where('fcmTokens', arrayContains: token)
      .get();
  for (final d in qArr.docs) {
    if (d.id == uid) continue;
    try {
      await d.reference.update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (_) {}
  }

  // 2) Remove from any other user's subcollection
  final qSub = await db.collectionGroup('fcmTokens')
      .where('token', isEqualTo: token)
      .get();
  for (final d in qSub.docs) {
    final parent = d.reference.parent.parent; // users/{otherUid}
    if (parent == null || parent.id == uid) continue;
    try {
      await d.reference.delete();
    } catch (_) {}
  }

  // 3) Ensure it is present for THIS user
  final userRef = db.collection('users').doc(uid);
  await userRef.set({
    'fcmTokens': FieldValue.arrayUnion([token]),
  }, SetOptions(merge: true));

  await userRef.collection('fcmTokens').doc(token).set({
    'token': token,
    'platform': Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other',
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
