// lib/features/hr/presentation/screens/ROI.dart
// Performance & ROI — redesigned to match the reference UI
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────
// THEME  (light, clean — matches reference)
// ─────────────────────────────────────────────────────────────
const Color _bg      = Color(0xFFF8F8F7);
const Color _card    = Color(0xFFFBFAF9);
const Color _primary = Color(0xFF00C444);   // green accent
const Color _dark    = Color(0xFF18181B);   // hero gradient start
const Color _dark2   = Color(0xFF3F3F46);   // hero gradient end
const Color _border  = Color(0xFFE8E8E8);
const Color _muted   = Color(0xFF949494);
const Color _text1   = Color(0xFF000000);
const Color _red     = Color(0xFFEF4444);
const Color _amber   = Color(0xFFF59E0B);
const Color _green   = Color(0xFF22C55E);

TextStyle _ts(double size, {FontWeight w = FontWeight.w400, Color c = _text1}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: w, color: c);

// ─────────────────────────────────────────────────────────────
// HELPERS / MATH
// ─────────────────────────────────────────────────────────────
double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0.0;
  return 0.0;
}

bool _tsInRange(dynamic v, Timestamp a, Timestamp b) {
  if (v is! Timestamp) return false;
  return v.compareTo(a) >= 0 && v.compareTo(b) <= 0;
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
final _money = NumberFormat.currency(locale: 'en', symbol: '৳', decimalDigits: 0);

// ─────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────
class EmployeeROI {
  final String name, email, department;
  final double t;     // base salary per month
  final int months;
  final double f;     // incentive paid
  final double d;     // other direct costs

  const EmployeeROI({
    required this.name, required this.email, required this.department,
    required this.t, required this.months, required this.f, required this.d,
  });

  ROICompute compute() {
    final N  = f * (100.0 / 15.0);
    final T  = t * months;
    final EC = T + f + d;
    final NR = N - EC;
    final roi = EC == 0 ? 0.0 : NR / EC;
    return ROICompute(T: T, N: N, EC: EC, NR: NR, roi: roi);
  }
}

class ROICompute {
  final double T, N, EC, NR, roi;
  const ROICompute({required this.T, required this.N, required this.EC, required this.NR, required this.roi});
}

// ─────────────────────────────────────────────────────────────
// DATE RANGE PRESET
// ─────────────────────────────────────────────────────────────
enum _Preset { thisMonth, last30, custom }

class _DateRange {
  final DateTime from, to;
  final _Preset preset;
  const _DateRange({required this.from, required this.to, required this.preset});

  static _DateRange thisMonth() {
    final now = DateTime.now();
    return _DateRange(
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      preset: _Preset.thisMonth,
    );
  }

  static _DateRange last30() {
    final now = DateTime.now();
    return _DateRange(
      from: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
      preset: _Preset.last30,
    );
  }

  String get label {
    switch (preset) {
      case _Preset.thisMonth: return 'This Month';
      case _Preset.last30:    return 'Last 30 Days';
      case _Preset.custom:
        return '${DateFormat('dd MMM').format(from)} – ${DateFormat('dd MMM yyyy').format(to)}';
    }
  }

  String get periodKey => '${from.year}-${from.month.toString().padLeft(2, '0')}';
  String get periodLabel => DateFormat('MMMM yyyy').format(from);
}

// ─────────────────────────────────────────────────────────────
// MAIN PAGE
// ─────────────────────────────────────────────────────────────
class ROIPage extends StatefulWidget {
  const ROIPage({super.key});
  @override
  State<ROIPage> createState() => _ROIPageState();
}

class _ROIPageState extends State<ROIPage> {
  String _cid = '';
  _DateRange _range = _DateRange.thisMonth();

  String _deptFilter = 'All';
  String _empFilter  = 'All';

  // The employee selected for "Analyze ROI" result
  String? _analyzedEmp;

  static const List<String> _departments = ['All', 'marketing', 'factory', 'hr', 'admin', 'rnd'];

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final usersQ = _deptFilter == 'All'
        ? DB.colSync(_cid, C.users)
        : DB.colSync(_cid, C.users).where('department', isEqualTo: _deptFilter);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: usersQ.snapshots(),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator(color: _primary));
                  }
                  final allUsers = snap.data!.docs;
                  final employeeNames = ['All', ...{
                    for (final u in allUsers)
                      (u.data()['fullName'] ?? u.data()['name'] ?? '').toString().trim()
                  }.where((n) => n.isNotEmpty)];

                  // Filtered users for tiles
                  var users = allUsers;
                  if (_empFilter != 'All') {
                    users = users.where((u) {
                      final n = (u.data()['fullName'] ?? u.data()['name'] ?? '').toString().trim();
                      return n == _empFilter;
                    }).toList();
                  }

              return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                      const SizedBox(height: 16),

                      // ── Hero Card ──────────────────────────────
                      _HeroCard(users: allUsers, range: _range, cid: _cid),
                      const SizedBox(height: 20),

                      // ── Stats Grid ─────────────────────────────
                      _StatsGrid(users: allUsers, range: _range, cid: _cid),
                      const SizedBox(height: 24),

                      // ── Find Employee ──────────────────────────
                      Text('Find Employee', style: _ts(16, w: FontWeight.w600)),
                  const SizedBox(height: 12),
                      _FilterCard(
                        departments: _departments,
                        employeeNames: employeeNames,
                        deptFilter: _deptFilter,
                        empFilter: _empFilter,
                        range: _range,
                        onDeptChanged: (v) => setState(() {
                          _deptFilter = v;
                          _empFilter = 'All';
                          _analyzedEmp = null;
                        }),
                        onEmpChanged: (v) => setState(() => _empFilter = v),
                        onRangeChanged: (r) => setState(() => _range = r),
                        onAnalyze: () => setState(() => _analyzedEmp = _empFilter),
                      ),
                      const SizedBox(height: 20),

                      // ── Result Card ────────────────────────────
                      if (_analyzedEmp != null && _analyzedEmp != 'All' && users.isNotEmpty)
                        _ResultSection(
                          users: users,
                          range: _range,
                          cid: _cid,
                        ),

                      // ── Employee list (when no specific emp selected) ──
                      if (_analyzedEmp == null || _analyzedEmp == 'All') ...[
                        Row(children: [
                          Text('Employee ROI', style: _ts(15, w: FontWeight.w700)),
                          const Spacer(),
                          PdfExportButton(users: users, range: _range),
                        ]),
                        const SizedBox(height: 10),
                  if (users.isEmpty)
                          _EmptyState()
                  else
                    ...users.map((u) {
                      final um = u.data();
                      final name  = (um['fullName'] ?? um['name'] ?? '').toString().trim();
                      final email = (um['email'] ?? um['officeEmail'] ?? '').toString().trim();
                            final dept  = (um['department'] ?? '').toString().trim();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: EmployeeRoiTile(
                                name: name.isEmpty ? (email.isEmpty ? u.id : email) : name,
                        email: email,
                                department: dept,
                                range: _range,
                              ),
                      );
                    }),
                      ],
                ],
              );
            },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.maybePop(context),
          ),
          const Spacer(),
          Text('Performance & ROI', style: _ts(17, w: FontWeight.w600)),
          const Spacer(),
          _IconBtn(
            icon: Icons.more_vert_rounded,
            onTap: () => _showMoreMenu(context),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.calendar_today_rounded, color: _dark),
            title: Text('This Month', style: _ts(14)),
            onTap: () { Navigator.pop(context); setState(() => _range = _DateRange.thisMonth()); },
          ),
          ListTile(
            leading: const Icon(Icons.date_range_rounded, color: _dark),
            title: Text('Last 30 Days', style: _ts(14)),
            onTap: () { Navigator.pop(context); setState(() => _range = _DateRange.last30()); },
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded, color: _dark),
            title: Text('Custom Range…', style: _ts(14)),
            onTap: () async {
              Navigator.pop(context);
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: now,
                initialDateRange: DateTimeRange(start: _range.from, end: _range.to),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(primary: _primary, onPrimary: Colors.white),
                  ),
                  child: child!,
                ),
              );
              if (picked != null && mounted) {
                setState(() => _range = _DateRange(
                  from: picked.start,
                  to: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                  preset: _Preset.custom,
                ));
              }
            },
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ICON BUTTON
// ─────────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        child: Icon(icon, size: 20, color: _text1),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HERO CARD  — Overall Company ROI
// ─────────────────────────────────────────────────────────────
class _HeroCard extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> users;
  final _DateRange range;
  final String cid;
  const _HeroCard({required this.users, required this.range, required this.cid});
  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.users.isEmpty || widget.cid.isEmpty) {
      return _buildCard(context, 0.0, '+0.0% this period');
    }

    final emails = widget.users
        .map((u) => (u.data()['email'] ?? u.data()['officeEmail'] ?? '').toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    final fromTs = Timestamp.fromDate(widget.range.from);
    final toTs   = Timestamp.fromDate(widget.range.to);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(widget.cid, C.marketingIncentives).snapshots(),
      builder: (_, incSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: DB.colSync(widget.cid, C.payrolls)
              .where('period', isEqualTo: widget.range.periodLabel).snapshots(),
          builder: (_, paySnap) {
            final incentiveByEmail = <String, double>{};
            if (incSnap.hasData) {
        for (final d in incSnap.data!.docs) {
          final m = d.data();
          final f = _num(m['totalIncentive']);
          if (f <= 0) continue;
          final ts = m['timestamp'];
                if (!_tsInRange(ts, fromTs, toTs)) continue;
          final ue = (m['userEmail'] ?? '').toString().toLowerCase();
          final ae = (m['agentEmail'] ?? '').toString().toLowerCase();
                if (emails.contains(ue)) incentiveByEmail.update(ue, (v) => v + f, ifAbsent: () => f);
                else if (emails.contains(ae)) incentiveByEmail.update(ae, (v) => v + f, ifAbsent: () => f);
              }
            }
            final salaryByEmail = <String, double>{};
            if (paySnap.hasData) {
              for (final d in paySnap.data!.docs) {
                final m = d.data();
                final mail = (m['officeEmail'] ?? '').toString().toLowerCase();
                if (!emails.contains(mail)) continue;
                final gross = _num(m['grossSalary']);
                salaryByEmail[mail] = gross > 0 ? gross : (_num(m['basicSalary']) > 0 ? _num(m['basicSalary']) : _num(m['netSalary']));
              }
            }

            double totalRoi = 0; int count = 0;
            for (final e in emails) {
              final f = incentiveByEmail[e] ?? 0.0;
              final t = salaryByEmail[e] ?? 0.0;
              final EC = t + f;
              if (EC <= 0 && f <= 0) continue;
              final N = f * (100.0 / 15.0);
              final roi = EC == 0 ? 0.0 : (N - EC) / EC;
              totalRoi += roi; count++;
            }
            final avg = count == 0 ? 0.0 : totalRoi / count;
            return _buildCard(context, avg * 100, '${avg >= 0 ? '+' : ''}${(avg * 100).toStringAsFixed(1)}% avg this period');
          },
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, double roiPct, String trendLabel) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_dark, _dark2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          // Background icon
          Positioned(
            top: -16, right: -16,
            child: Opacity(
              opacity: 0.08,
              child: Icon(Icons.pie_chart_rounded, size: 120, color: Colors.white),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.trending_up_rounded, size: 18, color: Colors.white70),
                const SizedBox(width: 6),
                Text('Overall Company ROI', style: _ts(14, w: FontWeight.w500, c: Colors.white.withValues(alpha: 0.9))),
              ]),
              const SizedBox(height: 10),
              Text('${roiPct.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(fontSize: 44, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -1)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_upward_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(trendLabel, style: _ts(12, w: FontWeight.w600, c: Colors.white)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STATS GRID  — Best / Needs Focus / Total Staff
// ─────────────────────────────────────────────────────────────
class _StatsGrid extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> users;
  final _DateRange range;
  final String cid;
  const _StatsGrid({required this.users, required this.range, required this.cid});
  @override
  State<_StatsGrid> createState() => _StatsGridState();
}

class _StatsGridState extends State<_StatsGrid> {
  @override
  Widget build(BuildContext context) {
    final total = widget.users.length;

    if (widget.users.isEmpty || widget.cid.isEmpty) {
      return _buildGrid(context, total, '—', '—', '—', '—');
    }

    final emails = widget.users
        .map((u) => (u.data()['email'] ?? u.data()['officeEmail'] ?? '').toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    final fromTs = Timestamp.fromDate(widget.range.from);
    final toTs   = Timestamp.fromDate(widget.range.to);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(widget.cid, C.marketingIncentives).snapshots(),
      builder: (_, incSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: DB.colSync(widget.cid, C.payrolls)
              .where('period', isEqualTo: widget.range.periodLabel).snapshots(),
          builder: (_, paySnap) {
            final incentiveByEmail = <String, double>{};
            if (incSnap.hasData) {
              for (final d in incSnap.data!.docs) {
                final m = d.data();
                final f = _num(m['totalIncentive']);
                if (f <= 0) continue;
                final ts = m['timestamp'];
                if (!_tsInRange(ts, fromTs, toTs)) continue;
                final ue = (m['userEmail'] ?? '').toString().toLowerCase();
                final ae = (m['agentEmail'] ?? '').toString().toLowerCase();
                if (emails.contains(ue)) incentiveByEmail.update(ue, (v) => v + f, ifAbsent: () => f);
                else if (emails.contains(ae)) incentiveByEmail.update(ae, (v) => v + f, ifAbsent: () => f);
              }
            }
            final salaryByEmail = <String, double>{};
            if (paySnap.hasData) {
              for (final d in paySnap.data!.docs) {
                final m = d.data();
                final mail = (m['officeEmail'] ?? '').toString().toLowerCase();
                if (!emails.contains(mail)) continue;
                final gross = _num(m['grossSalary']);
                salaryByEmail[mail] = gross > 0 ? gross : (_num(m['basicSalary']) > 0 ? _num(m['basicSalary']) : _num(m['netSalary']));
              }
            }

            final roiList = <MapEntry<String, double>>[];
            for (final eLower in emails) {
              final f = incentiveByEmail[eLower] ?? 0.0;
              final t = salaryByEmail[eLower] ?? 0.0;
              final EC = t + f;
              if (EC <= 0 && f <= 0) continue;
              final N = f * (100.0 / 15.0);
              final roi = EC == 0 ? 0.0 : (N - EC) / EC;
              roiList.add(MapEntry(eLower, roi));
            }

            if (roiList.isEmpty) return _buildGrid(context, total, '—', '—', '—', '—');

            roiList.sort((a, b) => b.value.compareTo(a.value));
            final best   = roiList.first;
            final lowest = roiList.last;

            String nameFor(String email) {
              try {
                final u = widget.users.firstWhere(
                  (u) => (u.data()['email'] ?? u.data()['officeEmail'] ?? '').toString().toLowerCase() == email,
                );
                final n = (u.data()['fullName'] ?? u.data()['name'] ?? '').toString().trim();
                if (n.isNotEmpty) {
                  final parts = n.split(' ');
                  return parts.length > 1 ? '${parts[0]} ${parts[1][0]}.' : parts[0];
                }
              } catch (_) {}
              return email.split('@').first;
            }

            return _buildGrid(
              context, total,
              nameFor(best.key), _pct(best.value),
              nameFor(lowest.key), _pct(lowest.value),
            );
          },
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, int total,
      String bestName, String bestPct, String lowName, String lowPct) {
    return Row(
      children: [
        Expanded(child: _StatItem(
          icon: Icons.emoji_events_rounded,
          iconBg: const Color(0x1A22C55E),
          iconColor: _green,
          label: 'Best Performer',
          value: bestName,
          sub: bestPct,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatItem(
          icon: Icons.warning_amber_rounded,
          iconBg: const Color(0x1AEF4444),
          iconColor: _red,
          label: 'Needs Focus',
          value: lowName,
          sub: lowPct,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatItem(
          icon: Icons.people_alt_rounded,
          iconBg: _border,
          iconColor: _text1,
          label: 'Total Staff',
          value: '$total',
          sub: 'Active',
        )),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label, value, sub;
  const _StatItem({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.label, required this.value, required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
            children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(999)),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(label.toUpperCase(),
              textAlign: TextAlign.center,
              style: _ts(9, w: FontWeight.w700, c: _muted)),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _ts(13, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(sub, style: _ts(11, c: _muted)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FILTER CARD  — Find Employee
// ─────────────────────────────────────────────────────────────
class _FilterCard extends StatelessWidget {
  final List<String> departments, employeeNames;
  final String deptFilter, empFilter;
  final _DateRange range;
  final ValueChanged<String> onDeptChanged, onEmpChanged;
  final ValueChanged<_DateRange> onRangeChanged;
  final VoidCallback onAnalyze;

  const _FilterCard({
    required this.departments, required this.employeeNames,
    required this.deptFilter, required this.empFilter,
    required this.range,
    required this.onDeptChanged, required this.onEmpChanged,
    required this.onRangeChanged, required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Department
        _MockInput(
          icon: Icons.business_rounded,
          label: deptFilter == 'All' ? 'All Departments' : deptFilter.toUpperCase(),
          active: deptFilter != 'All',
          trailing: Icons.keyboard_arrow_down_rounded,
          onTap: () => _pickFromList(context, departments, deptFilter, onDeptChanged),
        ),
        const SizedBox(height: 10),

        // Employee
        _MockInput(
          icon: Icons.search_rounded,
          label: empFilter == 'All' ? 'Search Employee…' : empFilter,
          active: empFilter != 'All',
          trailing: empFilter != 'All' ? Icons.cancel_rounded : null,
          onTap: () => _pickFromList(context, employeeNames, empFilter, onEmpChanged),
          onTrailingTap: empFilter != 'All' ? () => onEmpChanged('All') : null,
        ),
        const SizedBox(height: 10),

        // Date range
        _MockInput(
          icon: Icons.calendar_today_rounded,
          label: range.label,
          active: false,
          trailing: Icons.keyboard_arrow_down_rounded,
          onTap: () => _pickRange(context),
        ),
        const SizedBox(height: 14),

        // Analyze button
        GestureDetector(
          onTap: onAnalyze,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.analytics_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text('Analyze ROI', style: _ts(15, w: FontWeight.w700, c: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }

  void _pickFromList(BuildContext context, List<String> items, String current, ValueChanged<String> onPick) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: items.map((item) => ListTile(
          title: Text(item == 'All' ? 'All' : item, style: _ts(14)),
          trailing: item == current ? Icon(Icons.check_rounded, color: _primary) : null,
          onTap: () { Navigator.pop(context); onPick(item); },
        )).toList(),
      ),
    );
  }

  void _pickRange(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.calendar_today_rounded),
            title: Text('This Month', style: _ts(14)),
            onTap: () { Navigator.pop(context); onRangeChanged(_DateRange.thisMonth()); },
          ),
          ListTile(
            leading: const Icon(Icons.date_range_rounded),
            title: Text('Last 30 Days', style: _ts(14)),
            onTap: () { Navigator.pop(context); onRangeChanged(_DateRange.last30()); },
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: Text('Custom Range…', style: _ts(14)),
            onTap: () async {
              Navigator.pop(context);
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: now,
                initialDateRange: DateTimeRange(start: range.from, end: range.to),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(primary: _primary, onPrimary: Colors.white),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                onRangeChanged(_DateRange(
                  from: picked.start,
                  to: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                  preset: _Preset.custom,
                ));
              }
            },
          ),
        ]),
      ),
    );
  }
}

class _MockInput extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final IconData? trailing;
  final VoidCallback onTap;
  final VoidCallback? onTrailingTap;

  const _MockInput({
    required this.icon, required this.label, required this.active,
    this.trailing, required this.onTap, this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: active ? Colors.white : _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _primary : Colors.transparent),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: active ? _primary : _muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: _ts(14, c: active ? _text1 : _muted),
                overflow: TextOverflow.ellipsis),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap ?? onTap,
              child: Icon(trailing, size: 18, color: _muted),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RESULT SECTION  — shown after "Analyze ROI"
// ─────────────────────────────────────────────────────────────
class _ResultSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> users;
  final _DateRange range;
  final String cid;
  const _ResultSection({required this.users, required this.range, required this.cid});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Analysis Result', style: _ts(15, w: FontWeight.w700)),
          const Spacer(),
          PdfExportButton(users: users, range: range),
        ]),
        const SizedBox(height: 12),
        ...users.map((u) {
          final um = u.data();
          final name  = (um['fullName'] ?? um['name'] ?? '').toString().trim();
          final email = (um['email'] ?? um['officeEmail'] ?? '').toString().trim();
          final dept  = (um['department'] ?? '').toString().trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ResultCard(
              name: name.isEmpty ? email : name,
              email: email,
              department: dept,
              range: range,
              cid: cid,
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ResultCard extends StatefulWidget {
  final String name, email, department, cid;
  final _DateRange range;
  const _ResultCard({required this.name, required this.email, required this.department,
      required this.range, required this.cid});
  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  @override
  Widget build(BuildContext context) {
    final fromTs = Timestamp.fromDate(widget.range.from);
    final toTs   = Timestamp.fromDate(widget.range.to);
    final emailLower = widget.email.toLowerCase();
    final monthKey = DateFormat('MMMM_yyyy').format(widget.range.from).toLowerCase();

    final incentivesStream = DB.colSync(widget.cid, C.marketingIncentives).snapshots().map((s) {
      num sumByFields = 0; bool anyFieldMatch = false; num sumByIdPattern = 0;
      for (final d in s.docs) {
        final m = d.data();
        final ts = m['timestamp'];
        final ue = (m['userEmail'] ?? '').toString().toLowerCase();
        final ae = (m['agentEmail'] ?? '').toString().toLowerCase();
        final inc = _num(m['totalIncentive']);
        if (inc > 0 && _tsInRange(ts, fromTs, toTs) && (ue == emailLower || ae == emailLower)) {
          sumByFields += inc; anyFieldMatch = true;
        }
        final idL = d.id.toLowerCase();
        if (inc > 0 && idL.startsWith(emailLower) && idL.contains(monthKey)) sumByIdPattern += inc;
      }
      return (anyFieldMatch ? sumByFields : sumByIdPattern).toDouble();
    });

    final salaryStream = DB.colSync(widget.cid, C.payrolls)
        .where('officeEmail', isEqualTo: widget.email)
        .where('period', isEqualTo: widget.range.periodLabel)
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((s) {
      if (s.docs.isEmpty) return 0.0;
      final m = s.docs.first.data();
      final gross = _num(m['grossSalary']);
      if (gross > 0) return gross;
      final basic = _num(m['basicSalary']);
      return basic > 0 ? basic : _num(m['netSalary']);
    });

    return StreamBuilder<double>(
      stream: incentivesStream,
      builder: (_, incSnap) {
        final f = incSnap.data ?? 0.0;
        return StreamBuilder<double>(
          stream: salaryStream,
          builder: (_, salSnap) {
            final t = salSnap.data ?? 0.0;
            final emp = EmployeeROI(
              name: widget.name, email: widget.email, department: widget.department,
              t: t, months: 1, f: f, d: 0.0,
            );
            final c = emp.compute();
            final roiColor = c.roi > 0.3 ? _green : (c.roi >= 0 ? _amber : _red);

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  // ── Result Header ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: _border)),
                    ),
                    child: Row(
                      children: [
                        // Avatar circle
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: roiColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Center(
                            child: Text(
                              widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                              style: _ts(22, w: FontWeight.w800, c: roiColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.name, style: _ts(17, w: FontWeight.w700),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.work_outline_rounded, size: 13, color: _muted),
                                const SizedBox(width: 4),
                                Text(widget.department.isEmpty ? 'Employee' : widget.department.toUpperCase(),
                                    style: _ts(12, c: _muted)),
                              ]),
                            ],
                          ),
                        ),
                        // ROI Badge
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(_pct(c.roi),
                              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: roiColor, height: 1)),
                          const SizedBox(height: 3),
                          Text('NET ROI', style: _ts(11, w: FontWeight.w700, c: _muted)),
                        ]),
                      ],
                    ),
                  ),

                  // ── Result Body ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Calculation Breakdown
                        Row(children: [
                          Icon(Icons.calculate_outlined, size: 15, color: _dark),
                          const SizedBox(width: 6),
                          Text('Calculation Breakdown', style: _ts(13, w: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ROI is determined by subtracting the total cost of employment from the revenue generated, divided by the cost.',
                                style: _ts(13, c: _muted),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _border, style: BorderStyle.solid),
                                ),
                                child: Text(
                                  '(${_money.format(c.N)} Rev − ${_money.format(c.EC)} Cost) / ${_money.format(c.EC)}',
                                  style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w600, color: _text1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Performance Insights
                        Row(children: [
                          Icon(Icons.lightbulb_outline_rounded, size: 15, color: _amber),
                          const SizedBox(width: 6),
                          Text('Performance Insights', style: _ts(13, w: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 8),
                        _InsightItem(
                          positive: c.roi > 0,
                          text: c.roi > 0
                              ? 'Positive return: generated ${_money.format(c.NR)} net value above employment cost.'
                              : 'Negative return: employment cost exceeds generated value by ${_money.format(-c.NR)}.',
                        ),
                        const SizedBox(height: 8),
                        _InsightItem(
                          positive: f > 0,
                          text: f > 0
                              ? 'Incentive earned: ${_money.format(f)} — indicates active revenue contribution.'
                              : 'No incentive recorded for this period. Check payroll or incentive data.',
                        ),
                        const SizedBox(height: 16),

                        // Key metrics row
                        Row(children: [
                          _MetricChip(label: 'Incentive', value: _money.format(f)),
                          const SizedBox(width: 8),
                          _MetricChip(label: 'Salary', value: _money.format(t)),
                          const SizedBox(width: 8),
                          _MetricChip(label: 'Net Return', value: _money.format(c.NR)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _InsightItem extends StatelessWidget {
  final bool positive;
  final String text;
  const _InsightItem({required this.positive, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            positive ? Icons.check_circle_rounded : Icons.arrow_circle_down_rounded,
            size: 18,
            color: positive ? _green : _red,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _ts(13, c: _text1))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EMPLOYEE ROI TILE  (list view — unchanged logic, refreshed UI)
// ─────────────────────────────────────────────────────────────
class EmployeeRoiTile extends StatefulWidget {
  final String name, email, department;
  final _DateRange range;

  const EmployeeRoiTile({
    super.key,
    required this.name, required this.email, required this.department, required this.range,
  });

  Timestamp get _fromTs => Timestamp.fromDate(range.from);
  Timestamp get _toTs   => Timestamp.fromDate(range.to);

  @override
  State<EmployeeRoiTile> createState() => _EmployeeRoiTileState();
}

class _EmployeeRoiTileState extends State<EmployeeRoiTile> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthKey   = DateFormat('MMMM_yyyy').format(widget.range.from).toLowerCase();
    final emailLower = widget.email.toLowerCase();
    final fromTs     = widget._fromTs;
    final toTs       = widget._toTs;

    final incentivesStream = DB.colSync(_cid, C.marketingIncentives).snapshots().map((s) {
      num sumByFields = 0; bool anyFieldMatch = false; num sumByIdPattern = 0;
      for (final d in s.docs) {
        final m = d.data();
        final ts = m['timestamp'];
        final ue = (m['userEmail'] ?? '').toString().toLowerCase();
        final ae = (m['agentEmail'] ?? '').toString().toLowerCase();
        final inc = _num(m['totalIncentive']);
        if (inc > 0 && _tsInRange(ts, fromTs, toTs) && (ue == emailLower || ae == emailLower)) {
          sumByFields += inc; anyFieldMatch = true;
        }
        final idL = d.id.toLowerCase();
        if (inc > 0 && idL.startsWith(emailLower) && idL.contains(monthKey)) sumByIdPattern += inc;
      }
      return (anyFieldMatch ? sumByFields : sumByIdPattern).toDouble();
    });

    final salaryStream = DB.colSync(_cid, C.payrolls)
        .where('officeEmail', isEqualTo: widget.email)
        .where('period', isEqualTo: widget.range.periodLabel)
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((s) {
      if (s.docs.isEmpty) return 0.0;
      final m = s.docs.first.data();
      final gross = _num(m['grossSalary']);
      if (gross > 0) return gross;
      final basic = _num(m['basicSalary']);
      return basic > 0 ? basic : _num(m['netSalary']);
    });

    return StreamBuilder<double>(
      stream: incentivesStream,
      builder: (_, incSnap) {
        final f = incSnap.data ?? 0.0;
        return StreamBuilder<double>(
          stream: salaryStream,
          builder: (_, salSnap) {
            final t = salSnap.data ?? 0.0;
            final e = EmployeeROI(name: widget.name, email: widget.email,
                department: widget.department, t: t, months: 1, f: f, d: 0.0);
            final c = e.compute();
            return _EmployeeTileCard(emp: e, computed: c);
          },
        );
      },
    );
  }
}

class _EmployeeTileCard extends StatelessWidget {
  final EmployeeROI emp;
  final ROICompute computed;
  const _EmployeeTileCard({required this.emp, required this.computed});

  @override
  Widget build(BuildContext context) {
    final c = computed;
    final roiPositive = c.roi >= 0;
    final roiColor = c.roi > 0.3 ? _green : (c.roi >= 0 ? _amber : _red);
    final barVal = c.roi.isNaN || !c.roi.isFinite ? 0.0 : c.roi.clamp(0.0, 1.0).toDouble();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (_) => RoiDetailsDialog(emp: emp, computed: c),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: roiPositive ? _border : _red.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: roiColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                        style: _ts(16, w: FontWeight.w800, c: roiColor)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(emp.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: _ts(14, w: FontWeight.w700)),
                    Text(emp.department.isEmpty ? emp.email : emp.department,
                        style: _ts(11, c: _muted)),
                  ]),
                  ),
                  Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: roiColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: roiColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(_pct(c.roi), style: _ts(13, w: FontWeight.w800, c: roiColor)),
                ),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: barVal, minHeight: 5,
                  color: roiColor, backgroundColor: roiColor.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                _MetricChip(label: 'Incentive', value: _money.format(emp.f)),
                const SizedBox(width: 6),
                _MetricChip(label: 'Salary', value: _money.format(emp.t)),
                const SizedBox(width: 6),
                _MetricChip(label: 'Net Return', value: _money.format(c.NR)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.touch_app_rounded, size: 11, color: _muted),
                const SizedBox(width: 4),
                Text('Tap for full details', style: _ts(10, c: _muted)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label, value;
  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: _ts(9, c: _muted)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: _ts(11, w: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ROI DETAILS DIALOG
// ─────────────────────────────────────────────────────────────
class RoiDetailsDialog extends StatelessWidget {
  final EmployeeROI emp;
  final ROICompute computed;
  const RoiDetailsDialog({super.key, required this.emp, required this.computed});

  @override
  Widget build(BuildContext context) {
    final c = computed;
    final roiColor = c.roi > 0.3 ? _green : (c.roi >= 0 ? _amber : _red);
    final roiPositive = c.roi >= 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
        ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
            children: [
            // Header
                    Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_dark, _dark2],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                        style: _ts(20, w: FontWeight.w800, c: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(emp.name, style: _ts(15, w: FontWeight.w700, c: Colors.white),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(emp.department.isEmpty ? 'Employee' : emp.department,
                        style: _ts(11, c: Colors.white70)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero ROI
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: roiColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: roiColor.withValues(alpha: 0.25)),
                      ),
                      child: Column(children: [
                        Text('Final ROI', style: _ts(12, c: _muted)),
                        const SizedBox(height: 6),
                        Text(_pct(c.roi), style: GoogleFonts.inter(fontSize: 38, fontWeight: FontWeight.w800, color: roiColor)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: roiColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            roiPositive ? '✅  Positive Return' : '❌  Negative Return',
                            style: _ts(11, w: FontWeight.w700, c: roiColor),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    _DialogSection(title: 'Calculation Inputs'),
                    _DialogRow('Incentive Paid',           _money.format(emp.f)),
                    _DialogRow('Monthly Salary',           _money.format(emp.t)),
                    _DialogRow('Period (Months)',           '${emp.months}'),
                    _DialogRow('Other Direct Costs',       _money.format(emp.d)),
                    const SizedBox(height: 16),

                    _DialogSection(title: 'Derived Values'),
                    _DialogRow('Estimated Net Profit',     _money.format(c.N),   sub: 'Incentive × 100 ÷ 15'),
                    _DialogRow('Employee Cost',            _money.format(c.EC),  sub: 'Salary × Months + Incentive + Other'),
                    _DialogRow('Net Return',               _money.format(c.NR),  sub: 'Net Profit − Employee Cost'),
                    const SizedBox(height: 16),

                    _HowItWorks(),
                  ],
                ),
                ),
              ),
            ],
        ),
      ),
    );
  }
}

class _DialogSection extends StatelessWidget {
  final String title;
  const _DialogSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 3, height: 14,
            decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: _ts(13, w: FontWeight.w700)),
      ]),
    );
  }
}

class _DialogRow extends StatelessWidget {
  final String label, value;
  final String? sub;
  const _DialogRow(this.label, this.value, {this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: _ts(13, w: FontWeight.w600)),
            if (sub != null) Text(sub!, style: _ts(10, c: _muted)),
          ]),
        ),
        Text(value, style: _ts(13, w: FontWeight.w700, c: _primary)),
      ]),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline_rounded, size: 14, color: _green),
          const SizedBox(width: 6),
          Text('How ROI is Calculated', style: _ts(12, w: FontWeight.w700, c: _green)),
        ]),
        const SizedBox(height: 8),
        ...[
          'Incentive is assumed to be 15% of net profit.',
          'Net Profit = Incentive × 100 ÷ 15',
          'Employee Cost = (Salary × Months) + Incentive + Other Costs',
          'Net Return = Net Profit − Employee Cost',
          'ROI (%) = Net Return ÷ Employee Cost × 100',
        ].map((line) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('• ', style: _ts(12, c: _green)),
            Expanded(child: Text(line, style: _ts(11, c: _muted))),
          ]),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PDF EXPORT BUTTON
// ─────────────────────────────────────────────────────────────
class PdfExportButton extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> users;
  final _DateRange range;
  const PdfExportButton({super.key, required this.users, required this.range});
  @override
  State<PdfExportButton> createState() => _PdfExportButtonState();
}

class _PdfExportButtonState extends State<PdfExportButton> {
  String _cid = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  Future<void> _export() async {
    setState(() => _loading = true);
    try {
      String companyName = 'Company';
      try {
        final snap = await DB.colSync(_cid, C.companyProfile).doc('main').get();
        if (snap.exists) {
          companyName = (snap.data()?['companyName'] ?? snap.data()?['legalName'] ?? 'Company').toString();
        }
      } catch (_) {}

      final rows = <_PdfRow>[];
      for (final u in widget.users) {
        final um = u.data();
        final name  = (um['fullName'] ?? um['name'] ?? '').toString().trim();
        final email = (um['email'] ?? um['officeEmail'] ?? '').toString().trim();
        final dept  = (um['department'] ?? '').toString().trim();

        double f = 0.0;
        try {
          final incSnap = await DB.colSync(_cid, C.marketingIncentives).get();
          final fromTs = Timestamp.fromDate(widget.range.from);
          final toTs   = Timestamp.fromDate(widget.range.to);
          final monthKey = DateFormat('MMMM_yyyy').format(widget.range.from).toLowerCase();
          final emailLower = email.toLowerCase();
          num sumByFields = 0; bool anyField = false; num sumById = 0;
          for (final d in incSnap.docs) {
            final m = d.data();
            final inc = _num(m['totalIncentive']);
            if (inc <= 0) continue;
            final ts = m['timestamp'];
            final ue = (m['userEmail'] ?? '').toString().toLowerCase();
            final ae = (m['agentEmail'] ?? '').toString().toLowerCase();
            if (_tsInRange(ts, fromTs, toTs) && (ue == emailLower || ae == emailLower)) {
              sumByFields += inc; anyField = true;
            }
            final idL = d.id.toLowerCase();
            if (idL.startsWith(emailLower) && idL.contains(monthKey)) sumById += inc;
          }
          f = (anyField ? sumByFields : sumById).toDouble();
        } catch (_) {}

        double t = 0.0;
        try {
          final paySnap = await DB.colSync(_cid, C.payrolls)
              .where('officeEmail', isEqualTo: email)
              .where('period', isEqualTo: widget.range.periodLabel)
              .orderBy('generatedAt', descending: true).limit(1).get();
          if (paySnap.docs.isNotEmpty) {
            final m = paySnap.docs.first.data();
            final gross = _num(m['grossSalary']);
            t = gross > 0 ? gross : (_num(m['basicSalary']) > 0 ? _num(m['basicSalary']) : _num(m['netSalary']));
          }
        } catch (_) {}

        final emp = EmployeeROI(name: name.isEmpty ? email : name, email: email, department: dept, t: t, months: 1, f: f, d: 0.0);
        final c = emp.compute();
        rows.add(_PdfRow(name: emp.name, dept: dept, incentive: f, salary: t, ec: c.EC, nr: c.NR, roi: c.roi));
      }

      final pdfBytes = await _buildPdf(companyName, rows);
      await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'ROI_Report_${widget.range.label.replaceAll(' ', '_')}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Uint8List> _buildPdf(String companyName, List<_PdfRow> rows) async {
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.times(), bold: pw.Font.timesBold(),
        italic: pw.Font.timesItalic(), boldItalic: pw.Font.timesBoldItalic(),
      ),
    );
    final green  = PdfColor.fromHex('#00C444');
    final dark   = PdfColor.fromHex('#18181B');
    final grey   = PdfColor.fromHex('#949494');
    final light  = PdfColor.fromHex('#F8F8F7');
    final red    = PdfColor.fromHex('#EF4444');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(companyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.Text('ROI Performance Report', style: pw.TextStyle(fontSize: 11, color: grey)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Period: ${widget.range.label}', style: pw.TextStyle(fontSize: 10, color: grey)),
            pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: grey)),
          ]),
        ]),
        pw.SizedBox(height: 4),
        pw.Divider(color: green, thickness: 1.5),
        pw.SizedBox(height: 8),
      ]),
      footer: (ctx) => pw.Column(children: [
        pw.Divider(color: grey, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('$companyName — Confidential', style: pw.TextStyle(fontSize: 8, color: grey)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 8, color: grey)),
        ]),
      ]),
      build: (ctx) {
        final totalEmp = rows.length;
        final avgRoi = rows.isEmpty ? 0.0 : rows.fold(0.0, (s, r) => s + r.roi) / rows.length;
        final best  = rows.isEmpty ? null : rows.reduce((a, b) => a.roi > b.roi ? a : b);
        final worst = rows.isEmpty ? null : rows.reduce((a, b) => a.roi < b.roi ? a : b);

        return [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: light, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
                _pdfStat('Total Employees', '$totalEmp', dark),
                _pdfStat('Average ROI', _pct(avgRoi), green),
                _pdfStat('Best ROI', best == null ? '—' : _pct(best.roi), green),
                _pdfStat('Worst ROI', worst == null ? '—' : _pct(worst.roi), red),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Employee-wise ROI Breakdown',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: dark)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#E8E8E8'), width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5), 3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5), 5: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: dark),
                children: ['Employee', 'Department', 'Incentive', 'Salary', 'Emp. Cost', 'ROI']
                    .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                )).toList(),
              ),
              ...rows.asMap().entries.map((entry) {
                final i = entry.key; final r = entry.value;
                final bg = i.isEven ? PdfColors.white : light;
                final roiC = r.roi >= 0 ? green : red;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _pdfCell(r.name, bold: true),
                    _pdfCell(r.dept.isEmpty ? '—' : r.dept),
                    _pdfCell(_money.format(r.incentive)),
                    _pdfCell(_money.format(r.salary)),
                    _pdfCell(_money.format(r.ec)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: pw.Text(_pct(r.roi),
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: roiC)),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: light, borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: green, width: 0.5),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('How ROI is Calculated', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark)),
              pw.SizedBox(height: 4),
              pw.Text('• Net Profit = Incentive × 100 ÷ 15', style: pw.TextStyle(fontSize: 8, color: grey)),
              pw.Text('• Employee Cost = (Salary × Months) + Incentive + Other Costs', style: pw.TextStyle(fontSize: 8, color: grey)),
              pw.Text('• Net Return = Net Profit − Employee Cost', style: pw.TextStyle(fontSize: 8, color: grey)),
              pw.Text('• ROI = Net Return ÷ Employee Cost × 100', style: pw.TextStyle(fontSize: 8, color: grey)),
            ]),
          ),
        ];
      },
    ));
    return doc.save();
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color) {
    return pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#949494'))),
    ]);
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text, style: pw.TextStyle(
          fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : _export,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: _dark,
        borderRadius: BorderRadius.circular(10),
      ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _loading
              ? const SizedBox(width: 13, height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(_loading ? 'Generating…' : 'PDF', style: _ts(12, w: FontWeight.w700, c: Colors.white)),
        ]),
      ),
    );
  }
}

class _PdfRow {
  final String name, dept;
  final double incentive, salary, ec, nr, roi;
  const _PdfRow({required this.name, required this.dept, required this.incentive,
      required this.salary, required this.ec, required this.nr, required this.roi});
}

// ─────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline_rounded, size: 36, color: _muted.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text('No employees match the selected filters.', style: _ts(13, c: _muted)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LEGACY EXPORTS (kept for any external references)
// ─────────────────────────────────────────────────────────────
class FilterBar extends StatelessWidget {
  final List<String> departments, employeeNames;
  final String deptFilter, subFilter, empFilter;
  final _DateRange range;
  final ValueChanged<String> onDeptChanged, onSubChanged, onEmpChanged;
  final ValueChanged<_DateRange> onRangeChanged;

  const FilterBar({
    super.key,
    required this.departments, required this.employeeNames,
    required this.deptFilter, required this.subFilter, required this.empFilter,
    required this.range,
    required this.onDeptChanged, required this.onSubChanged, required this.onEmpChanged,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SummaryCard extends StatelessWidget {
  final double width;
  final String label, value;
  final String? sub;
  final IconData icon;
  final Color color;

  const SummaryCard({
    super.key, required this.width, required this.label, required this.value,
    this.sub, required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
