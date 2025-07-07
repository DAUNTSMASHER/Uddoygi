import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/profile.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    return Drawer(
      backgroundColor: Colors.grey[100],
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Error loading profile'));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data()!;
          final name = (data['fullName'] as String?)?.trim().isNotEmpty == true
              ? data['fullName'] as String
              : (data['name'] as String?) ?? 'User';
          final photoUrl = (data['profilePhotoUrl'] as String?) ?? '';

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 180,
                color: _darkBlue,
                padding:
                const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                        name.isNotEmpty ? name[0] : '?',
                        style: const TextStyle(
                            fontSize: 36, color: Colors.white),
                      )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 20),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfilePage(userId: uid),
                                ),
                              );
                            },
                            child: const Text(
                              'View Profile',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilePage(userId: uid),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              _drawerItem(
                  context, 'Dashboard', Icons.dashboard, '/admin/dashboard'),
              _drawerHeading('Notices'),
              _drawerItem(context, 'All Notices', Icons.list_alt,
                  '/admin/notices/all'),
              _drawerItem(
                  context, 'Publish Notice', Icons.add_alert, '/admin/notices'),
              _drawerHeading('Employees'),
              _drawerItem(context, 'Employee Directory', Icons.people,
                  '/admin/employees'),
              _drawerHeading('Reports'),
              _drawerItem(context, 'Generate Reports', Icons.bar_chart,
                  '/admin/reports'),
              _drawerHeading('Welfare'),
              _drawerItem(context, 'Welfare Scheme', Icons.favorite,
                  '/common/welfare'),
              _drawerHeading('Complaints'),
              _drawerItem(context, 'Complaints', Icons.report_problem,
                  '/common/complaints'),
              _drawerHeading('Finance'),
              _drawerItem(context, 'Salary Management', Icons.attach_money,
                  '/admin/salary'),
              _drawerHeading('Communication'),
              _drawerItem(context, 'Messages', Icons.message, '/common/messages'),
              const Divider(),
              ListTile(
                dense: true,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
                onTap: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _drawerHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: _darkBlue,
        ),
      ),
    );
  }

  Widget _drawerItem(
      BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: _darkBlue, size: 18),
      title: Text(title, style: const TextStyle(fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }
}
