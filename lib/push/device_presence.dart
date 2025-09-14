// lib/push/device_presence.dart
//
// Tracks "who is online" by writing to
//   users/{uid}/devices/{deviceId}
// where deviceId = current FCM token (fallback to a random id if token not ready).
//
// Fields written:
//   online: bool
//   lastSeen: serverTimestamp
//   platform: android/ios/other
//   token: current FCM token (if any)
//   app: 'uddoygi'
//
// Call DevicePresence.instance.initialize() once at app start
// (it will auto start/stop on auth changes). You can still call
// start()/stop() manually if you prefer.

import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

class DevicePresence with WidgetsBindingObserver {
  DevicePresence._();
  static final DevicePresence instance = DevicePresence._();

  bool _started = false;
  DocumentReference<Map<String, dynamic>>? _docRef;
  Timer? _heartbeat;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenSub;

  /// Set up auth listener so presence starts on login and
  /// stops on logout automatically.
  void initialize() {
    // Ensure we don't attach multiple listeners.
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await start();
      } else {
        await stop();
      }
    });
  }

  /// Begin tracking presence for the current user.
  Future<void> start() async {
    if (_started) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Try to get an FCM token to use as our deviceId (stable per install).
    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (_) {}

    final String deviceId = token ?? 'dev_${DateTime.now().millisecondsSinceEpoch}';
    _docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(deviceId);

    await _docRef!.set({
      'online'   : true,
      'lastSeen' : FieldValue.serverTimestamp(),
      'platform' : Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other',
      'token'    : token,
      'app'      : 'uddoygi',
    }, SetOptions(merge: true));

    // Refresh lastSeen periodically while app is in foreground.
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) async {
      final ref = _docRef;
      if (ref == null) return;
      try {
        await ref.set({
          'online'  : true,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    });

    // Observe lifecycle (resume → bump lastSeen; detach handled in stop()).
    WidgetsBinding.instance.addObserver(this);
    _started = true;

    // React to FCM token refresh (create/update the new device doc).
    _tokenSub?.cancel();
    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((newT) async {
      if (newT.trim().isEmpty) return;
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;

      final newRef = FirebaseFirestore.instance
          .collection('users').doc(u.uid)
          .collection('devices').doc(newT);

      try {
        await newRef.set({
          'online'  : true,
          'lastSeen': FieldValue.serverTimestamp(),
          'platform': Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other',
          'token'   : newT,
          'app'     : 'uddoygi',
        }, SetOptions(merge: true));

        // Point subsequent heartbeats at the new device doc.
        _docRef = newRef;
      } catch (_) {}
    });
  }

  /// Stop tracking (e.g., on logout/app exit).
  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;

    WidgetsBinding.instance.removeObserver(this);

    // Best-effort set offline.
    final ref = _docRef;
    _docRef = null;

    _tokenSub?.cancel();
    _tokenSub = null;

    _started = false;

    if (ref != null) {
      try {
        await ref.set({
          'online'  : false,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Clean up auth listener if you need to tear down the service.
  void dispose() {
    _authSub?.cancel();
    _authSub = null;
    _tokenSub?.cancel();
    _tokenSub = null;
  }

  /// App lifecycle -> keep lastSeen fresh when resuming; mark offline on detach.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ref = _docRef;
    if (ref == null) return;

    if (state == AppLifecycleState.resumed) {
      ref.set({
        'online'  : true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else if (state == AppLifecycleState.detached) {
      ref.set({
        'online'  : false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
