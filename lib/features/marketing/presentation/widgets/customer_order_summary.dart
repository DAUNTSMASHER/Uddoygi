// lib/features/marketing/presentation/widgets/customer_order_summary.dart
//
// TWO MODES + "AGENT DASHBOARD" HEADER (always agent-only)
// ------------------------------------------------------------
// MODE A (Per-customer): pass a non-empty `email`
//   • Header & pie = ALL orders for the logged-in agent
//   • Order list   = ONLY this customer's orders for the agent
// MODE B (Tab/Bar "Orders Summary"): pass an empty `email`
//   • Header & pie = ALL orders for the logged-in agent
//   • Order list   = ALL orders for the logged-in agent
//
// Add to pubspec.yaml (if not already present):
// dependencies:
//   google_fonts: ^6.2.1
//   circle_flags: ^3.0.1
//   fl_chart: ^0.68.0

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:circle_flags/circle_flags.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/order_details.dart';

class CustomerOrderSummary extends StatefulWidget {
  /// If non-empty => Per-customer list (but header is agent-wide)
  /// If empty     => Agent summary (header + list are agent-wide)
  final String email;
  const CustomerOrderSummary({super.key, required this.email});

  @override
  State<CustomerOrderSummary> createState() => _CustomerOrderSummaryState();
}

class _CustomerOrderSummaryState extends State<CustomerOrderSummary> {
  String? agentEmail;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final session = await LocalStorageService.getSession();
    if (!mounted) return;
    setState(() => agentEmail = session?['email']);
  }

  // ---------- parsing helpers ----------
  int _extractQty(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  DateTime _bestDate(Map<String, dynamic> data) {
    final d1 = data['date'];
    final d2 = data['timestamp'];
    final d3 = data['createdAt'];
    if (d1 is Timestamp) return d1.toDate();
    if (d2 is Timestamp) return d2.toDate();
    if (d3 is Timestamp) return d3.toDate();
    return DateTime.now();
  }

  String _formatCurrency(num v) {
    final d = NumberFormat.currency(locale: 'en_BD', symbol: '৳', decimalDigits: 0);
    return d.format(v);
  }

  // ---------- UI helpers ----------
  Widget _statTile({
    required IconData icon,
    required String label,
    required num value,
    Duration duration = const Duration(milliseconds: 900),
  }) {
    final isMoney = label.toLowerCase().contains('amount');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value.toDouble()),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (_, val, __) => Text(
            isMoney ? _formatCurrency(val) : val.toStringAsFixed(0),
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _statusSections(int shipped, int pending) {
    final total = shipped + pending;
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: Colors.blueGrey.shade100,
          title: 'No data',
          titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54),
        ),
      ];
    }
    return [
      PieChartSectionData(
        value: shipped.toDouble(),
        color: Colors.green.shade500,
        title: 'Shipped\n${((shipped / total) * 100).toStringAsFixed(0)}%',
        radius: 48,
        titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
      ),
      PieChartSectionData(
        value: pending.toDouble(),
        color: Colors.orange.shade500,
        title: 'Pending\n${((pending / total) * 100).toStringAsFixed(0)}%',
        radius: 48,
        titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    ];
  }

  Widget _orderCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = _bestDate(data);
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    final items = (data['items'] as List<dynamic>? ?? const []);
    final quantity = items.fold<int>(0, (sum, it) => sum + _extractQty(it['qty']));
    final grandTotal = _toDouble(data['grandTotal']);

    final status = (data['status'] ?? 'Pending').toString();
    final country = (data['country'] ?? 'N/A').toString();
    final countryCode = (data['countryCode'] ?? '').toString().toUpperCase();

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: doc)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              // Leading: flag or receipt icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.indigo.shade50,
                ),
                alignment: Alignment.center,
                child: (countryCode.length == 2)
                    ? ClipOval(child: CircleFlag(countryCode, size: 48))
                    : const Icon(Icons.receipt_long, color: Colors.indigo),
              ),
              const SizedBox(width: 12),
              // Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount + qty line
                    Text(
                      '${_formatCurrency(grandTotal)} • Qty: $quantity',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Status + Country + Date
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chipSmall(
                          icon: Icons.verified_outlined,
                          text: 'Status: $status',
                          color: status.toLowerCase() == 'shipped'
                              ? Colors.green.shade600
                              : Colors.orange.shade700,
                        ),
                        _chipSmall(
                          icon: Icons.flag_outlined,
                          text: 'Country: $country',
                          color: Colors.blueGrey.shade700,
                        ),
                        _chipSmall(
                          icon: Icons.calendar_month_outlined,
                          text: 'Date: $formattedDate',
                          color: Colors.blueGrey.shade700,
                        ),
                      ],
                    ),
                    if (data['note'] != null && '${data['note']}'.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Note: ${data['note']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,                 // was 12
                          fontWeight: FontWeight.w400,  // was w500-ish
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    ],

                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipSmall({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // a bit tighter
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color), // smaller icon to match small text
          const SizedBox(width: 4),
          Text(
            text,
            // ↓↓↓ size 10, weight 400 per your spec
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(fontWeight: FontWeight.w800);
    final perCustomer = (widget.email.trim().isNotEmpty);

    return Scaffold(

      body: agentEmail == null
          ? const Center(child: CircularProgressIndicator())
          : perCustomer
      // MODE A: Header = agent-wide; List = this customer
          ? _AgentHeaderPlusCustomerList(
        agentEmail: agentEmail!,
        customerEmail: widget.email.trim(),
        buildHeader: _buildHeader,
        buildOrderCard: _orderCard,
      )
      // MODE B: Header = agent-wide; List = agent-wide
          : _AgentAllInvoices(
        agentEmail: agentEmail!,
        buildHeader: _buildHeader,
        buildOrderCard: _orderCard,
      ),
    );
  }

  /// Shared header+list layout builder (used after stats are computed)
  Widget _buildHeader({
    required int ordersCount,
    required double totalAmount,
    required int totalQuantity,
    required int shipped,
    required int pending,
    required List<QueryDocumentSnapshot> orders,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Dashboard Header Card (AGENT-WIDE)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade700, Colors.indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statTile(icon: Icons.list,               label: 'Orders',   value: ordersCount),
                _statTile(icon: Icons.monetization_on,     label: 'Amount',   value: totalAmount),
                _statTile(icon: Icons.inventory_2_rounded, label: 'Quantity', value: totalQuantity),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Pie Chart (AGENT-WIDE)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Order Status Distribution',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12.withOpacity(.06)),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: PieChart(
              PieChartData(
                sections: _statusSections(
                  // shipped/pending passed in are agent-wide
                  // (for per-customer mode we still pass agent stats)
                  shipped,
                  pending,
                ),
                sectionsSpace: 4,
                centerSpaceRadius: 42,
                startDegreeOffset: -90,
              ),
              swapAnimationCurve: Curves.easeOutCubic,
              swapAnimationDuration: const Duration(milliseconds: 700),
            ),
          ),

          const SizedBox(height: 20),

          // Orders List (the caller decides which list to pass)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Detailed Orders',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) => _orderCard(orders[index]),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================================
   MODE A helper:
   AGENT header (stats) + PER-CUSTOMER order list
============================================================================ */

class _AgentHeaderPlusCustomerList extends StatelessWidget {
  final String agentEmail;
  final String customerEmail;
  final Widget Function({
  required int ordersCount,
  required double totalAmount,
  required int totalQuantity,
  required int shipped,
  required int pending,
  required List<QueryDocumentSnapshot> orders,
  }) buildHeader;
  final Widget Function(QueryDocumentSnapshot doc) buildOrderCard;

  const _AgentHeaderPlusCustomerList({
    required this.agentEmail,
    required this.customerEmail,
    required this.buildHeader,
    required this.buildOrderCard,
  });

  int _extractQty(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // Stream ALL invoices for this agent (for header/pie)
    final agentInvoicesQ = FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: agentEmail)
        .orderBy('timestamp', descending: true);

    // Stream ONLY this customer's invoices for this agent (for list)
    final customerInvoicesQ = FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: agentEmail)
        .where('customerEmail', isEqualTo: customerEmail)
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: agentInvoicesQ.snapshots(),
      builder: (context, agentSnap) {
        if (!agentSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final agentOrders = agentSnap.data!.docs;

        // Compute AGENT-WIDE stats for header/pie
        double agentTotalAmount = 0;
        int agentTotalQuantity = 0;
        int shipped = 0;
        int pending = 0;

        for (var doc in agentOrders) {
          final data = doc.data();
          final grandTotal = _toDouble(data['grandTotal']);
          final items = data['items'] as List<dynamic>? ?? const [];
          final quantity = items.fold<int>(0, (sum, item) => sum + _extractQty(item['qty']));
          final status = (data['status'] ?? 'Pending').toString();

          agentTotalAmount += grandTotal;
          agentTotalQuantity += quantity;
          if (status.toLowerCase() == 'shipped') shipped++;
          if (status.toLowerCase() == 'pending') pending++;
        }

        // Now stream PER-CUSTOMER list to show beneath the agent header/pie
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: customerInvoicesQ.snapshots(),
          builder: (context, custSnap) {
            if (!custSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final customerOrders = custSnap.data!.docs;

            // Pass agent stats + customer orders list to the shared header renderer
            return buildHeader(
              ordersCount: agentOrders.length,         // agent-wide count (dashboard)
              totalAmount: agentTotalAmount,           // agent-wide total
              totalQuantity: agentTotalQuantity,       // agent-wide quantity
              shipped: shipped,                        // agent-wide shipped
              pending: pending,                        // agent-wide pending
              orders: customerOrders,                  // LIST shows this customer's orders
            );
          },
        );
      },
    );
  }
}

/* ============================================================================
   MODE B: Agent-wide invoices stream (ALL orders for this agent)
============================================================================ */

class _AgentAllInvoices extends StatelessWidget {
  final String agentEmail;
  final Widget Function({
  required int ordersCount,
  required double totalAmount,
  required int totalQuantity,
  required int shipped,
  required int pending,
  required List<QueryDocumentSnapshot> orders,
  }) buildHeader;
  final Widget Function(QueryDocumentSnapshot doc) buildOrderCard;

  const _AgentAllInvoices({
    required this.agentEmail,
    required this.buildHeader,
    required this.buildOrderCard,
  });

  int _extractQty(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // Stream ALL invoices for this agent (header + list)
    final invoicesQ = FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: agentEmail)
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: invoicesQ.snapshots(),
      builder: (context, invSnap) {
        if (!invSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = invSnap.data!.docs;

        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.blueGrey.shade300),
                  const SizedBox(height: 10),
                  Text('No orders for this agent yet.',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          );
        }

        double totalAmount = 0;
        int totalQuantity = 0;
        int shipped = 0;
        int pending = 0;

        for (var doc in orders) {
          final data = doc.data();
          final grandTotal = _toDouble(data['grandTotal']);
          final items = data['items'] as List<dynamic>? ?? const [];
          final quantity = items.fold<int>(0, (sum, item) => sum + _extractQty(item['qty']));
          final status = (data['status'] ?? 'Pending').toString();

          totalAmount += grandTotal;
          totalQuantity += quantity;
          if (status.toLowerCase() == 'shipped') shipped++;
          if (status.toLowerCase() == 'pending') pending++;
        }

        return buildHeader(
          ordersCount: orders.length,
          totalAmount: totalAmount,
          totalQuantity: totalQuantity,
          shipped: shipped,
          pending: pending,
          orders: orders, // list = agent-wide
        );
      },
    );
  }
}
