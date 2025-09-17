import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'employee_details_page.dart';

const Color _darkBlue = Color(0xFF3C0765);
const Color _tileTint = Color(0xFFEEF4FF);

/// Displays department tiles (1 per row). Each tile shows a live count and opens a list.
class AllEmployeesPage extends StatelessWidget {
  const AllEmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_Dept>[
      const _Dept(label: 'HR & Accounts', keyValue: 'hr', icon: Icons.groups_2),
      const _Dept(label: 'Marketing',     keyValue: 'marketing', icon: Icons.campaign),
      const _Dept(label: 'Factory',       keyValue: 'factory', icon: Icons.factory),
      const _Dept(label: 'Admin',         keyValue: 'admin', icon: Icons.admin_panel_settings),
      const _Dept(label: 'All',           keyValue: null, icon: Icons.all_inclusive),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFC18FEA),
      appBar: AppBar(
        backgroundColor: _darkBlue,
        elevation: 0,
        title: const Text(
          'Employees',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          // Single-column list of tiles (no overflow)
          Column(
            children: [
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DeptTile(dept: it),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Inline "All" list below tiles (keep/remove as you prefer)
          const _SectionTitle('All employees'),
          const SizedBox(height: 6),
          const EmployeeList(department: null),
        ],
      ),
    );
  }
}

/* ------------------------ Department Tile ------------------------ */

class _Dept {
  final String label;
  final String? keyValue; // 'hr' | 'marketing' | 'factory' | 'admin' | null => all
  final IconData icon;
  const _Dept({required this.label, required this.keyValue, required this.icon});
}

class _DeptTile extends StatelessWidget {
  final _Dept dept;
  const _DeptTile({required this.dept});

  Query<Map<String, dynamic>> _query() {
    final base = FirebaseFirestore.instance.collection('users');
    if (dept.keyValue == null) return base;
    return base.where('department', isEqualTo: dept.keyValue);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _query().snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : null;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openList(context, count: count),
          child: Ink(
            decoration: BoxDecoration(
              color: _tileTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _darkBlue.withOpacity(.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min, // let height adapt; prevents overflow
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _darkBlue.withOpacity(.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(dept.icon, color: _darkBlue, size: 28), // bigger icon
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _darkBlue.withOpacity(.15)),
                        ),
                        child: Text(
                          count == null ? '—' : count.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16, // bigger count
                            color: _darkBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dept.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20, // bigger title
                      color: _darkBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dept.keyValue == null ? 'All employees' : 'Tap to view',
                    style: const TextStyle(fontSize: 14, color: Colors.black54), // bigger subtitle
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openList(BuildContext context, {int? count}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        final height = MediaQuery.of(context).size.height * .86;
        return SizedBox(
          height: height,
          child: Column(
            children: [
              // drag handle + header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 4,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        dept.label,
                        style: const TextStyle(
                          color: _darkBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (count != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _darkBlue.withOpacity(.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: _darkBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: EmployeeList(department: dept.keyValue)),
            ],
          ),
        );
      },
    );
  }
}

/* ------------------------ List (reused) ------------------------ */

/// Streams and displays a list of employees, filtered by [department] if provided.
class EmployeeList extends StatelessWidget {
  final String? department;
  const EmployeeList({super.key, this.department});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .orderBy('fullName'); // stable UX sort

    if (department != null && department!.isNotEmpty) {
      query = query.where('department', isEqualTo: department);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return const _CenteredMessage('Error loading employees');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _darkBlue));
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _CenteredMessage('No employees found');
        }

        return ListView.separated(
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x11000000)),
          itemBuilder: (ctx, i) {
            final d = docs[i];
            final m = d.data();

            final name = (m['fullName'] as String?)?.trim().isNotEmpty == true
                ? m['fullName'] as String
                : 'Unknown';
            final deptRaw = (m['department'] as String?) ?? '';
            final deptLabel = deptRaw.isEmpty
                ? '—'
                : deptRaw[0].toUpperCase() + deptRaw.substring(1);
            final email = (m['officeEmail'] as String?) ?? (m['email'] as String? ?? '');
            final employeeId = (m['employeeId'] as String?) ?? d.id;
            final photoUrl = (m['profilePhotoUrl'] as String?) ?? '';

            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeeDetailsPage(
                    uid: d.id,
                    userEmail: email,
                    employeeId: employeeId,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Hero(
                      tag: 'emp-avatar-$employeeId',
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: _darkBlue,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Text(
                          _initials(name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _Chip(text: deptLabel),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'ID: $employeeId',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white, // kept from your version
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white), // kept from your version
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/* ------------------------ tiny helpers ------------------------ */

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _darkBlue,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _darkBlue.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _darkBlue.withOpacity(.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _darkBlue,
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final String text;
  const _CenteredMessage(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(color: _darkBlue, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
