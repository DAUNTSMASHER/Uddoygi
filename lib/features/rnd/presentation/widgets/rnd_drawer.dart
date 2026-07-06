// lib/features/rnd/presentation/widgets/rnd_drawer.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uddoygi/profile.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/common/notification.dart';

// ── R&D Colour Palette ──────────────────────────────────────
const Color _rndPrimary = Color(0xFF5B21B6); // Deep Violet
const Color _rndDark    = Color(0xFF3B0764); // Royal Purple
const Color _rndMid     = Color(0xFF7C3AED); // Violet mid
const Color _rndSurface = Color(0xFFF8F7FF); // Light lavender-white
const Color _rndCard    = Color(0xFFEDE9FE); // Soft purple tint
const Color _rndAccent  = Color(0xFF2563EB); // Electric Blue
const Color _rndMagenta = Color(0xFFC026D3); // Vivid Magenta

class RndDrawer extends StatefulWidget {
  const RndDrawer({super.key});
  @override
  State<RndDrawer> createState() => _RndDrawerState();
}

class _RndDrawerState extends State<RndDrawer> {
  String _cid = '';
  String? uid, email, name, photoUrl;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadUser();
  }

  Future<void> _loadUser() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    setState(() {
      uid      = session?['uid']   as String? ?? current?.uid;
      email    = session?['email'] as String? ?? current?.email;
      name     = session?['name']  as String? ?? current?.displayName ?? current?.email ?? 'R&D';
      photoUrl = current?.photoURL;
    });
    if (uid != null) {
      try {
        final snap = await DB.colSync(_cid, C.users).doc(uid).get();
        if (snap.exists && mounted) {
          final d = snap.data()!;
          setState(() {
            final n = (d['fullName'] as String?)?.trim();
            if (n != null && n.isNotEmpty) name = n;
            final p = (d['profilePhotoUrl'] as String?)?.trim();
            if (p != null && p.isNotEmpty) photoUrl = p;
          });
        }
      } catch (_) {}
    }
  }

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'R';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = name ?? 'R&D Member';
    final initials    = _initials(displayName);

    return Drawer(
      child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_rndDark, _rndMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                    ? NetworkImage(photoUrl!) : null,
                child: (photoUrl == null || photoUrl!.isEmpty)
                    ? Text(initials, style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(height: 12),
              Text(displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  if (uid != null) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ProfilePage(userId: uid!)));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text('View Profile', style: TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Nav items ──
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              _section('GENERAL'),
              _tile(context, Icons.dashboard_rounded,      'Dashboard',       '/rnd/dashboard'),
              _tile(context, Icons.science_rounded,        'My Projects',     '/rnd/projects'),
              _tile(context, Icons.edit_note_rounded,      'Daily Updates',   '/rnd/updates'),
              _tile(context, Icons.flag_rounded,           'Milestones',      '/rnd/milestones'),

              _section('REQUESTS'),
              _tile(context, Icons.inbox_rounded,          'Project Inbox',   '/rnd/inbox'),

              _section('COMMUNICATION'),
              _tile(context, Icons.announcement_rounded,   'Notices',         '/rnd/notices'),
              _tile(context, Icons.message_rounded,        'Messages',        '/common/messages',
                  badgeQuery: DB.colSync(_cid, C.messages)
                      .where('to', isEqualTo: email ?? '')
                      .where('read', isEqualTo: false)),
              _tile(context, Icons.notifications_rounded,  'Notifications',   null,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const NotificationPage()));
                  }),

              _section('PERSONAL'),
              _tile(context, Icons.how_to_reg_rounded,     'Attendance',      '/rnd/attendance'),
              _tile(context, Icons.payments_rounded,       'Salary',          '/common/salary'),
              _tile(context, Icons.account_balance_rounded,'Loan Request',    '/rnd/loan'),

              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Logout',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context);
                  await LocalStorageService.performLogout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: _rndPrimary.withOpacity(0.5), letterSpacing: 1.2)),
  );

  Widget _tile(BuildContext context, IconData icon, String title, String? route,
      {Query<Map<String, dynamic>>? badgeQuery, VoidCallback? onTap}) {
    return _DrawerTile(
      icon: icon,
      title: title,
      badgeQuery: badgeQuery,
      onTap: onTap ?? () {
        Navigator.pop(context);
        if (route != null) Navigator.pushNamed(context, route);
      },
    );
  }
}

class _DrawerTile extends StatefulWidget {
  final IconData icon;
  final String   title;
  final Query<Map<String, dynamic>>? badgeQuery;
  final VoidCallback onTap;
  const _DrawerTile({required this.icon, required this.title,
      this.badgeQuery, required this.onTap});
  @override
  State<_DrawerTile> createState() => _DrawerTileState();
}

class _DrawerTileState extends State<_DrawerTile> {
  StreamSubscription? _sub;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    if (widget.badgeQuery != null) {
      _sub = widget.badgeQuery!.snapshots().listen((s) {
        if (mounted) setState(() => _count = s.docs.length);
      });
    }
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _rndCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _rndPrimary.withOpacity(0.15)),
        ),
        child: Icon(widget.icon, size: 18, color: _rndPrimary),
      ),
      title: Text(widget.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: _count > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
          color: _rndMagenta,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text('$_count',
            style: const TextStyle(color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w700)),
            )
          : const Icon(Icons.chevron_right_rounded, color: Colors.black26),
      onTap: widget.onTap,
    );
  }
}
