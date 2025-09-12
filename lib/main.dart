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

// Push helpers (these files are below)
import 'push/fcm_register.dart';
import 'push/notify_bootstrap.dart';

/// Background FCM handler (Android).
/// If your server sends a `notification` block, Android will usually post
/// to the tray automatically. This handler is here in case you want to do
/// extra work and to keep Firebase initialized in the background isolate.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Already initialized – ignore.
  }

  // Optionally mirror as a local banner if needed:
  // (Only useful for data-only messages; for notification+data the system tray shows already.)
  await showRemoteNotificationFromBackground(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Android background delivery
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  // Local notifications: channel, iOS foreground presentation, etc.
  await initLocalNotifications();

  // Foreground FCM -> local banner
  setupOnMessageHandler();

  // If already signed in, make sure this device can receive push
  final current = FirebaseAuth.instance.currentUser;
  if (current != null) {
    await registerForPushNotifications();
  }

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

/// Wraps LoginScreen to sign in, register push, and route by department.
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

      // Register this device & request permission
      await registerForPushNotifications();

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
