// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/routes.dart'; // ✅ Centralized route map
import 'firebase_options.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

// ✅ Import the confirmation screen (public deep link surface)
import 'features/auth/presentation/screens/confirmation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const UddyogiApp());
}

class UddyogiApp extends StatelessWidget {
  const UddyogiApp({super.key});

  /// Decide initial route at app start.
  /// On web, if the URL targets the confirmation page, go there directly.
  String _computeInitialRoute() {
    if (!kIsWeb) return '/';

    final base = Uri.base;

    // Works for: https://site.com/address-confirm?token=...
    final hasPath = base.pathSegments.contains('address-confirm');

    // Works for: https://site.com/#/address-confirm?token=...
    final hasHash = base.fragment.contains('address-confirm');

    if (hasPath || hasHash) return '/address-confirm';
    return '/';
  }

  @override
  Widget build(BuildContext context) {
    // Merge root routes with your existing app routes
    final mergedRoutes = <String, WidgetBuilder>{
      // Root splash
      '/': (context) => const SplashScreen(),

      // Public confirmation screen (reads token from Uri.base internally)
      '/address-confirm': (context) => const ConfirmationScreen(),

      // Everything else
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

      // ✅ Respect web deep links (hash or path) without changing your design
      initialRoute: _computeInitialRoute(),
      routes: mergedRoutes,

      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Page Not Found')),
          body: const Center(child: Text('404 - Page Not Found')),
        ),
      ),
    );
  }
}

// ✅ Your LoginScreen logic remains the same
class LoginScreenWrapper extends StatefulWidget {
  const LoginScreenWrapper({super.key});

  @override
  State<LoginScreenWrapper> createState() => _LoginScreenWrapperState();
}

class _LoginScreenWrapperState extends State<LoginScreenWrapper> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = false;

  Future<void> _handleLogin(String email, String password) async {
    setState(() {
      _loading = true;
    });

    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userDoc =
      await _firestore.collection('users').doc(credential.user!.uid).get();

      if (!userDoc.exists) {
        throw Exception("User data not found");
      }

      final data = userDoc.data()!;
      final String department = data['department'] ?? '';

      String route;
      switch (department) {
        case 'admin':
          route = '/admin/dashboard';
          break;
        case 'hr':
          route = '/hr/dashboard';
          break;
        case 'marketing':
          route = '/marketing/dashboard';
          break;
        case 'factory':
          route = '/factory/dashboard';
          break;
        default:
          throw Exception("Invalid department: $department");
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Authentication Error: ${e.message}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoginScreen(
      loading: _loading,
      onLogin: _handleLogin,
    );
    // Note: If you want to use this wrapper somewhere in routes:
    // appRoutes['/login'] = (_) => const LoginScreenWrapper();
  }
}
