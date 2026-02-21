// lib/features/factory/presentation/screens/production_dashboard.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFFD51616);

class ProductionDashboard extends StatefulWidget {
  const ProductionDashboard({Key? key}) : super(key: key);

  @override
  State<ProductionDashboard> createState() => _ProductionDashboardState();
}

class _ProductionDashboardState extends State<ProductionDashboard> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  DateTimeRange get _todayRange {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange get _monthRange {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  Stream<int> _sumForRange(DateTimeRange range, String userEmail) {
    return DB.colSync(_cid, C.dailyProduction)
        .where('managerEmail', isEqualTo: userEmail)
        .where('productionDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('productionDate',
        isLessThanOrEqualTo: Timestamp.fromDate(range.end))
        .snapshots()
        .map((snap) {
      return snap.docs.fold<int>(
        0,
            (sum, doc) =>
        sum + (doc.data()['quantity'] as int? ?? 0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('à¦¡à§à¦¯à¦¾à¦¶à¦¬à§‹à¦°à§à¦¡', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          backgroundColor: _darkBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: Text('à¦…à¦¨à§à¦—à§à¦°à¦¹ à¦•à¦°à§‡ à¦¸à¦¾à¦‡à¦¨ à¦‡à¦¨ à¦•à¦°à§à¦¨')),
      );
    }

    return Scaffold(
      appBar: AppBar(
          title: const Text('à¦‰à§Žà¦ªà¦¾à¦¦à¦¨ à¦¡à§à¦¯à¦¾à¦¶à¦¬à§‹à¦°à§à¦¡', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Today's total
            StreamBuilder<int>(
              stream: _sumForRange(_todayRange, userEmail),
              builder: (context, snapshot) {
                final qty = snapshot.data ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading: const Icon(Icons.today, size: 32, color: _darkBlue),
                    title: const Text('আজকের উৎপাদন'),
                    subtitle: Text(
                      '${DateFormat.yMMMMd().format(_todayRange.start)}',
                    ),
                    trailing: Text(
                      qty.toString(),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),

            // This month's total
            StreamBuilder<int>(
              stream: _sumForRange(_monthRange, userEmail),
              builder: (context, snapshot) {
                final qty = snapshot.data ?? 0;
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading:
                    const Icon(Icons.calendar_view_month, size: 32, color: _darkBlue),
                    title: const Text('এই মাসের উৎপাদন'),
                    subtitle: Text(
                      DateFormat.yMMMM().format(_monthRange.start),
                    ),
                    trailing: Text(
                      qty.toString(),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),

            // you can expand with charts or more metrics here...
          ],
        ),
      ),
    );
  }
}

