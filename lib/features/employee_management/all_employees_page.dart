import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'employee_details_page.dart';

const Color _darkBlue = Color(0xFF0D47A1);

/// Displays tabs for each department and shows filtered employee lists
class AllEmployeesPage extends StatelessWidget {
  const AllEmployeesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Employees',
            style: TextStyle(
              fontFamily: 'Times New Roman',
              color: Colors.white,
            ),
          ),
          backgroundColor: _darkBlue,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
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
  const EmployeeList({Key? key, this.department}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true);

    if (department != null && department!.isNotEmpty) {
      query = query.where('department', isEqualTo: department);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text('Error loading employees', style: TextStyle(color: _darkBlue)),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _darkBlue));
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('No employees found', style: TextStyle(color: _darkBlue)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data       = doc.data();
            final name       = data['fullName']        as String? ?? 'Unknown';
            final dept       = (data['department']      as String? ?? '').toUpperCase();
            final profileUrl = data['profilePhotoUrl'] as String? ?? '';
            final email      = data['officeEmail']     as String? ?? '';
            final employeeId = data['employeeId']      as String? ?? doc.id;

            // Derive initials if no picture
            final initials = name
                .split(' ')
                .where((s) => s.isNotEmpty)
                .map((s) => s[0])
                .take(2)
                .join();

            return Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: _darkBlue, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmployeeDetailsPage(
                      uid: doc.id,
                      userEmail: email,
                      employeeId: employeeId,
                    ),
                  ),
                ),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: _darkBlue,
                  backgroundImage:
                  profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  child: profileUrl.isEmpty
                      ? Text(initials, style: const TextStyle(color: Colors.white))
                      : null,
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _darkBlue,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dept,
                      style: const TextStyle(color: _darkBlue),
                    ),
                    Text(
                      'ID: $employeeId',
                      style: const TextStyle(fontSize: 12, color: _darkBlue),
                    ),
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
