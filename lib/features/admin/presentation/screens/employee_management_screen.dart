import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:uddoygi/features/employee_management/add_employee_page.dart';
import 'package:uddoygi/features/employee_management/all_employees_page.dart';
import 'package:uddoygi/features/employee_management/hr_recommendations_page.dart';
import 'package:uddoygi/features/employee_management/transitions_page.dart';

class EmployeeManagementScreen extends StatelessWidget {
  const EmployeeManagementScreen({super.key});

  static const Color _darkBlue = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    final cards = [
      _DashboardCard(
        title: 'Add Employee',
        icon: Icons.person_add,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEmployeePage()),
        ),
      ),
      _DashboardCard(
        title: 'All Employees',
        icon: Icons.group,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllEmployeesPage()),
        ),
      ),
      _DashboardCard(
        title: 'Recommendations',
        icon: Icons.thumb_up,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HRRecommendationsPage()),
        ),
      ),
      _DashboardCard(
        title: 'Promotions',
        icon: Icons.swap_vert,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransitionsPage()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Employee Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: _darkBlue,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SummaryBar(), // 🔹 New live summary
          const SizedBox(height: 16),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.05,
            children: cards,
          ),
        ],
      ),
    );
  }
}

/* ======================== SUMMARY BAR ======================== */

class _SummaryBar extends StatelessWidget {
  const _SummaryBar();

  static const Color _darkBlue = Color(0xFF0D47A1);

  Future<_AttendanceQuick> _attendanceQuick() async {
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

      // Monthly average (present + late) / total
      if (parts[0] == y && parts[1] == m) {
        if (status == 'present') present++;
        if (status == 'late') late++;
        total++;
      }

      // Today’s leave count
      if (parts[0] == y && parts[1] == m && parts[2] == d) {
        if (status == 'leave') leaveToday++;
      }
    }

    final avg = total > 0 ? ((present + late) / total) * 100 : 0.0;
    return _AttendanceQuick(avgPercent: avg, leaveToday: leaveToday);
  }

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (ctx, usersSnap) {
        if (!usersSnap.hasData) {
          return const SizedBox(
            height: 118,
            child: Center(child: CircularProgressIndicator(color: _darkBlue)),
          );
        }

        final users = usersSnap.data!.docs;

        // Totals
        final totalEmployees = users.length;

        // New this month
        int newThisMonth = 0;
        final Map<String, int> deptCounts = {'hr': 0, 'marketing': 0, 'factory': 0, 'admin': 0};
        for (final u in users) {
          final data = u.data();
          final dep = (data['department'] as String?)?.toLowerCase() ?? '';
          if (deptCounts.containsKey(dep)) deptCounts[dep] = (deptCounts[dep] ?? 0) + 1;

          final createdAt = data['createdAt'];
          DateTime? created;
          if (createdAt is Timestamp) created = createdAt.toDate();
          if (createdAt is DateTime) created = createdAt;
          if (created != null && created.isAfter(monthStart)) newThisMonth++;
        }

        return FutureBuilder<_AttendanceQuick>(
          future: _attendanceQuick(),
          builder: (ctx, attSnap) {
            final attendance = attSnap.data ?? const _AttendanceQuick();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horizontal stat cards
                SizedBox(
                  height: 108,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _StatCard(
                        title: 'Total Employees',
                        value: '$totalEmployees',
                        icon: Icons.badge,
                        color: _darkBlue,
                      ),
                      _StatCard(
                        title: 'New This Month',
                        value: '$newThisMonth',
                        icon: Icons.fiber_new,
                        color: Colors.indigo,
                      ),
                      _StatCard(
                        title: 'Avg Attendance',
                        value: '${attendance.avgPercent.toStringAsFixed(1)}%',
                        icon: Icons.insights,
                        color: Colors.green,
                      ),
                      _StatCard(
                        title: 'On Leave Today',
                        value: '${attendance.leaveToday}',
                        icon: Icons.beach_access,
                        color: Colors.orange,
                      ),
                    ].map((w) => Padding(padding: const EdgeInsets.only(right: 12), child: w)).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Quick department chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DeptChip(label: 'HR & Accounts', count: deptCounts['hr'] ?? 0),
                    _DeptChip(label: 'Marketing', count: deptCounts['marketing'] ?? 0),
                    _DeptChip(label: 'Factory', count: deptCounts['factory'] ?? 0),
                    _DeptChip(label: 'Admin', count: deptCounts['admin'] ?? 0),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AttendanceQuick {
  final double avgPercent;
  final int leaveToday;
  const _AttendanceQuick({this.avgPercent = 0, this.leaveToday = 0});
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeptChip extends StatelessWidget {
  final String label;
  final int count;
  const _DeptChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E6EF)),
      ),
      child: Text('$label • $count',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
    );
  }
}

/* ======================== DASH CARDS ======================== */

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  static const Color _darkBlue = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: _darkBlue.withOpacity(.22), width: 1.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _darkBlue.withOpacity(.08),
                child: Icon(icon, size: 28, color: _darkBlue),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _darkBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
