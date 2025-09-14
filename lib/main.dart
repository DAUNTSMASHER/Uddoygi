// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'core/routes.dart';

// Auth surfaces
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/confirmation_screen.dart';

// Push + in-app banners + presence
import 'push/fcm_register.dart';
import 'push/notify_bootstrap.dart';
import 'push/message_notification.dart';
import 'push/device_presence.dart';

@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  await showRemoteNotificationFromBackground(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // In-app Firestore → banner listener
  MessageNotificationService.instance.initialize();

  // Presence needs to hook lifecycle once at app start
  DevicePresence.instance.initialize();

  // Push setup (not for Web)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
    await initLocalNotifications();   // channel + iOS foreground settings
    setupOnMessageHandler();          // mirror FCM → local banner

    // handle taps (cold/warm)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      messageNavigatorKey.currentState?.pushNamed('/notifications');
    }
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      messageNavigatorKey.currentState?.pushNamed('/notifications');
    });
  }

  // If already signed in, register push + start presence
  final current = FirebaseAuth.instance.currentUser;
  if (current != null) {
    if (!kIsWeb) {
      await registerForPushNotifications();
    }
    await DevicePresence.instance.start(); // show as live device
  }

  // Watch future sign-ins / sign-outs
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      if (!kIsWeb) {
        await registerForPushNotifications();
      }
      await DevicePresence.instance.start();
    } else {
      await DevicePresence.instance.stop();
    }
  });

  runApp(const UddyogiApp());
}

class UddyogiApp extends StatelessWidget {
  const UddyogiApp({super.key});

  String _computeInitialRoute() {
    if (!kIsWeb) return '/';
    final base = Uri.base;
    final hasPath = base.pathSegments.any((s) => s == 'address-confirm');
    final hasHash = base.fragment.contains('address-confirm');
    return (hasPath || hasHash) ? '/address-confirm' : '/';
  }

  @override
  Widget build(BuildContext context) {
    final mergedRoutes = <String, WidgetBuilder>{
      '/': (_) => const SplashScreen(),
      '/address-confirm': (_) => const ConfirmationScreen(),
      '/login': (_) => const LoginScreenWrapper(),
      ...appRoutes,
    };

    return MaterialApp(
      navigatorKey: messageNavigatorKey, // required for in-app banners/deeplinks
      title: 'Uddyogi - Smart Company Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: _computeInitialRoute(),
      routes: mergedRoutes,
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Page Not Found')),
          body: const Center(child: Text('404 - Page Not Found')),
        ),
      ),
    );
  }
}

/// Wraps LoginScreen to sign in, register push, start presence, and route by department.
class LoginScreenWrapper extends StatefulWidget {
  const LoginScreenWrapper({super.key});
  @override
  State<LoginScreenWrapper> createState() => _LoginScreenWrapperState();
}

class _LoginScreenWrapperState extends State<LoginScreenWrapper> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  bool _loading = false;

  Future<void> _handleLogin(String email, String password) async {
    setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (!kIsWeb) {
        await registerForPushNotifications();
      }
      await DevicePresence.instance.start(); // defensive: ensure presence starts here too

      // Route by department
      final snap = await _db.collection('users').doc(cred.user!.uid).get();
      if (!snap.exists) throw Exception('User data not found');

      final data = snap.data()!;
      final dept = (data['department'] ?? '').toString().toLowerCase();

      String route;
      switch (dept) {
        case 'admin':     route = '/admin/dashboard';     break;
        case 'hr':        route = '/hr/dashboard';        break;
        case 'marketing': route = '/marketing/dashboard'; break;
        case 'factory':   route = '/factory/dashboard';   break;
        default: throw Exception('Invalid department: $dept');
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication Error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoginScreen(
      loading: _loading,
      onLogin: _handleLogin,
    );
  }
}
