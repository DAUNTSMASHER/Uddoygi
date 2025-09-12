// lib/push/notify_bootstrap.dart
//
// Works with flutter_local_notifications 17.x
// - Android uses AndroidInitializationSettings & AndroidNotificationDetails
// - iOS uses DarwinInitializationSettings & DarwinNotificationDetails
//
// Provides:
//   initLocalNotifications()   -> call once in main()
//   setupOnMessageHandler()    -> mirrors FCM foreground to local banner
//   showRemoteNotificationFromBackground(RemoteMessage) -> optional mirror in BG

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final FlutterLocalNotificationsPlugin _fln =
FlutterLocalNotificationsPlugin();

const String _channelId   = 'alert_channel';
const String _channelName = 'Alerts';
const String _channelDesc = 'Urgent and general alerts';

bool _inited = false;

/// Initialize local notifications & iOS foreground presentation.
Future<void> initLocalNotifications() async {
  if (_inited) return;
  _inited = true;

  // Android init (use your launcher icon)
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

  // iOS / macOS init
  const darwinInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const settings = InitializationSettings(
    android: androidInit,
    iOS: darwinInit,
  );

  await _fln.initialize(
    settings,
    onDidReceiveNotificationResponse: (resp) async {
      // TODO: deep-link (payload is resp.payload)
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  // iOS: allow banners while in foreground
  try {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
  } catch (_) {}

  // Android: create a high-importance channel (Facebook-like)
  final androidImpl =
  _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.high,
  ));
}

/// Foreground FCM -> show local banner so the user sees an alert instantly.
void setupOnMessageHandler() {
  FirebaseMessaging.onMessage.listen((RemoteMessage m) async {
    final title = m.notification?.title ?? m.data['title'] ?? 'Alert';
    final body  = m.notification?.body  ?? m.data['body']  ?? 'You have a new alert';
    await _showLocal(title, body, payload: m.data['payload'] ?? 'fcm');
  });
}

/// Used by the background handler in main.dart for data-only fallbacks.
/// (If your server always sends a `notification` block, Android shows it
/// automatically and this is not strictly necessary.)
Future<void> showRemoteNotificationFromBackground(RemoteMessage m) async {
  final title = m.notification?.title ?? m.data['title'];
  final body  = m.notification?.body  ?? m.data['body'];
  if (title == null && body == null) return;
  await _showLocal(title ?? 'Alert', body ?? 'You have a new alert',
      payload: m.data['payload'] ?? 'bg');
}

Future<void> _showLocal(String title, String body, {String? payload}) async {
  const android = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  const ios = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const details = NotificationDetails(android: android, iOS: ios);
  await _fln.show(0, title, body, details, payload: payload);
}

/// Required for background tap handling (v17 API).
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Handle background tap if needed.
}
