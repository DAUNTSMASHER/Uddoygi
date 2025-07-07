import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/profile.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class MarketingDrawer extends StatelessWidget {
  const MarketingDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? '';

    return Drawer(
      backgroundColor: Colors.white,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .snapshots(),
        builder: (ctx, snap) {
          String name = 'User';
          String photoUrl = '';

          if (snap.hasData && snap.data!.exists) {
            final data = snap.data!.data()!;
            name = (data['fullName'] as String?)?.trim().isNotEmpty == true
                ? data['fullName']!
                : (data['name'] as String?) ?? name;
            photoUrl = (data['profilePhotoUrl'] as String?) ?? '';
          }

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 180, // increased height
                color: _darkBlue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36, // larger avatar
                      backgroundColor: Colors.white,
                      backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                        name.isNotEmpty ? name[0] : '?',
                        style: const TextStyle(
                            fontSize: 36, color: _darkBlue),
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
                              fontSize: 20, // larger text
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                                  builder: (_) =>
                                      ProfilePage(userId: currentUid),
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
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProfilePage(userId: currentUid),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              _drawerItem(context, 'Dashboard', Icons.dashboard_outlined,
                  '/marketing/dashboard'),
              _drawerItem(context, 'Clients', Icons.people_alt_outlined,
                  '/marketing/clients'),
              _drawerItem(context, 'Sales & Invoices',
                  Icons.receipt_long_outlined, '/marketing/sales'),
              _drawerItem(context, 'Task Assignment', Icons.task_outlined,
                  '/marketing/task_assignment'),
              _drawerItem(context, 'Campaigns', Icons.campaign_outlined,
                  '/marketing/campaign'),
              _drawerItem(context, 'Orders', Icons.shopping_bag_outlined,
                  '/marketing/orders'),
              _drawerItem(context, 'Loan Requests',
                  Icons.request_page_outlined, '/marketing/loan_request'),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _drawerItem(BuildContext context, String title, IconData icon,
      String route) {
    return ListTile(
      leading: Icon(icon, color: _darkBlue),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, route);
      },
    );
  }
}
