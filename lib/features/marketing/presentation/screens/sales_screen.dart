// lib/features/marketing/presentation/screens/sales_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:fl_chart/fl_chart.dart';
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
  int    orderCount    = 0;
  double totalSales    = 0;
  String? userEmail;
  bool   targetReached = false;
  DateTime selectedMonth = DateTime.now();
  bool showSummary = true;
  bool showPie     = false;

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
    }
  }

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

    double total = 0;
    for (var doc in snap.docs) {
      total += (doc.data()['grandTotal'] as num? ?? 0).toDouble();
    }

    if (mounted) {
      setState(() {
        totalSales    = total;
        orderCount    = snap.docs.length;
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
    final double achievement =
    (totalSales / salesTarget * 100).clamp(0.0, 100.0).toDouble();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Sales Dashboard', style: TextStyle(fontSize: _fontLarge)),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_darkBlue, _ink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectMonth(context),
          )
        ],
      ),
      body: userEmail == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (context, constraints) {
          // Responsive counts
          final bool wide = constraints.maxWidth >= 900;
          final int statCols = constraints.maxWidth >= 1200
              ? 4
              : (constraints.maxWidth >= 700 ? 2 : 1);
          final int actionCols = constraints.maxWidth >= 700 ? 3 : 2;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar (month + filter)
                _pageHeader(achievement),

                const SizedBox(height: 14),

                // KPI row: Target / Sales / Orders / Achievement (grid, responsive)
                _sectionHeader('Summary', showSummary, () {
                  setState(() => showSummary = !showSummary);
                }),
                if (showSummary) ...[
                  const SizedBox(height: 8),
                  GridView(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: statCols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: wide ? 2.8 : 2.2,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _kpiCard(
                        title: 'Revenue',
                        value: '৳${totalSales.toStringAsFixed(0)}',
                        icon: Icons.payments,
                        accent: _okGreen,
                        footer: 'This month • ${DateFormat.yMMM().format(selectedMonth)}',
                      ),
                      _kpiCard(
                        title: 'Sales Target',
                        value: '৳${salesTarget.toStringAsFixed(0)}',
                        icon: Icons.flag,
                        accent: _darkBlue,
                        footer: 'Progress shown below',
                        trailing: _miniProgress(achievement),
                      ),
                      _kpiCard(
                        title: 'Orders',
                        value: '$orderCount',
                        icon: Icons.receipt_long,
                        accent: const Color(0xFF20B2AA),
                        footer: 'Created this month',
                      ),
                      _kpiCard(
                        title: 'Achievement',
                        value: '${achievement.toStringAsFixed(1)}%',
                        icon: Icons.trending_up,
                        accent: _ink,
                        footer: targetReached ? 'Target achieved 🎉' : 'Keep going!',
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Pie chart section
                _sectionHeader('Achievement Chart', showPie, () {
                  setState(() => showPie = !showPie);
                }),
                if (showPie) ...[
                  const SizedBox(height: 8),
                  _card(
                    child: SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 48,
                          sectionsSpace: 2,
                          sections: [
                            PieChartSectionData(
                              value: achievement,
                              color: _darkBlue,
                              title: '${achievement.toStringAsFixed(1)}%',
                              radius: 72,
                              titleStyle: const TextStyle(
                                fontSize: _fontRegular,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              value: 100 - achievement,
                              color: Colors.grey.shade300,
                              title: '',
                              radius: 64,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // Actions
                Text(
                  'Actions',
                  style: const TextStyle(
                    fontSize: _fontLarge,
                    color: _darkBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GridView(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: actionCols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _actionTile(
                      icon: Icons.add_circle,
                      label: 'New Invoice',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NewInvoicesScreen()),
                        );
                      },
                    ),
                    _actionTile(
                      icon: Icons.list_alt,
                      label: 'All Invoices',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AllInvoicesScreen()),
                        );
                      },
                    ),
                    _actionTile(
                      icon: Icons.work,
                      label: 'Work Orders',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WorkOrderScreen()),
                        );
                      },
                    ),
                    _actionTile(
                      icon: Icons.bar_chart,
                      label: 'Report',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SalesReportScreen()),
                        );
                      },
                    ),
                    _actionTile(
                      icon: Icons.timeline,
                      label: 'Progress',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrderProgressScreen()),
                        );
                      },
                    ),
                    // Empty slot for symmetry on large screens
                    const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ——————————————————— UI helpers ———————————————————

  Widget _pageHeader(double achievement) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Sales Overview',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _darkBlue,
            ),
          ),
        ),
        _pillButton(
          icon: Icons.filter_alt,
          label: DateFormat.yMMMM().format(selectedMonth),
          onTap: () => _selectMonth(context),
        ),
      ],
    );
  }

  Widget _pillButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: _darkBlue.withOpacity(0.08),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: _darkBlue, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _darkBlue,
                  fontSize: _fontRegular,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniProgress(double achievement) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: achievement / 100,
            minHeight: 8,
            backgroundColor: Colors.grey.shade300,
            color: _darkBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${achievement.toStringAsFixed(0)}%',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: _fontSmall,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String text, bool expanded, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: _fontLarge,
                fontWeight: FontWeight.w800,
                color: _darkBlue,
              ),
            ),
          ),
          Icon(expanded ? Icons.expand_less : Icons.expand_more, color: _darkBlue),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
    String? footer,
    Widget? trailing,
  }) {
    return _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: _fontSmall,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    color: _darkBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    footer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: _fontSmall),
                  ),
                ],
                if (trailing != null) trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _darkBlue.withOpacity(.10),
              child: Icon(icon, color: _darkBlue),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: _fontRegular,
                color: _darkBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(14)}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.withOpacity(.1)),
      ),
      padding: padding,
      child: child,
    );
  }
}
