// lib/features/hr/presentation/screens/ROI.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ===== Colors (green + white, consistent with your HR dashboard) =====
const Color _brandGreen  = Color(0xFF03251D); // deep green
const Color _greenMid    = Color(0xFF10B981); // accent
const Color _surface     = Color(0xFFF1F8F4); // near-white surface
const Color _cardBorder  = Color(0xDB234206); // 10% green border
const Color _shadowLite  = Color(0x14887272);

class ROIPage extends StatefulWidget {
  const ROIPage({Key? key}) : super(key: key);

  @override
  State<ROIPage> createState() => _ROIPageState();
}

class _ROIPageState extends State<ROIPage> {
  final _money = NumberFormat.currency(locale: 'en', symbol: '৳', decimalDigits: 0);

  // Period: current month (change here if needed)
  late final DateTime _from;
  late final DateTime _to; // inclusive end-of-day
  late final String _periodLabel; // "September 2025"
  late final String _periodKey;   // "2025-09"

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to   = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _periodLabel = DateFormat('MMMM yyyy').format(_from);
    _periodKey   = '${_from.year}-${_from.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    // live list of marketing agents
    final usersQ = db.collection('users').where('department', isEqualTo: 'marketing');

    // the month’s budget doc (kept for future settings; not used in math now)
    final budgetDocRef = db.collection('budgets').doc(_periodKey);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        title: Text('Return On Investment ( ROI )', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: usersQ.snapshots(),
        builder: (_, usersSnap) {
          if (usersSnap.hasError) {
            return const Center(child: Text('Failed to load users.', style: TextStyle(color: _brandGreen)));
          }
          if (!usersSnap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _brandGreen));
          }

          final users = usersSnap.data!.docs;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: budgetDocRef.snapshots(),
            builder: (_, __) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _HeaderPeriodCard(period: _periodLabel),

                  // NEW: Top overview (Good / Bad / Average ROI)
                  const SizedBox(height: 12),
                  _TopOverview(users: users, from: _from, to: _to),

                  const SizedBox(height: 16),
                  const _SectionTitle('Employees (live)'),
                  const SizedBox(height: 6),
                  if (users.isEmpty)
                    const _EmptyEmployees()
                  else
                    ...users.map((u) {
                      final um = u.data();
                      final name  = (um['fullName'] ?? um['name'] ?? '').toString().trim();
                      final email = (um['email'] ?? um['officeEmail'] ?? '').toString().trim();
                      final uid   = (um['uid'] ?? u.id).toString(); // fallback for display

                      return _EmployeeROIStreamTile(
                        name: name.isEmpty ? (email.isEmpty ? uid : email) : name,
                        email: email,
                        from: _from,
                        to: _to,
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/* ======================= Top overview (Good/Bad/Average) ======================= */

class _TopOverview extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> users;
  final DateTime from, to;
  const _TopOverview({required this.users, required this.from, required this.to});

  Timestamp get _fromTs => Timestamp.fromDate(from);
  Timestamp get _toTs   => Timestamp.fromDate(to);

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0.0;
    return 0.0;
  }

  static bool _tsInRange(dynamic v, Timestamp a, Timestamp b) {
    if (v is! Timestamp) return false;
    return (v.compareTo(a) >= 0) && (v.compareTo(b) <= 0);
  }

  @override
  Widget build(BuildContext context) {
    final emails = <String>[
      for (final u in users)
        ((u.data()['email'] ?? u.data()['officeEmail'] ?? '') as String).trim()
    ].where((e) => e.isNotEmpty).toList();

    if (emails.isEmpty) {
      return _OverviewRow(good: 0, bad: 0, avgRoi: 0);
    }

    final monthKey = DateFormat('MMMM_yyyy').format(from).toLowerCase();
    final emailsLower = {for (final e in emails) e.toLowerCase(): e};

    // 1) Incentives (both field-based and id-fallback in one pass)
    final incentivesStream = FirebaseFirestore.instance
        .collection('marketing_incentives')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: incentivesStream,
      builder: (context, incSnap) {
        if (!incSnap.hasData) {
          return _OverviewRow(good: 0, bad: 0, avgRoi: 0);
        }

        final fieldSum = <String, double>{}; // emailLower -> sum
        final idSum    = <String, double>{}; // emailLower -> sum

        for (final d in incSnap.data!.docs) {
          final m = d.data();
          final f = _num(m['totalIncentive']);
          if (f <= 0) continue;

          // Field-based
          final ts = m['timestamp'];
          final ue = (m['userEmail'] ?? '').toString().toLowerCase();
          final ae = (m['agentEmail'] ?? '').toString().toLowerCase();

          if (_tsInRange(ts, _fromTs, _toTs)) {
            if (emailsLower.containsKey(ue)) {
              fieldSum.update(ue, (v) => v + f, ifAbsent: () => f);
            } else if (emailsLower.containsKey(ae)) {
              fieldSum.update(ae, (v) => v + f, ifAbsent: () => f);
            }
          }

          // ID-pattern fallback: "<email>_sales_<MMMM>_<yyyy>"
          final idLower = d.id.toLowerCase();
          for (final eLower in emailsLower.keys) {
            if (idLower.startsWith(eLower) && idLower.contains(monthKey)) {
              idSum.update(eLower, (v) => v + f, ifAbsent: () => f);
              break;
            }
          }
        }

        // 2) Salaries for the month (period label)
        final periodLabel = DateFormat('MMMM yyyy').format(from);
        final payrollStream = FirebaseFirestore.instance
            .collection('payrolls')
            .where('period', isEqualTo: periodLabel)
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: payrollStream,
          builder: (context, paySnap) {
            final salaryByEmail = <String, double>{}; // emailLower -> t

            if (paySnap.hasData) {
              for (final d in paySnap.data!.docs) {
                final m = d.data();
                final mail = (m['officeEmail'] ?? '').toString().toLowerCase();
                if (!emailsLower.containsKey(mail)) continue;

                final gross = _num(m['grossSalary']);
                final t = gross > 0 ? gross : (_num(m['basicSalary']) > 0 ? _num(m['basicSalary']) : _num(m['netSalary']));
                salaryByEmail[mail] = t;
              }
            }

            // Compute ROI per employee (months=1, d=0)
            int good = 0, bad = 0;
            double sumRoi = 0;
            int roiCount = 0;

            for (final eLower in emailsLower.keys) {
              final f = fieldSum.containsKey(eLower) ? fieldSum[eLower]! : (idSum[eLower] ?? 0.0);
              final t = salaryByEmail[eLower] ?? 0.0;
              final months = 1.0;
              final d = 0.0;

              final N  = f * (100.0 / 15.0);
              final T  = t * months;
              final EC = T + f + d;
              final NR = N - EC;
              final roi = EC == 0 ? 0.0 : (NR / EC);

              if (EC > 0 || f > 0) {
                // Only count people who have any data
                sumRoi += roi;
                roiCount++;
                if (roi > 0) good++; else if (roi < 0) bad++;
              }
            }

            final avg = roiCount == 0 ? 0.0 : (sumRoi / roiCount);
            return _OverviewRow(good: good, bad: bad, avgRoi: avg);
          },
        );
      },
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final int good, bad;
  final double avgRoi;
  const _OverviewRow({required this.good, required this.bad, required this.avgRoi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final w = c.maxWidth;
          final itemW = (w - 16) / 3;
          return Row(
            children: [
              _OverviewStat(width: itemW, label: 'Good ROI', value: '$good', emoji: '✅'),
              const SizedBox(width: 8),
              _OverviewStat(width: itemW, label: 'Bad ROI', value: '$bad', emoji: '❌'),
              const SizedBox(width: 8),
              _OverviewStat(width: itemW, label: 'Avg ROI', value: _pct(avgRoi), emoji: 'ℹ️'),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final String emoji;
  const _OverviewStat({required this.width, required this.label, required this.value, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 72,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _brandGreen.withOpacity(.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _brandGreen.withOpacity(.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji  $label', style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }
}

/* ======================= Live per-employee tile ======================= */

class _EmployeeROIStreamTile extends StatelessWidget {
  final String name;
  final String email;
  final DateTime from, to;

  const _EmployeeROIStreamTile({
    required this.name,
    required this.email,
    required this.from,
    required this.to,
  });

  Timestamp get _fromTs => Timestamp.fromDate(from);
  Timestamp get _toTs   => Timestamp.fromDate(to);

  // --- helpers ---
  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0.0;
    return 0.0;
  }

  static bool _tsInRange(dynamic v, Timestamp a, Timestamp b) {
    if (v is! Timestamp) return false;
    return (v.compareTo(a) >= 0) && (v.compareTo(b) <= 0);
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    // (f) Incentives in period: field-based first, id-pattern fallback
    final String monthKey = DateFormat('MMMM_yyyy').format(from); // e.g. "July_2025"
    final incentivesStream = db
        .collection('marketing_incentives')
        .snapshots()
        .map((s) {
      num sumByFields = 0;
      bool anyFieldMatch = false;
      num sumByIdPattern = 0;

      final emailLower = email.toLowerCase();
      final monthLower = monthKey.toLowerCase();

      for (final d in s.docs) {
        final m = d.data();

        // Field-based
        final ts = m['timestamp']; // may be missing
        final ue = (m['userEmail'] ?? '').toString().toLowerCase();
        final ae = (m['agentEmail'] ?? '').toString().toLowerCase();
        final totalIncentive = _num(m['totalIncentive']);

        if (totalIncentive > 0 &&
            _tsInRange(ts, _fromTs, _toTs) &&
            (ue == emailLower || ae == emailLower)) {
          sumByFields += totalIncentive;
          anyFieldMatch = true;
        }

        // ID-pattern fallback
        final idLower = d.id.toLowerCase();
        final looksMine = idLower.startsWith(emailLower) && idLower.contains(monthLower);
        if (totalIncentive > 0 && looksMine) {
          sumByIdPattern += totalIncentive;
        }
      }

      return (anyFieldMatch ? sumByFields : sumByIdPattern).toDouble();
    });

    // (t) base salary for this month → prefer gross/base from payrolls
    final periodLabel = DateFormat('MMMM yyyy').format(from);
    final salaryStream = db
        .collection('payrolls')
        .where('officeEmail', isEqualTo: email)
        .where('period', isEqualTo: periodLabel)
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((s) {
      if (s.docs.isEmpty) return 0.0;
      final m = s.docs.first.data();
      final gross = _num(m['grossSalary']);
      if (gross > 0) return gross;
      final basic = _num(m['basicSalary']);
      if (basic > 0) return basic;
      return _num(m['netSalary']);
    });

    // Compose (months=1, d=0)
    return StreamBuilder<double>(
      stream: incentivesStream,
      builder: (_, incSnap) {
        final f = incSnap.data ?? 0.0;

        return StreamBuilder<double>(
          stream: salaryStream,
          builder: (_, salSnap) {
            final t = salSnap.data ?? 0.0;

            const months = 1;  // current month
            const d = 0.0;     // other direct costs

            final e = EmployeeROI(
              name: name,
              t: t,
              months: months,
              f: f,
              d: d,
            );
            final c = e.compute();

            return _EmployeeTile(
              e: e,
              computed: c,
              money: (n) => NumberFormat.currency(locale: 'en', symbol: '৳', decimalDigits: 0).format(n),
            );
          },
        );
      },
    );
  }
}

/* ======================= Widgets ======================= */

class _HeaderPeriodCard extends StatelessWidget {
  final String period;
  const _HeaderPeriodCard({required this.period});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_brandGreen, _greenMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Marketing Department', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          // period text supplied by parent area above
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w900, fontSize: 14));
  }
}

class _EmployeeTile extends StatelessWidget {
  final EmployeeROI e;
  final ROICompute computed;
  final String Function(num) money;
  const _EmployeeTile({required this.e, required this.computed, required this.money});

  @override
  Widget build(BuildContext context) {
    final c = computed;
    final bar = c.roi.isNaN ? 0.0 : c.roi;
    final clamped = bar.isFinite ? bar.clamp(0.0, 1.0) as double : 0.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _showDetails(context, e, c, money),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: _cardBorder),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: name + ROI badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _brandGreen.withOpacity(.08), borderRadius: BorderRadius.circular(999)),
                    child: Text(_pct(c.roi), style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: clamped,
                  minHeight: 8,
                  color: _brandGreen,
                  backgroundColor: _brandGreen.withOpacity(.12),
                ),
              ),
              const SizedBox(height: 8),

              // Small stats row (inputs)
              Row(
                children: [
                  Expanded(child: _MiniKV('Incentive (f)', money(e.f))),
                  Expanded(child: _MiniKV('Salary/mo (t)', money(e.t))),
                  Expanded(child: _MiniKV('Months', '${e.months}')),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: _MiniKV('Other costs (d)', money(e.d))),
                  Expanded(child: _MiniKV('Net profit (N)', money(computed.N))),
                  Expanded(child: _MiniKV('EC', money(computed.EC))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, EmployeeROI e, ROICompute r, String Function(num) money) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) {
        final h = MediaQuery.of(context).size.height * .88;
        return SizedBox(
          height: h,
          child: Column(
            children: [
              // handle + header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(999))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.name, style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w900, fontSize: 16), overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _brandGreen.withOpacity(.08), borderRadius: BorderRadius.circular(999)),
                      child: Text(_pct(r.roi), style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const _SectionTitle('Inputs'),
                    _KV('Incentive (f)', money(e.f)),
                    _KV('Months', '${e.months}'),
                    _KV('Base salary per month (t)', money(e.t)),
                    _KV('Other direct costs (d)', money(e.d)),

                    const SizedBox(height: 12),
                    const _SectionTitle('Derived (using your rule)'),
                    _KV('Net profit (N) = f × 100 / 15', money(r.N)),
                    _KV('Salary for period (T) = t × months', money(r.T)),
                    _KV('Employee Cost (EC) = T + f + d', money(r.EC)),
                    _KV('Net Return (NR) = N − EC', money(r.NR)),
                    _KV('ROI = NR / EC', _pct(r.roi)),

                    const SizedBox(height: 16),
                    const _SectionTitle('Notation & Tips'),
                    const _Note(
                      lines: [
                        '• ✅ ROI > 0 : Good — the employee generated more net profit than they cost.',
                        '• ❌ ROI < 0 : Bad — costs were higher than the net profit.',
                        '• f = Incentive paid this month.',
                        '• We assume incentive is 15% of net profit, so N = f × 100 / 15.',
                        '• EC (Employee Cost) = Salary for the period + Incentive + Other direct costs.',
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ======================= Small building blocks ======================= */

class _MiniKV extends StatelessWidget {
  final String k, v;
  const _MiniKV(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$k: ', style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w700, fontSize: 12)),
        Expanded(
          child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _brandGreen, fontSize: 12)),
        ),
      ],
    );
  }
}

class _KV extends StatelessWidget {
  final String k, v;
  const _KV(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w700))),
          Text(v, style: const TextStyle(color: _brandGreen)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final List<String> lines;
  const _Note({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _brandGreen.withOpacity(.06),
        border: Border.all(color: _brandGreen.withOpacity(.18)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(t, style: const TextStyle(color: _brandGreen)),
        )).toList(),
      ),
    );
  }
}

class _EmptyEmployees extends StatelessWidget {
  const _EmptyEmployees({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _cardBorder), borderRadius: BorderRadius.circular(14)),
      child: const Center(
        child: Text('No marketing employees found.',
            style: TextStyle(color: _brandGreen, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/* ======================= Data + Math ======================= */

/// New compact model: only what we need for the updated rule.
class EmployeeROI {
  final String name;
  final double t;      // base salary per month
  final int months;    // period months
  final double f;      // incentive paid (this month)
  final double d;      // other direct costs

  const EmployeeROI({
    required this.name,
    required this.t,
    required this.months,
    required this.f,
    required this.d,
  });

  ROICompute compute() {
    // Business rule:
    // Net profit (N) = Incentive (f) × 100 / 15
    final N = f * (100.0 / 15.0);

    // Salary for the period:
    final T = t * months;

    // Employee Cost (EC):
    final EC = T + f + d;

    // Net Return (NR):
    final NR = N - EC;

    // ROI:
    final roi = EC == 0 ? 0.0 : (NR / EC);

    return ROICompute(T: T, N: N, EC: EC, NR: NR, roi: roi);
  }
}

class ROICompute {
  final double T, N, EC, NR, roi;
  const ROICompute({
    required this.T,
    required this.N,
    required this.EC,
    required this.NR,
    required this.roi,
  });
}

/* ======================= Utilities ======================= */

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
