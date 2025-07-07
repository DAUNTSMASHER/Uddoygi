import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class FactoryDrawer extends StatefulWidget {
  const FactoryDrawer({Key? key}) : super(key: key);

  @override
  State<FactoryDrawer> createState() => _FactoryDrawerState();
}

class _FactoryDrawerState extends State<FactoryDrawer> {
  String? _uid;
  String _name = 'User';
  String _email = '';
  String _photoUrl = '';

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _loadSession();
    if (_uid != null) _listenProfile();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    setState(() {
      _email = session?['email'] as String? ?? '';
    });
  }

  void _listenProfile() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data != null) {
        setState(() {
          _name = (data['fullName'] as String?)?.trim().isNotEmpty == true
              ? data['fullName']!
              : (data['name'] as String?) ?? _name;
          _photoUrl = (data['profilePhotoUrl'] as String?) ?? '';
          _email = (data['personalEmail'] as String?) ?? _email;
        });
      }
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Custom header
          Container(
            height: 180,
            color: _darkBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  backgroundImage:
                  _photoUrl.isNotEmpty ? NetworkImage(_photoUrl) : null,
                  child: _photoUrl.isEmpty
                      ? Text(_name.isNotEmpty ? _name[0] : '?',
                      style: const TextStyle(fontSize: 36, color: _darkBlue))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
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
                              builder: (_) => ProfilePage(userId: _uid!),
                            ),
                          );
                        },
                        child: const Text('View Profile',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon:
                  const Icon(Icons.chevron_right, size: 28, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(userId: _uid!),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Menu items
          _tile(context, Icons.dashboard, 'Dashboard', '/factory/dashboard'),
          _tile(context, Icons.notifications_active, 'Notices', '/factory/notices'),
          _tile(context, Icons.volunteer_activism, 'Welfare', '/common/welfare'),
          _tile(context, Icons.message, 'Messages', '/common/messages'),
          _tile(context, Icons.work, 'Work Orders', '/factory/work_orders'),
          _tile(context, Icons.request_page, 'Resource Requests',
              '/factory/resource_requests'),
          _tile(context, Icons.update, 'Progress Update',
              '/factory/progress_update'),
          _tile(
              context, Icons.event_available, 'Attendance', '/factory/attendance'),
          _tile(context, Icons.request_page, 'Loan Requests',
              '/factory/loan_requests'),
          _tile(context, Icons.money_off, 'Salary & Overtime',
              '/factory/salary_overtime'),

          const Spacer(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: _darkBlue),
            title:
            const Text('Logout', style: TextStyle(color: _darkBlue)),
            onTap: _logout,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, color: _darkBlue),
      title: Text(label, style: const TextStyle(color: _darkBlue)),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, route);
      },
    );
  }
}
