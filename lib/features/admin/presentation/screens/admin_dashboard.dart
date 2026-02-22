import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import '../widgets/admin_drawer.dart';
import '../widgets/admin_dashboard_summary.dart';
import 'package:uddoygi/features/common/notification.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _p900 = Color(0xFF1E0040);
const Color _p700 = Color(0xFF2A0A4B);
const Color _p500 = Color(0xFF6D28D9);
const Color _p100 = Color(0xFFEDE9FE);
const Color _bg   = Color(0xFFF3F0FA);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _DashboardItem {
  final String keyId;
  final String title;
  final IconData icon;
  final String route;
  final List<Query<Map<String, dynamic>>> queries;
  const _DashboardItem({
    required this.keyId,
    required this.title,
    required this.icon,
    required this.route,
    required this.queries,
  });
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _cid          = '';
  bool   _isRefreshing = false;

  String? uid;
  String? name;
  String? photoUrl;

  int _currentTab = 0;

  Stream<int> _notifStream = Stream.value(0);
  Stream<int> _msgStream   = Stream.value(0);

  List<_DashboardItem> get _items {
    if (_cid.isEmpty) return [];
    return [
      _DashboardItem(keyId: 'notices',    title: 'Notices',    icon: Icons.announcement_outlined,  route: '/admin/notices',     queries: [DB.colSync(_cid, C.notices)]),
      _DashboardItem(keyId: 'employees',  title: 'Employees',  icon: Icons.people_outline,          route: '/admin/employees',   queries: [DB.colSync(_cid, C.users)]),
      _DashboardItem(keyId: 'reports',    title: 'Reports',    icon: Icons.bar_chart_outlined,      route: '/admin/reports',     queries: [DB.colSync(_cid, C.invoices), DB.colSync(_cid, C.expenses)]),
      _DashboardItem(keyId: 'welfare',    title: 'Welfare',    icon: Icons.favorite_outline,        route: '/common/welfare',    queries: [DB.colSync(_cid, C.welfare)]),
      _DashboardItem(keyId: 'complaints', title: 'Complaints', icon: Icons.report_problem_outlined, route: '/common/complaints', queries: [DB.colSync(_cid, C.complaints)]),
      _DashboardItem(keyId: 'salary',     title: 'Salary',     icon: Icons.payments_outlined,       route: '/common/salary',     queries: [DB.colSync(_cid, C.salaries)]),
      _DashboardItem(keyId: 'messages',   title: 'Messages',   icon: Icons.chat_bubble_outline,     route: '/common/messages',   queries: [DB.colSync(_cid, C.messages)]),
      _DashboardItem(keyId: 'rnd',        title: 'R&D',        icon: Icons.science_outlined,        route: '/admin/research',    queries: [DB.colSync(_cid, C.rndUpdates)]),
      _DashboardItem(keyId: 'company',    title: 'My Company', icon: Icons.business_outlined,         route: '/admin/company',     queries: []),
      _DashboardItem(keyId: 'settings',   title: 'Settings',   icon: Icons.settings_outlined,         route: '/admin/settings',    queries: []),
      _DashboardItem(keyId: 'attendance', title: 'Attendance', icon: Icons.event_available_outlined,  route: '/admin/attendance',  queries: []),
    ];
  }

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
    await _loadUser();
  }

  Future<void> _loadUser() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    setState(() {
      uid      = session?['uid']  as String? ?? current?.uid;
      name     = session?['name'] as String? ?? current?.displayName ?? current?.email ?? 'Admin';
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

  Stream<int> _buildNotifStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _cid.isEmpty) return Stream.value(0);
    return DB.colSync(_cid, C.notifications)
        .where('to', isEqualTo: user.email ?? '')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _buildMsgStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _cid.isEmpty) return Stream.value(0);
    return DB.colSync(_cid, C.messages)
        .where('to', isEqualTo: user.email ?? '')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<void> _openSection(_DashboardItem item) async {
    await _markSeen(item.keyId);
    if (!mounted) return;
    setState(() {});
    await Navigator.pushNamed(context, item.route);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _markSeen(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('lastSeen_$key', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<DateTime> _getLastSeen(String key) async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt('lastSeen_$key');
    if (ms == null) {
      final now = DateTime.now();
      await p.setInt('lastSeen_$key', now.millisecondsSinceEpoch);
      return now;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (name ?? 'Admin').trim();

    return Scaffold(
      backgroundColor: _bg,
      drawer: const AdminDrawer(),
      bottomNavigationBar: _buildBottomNav(),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [_buildAppBar(displayName)],
        body: _buildBody(),
      ),
    );
  }

  // ── Sliver App Bar ────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar(String displayName) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      expandedHeight: 0,
      backgroundColor: _p700,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 0,
      title: Row(children: [
        const SizedBox(width: 4),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30, width: 1.5),
          ),
          child: ClipOval(
            child: (photoUrl != null && photoUrl!.isNotEmpty)
                ? Image.network(photoUrl!, fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => _InitialsAvatar(displayName))
                : _InitialsAvatar(displayName),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Admin Panel',
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500)),
              Text(displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      ]),
      actions: [
        StreamBuilder<int>(
          stream: _notifStream,
          builder: (_, s) => _AppBarAction(
            icon: Icons.notifications_outlined,
            badge: s.data ?? 0,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationPage())),
          ),
        ),
        _AppBarAction(
          icon: Icons.logout_rounded,
          onTap: () async {
            await LocalStorageService.performLogout();
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        // ── Summary hero card ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                      color: _p100, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.insights_rounded, size: 12, color: _p500),
                ),
                const SizedBox(width: 6),
                Text('Overview',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w800, color: _p700)),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    setState(() => _isRefreshing = true);
                    await Future.delayed(const Duration(milliseconds: 600));
                    if (mounted) setState(() => _isRefreshing = false);
                  },
                  child: _isRefreshing
                      ? const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _p500)),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                                color: _p100,
                                borderRadius: BorderRadius.circular(7)),
                            child: const Icon(Icons.refresh_rounded,
                                size: 13, color: _p500),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),

        // ── Summary (single big hero card) ───────────────────────────────
        const SliverToBoxAdapter(child: AdminDashboardSummary()),

        // ── Quick Actions header ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                    color: _p100, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.bolt_rounded, size: 12, color: _p500),
              ),
              const SizedBox(width: 6),
              Text('Quick Actions',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w800, color: _p700)),
            ]),
          ),
        ),

        // ── Quick action 4-column grid ───────────────────────────────────
        _cid.isEmpty
            ? const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _p500)))
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 7,
                    mainAxisSpacing: 7,
                    childAspectRatio: 0.88,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _items[index];
                      return _ActionTile(
                        item: item,
                        getLastSeen: _getLastSeen,
                        onTap: () => _openSection(item),
                        noticeBadgeStream:
                            item.keyId == 'notices' ? _notifStream : null,
                      );
                    },
                    childCount: _items.length,
                  ),
                ),
              ),
      ],
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final tabs = [
      _NavItem('Home',          Icons.home_rounded,         () => setState(() => _currentTab = 0)),
      _NavItem('Employees',     Icons.people_rounded,       () => Navigator.pushNamed(context, '/admin/employees')),
      _NavItem('Messages',      Icons.chat_bubble_rounded,  () => Navigator.pushNamed(context, '/common/messages'),  badge: _msgStream),
      _NavItem('Notifications', Icons.notifications_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage())),
          badge: _notifStream),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _p900,
        boxShadow: [
          BoxShadow(
            color: _p900.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final t        = tabs[i];
              final selected = i == _currentTab;
              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _currentTab = i);
                    t.onTap();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: selected ? _p500 : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        t.badge == null
                            ? Icon(t.icon,
                                color: selected ? Colors.white : Colors.white38,
                                size: 22)
                            : StreamBuilder<int>(
                                stream: t.badge,
                                builder: (_, s) {
                                  final n = s.data ?? 0;
                                  return Stack(clipBehavior: Clip.none, children: [
                                    Icon(t.icon,
                                        color: selected ? Colors.white : Colors.white38,
                                        size: 22),
                                    if (n > 0)
                                      Positioned(
                                        right: -6, top: -4,
                                        child: _Dot(n),
                                      ),
                                  ]);
                                },
                              ),
                        const SizedBox(height: 3),
                        Text(t.label,
                            maxLines: 1,
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                color: selected ? Colors.white : Colors.white38)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Action tile — 4-column grid, white card with dark-purple label ─────────────
class _ActionTile extends StatefulWidget {
  final _DashboardItem item;
  final Future<DateTime> Function(String) getLastSeen;
  final VoidCallback onTap;
  final Stream<int>? noticeBadgeStream;

  const _ActionTile({
    required this.item,
    required this.getLastSeen,
    required this.onTap,
    this.noticeBadgeStream,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  int _newCount = 0;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs = [];
  final Map<int, int> _perQ = {};

  // One icon-box colour per tile (cycles through purple shades)
  static const _iconColors = [
    Color(0xFF3B0764),
    Color(0xFF4C1D95),
    Color(0xFF312E81),
    Color(0xFF1E1B4B),
    Color(0xFF2A0A4B),
    Color(0xFF2E1065),
    Color(0xFF1E0040),
    Color(0xFF1A0533),
  ];

  Color get _iconBg =>
      _iconColors[widget.item.keyId.hashCode.abs() % _iconColors.length];

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant _ActionTile old) {
    super.didUpdateWidget(old);
    _detach();
    _attach();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  Future<void> _attach() async {
    if (widget.item.queries.isEmpty) return;
    final lastSeen = await widget.getLastSeen(widget.item.keyId);
    _perQ.clear();
    for (final q in widget.item.queries) {
      final sub = q
          .where('createdAt', isGreaterThan: Timestamp.fromDate(lastSeen))
          .snapshots()
          .listen((snap) {
        _perQ[q.hashCode] = snap.docs.length;
        final total = _perQ.values.fold(0, (s, n) => s + n);
        if (mounted) setState(() => _newCount = total);
      });
      _subs.add(sub);
    }
  }

  void _detach() {
    for (final s in _subs) s.cancel();
    _subs.clear();
  }

  @override
  Widget build(BuildContext context) {
    final badgeStream = widget.noticeBadgeStream;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEDE9FE), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Badge (top-right)
            if (badgeStream != null)
              Positioned(
                top: 5, right: 5,
                child: StreamBuilder<int>(
                  stream: badgeStream,
                  builder: (_, s) {
                    final n = s.data ?? 0;
                    final show = n > 0 || _newCount > 0;
                    if (!show) return const SizedBox.shrink();
                    return _Dot(n > 0 ? n : _newCount);
                  },
                ),
              )
            else if (_newCount > 0)
              Positioned(
                top: 5, right: 5,
                child: _Dot(_newCount),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon box
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: _iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.item.icon,
                        color: Colors.white, size: 17),
                  ),
                  const SizedBox(height: 6),
                  // Label
                  Text(
                    widget.item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _p900,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Initials avatar ───────────────────────────────────────────────────────────
class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar(this.name);

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white24,
      child: Center(
        child: Text(_initials,
            style: GoogleFonts.inter(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ── App bar action ────────────────────────────────────────────────────────────
class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;

  const _AppBarAction({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(icon: Icon(icon, size: 22), onPressed: onTap, color: Colors.white),
      if (badge > 0) Positioned(right: 6, top: 6, child: _Dot(badge)),
    ]);
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(color: _p100, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: _p500),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w800, color: _p700)),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// ── Badge dot ─────────────────────────────────────────────────────────────────
class _Dot extends StatelessWidget {
  final int count;
  const _Dot(this.count);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: GoogleFonts.inter(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, height: 1.1),
      ),
    );
  }
}

// ── Nav item model ────────────────────────────────────────────────────────────
class _NavItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Stream<int>? badge;
  _NavItem(this.label, this.icon, this.onTap, {this.badge});
}
