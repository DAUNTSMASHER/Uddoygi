import 'package:flutter/material.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/add_customer_form.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/customer_list_view.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/customer_order_summary.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String? userId;
  String? email;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final session = await LocalStorageService.getSession();
      if (!mounted) return; // <-- guard
      setState(() {
        userId = session?['uid'];
        email = session?['email'];
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Management')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Session not available
    if (userId == null || email == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Management')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No active session found.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadSession,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customer Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All Customers'),
              Tab(text: 'Add Customer'),
              Tab(text: 'Orders Summary'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              // Non-const because they depend on state — remove const if needed.
              // Keeping without const here; add back if your constructors are const.
            ],
          ),
        ),
      ),
    );
  }
}
