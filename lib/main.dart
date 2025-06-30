import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/routes.dart'; // ✅ Centralized route map
import 'firebase_options.dart';
import 'features/auth/presentation/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const UddyogiApp());
}

class UddyogiApp extends StatelessWidget {
  const UddyogiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uddyogi - Smart Company Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const LoginScreenWrapper(),
      routes: appRoutes, // ✅ Use centralized route map
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Page Not Found')),
          body: const Center(child: Text('404 - Page Not Found')),
        ),
      ),
    );
  }
}

class LoginScreenWrapper extends StatefulWidget {
  const LoginScreenWrapper({Key? key}) : super(key: key);

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

      final userDoc = await _firestore.collection('users').doc(credential.user!.uid).get();

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
  }
}
