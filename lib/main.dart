import 'package:flutter/material.dart';

// Import your feature screens
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/admin/presentation/screens/admin_dashboard.dart';
import 'features/hr/presentation/screens/hr_dashboard.dart';
import 'features/marketing/presentation/screens/marketing_dashboard.dart';
import 'features/factory/presentation/screens/factory_dashboard.dart';

void main() {
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

      initialRoute: '/login',

      routes: {
        '/login': (context) => const LoginScreen(),
        '/admin/dashboard': (context) => const AdminDashboard(),
        '/hr/dashboard': (context) => const HRDashboard(),
        '/marketing/dashboard': (context) => const MarketingDashboard(),
        '/factory/dashboard': (context) => const FactoryDashboard(),
      },

      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: const Center(child: Text('404 - Page Not Found')),
          ),
        );
      },
    );
  }
}
