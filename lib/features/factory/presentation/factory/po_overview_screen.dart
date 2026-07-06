import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'dart:math';

class POOverviewScreen extends StatefulWidget {
  const POOverviewScreen({Key? key}) : super(key: key);

  @override
  State<POOverviewScreen> createState() => _POOverviewScreenState();
}

class _POOverviewScreenState extends State<POOverviewScreen> {
  String _cid = '';
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
  }


  Future<void> _updateStatus(String docId, String newStatus) async {
    if (_cid.isEmpty || docId.startsWith('PO-DUMMY')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dummy Data: Status updated to $newStatus')));
      }
      return;
    }

    try {
      await DB.colSync(_cid, C.purchaseOrders).doc(docId).update({
        'status': newStatus,
        '${newStatus}At': Timestamp.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeroCard(),
            SizedBox(height: 8),
            _buildQuickStats(),
            SizedBox(height: 12),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B0000), Color(0xFF5A0000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [BoxShadow(color: const Color(0xFF8B0000).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      title: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
                Text(
                    'PO Overview',
                    style: AppFonts.banglaHeading(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                ),
              ],
            ),
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                final now = DateTime.now();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(DateFormat('dd MMM yyyy').format(now), style: AppFonts.banglaHeading(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(DateFormat('hh:mm a').format(now), style: AppFonts.banglaBody(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.white70)),
                  ],
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _cid.isEmpty
          ? const Stream.empty()
          : DB.colSync(_cid, C.purchaseOrders).snapshots(),
      builder: (context, snapshot) {
        int pendingCount = 0;
        Duration totalDuration = Duration.zero;
        int completedCount = 0;

        List<Map<String, dynamic>> docs = [];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          docs = snapshot.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();
        } else {
          docs = [
            {'status': 'pending', 'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2)))},
            {'status': 'completed', 'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 3))), 'completedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1)))},
            {'status': 'qc_sent', 'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 4))), 'qc_sentAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2)))},
            {'status': 'order_received', 'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(minutes: 45)))},
          ];
        }

        for (var data in docs) {
          final status = data['status'];
          if (status == 'pending' || status == 'order_received' || status == null) {
            pendingCount++;
          } else if (status == 'qc_sent' || status == 'completed') {
            final startTs = data['timestamp'] as Timestamp?;
            final endTs = (data['qc_sentAt'] ?? data['completedAt']) as Timestamp?;
            if (startTs != null && endTs != null) {
              totalDuration += endTs.toDate().difference(startTs.toDate());
              completedCount++;
            }
          }
        }

        String avgTimeString = 'N/A';
        if (completedCount > 0) {
          final avgMinutes = totalDuration.inMinutes ~/ completedCount;
          if (avgMinutes < 60) {
            avgTimeString = '${avgMinutes}m';
          } else if (avgMinutes < 24 * 60) {
            final hrs = avgMinutes ~/ 60;
            avgTimeString = '${hrs}h ${avgMinutes % 60}m';
          } else {
            final days = avgMinutes ~/ (24 * 60);
            final hrs = (avgMinutes % (24 * 60)) ~/ 60;
            avgTimeString = '${days}d ${hrs}h';
          }
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B0000), Color(0xFF5A0000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B0000).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PURCHASE REQUESTS OVERVIEW',
                style: AppFonts.banglaHeading(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$pendingCount',
                    style: AppFonts.banglaData(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Pending',
                    style: AppFonts.banglaBody(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                        'Average Completion Time',
                          style: AppFonts.banglaBody(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          avgTimeString,
                          style: AppFonts.banglaData(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Review All',
                            style: AppFonts.banglaBody(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.1);
      },
    );
  }

  Widget _buildQuickStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _cid.isEmpty
          ? const Stream.empty()
          : DB.colSync(_cid, C.purchaseOrders).snapshots(),
      builder: (context, snapshot) {
        int todayCount = 0;
        int approvedCount = 0;
        int rejectedCount = 0;

        final now = DateTime.now();
        List<Map<String, dynamic>> docs = [];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          docs = snapshot.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();
        } else {
          docs = [
            {'status': 'pending', 'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2)))},
            {'status': 'purchase_completed', 'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 5)))},
            {'status': 'rejected', 'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 8)))},
            {'status': 'completed', 'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 3))), 'completedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1)))},
            {'status': 'order_received', 'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(minutes: 45)))},
          ];
        }

        for (var data in docs) {
          final status = data['status'] as String? ?? 'order_received';
          
          if (status == 'purchase_completed' || status == 'accepted') approvedCount++;
          if (status == 'rejected') rejectedCount++;
          
          final ts = data['timestamp'] as Timestamp?;
          if (ts != null) {
            final date = ts.toDate();
            if (date.year == now.year && date.month == now.month && date.day == now.day) {
              todayCount++;
            }
          }
        }

        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.today_rounded,
                iconBg: const Color(0xFFE31C40).withOpacity(0.1),
                iconColor: const Color(0xFFBA002E),
                value: '$todayCount',
                label: "Today's POs",
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_rounded,
                iconBg: Colors.green.shade100,
                iconColor: Colors.green.shade700,
                value: '$approvedCount',
                label: 'Approved',
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.cancel_rounded,
                iconBg: const Color(0xFFFFDAD6).withOpacity(0.4),
                iconColor: const Color(0xFFBA1A1A),
                value: '$rejectedCount',
                label: 'Rejected',
              ),
            ),
          ],
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
      },
    );
  }

  Widget _buildRecentActivity() {
    return StreamBuilder<QuerySnapshot>(
      stream: _cid.isEmpty
          ? const Stream.empty()
          : DB.colSync(_cid, C.purchaseOrders)
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cid.isNotEmpty) {
          return const SizedBox();
        }
        
        List<Map<String, dynamic>> itemsList = [];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          itemsList = snapshot.data!.docs.map((d) => {'_id': d.id, ...d.data() as Map<String, dynamic>}).toList();
        } else {
          itemsList = [
            {
              '_id': 'PO-DUMMY-1',
              'poNo': 'PO-20261001',
              'status': 'order_received',
              'submittedBy': 'Michael Scott',
              'supplierName': 'Dunder Mifflin',
              'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2))),
              'items': [{'qty': 50, 'unitPrice': 12.50}, {'qty': 20, 'unitPrice': 5.0}],
            },
            {
              '_id': 'PO-DUMMY-2',
              'poNo': 'PO-20261002',
              'status': 'supplier_found',
              'submittedBy': 'Jim Halpert',
              'supplierName': 'Athlead',
              'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
              'supplier_foundAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 4))),
              'items': [{'qty': 5, 'unitPrice': 1200.0}],
            },
            {
              '_id': 'PO-DUMMY-3',
              'poNo': 'PO-20261003',
              'status': 'bought_from_supplier',
              'submittedBy': 'Dwight Schrute',
              'supplierName': 'Schrute Farms',
              'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2))),
              'bought_from_supplierAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
              'items': [{'qty': 100, 'unitPrice': 4.50}],
            },
            {
              '_id': 'PO-DUMMY-4',
              'poNo': 'PO-20261004',
              'status': 'in_factory_for_modification',
              'submittedBy': 'Pam Beesly',
              'supplierName': 'Vance Refrigeration',
              'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 3))),
              'in_factory_for_modificationAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
              'items': [{'qty': 2, 'unitPrice': 4500.0}],
            },
            {
              '_id': 'PO-DUMMY-5',
              'poNo': 'PO-20261005',
              'status': 'sent_to_marketing',
              'submittedBy': 'Stanley Hudson',
              'supplierName': 'Pretzel Co',
              'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 5))),
              'sent_to_marketingAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2))),
              'items': [{'qty': 500, 'unitPrice': 1.25}],
            },
            {
              '_id': 'PO-DUMMY-6',
              'poNo': 'PO-20261006',
              'status': 'rejected',
              'submittedBy': 'Angela Martin',
              'supplierName': 'Cat Fancy',
              'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 4))),
              'rejectedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2))),
              'items': [{'qty': 15, 'unitPrice': 85.0}],
            },
          ];
        }

        final pendingItems = itemsList.where((d) {
          final st = d['status'];
          return st == 'pending' || st == 'order_received' || st == null;
        }).take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Requests',
                  style: AppFonts.banglaHeading(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1C1C),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'View History',
                    style: AppFonts.banglaHeading(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8B0000),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            if (pendingItems.isEmpty)
              _buildEmptyState()
            else
              ...pendingItems.map((data) => _buildActivityItem(data, data['_id'])).toList(),
          ],
        ).animate().fadeIn(delay: 200.ms);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 32),
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFE5E2E1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_rounded, size: 40, color: const Color(0xFF5A413D)),
          ),
          SizedBox(height: 16),
          Text(
          'No new requests',
          style: AppFonts.banglaHeading(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1C1B1B),
          ),
          ),
          SizedBox(height: 8),
          Text(
          'All purchase orders have been processed.',
          style: AppFonts.banglaBody(
            fontSize: 14,
            color: const Color(0xFF5A413D),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> data, String id) {
    final status = data['status'] as String? ?? 'pending';
    final ts = data['timestamp'] as Timestamp?;
    final timeString = ts != null ? timeago.format(ts.toDate()) : '';
    
    double totalValue = 0;
    final items = data['items'] as List<dynamic>? ?? [];
    for (var item in items) {
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      final price = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
      totalValue += (qty * price);
    }

    Color statusColor;
    Color statusBg;
    String statusText = status.replaceAll('_', ' ').toUpperCase();
    if (status == 'sent_to_marketing') {
      statusColor = Colors.green.shade700;
      statusBg = Colors.green.shade100;
    } else if (status == 'in_factory_for_modification') {
      statusColor = Colors.orange.shade700;
      statusBg = Colors.orange.shade100;
    } else if (status == 'bought_from_supplier') {
      statusColor = Colors.purple.shade700;
      statusBg = Colors.purple.shade100;
    } else if (status == 'supplier_found') {
      statusColor = Colors.blue.shade700;
      statusBg = Colors.blue.shade100;
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFBA1A1A);
      statusBg = const Color(0xFFFFDAD6).withOpacity(0.4);
    } else { // order_received
      statusColor = const Color(0xFFBA002E);
      statusBg = const Color(0xFFE31C40).withOpacity(0.1);
      statusText = 'ORDER RECEIVED';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, const Color(0xFFFCF9F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF8B0000).withOpacity(0.04), blurRadius: 10, offset: Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFCF9F8), Color(0xFFF0EDED)]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white),
            ),
            child: Icon(Icons.receipt_long_rounded, color: const Color(0xFF5A413D), size: 16),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data['poNo'] ?? id,
                      style: AppFonts.banglaHeading(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1B1B),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: AppFonts.banglaHeading(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  data['submittedBy'] ?? 'Unknown',
                  style: AppFonts.banglaBody(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeString,
                      style: AppFonts.banglaBody(
                        fontSize: 7,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFA6A7A8),
                      ),
                    ),
                    Text(
                      '\$${totalValue.toStringAsFixed(2)}',
                      style: AppFonts.banglaData(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF8B0000),
                      ),
                    ),
                  ],
                ),
                if (status == 'order_received') ...[
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => _updateStatus(id, 'rejected'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBA1A1A).withOpacity(0.3)),
                            boxShadow: [BoxShadow(color: const Color(0xFFBA1A1A).withOpacity(0.1), blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.close_rounded, size: 12, color: const Color(0xFFBA1A1A)),
                              SizedBox(width: 4),
                              Text('Reject', style: AppFonts.banglaHeading(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFBA1A1A))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _updateStatus(id, 'supplier_found'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8B0000), Color(0xFF5A0000)]),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: const Color(0xFF8B0000).withOpacity(0.3), blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_rounded, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Supplier Found', style: AppFonts.banglaHeading(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF0EDED)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 12),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: AppFonts.banglaData(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1B1B),
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: AppFonts.banglaBody(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

