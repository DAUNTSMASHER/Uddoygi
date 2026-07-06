import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/theme/app_fonts.dart';

const Color _primary = Color(0xFF8B0000);
const LinearGradient _primaryGradient = LinearGradient(colors: [_primary, Color(0xFF5A0000)], begin: Alignment.topLeft, end: Alignment.bottomRight);

class FactoryDrawer extends StatefulWidget {
  const FactoryDrawer({Key? key}) : super(key: key);

  @override
  State<FactoryDrawer> createState() => _FactoryDrawerState();
}

class _FactoryDrawerState extends State<FactoryDrawer> {
  String _cid = '';
  String? _uid;
  String _name = 'User';
  String _email = '';
  String _photoUrl = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
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
    DB.colSync(_cid, C.users)
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
    await LocalStorageService.performLogout();
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
            height: 120,
            decoration: const BoxDecoration(gradient: _primaryGradient),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  backgroundImage:
                  _photoUrl.isNotEmpty ? NetworkImage(_photoUrl) : null,
                  child: _photoUrl.isEmpty
                      ? Text(_name.isNotEmpty ? _name[0] : '?',
                      style: AppFonts.englishSystem(fontSize: 18, color: _primary, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name, style: AppFonts.banglaHeading(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 16),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: _uid!)));
                        },
                        child: Text('প্রোফাইল দেখুন', style: AppFonts.banglaBody(color: Colors.white70, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: _uid!)));
                  },
                ),
              ],
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _sectionHeader('সাধারণ (General)'),
                _tile(context, Icons.dashboard_rounded, 'ড্যাশবোর্ড (Dashboard)', '/factory/dashboard'),
                _tile(context, Icons.notifications_active_rounded, 'নোটিশ (Notices)', '/factory/notices'),
                _tile(context, Icons.message_rounded, 'বার্তা (Messages)', '/common/messages'),
                
                _sectionHeader('উৎপাদন (Production)'),
                _tile(context, Icons.assignment_rounded, 'ওয়ার্ক অর্ডার (Work Orders)', '/factory/work_orders'),
                _tile(context, Icons.update_rounded, 'কাজের অগ্রগতি (Progress)', '/factory/progress_update'),
                _tile(context, Icons.request_page_rounded, 'মালামাল অনুরোধ (Resources)', '/factory/resource_requests'),
                
                _sectionHeader('এইচআর ও অর্থ (HR & Finance)'),
                _tile(context, Icons.event_available_rounded, 'উপস্থিতি (Attendance)', '/factory/attendance'),
                _tile(context, Icons.payments_rounded, 'বেতন ও ওভারটাইম (Salary)', '/factory/salary_overtime'),
                _tile(context, Icons.account_balance_wallet_rounded, 'ঋণ আবেদন (Loans)', '/factory/loan_requests'),
                _tile(context, Icons.volunteer_activism_rounded, 'কল্যাণ তহবিল (Welfare)', '/common/welfare'),
              ],
            ),
          ),

          // Logout
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.logout_rounded, color: _primary, size: 16),
            title: Text('লগআউট (Logout)', style: AppFonts.banglaBody(color: _primary, fontSize: 13, fontWeight: FontWeight.bold)),
            onTap: _logout,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 16, bottom: 4),
      child: Text(
        title,
        style: AppFonts.banglaHeading(
          color: Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: Icon(icon, color: _primary, size: 16),
      title: Text(label, style: AppFonts.banglaBody(color: _primary, fontSize: 13, fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, route);
      },
    );
  }
}
