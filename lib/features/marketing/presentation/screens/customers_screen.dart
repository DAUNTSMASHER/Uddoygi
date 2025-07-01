import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import '../widgets/add_customer_form.dart';
import '../widgets/customer_list_view.dart';
import '../widgets/customer_order_summary.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUidFromSession();
  }

  Future<void> _loadUidFromSession() async {
    final session = await LocalStorageService.getSession();
    if (session != null && session['uid'] != null) {
      setState(() {
        _userId = session['uid'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
        body: TabBarView(
          children: [
            CustomerListView(userId: _userId!),
            AddCustomerForm(userId: _userId!),
            CustomerOrderSummary(userId: _userId!),
          ],
        ),
      ),
    );
  }
}