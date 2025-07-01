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

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    if (session != null) {
      setState(() {
        userId = session['uid'];
        email = session['email'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null || email == null) {
      return const Center(child: CircularProgressIndicator());
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
        body: TabBarView(
          children: [
            CustomerListView(userId: userId!, email: email!), // ✅ both
            AddCustomerForm(userId: userId!, email: email!),   // ✅ both
            CustomerOrderSummary(email: email!),               // ✅ only email
          ],
        ),
      ),
    );
  }
}
