// lib/features/marketing/presentation/screens/sales_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'new_invoices_screen.dart';
import 'all_invoices_screen.dart';
import 'sales_report_screen.dart';
import 'order_progress_screen.dart';
import 'work_order_screen.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const Color _ink = Color(0xFF1D5DF1);
const Color _surface = Color(0xFFF4F6FA);
const Color _cardBg = Colors.white;
const Color _okGreen = Color(0xFF2ECC71);

/// Quick-action model (top-level)
class _Feature {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _Feature(this.icon, this.label, this.onTap);
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  static const double _fontSmall   = 12;
  static const double _fontRegular = 14;
  static const double _fontLarge   = 16;

  double salesTarget   = 100000;
  int    orderCount    = 0;     // paid orders (selected month)
  double totalSales    = 0;     // paid amount only (selected month)
  String? userEmail;
  bool   targetReached = false;
  DateTime selectedMonth = DateTime.now();

  int _activeTabIndex = 0;

  // bottom nav
  int _bottomIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    final session = await LocalStorageService.getSession();
    if (session != null && mounted) {
      userEmail = session['email'];
      await _calculateUserSales();
      setState(() {});
    }
  }

  /// Update: count/sum **only PAID** invoices for the selected month
  Future<void> _calculateUserSales() async {
    if (userEmail == null) return;
    final start = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final end   = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    final snap = await FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: userEmail)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    double paidTotal = 0;
    int paidCount = 0;

    bool _isPaid(Map<String, dynamic> m) {
      final paidByFlag = (m['payment'] is Map) && ((m['payment']['taken'] as bool?) ?? false);
      final s = (m['status'] ?? '').toString().toLowerCase();
      return paidByFlag || s.contains('payment taken') || s.contains('paid');
    }

    for (var doc in snap.docs) {
      final m = doc.data();
      if (_isPaid(m)) {
        paidTotal += (m['grandTotal'] as num? ?? 0).toDouble();
        paidCount += 1;
      }
    }

    if (mounted) {
      setState(() {
        totalSales    = paidTotal;
        orderCount    = paidCount;
        targetReached = totalSales >= salesTarget;
      });
    }
  }

  Future<void> _selectMonth(BuildContext ctx) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: selectedMonth,
      firstDate: DateTime(2025, 1),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (c, w) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _darkBlue),
        ),
        child: w!,
      ),
    );
    if (picked != null && picked != selectedMonth) {
      setState(() => selectedMonth = picked);
      await _calculateUserSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sw = media.size.width;
    final isSmall = sw < 360;

    if (userEmail == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Last 30 days invoices for header counters + recent list
    final since = DateTime.now().subtract(const Duration(days: 30));
    final invQuery = FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: userEmail)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: Colors.white, // rest of the page is white
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Sales Dashboard',
          style: TextStyle(
            fontSize: isSmall ? _fontRegular : _fontLarge,
            fontWeight: FontWeight.w800,
            color: Colors.white, // label foreground white
          ),
        ),
        centerTitle: true,
        elevation: 4,
        shadowColor: Colors.black26,
        backgroundColor: _darkBlue,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_darkBlue, _ink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: invQuery.snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          // Header counters (counts for last 30d)
          final totalInvoices = docs.length;
          final paid = docs.where((d) {
            final m = d.data();
            final paidByFlag = (m['payment'] is Map) && ((m['payment']['taken'] as bool?) ?? false);
            final status = (m['status'] ?? '').toString().toLowerCase();
            return paidByFlag || status.contains('paid') || status.contains('payment taken');
          }).length;
          final pending = totalInvoices - paid;

          return CustomScrollView(
            slivers: [
              // Glass header with 4 KPIs + month pill
              SliverToBoxAdapter(
                child: _glassHeader(
                  totalInvoices: totalInvoices,
                  paid: paid,
                  pending: pending,
                ),
              ),

              // Five quick actions (kept; page background is white, labels dark blue)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: _featuresGrid(context)),
              ),

              // Section title
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Recent transactions',
                    style: TextStyle(
                      fontSize: _fontLarge,
                      fontWeight: FontWeight.w900,
                      color: _darkBlue,
                    ),
                  ),
                ),
              ),

              // Segmented control
              SliverToBoxAdapter(child: _segmentedTabs()),

              // Content
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _activeTabIndex == 0
                      ? _recentInvoicesList(docs)
                      : (_activeTabIndex == 1 ? _expensesList() : _incomeList()),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          );
        },
      ),

      // Bottom Navigation Bar (blue background, white labels/icons)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _darkBlue,
          boxShadow: [
            BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, -3)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _bottomIndex,
            onTap: (i) {
              setState(() => _bottomIndex = i);
              switch (i) {
                case 0:
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NewInvoicesScreen()));
                  break;
                case 1:
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AllInvoicesScreen()));
                  break;
                case 2:
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkOrderScreen()));
                  break;
                case 3:
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen()));
                  break;
                case 4:
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderProgressScreen()));
                  break;
              }
            },
            backgroundColor: _darkBlue,               // blue background
            selectedItemColor: Colors.white,          // label/icon white
            unselectedItemColor: Colors.white70,      // slightly dimmed white
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.description_rounded), label: 'New'),
              BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Invoices'),
              BottomNavigationBarItem(icon: Icon(Icons.work_history_rounded), label: 'Work'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
              BottomNavigationBarItem(icon: Icon(Icons.timeline_rounded), label: 'Progress'),
            ],
          ),
        ),
      ),
    );
  }

  // ——————————————————— Header ———————————————————
  Widget _glassHeader({
    required int totalInvoices,
    required int paid,
    required int pending,
  }) {
    final achievement = (salesTarget == 0)
        ? 0.0
        : (totalSales / salesTarget * 100).clamp(0.0, 100.0).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDEFDF4), Color(0xFFF4FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting + month pill
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your business at a glance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _darkBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _pillButton(
                icon: Icons.calendar_month_rounded,
                label: DateFormat.yMMMM().format(selectedMonth),
                onTap: () => _selectMonth(context),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4 KPIs (Target, Achieved [PAID ONLY], Orders [PAID ONLY], Progress)
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              final cross = wide ? 4 : 2;
              final aspect = wide ? 3.1 : 2.2;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: aspect,
                ),
                children: [
                  _kpiTiny(
                    label: 'Target',
                    value: '৳${salesTarget.toStringAsFixed(0)}',
                    icon: Icons.flag_rounded,
                    accent: _darkBlue,
                  ),
                  _kpiTiny(
                    label: 'Achieved (Paid)',
                    value: '৳${totalSales.toStringAsFixed(0)}',
                    icon: Icons.payments_rounded,
                    accent: _okGreen,
                  ),
                  _kpiTiny(
                    label: 'Orders (Paid)',
                    value: '$orderCount',
                    icon: Icons.receipt_long_rounded,
                    accent: const Color(0xFF20B2AA),
                  ),
                  _kpiTiny(
                    label: 'Progress',
                    value: '${achievement.toStringAsFixed(0)}%',
                    icon: Icons.trending_up_rounded,
                    accent: _ink,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),

          // Inline quick counters for last 30d (kept subtle)
          Row(
            children: [
              Expanded(child: _pillStat('Total', totalInvoices.toString())),
              const SizedBox(width: 8),
              Expanded(child: _pillStat('Paid', paid.toString(), color: const Color(0xFF21C7A8))),
              const SizedBox(width: 8),
              Expanded(child: _pillStat('Pending', pending.toString(), color: Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiTiny({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    color: _darkBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillStat(String label, String value, {Color color = _darkBlue}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ——————————————————— Quick actions (5 only) ———————————————————
  Widget _featuresGrid(BuildContext context) {
    final tiles = <_Feature>[
      _Feature(Icons.description_rounded, 'New invoice', () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NewInvoicesScreen()));
      }),
      _Feature(Icons.list_alt_rounded, 'All invoices', () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AllInvoicesScreen()));
      }),
      _Feature(Icons.work_history_rounded, 'Work orders', () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkOrderScreen()));
      }),
      _Feature(Icons.bar_chart_rounded, 'Reports', () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen()));
      }),
      _Feature(Icons.timeline_rounded, 'Progress', () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderProgressScreen()));
      }),
    ];

    // 3 per row on phones, 5 in one row on wide screens
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 5 : 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: wide ? 1.15 : .98,
          ),
          itemBuilder: (_, i) => _featureTile(tiles[i]),
        );
      },
    );
  }

  Widget _featureTile(_Feature f) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: f.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _darkBlue.withOpacity(.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(f.icon, color: _darkBlue),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                f.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _darkBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ——————————————————— Tabs ———————————————————
  Widget _segmentedTabs() {
    final tabs = ['All invoices', 'Expenses', 'Income'];
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = i == _activeTabIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTabIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF21C7A8).withOpacity(.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? const Color(0xFF21C7A8) : _darkBlue,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ——————————————————— Lists ———————————————————
  Widget _recentInvoicesList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: _emptyCard('No invoices in the last 30 days'),
      );
    }
    return Column(
      key: const ValueKey('invoices'),
      children: [
        const SizedBox(height: 6),
        ...docs.take(15).map((d) => _invoiceRow(d.id, d.data())).toList(),
      ],
    );
  }

  Widget _expensesList() {
    return Padding(
      key: const ValueKey('expenses'),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: _emptyCard('No expenses recorded'),
    );
  }

  Widget _incomeList() {
    return Padding(
      key: const ValueKey('income'),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: _emptyCard('No income records'),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _darkBlue.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inbox, color: _darkBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceRow(String id, Map<String, dynamic> m) {
    final customer = (m['customerName'] ?? 'N/A').toString();
    final amt      = ((m['grandTotal'] as num?) ?? 0).toDouble();
    final tracking = (m['tracking_number'] ?? '').toString();
    final status   = (m['status'] ?? '').toString();
    final ts       = m['timestamp'];
    final date     = ts is Timestamp ? ts.toDate() : DateTime.now();

    final isPaid = () {
      final paidByFlag = (m['payment'] is Map) && ((m['payment']['taken'] as bool?) ?? false);
      final s = status.toLowerCase();
      return paidByFlag || s.contains('paid') || s.contains('payment taken');
    }();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isPaid ? const Color(0xFF21C7A8) : Colors.orange).withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isPaid ? Icons.check_circle : Icons.schedule,
                color: isPaid ? const Color(0xFF21C7A8) : Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showDetails(id, m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _darkBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _statusDot(isPaid ? 'Paid' : 'Unpaid',
                          color: isPaid ? const Color(0xFF21C7A8) : Colors.orange),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          tracking.isEmpty
                              ? DateFormat('dd MMM, yyyy').format(date)
                              : tracking,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '৳${amt.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: _darkBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDot(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ——————————————————— Shared UI helpers ———————————————————
  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.black12.withOpacity(.06)),
            boxShadow: const [
              BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3)),
            ],
            gradient: const LinearGradient(
              colors: [Color(0xFFF8FBFF), Color(0xFFF5FFFB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: _darkBlue, size: 18),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    color: _darkBlue,
                    fontSize: _fontRegular,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(14)}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
        border: Border.all(color: Colors.black12.withOpacity(.06)),
      ),
      padding: padding,
      child: child,
    );
  }

  // Minimal details bottom sheet
  void _showDetails(String id, Map<String, dynamic> m) {
    final customer = (m['customerName'] ?? 'N/A').toString();
    final amt = ((m['grandTotal'] as num?) ?? 0).toDouble();
    final tracking = (m['tracking_number'] ?? '').toString();
    final status   = (m['status'] ?? '').toString();
    final ts       = m['timestamp'];
    final date = ts is Timestamp ? ts.toDate() : DateTime.now();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              _kv('Status', status.isEmpty ? '—' : status),
              _kv('Tracking', tracking.isEmpty ? '—' : tracking),
              _kv('Date', DateFormat('dd MMM, yyyy').format(date)),
              _kv('Amount', '৳${amt.toStringAsFixed(0)}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AllInvoicesScreen()),
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Go to invoice'),
                      style: OutlinedButton.styleFrom(foregroundColor: _darkBlue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _darkBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
