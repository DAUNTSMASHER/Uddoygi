import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'employee_details_page.dart';

const Color _darkBlue = Color(0xFF0D47A1);

/// Displays tabs for each department and shows filtered employee lists
class AllEmployeesPage extends StatelessWidget {
  const AllEmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: _darkBlue,
          elevation: 0,
          title: const Text(
            'Employees',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'HR & Accounts'),
              Tab(text: 'Marketing'),
              Tab(text: 'Factory'),
              Tab(text: 'Admin'),
              Tab(text: 'All'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            EmployeeList(department: 'hr'),
            EmployeeList(department: 'marketing'),
            EmployeeList(department: 'factory'),
            EmployeeList(department: 'admin'),
            EmployeeList(department: null),
          ],
        ),
      ),
    );
  }
}

/// Streams and displays a list of employees, filtered by [department] if provided.
class EmployeeList extends StatelessWidget {
  final String? department;
  const EmployeeList({super.key, this.department});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .orderBy('fullName'); // nicer mobile sort

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

            final name       = (m['fullName'] as String?)?.trim().isNotEmpty == true
                ? m['fullName'] as String
                : 'Unknown';
            final deptRaw    = (m['department'] as String?) ?? '';
            final deptLabel  = deptRaw.isEmpty ? '—' : deptRaw[0].toUpperCase() + deptRaw.substring(1);
            final email      = (m['officeEmail'] as String?) ?? '';
            final employeeId = (m['employeeId'] as String?) ?? d.id;
            final photoUrl   = (m['profilePhotoUrl'] as String?) ?? '';

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
                    // Avatar
                    Hero(
                      tag: 'emp-avatar-$employeeId',
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: _darkBlue,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Text(
                          _initials(name),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Texts
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
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black26),
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
