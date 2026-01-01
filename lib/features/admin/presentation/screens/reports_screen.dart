// lib/features/admin/presentation/screens/reports_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import 'admin_ai_insights.dart';
import 'admin_analytics_kpis.dart';
import 'admin_customers_buyers.dart';
import 'admin_export_logistics.dart';
import 'admin_finance.dart';
import 'admin_hr_payroll.dart';
import 'admin_inventory.dart';
import 'admin_manufacturing.dart';
import 'admin_quick_actions.dart';
import 'admin_risk_compliance.dart';
import 'admin_sales_marketing.dart';
import 'admin_security.dart';
import 'admin_settings_admin.dart';
import 'admin_suppliers.dart';

/// ===============================================
/// SAAS PATH HELPER
/// ===============================================
class SaaSPath {
  final String? orgId;
  const SaaSPath({this.orgId});

  CollectionReference<Map<String, dynamic>> col(String name) {
    final db = FirebaseFirestore.instance;
    if (orgId == null || orgId!.trim().isEmpty) return db.collection(name);
    return db.collection('orgs').doc(orgId).collection(name);
  }
}

/// ===============================================
/// THEME COLORS (Deep Purple Gradient)
/// ===============================================
class AppColors {
  static const p1 = Color(0xFF2E1065);
  static const p2 = Color(0xFF5B21B6);
  static const p3 = Color(0xFF7C3AED);

  static const bg = Color(0xFFF7F7FB);
  static const card = Colors.white;
  static const text = Color(0xFF0F172A);
  static const text2 = Color(0xFF64748B);
  static const border = Color(0xFFE7E9F3);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF06B6D4);
}

/// ===============================================
/// HELPERS
/// ===============================================
double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '').trim()) ?? 0.0;
  return 0.0;
}

/// Use "L" for Lakh (1 Lakh = 100,000)
String _fmtLakh(double amount, {String prefix = '৳'}) {
  final abs = amount.abs();
  if (abs >= 100000) {
    final l = amount / 100000.0;
    final s = (l.abs() >= 100) ? l.toStringAsFixed(0) : l.toStringAsFixed(1);
    return '$prefix $s L';
  }
  final n = NumberFormat.decimalPattern('en_BD').format(amount.round());
  return '$prefix $n';
}

/// Compact axis labels: ৳ 2.5 L, ৳ 80k, ৳ 900
String _fmtLakhShort(double amount, {String prefix = '৳'}) {
  final abs = amount.abs();
  if (abs >= 100000) {
    final l = amount / 100000.0;
    final s = (l.abs() >= 100) ? l.toStringAsFixed(0) : l.toStringAsFixed(1);
    return '$prefix $s L';
  }
  if (abs >= 1000) {
    final k = amount / 1000.0;
    final s = (k.abs() >= 100) ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
    return '$prefix $s k';
  }
  return '$prefix ${amount.toStringAsFixed(0)}';
}

String _fmtInt(int n) => NumberFormat.decimalPattern('en_BD').format(n);

DateTimeRange _monthRange(DateTime anchor) {
  final start = DateTime(anchor.year, anchor.month, 1);
  final end = DateTime(anchor.year, anchor.month + 1, 1);
  return DateTimeRange(start: start, end: end);
}

String _fmtRange(DateTimeRange r) {
  final f = DateFormat('dd MMM');
  final y = DateFormat('yyyy');
  return '${f.format(r.start)} - ${f.format(r.end.subtract(const Duration(days: 1)))} ${y.format(r.start)}';
}

DateTime? _extractAnyDate(Map<String, dynamic> m) {
  final candidates = [
    'date',
    'createdAt',
    'created_at',
    'invoiceDate',
    'invoice_date',
    'timestamp',
    'time',
  ];

  for (final k in candidates) {
    final v = m[k];
    if (v == null) continue;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) {
      final s = v.trim();
      final d1 = DateTime.tryParse(s);
      if (d1 != null) return d1;
      for (final p in ['yyyy-MM-dd', 'dd/MM/yyyy', 'MM/dd/yyyy']) {
        try {
          return DateFormat(p).parseStrict(s);
        } catch (_) {}
      }
    }
  }
  return null;
}

String _agentKey(Map<String, dynamic> m) {
  final email = (m['agentEmail'] ?? m['createdBy'] ?? m['userEmail'] ?? m['salesEmail'] ?? '')
      .toString()
      .trim();
  final name =
  (m['agentName'] ?? m['salesPerson'] ?? m['createdByName'] ?? m['name'] ?? '').toString().trim();
  if (email.isNotEmpty) return email;
  if (name.isNotEmpty) return name;
  return 'Unknown';
}

String _agentName(Map<String, dynamic> m, String fallbackKey) {
  final name = (m['agentName'] ?? m['salesPerson'] ?? m['createdByName'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  return fallbackKey;
}

class TrendPoint {
  final String label;
  final double sales;
  final double profit;
  TrendPoint({required this.label, required this.sales, required this.profit});
}

class TopSeller {
  final String key;
  final String name;
  final double sales;
  final int invoices;
  TopSeller({required this.key, required this.name, required this.sales, required this.invoices});
}

class OwnerDashboardData {
  final double sales;
  final double profit; // Profit = sales - expenses
  final double expenses;
  final double moneyIn;

  final int orders;
  final int shipments;
  final int workOrders;

  final int buyers;
  final int suppliers;
  final int workers;

  /// Last 6 months (including current month)
  final List<TrendPoint> trend;

  final List<TopSeller> topSellers;

  OwnerDashboardData({
    required this.sales,
    required this.profit,
    required this.expenses,
    required this.moneyIn,
    required this.orders,
    required this.shipments,
    required this.workOrders,
    required this.buyers,
    required this.suppliers,
    required this.workers,
    required this.trend,
    required this.topSellers,
  });
}

/// ===============================================
/// REPORTS SCREEN
/// ===============================================
class ReportsScreen extends StatefulWidget {
  final String? orgId;
  const ReportsScreen({super.key, this.orgId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _GraphType { line, bar }
enum _RangePreset { thisMonth, lastMonth, last3Months, custom }
enum _GraphMetric { sales, profit }

class _ReportsScreenState extends State<ReportsScreen> {
  late final SaaSPath path;

  _RangePreset _preset = _RangePreset.thisMonth;
  _GraphType _graphType = _GraphType.line;

  late DateTimeRange _range;
  DateTimeRange? _custom;

  @override
  void initState() {
    super.initState();
    path = SaaSPath(orgId: widget.orgId);
    _range = _monthRange(DateTime.now());
  }

  DateTimeRange _computeRange() {
    final now = DateTime.now();
    if (_preset == _RangePreset.thisMonth) return _monthRange(now);
    if (_preset == _RangePreset.lastMonth) return _monthRange(DateTime(now.year, now.month - 1, 1));
    if (_preset == _RangePreset.last3Months) {
      final start = DateTime(now.year, now.month - 2, 1);
      final end = DateTime(now.year, now.month + 1, 1);
      return DateTimeRange(start: start, end: end);
    }
    return _custom ?? _monthRange(now);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom ?? _range,
    );
    if (picked == null) return;
    setState(() {
      _custom = picked;
      _preset = _RangePreset.custom;
      _range = _computeRange();
    });
  }

  void _applyPreset(_RangePreset p) {
    setState(() {
      _preset = p;
      _range = _computeRange();
    });
  }

  /// Profit logic: Profit = Sales - Expenses
  Stream<OwnerDashboardData> _streamData(DateTimeRange range) {
    final invoicesQ = path.col('invoices').orderBy('createdAt', descending: true).limit(1200);
    final expensesQ = path.col('expenses').orderBy('createdAt', descending: true).limit(1200);

    final usersQ = path.col('users').limit(3000);
    final workOrdersQ = path.col('work_orders').orderBy('createdAt', descending: true).limit(1200);
    final shipmentsQ = path.col('shipments').orderBy('createdAt', descending: true).limit(1200);

    return CombineLatestStream.combine5<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        OwnerDashboardData>(
      invoicesQ.snapshots(),
      expensesQ.snapshots(),
      usersQ.snapshots(),
      workOrdersQ.snapshots(),
      shipmentsQ.snapshots(),
          (invoicesSnap, expensesSnap, usersSnap, workOrdersSnap, shipmentsSnap) {
        double sales = 0;
        double moneyIn = 0;
        int orders = 0;

        final now = DateTime.now();
        final start6 = DateTime(now.year, now.month - 5, 1);

        final buckets = <String, _Bucket>{};

        // top performers (highest sales)
        final sellerSales = <String, double>{};
        final sellerInvoices = <String, int>{};
        final sellerName = <String, String>{};

        // INVOICES
        for (final d in invoicesSnap.docs) {
          final m = d.data();
          final dt = _extractAnyDate(m);
          if (dt == null) continue;
          if (dt.isBefore(range.start) || !dt.isBefore(range.end)) continue;

          orders++;

          final total = _asDouble(m['grandTotal'] ?? m['total'] ?? m['amount'] ?? 0);
          sales += total;

          final received =
          _asDouble(m['received'] ?? m['paidAmount'] ?? m['paid'] ?? m['paymentReceived'] ?? 0);
          moneyIn += received;

          final key = _agentKey(m);
          sellerSales[key] = (sellerSales[key] ?? 0) + total;
          sellerInvoices[key] = (sellerInvoices[key] ?? 0) + 1;
          sellerName[key] = _agentName(m, key);

          if (!dt.isBefore(start6)) {
            final k = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            buckets.putIfAbsent(k, () => _Bucket());
            buckets[k]!.sales += total;
          }
        }

        // EXPENSES
        double expenses = 0;
        for (final d in expensesSnap.docs) {
          final m = d.data();
          final dt = _extractAnyDate(m);
          if (dt == null) continue;

          final amt = _asDouble(m['amount'] ?? m['total'] ?? m['expense'] ?? 0);

          if (!dt.isBefore(range.start) && dt.isBefore(range.end)) {
            expenses += amt;
          }

          if (!dt.isBefore(start6)) {
            final k = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            buckets.putIfAbsent(k, () => _Bucket());
            buckets[k]!.expenses += amt;
          }
        }

        final profit = sales - expenses;

        // USERS
        int buyers = 0, suppliers = 0, workers = 0;
        for (final d in usersSnap.docs) {
          final m = d.data();
          final role = (m['role'] ?? m['type'] ?? '').toString().toLowerCase();
          if (role.contains('buyer') || role.contains('customer')) buyers++;
          if (role.contains('supplier') || role.contains('vendor')) suppliers++;
          if (role.contains('worker') || role.contains('factory') || role.contains('staff')) workers++;
        }

        // WORK ORDERS
        int workOrders = 0;
        for (final d in workOrdersSnap.docs) {
          final m = d.data();
          final dt = _extractAnyDate(m);
          if (dt == null) continue;
          if (dt.isBefore(range.start) || !dt.isBefore(range.end)) continue;
          workOrders++;
        }

        // SHIPMENTS
        int shipments = 0;
        for (final d in shipmentsSnap.docs) {
          final m = d.data();
          final dt = _extractAnyDate(m);
          if (dt == null) continue;
          if (dt.isBefore(range.start) || !dt.isBefore(range.end)) continue;
          shipments++;
        }

        // Last 6 months trend
        final points = <TrendPoint>[];
        var cursor = start6;
        for (int i = 0; i < 6; i++) {
          final key = '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}';
          final b = buckets[key] ?? _Bucket();
          points.add(
            TrendPoint(
              label: DateFormat('MMM').format(cursor),
              sales: b.sales,
              profit: b.profit,
            ),
          );
          cursor = DateTime(cursor.year, cursor.month + 1, 1);
        }

        // Top sellers
        final top = sellerSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final topSellers = top.take(5).map((e) {
          final key = e.key;
          return TopSeller(
            key: key,
            name: sellerName[key] ?? key,
            sales: e.value,
            invoices: sellerInvoices[key] ?? 0,
          );
        }).toList();

        return OwnerDashboardData(
          sales: sales,
          profit: profit,
          expenses: expenses,
          moneyIn: moneyIn,
          orders: orders,
          shipments: shipments,
          workOrders: workOrders,
          buyers: buyers,
          suppliers: suppliers,
          workers: workers,
          trend: points,
          topSellers: topSellers,
        );
      },
    );
  }

  void _openHead(String head) {
    final range = _range;
    late final Widget page;

    switch (head) {
      case 'FINANCE':
        page = AdminFinancePage(orgId: widget.orgId, range: range);
        break;
      case 'MANUFACTURING':
        page = AdminManufacturingPage(orgId: widget.orgId, range: range);
        break;
      case 'INVENTORY':
        page = AdminInventoryPage(orgId: widget.orgId, range: range);
        break;
      case 'EXPORT & LOGISTICS':
        page = AdminExportLogisticsPage(orgId: widget.orgId, range: range);
        break;
      case 'SALES & MARKETING':
        page = AdminSalesMarketingPage(orgId: widget.orgId, range: range);
        break;
      case 'HR & PAYROLL':
        page = AdminHrPayrollPage(orgId: widget.orgId, range: range);
        break;
      case 'CUSTOMERS & BUYERS':
        page = AdminCustomersBuyersPage(orgId: widget.orgId, range: range);
        break;
      case 'SUPPLIERS':
        page = AdminSuppliersPage(orgId: widget.orgId, range: range);
        break;
      case 'RISK & COMPLIANCE':
        page = AdminRiskCompliancePage(orgId: widget.orgId, range: range);
        break;
      case 'ANALYTICS & KPIs':
        page = AdminAnalyticsKpisPage(orgId: widget.orgId, range: range);
        break;
      case 'AI INSIGHTS':
        page = AdminAiInsightsPage(orgId: widget.orgId, range: range);
        break;
      case 'SETTINGS & ADMIN':
        page = AdminSettingsAdminPage(orgId: widget.orgId, range: range);
        break;
      case 'SECURITY':
        page = AdminSecurityPage(orgId: widget.orgId, range: range);
        break;
      case 'QUICK ACTIONS':
        page = AdminQuickActionsPage(orgId: widget.orgId, range: range);
        break;
      default:
        page = AdminAnalyticsKpisPage(orgId: widget.orgId, range: range);
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  static const _heads = [
    'FINANCE',
    'MANUFACTURING',
    'INVENTORY',
    'EXPORT & LOGISTICS',
    'SALES & MARKETING',
    'HR & PAYROLL',
    'CUSTOMERS & BUYERS',
    'SUPPLIERS',
    'RISK & COMPLIANCE',
    'ANALYTICS & KPIs',
    'AI INSIGHTS',
    'SETTINGS & ADMIN',
    'SECURITY',
    'QUICK ACTIONS',
  ];

  @override
  Widget build(BuildContext context) {
    _range = _computeRange();

    final titleStyle = GoogleFonts.manrope(fontWeight: FontWeight.w900);
    final subStyle = GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.text2);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        elevation: 0,
        title: Text('Reports', style: titleStyle.copyWith(color: Colors.white)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.p1, AppColors.p2, AppColors.p3],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Custom range',
            onPressed: _pickCustomRange,
            icon: const Icon(Icons.date_range_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {});
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: StreamBuilder<OwnerDashboardData>(
        stream: _streamData(_range),
        builder: (context, snap) {
          if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
            return _ShimmerLoading();
          }
          if (snap.hasError) {
            return _ErrorState(
              message: 'Failed to load dashboard.\n${snap.error}',
              onRetry: () => setState(() {}),
            );
          }
          if (!snap.hasData) {
            return _ErrorState(
              message: 'No data found for this range.',
              onRetry: () => setState(() {}),
            );
          }

          final data = snap.data!;
          final profit5 = data.trend.length <= 5 ? data.trend : data.trend.sublist(data.trend.length - 5);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // TOP: Filter -> Key numbers -> BIG Graphs (Sales + Profit)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FilterRow(
                        preset: _preset,
                        rangeText: _fmtRange(_range),
                        graphType: _graphType,
                        onPreset: (p) async {
                          if (p == _RangePreset.custom) {
                            await _pickCustomRange();
                            return;
                          }
                          _applyPreset(p);
                        },
                        onToggleGraph: (t) => setState(() => _graphType = t),
                      ),
                      const SizedBox(height: 10),

                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        childAspectRatio: 1.55,
                        children: [
                          _KeyNumberCard(
                            title: 'Revenue (Sales)',
                            value: _fmtLakh(data.sales),
                            icon: Icons.trending_up_rounded,
                            glow: AppColors.info,
                          ).animate().fadeIn(duration: 240.ms).slideY(begin: .08),
                          _KeyNumberCard(
                            title: 'Profit',
                            value: _fmtLakh(data.profit),
                            icon: Icons.auto_graph_rounded,
                            glow: AppColors.success,
                          ).animate().fadeIn(duration: 260.ms).slideY(begin: .08),
                          _KeyNumberCard(
                            title: 'Expense',
                            value: _fmtLakh(data.expenses),
                            icon: Icons.receipt_long_rounded,
                            glow: AppColors.warning,
                          ).animate().fadeIn(duration: 280.ms).slideY(begin: .08),
                          _KeyNumberCard(
                            title: 'Cash In',
                            value: _fmtLakh(data.moneyIn),
                            icon: Icons.account_balance_wallet_rounded,
                            glow: AppColors.p3,
                          ).animate().fadeIn(duration: 300.ms).slideY(begin: .08),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // BIGGER SALES GRAPH
                      SizedBox(
                        height: 260,
                        child: _GraphCard(
                          title: 'Company Sales Trend',
                          subtitle: 'Last 6 months',
                          graphType: _graphType,
                          metric: _GraphMetric.sales,
                          points: data.trend,
                        ).animate().fadeIn(duration: 220.ms),
                      ),

                      const SizedBox(height: 12),

                      // BIGGER PROFIT GRAPH
                      SizedBox(
                        height: 240,
                        child: _GraphCard(
                          title: 'Company Profit Trend',
                          subtitle: 'Last 4 + current',
                          graphType: _graphType,
                          metric: _GraphMetric.profit,
                          points: profit5,
                        ).animate().fadeIn(duration: 240.ms),
                      ),
                    ],
                  ),
                ),
              ),

              // AFTER SCROLL: Modules -> KPIs -> Top Performers
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Modules', style: titleStyle.copyWith(fontSize: 16, color: AppColors.text)),
                      const SizedBox(height: 10),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _heads.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.05,
                        ),
                        itemBuilder: (_, i) => _ModuleTile(
                          title: _heads[i],
                          onTap: () => _openHead(_heads[i]),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Divider(height: 1, thickness: 1, color: AppColors.border),
                      const SizedBox(height: 18),

                      _KpiGridDark(data: data),
                      const SizedBox(height: 22),

                      Text('Top Performers', style: titleStyle.copyWith(fontSize: 16, color: AppColors.text)),
                      const SizedBox(height: 6),
                      Text('Highest sales by owner/agent in this range', style: subStyle),
                      const SizedBox(height: 10),

                      if (data.topSellers.isEmpty)
                        Text('No sellers found in this range.', style: subStyle)
                      else
                        ...data.topSellers.asMap().entries.map((e) {
                          final i = e.key + 1;
                          final s = e.value;
                          return _TopSellerTile(rank: i, seller: s)
                              .animate()
                              .fadeIn(duration: 220.ms)
                              .slideX(begin: .04);
                        }),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ===============================================
/// MINI COMBINE LATEST (no rxdart needed)
/// ===============================================
class CombineLatestStream {
  static Stream<R> combine5<A, B, C, D, E, R>(
      Stream<A> a,
      Stream<B> b,
      Stream<C> c,
      Stream<D> d,
      Stream<E> e,
      R Function(A, B, C, D, E) combiner,
      ) async* {
    A? la;
    B? lb;
    C? lc;
    D? ld;
    E? le;

    final ctrl = StreamController<R>();
    late final StreamSubscription sa;
    late final StreamSubscription sb;
    late final StreamSubscription sc;
    late final StreamSubscription sd;
    late final StreamSubscription se;

    void emit() {
      if (la != null && lb != null && lc != null && ld != null && le != null) {
        ctrl.add(combiner(la as A, lb as B, lc as C, ld as D, le as E));
      }
    }

    sa = a.listen((v) {
      la = v;
      emit();
    }, onError: ctrl.addError);
    sb = b.listen((v) {
      lb = v;
      emit();
    }, onError: ctrl.addError);
    sc = c.listen((v) {
      lc = v;
      emit();
    }, onError: ctrl.addError);
    sd = d.listen((v) {
      ld = v;
      emit();
    }, onError: ctrl.addError);
    se = e.listen((v) {
      le = v;
      emit();
    }, onError: ctrl.addError);

    ctrl.onCancel = () async {
      await sa.cancel();
      await sb.cancel();
      await sc.cancel();
      await sd.cancel();
      await se.cancel();
    };

    yield* ctrl.stream;
  }
}

class _Bucket {
  double sales = 0;
  double expenses = 0;
  double get profit => sales - expenses;
}

/// ===============================================
/// UI WIDGETS
/// ===============================================
class _KpiGridDark extends StatelessWidget {
  final OwnerDashboardData data;
  const _KpiGridDark({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem('Orders', _fmtInt(data.orders), Icons.receipt_long_rounded),
      _KpiItem('Shipments', _fmtInt(data.shipments), Icons.local_shipping_rounded),
      _KpiItem('Work Orders', _fmtInt(data.workOrders), Icons.factory_rounded),
      _KpiItem('Buyers', _fmtInt(data.buyers), Icons.people_alt_rounded),
      _KpiItem('Suppliers', _fmtInt(data.suppliers), Icons.handshake_rounded),
      _KpiItem('Workers', _fmtInt(data.workers), Icons.badge_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.p1, AppColors.p2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KPIs',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.45,
            ),
            itemBuilder: (_, i) {
              final it = items[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(.18)),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(.12),
                      ),
                      child: Icon(it.icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withOpacity(.85),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            it.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 220.ms).slideY(begin: .06);
            },
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final _RangePreset preset;
  final String rangeText;
  final _GraphType graphType;
  final ValueChanged<_RangePreset> onPreset;
  final ValueChanged<_GraphType> onToggleGraph;

  const _FilterRow({
    required this.preset,
    required this.rangeText,
    required this.graphType,
    required this.onPreset,
    required this.onToggleGraph,
  });

  @override
  Widget build(BuildContext context) {
    final t = GoogleFonts.manrope(fontWeight: FontWeight.w900);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_RangePreset>(
                value: preset,
                isExpanded: true,
                style: t.copyWith(color: AppColors.text, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: _RangePreset.thisMonth, child: Text('This Month')),
                  DropdownMenuItem(value: _RangePreset.lastMonth, child: Text('Last Month')),
                  DropdownMenuItem(value: _RangePreset.last3Months, child: Text('Last 3 Months')),
                  DropdownMenuItem(value: _RangePreset.custom, child: Text('Custom')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  onPreset(v);
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rangeText,
              textAlign: TextAlign.right,
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.text2, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          _SegButton(
            left: 'Line',
            right: 'Bar',
            value: graphType == _GraphType.line ? 0 : 1,
            onChanged: (i) => onToggleGraph(i == 0 ? _GraphType.line : _GraphType.bar),
          ),
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  final String left;
  final String right;
  final int value;
  final ValueChanged<int> onChanged;

  const _SegButton({
    required this.left,
    required this.right,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        color: AppColors.bg,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(0),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: value == 0 ? AppColors.p2 : Colors.transparent,
                ),
                child: Text(
                  left,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: value == 0 ? Colors.white : AppColors.text2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(1),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: value == 1 ? AppColors.p2 : Colors.transparent,
                ),
                child: Text(
                  right,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: value == 1 ? Colors.white : AppColors.text2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyNumberCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color glow;

  const _KeyNumberCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: glow.withOpacity(.10), blurRadius: 22, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [AppColors.p2, glow.withOpacity(.9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.text2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'Realtime',
            style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text2),
          ),
        ],
      ),
    );
  }
}

class _KpiItem {
  final String title;
  final String value;
  final IconData icon;
  _KpiItem(this.title, this.value, this.icon);
}

/// ===============================================
/// BIGGER + CLEARER GRAPH UI
/// ===============================================
class _GraphCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final _GraphType graphType;
  final _GraphMetric metric;
  final List<TrendPoint> points;

  const _GraphCard({
    required this.title,
    required this.subtitle,
    required this.graphType,
    required this.metric,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = metric == _GraphMetric.profit;

    double last = 0, avg = 0, peak = 0;
    String peakMonth = '';
    String lastMonth = '';

    if (points.isNotEmpty) {
      final vals = points.map((e) => isProfit ? e.profit : e.sales).toList();
      last = vals.last;
      avg = vals.reduce((a, b) => a + b) / vals.length;
      peak = vals.reduce(math.max);

      final peakIndex = vals.indexOf(peak);
      peakMonth = points[peakIndex].label;
      lastMonth = points.last.label;
    }

    final trendUp = last >= avg;
    final trendIcon = trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final trendColor = trendUp ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [AppColors.p2, AppColors.p3],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  isProfit ? Icons.auto_graph_rounded : Icons.show_chart_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Big business summary row (makes chart understandable)
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Last ($lastMonth)', value: _fmtLakh(last))),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: 'Average', value: _fmtLakh(avg))),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: 'Peak ($peakMonth)', value: _fmtLakh(peak))),
              const SizedBox(width: 8),
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: trendColor.withOpacity(.10),
                  border: Border.all(color: trendColor.withOpacity(.25)),
                ),
                child: Icon(trendIcon, color: trendColor),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Legend (simple)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _LegendChip(
                color: AppColors.p2,
                label: isProfit ? 'Profit (Sales − Expense)' : 'Sales (Revenue)',
              ),
              if (isProfit) _LegendChip(color: AppColors.text2, label: '0 = Break-even', outline: true),
            ],
          ),

          const SizedBox(height: 12),

          Expanded(
            child: points.isEmpty
                ? Center(
              child: Text(
                'No trend data',
                style: GoogleFonts.manrope(color: AppColors.text2, fontWeight: FontWeight.w700),
              ),
            )
                : (graphType == _GraphType.line
                ? _LineChart(points: points, metric: metric)
                : _BarChart(points: points, metric: metric)),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.text2),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final bool outline;

  const _LegendChip({
    required this.color,
    required this.label,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: outline ? AppColors.border : color.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(
              color: outline ? AppColors.text2 : color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.text2),
          ),
        ],
      ),
    );
  }
}

double _niceStep(double range) {
  // produces “nice” axis intervals (1,2,5 * 10^n)
  if (range <= 0) return 1;
  final exp = math.pow(10, (math.log(range) / math.ln10).floor()).toDouble();
  final f = range / exp;
  double nf;
  if (f < 1.5) {
    nf = 1;
  } else if (f < 3) {
    nf = 2;
  } else if (f < 7) {
    nf = 5;
  } else {
    nf = 10;
  }
  return nf * exp;
}

class _LineChart extends StatelessWidget {
  final List<TrendPoint> points;
  final _GraphMetric metric;
  const _LineChart({required this.points, required this.metric});

  @override
  Widget build(BuildContext context) {
    final isProfit = metric == _GraphMetric.profit;

    final values = points.map((e) => isProfit ? e.profit : e.sales).toList();
    double minY = values.reduce(math.min);
    double maxY = values.reduce(math.max);

    // Always show 0 line for business meaning
    minY = math.min(minY, 0);
    maxY = math.max(maxY, 0);

    final span = (maxY - minY).abs();
    final pad = span == 0 ? 1000.0 : span * 0.20;
    final finalMin = minY - pad;
    final finalMax = maxY + pad;

    final interval = _niceStep((finalMax - finalMin) / 4);

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            // Keep version-safe: no tooltipRoundedRadius / getTooltipColor
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final i = spot.x.toInt().clamp(0, points.length - 1);
                return LineTooltipItem(
                  '${points[i].label}\n${_fmtLakh(spot.y)}',
                  GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),

        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border.withOpacity(.85), strokeWidth: 1),
        ),

        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: interval,
              getTitlesWidget: (v, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    _fmtLakhShort(v),
                    style: GoogleFonts.manrope(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[i].label,
                    style: GoogleFonts.manrope(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w800),
                  ),
                );
              },
            ),
          ),
        ),

        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: finalMin,
        maxY: finalMax,

        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: AppColors.text2.withOpacity(.35),
              strokeWidth: 1.2,
              dashArray: isProfit ? [6, 6] : null,
            ),
          ],
        ),

        lineBarsData: [
          LineChartBarData(
            spots: [
              for (int i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), isProfit ? points[i].profit : points[i].sales),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            barWidth: 5,
            color: AppColors.p2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 3.6,
                  color: Colors.white,
                  strokeWidth: 2.2,
                  strokeColor: AppColors.p2,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.p2.withOpacity(.22),
                  AppColors.p2.withOpacity(.02),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<TrendPoint> points;
  final _GraphMetric metric;
  const _BarChart({required this.points, required this.metric});

  @override
  Widget build(BuildContext context) {
    final isProfit = metric == _GraphMetric.profit;

    final values = points.map((e) => isProfit ? e.profit : e.sales).toList();
    double minY = values.reduce(math.min);
    double maxY = values.reduce(math.max);

    minY = math.min(minY, 0);
    maxY = math.max(maxY, 0);

    final span = (maxY - minY).abs();
    final pad = span == 0 ? 1000.0 : span * 0.20;
    final finalMin = minY - pad;
    final finalMax = maxY + pad;

    final interval = _niceStep((finalMax - finalMin) / 4);

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            // Keep version-safe: no tooltipBgColor/getTooltipColor/roundedRadius
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final i = group.x.toInt().clamp(0, points.length - 1);
              return BarTooltipItem(
                '${points[i].label}\n${_fmtLakh(rod.toY)}',
                GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
              );
            },
          ),
        ),

        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border.withOpacity(.85), strokeWidth: 1),
        ),

        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: interval,
              getTitlesWidget: (v, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    _fmtLakhShort(v),
                    style: GoogleFonts.manrope(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[i].label,
                    style: GoogleFonts.manrope(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w800),
                  ),
                );
              },
            ),
          ),
        ),

        borderData: FlBorderData(show: false),
        minY: finalMin,
        maxY: finalMax,

        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: AppColors.text2.withOpacity(.35),
              strokeWidth: 1.2,
              dashArray: isProfit ? [6, 6] : null,
            ),
          ],
        ),

        barGroups: [
          for (int i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 6,
              barRods: [
                BarChartRodData(
                  fromY: 0,
                  toY: (isProfit ? points[i].profit : points[i].sales).toDouble(),
                  width: 18,
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [AppColors.p2, AppColors.p3],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _ModuleTile({required this.title, required this.onTap});

  IconData _iconFor(String t) {
    final s = t.toLowerCase();
    if (s.contains('finance')) return Icons.account_balance_rounded;
    if (s.contains('manufacturing')) return Icons.factory_rounded;
    if (s.contains('inventory')) return Icons.inventory_2_rounded;
    if (s.contains('export')) return Icons.local_shipping_rounded;
    if (s.contains('sales')) return Icons.sell_rounded;
    if (s.contains('hr')) return Icons.badge_rounded;
    if (s.contains('customer')) return Icons.people_alt_rounded;
    if (s.contains('supplier')) return Icons.handshake_rounded;
    if (s.contains('risk')) return Icons.shield_rounded;
    if (s.contains('analytics')) return Icons.query_stats_rounded;
    if (s.contains('ai')) return Icons.auto_awesome_rounded;
    if (s.contains('settings')) return Icons.settings_rounded;
    if (s.contains('security')) return Icons.security_rounded;
    return Icons.dashboard_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 28,
              width: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [AppColors.p2, AppColors.p3],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(_iconFor(title), color: Colors.white, size: 18),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopSellerTile extends StatelessWidget {
  final int rank;
  final TopSeller seller;
  const _TopSellerTile({required this.rank, required this.seller});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    final a = parts.first.isNotEmpty ? parts.first[0] : 'U';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final crown = rank == 1 ? Icons.emoji_events_rounded : Icons.military_tech_rounded;
    final badgeColor = rank == 1 ? AppColors.warning : AppColors.p2;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [AppColors.p1, AppColors.p2, AppColors.p3],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(seller.name),
              style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seller.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtInt(seller.invoices)} invoices',
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(crown, size: 16, color: badgeColor),
                    const SizedBox(width: 6),
                    Text(
                      '#$rank',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: badgeColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _fmtLakh(seller.sales),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.danger),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: AppColors.text2, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.p2,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onRetry,
              child: Text('Retry', style: GoogleFonts.manrope(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget box({double h = 60}) => Container(
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: [
            box(h: 52),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: box()), const SizedBox(width: 10), Expanded(child: box())]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: box()), const SizedBox(width: 10), Expanded(child: box())]),
            const SizedBox(height: 12),
            box(h: 260),
            const SizedBox(height: 12),
            box(h: 240),
          ],
        ),
      ),
    );
  }
}
