import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:uddoygi/features/employee_management/add_employee_page.dart';
import 'package:uddoygi/features/employee_management/all_employees_page.dart';
import 'package:uddoygi/features/employee_management/hr_recommendations_page.dart';
import 'package:uddoygi/features/employee_management/transitions_page.dart';

class EmployeeManagementScreen extends StatelessWidget {
  const EmployeeManagementScreen({super.key});

  static const Color _deepPurple = Color(0xFF5B0A98);
  static const Color _accentPurple = Color(0xFF6911AC);
  static const Color _ink = Color(0xFF1B1B1F);

  @override
  Widget build(BuildContext context) {
    final navCards = [
      _DashboardCard(
        title: 'Add Employee',
        icon: Icons.person_add,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEmployeePage())),
      ),
      _DashboardCard(
        title: 'All Employees',
        icon: Icons.group,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllEmployeesPage())),
      ),
      _DashboardCard(
        title: 'Recommendations',
        icon: Icons.thumb_up,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HRRecommendationsPage())),
      ),
      _DashboardCard(
        title: 'Promotions',
        icon: Icons.swap_vert,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransitionsPage())),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: _deepPurple,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF7F8FB),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final cross = _gridCount(w);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (ctx, usersSnap) {
              final waiting = usersSnap.connectionState == ConnectionState.waiting;
              final users = usersSnap.data?.docs ?? [];

              final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
              final totalEmployees = users.length;
              int newThisMonth = 0;

              final Map<String, int> dept = {
                'hr': 0,
                'accounts': 0,
                'marketing': 0,
                'factory': 0,
                'admin': 0,
                'others': 0,
              };

              for (final u in users) {
                final data = u.data();
                final raw = (data['department'] as String?)?.trim().toLowerCase() ?? '';
                final dep = _normalizeDept(raw);
                if (!dept.containsKey(dep)) {
                  dept['others'] = (dept['others'] ?? 0) + 1;
                } else {
                  dept[dep] = (dept[dep] ?? 0) + 1;
                }

                final createdAt = data['createdAt'];
                DateTime? created;
                if (createdAt is Timestamp) created = createdAt.toDate();
                if (createdAt is DateTime) created = createdAt;
                if (created != null && created.isAfter(monthStart)) newThisMonth++;
              }

              final hrAndAccounts = (dept['hr'] ?? 0) + (dept['accounts'] ?? 0);

              return FutureBuilder<_AttendanceQuick>(
                future: _attendanceQuick(),
                builder: (ctx, attSnap) {
                  final attendance = attSnap.data ?? const _AttendanceQuick();

                  final statTiles = [
                    _StatTileData(title: 'Total Employees', value: '$totalEmployees', icon: Icons.badge, color: _deepPurple),
                    _StatTileData(title: 'New This Month', value: '$newThisMonth', icon: Icons.fiber_new, color: _accentPurple),
                    _StatTileData(title: 'Avg Attendance', value: '${attendance.avgPercent.toStringAsFixed(1)}%', icon: Icons.insights, color: Colors.green.shade700),
                    _StatTileData(title: 'On Leave Today', value: '${attendance.leaveToday}', icon: Icons.beach_access, color: Colors.orange.shade800),
                  ];

                  final deptTiles = <_DeptTileData>[
                    _DeptTileData(label: 'HR & Accounts', count: hrAndAccounts, icon: Icons.account_balance),
                    _DeptTileData(label: 'Marketing', count: dept['marketing'] ?? 0, icon: Icons.campaign),
                    _DeptTileData(label: 'Factory', count: dept['factory'] ?? 0, icon: Icons.precision_manufacturing),
                    _DeptTileData(label: 'Admin', count: dept['admin'] ?? 0, icon: Icons.admin_panel_settings),
                    if ((dept['others'] ?? 0) > 0) _DeptTileData(label: 'Others', count: dept['others']!, icon: Icons.grid_view),
                  ];

                  // Responsive fixed heights → no overflow
                  final statHeight = _gridItemHeight(w, cross, factor: 0.46, minH: 76, maxH: 100);
                  final deptHeight = _gridItemHeight(w, cross, factor: 0.44, minH: 72, maxH: 96);
                  final navHeight  = _gridItemHeight(w, cross, factor: 0.95, minH: 110, maxH: 150);

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SectionFrame(
                        title: 'Overview',
                        gradientA: _deepPurple,
                        gradientB: _accentPurple,
                        // section body background now purple-tinted (not white)
                        bodyTint: const Color(0xFFF1E8FF),
                        child: waiting
                            ? const SizedBox(height: 128, child: Center(child: CircularProgressIndicator(color: _deepPurple)))
                            : GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: statTiles.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: statHeight,
                          ),
                          itemBuilder: (_, i) => _StatTile(data: statTiles[i]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionFrame(
                        title: 'Employees by Department',
                        gradientA: _accentPurple,
                        gradientB: _deepPurple,
                        bodyTint: const Color(0xFFF1E8FF),
                        child: waiting
                            ? const SizedBox(height: 96, child: Center(child: CircularProgressIndicator(color: _deepPurple)))
                            : GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: deptTiles.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: deptHeight,
                          ),
                          itemBuilder: (_, i) => _DeptTile(data: deptTiles[i]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionFrame(
                        title: 'Quick Actions',
                        gradientA: _deepPurple,
                        gradientB: _accentPurple,
                        bodyTint: const Color(0xFFF1E8FF),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: navCards.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: navHeight,
                          ),
                          itemBuilder: (_, i) => navCards[i],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static int _gridCount(double w) {
    if (w < 560) return 2;
    if (w < 960) return 3;
    return 4;
  }

  static double _gridItemHeight(double w, int cross, {required double factor, double minH = 72, double maxH = 120}) {
    // content width (ListView has 16+16 padding; tiles have 12 spacing)
    final contentW = math.max(0.0, w - 32);
    final colW = (contentW - (cross - 1) * 12) / cross;
    final h = colW * factor;
    return h.clamp(minH, maxH);
  }

  static String _normalizeDept(String raw) {
    if (raw.isEmpty) return 'others';
    if (raw.contains('hr')) return 'hr';
    if (raw.contains('account')) return 'accounts';
    if (raw.contains('market')) return 'marketing';
    if (raw.contains('factory') || raw.contains('production')) return 'factory';
    if (raw.contains('admin')) return 'admin';
    return raw;
  }

  static Future<_AttendanceQuick> _attendanceQuick() async {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');

    final recs = await FirebaseFirestore.instance.collectionGroup('records').get();

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
  }
}

/* ======================== SECTION FRAME (animated bg + PURPLE body) ======================== */

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({
    required this.title,
    required this.child,
    required this.gradientA,
    required this.gradientB,
    this.bodyTint = const Color(0xFFF1E8FF), // soft purple panel
  });

  final String title;
  final Widget child;
  final Color gradientA;
  final Color gradientB;
  final Color bodyTint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          _AnimatedPurpleBg(a: gradientA, b: gradientB),
          // Purple panel with header + content (no Positioned overlays)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              elevation: 0,
              color: bodyTint,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: gradientA.withOpacity(.25), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title pill (solid purple, white text)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: gradientA,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Section content (grids/list/etc.)
                    child,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedPurpleBg extends StatefulWidget {
  const _AnimatedPurpleBg({required this.a, required this.b});
  final Color a;
  final Color b;

  @override
  State<_AnimatedPurpleBg> createState() => _AnimatedPurpleBgState();
}

class _AnimatedPurpleBgState extends State<_AnimatedPurpleBg> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, __) {
        final begin = Alignment.topLeft;
        final end = Alignment.bottomRight;
        final a = Alignment.lerp(begin, end, _t.value)!;
        final b = Alignment.lerp(end, begin, _t.value)!;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: a, end: b, colors: [widget.a, widget.b]),
          ),
          foregroundDecoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.white24, Colors.transparent, Colors.white12], stops: [0.0, 0.55, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/* ======================== MODELS & TILES ======================== */

class _AttendanceQuick {
  final double avgPercent;
  final int leaveToday;
  const _AttendanceQuick({this.avgPercent = 0, this.leaveToday = 0});
}

class _StatTileData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTileData({required this.title, required this.value, required this.icon, required this.color});
}

class _StatTile extends StatelessWidget {
  const _StatTile({super.key, required this.data});
  final _StatTileData data;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      borderColor: data.color.withOpacity(.22),
      child: Row(
        children: [
          CircleAvatar(radius: 18, backgroundColor: data.color.withOpacity(.10), child: Icon(data.icon, color: data.color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: data.color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeptTileData {
  final String label;
  final int count;
  final IconData icon;
  const _DeptTileData({required this.label, required this.count, required this.icon});
}

class _DeptTile extends StatelessWidget {
  const _DeptTile({super.key, required this.data});
  final _DeptTileData data;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF3C0765);
    return _CardShell(
      child: Row(
        children: [
          CircleAvatar(radius: 18, backgroundColor: purple.withOpacity(.08), child: Icon(data.icon, color: purple)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${data.count}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({super.key, this.child, this.borderColor});
  final Widget? child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: (borderColor ?? const Color(0x22000000)), width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _DashboardCard({required this.title, required this.icon, required this.onTap});

  static const Color _darkBlue = Color(0xFF3C0765);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: _darkBlue.withOpacity(.22), width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 26, backgroundColor: _darkBlue.withOpacity(.08), child: Icon(icon, size: 26, color: _darkBlue)),
                const SizedBox(height: 10),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _darkBlue)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
