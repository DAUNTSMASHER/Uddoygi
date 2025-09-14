// lib/push/message_notification.dart
//
// Listens to Firestore "notifications" for the signed-in user and shows a
// centered, modal-style banner while the app is in foreground. The banner
// opens a dialog (inside BannerMessage) and, after OK, the banner dismisses.
// We mark the notification as read when the banner is dismissed.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'banner_message.dart';

/// Attach this to MaterialApp.navigatorKey
final GlobalKey<NavigatorState> messageNavigatorKey = GlobalKey<NavigatorState>();

class MessageNotificationService {
  MessageNotificationService._();
  static final MessageNotificationService instance = MessageNotificationService._();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;

  final _seen = <String>{};
  final _queue = <_BannerData>[];
  bool _showing = false;

  void initialize() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      await _detach();
      if (user != null) await _attach(user);
    });
  }

  Future<void> _attach(User user) async {
    final uid = user.uid;
    final col = FirebaseFirestore.instance.collection('notifications');

    _notifSub = col
        .where('toUserId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .listen((snap) {
      for (final c in snap.docChanges) {
        if (c.type != DocumentChangeType.added) continue;

        final d = c.doc;
        if (_seen.contains(d.id)) continue;
        _seen.add(d.id);

        final Map<String, dynamic> m = d.data() ?? <String, dynamic>{};
        if ((m['type'] as String?) != 'message') continue;

        final String title    = (m['title'] as String?) ?? 'New message';
        final String body     = (m['body'] as String?) ?? '';
        final String sender   = (m['fromName'] as String?)
            ?? (m['from'] as String?)
            ?? _parseSender(body)
            ?? 'someone';
        final String? subject = (m['subject'] as String?) ?? _parseSubject(body);

        _queue.add(_BannerData(
          id: d.id,
          docRef: d.reference,
          title: title,
          sender: sender,
          subject: subject,
        ));
      }
      _drain();
    }, onError: (_) {
      // Fallback to ordering by "timestamp" if "createdAt" index isn't available
      _notifSub?.cancel();
      _notifSub = col
          .where('toUserId', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(25)
          .snapshots()
          .listen((snap) {
        for (final c in snap.docChanges) {
          if (c.type != DocumentChangeType.added) continue;

          final d = c.doc;
          if (_seen.contains(d.id)) continue;
          _seen.add(d.id);

          final Map<String, dynamic> m = d.data() ?? <String, dynamic>{};
          if ((m['type'] as String?) != 'message') continue;

          final String title    = (m['title'] as String?) ?? 'New message';
          final String body     = (m['body'] as String?) ?? '';
          final String sender   = (m['fromName'] as String?)
              ?? (m['from'] as String?)
              ?? _parseSender(body)
              ?? 'someone';
          final String? subject = (m['subject'] as String?) ?? _parseSubject(body);

          _queue.add(_BannerData(
            id: d.id,
            docRef: d.reference,
            title: title,
            sender: sender,
            subject: subject,
          ));
        }
        _drain();
      });
    });
  }

  String? _parseSender(String s) {
    final i = s.indexOf(':');
    if (i <= 0) return null;
    return s.substring(0, i).trim();
  }

  String? _parseSubject(String s) {
    final i = s.indexOf(':');
    if (i < 0 || i + 1 >= s.length) return null;
    return s.substring(i + 1).trim();
  }

  Future<void> _detach() async {
    await _notifSub?.cancel();
    _notifSub = null;
    _queue.clear();
    _showing = false;
  }

  void _drain() {
    if (_showing || _queue.isEmpty) return;
    final next = _queue.removeAt(0);
    _showBanner(next);
  }

  void _showBanner(_BannerData data) {
    final nav = messageNavigatorKey.currentState;
    final overlay = nav?.overlay;
    if (overlay == null) return;

    _showing = true;

    late OverlayEntry entry;
    final opacity = ValueNotifier<double>(0);   // 0 → 1
    final scale   = ValueNotifier<double>(0.92); // 0.92 → 1.0

    Future<void> markRead() async {
      try {
        await data.docRef.update({'read': true, 'readAt': FieldValue.serverTimestamp()});
      } catch (_) {}
    }

    Future<void> close() async {
      // Mark as read when the banner is dismissed (after dialog OK).
      await markRead();

      opacity.value = 0;
      scale.value = 0.92;
      await Future.delayed(const Duration(milliseconds: 180));
      if (entry.mounted) entry.remove();
      _showing = false;
      _drain();
    }

    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Slight dim behind
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: AnimatedBuilder(
                animation: opacity,
                builder: (_, __) => Container(
                  color: Colors.black.withOpacity(0.08 * opacity.value),
                ),
              ),
            ),
          ),
          // Centered banner
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([opacity, scale]),
              builder: (_, __) => Opacity(
                opacity: opacity.value,
                child: Transform.scale(
                  scale: scale.value,
                  child: BannerMessage(
                    title: data.title,
                    sender: data.sender,
                    subject: data.subject,
                    onClose: close, // Banner opens dialog; after OK it calls this.
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(entry);

    // Animate in
    Future.delayed(const Duration(milliseconds: 16), () {
      opacity.value = 1;
      scale.value = 1.0;
    });

    // Safety auto-dismiss after 6s if untouched
    Future.delayed(const Duration(milliseconds: 6000), () {
      if (entry.mounted) close();
    });
  }

  void dispose() {
    _authSub?.cancel();
    _notifSub?.cancel();
  }
}

class _BannerData {
  final String id;
  final DocumentReference<Map<String, dynamic>> docRef;
  final String title;
  final String sender;
  final String? subject;

  _BannerData({
    required this.id,
    required this.docRef,
    required this.title,
    required this.sender,
    required this.subject,
  });
}
