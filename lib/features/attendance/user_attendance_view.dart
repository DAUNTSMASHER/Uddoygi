// lib/features/attendance/user_attendance_view.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg        = Color(0xFFF8FAF9);
const _primary   = Color(0xFF166534); // Darker Green from inspiration
const _accent    = Color(0xFF22C55E); // Bright Green for button ring
const _card      = Color(0xFFFFFFFF);
const _fg        = Color(0xFF1F2937);
const _muted     = Color(0xFF6B7280);
const _success   = Color(0xFF10B981);
const _warning   = Color(0xFFF59E0B);
const _danger    = Color(0xFFEF4444);
const _info      = Color(0xFF3B82F6);
const _border    = Color(0xFFE2E8F0);

Color _statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'present': return _success;
    case 'late':    return _warning;
    case 'absent':  return _danger;
    case 'leave':   return _info;
    default:        return _muted;
  }
}

String _statusLabel(String s) {
  if (s.isEmpty) return '—';
  return s[0].toUpperCase() + s.substring(1);
}

IconData _statusIcon(String s) {
  switch (s.toLowerCase()) {
    case 'present': return Icons.check_rounded;
    case 'late':    return Icons.watch_later_rounded;
    case 'absent':  return Icons.close_rounded;
    case 'leave':   return Icons.beach_access_rounded;
    default:        return Icons.help_outline_rounded;
  }
}

class UserAttendanceView extends StatefulWidget {
  final String? employeeId;
  const UserAttendanceView({super.key, this.employeeId});

  @override
  State<UserAttendanceView> createState() => _UserAttendanceViewState();
}

class _UserAttendanceViewState extends State<UserAttendanceView> {
  String  _cid        = '';
  String? _employeeId;
  String? _userName;
  String? _profilePhoto;
  bool    _loading    = true;
  String? _error;

  late Timer _clockTimer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
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
    await _resolveEmployee();
  }

  Future<void> _resolveEmployee() async {
    try {
      if (widget.employeeId != null) {
        setState(() {
          _employeeId = widget.employeeId;
          _loading    = false;
        });
        // We might also want to fetch their name/photo here if we had the UID
        return;
      }
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() { _error = 'Not logged in.'; _loading = false; });
        return;
      }

      final doc = await DB.colSync(_cid, C.users).doc(user.uid).get();
      if (doc.exists) {
        final d = doc.data()!;
        if (mounted) {
          setState(() {
            _employeeId = (d['employeeId'] ?? user.uid).toString();
            _userName   = (d['fullName'] ?? d['name'] ?? 'Employee').toString();
            _profilePhoto = (d['profilePhotoUrl'] ?? '').toString();
            _loading    = false;
          });
        }
      } else {
        setState(() { _error = 'Profile not found.'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: Center(child: Text(_error!)));

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── Header (Title + Clock) ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Column(
                children: [
                  Text('Dashboard', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: _fg)),
                  const SizedBox(height: 24),
                  Text(DateFormat('HH:mm:ss').format(_now), 
                    style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.w800, color: _primary)),
                  Text(DateFormat('MMM dd yyyy EEEE').format(_now), 
                    style: GoogleFonts.outfit(fontSize: 14, color: _muted)),
                ],
              ),
            ),
          ),

          // ── Circular Check-In Button ──────────────────────────────────
          SliverToBoxAdapter(
            child: StreamBuilder<Map<String, dynamic>?>(
              stream: _todayStream(),
              builder: (context, snap) {
                final data = snap.data;
                final checkIn = data?['checkIn'];
                final checkOut = data?['checkOut'];
                
                return Column(
                  children: [
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 180, height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _accent.withOpacity(0.2), width: 12),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.touch_app_outlined, color: Colors.white, size: 40),
                              const SizedBox(height: 8),
                              Text(checkIn == null ? 'Check In' : (checkOut == null ? 'Check Out' : 'Done'),
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                            ],
                          ),
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: Colors.white24),
                    
                    const SizedBox(height: 40),
                    // Stats Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatIconItem(
                            icon: Icons.login_rounded, 
                            label: 'Check In', 
                            value: checkIn != null ? DateFormat('hh:mm a').format((checkIn as Timestamp).toDate()) : '--:--'
                          ),
                          _StatIconItem(
                            icon: Icons.logout_rounded, 
                            label: 'Check Out', 
                            value: checkOut != null ? DateFormat('hh:mm a').format((checkOut as Timestamp).toDate()) : '--:--'
                          ),
                          _StatIconItem(
                            icon: Icons.schedule_rounded, 
                            label: 'Total Hrs', 
                            value: '08:45' // Mocked for UI
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Announcements Section ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Announcement's", 
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: _fg)),
                  const SizedBox(height: 16),
                  UCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Event Related', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: _fg)),
                        const SizedBox(height: 4),
                        Text('Date : 15/Apr/2024 To 20/Apr/2024', style: GoogleFonts.outfit(fontSize: 12, color: _muted)),
                        const SizedBox(height: 2),
                        Text('Event Related Information', style: GoogleFonts.outfit(fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── History Button Link ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: UCard(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceHistoryPage(cid: _cid, empId: _employeeId!))),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: _primary),
                    const SizedBox(width: 16),
                    Text('View Attendance History', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: _fg)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: _muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
      bottomNavigationBar: _BottomNav(),
    );
  }
}

class _StatIconItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatIconItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: _primary, size: 28),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: _fg, fontSize: 13)),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: _muted)),
      ],
    );
  }
}

class AttendanceHistoryPage extends StatelessWidget {
  final String cid;
  final String empId;
  const AttendanceHistoryPage({required this.cid, required this.empId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('Attendance History', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: _fg)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _fg,
      ),
      body: Column(
        children: [
          // Month Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.chevron_left_rounded, color: _muted),
                  Text('April 2024', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: _fg)),
                  const Icon(Icons.chevron_right_rounded, color: _muted),
                ],
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _HistoryCard(date: '10/Mar/2024', totalHours: '09:00', records: [
                  {'in': '09:00:00', 'out': '18:00:00', 'total': '09:00 hours'}
                ]),
                _HistoryCard(date: '21/Mar/2024', totalHours: '11:20', records: [
                  {'in': '03:36:00', 'out': '14:48:16', 'total': '11:12 hours'},
                  {'in': '03:45:00', 'out': '03:53:00', 'total': '00:08 hours'},
                  {'in': '18:54:00', 'out': '18:54:00', 'total': '00:00 hours'},
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String date;
  final String totalHours;
  final List<Map<String, String>> records;
  const _HistoryCard({required this.date, required this.totalHours, required this.records});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey[200]!)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: _primary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date: $date', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('Total Hours : $totalHours', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
              ...records.map((r) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _HistBit(icon: Icons.login_rounded, label: 'Check In', value: r['in']!),
                        _HistBit(icon: Icons.logout_rounded, label: 'Check Out', value: r['out']!),
                        _HistBit(icon: Icons.timer_outlined, label: 'Total Hrs', value: r['total']!),
                      ],
                    ),
                  ),
                  if (records.indexOf(r) < records.length - 1) Divider(height: 1, color: Colors.grey[100]),
                ],
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistBit extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _HistBit({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: _primary, size: 20),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: _fg, fontSize: 11)),
        Text(label, style: GoogleFonts.outfit(fontSize: 10, color: _muted)),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavIcon(icon: Icons.home_rounded, active: true),
          _NavIcon(icon: Icons.assignment_outlined),
          _NavIcon(icon: Icons.access_time_rounded),
          _NavIcon(icon: Icons.person_outline_rounded),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  const _NavIcon({required this.icon, this.active = false});
  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: active ? _primary : _muted, size: 28);
  }
}

class _RecordItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _RecordItem({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: UCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: _primary, size: 20),
            const SizedBox(width: 16),
            Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: _fg)),
            const Spacer(),
            Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: _fg)),
          ],
        ),
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
          Icon(Icons.error_outline_rounded, color: _danger, size: 48),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: _fg)),
        ]),
      ),
    );
  }
}
