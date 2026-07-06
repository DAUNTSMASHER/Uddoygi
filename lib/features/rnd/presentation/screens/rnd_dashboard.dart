import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/features/rnd/rnd_theme.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/common/notification.dart';
import '../widgets/rnd_drawer.dart';

// ─────────────────────────────────────────────────────────────
// THEME  — Deep Violet / Royal Purple + Electric Blue accent
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// DASHBOARD
// ─────────────────────────────────────────────────────────────
class RndDashboard extends StatefulWidget {
  const RndDashboard({super.key});
  @override
  State<RndDashboard> createState() => _RndDashboardState();
}

class _RndDashboardState extends State<RndDashboard> {
  String _cid = '';
  String? uid, email, name, photoUrl;
  int _currentTab = 0;

  Stream<int> _notifStream = Stream.value(0);
  Stream<int> _msgStream   = Stream.value(0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (!mounted) return;
    setState(() {
      _cid = id ?? '';
      if (_cid.isNotEmpty) {
        _notifStream = _buildNotifStream();
        _msgStream   = _buildMsgStream();
      }
    });
    await _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    setState(() {
      uid      = session?['uid']   as String? ?? current?.uid;
      email    = session?['email'] as String? ?? current?.email;
      name     = session?['name']  as String? ?? current?.displayName ?? current?.email ?? 'R&D';
      photoUrl = current?.photoURL;
    });
    if (uid != null && _cid.isNotEmpty) {
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

  Stream<int> _buildNotifStream() {
    if (_cid.isEmpty || email == null) return Stream.value(0);
    return DB.colSync(_cid, C.notifications)
        .where('to', isEqualTo: email)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _buildMsgStream() {
    if (_cid.isEmpty || email == null) return Stream.value(0);
    return DB.colSync(_cid, C.messages)
        .where('to', isEqualTo: email)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (name ?? 'R&D').trim();
    final initials    = _initials(displayName);

    return Scaffold(
      backgroundColor: rndSurface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: rndBrandDk,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: Colors.white24,
            backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                ? NetworkImage(photoUrl!) : null,
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? Text(initials, style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))
                : null,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('R&D Specialist', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                Text(displayName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
          ),
        ]),
        actions: [
          StreamBuilder<int>(
            stream: _notifStream,
            builder: (_, s) => Stack(clipBehavior: Clip.none, children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 22),
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationPage())),
              ),
              if ((s.data ?? 0) > 0)
                Positioned(right: 8, top: 8,
                    child: _Badge(count: s.data ?? 0)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () async {
              await LocalStorageService.performLogout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      drawer: const RndDrawer(),
      bottomNavigationBar: _buildBottomNav(),
      body: RefreshIndicator(
        color: rndBrand,
        onRefresh: () async => setState(() {}),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── KPI Hero card ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _KpiHeader(email: email),
              ),
            ),

            // ── Today's Activity ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _TodayActivity(email: email),
              ),
            ),

            // ── Quick Actions section label ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Row(children: [
                  const Icon(Icons.flash_on_rounded, size: 20, color: rndBrand),
                  const SizedBox(width: 10),
                  Text('Quick Actions',
                      style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Theme.of(context).colorScheme.onSurface)),
                ]),
              ),
            ),

            // ── Quick Actions grid ────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverToBoxAdapter(
                child: _QuickActionsGrid(context: context),
              ),
            ),

            // ── Recent Activity ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _RecentFeed(email: email),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      _NavItem('Home',       Icons.home_rounded,
          onTap: () => setState(() => _currentTab = 0)),
      _NavItem('Projects',   Icons.science_rounded,
          onTap: () => Navigator.pushNamed(context, '/rnd/projects')),
      _NavItem('Updates',    Icons.edit_note_rounded,
          onTap: () => Navigator.pushNamed(context, '/rnd/updates')),
      _NavItem('Milestones', Icons.flag_rounded,
          onTap: () => Navigator.pushNamed(context, '/rnd/milestones')),
      _NavItem('Inbox',      Icons.inbox_rounded,
          onTap: () => Navigator.pushNamed(context, '/rnd/inbox')),
      _NavItem('Messages',   Icons.message_rounded,
          onTap: () => Navigator.pushNamed(context, '/common/messages'),
          badgeStream: _msgStream),
    ];

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [rndBrandDk, rndBrand],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: items.asMap().entries.map((e) {
            final i  = e.key;
            final it = e.value;
            final selected = i == _currentTab;
            final color = selected ? Colors.white : Colors.white70;
            final iconWidget = it.badgeStream == null
                ? Icon(it.icon, color: color)
                : StreamBuilder<int>(
                    stream: it.badgeStream,
                    builder: (_, s) => _BadgeIcon(
                        icon: it.icon, color: color, count: s.data ?? 0));
            return Expanded(
              child: InkWell(
                onTap: () { setState(() => _currentTab = i); it.onTap(); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    iconWidget,
                    const SizedBox(height: 3),
                    Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: color, fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KPI HEADER
// ─────────────────────────────────────────────────────────────
class _KpiHeader extends StatefulWidget {

  final String? email;
  const _KpiHeader({this.email});
  @override
  State<_KpiHeader> createState() => _KpiHeaderState();
}

class _KpiHeaderState extends State<_KpiHeader> {
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [rndBrandDk, rndMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: rndBrand.withValues(alpha: 0.3),
            blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.biotech_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('R&D Overview',
                style: TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white30),
            ),
            child: Text(
              DateFormat('d MMM yyyy').format(DateTime.now()),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          _KpiStream(
            icon: Icons.science_rounded,
            label: 'Active',
            stream: DB.colSync(_cid, C.rndProjects)
                .where('status', isEqualTo: 'In Progress')
                .snapshots().map((s) => '${s.docs.length}'),
          ),
          _KpiStream(
            icon: Icons.pending_actions_rounded,
            label: 'Pending',
            stream: DB.colSync(_cid, C.rndRequests)
                .where('status', isEqualTo: 'Submitted')
                .snapshots().map((s) => '${s.docs.length}'),
          ),
          _KpiStream(
            icon: Icons.check_circle_rounded,
            label: 'Done',
            stream: DB.colSync(_cid, C.rndProjects)
                .where('status', isEqualTo: 'Completed')
                .snapshots().map((s) => '${s.docs.length}'),
          ),
          _KpiStream(
            icon: Icons.warning_amber_rounded,
            label: 'Overdue',
            stream: DB.colSync(_cid, C.rndProjects)
                .where('status', whereIn: ['In Progress', 'Testing'])
                .snapshots().map((s) {
                  final now = DateTime.now();
                  return '${s.docs.where((d) {
                    final dl = d.data()['deadline'];
                    if (dl == null) return false;
                    final dt = dl is Timestamp ? dl.toDate()
                        : DateTime.tryParse(dl.toString());
                    return dt != null && dt.isBefore(now);
                  }).length}';
                }),
          ),
        ]),
      ]),
    );
  }
}

class _KpiStream extends StatelessWidget {
  final String label;
  final Stream<String> stream;
  final IconData? icon;
  const _KpiStream({required this.label, required this.stream, this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white60, size: 16),
          const SizedBox(height: 4),
        ],
        StreamBuilder<String>(
          stream: stream,
          builder: (_, s) => Text(s.data ?? '—',
              style: const TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 10,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TODAY'S ACTIVITY
// ─────────────────────────────────────────────────────────────
class _TodayActivity extends StatefulWidget {

  final String? email;
  const _TodayActivity({this.email});
  @override
  State<_TodayActivity> createState() => _TodayActivityState();
}

class _TodayActivityState extends State<_TodayActivity> {
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
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end   = start.add(const Duration(days: 1));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [BoxShadow(color: Color(0x06000000),
            blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: rndBrand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.today_rounded, size: 22, color: rndBrand),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Today's Activity",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            StreamBuilder<QuerySnapshot>(
              stream: DB.colSync(_cid, C.rndUpdates)
                  .where('submittedByEmail', isEqualTo: widget.email ?? '')
                  .where('createdAt',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                  .where('createdAt', isLessThan: Timestamp.fromDate(end))
                  .snapshots(),
              builder: (_, snap) {
                final count = snap.data?.docs.length ?? 0;
                return _ActivityChip(
                  Icons.check_circle_rounded,
                  '$count update${count == 1 ? '' : 's'} today',
                  count > 0 ? rndAccent : const Color(0xFF94A3B8),
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _ActivityChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: color)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// QUICK ACTIONS GRID
// ─────────────────────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  final BuildContext context;
  const _QuickActionsGrid({required this.context});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Tile('My Projects',   Icons.science_rounded,        '/rnd/projects',   const Color(0xFF5B21B6)),
      _Tile('Daily Update',  Icons.edit_note_rounded,       '/rnd/updates',    const Color(0xFF7C3AED)),
      _Tile('Milestones',    Icons.flag_rounded,            '/rnd/milestones', const Color(0xFF0891B2)),
      _Tile('Project Inbox', Icons.inbox_rounded,           '/rnd/inbox',      const Color(0xFF6366F1)),
      _Tile('Reports',       Icons.bar_chart_rounded,       '/rnd/reports',    const Color(0xFF059669)),
      _Tile('Notices',       Icons.announcement_rounded,    '/rnd/notices',    const Color(0xFFDB2777)),
      _Tile('Messages',      Icons.message_rounded,         '/common/messages',const Color(0xFF7C3AED)),
      _Tile('Attendance',    Icons.how_to_reg_rounded,      '/rnd/attendance', const Color(0xFF0D9488)),
      _Tile('Salary',        Icons.payments_rounded,        '/common/salary',  const Color(0xFF16A34A)),
      _Tile('Loan Request',  Icons.account_balance_rounded, '/rnd/loan',       const Color(0xFFB45309)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (_, i) => _DashTile(tile: tiles[i]),
    );
  }
}

class _Tile {
  final String   label, route;
  final IconData icon;
  final Color    accent;
  const _Tile(this.label, this.icon, this.route, this.accent);
}

class _DashTile extends StatelessWidget {
  final _Tile tile;
  const _DashTile({required this.tile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: tile.accent.withValues(alpha: 0.08),
        onTap: () => Navigator.pushNamed(context, tile.route),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14000000)),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: tile.accent,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: tile.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(tile.icon, color: tile.accent, size: 22),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(builder: (_, c) {
                        double fs = 11.5;
                        if (tile.label.length > 12 || c.maxWidth < 90) fs = 10.5;
                        if (tile.label.length > 16 || c.maxWidth < 76) fs = 9.5;
                        return Text(
                          tile.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: const Color(0xFF0F172A),
                              fontSize: fs,
                              fontWeight: FontWeight.w700),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RECENT FEED
// ─────────────────────────────────────────────────────────────
class _RecentFeed extends StatefulWidget {

  final String? email;
  const _RecentFeed({this.email});
  @override
  State<_RecentFeed> createState() => _RecentFeedState();
}

class _RecentFeedState extends State<_RecentFeed> {
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [rndBrand, rndAccent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        const Text('Recent Activity',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: rndBrand)),
      ]),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot>(
        stream: DB.colSync(_cid, C.rndUpdates)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const _Shimmer();
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const _Empty('No recent updates yet.');
          return Column(
            children: docs.map((d) {
              final m = d.data() as Map<String, dynamic>;
              return _FeedCard(data: m);
            }).toList(),
          );
        },
      ),
    ]);
  }
}

class _FeedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FeedCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ts = data['createdAt'];
    final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
    final ago = _timeAgo(dt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rndCardTint),
        boxShadow: const [BoxShadow(color: Color(0x06000000),
            blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [rndBrand, rndMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.science_rounded, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(data['projectTitle'] ?? 'R&D Update',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text(ago, style: const TextStyle(fontSize: 11, color: Colors.black38)),
          ]),
          const SizedBox(height: 2),
          Text(data['workDone'] ?? '',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ])),
      ]),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inHours < 1)    return '${diff.inMinutes}m ago';
    if (diff.inDays < 1)     return '${diff.inHours}h ago';
    return DateFormat('d MMM').format(dt);
  }
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────
class _NavItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Stream<int>? badgeStream;
  _NavItem(this.label, this.icon, {required this.onTap, this.badgeStream});
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final int      count;
  const _BadgeIcon({required this.icon, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Icon(icon, color: color),
      if (count > 0)
        Positioned(right: -5, top: -5,
            child: _Badge(count: count)),
    ]);
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Text(count > 99 ? '99+' : '$count',
          style: const TextStyle(color: Colors.white, fontSize: 9,
              fontWeight: FontWeight.w800, height: 1)),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(child: CircularProgressIndicator(
        color: rndBrand, strokeWidth: 2.5)),
  );
}

class _Empty extends StatelessWidget {
  final String msg;
  const _Empty(this.msg);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(child: Text(msg,
        style: const TextStyle(color: Colors.black38, fontSize: 14))),
  );
}
