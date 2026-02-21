// lib/features/attendance/user_attendance_view.dart
//
// Individual employee attendance view.
// Layout: hero card (today's status + time) → overview grid → week bar chart → recent logs.
// Data path: data/{cid}/attendance/{yyyy-MM-dd}/records/{employeeId}
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg        = Color(0xFFF0F4FF);
const _primary   = Color(0xFF2563EB);
const _primaryDk = Color(0xFF1E3A8A);
const _card      = Color(0xFFFFFFFF);
const _border    = Color(0x1A2563EB);
const _fg        = Color(0xFF0F172A);
const _muted     = Color(0xFF94A3B8);
const _success   = Color(0xFF16A34A);
const _warning   = Color(0xFFF97316);
const _danger    = Color(0xFFDC2626);
const _info      = Color(0xFF2563EB);

// ── Status helpers ────────────────────────────────────────────────────────────
Color _statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'present': return _success;
    case 'absent':  return _danger;
    case 'late':    return _warning;
    case 'leave':   return _info;
    default:        return _muted;
  }
}

IconData _statusIcon(String s) {
  switch (s.toLowerCase()) {
    case 'present': return Icons.check_circle_rounded;
    case 'absent':  return Icons.cancel_rounded;
    case 'late':    return Icons.watch_later_rounded;
    case 'leave':   return Icons.beach_access_rounded;
    default:        return Icons.help_outline_rounded;
  }
}

String _statusLabel(String s) {
  if (s.isEmpty) return 'Not Marked';
  return s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ── Main widget ───────────────────────────────────────────────────────────────
class UserAttendanceView extends StatefulWidget {
  final String? email;
  final String? employeeId;

  const UserAttendanceView({
    super.key,
    this.email,
    this.employeeId,
  });

  @override
  State<UserAttendanceView> createState() => _UserAttendanceViewState();
}

class _UserAttendanceViewState extends State<UserAttendanceView> {
  String  _cid        = '';
  String? _employeeId;
  String? _userEmail;
  bool    _loading    = true;
  String? _error;

  // Selected month for history
  late DateTime _selectedMonth;

  // Live clock for hero
  late Timer _clockTimer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _selectedMonth = DateTime(_now.year, _now.month);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _init();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (!mounted) return;
    setState(() => _cid = id ?? '');

    if (widget.employeeId != null && widget.email != null) {
      setState(() {
        _employeeId = widget.employeeId;
        _userEmail  = widget.email;
        _loading    = false;
      });
    } else {
      await _resolveEmployee();
    }
  }

  // Resolve employee from Firebase Auth current user.
  // Uses the real email stored in Firestore (not the compound auth email).
  Future<void> _resolveEmployee() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() { _error = 'Not logged in.'; _loading = false; });
        return;
      }

      final cid = _cid.isNotEmpty ? _cid
          : (await LocalStorageService.getSavedCompanyId() ?? '');
      if (cid.isEmpty) {
        setState(() { _error = 'Company not found.'; _loading = false; });
        return;
      }

      // The auth email is compound (local+CID@domain). The real email is stored
      // in the 'email' or 'officeEmail' field. Query by uid first (fastest).
      final byUid = await DB.colSync(cid, C.users).doc(user.uid).get();
      if (byUid.exists) {
        final d = byUid.data()!;
        final empId = (d['employeeId'] as String?)?.trim()
            ?? (d['uid'] as String?)?.trim()
            ?? user.uid;
        final realEmail = ((d['email'] ?? d['officeEmail']) as String?)?.trim()
            ?? user.email ?? '';
        if (mounted) {
          setState(() {
            _employeeId = empId;
            _userEmail  = realEmail;
            _loading    = false;
          });
        }
        return;
      }

      // Fallback: search by real email (strip compound suffix if present)
      final authEmail = user.email ?? '';
      final plusIdx   = authEmail.indexOf('+');
      final atIdx     = authEmail.indexOf('@');
      final realEmail = (plusIdx > 0 && atIdx > plusIdx)
          ? '${authEmail.substring(0, plusIdx)}@${authEmail.substring(atIdx + 1)}'
          : authEmail;

      QuerySnapshot<Map<String, dynamic>> q =
          await DB.colSync(cid, C.users)
              .where('email', isEqualTo: realEmail).limit(1).get();
      if (q.docs.isEmpty) {
        q = await DB.colSync(cid, C.users)
            .where('officeEmail', isEqualTo: realEmail).limit(1).get();
      }

      if (q.docs.isEmpty) {
        setState(() { _error = 'Employee record not found.'; _loading = false; });
        return;
      }

      final d = q.docs.first.data();
      final empId = (d['employeeId'] as String?)?.trim()
          ?? q.docs.first.id;
      if (mounted) {
        setState(() {
          _employeeId = empId;
          _userEmail  = realEmail;
          _loading    = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  // Stream today's attendance record for this employee.
  Stream<Map<String, dynamic>?> _todayStream() {
    if (_employeeId == null || _cid.isEmpty) return Stream.value(null);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return DB.colSync(_cid, C.attendance)
        .doc(today)
        .collection('records')
        .doc(_employeeId!)
        .snapshots()
        .map((s) => s.exists ? s.data() : null);
  }

  // Fetch all records for the selected month.
  Future<List<Map<String, dynamic>>> _fetchMonth() async {
    if (_employeeId == null || _cid.isEmpty) return [];
    final year  = _selectedMonth.year;
    final month = _selectedMonth.month;
    final days  = DateUtils.getDaysInMonth(year, month);
    final List<Map<String, dynamic>> result = [];
    for (int d = 1; d <= days; d++) {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime(year, month, d));
      final snap = await DB.colSync(_cid, C.attendance)
          .doc(dateStr)
          .collection('records')
          .doc(_employeeId!)
          .get();
      if (snap.exists) {
        final data = snap.data()!;
        result.add({
          'date':    dateStr,
          'status':  (data['status'] ?? '').toString().toLowerCase(),
          'remarks': (data['remarks'] ?? '').toString(),
          'checkIn': data['checkIn'],
          'checkOut': data['checkOut'],
        });
      }
    }
    return result;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primaryDk,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(),
        title: Text('My Attendance',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? _ErrorView(message: _error!)
              : _AttendanceBody(
                  employeeId:    _employeeId!,
                  userEmail:     _userEmail ?? '',
                  cid:           _cid,
                  now:           _now,
                  selectedMonth: _selectedMonth,
                  todayStream:   _todayStream(),
                  fetchMonth:    _fetchMonth,
                  onMonthChanged: (m) => setState(() => _selectedMonth = m),
                ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────
class _AttendanceBody extends StatefulWidget {
  final String   employeeId;
  final String   userEmail;
  final String   cid;
  final DateTime now;
  final DateTime selectedMonth;
  final Stream<Map<String, dynamic>?> todayStream;
  final Future<List<Map<String, dynamic>>> Function() fetchMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const _AttendanceBody({
    required this.employeeId,
    required this.userEmail,
    required this.cid,
    required this.now,
    required this.selectedMonth,
    required this.todayStream,
    required this.fetchMonth,
    required this.onMonthChanged,
  });

  @override
  State<_AttendanceBody> createState() => _AttendanceBodyState();
}

class _AttendanceBodyState extends State<_AttendanceBody> {
  List<Map<String, dynamic>> _records = [];
  bool _histLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant _AttendanceBody old) {
    super.didUpdateWidget(old);
    if (old.selectedMonth != widget.selectedMonth ||
        old.employeeId != widget.employeeId) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _histLoading = true);
    final r = await widget.fetchMonth();
    if (mounted) setState(() { _records = r; _histLoading = false; });
  }

  // ── Stats from records ────────────────────────────────────────────────────
  int get _present => _records.where((r) => r['status'] == 'present').length;
  int get _absent  => _records.where((r) => r['status'] == 'absent').length;
  int get _late    => _records.where((r) => r['status'] == 'late').length;
  int get _leave   => _records.where((r) => r['status'] == 'leave').length;
  int get _total   => _records.length;

  double get _presentPct => _total > 0 ? _present / _total : 0;

  // Last 7 days for the week bar chart
  List<_DayBar> get _weekBars {
    final bars = <_DayBar>[];
    for (int i = 6; i >= 0; i--) {
      final d    = widget.now.subtract(Duration(days: i));
      final key  = DateFormat('yyyy-MM-dd').format(d);
      final rec  = _records.firstWhere(
          (r) => r['date'] == key, orElse: () => {'status': ''});
      bars.add(_DayBar(
        label:   DateFormat('E').format(d)[0],
        status:  rec['status'] as String,
        isToday: i == 0,
      ));
    }
    return bars;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadHistory,
      child: CustomScrollView(
        slivers: [
          // ── Hero card ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StreamBuilder<Map<String, dynamic>?>(
              stream: widget.todayStream,
              builder: (_, snap) {
                final today = snap.data;
                final status = today != null
                    ? (today['status'] as String? ?? '').toLowerCase()
                    : '';
                return _HeroCard(
                  now:    widget.now,
                  status: status,
                  email:  widget.userEmail,
                );
              },
            ),
          ),

          // ── Month selector ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _MonthSelector(
                selected: widget.selectedMonth,
                onChanged: widget.onMonthChanged,
              ),
            ),
          ),

          // ── Overview grid ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _histLoading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: CircularProgressIndicator(color: _primary)))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _OverviewGrid(
                      present: _present,
                      absent:  _absent,
                      late:    _late,
                      leave:   _leave,
                      pct:     _presentPct,
                    ),
                  ),
          ),

          // ── Week chart ─────────────────────────────────────────────────
          if (!_histLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _WeekChart(
                  bars:    _weekBars,
                  pct:     _presentPct,
                ),
              ),
            ),

          // ── Recent logs ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Text('Recent Logs',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700, color: _fg)),
                const Spacer(),
                Text('${_records.length} records',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: _muted, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),

          if (_histLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: _primary)),
              ),
            )
          else if (_records.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Center(
                  child: Text('No records for this month.',
                      style: GoogleFonts.inter(color: _muted, fontSize: 14)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final sorted = [..._records]
                      ..sort((a, b) => b['date'].compareTo(a['date']));
                    return _LogCard(record: sorted[i]);
                  },
                  childCount: _records.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final DateTime now;
  final String   status;
  final String   email;

  const _HeroCard({
    required this.now,
    required this.status,
    required this.email,
  });

  String get _greeting {
    final h = now.hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String get _displayName {
    if (email.isEmpty) return 'Employee';
    final at = email.indexOf('@');
    final base = at > 0 ? email.substring(0, at) : email;
    return base.replaceAll('.', ' ').replaceAll('_', ' ')
        .split(' ').map((w) => w.isEmpty ? '' :
            w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm').format(now);
    final amPm    = DateFormat('a').format(now);
    final dateStr = DateFormat('EEEE, d MMM yyyy').format(now);
    final hasStatus = status.isNotEmpty;
    final statusC = hasStatus ? _statusColor(status) : _muted;
    final statusL = hasStatus ? _statusLabel(status) : 'Not Marked';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting row
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white70)),
                  Text(_displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white30),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon(status), color: statusC, size: 13),
                const SizedBox(width: 5),
                Text(statusL,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
            ),
          ]),

          const SizedBox(height: 16),

          // Time display
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(timeStr,
                style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1)),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(amPm,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(dateStr,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),

          const SizedBox(height: 16),

          // Today label
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Today',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasStatus
                    ? 'Status recorded as $statusL'
                    : 'Attendance not yet marked for today',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Month selector ────────────────────────────────────────────────────────────
class _MonthSelector extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;

  const _MonthSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now    = DateTime.now();
    final months = List.generate(12, (i) => DateTime(now.year, i + 1));

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime>(
          value: months.firstWhere(
              (m) => m.month == selected.month && m.year == selected.year,
              orElse: () => months[now.month - 1]),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _primary, size: 20),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: _fg),
          dropdownColor: _card,
          items: months.map((m) => DropdownMenuItem(
            value: m,
            child: Text(DateFormat('MMMM yyyy').format(m)),
          )).toList(),
          onChanged: (m) { if (m != null) onChanged(m); },
        ),
      ),
    );
  }
}

// ── Overview grid ─────────────────────────────────────────────────────────────
class _OverviewGrid extends StatelessWidget {
  final int    present;
  final int    absent;
  final int    late;
  final int    leave;
  final double pct;

  const _OverviewGrid({
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Overview',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _fg)),
          const Spacer(),
          GestureDetector(
            child: Text('View report',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primary)),
          ),
        ]),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _StatCard(
              icon: Icons.check_circle_outline_rounded,
              iconColor: _success,
              iconBg: _success.withValues(alpha: 0.08),
              value: '$present',
              label: 'Present days',
            ),
            _StatCard(
              icon: Icons.cancel_outlined,
              iconColor: _danger,
              iconBg: _danger.withValues(alpha: 0.08),
              value: '$absent',
              label: 'Absent days',
            ),
            _StatCard(
              icon: Icons.watch_later_outlined,
              iconColor: _warning,
              iconBg: _warning.withValues(alpha: 0.08),
              value: '$late',
              label: 'Late arrivals',
            ),
            _StatCard(
              icon: Icons.beach_access_outlined,
              iconColor: _info,
              iconBg: _info.withValues(alpha: 0.08),
              value: '$leave',
              label: 'Leave days',
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Attendance rate bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Attendance Rate',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _fg)),
                const Spacer(),
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _primary)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFEFF6FF),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(_primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Color    iconBg;
  final String   value;
  final String   label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _fg,
                      height: 1.1)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: _muted, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Week bar chart ────────────────────────────────────────────────────────────
class _DayBar {
  final String label;
  final String status;
  final bool   isToday;
  const _DayBar({required this.label, required this.status, required this.isToday});
}

class _WeekChart extends StatelessWidget {
  final List<_DayBar> bars;
  final double        pct;

  const _WeekChart({required this.bars, required this.pct});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('This Week',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _fg)),
            const Spacer(),
            Text('${(pct * 100).toStringAsFixed(0)}% present',
                style: GoogleFonts.inter(
                    fontSize: 11, color: _muted, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: bars.map((b) => _BarCol(bar: b)).toList(),
          ),
        ],
      ),
    );
  }
}

class _BarCol extends StatelessWidget {
  final _DayBar bar;
  const _BarCol({required this.bar});

  @override
  Widget build(BuildContext context) {
    final c = bar.status.isEmpty ? const Color(0xFFE2E8F0) : _statusColor(bar.status);
    final fillH = bar.status.isEmpty ? 0.0 : (bar.status == 'present' ? 1.0 :
                   bar.status == 'late' ? 0.6 : bar.status == 'leave' ? 0.5 : 0.3);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(99),
          ),
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: fillH,
            child: Container(
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(bar.label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: bar.isToday ? FontWeight.w800 : FontWeight.w500,
                color: bar.isToday ? _primary : _muted)),
      ],
    );
  }
}

// ── Log card ──────────────────────────────────────────────────────────────────
class _LogCard extends StatelessWidget {
  final Map<String, dynamic> record;
  const _LogCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final status  = (record['status'] as String? ?? '').toLowerCase();
    final dateStr = record['date'] as String? ?? '';
    final remarks = record['remarks'] as String? ?? '';
    final c       = _statusColor(status);
    final label   = _statusLabel(status);

    DateTime? date;
    try { date = DateTime.parse(dateStr); } catch (_) {}

    final displayDate = date != null
        ? DateFormat('EEE, d MMM').format(date)
        : dateStr;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        // Status dot
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          child: Icon(_statusIcon(status), color: Colors.white, size: 14),
        ),
        const SizedBox(width: 10),
        // Date + time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayDate,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _fg)),
              if (remarks.isNotEmpty)
                Text(remarks,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _muted)),
            ],
          ),
        ),
        // Status label
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c)),
          ],
        ),
      ]),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: _danger, size: 48),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: _fg)),
        ]),
      ),
    );
  }
}
