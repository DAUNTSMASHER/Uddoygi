// lib/features/admin/presentation/widgets/admin_dashboard_summary.dart
//
// One big hero card (~50% screen) containing:
//   • Period filter chips (top row inside card)
//   • Profit hero value + Revenue / Expense / Budget sub-stats
//   • 2×2 insight grid (Top Agent, Top Buyer, Attendance, Top Product)
// All packed into a single gradient card — no separate floating sections.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/admin_allbuyer.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _ink      = Color(0xFF0F172A);
const Color _sub      = Color(0xFF64748B);
const Color _border   = Color(0xFFEAE4F4);
const Color _card     = Color(0xFFFFFFFF);
const Color _purple   = Color(0xFF2A0A4B);
const Color _indigo   = Color(0xFF4F46E5);
const Color _indigoLt = Color(0xFF818CF8);
const Color _violet   = Color(0xFF6D28D9);
const Color _accent   = Color(0xFF7C3AED);

// ── Helpers ───────────────────────────────────────────────────────────────────
String _fmt(num n) {
  if (n == 0) return '৳0';
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer('৳');
  for (int i = 0; i < s.length; i++) {
    final r = s.length - i;
    buf.write(s[i]);
    if (r > 1 && r % 3 == 1) buf.write(',');
  }
  return buf.toString();
}

String _fmtShort(num n) {
  if (n >= 10000000) return '৳${(n / 10000000).toStringAsFixed(1)}Cr';
  if (n >= 100000)   return '৳${(n / 100000).toStringAsFixed(1)}L';
  if (n >= 1000)     return '৳${(n / 1000).toStringAsFixed(1)}K';
  return _fmt(n);
}

String _initials(String s) {
  if (s.isEmpty) return 'U';
  final at   = s.indexOf('@');
  final base = (at > 0 ? s.substring(0, at) : s).trim();
  final parts = base.split(RegExp(r'[._\s-]+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return base[0].toUpperCase();
  final a = parts.first[0].toUpperCase();
  final b = parts.length > 1 ? parts[1][0].toUpperCase() : '';
  return a + b;
}

// ── Public widget ─────────────────────────────────────────────────────────────
class AdminDashboardSummary extends StatefulWidget {
  const AdminDashboardSummary({super.key});
  @override
  State<AdminDashboardSummary> createState() => _AdminDashboardSummaryState();
}

class _AdminDashboardSummaryState extends State<AdminDashboardSummary>
    with SingleTickerProviderStateMixin {
  String _cid     = '';
  bool   _loading = true;
  String _filter  = 'this_month';

  double _sales    = 0;
  double _expenses = 0;
  double _budget   = 0;
  int    _buyers   = 0;

  double get _profit => _sales - _expenses;

  String _topAgentEmail = '';
  double _topAgentSales = 0;
  String _topBuyerKey   = '';
  double _topBuyerSales = 0;
  String _topProduct    = '';
  int    _topProductQty = 0;
  int    _present       = 0;
  int    _absent        = 0;

  final Map<String, String> _avatarCache = {};

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  static const _filters = [
    ('this_month',    'This Month'),
    ('prev_month',    'Prev Month'),
    ('last_3_months', 'Last 3 Mo.'),
    ('this_year',     'This Year'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    LocalStorageService.getSavedCompanyId().then((id) {
      if (!mounted) return;
      setState(() => _cid = id ?? '');
      _fetch();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  ({DateTime start, DateTime end}) _range() {
    final now = DateTime.now();
    switch (_filter) {
      case 'prev_month':
        final p = DateTime(now.year, now.month - 1, 1);
        return (start: p, end: DateTime(p.year, p.month + 1, 0));
      case 'last_3_months':
        return (start: DateTime(now.year, now.month - 2, 1),
                end:   DateTime(now.year, now.month + 1, 0));
      case 'this_year':
        return (start: DateTime(now.year, 1, 1),
                end:   DateTime(now.year, 12, 31));
      default:
        return (start: DateTime(now.year, now.month, 1),
                end:   DateTime(now.year, now.month + 1, 0));
    }
  }

  Future<void> _fetch() async {
    if (_cid.isEmpty) return;
    setState(() => _loading = true);
    try {
      final r = _range();
      Timestamp ts(DateTime d) => Timestamp.fromDate(d);

      final invSnap = await DB.colSync(_cid, C.invoices)
          .where('timestamp', isGreaterThanOrEqualTo: ts(r.start))
          .where('timestamp', isLessThanOrEqualTo:    ts(r.end))
          .get();

      double sales = 0;
      final Map<String, double> byAgent = {};
      final Map<String, double> byBuyer = {};
      final Map<String, int>    prodQty = {};

      for (final doc in invSnap.docs) {
        final d   = doc.data();
        final ag  = (d['agentEmail']    ?? 'Unknown').toString();
        final bk  = (d['customerEmail'] ?? d['customerName'] ?? 'Unknown').toString();
        final val = (d['grandTotal'] is num) ? (d['grandTotal'] as num).toDouble() : 0.0;
        sales += val;
        byAgent[ag] = (byAgent[ag] ?? 0) + val;
        byBuyer[bk] = (byBuyer[bk] ?? 0) + val;
        final items = d['items'];
        if (items is List) {
          for (final it in items) {
            if (it is Map) {
              final nm = (it['name'] ?? it['productName'] ?? '').toString();
              final q  = ((it['qty'] ?? it['quantity'] ?? 0) as num).toInt();
              if (nm.isNotEmpty && q > 0) prodQty[nm] = (prodQty[nm] ?? 0) + q;
            }
          }
        }
      }

      final buySnap = await DB.colSync(_cid, C.customers).get();
      final budSnap = await DB.colSync(_cid, C.budget).limit(1).get();
      final expSnap = await DB.colSync(_cid, C.expenses).get();
      double exp = 0;
      for (final d in expSnap.docs) {
        final v = d.data()['amount'];
        if (v is num) exp += v.toDouble();
      }

      String tProd = ''; int tQty = 0;
      if (prodQty.isNotEmpty) {
        final sorted = prodQty.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        tProd = sorted.first.key;
        tQty  = sorted.first.value;
      }

      String? tAgentKey, tBuyerKey;
      double  tAgentVal = 0, tBuyerVal = 0;
      if (byAgent.isNotEmpty) {
        final s = byAgent.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        tAgentKey = s.first.key; tAgentVal = s.first.value;
      }
      if (byBuyer.isNotEmpty) {
        final s = byBuyer.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        tBuyerKey = s.first.key; tBuyerVal = s.first.value;
      }

      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final todayEnd   = todayStart.add(const Duration(days: 1));
      int present = 0, absent = 0;
      try {
        final attSnap = await DB.colSync(_cid, C.attendance)
            .where('date', isGreaterThanOrEqualTo: ts(todayStart))
            .where('date', isLessThan:             ts(todayEnd))
            .get();
        for (final d in attSnap.docs) {
          final s = (d.data()['status'] ?? '').toString().toLowerCase();
          if (s == 'present') {
            present++;
          } else if (s == 'absent') {
            absent++;
          }
        }
      } catch (_) {}

      if (tAgentKey != null && !_avatarCache.containsKey(tAgentKey)) {
        final q = await DB.colSync(_cid, C.users)
            .where('officeEmail', isEqualTo: tAgentKey).limit(1).get();
        final url = q.docs.isNotEmpty
            ? (q.docs.first.data()['profilePhotoUrl'] ?? '').toString()
            : '';
        if (url.isNotEmpty) _avatarCache[tAgentKey] = url;
      }

      if (mounted) {
      setState(() {
          _sales         = sales;
          _expenses      = exp;
          _budget        = budSnap.docs.isNotEmpty
              ? ((budSnap.docs.first.data()['amount'] ?? 0) as num).toDouble()
              : 0;
          _buyers        = buySnap.docs.length;
          _topAgentEmail = tAgentKey ?? '';
          _topAgentSales = tAgentVal;
          _topBuyerKey   = tBuyerKey ?? '';
          _topBuyerSales = tBuyerVal;
          _topProduct    = tProd;
          _topProductQty = tQty;
          _present       = present;
          _absent        = absent;
        });
      }
    } catch (_) {
      // silently ignore — UI shows placeholders
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final cardH   = (screenH * 0.50).clamp(320.0, 480.0);

    final pct      = _budget > 0 ? (_sales / _budget * 100).clamp(0, 100).toDouble() : 0.0;
    final attTotal = _present + _absent;
    final attPct   = attTotal > 0 ? (_present / attTotal * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, _) {
          return Container(
            height: cardH,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E0040), Color(0xFF2A0A4B), Color(0xFF4C1D95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _purple.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative rings
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(
                      painter: _RingPainter(
                        scale: _pulseAnim.value,
                        progress: _budget > 0 ? (pct / 100).clamp(0, 1) : 0,
                      ),
                    ),
                  ),
                ),

                // Loading bar
                if (_loading)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: const LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: _indigoLt,
                      ),
                    ),
                  ),

                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
        children: [

                      // ── Period filter chips ──────────────────────────────
                      SizedBox(
                        height: 26,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _filters.map((f) {
                            final active = _filter == f.$1;
                            return GestureDetector(
                              onTap: () {
                                if (_filter == f.$1) return;
                                setState(() => _filter = f.$1);
                                _fetch();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: active
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: active
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.12),
                                    width: 1,
                                  ),
                                ),
                                child: Text(f.$2,
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: active ? Colors.white : Colors.white54)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Profit hero + sub-stats row ──────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Profit
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 18, height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Icon(
                                      _profit >= 0
                                          ? Icons.trending_up_rounded
                                          : Icons.trending_down_rounded,
                                      color: Colors.white, size: 11),
                                  ),
                                  const SizedBox(width: 5),
                                  Text('Profit',
                                      style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white54)),
                                ]),
                                const SizedBox(height: 3),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _loading ? '…' : _fmt(_profit.abs()),
                                    style: GoogleFonts.spaceGrotesk(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _loading
                                      ? ''
                                      : _profit < 0 ? 'Net loss' : 'Net profit',
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: _profit < 0
                                          ? const Color(0xFFFCA5A5)
                                          : Colors.white38),
                                ),
                              ],
                            ),
                          ),

                          // Divider
                          Container(
                            width: 1, height: 52,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            color: Colors.white12,
                          ),

                          // Sub-stats
                          Expanded(
                            flex: 4,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
            children: [
                                _SubStat(
                                  icon: Icons.receipt_long_rounded,
                                  label: 'Expense',
                                  value: _loading ? '…' : _fmtShort(_expenses),
                                  accent: _accent,
                                ),
                                const SizedBox(height: 6),
                                _SubStat(
                                  icon: Icons.trending_up_rounded,
                                  label: 'Revenue',
                                  value: _loading ? '…' : _fmtShort(_sales),
                                  accent: _indigoLt,
                                ),
                                const SizedBox(height: 6),
                                _SubStat(
                                  icon: Icons.donut_small_rounded,
                                  label: 'Budget',
                                  value: _loading
                                      ? '…'
                                      : (_budget > 0
                                          ? '${pct.toStringAsFixed(0)}%'
                                          : 'Not set'),
                                  accent: _violet,
                                ),
                              ],
                            ),
              ),
            ],
          ),

                      const SizedBox(height: 12),

                      // ── Divider ──────────────────────────────────────────
                      Container(height: 1, color: Colors.white10),

                      const SizedBox(height: 10),

                      // ── 2×2 Insight grid ─────────────────────────────────
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: false,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.6,
                          children: [
                            _InsightCell(
                              icon: Icons.person_rounded,
                              label: 'Top Agent',
                              value: _topAgentEmail.isEmpty
                                  ? '—'
                                  : _topAgentEmail.split('@').first,
                              sub: _topAgentEmail.isEmpty
                                  ? 'No data'
                                  : _fmtShort(_topAgentSales),
                              accentColor: _indigoLt,
                              avatarUrl: _avatarCache[_topAgentEmail],
                              initials: _initials(
                                  _topAgentEmail.isEmpty ? 'A' : _topAgentEmail),
                            ),
                            _InsightCell(
                              icon: Icons.business_rounded,
                              label: 'Top Buyer',
                              value: _topBuyerKey.isEmpty
                                  ? '—'
                                  : (_topBuyerKey.contains('@')
                                      ? _topBuyerKey.split('@').first
                                      : _topBuyerKey),
                              sub: _topBuyerKey.isEmpty
                                  ? 'No data'
                                  : _fmtShort(_topBuyerSales),
                              accentColor: _violet,
                              initials: _initials(
                                  _topBuyerKey.isEmpty ? 'B' : _topBuyerKey),
                              onTap: _topBuyerKey.isEmpty
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const AdminAllBuyersPage())),
                            ),
                            _InsightCell(
                              icon: Icons.how_to_reg_rounded,
                              label: 'Attendance',
                              value: _loading ? '—' : '$_present / $attTotal',
                              sub: attTotal == 0
                                  ? 'No records'
                                  : '$attPct% present',
                              accentColor: _accent,
                              initials: '✓',
                            ),
                            _InsightCell(
                              icon: Icons.inventory_2_rounded,
                              label: 'Top Product',
                              value: _loading
                                  ? '—'
                                  : (_topProduct.isEmpty ? 'None' : _topProduct),
                              sub: _topProductQty > 0
                                  ? '$_topProductQty units'
                                  : 'No sales',
                              accentColor: _indigoLt,
                              initials: '★',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Sub-stat row inside hero ──────────────────────────────────────────────────
class _SubStat extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    accent;

  const _SubStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 18, height: 18,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: accent, size: 10),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 8,
                    color: Colors.white38,
                    fontWeight: FontWeight.w500)),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1)),
          ],
        ),
      ),
    ]);
  }
}

// ── Insight cell (inside hero card, semi-transparent) ─────────────────────────
class _InsightCell extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final String        value;
  final String        sub;
  final Color         accentColor;
  final String        initials;
  final String?       avatarUrl;
  final VoidCallback? onTap;

  const _InsightCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.accentColor,
    required this.initials,
    this.avatarUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // Icon / avatar
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(initials,
                              style: GoogleFonts.inter(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10)),
                  ),
                ),
              )
                  : Icon(icon, color: accentColor, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 1),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1)),
                  const SizedBox(height: 1),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 8,
                          color: accentColor,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 12, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ── Ring painter (decorative radial arcs on hero) ─────────────────────────────
class _RingPainter extends CustomPainter {
  final double scale;
  final double progress;

  const _RingPainter({required this.scale, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  * 0.5;
    final cy = size.height * 0.5;

    final outerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40;
    canvas.drawCircle(
        Offset(cx * 1.6, cy * 0.3), size.width * 0.55 * scale, outerPaint);

    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;
    canvas.drawCircle(
        Offset(cx * 1.7, cy * 0.2), size.width * 0.32 * scale, innerPaint);

    if (progress > 0) {
      final trackPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      final arcRect = Rect.fromCircle(
          center: Offset(size.width - 28, size.height - 28), radius: 20);
      canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, trackPaint);

      final progressPaint = Paint()
        ..color = _accent.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          arcRect, -math.pi / 2, math.pi * 2 * progress, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.scale != scale || old.progress != progress;
}
