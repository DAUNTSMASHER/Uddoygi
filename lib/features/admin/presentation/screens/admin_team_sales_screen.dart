import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminTeamSalesScreen extends StatefulWidget {
  const AdminTeamSalesScreen({super.key});

  @override
  State<AdminTeamSalesScreen> createState() => _AdminTeamSalesScreenState();
}

class _AdminTeamSalesScreenState extends State<AdminTeamSalesScreen> {
  String _cid = '';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadCid();
  }

  Future<void> _loadCid() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (mounted) setState(() => _cid = id ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Team Performance', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DB.colSync(_cid, C.invoices).snapshots(),
        builder: (context, invSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: DB.colSync(_cid, C.users).snapshots(),
            builder: (context, userSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: DB.colSync(_cid, C.tasks).snapshots(),
                builder: (context, taskSnap) {
                  if (!invSnap.hasData || !userSnap.hasData || !taskSnap.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final invoices = invSnap.data!.docs;
                  final users = userSnap.data!.docs;
                  final tasks = taskSnap.data!.docs;
                  final stats = _calculateTeamStats(invoices, users, tasks);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCards(stats),
                        const SizedBox(height: 24),
                        _buildLeaderboard(stats.performance),
                        const SizedBox(height: 24),
                        _buildOrderWiseReport(invoices),
                        const SizedBox(height: 80),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(_TeamDashboardStats stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard('Total Sales', '৳${stats.totalSales.toStringAsFixed(0)}', Icons.point_of_sale, Colors.green),
        _buildStatCard('Collected', '৳${stats.cashCollected.toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.blue),
        _buildStatCard('Pending', '৳${stats.pendingPayments.toStringAsFixed(0)}', Icons.timer, Colors.red),
        _buildStatCard('Top Performer', stats.topPerformer, Icons.emoji_events, Colors.amber),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
              Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildLeaderboard(List<_UserPerformance> performance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sales & Meeting Leaderboard', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
          child: Column(
            children: performance.map((p) => ListTile(
              leading: CircleAvatar(backgroundColor: Colors.indigo[50], child: Text(p.name[0], style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))),
              title: Text(p.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              subtitle: Text('${p.meetingCount} Meetings logged', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('৳${p.salesAmount.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.indigo)),
                  Text('${p.orderCount} Orders', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderWiseReport(List<QueryDocumentSnapshot> docs) {
    final filtered = docs.where((d) {
      final data = d.data() as Map;
      final name = (data['customerName'] ?? '').toString().toLowerCase();
      final agent = (data['agentName'] ?? '').toString().toLowerCase();
      final no = (data['invoiceNo'] ?? '').toString().toLowerCase();
      return name.contains(_search.toLowerCase()) || agent.contains(_search.toLowerCase()) || no.contains(_search.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Order-Wise Reports', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${filtered.length} found', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search orders, customers, agents...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        ...filtered.take(20).map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final status = d['status'] ?? 'Draft';
          final color = status == 'Payment Taken' || status == 'Completed' ? Colors.green : Colors.orange;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['customerName'] ?? 'Walk-in', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    Text('Agent: ${d['agentName'] ?? 'System'}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('৳${(d['grandTotal'] ?? 0).toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(status, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                  ),
                ]),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  _TeamDashboardStats _calculateTeamStats(List<QueryDocumentSnapshot> invoices, List<QueryDocumentSnapshot> users, List<QueryDocumentSnapshot> tasks) {
    double totalSales = 0;
    double cashCollected = 0;
    Map<String, _UserPerformance> performanceMap = {};

    for (var u in users) {
      final d = u.data() as Map;
      if (d['department'] == 'Marketing' || d['department'] == 'Sales') {
        final name = d['fullName'] ?? d['name'] ?? 'Agent';
        performanceMap[u.id] = _UserPerformance(name: name);
      }
    }

    for (var doc in invoices) {
      final d = doc.data() as Map<String, dynamic>;
      final total = (d['grandTotal'] as num?)?.toDouble() ?? 0;
      final status = d['status'] ?? '';
      final agentId = d['agentId'] ?? d['ownerUid'] ?? '';

      totalSales += total;
      if (status == 'Payment Taken' || status == 'Completed') {
        cashCollected += total;
      }

      if (performanceMap.containsKey(agentId)) {
        performanceMap[agentId]!.salesAmount += total;
        performanceMap[agentId]!.orderCount++;
      }
    }

    for (var t in tasks) {
      final d = t.data() as Map;
      final assigneeId = d['assigneeId'] ?? '';
      if (performanceMap.containsKey(assigneeId)) {
        performanceMap[assigneeId]!.meetingCount++;
      }
    }

    final performance = performanceMap.values.toList()
      ..sort((a, b) => b.salesAmount.compareTo(a.salesAmount));

    String topPerformer = performance.isNotEmpty ? performance.first.name : 'N/A';

    return _TeamDashboardStats(
      totalSales: totalSales,
      cashCollected: cashCollected,
      pendingPayments: totalSales - cashCollected,
      topPerformer: topPerformer,
      performance: performance.take(5).toList(),
    );
  }
}

class _TeamDashboardStats {
  final double totalSales;
  final double cashCollected;
  final double pendingPayments;
  final String topPerformer;
  final List<_UserPerformance> performance;
  _TeamDashboardStats({required this.totalSales, required this.cashCollected, required this.pendingPayments, required this.topPerformer, required this.performance});
}

class _UserPerformance {
  final String name;
  double salesAmount = 0;
  int orderCount = 0;
  int meetingCount = 0;
  _UserPerformance({required this.name});
}
