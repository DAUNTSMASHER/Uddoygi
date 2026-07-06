import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  String _cid = '';

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
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        title: Text('Customer Relationships', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF1E0040), // _heroPurple
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DB.colSync(_cid, C.customers).snapshots(),
        builder: (context, custSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: DB.colSync(_cid, C.invoices).snapshots(),
            builder: (context, invSnap) {
              if (!custSnap.hasData || !invSnap.hasData) return const Center(child: CircularProgressIndicator());
              
              final customers = custSnap.data!.docs;
              final invoices = invSnap.data!.docs;
              final stats = _calculateCustomerStats(customers, invoices);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: UddoygiDesign.space20, vertical: UddoygiDesign.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(stats),
                    const SizedBox(height: UddoygiDesign.space32),
                    Text('Customer Tiering', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: UddoygiDesign.space16),
                    _buildCustomerTiering(stats.tieredCustomers),
                    const SizedBox(height: UddoygiDesign.space32),
                    Text('Aging Receivables (>30 Days)', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: UddoygiDesign.space16),
                    _buildAgingReceivables(stats.agingReceivables),
                    const SizedBox(height: UddoygiDesign.space32),
                    Text('At Risk (No orders in 30 days)', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: UddoygiDesign.space16),
                    _buildAtRiskCustomers(stats.atRisk),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(_CustomerDashboardStats stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard('Active Clients', '${stats.activeCount}', Icons.people_rounded, Colors.blue),
        _buildStatCard('Total Owed', '৳${NumberFormat('#,###').format(stats.totalOwed)}', Icons.money_off_rounded, Colors.redAccent),
        _buildStatCard('Gold Tier', '${stats.goldCount}', Icons.workspace_premium_rounded, Colors.amber),
        _buildStatCard('At Risk', '${stats.atRiskCount}', Icons.warning_amber_rounded, Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return UCard(
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF1E0040), letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildCustomerTiering(List<_TieredCustomer> customers) {
    return UCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: customers.map((c) => Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: UddoygiDesign.space16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.tierColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.workspace_premium_rounded, color: c.tierColor, size: 18),
              ),
              title: Text(c.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: Text(c.tierName, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.tierColor, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              trailing: Text(
                '৳${NumberFormat('#,###').format(c.totalSpend)}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1E0040)),
              ),
            ),
            if (customers.indexOf(c) != customers.length - 1)
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildAgingReceivables(List<_AgingInvoice> invoices) {
    if (invoices.isEmpty) {
      return UCard(
        padding: const EdgeInsets.all(UddoygiDesign.space24),
        child: Center(
          child: Text('No overdue payments', style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ),
      );
    }
    
    return Column(
      children: invoices.map((inv) => UCard(
        margin: const EdgeInsets.only(bottom: UddoygiDesign.space12),
        padding: const EdgeInsets.all(UddoygiDesign.space16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: UddoygiDesign.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv.customerName, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('${inv.daysLate} days overdue', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Text(
              '৳${NumberFormat('#,###').format(inv.amount)}',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.redAccent),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildAtRiskCustomers(List<_TieredCustomer> atRisk) {
    if (atRisk.isEmpty) {
      return UCard(
        padding: const EdgeInsets.all(UddoygiDesign.space24),
        child: Center(
          child: Text('All customers are active', style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ),
      );
    }

    return UCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: atRisk.map((c) => Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: UddoygiDesign.space16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.timer_off_rounded, color: Colors.orange, size: 18),
              ),
              title: Text(c.name, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: Text(
                'Last order: ${c.lastOrderDate != null ? DateFormat('MMM dd, yyyy').format(c.lastOrderDate!) : 'Never'}',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: UddoygiDesign.borderFull),
                child: Text('AT RISK', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
              ),
            ),
            if (atRisk.indexOf(c) != atRisk.length - 1)
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ],
        )).toList(),
      ),
    );
  }

  _CustomerDashboardStats _calculateCustomerStats(List<QueryDocumentSnapshot> customers, List<QueryDocumentSnapshot> invoices) {
    Map<String, double> customerSpend = {};
    Map<String, double> customerOwed = {};
    Map<String, DateTime?> customerLastOrder = {};
    
    for (var doc in invoices) {
      final data = doc.data() as Map<String, dynamic>;
      final cid = data['customerId'] ?? '';
      final total = (data['grandTotal'] as num?)?.toDouble() ?? 0;
      final status = data['status'] ?? '';
      final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

      customerSpend[cid] = (customerSpend[cid] ?? 0) + total;
      if (status != 'Payment Taken' && status != 'Completed') {
        customerOwed[cid] = (customerOwed[cid] ?? 0) + total;
      }
      
      if (customerLastOrder[cid] == null || ts.isAfter(customerLastOrder[cid]!)) {
        customerLastOrder[cid] = ts;
      }
    }

    List<_TieredCustomer> tiered = [];
    List<_TieredCustomer> atRisk = [];
    double totalOwed = 0;
    int goldCount = 0;

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    for (var doc in customers) {
      final d = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      final name = d['name'] ?? 'Unknown';
      final spend = customerSpend[id] ?? 0;
      final owed = customerOwed[id] ?? 0;
      final lastOrder = customerLastOrder[id];

      totalOwed += owed;
      if (spend > 1000000) goldCount++;

      final tc = _TieredCustomer(name: name, totalSpend: spend, lastOrderDate: lastOrder);
      tiered.add(tc);

      if (lastOrder == null || lastOrder.isBefore(thirtyDaysAgo)) {
        atRisk.add(tc);
      }
    }

    tiered.sort((a, b) => b.totalSpend.compareTo(a.totalSpend));
    final top10 = tiered.take(10).toList();

    List<_AgingInvoice> aging = [];
    for (var doc in invoices) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      if (status != 'Payment Taken' && status != 'Completed' && ts.isBefore(thirtyDaysAgo)) {
        aging.add(_AgingInvoice(
          customerName: data['customerName'] ?? 'Unknown',
          amount: (data['grandTotal'] as num?)?.toDouble() ?? 0,
          daysLate: DateTime.now().difference(ts).inDays,
        ));
      }
    }

    return _CustomerDashboardStats(
      activeCount: customers.length,
      totalOwed: totalOwed,
      goldCount: goldCount,
      atRiskCount: atRisk.length,
      tieredCustomers: top10,
      agingReceivables: aging,
      atRisk: atRisk.take(5).toList(),
    );
  }
}

class _CustomerDashboardStats {
  final int activeCount;
  final double totalOwed;
  final int goldCount;
  final int atRiskCount;
  final List<_TieredCustomer> tieredCustomers;
  final List<_AgingInvoice> agingReceivables;
  final List<_TieredCustomer> atRisk;

  _CustomerDashboardStats({
    required this.activeCount,
    required this.totalOwed,
    required this.goldCount,
    required this.atRiskCount,
    required this.tieredCustomers,
    required this.agingReceivables,
    required this.atRisk,
  });
}

class _TieredCustomer {
  final String name;
  final double totalSpend;
  final DateTime? lastOrderDate;
  _TieredCustomer({required this.name, required this.totalSpend, this.lastOrderDate});

  String get tierName {
    if (totalSpend > 1000000) return 'Gold';
    if (totalSpend > 500000) return 'Silver';
    return 'Bronze';
  }
  Color get tierColor {
    if (totalSpend > 1000000) return Colors.amber;
    if (totalSpend > 500000) return Colors.blueGrey;
    return Colors.brown;
  }
}

class _AgingInvoice {
  final String customerName;
  final double amount;
  final int daysLate;
  _AgingInvoice({required this.customerName, required this.amount, required this.daysLate});
}


  _CustomerDashboardStats _calculateCustomerStats(List<QueryDocumentSnapshot> customers, List<QueryDocumentSnapshot> invoices) {
    Map<String, double> customerSpend = {};
    Map<String, double> customerOwed = {};
    Map<String, DateTime?> customerLastOrder = {};
    
    for (var doc in invoices) {
      final data = doc.data() as Map<String, dynamic>;
      final cid = data['customerId'] ?? '';
      final total = (data['grandTotal'] as num?)?.toDouble() ?? 0;
      final status = data['status'] ?? '';
      final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

      customerSpend[cid] = (customerSpend[cid] ?? 0) + total;
      if (status != 'Payment Taken' && status != 'Completed') {
        customerOwed[cid] = (customerOwed[cid] ?? 0) + total;
      }
      
      if (customerLastOrder[cid] == null || ts.isAfter(customerLastOrder[cid]!)) {
        customerLastOrder[cid] = ts;
      }
    }

    List<_TieredCustomer> tiered = [];
    List<_TieredCustomer> atRisk = [];
    double totalOwed = 0;
    int goldCount = 0;

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    for (var doc in customers) {
      final d = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      final name = d['name'] ?? 'Unknown';
      final spend = customerSpend[id] ?? 0;
      final owed = customerOwed[id] ?? 0;
      final lastOrder = customerLastOrder[id];

      totalOwed += owed;
      if (spend > 1000000) goldCount++;

      final tc = _TieredCustomer(name: name, totalSpend: spend, lastOrderDate: lastOrder);
      tiered.add(tc);

      if (lastOrder == null || lastOrder.isBefore(thirtyDaysAgo)) {
        atRisk.add(tc);
      }
    }

    tiered.sort((a, b) => b.totalSpend.compareTo(a.totalSpend));
    final top10 = tiered.take(10).toList();

    List<_AgingInvoice> aging = [];
    for (var doc in invoices) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      if (status != 'Payment Taken' && status != 'Completed' && ts.isBefore(thirtyDaysAgo)) {
        aging.add(_AgingInvoice(
          customerName: data['customerName'] ?? 'Unknown',
          amount: (data['grandTotal'] as num?)?.toDouble() ?? 0,
          daysLate: DateTime.now().difference(ts).inDays,
        ));
      }
    }

    return _CustomerDashboardStats(
      activeCount: customers.length,
      totalOwed: totalOwed,
      goldCount: goldCount,
      atRiskCount: atRisk.length,
      tieredCustomers: top10,
      agingReceivables: aging,
      atRisk: atRisk.take(5).toList(),
    );
  }
}

class _CustomerDashboardStats {
  final int activeCount;
  final double totalOwed;
  final int goldCount;
  final int atRiskCount;
  final List<_TieredCustomer> tieredCustomers;
  final List<_AgingInvoice> agingReceivables;
  final List<_TieredCustomer> atRisk;

  _CustomerDashboardStats({
    required this.activeCount,
    required this.totalOwed,
    required this.goldCount,
    required this.atRiskCount,
    required this.tieredCustomers,
    required this.agingReceivables,
    required this.atRisk,
  });
}

class _TieredCustomer {
  final String name;
  final double totalSpend;
  final DateTime? lastOrderDate;
  _TieredCustomer({required this.name, required this.totalSpend, this.lastOrderDate});

  String get tierName {
    if (totalSpend > 1000000) return 'Gold';
    if (totalSpend > 500000) return 'Silver';
    return 'Bronze';
  }
  Color get tierColor {
    if (totalSpend > 1000000) return Colors.amber;
    if (totalSpend > 500000) return Colors.blueGrey;
    return Colors.brown;
  }
}

class _AgingInvoice {
  final String customerName;
  final double amount;
  final int daysLate;
  _AgingInvoice({required this.customerName, required this.amount, required this.daysLate});
}
