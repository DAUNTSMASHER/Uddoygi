import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

import 'package:uddoygi/features/employee_management/add_employee_page.dart';
import 'package:uddoygi/features/employee_management/all_employees_page.dart';
import 'package:uddoygi/features/employee_management/hr_recommendations_page.dart';
import 'package:uddoygi/features/employee_management/transitions_page.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _p900  = Color(0xFF2D0060);   // deepest purple
const Color _p700  = Color(0xFF5B0A98);   // primary purple
const Color _p500  = Color(0xFF7C3AED);   // mid violet
const Color _p200  = Color(0xFFEDE9FE);   // lavender tint
const Color _bg    = Color(0xFFF5F3FF);   // page bg
const Color _white = Colors.white;
const Color _ink   = Color(0xFF1A1A2E);
const Color _sub   = Color(0xFF64748B);

// Accent palette for dept chips
const _deptColors = {
  'HR & Accounts':  Color(0xFF0891B2),
  'Marketing':      Color(0xFF16A34A),
  'Factory':        Color(0xFFB45309),
  'Admin':          Color(0xFF7C3AED),
  'R&D':            Color(0xFFDB2777),
  'Others':         Color(0xFF64748B),
};

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});
  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen>
    with SingleTickerProviderStateMixin {
  String _cid = '';
  late final AnimationController _heroCtrl;
  late final Animation<double> _heroAnim;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
    _heroAnim = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeInOut);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    super.dispose();
  }

  static String _normalizeDept(String raw) {
    if (raw.isEmpty) return 'Others';
    if (raw.contains('hr') || raw.contains('account')) return 'HR & Accounts';
    if (raw.contains('market')) return 'Marketing';
    if (raw.contains('factory') || raw.contains('production')) return 'Factory';
    if (raw.contains('admin')) return 'Admin';
    if (raw.contains('rnd') || raw.contains('r&d') || raw.contains('research')) return 'R&D';
    return 'Others';
  }

  static Future<_AttendanceQuick> _attendanceQuick() async {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    try {
      final recs = await DB.firestore.collectionGroup('records').get();
    int present = 0, late = 0, total = 0, leaveToday = 0;
    for (final r in recs.docs) {
      final parentId = r.reference.parent.parent?.id ?? '';
      final parts = parentId.split('-');
      if (parts.length != 3) continue;
      final status = (r.data()['status'] ?? '').toString().toLowerCase();
      if (parts[0] == y && parts[1] == m) {
        if (status == 'present') present++;
        if (status == 'late') late++;
        total++;
      }
      if (parts[0] == y && parts[1] == m && parts[2] == d) {
        if (status == 'leave') leaveToday++;
      }
    }
    final avg = total > 0 ? ((present + late) / total) * 100 : 0.0;
    return _AttendanceQuick(avgPercent: avg, leaveToday: leaveToday);
    } catch (_) {
      return const _AttendanceQuick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _p700))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: DB.colSync(_cid, C.users).snapshots(),
              builder: (_, usersSnap) {
                final users = usersSnap.data?.docs ?? [];
                final waiting = usersSnap.connectionState == ConnectionState.waiting;

                final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
                int totalEmployees = users.length;
                int newThisMonth = 0;
                final Map<String, int> deptMap = {};

                for (final u in users) {
                  final data = u.data();
                  final raw = (data['department'] as String?)?.trim().toLowerCase() ?? '';
                  final dep = _normalizeDept(raw);
                  deptMap[dep] = (deptMap[dep] ?? 0) + 1;

                  final createdAt = data['createdAt'];
                  DateTime? created;
                  if (createdAt is Timestamp) created = createdAt.toDate();
                  if (createdAt is DateTime) created = createdAt;
                  if (created != null && created.isAfter(monthStart)) newThisMonth++;
                }

                return FutureBuilder<_AttendanceQuick>(
                  future: _attendanceQuick(),
                  builder: (_, attSnap) {
                    final att = attSnap.data ?? const _AttendanceQuick();

                    return CustomScrollView(
                      slivers: [
                        // ── Animated hero header ──────────────────────────────
                        SliverToBoxAdapter(
                          child: _HeroHeader(
                            anim: _heroAnim,
                            totalEmployees: totalEmployees,
                            newThisMonth: newThisMonth,
                            avgAttendance: att.avgPercent,
                            leaveToday: att.leaveToday,
                            loading: waiting,
                          ),
                        ),

                        // ── Department breakdown ──────────────────────────────
                        SliverToBoxAdapter(
              child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            child: _SectionLabel(
                              icon: Icons.donut_small_rounded,
                              label: 'By Department',
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: waiting
                                ? const _Shimmer(height: 72)
                                : _DeptRow(deptMap: deptMap, total: totalEmployees),
                          ),
                        ),

                        // ── Quick actions ─────────────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            child: _SectionLabel(
                              icon: Icons.bolt_rounded,
                              label: 'Quick Actions',
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                          sliver: SliverGrid(
                            delegate: SliverChildListDelegate([
                              _ActionCard(
                                title: 'Add Employee',
                                subtitle: 'Onboard a new team member',
                                icon: Icons.person_add_alt_1_rounded,
                                accent: _p700,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const AddEmployeePage())),
                              ),
                              _ActionCard(
                                title: 'All Employees',
                                subtitle: 'View & manage the full directory',
                                icon: Icons.groups_rounded,
                                accent: const Color(0xFF0891B2),
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const AllEmployeesPage())),
                              ),
                              _ActionCard(
                                title: 'Recommendations',
                                subtitle: 'Review HR suggestions',
                                icon: Icons.thumb_up_alt_rounded,
                                accent: const Color(0xFF16A34A),
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const HRRecommendationsPage())),
                              ),
                              _ActionCard(
                                title: 'Promotions',
                                subtitle: 'Manage role transitions',
                                icon: Icons.trending_up_rounded,
                                accent: const Color(0xFFB45309),
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const TransitionsPage())),
                              ),
                            ]),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.35,
              ),
            ),
          ),
        ],
                    );
                  },
                );
              },
      ),
    );
  }
}

// ── Animated hero header ──────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final Animation<double> anim;
  final int totalEmployees;
  final int newThisMonth;
  final double avgAttendance;
  final int leaveToday;
  final bool loading;

  const _HeroHeader({
    required this.anim,
    required this.totalEmployees,
    required this.newThisMonth,
    required this.avgAttendance,
    required this.leaveToday,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final t = anim.value;
        final gradBegin = Alignment.lerp(Alignment.topLeft, Alignment.bottomLeft, t)!;
        final gradEnd   = Alignment.lerp(Alignment.bottomRight, Alignment.topRight, t)!;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: gradBegin,
              end: gradEnd,
              colors: const [_p900, _p700, Color(0xFF9333EA)],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text('Employee Dashboard',
                          style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    ),
                    // Decorative orb
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_rounded,
                          color: Colors.white70, size: 20),
                    ),
                    const SizedBox(width: 8),
                  ]),
                ),

                const SizedBox(height: 20),

                // Big stat
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        loading ? '—' : '$totalEmployees',
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            height: 1.0),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total',
                                style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            Text('Employees',
                                style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // New badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.fiber_new_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            loading ? '—' : '+$newThisMonth this month',
                            style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // KPI chips row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Row(children: [
                    _HeroChip(
                      icon: Icons.how_to_reg_rounded,
                      label: 'Avg Attendance',
                      value: loading
                          ? '—'
                          : '${avgAttendance.toStringAsFixed(1)}%',
                      color: const Color(0xFF4ADE80),
                    ),
                    const SizedBox(width: 10),
                    _HeroChip(
                      icon: Icons.beach_access_rounded,
                      label: 'On Leave Today',
                      value: loading ? '—' : '$leaveToday',
                      color: const Color(0xFFFBBF24),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _HeroChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Department row ────────────────────────────────────────────────────────────
class _DeptRow extends StatelessWidget {
  final Map<String, int> deptMap;
  final int total;
  const _DeptRow({required this.deptMap, required this.total});

  @override
  Widget build(BuildContext context) {
    if (deptMap.isEmpty) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x14000000)),
        ),
        child: Center(
          child: Text('No employees yet',
              style: GoogleFonts.spaceGrotesk(color: _sub, fontSize: 13)),
        ),
      );
    }

    final sorted = deptMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: sorted.map((e) {
                  final frac = total > 0 ? e.value / total : 0.0;
                  final color = _deptColors[e.key] ?? _p500;
                  return Flexible(
                    flex: (frac * 1000).round(),
                    child: Container(color: color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: sorted.map((e) {
              final color = _deptColors[e.key] ?? _p500;
              final pct = total > 0
                  ? '${(e.value / total * 100).toStringAsFixed(0)}%'
                  : '0%';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text('${e.key}  ',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
                  Text('${e.value}',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  Text('  $pct',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, color: _sub)),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Action card ───────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: accent.withValues(alpha: 0.08),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x14000000)),
            boxShadow: const [
              BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          padding: const EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: icon + arrow
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const Spacer(),
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: accent, size: 14),
                  ),
                ],
              ),
              const Spacer(),
              // Title
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _ink)),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 10.5,
                      color: _sub,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: _p200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _p700, size: 15),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _ink)),
    ]);
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────
class _Shimmer extends StatelessWidget {
  final double height;
  const _Shimmer({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _p200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _p700, strokeWidth: 2),
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────
class _AttendanceQuick {
  final double avgPercent;
  final int leaveToday;
  const _AttendanceQuick({this.avgPercent = 0, this.leaveToday = 0});
}
