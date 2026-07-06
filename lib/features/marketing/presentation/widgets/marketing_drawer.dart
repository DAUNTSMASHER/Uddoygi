import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/profile.dart';
import 'package:uddoygi/theme/app_fonts.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class MarketingDrawer extends StatefulWidget {
  const MarketingDrawer({super.key});

  @override
  State<MarketingDrawer> createState() => _MarketingDrawerState();
}

class _MarketingDrawerState extends State<MarketingDrawer> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? '';

    return Drawer(
      backgroundColor: Colors.white,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.users).doc(currentUid).snapshots(),
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
                        style: AppFonts.englishSystem(
                            fontSize: 36, color: _darkBlue, fontWeight: FontWeight.bold),
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
                            style: AppFonts.banglaHeading(
                              color: Colors.white,
                              fontSize: 18, // larger text
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
                            child: Text(
                              'প্রোফাইল দেখুন',
                              style: AppFonts.banglaBody(
                                color: Colors.white70,
                                fontSize: 13,
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
              _drawerItem(context, 'ড্যাশবোর্ড (Dashboard)', Icons.dashboard_outlined,
                  '/marketing/dashboard'),
              _drawerItem(context, 'ক্লায়েন্ট তালিকা (Clients)', Icons.people_alt_outlined,
                  '/marketing/clients'),
              _drawerItem(context, 'বিক্রয় ও ইনভয়েস (Sales)',
                  Icons.receipt_long_outlined, '/marketing/sales'),
              _drawerItem(context, 'ইনভয়েস তালিকা (All Invoices)',
                  Icons.receipt_outlined, '/marketing/sales/all'),
              _drawerItem(context, 'নতুন ইনভয়েস (New Invoice)',
                  Icons.add_circle_outline_rounded, '/marketing/sales/new'),
              _drawerItem(context, 'টাস্ক ও দায়িত্ব (Tasks)', Icons.task_outlined,
                  '/marketing/task_assignment'),
              _drawerItem(context, 'ক্যাম্পেইন (Campaigns)', Icons.campaign_outlined,
                  '/marketing/campaign'),
              _drawerItem(context, 'অর্ডারসমূহ (Orders)', Icons.shopping_bag_outlined,
                  '/marketing/orders'),
              _drawerItem(context, 'ঋণ আবেদন (Loans)',
                  Icons.request_page_outlined, '/marketing/loan_request'),
              const Divider(),
              _drawerItem(context, 'বেতন ও পে-স্লিপ (Salary)',
                  Icons.payments_outlined, '/common/salary'),
              _drawerItem(context, 'ইনসেনটিভ (Incentives)',
                  Icons.star_outline_rounded, '/marketing/renumeration'),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text('লগআউট (Logout)',
                    style: AppFonts.banglaBody(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                onTap: () async {
                  Navigator.pop(context);
                  await LocalStorageService.performLogout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
      title: Text(title, style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, route);
      },
    );
  }
}
