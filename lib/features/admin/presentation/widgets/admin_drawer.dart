// lib/features/marketing/presentation/widgets/admin_drawer.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uddoygi/profile.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class AdminDrawer extends StatefulWidget {
  const AdminDrawer({Key? key}) : super(key: key);

  @override
  State<AdminDrawer> createState() => _AdminDrawerState();
}

class _DrawerItemCfg {
  final String keyId; // for lastSeen
  final String title;
  final IconData icon;
  final String route;
  final List<Query<Map<String, dynamic>>> sources; // collections to watch
  const _DrawerItemCfg(this.keyId, this.title, this.icon, this.route, this.sources);
}

class _AdminDrawerState extends State<AdminDrawer> {
  final user = FirebaseAuth.instance.currentUser;
  late final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  late final List<_DrawerItemCfg> _items = [
    _DrawerItemCfg('dashboard', 'Dashboard', Icons.dashboard, '/admin/dashboard', const []),

    _DrawerItemCfg('notices', 'All Notices', Icons.list_alt, '/admin/notices/all',
        [FirebaseFirestore.instance.collection('notices')]),
    _DrawerItemCfg('notice_publish', 'Publish Notice', Icons.add_alert, '/admin/notices',
        [FirebaseFirestore.instance.collection('notices')]),

    _DrawerItemCfg('employees', 'Employee Directory', Icons.people, '/admin/employees',
        [FirebaseFirestore.instance.collection('users')]),

    _DrawerItemCfg('reports', 'Generate Reports', Icons.bar_chart, '/admin/reports',
        [FirebaseFirestore.instance.collection('invoices'),
          FirebaseFirestore.instance.collection('expenses')]),

    _DrawerItemCfg('welfare', 'Welfare Scheme', Icons.favorite, '/common/welfare',
        [FirebaseFirestore.instance.collection('welfare')]),

    _DrawerItemCfg('complaints', 'Complaints', Icons.report_problem, '/common/complaints',
        [FirebaseFirestore.instance.collection('complaints')]),

    _DrawerItemCfg('salary', 'Salary Management', Icons.attach_money, '/admin/salary',
        [FirebaseFirestore.instance.collection('salaries')]),

    _DrawerItemCfg('messages', 'Messages', Icons.message, '/common/messages',
        [FirebaseFirestore.instance.collection('messages')]),
  ];

  Future<void> _markSectionSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSeen_$key', DateTime.now().millisecondsSinceEpoch);
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.grey[50],
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid.isEmpty
            ? null
            : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          final hasData = snap.hasData && snap.data!.exists;
          final data = hasData ? (snap.data!.data() ?? <String, dynamic>{}) : <String, dynamic>{};
          final name = (data['fullName'] as String?)?.trim().isNotEmpty == true
              ? data['fullName'] as String
              : (user?.displayName ?? user?.email ?? 'User');
          final photoUrl = (data['profilePhotoUrl'] as String?) ?? '';

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // HEADER
              Container(
                height: 190,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo, _darkBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 40, 8, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white24,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                        _initialsFor(name),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _HeaderPill(
                                icon: Icons.person,
                                label: 'View Profile',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ProfilePage(userId: uid)),
                                  );
                                },
                              ),

                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // MENU SECTIONS
              _SectionTitle('GENERAL'),
              _DrawerTile(
                cfg: _items.firstWhere((e) => e.keyId == 'dashboard'),
                onTap: () async {
                  await _markSectionSeen('dashboard');
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin/dashboard');
                },
              ),

              _SectionTitle('NOTICES'),
              _DrawerTile(
                cfg: _items.firstWhere((e) => e.keyId == 'notices'),
                onTap: () async {
                  await _markSectionSeen('notices');
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin/notices/all');
                },
              ),
              _DrawerTile(
                cfg: _items.firstWhere((e) => e.keyId == 'notice_publish'),
                onTap: () async {
                  await _markSectionSeen('notice_publish');
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin/notices');
                },
              ),

              _SectionTitle('EMPLOYEES'),
              _DrawerTile(
                cfg: _items.firstWhere((e) => e.keyId == 'employees'),
                onTap: () async {
                  await _markSectionSeen('employees');
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin/employees');
                },
              ),

              _SectionTitle('REPORTS'),
              _DrawerTile(
                cfg: _items.firstWhere((e) => e.keyId == 'reports'),
                onTap: () async {
                  await _markSectionSeen('reports');
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin/reports');
                },
              ),

              _SectionTitle('WELFARE & COMPLAINTS'),
              _DrawerTile(
                cfg: _items.firstWhere((e) => e.keyId == 'welfare'),
                onTap: () async {
                  await _markSectionSeen('welfare');
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/common/welfare');
                },
              ),
              _DrawerTile(
                cfg: _items.firstWhere((e) => e.keyId == 'complaints'),
                onTap: () async {
                  await _markSectionSeen('complaints');
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/common/complaints');
                },
              ),

              _SectionTitle('FINANCE & COMMS'),
              _DrawerTile(
                cfg: _items.firstWhere((e) => e.keyId == 'salary'),
                onTap: () async {
                  await _markSectionSeen('salary');
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin/salary');
                },
              ),
              _DrawerTile(
                cfg: _items.firstWhere((e) => e.keyId == 'messages'),
                onTap: () async {
                  await _markSectionSeen('messages');
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/common/messages');
                },
              ),

              const Divider(height: 24),
              ListTile(
                dense: true,
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

/* -------------------- Header pill button -------------------- */
class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HeaderPill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------- Section title -------------------- */
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w900,
          color: _darkBlue,
        ),
      ),
    );
  }
}

/* -------------------- Drawer tile with live badge -------------------- */
class _DrawerTile extends StatelessWidget {
  final _DrawerItemCfg cfg;
  final VoidCallback onTap;
  const _DrawerTile({required this.cfg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: _darkBlue.withOpacity(0.08), shape: BoxShape.circle),
        child: Icon(cfg.icon, color: _darkBlue, size: 16),
      ),
      title: Text(
        cfg.title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cfg.sources.isNotEmpty) _BadgeCounter(keyId: cfg.keyId, sources: cfg.sources),
          const Icon(Icons.chevron_right, color: Colors.black38, size: 18),
        ],
      ),
      onTap: onTap,
    );
  }
}

/* -------------------- Badge counter (createdAt > lastSeen_keyId) -------------------- */
class _BadgeCounter extends StatefulWidget {
  final String keyId;
  final List<Query<Map<String, dynamic>>> sources;
  const _BadgeCounter({required this.keyId, required this.sources});

  @override
  State<_BadgeCounter> createState() => _BadgeCounterState();
}

class _BadgeCounterState extends State<_BadgeCounter> {
  int _count = 0;
  final Map<int, int> _perStream = {};
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs = [];

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant _BadgeCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _detach();
    _attach();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  Future<void> _attach() async {
    final lastSeen = await _getLastSeen(widget.keyId);
    _perStream.clear();
    for (final q in widget.sources) {
      final sub = q
          .where('createdAt', isGreaterThan: Timestamp.fromDate(lastSeen)) // make sure you write createdAt
          .snapshots()
          .listen((snap) {
        _perStream[q.hashCode] = snap.docs.length;
        final total = _perStream.values.fold<int>(0, (s, n) => s + n);
        if (mounted) setState(() => _count = total);
      });
      _subs.add(sub);
    }
  }

  void _detach() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  Future<DateTime> _getLastSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('lastSeen_$key');
    if (ms == null) {
      final seed = DateTime.now().subtract(const Duration(days: 1));
      await prefs.setInt('lastSeen_$key', seed.millisecondsSinceEpoch);
      return seed;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Widget build(BuildContext context) {
    if (_count <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _count > 99 ? '99+' : '$_count',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
