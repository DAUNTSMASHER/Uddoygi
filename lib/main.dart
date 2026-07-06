import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/theme/app_theme.dart';
import 'package:uddoygi/widgets/global_ai_assistant.dart';
import 'package:uddoygi/services/navigation_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/routes.dart';
import 'services/db.dart';
import 'services/local_storage_service.dart';
import 'services/app_rules.dart';
import 'services/ai_service.dart';
import 'services/seed_data_service.dart';
import 'services/language_service.dart';

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

  await LanguageService.instance.init();
  runApp(const UddyogiApp());
}

class UddyogiApp extends StatefulWidget {
  const UddyogiApp({super.key});

  @override
  State<UddyogiApp> createState() => _UddyogiAppState();
}

class _UddyogiAppState extends State<UddyogiApp> {
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

    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageService.instance.locale,
      builder: (_, locale, __) {
        return MaterialApp(
          navigatorKey: messageNavigatorKey,
          title: 'Uddyogi - Smart Company Management',
          theme: buildAppTheme(),
          locale: locale,
          debugShowCheckedModeBanner: false,
          initialRoute: _computeInitialRoute(),
          routes: mergedRoutes,
          navigatorObservers: [RouteObserverService()],
          builder: (context, child) => GlobalAiAssistant(child: child),
          onUnknownRoute: (_) => MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Page Not Found')),
              body: const Center(child: Text('404 - Page Not Found')),
            ),
          ),
        );
      },
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
  bool _loading = false;

  /// Builds the company-namespaced Auth email (same logic as add_employee_page.dart).
  /// e.g. john@co.com + CID12345 → john+CID12345@co.com
  String _authEmail(String realEmail, String cid) {
    final parts = realEmail.split('@');
    if (parts.length != 2) return realEmail;
    return '${parts[0]}+$cid@${parts[1]}';
  }

  /// Called by LoginScreen after the user enters email + password.
  /// [companyId] is the verified company ID from Phase 1.
  /// Tries compound email (john+CID@domain) first, falls back to raw email
  /// for admin accounts and legacy employees created before this change.
  Future<void> _handleLogin(
      String email, String password, String companyId) async {
    setState(() => _loading = true);
    try {
      await LocalStorageService.saveCompanyId(companyId);

      UserCredential cred;
      try {
        final compoundEmail = _authEmail(email, companyId);
        cred = await _auth.signInWithEmailAndPassword(
            email: compoundEmail, password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          try {
            cred = await _auth.signInWithEmailAndPassword(
                email: email, password: password);
          } on FirebaseAuthException catch (e2) {
            if ((e2.code == 'user-not-found' || e2.code == 'invalid-credential') &&
                companyId == '12345678') {
              cred = await _setupDemoAccount(email, password, companyId);
            } else {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }

      if (!kIsWeb) await registerForPushNotifications();
      await DevicePresence.instance.start();

      final snap = await DB.colSync(companyId, C.users)
          .doc(cred.user!.uid)
          .get();
      if (!snap.exists) {
        throw Exception('User data not found.');
      }

      final data = snap.data()!;
      final userCompanyId = (data['companyId'] ?? '').toString().trim();
      if (userCompanyId.isNotEmpty && userCompanyId != companyId.trim()) {
        await _auth.signOut();
        throw Exception('This account does not belong to Company ID $companyId.');
      }

      final pendingPass = (data['_pendingPasswordReset'] as String?)?.trim() ?? '';
      if (pendingPass.isNotEmpty && cred.user != null) {
        try {
          await DB.colSync(companyId, C.users).doc(cred.user!.uid).update({
            '_pendingPasswordReset': null,
            '_passwordResetAt': null,
            '_passwordResetBy': null,
          });
        } catch (_) {}
      }

      final role = (data['role'] ?? 'unknown').toString();
      await LocalStorageService.saveSession(cred.user!.uid, email, role);
      await LocalStorageService.saveCompanyId(companyId);

      AppRules.instance.loadSession(
        uid: cred.user!.uid,
        companyId: companyId,
        role: role,
      );

      final dept = (data['department'] ?? '').toString().toLowerCase();
      String route;
      switch (dept) {
        case 'admin':     route = '/admin/dashboard';     break;
        case 'hr':        route = '/hr/dashboard';        break;
        case 'marketing': route = '/marketing/dashboard'; break;
        case 'factory':   route = '/factory/dashboard';   break;
        case 'rnd':       route = '/rnd/dashboard';       break;
        default:
          throw Exception('Invalid department: $dept');
      }

      AIService.init();
      await SeedDataService.seedIfEmpty(companyId);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyAuthError(e.code)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                "Hmm, something didn't go as planned. Please try again in a moment."),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<UserCredential> _setupDemoAccount(
      String email, String password, String companyId) async {
    final dept = email.split('@').first;
    final role = dept == 'admin' ? 'super_admin' : dept;
    final displayName = '${dept[0].toUpperCase()}${dept.substring(1)} User';

    await FirebaseFirestore.instance.collection('companies').doc(companyId).set({
      'companyId': companyId,
      'companyName': 'UDDYOGI Demo Corp.',
      'isActive': true,
      'email': 'demo@uddoygi.com',
      'phone': '+8801700000000',
      'industry': 'Manufacturing',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final uid = cred.user!.uid;

    await DB.colSync(companyId, C.users).doc(uid).set({
      'uid': uid,
      'email': email,
      'name': displayName,
      'role': role,
      'department': dept,
      'companyId': companyId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  /// Converts Firebase Auth error codes into friendly, human-readable messages.
  static String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return "We couldn't find an account with that email. Double-check it and try again.";
      case 'wrong-password':
        return "That password doesn't look right. Give it another try.";
      case 'invalid-credential':
        return "Your email or password doesn't match our records. Please check and try again.";
      case 'invalid-email':
        return "That doesn't look like a valid email address. Could you check it?";
      case 'user-disabled':
        return "This account has been disabled. Please contact your administrator.";
      case 'too-many-requests':
        return "Too many failed attempts — your account is temporarily locked. Please wait a few minutes and try again.";
      case 'network-request-failed':
        return "Looks like you're offline. Please check your internet connection and try again.";
      case 'email-already-in-use':
        return "That email is already registered. Try logging in instead.";
      case 'weak-password':
        return "That password is a bit too simple. Please use at least 6 characters.";
      case 'operation-not-allowed':
        return "Sign-in isn't available right now. Please contact support.";
      default:
        return "Something went wrong with signing in. Please try again.";
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
