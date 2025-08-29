import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/admin_allbuyer.dart';

class AdminDashboardSummary extends StatefulWidget {
  const AdminDashboardSummary({super.key});

  @override
  State<AdminDashboardSummary> createState() => _AdminDashboardSummaryState();
}

/* ─────────────────────────── Helpers ─────────────────────────── */

String _money(num n) {
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final r = s.length - i;
    buf.write(s[i]);
    if (r > 1 && r % 3 == 1) buf.write(',');
  }
  return '৳${buf.toString()}';
}

String _initialsFromKey(String s) {
  if (s.isEmpty) return 'U';
  final at = s.indexOf('@');
  final base = (at > 0 ? s.substring(0, at) : s).trim();
  final parts = base.split(RegExp(r'[._\s-]+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return base[0].toUpperCase();
  final a = parts.first[0].toUpperCase();
  final b = parts.length > 1 ? parts[1][0].toUpperCase() : '';
  return a + b;
}

/* ────────────────────────── Small UI parts ────────────────────────── */

class _AvatarBubble extends StatelessWidget {
  final String keyText;
  final String? imageUrl;
  final double size;
  final Color fallbackColor;
  const _AvatarBubble({
    required this.keyText,
    this.imageUrl,
    this.size = 56,
    this.fallbackColor = const Color(0xFF0D47A1),
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromKey(keyText);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size),
      child: Container(
        height: size,
        width: size,
        color: fallbackColor.withOpacity(0.12),
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _InitAvatar(initials: initials),
        )
            : _InitAvatar(initials: initials),
      ),
    );
  }
}

class _InitAvatar extends StatelessWidget {
  final String initials;
  const _InitAvatar({required this.initials});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF263238),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
      ),
    );
  }
}

/* Unified card (photo/icon header → compact content). */
class _ProfileCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;
  final String buttonText;
  final VoidCallback? onPressed;
  final String? imageUrl;               // optional header photo
  final String initialsForFallback;     // for avatar fallback
  final IconData? fallbackIcon;         // large icon if no image
  final bool verified;

  const _ProfileCard({
    required this.title,
    required this.subtitle,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Label,
    required this.stat2Value,
    required this.buttonText,
    required this.initialsForFallback,
    this.imageUrl,
    this.fallbackIcon,
    this.onPressed,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (image or icon) — height trimmed to avoid overflow on small screens
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SizedBox(
              height: 150, // ↓ from 160
              width: double.infinity,
              child: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _HeaderFallback(initials: initialsForFallback, icon: fallbackIcon),
              )
                  : _HeaderFallback(initials: initialsForFallback, icon: fallbackIcon),
            ),
          ),

          // Content (extra-tight; no wasted space)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10), // tighter
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (verified)
                      Container(
                        height: 18,
                        width: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2ECC71),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 12, color: Colors.white),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _miniStat(icon: Icons.local_fire_department, label: stat1Label, value: stat1Value),
                    const SizedBox(width: 14),
                    _miniStat(icon: Icons.receipt_long, label: stat2Label, value: stat2Value),
                    const Spacer(),
                    if (buttonText.isNotEmpty)
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // tighter
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: onPressed,
                        child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _miniStat({required IconData icon, required String label, required String value}) {
  return Row(
    children: [
      Icon(icon, size: 16, color: Colors.white70),
      const SizedBox(width: 6),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ],
  );
}

class _HeaderFallback extends StatelessWidget {
  final String? initials;
  final IconData? icon;
  const _HeaderFallback({this.initials, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF263238),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: Colors.white, size: 56)
          : _AvatarBubble(keyText: (initials ?? 'U'), size: 64),
    );
  }
}

/* Perfect pie that auto-fits available space (height-bounded). */
class _PieAutoFitCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double percent; // 0..100
  const _PieAutoFitCard({required this.title, required this.subtitle, required this.percent});

  @override
  Widget build(BuildContext context) {
    final pct = percent.clamp(0.0, 100.0);
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          // Cap pie size to a fraction of screen height to avoid overflow inside carousel.
          final maxByHeight = screenH * 0.28;
          final double size = math.max(120, math.min(w, maxByHeight));
          final rMain = size * 0.45;
          final rRem = rMain * 0.85;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: size,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 0,
                    sectionsSpace: 2,
                    startDegreeOffset: 270,
                    pieTouchData: PieTouchData(enabled: false),
                    sections: [
                      PieChartSectionData(
                        value: pct,
                        color: Colors.white,
                        title: '${pct.toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
                        radius: rMain,
                        showTitle: true,
                        titlePositionPercentageOffset: 0.52,
                      ),
                      PieChartSectionData(value: 100.0 - pct, color: Colors.white24, title: '', radius: rRem),
                    ],
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 600),
                  swapAnimationCurve: Curves.easeInOut,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ────────────────────────────── State ────────────────────────────── */

class _AdminDashboardSummaryState extends State<AdminDashboardSummary> {
  bool isLoading = true;

  // Filters
  String filterType = 'this_month'; // this_month, prev_month, last_3_months, this_year

  // KPIs
  double totalSales = 0;
  int totalBuyers = 0;
  double budget = 0;
  double totalExpenses = 0;

  // Leaders
  Map<String, double> agentSales = {};
  Map<String, int> agentOrders = {};
  Map<String, double> buyerSales = {};
  Map<String, int> buyerOrders = {};

  // Most sold product
  String topProduct = '';
  int topProductQty = 0;

  // Attendance today
  int presentCount = 0;
  int absentCount = 0;

  // Avatar cache
  final Map<String, String> _avatarUrlCache = {};

  @override
  void initState() {
    super.initState();
    fetchReportData();
  }

  ({DateTime start, DateTime end, String label}) _rangeForFilter() {
    final now = DateTime.now();
    if (filterType == 'prev_month') {
      final prev = DateTime(now.year, now.month - 1, 1);
      return (start: DateTime(prev.year, prev.month, 1), end: DateTime(prev.year, prev.month + 1, 0), label: 'Previous Month');
    }
    if (filterType == 'last_3_months') {
      return (start: DateTime(now.year, now.month - 2, 1), end: DateTime(now.year, now.month + 1, 0), label: 'Last 3 Months');
    }
    if (filterType == 'this_year') {
      return (start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31), label: 'This Year');
    }
    return (start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0), label: 'This Month');
  }

  Future<void> fetchReportData() async {
    setState(() => isLoading = true);
    try {
      final fs = FirebaseFirestore.instance;
      final r = _rangeForFilter();

      final invoicesSnap = await fs
          .collection('invoices')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.end))
          .get();

      final buyersSnap = await fs.collection('customers').get();
      final budgetSnap = await fs.collection('budget').limit(1).get();
      final expensesSnap = await fs.collection('expenses').get();

      double sales = 0;
      final Map<String, double> byAgent = {};
      final Map<String, int> ordersByAgent = {};
      final Map<String, double> byBuyer = {};
      final Map<String, int> ordersByBuyer = {};
      final Map<String, int> productQty = {};

      for (var doc in invoicesSnap.docs) {
        final d = doc.data();
        final agentEmail = (d['agentEmail'] ?? 'Unknown').toString();
        final buyerKey = (d['customerEmail'] ?? d['customerName'] ?? 'Unknown').toString();
        final val = d['grandTotal'];
        final sale = (val is num) ? val.toDouble() : 0.0;

        sales += sale;
        byAgent[agentEmail] = (byAgent[agentEmail] ?? 0) + sale;
        ordersByAgent[agentEmail] = (ordersByAgent[agentEmail] ?? 0) + 1;

        byBuyer[buyerKey] = (byBuyer[buyerKey] ?? 0) + sale;
        ordersByBuyer[buyerKey] = (ordersByBuyer[buyerKey] ?? 0) + 1;

        final items = d['items'];
        if (items is List) {
          for (final it in items) {
            if (it is Map) {
              final name = (it['name'] ?? it['productName'] ?? 'Unknown').toString();
              final qraw = it['qty'] ?? it['quantity'] ?? 0;
              final q = (qraw is num) ? qraw.toInt() : 0;
              if (name.isNotEmpty && q > 0) {
                productQty[name] = (productQty[name] ?? 0) + q;
              }
            }
          }
        }
      }

      double expense = 0;
      for (var doc in expensesSnap.docs) {
        final val = doc.data()['amount'];
        if (val is num) expense += val.toDouble();
      }

      String pName = '';
      int pQty = 0;
      if (productQty.isNotEmpty) {
        final list = productQty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        pName = list.first.key;
        pQty = list.first.value;
      }

      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      int present = 0, absent = 0;
      try {
        final attSnap = await fs
            .collection('attendance')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
            .get();
        for (var d in attSnap.docs) {
          final s = (d.data()['status'] ?? '').toString().toLowerCase();
          if (s == 'present') present++;
          else if (s == 'absent') absent++;
        }
      } catch (_) {}

      setState(() {
        totalSales = sales;
        totalBuyers = buyersSnap.docs.length;
        budget = budgetSnap.docs.isNotEmpty ? ((budgetSnap.docs.first.data()['amount'] ?? 0) as num).toDouble() : 0.0;
        totalExpenses = expense;

        agentSales = byAgent;
        agentOrders = ordersByAgent;
        buyerSales = byBuyer;
        buyerOrders = ordersByBuyer;

        topProduct = pName;
        topProductQty = pQty;

        presentCount = present;
        absentCount = absent;
      });

      await _prefetchTopAvatars(fs);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _prefetchTopAvatars(FirebaseFirestore fs) async {
    String? topAgent = _topKey(agentSales);
    String? topBuyer = _topKey(buyerSales);

    if (topAgent != null && !_avatarUrlCache.containsKey(topAgent)) {
      final q = await fs.collection('users').where('officeEmail', isEqualTo: topAgent).limit(1).get();
      if (q.docs.isNotEmpty) {
        final m = q.docs.first.data();
        final url = (m['profilePhotoUrl'] ?? m['photoUrl'] ?? m['avatarUrl'] ?? '').toString();
        if (url.isNotEmpty) _avatarUrlCache[topAgent] = url;
      } else {
        final q2 = await fs.collection('users').where('email', isEqualTo: topAgent).limit(1).get();
        if (q2.docs.isNotEmpty) {
          final m = q2.docs.first.data();
          final url = (m['profilePhotoUrl'] ?? m['photoUrl'] ?? m['avatarUrl'] ?? '').toString();
          if (url.isNotEmpty) _avatarUrlCache[topAgent] = url;
        }
      }
    }

    if (topBuyer != null && !_avatarUrlCache.containsKey(topBuyer)) {
      final qb = await fs.collection('customers').where('email', isEqualTo: topBuyer).limit(1).get();
      if (qb.docs.isNotEmpty) {
        final m = qb.docs.first.data();
        final url = (m['logoUrl'] ?? m['photoUrl'] ?? m['avatarUrl'] ?? '').toString();
        if (url.isNotEmpty) _avatarUrlCache[topBuyer] = url;
      } else {
        final qb2 = await fs.collection('customers').where('name', isEqualTo: topBuyer).limit(1).get();
        if (qb2.docs.isNotEmpty) {
          final m = qb2.docs.first.data();
          final url = (m['logoUrl'] ?? m['photoUrl'] ?? m['avatarUrl'] ?? '').toString();
          if (url.isNotEmpty) _avatarUrlCache[topBuyer] = url;
        }
      }
    }

    if (mounted) setState(() {});
  }

  String? _topKey(Map<String, double> map) {
    if (map.isEmpty) return null;
    final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.first.key;
  }

  double _topVal(Map<String, double> map) {
    if (map.isEmpty) return 0.0;
    final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.first.value;
  }

  void _openAllBuyers() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAllBuyersPage()));
  }

  String _periodLabel() => _rangeForFilter().label;

  /* ─────────────────────────── Build ─────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final topAgentEmail = _topKey(agentSales) ?? '';
    final topAgentAmount = _topVal(agentSales);
    final topAgentOrderN = agentOrders[topAgentEmail] ?? 0;

    final topBuyerKey = _topKey(buyerSales) ?? '';
    final topBuyerAmount = _topVal(buyerSales);
    final topBuyerOrderN = buyerOrders[topBuyerKey] ?? 0;

    final percent = budget > 0 ? (totalSales / budget) * 100.0 : 0.0;
    final safePercent = percent.clamp(0.0, 100.0).toDouble();

    final cards = <Widget>[
      _ProfileCard(
        title: 'Total Sales',
        subtitle: 'Overall revenue • ${_periodLabel()}',
        stat1Label: 'amount',
        stat1Value: _money(totalSales),
        stat2Label: 'buyers',
        stat2Value: '$totalBuyers',
        buttonText: '',
        initialsForFallback: 'S',
        fallbackIcon: Icons.shopping_bag,
      ),
      _ProfileCard(
        title: 'Expenses',
        subtitle: 'Cost this period • ${_periodLabel()}',
        stat1Label: 'cost',
        stat1Value: _money(totalExpenses),
        stat2Label: 'budget',
        stat2Value: budget > 0 ? _money(budget) : '—',
        buttonText: '',
        initialsForFallback: 'E',
        fallbackIcon: Icons.receipt_long,
      ),
      _ProfileCard(
        title: topAgentEmail.isEmpty ? 'Top Agent' : topAgentEmail.split('@').first,
        subtitle: topAgentEmail.isEmpty ? 'No data in this period' : 'Top performer • ${_periodLabel()}',
        stat1Label: 'sales',
        stat1Value: topAgentEmail.isEmpty ? '—' : _money(topAgentAmount),
        stat2Label: 'orders',
        stat2Value: '$topAgentOrderN',
        buttonText: 'View',
        onPressed: topAgentEmail.isEmpty ? null : () {},
        imageUrl: _avatarUrlCache[topAgentEmail],
        initialsForFallback: _initialsFromKey(topAgentEmail.isEmpty ? 'A' : topAgentEmail),
        fallbackIcon: Icons.person,
        verified: true,
      ),
      _ProfileCard(
        title: topBuyerKey.isEmpty ? 'Top Buyer' : topBuyerKey.split('@').first,
        subtitle: topBuyerKey.isEmpty ? 'No data in this period' : 'Most valuable customer • ${_periodLabel()}',
        stat1Label: 'spent',
        stat1Value: topBuyerKey.isEmpty ? '—' : _money(topBuyerAmount),
        stat2Label: 'orders',
        stat2Value: '$topBuyerOrderN',
        buttonText: 'View',
        onPressed: topBuyerKey.isEmpty ? null : () {},
        imageUrl: _avatarUrlCache[topBuyerKey],
        initialsForFallback: _initialsFromKey(topBuyerKey.isEmpty ? 'B' : topBuyerKey),
        fallbackIcon: Icons.business,
        verified: true,
      ),
      _ProfileCard(
        title: topProduct.isEmpty ? 'Most Sold Product' : topProduct,
        subtitle: 'Highest quantity sold • ${_periodLabel()}',
        stat1Label: 'qty',
        stat1Value: topProductQty > 0 ? '${topProductQty} pcs' : '—',
        stat2Label: ' ',
        stat2Value: ' ',
        buttonText: '',
        initialsForFallback: 'P',
        fallbackIcon: Icons.inventory_2,
      ),
      _ProfileCard(
        title: 'Attendance (Today)',
        subtitle: 'Daily presence snapshot',
        stat1Label: 'present',
        stat1Value: '$presentCount',
        stat2Label: 'absent',
        stat2Value: '$absentCount',
        buttonText: '',
        initialsForFallback: 'T',
        fallbackIcon: Icons.groups_2,
      ),
      _PieAutoFitCard(
        title: 'Budget Achievement',
        subtitle: _periodLabel(),
        percent: safePercent,
      ),
    ];

    // Auto height for carousel: scales with screen, capped to avoid overflow.
    final screenH = MediaQuery.of(context).size.height;
    final carouselHeight = math.min(360.0, screenH * 0.42);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              DropdownButton<String>(
                value: filterType,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                  DropdownMenuItem(value: 'prev_month', child: Text('Previous Month')),
                  DropdownMenuItem(value: 'last_3_months', child: Text('Last 3 Months')),
                  DropdownMenuItem(value: 'this_year', child: Text('This Year')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => filterType = v);
                  fetchReportData();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          SizedBox(
            height: carouselHeight,
            child: CarouselSlider(
              items: cards
                  .map(
                    (w) => Builder(
                  builder: (context) => SizedBox(
                    width: MediaQuery.of(context).size.width * 0.92,
                    child: w,
                  ),
                ),
              )
                  .toList(),
              options: CarouselOptions(
                height: carouselHeight,
                autoPlay: true,
                viewportFraction: 1.0,
                enlargeCenterPage: false, // prevent scale-induced overflow
                autoPlayInterval: const Duration(seconds: 4),
              ),
            ),
          ),

          if (isLoading) const SizedBox(height: 8),
          if (isLoading) const LinearProgressIndicator(minHeight: 3),
        ],
      ),
    );
  }
}
