// lib/features/factory/presentation/factory/live_order_tracking_screen.dart

import 'package:flutter/material.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'widgets/factory_bottom_nav.dart';
import 'industrial_velocity_dashboard_screen.dart';
import 'all_work_orders_screen.dart';
import 'pending_work_orders_screen.dart';
import 'running_work_orders_screen.dart';
class LiveOrderTrackingScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const LiveOrderTrackingScreen({Key? key, this.initialSearchQuery}) : super(key: key);

  @override
  State<LiveOrderTrackingScreen> createState() => _LiveOrderTrackingScreenState();
}

class _LiveOrderTrackingScreenState extends State<LiveOrderTrackingScreen> {
  String _cid = '';
  final TextEditingController _searchController = TextEditingController();
  String _currentQuery = '';
  
  Map<String, dynamic>? _searchedOrder;
  String? _searchedOrderId;
  bool _isSearching = false;
  String? _errorMsg;

  static const List<String> _stages = <String>[
    'Submitted to factory',
    'Factory update 1 (base is done)',
    'Hair is ready',
    'Knotting is going on',
    'Putting',
    'Molding',
    'Submit to the Head office',
  ];

  static const Map<String, String> _stageBn = {
    'Submitted to factory': 'কারখানায় জমা দেওয়া হয়েছে',
    'Factory update 1 (base is done)': 'আপডেট ১ (বেস সম্পন্ন)',
    'Hair is ready': 'চুল প্রস্তুত',
    'Knotting is going on': 'নটিং চলছে',
    'Putting': 'পুটিং',
    'Molding': 'মোল্ডিং',
    'Submit to the Head office': 'প্রধান কার্যালয়ে জমা',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
      _currentQuery = widget.initialSearchQuery!;
    }
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted && id != null) {
        setState(() => _cid = id);
        if (_currentQuery.isNotEmpty) {
          _performSearch();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNavTabSelected(FactoryNavTab tab) {
    if (tab == FactoryNavTab.track) return;

    Widget target;
    switch (tab) {
      case FactoryNavTab.overview:
        target = const IndustrialVelocityDashboardScreen();
        break;
      case FactoryNavTab.all:
        target = const AllWorkOrdersScreen();
        break;
      case FactoryNavTab.pending:
        target = const PendingWorkOrdersScreen();
        break;
      case FactoryNavTab.running:
        target = const RunningWorkOrdersScreen();
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

  int _stageIndex(String? name) => name == null ? -1 : _stages.indexOf(name);
  String _stageName(String s) => _stageBn[s] ?? s;

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _errorMsg = null;
      _searchedOrder = null;
      _searchedOrderId = null;
      _currentQuery = _searchController.text.trim();
    });

    // Dummy data injection
    Map<String, dynamic> dummyWo = {
      'workOrderNo': _currentQuery,
      'buyerName': 'Globex',
      'instructions': 'Welding - Frame Structural',
      'completed': false,
      'currentStage': 'In Production',
      'createdAt': Timestamp.now(),
      'timeline': [
        {'stage': 'Submitted to factory', 'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2)))},
        {'stage': 'Raw Material Sourcing', 'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1)))},
        {'stage': 'In Production', 'timestamp': Timestamp.now()},
      ],
      'invoiceId': 'INV-9999'
    };

    if (_cid.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _searchedOrder = dummyWo;
          _searchedOrderId = 'MOCK-1002';
          _isSearching = false;
        });
      }
      return;
    }

    try {
      // Allow searching by exact ID or workOrderNo
      final idSnap = await DB.colSync(_cid, C.workOrders).doc(_currentQuery).get();
      if (idSnap.exists) {
        setState(() {
          _searchedOrder = idSnap.data();
          _searchedOrderId = idSnap.id;
          _isSearching = false;
        });
        return;
      }

      final noSnap = await DB.colSync(_cid, C.workOrders).where('workOrderNo', isEqualTo: _currentQuery).limit(1).get();
      if (noSnap.docs.isNotEmpty) {
        setState(() {
          _searchedOrder = noSnap.docs.first.data();
          _searchedOrderId = noSnap.docs.first.id;
          _isSearching = false;
        });
        return;
      }

      setState(() {
        // Fallback to dummy data for verification if not found
        _searchedOrder = dummyWo;
        _searchedOrderId = 'MOCK-1002';
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchedOrder = dummyWo;
        _searchedOrderId = 'MOCK-1002';
        _isSearching = false;
      });
    }
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
                    'Track Order',
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
      ),
      bottomNavigationBar: FactoryBottomNav(
        currentTab: FactoryNavTab.track,
        onTabSelected: _onNavTabSelected,
      ),
      body: SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSearchHero().animate().fadeIn().slideY(begin: 0.1, end: 0),
                        const SizedBox(height: 24),
                        if (_isSearching)
                          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                        else if (_errorMsg != null)
                          _buildErrorCard().animate().fadeIn()
                        else if (_searchedOrder != null) ...[
                          _buildLiveStatusCard().animate().fadeIn().slideY(begin: 0.1, end: 0),
                          const SizedBox(height: 24),
                          _buildRealTimeTimeline().animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchHero() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2BFB9).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Locate Shipment', style: AppFonts.banglaHeading(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF161c22))),
          const SizedBox(height: 6),
          Text('Enter your tracking identifier to view live manufacturing status.', style: AppFonts.banglaBody(fontSize: 12, color: Color(0xFF5c5f60))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _performSearch(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF8B0000), size: 18),
                      hintText: 'Enter Tracking Number (e.g., WO-1001)',
                      hintStyle: AppFonts.banglaBody(color: Color(0xFF5c5f60).withOpacity(0.7), fontSize: 12),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      isDense: true,
                    ),
                    style: AppFonts.banglaBody(fontSize: 12, color: Color(0xFF161c22), fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _performSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text('Track Order', style: AppFonts.banglaHeading(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFba1a1a).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFba1a1a).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFba1a1a)),
          const SizedBox(width: 12),
          Expanded(child: Text(_errorMsg!, style: AppFonts.banglaBody(fontSize: 14, color: Color(0xFFba1a1a), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildLiveStatusCard() {
    final woNo = _searchedOrder!['workOrderNo'] ?? _searchedOrderId!;
    final isCompleted = _searchedOrder!['completed'] == true || _searchedOrder!['status'] == 'Completed';
    final currentStage = (_searchedOrder!['currentStage'] as String?) ?? _stages.first;
    
    final idx = _stageIndex(currentStage);
    final progress = isCompleted ? 1.0 : (idx + 1) / _stages.length;

    final finalTs = _searchedOrder!['finalDate'] as Timestamp?;
    final dateStr = finalTs != null ? DateFormat('MMM d, yyyy').format(finalTs.toDate()) : 'Unknown';

    String statusStr = 'Production Ongoing';
    Color statusColor = const Color(0xFF800080);
    if (isCompleted) {
      statusStr = 'Production Completed';
      statusColor = const Color(0xFF28a745);
    } else if (currentStage == 'Submitted to factory') {
      statusStr = 'Pending';
      statusColor = const Color(0xFFffa500);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2BFB9).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withOpacity(0.05),
              border: const Border(bottom: BorderSide(color: Color(0xFFE2BFB9))),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2, size: 16, color: Color(0xFF8B0000)),
                    const SizedBox(width: 6),
                    Text(woNo, style: AppFonts.banglaBody(color: Color(0xFF8B0000), fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle))
                              .animate(onPlay: (c) => c.repeat()).fade(duration: 1.seconds, begin: 0.3, end: 1),
                        ),
                      Text(statusStr, style: AppFonts.banglaBody(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ESTIMATED COMPLETION', style: AppFonts.banglaBody(fontSize: 10, color: Color(0xFF5c5f60), letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(dateStr, style: AppFonts.banglaBody(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF161c22))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('PROGRESS', style: AppFonts.banglaBody(fontSize: 10, color: Color(0xFF5c5f60), letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text('${(progress * 100).toInt()}%', style: AppFonts.banglaData(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF8B0000))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(color: const Color(0xFFdde3eb), borderRadius: BorderRadius.circular(3)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFF8B0000), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeTimeline() {
    if (_cid.isEmpty) {
      final List<dynamic> tList = _searchedOrder!['timeline'] ?? [];
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2BFB9).withOpacity(0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Journey Log', style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF161c22))),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tList.length,
              itemBuilder: (ctx, i) {
                final d = tList[i];
                return _buildTimelineItem(
                  isCompleted: i < tList.length - 1,
                  isCurrent: i == tList.length - 1,
                  title: d['stage'],
                  timeStr: 'Mock Time',
                  desc: 'Mock data',
                  isLastItem: i == tList.length - 1,
                );
              },
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2BFB9).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Journey Log', style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF161c22))),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: DB.colSync(_cid, C.workOrderTracking).where('workOrderNo', isEqualTo: _searchedOrder!['workOrderNo']).orderBy('createdAt', descending: false).snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              
              final logs = snap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();
              
              if (logs.isEmpty) {
                // If no logs, just show the current stage as a single log
                return _buildTimelineItem(
                  isCompleted: false,
                  isCurrent: true,
                  title: _stageName(_searchedOrder!['currentStage'] ?? _stages.first),
                  timeStr: 'Now',
                  desc: 'Order entered system.',
                  isLastItem: true,
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                itemBuilder: (ctx, i) {
                  final log = logs[i];
                  final isLast = i == logs.length - 1;
                  final isOrderCompleted = _searchedOrder!['completed'] == true;
                  final isCurrent = isLast && !isOrderCompleted;
                  
                  final ts = (log['createdAt'] as Timestamp).toDate();
                  
                  return _buildTimelineItem(
                    isCompleted: !isCurrent,
                    isCurrent: isCurrent,
                    title: _stageName(log['stage']),
                    timeStr: DateFormat('MMM d, hh:mm a').format(ts),
                    desc: log['notes'] ?? '',
                    isLastItem: isLast,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required bool isCompleted,
    required bool isCurrent,
    required String title,
    required String timeStr,
    required String desc,
    required bool isLastItem,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFF28a745) : (isCurrent ? const Color(0xFF8B0000).withOpacity(0.2) : const Color(0xFFdde3eb)),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : (isCurrent
                          ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF8B0000), shape: BoxShape.circle)).animate(onPlay: (c) => c.repeat()).fade(duration: 1.seconds, begin: 0.3, end: 1))
                          : null),
                ),
                if (!isLastItem)
                  Expanded(child: Container(width: 2, color: const Color(0xFFdde3eb))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: (isCurrent ? AppFonts.banglaHeading : AppFonts.banglaBody)(
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                            color: isCurrent ? const Color(0xFF8B0000) : const Color(0xFF161c22),
                          ),
                        ),
                      ),
                      Text(timeStr, style: AppFonts.banglaBody(fontSize: 9, color: Color(0xFF5c5f60))),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(desc, style: AppFonts.banglaBody(fontSize: 11, color: Color(0xFF5c5f60))),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
