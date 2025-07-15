// lib/features/marketing/presentation/screens/salary_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const double _fontMed = 14.0;

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({Key? key}) : super(key: key);

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _email;
  String? _uid;
  String? _role;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    final fbUser = FirebaseAuth.instance.currentUser;
    if (mounted) {
      setState(() {
        _email = session?['email'] as String? ?? fbUser?.email;
        _uid   = session?['uid']   as String? ?? fbUser?.uid;
        _role  = session?['role']  as String?;
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _canViewAll => _role == 'admin' || _role == 'hr';

  /// Stream of this user's payrolls: match on email, fallback to uid
  Stream<QuerySnapshot<Map<String,dynamic>>> _mySalaryStream() {
    final key = _email ?? _uid;
    return FirebaseFirestore.instance
        .collection('payrolls')
        .where('userId', isEqualTo: key)
        .orderBy('month', descending: true)
        .snapshots();
  }

  /// Stream of everybody's payrolls (admin/HR only)
  Stream<QuerySnapshot<Map<String,dynamic>>> _allSalaryStream() {
    return FirebaseFirestore.instance
        .collection('payrolls')
        .orderBy('month', descending: true)
        .snapshots();
  }

  Widget _buildSalaryList(Stream<QuerySnapshot<Map<String,dynamic>>> stream) {
    return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _darkBlue));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No records found.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data();
            final month      = d['month']      as String? ?? '-';
            final baseSalary = d['baseSalary'] as num?    ?? 0;
            final bonus      = d['bonus']      as num?    ?? 0;
            final deductions = d['deductions'] as num?   ?? 0;
            final netSalary  = d['netSalary']  as num?    ?? 0;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(month,
                        style: const TextStyle(
                          fontSize: _fontMed,
                          fontWeight: FontWeight.bold,
                          color: _darkBlue,
                        )),
                    const SizedBox(height: 8),
                    Text('Base Salary:   \$${baseSalary.toStringAsFixed(2)}'),
                    Text('Bonus:         \$${bonus.toStringAsFixed(2)}'),
                    Text('Deductions:    \$${deductions.toStringAsFixed(2)}'),
                    const Divider(height: 20),
                    Text('Net Salary:    \$${netSalary.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: _fontMed,
                          fontWeight: FontWeight.w600,
                          color: _darkBlue,
                        )),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // don't render tabs until we know email/uid
    if (_email == null && _uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
        appBar: AppBar(
          title: const Text('Salary'),
          backgroundColor: _darkBlue,
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: Colors.white,
            tabs: [
              const Tab(text: 'My Salary'),
              Tab(text: _canViewAll ? 'All Salaries' : 'Locked'),
            ],
          ),
        ),
        body: TabBarView(
            controller: _tabs,
            children: [
              // always show this user's salary
              _buildSalaryList(_mySalaryStream()),

              // only admin/HR can view all
              if (_canViewAll)
                _buildSalaryList(_allSalaryStream())
              else
                const Center(
                  child: Text(
                    'Access denied',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
        ),
        );
    }
}