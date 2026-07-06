// lib/features/factory/presentation/factory/industrial_velocity_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'widgets/factory_bottom_nav.dart';
import 'all_work_orders_screen.dart';
import 'pending_work_orders_screen.dart';
import 'running_work_orders_screen.dart';
import 'all_work_orders_screen.dart';
import 'work_order_details_screen.dart';
import 'live_order_tracking_screen.dart';

class IndustrialVelocityDashboardScreen extends StatefulWidget {
  const IndustrialVelocityDashboardScreen({Key? key}) : super(key: key);

  @override
  State<IndustrialVelocityDashboardScreen> createState() => _IndustrialVelocityDashboardScreenState();
}

class _IndustrialVelocityDashboardScreenState extends State<IndustrialVelocityDashboardScreen> {
  String _cid = '';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted && id != null) setState(() => _cid = id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNavTabSelected(FactoryNavTab tab) {
    if (tab == FactoryNavTab.overview) return;
    
    Widget target;
    switch (tab) {
      case FactoryNavTab.all:
        target = const AllWorkOrdersScreen();
        break;
      case FactoryNavTab.pending:
        target = const PendingWorkOrdersScreen();
        break;
      case FactoryNavTab.running:
        target = const RunningWorkOrdersScreen();
        break;
      case FactoryNavTab.track:
        target = const LiveOrderTrackingScreen();
        break;
      default:
        return;
    }
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => target,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      appBar: AppBar(
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
                  Text(
                    'Work Orders',
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
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      bottomNavigationBar: FactoryBottomNav(
        currentTab: FactoryNavTab.overview,
        onTabSelected: _onNavTabSelected,
      ),
      body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricsGrid(),
                    const SizedBox(height: 24),
                    _buildSearchBar(),
                    const SizedBox(height: 24),
                    Text(
                      'Recent Work Orders',
                      style: AppFonts.banglaHeading(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF161c22),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRecentOrders(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricsGrid() {
    // DUMMY DATA FOR UI TESTING
    int total = 1248;
    int pending = 42;
    int production = 391;
    int completed = 815;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2BFB9).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Color(0xFF8B0000), size: 14),
              const SizedBox(width: 6),
              Text('Factory Overview', style: AppFonts.banglaHeading(color: Color(0xFF8B0000), fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildHeroMetric('TOTAL', total.toString(), Icons.analytics)),
              Container(width: 1, height: 30, color: const Color(0xFFE2BFB9).withOpacity(0.5)),
              Expanded(child: _buildHeroMetric('PENDING', pending.toString(), Icons.pending_actions)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: const Color(0xFFE2BFB9).withOpacity(0.5), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildHeroMetric('PRODUCTION', production.toString(), Icons.factory)),
              Container(width: 1, height: 30, color: const Color(0xFFE2BFB9).withOpacity(0.5)),
              Expanded(child: _buildHeroMetric('COMPLETED', completed.toString(), Icons.check_circle)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildHeroMetric(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: const Color(0xFF5A0000).withOpacity(0.7)),
              const SizedBox(width: 4),
              Text(title, style: AppFonts.banglaBody(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF5A0000).withOpacity(0.7), letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: AppFonts.banglaData(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF8B0000))),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2BFB9).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: const Color(0xFF8B0000).withOpacity(0.7), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              style: AppFonts.banglaBody(fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Search work orders (e.g., MOCK-1001)',
                hintStyle: AppFonts.banglaBody(
                  fontSize: 11,
                  color: const Color(0xFF8E706C).withOpacity(0.7),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(bottom: 15),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    final List<Map<String, dynamic>> dummyData = [
      {
        'id': 'MOCK-1001',
        'workOrderNo': 'MOCK-1001',
        'buyerName': 'Acme Corp',
        'instructions': 'Machining - Shaft Assembly',
        'completed': false,
        'currentStage': 'Submitted to factory',
        'createdAt': Timestamp.now(),
      },
      {
        'id': 'MOCK-1002',
        'workOrderNo': 'MOCK-1002',
        'buyerName': 'Globex',
        'instructions': 'Welding - Frame Structural',
        'completed': false,
        'currentStage': 'In Production',
        'createdAt': Timestamp.now(),
      },
      {
        'id': 'MOCK-1003',
        'workOrderNo': 'MOCK-1003',
        'buyerName': 'Stark Ind',
        'instructions': 'Laser Cutting - Panels',
        'completed': true,
        'currentStage': 'Completed',
        'createdAt': Timestamp.now(),
      },
    ];

    var docs = dummyData;
    if (_searchQuery.isNotEmpty) {
      docs = docs.where((data) {
        final no = (data['workOrderNo'] ?? '').toString().toLowerCase();
        final buyer = (data['buyerName'] ?? '').toString().toLowerCase();
        return no.contains(_searchQuery) || buyer.contains(_searchQuery);
      }).toList();
    }

    if (docs.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No recent orders found.')));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 16),
      itemBuilder: (ctx, i) {
        final data = docs[i];
        return _buildOrderCard(data['id'], data).animate().fadeIn(delay: (i * 100).ms).slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildOrderCard(String id, Map<String, dynamic> data) {
    final woNo = data['workOrderNo'] ?? id;
    final isCompleted = data['completed'] == true || data['status'] == 'Completed';
    final currentStage = data['currentStage'];
    
    String statusStr = 'Pending';
    Color statusColor = const Color(0xFFffa500);
    
    if (isCompleted) {
      statusStr = 'Completed';
      statusColor = const Color(0xFF28a745);
    } else if (currentStage != null && currentStage != 'Submitted to factory') {
      statusStr = 'Running';
      statusColor = const Color(0xFF800080);
    }

    final createdAt = data['createdAt'] as Timestamp?;
    
    // Simulate time ago
    String timeAgo = 'Just now';
    if (createdAt != null) {
      final diff = DateTime.now().difference(createdAt.toDate());
      if (diff.inHours > 0) timeAgo = '${diff.inHours}h ago';
      else if (diff.inMinutes > 0) timeAgo = '${diff.inMinutes}m ago';
    }

    return GestureDetector(
      onTap: () {
        if (statusStr == 'Running') {
          Navigator.push(context, MaterialPageRoute(builder: (ctx) => LiveOrderTrackingScreen(initialSearchQuery: woNo)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (ctx) => WorkOrderDetailsScreen(orderId: id)));
        }
      },
        child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2BFB9).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withOpacity(0.05),
              border: Border(bottom: BorderSide(color: const Color(0xFFE2BFB9).withOpacity(0.5))),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(woNo, style: AppFonts.banglaHeading(color: Color(0xFF8B0000), fontWeight: FontWeight.w700, fontSize: 11)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (statusStr == 'Running')
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle))
                              .animate(onPlay: (c) => c.repeat()).fade(duration: 800.ms, begin: 0.3, end: 1),
                        ),
                      if (statusStr == 'Pending')
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        ),
                      Text(statusStr.toUpperCase(), style: AppFonts.banglaHeading(color: statusColor, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data['instructions']?.isNotEmpty == true ? data['instructions'] : 'Standard Order',
                        style: AppFonts.banglaBody(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1C1C)),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(timeAgo, style: AppFonts.banglaBody(fontSize: 10, color: Color(0xFF5A413D))),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Client: ${data['buyerName'] ?? 'Unknown'} | Priority: High', style: AppFonts.banglaBody(fontSize: 10, color: Color(0xFF5A413D))),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: const Color(0xFFE2BFB9).withOpacity(0.5)))),
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      if (statusStr == 'Pending') ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF28a745),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              textStyle: AppFonts.banglaHeading(fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.close, size: 14),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFba1a1a),
                              side: const BorderSide(color: Color(0xFFba1a1a)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              textStyle: AppFonts.banglaHeading(fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              disabledBackgroundColor: const Color(0xFFE2BFB9).withOpacity(0.3),
                              disabledForegroundColor: const Color(0xFF5A413D),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              textStyle: AppFonts.banglaHeading(fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('In Progress'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (ctx) => WorkOrderDetailsScreen(orderId: id)));
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF5A413D),
                              side: const BorderSide(color: Color(0xFF5A413D)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              textStyle: AppFonts.banglaHeading(fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Details'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
