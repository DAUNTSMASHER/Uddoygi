// lib/features/marketing/presentation/customers/customers_screen.dart
//
// CustomersScreen — now with a BottomNavigationBar (blue bg + white labels/icons)
// Pages kept alive using an IndexedStack.

import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// === Your pages ===
import 'package:uddoygi/features/marketing/presentation/widgets/customer_list_view.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/add_customer_form.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/customer_order_summary.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String? userId;
  String? email;
  bool isLoading = true;

  int _currentIndex = 0; // bottom nav index

  // Brand palette
  static const Color _brandTeal  = Color(0xFF001863); // deep blue
  static const Color _indigoCard = Color(0xFF0B2D9F); // indigo/blue for nav bg
  static const Color _surface    = Color(0xFFF4FBFB);

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final session = await LocalStorageService.getSession();
      if (!mounted) return;
      setState(() {
        userId = session?['uid'];
        email  = session?['email'];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load session: $e')),
      );
    }
  }

  String _titleFor(int index) {
    switch (index) {
      case 0: return 'All Customers';
      case 1: return 'Add Customer';
      case 2: return 'Orders Summary';
      default: return 'Customer Management';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading
    if (isLoading) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          title: const Text('Customer Management', style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: _brandTeal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // No session
    if (userId == null || email == null) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          title: const Text('Customer Management', style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: _brandTeal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No active session found.'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadSession, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Pages for bottom nav
    final pages = <Widget>[
      CustomerListView(userId: userId!, email: email!),
      AddCustomerForm(userId: userId!, email: email!),
      CustomerOrderSummary(email: email!), // scoped to agent email
    ];

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(_titleFor(_currentIndex), style: const TextStyle(fontWeight: FontWeight.w800)),
        // keep your nice gradient header
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brandTeal, _indigoCard],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      // Keep state of each tab
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),

      // Bottom navigation (blue bg + white labels/icons)
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: _indigoCard,           // blue background
          selectedItemColor: Colors.white,         // white selected
          unselectedItemColor: Colors.white70,     // white (dim) unselected
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt),
              label: 'Customers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_add_alt_1),
              label: 'Add',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Summary',
            ),
          ],
        ),
      ),
    );
  }
}
