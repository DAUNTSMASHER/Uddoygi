// lib/push/fcm_register.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Requests runtime permission, obtains an FCM token, and persists it under:
/// users/{uid}/fcmTokens/{token}
Future<void> registerForPushNotifications() async {
  final msg = FirebaseMessaging.instance;

  // Android 13+ runtime permission; iOS explicit permission
  await msg.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  // (iOS) request APNs token as well
  try {
    await msg.getAPNSToken();
  } catch (_) {}

  // Obtain the FCM token
  final token = await msg.getToken();
  final user = FirebaseAuth.instance.currentUser;

  if (token != null) {
    // Helpful for debugging delivery
    // ignore: avoid_print
    print('FCM token: $token');
  }

  if (user != null && token != null) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('fcmTokens')
        .doc(token);

    await ref.set({
      'token': token,
      'platform': Platform.operatingSystem,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Keep Firestore up to date when token rotates
  msg.onTokenRefresh.listen((t) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .collection('fcmTokens')
        .doc(t)
        .set({
      'token': t,
      'platform': Platform.operatingSystem,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}
