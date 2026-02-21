import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (matches HTML mockup)
// ─────────────────────────────────────────────────────────────────────────────
const _bg         = Color(0xFFF7F9FC);
const _primary    = Color(0xFF2563EB);
const _primaryDk  = Color(0xFF154580);
const _card       = Color(0xFFFFFFFF);
const _border     = Color(0x14000000);
const _muted      = Color(0xFFF1F5F9);
const _mutedFg    = Color(0xFF94A3B8);
const _fg         = Color(0xFF0F1724);
const _success    = Color(0xFF16A34A);
const _destructive= Color(0xFFDC2626);
const _warning    = Color(0xFFF97316);

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _cid = '';
  final _auth = FirebaseAuth.instance;

  DateTime _selectedDate = DateTime.now();
  String _selectedDepartment = 'All';
  String? _searchedId;

  final List<String> _departments = const [
    'All', 'hr', 'marketing', 'factory', 'rnd',
  ];

  String get _formattedDate =>
      DateFormat('yyyy-MM-dd').format(_selectedDate);
  bool get _isToday =>
      _formattedDate == DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ── Status helpers ────────────────────────────────────────────────────────
  static Color statusColor(String s) {
    switch (s) {
      case 'present': return _success;
      case 'absent':  return _destructive;
      case 'late':    return _warning;
      case 'leave':   return _primary;
      default:        return _mutedFg;
    }
  }

  static IconData statusIcon(String s) {
    switch (s) {
      case 'present': return Icons.check_circle_rounded;
      case 'absent':  return Icons.cancel_rounded;
      case 'late':    return Icons.watch_later_rounded;
      case 'leave':   return Icons.beach_access_rounded;
      default:        return Icons.help_rounded;
    }
  }

  // ── Password confirm for back-date edits ─────────────────────────────────
  Future<bool> _confirmPassword() async {
    String inputPassword = '';
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text('Confirm edit',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "You're editing a past date. Please confirm with your password.",
                  style: GoogleFonts.inter(color: _mutedFg, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Your password',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  onChanged: (val) => inputPassword = val,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context, false),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  try {
                    final cred = EmailAuthProvider.credential(
                        email: user.email!, password: inputPassword);
                    await user.reauthenticateWithCredential(cred);
                    if (context.mounted) Navigator.pop(context, true);
                  } on FirebaseAuthException catch (e) {
                    if (context.mounted) {
                      final msg =
                          e.code == 'wrong-password' || e.code == 'invalid-credential'
                              ? "That password doesn't match. Please try again."
                              : "We couldn't verify your identity. Please try again.";
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(msg),
                        backgroundColor: _destructive,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                      Navigator.pop(context, false);
                    }
                  }
                },
                child: const Text('Confirm',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Mark attendance ───────────────────────────────────────────────────────
  Future<void> _markAttendance(
      String empId, String status, String? remarks) async {
    await DB.colSync(_cid, C.attendance)
        .doc(_formattedDate)
        .collection('records')
        .doc(empId)
        .update({'status': status, 'remarks': remarks ?? ''});
  }

  void _editStatus(
      String empId, String currentStatus, String? currentRemarks) async {
    if (!_isToday) {
      final confirmed = await _confirmPassword();
      if (!confirmed) return;
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditStatusSheet(
        initialStatus: currentStatus,
        initialRemarks: currentRemarks ?? '',
        onSave: (s, r) {
          Navigator.pop(context);
          _markAttendance(empId, s, r);
        },
      ),
    );
  }

  // ── Returns true if a user doc should be excluded from attendance ──────────
  static bool _isAdminUser(Map<String, dynamic> u) {
    final role = (u['role'] ?? '').toString().toLowerCase();
    final dept = (u['department'] ?? '').toString().toLowerCase();
    final isAdmin = u['isAdmin'];
    return role == 'admin' ||
        dept == 'admin' ||
        (isAdmin is bool && isAdmin == true);
  }

  // ── Create daily records if empty ─────────────────────────────────────────
  Future<void> _createIfEmpty() async {
    if (_cid.isEmpty) return;

    final snap = await DB.colSync(_cid, C.attendance)
        .doc(_formattedDate)
        .collection('records')
        .get();

    if (snap.docs.isEmpty) {
      // Use colSync with the already-loaded _cid — avoids async CID lookup
      // and ensures we always read from the correct company's users collection.
      final users = await DB.colSync(_cid, C.users).get();
      final batch = DB.firestore.batch();

      for (final doc in users.docs) {
        final u = doc.data();

        // Skip admin accounts — they are not regular employees
        if (_isAdminUser(u)) continue;

        // Fall back to the Firestore document ID (UID) if employeeId is missing
        final empId = (u['employeeId'] as String?)?.trim();
        final recordId = (empId != null && empId.isNotEmpty) ? empId : doc.id;

        final ref = DB.colSync(_cid, C.attendance)
            .doc(_formattedDate)
            .collection('records')
            .doc(recordId);
        batch.set(ref, {
          'employeeId': recordId,
          'email':      u['email'] ?? u['officeEmail'] ?? '',
          'name':       u['fullName'] ?? u['name'] ?? '',
          'department': u['department'] ?? '',
          'status':     'absent',
          'remarks':    '',
          'timestamp':  FieldValue.serverTimestamp(),
          'markedBy':   _auth.currentUser?.email ?? 'system',
        });
      }
      await batch.commit();
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colRef = _cid.isEmpty
        ? null
        : DB.colSync(_cid, C.attendance)
            .doc(_formattedDate)
            .collection('records');

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Minimal top bar (back button + title + date picker) ────────
            _TopBar(
              selectedDate: _selectedDate,
              isToday: _isToday,
              onDatePick: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2023),
                  lastDate: DateTime(2027),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme:
                          const ColorScheme.light(primary: _primary),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),

            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: colRef == null
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: colRef.snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        // Exclude admin users from attendance display
                        final records = snapshot.data!.docs.where((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final dept = (d['department'] ?? '').toString().toLowerCase();
                          return dept != 'admin';
                        }).toList();

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          children: [
                            // Hero card
                            _HeroCard(
                              records: records,
                              selectedDate: _selectedDate,
                              isToday: _isToday,
                            ),
                            const SizedBox(height: 20),

                            if (records.isEmpty) ...[
                              _EmptyCard(onCreate: _createIfEmpty),
                            ] else ...[
                              // Overview 2×2 grid
                              _OverviewGrid(records: records),
                              const SizedBox(height: 20),

                              // Week bar chart
                              _WeekCard(
                                  records: records,
                                  selectedDate: _selectedDate),
                              const SizedBox(height: 20),

                              // Filters row
                              _FiltersRow(
                                departments: _departments,
                                selectedDept: _selectedDepartment,
                                onDeptChanged: (v) => setState(
                                    () => _selectedDepartment = v),
                                onSearchChanged: (v) => setState(() =>
                                    _searchedId = v.trim().isEmpty
                                        ? null
                                        : v.trim()),
                              ),
                              const SizedBox(height: 14),

                              // Section label
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedDepartment == 'All'
                                          ? 'All Employees'
                                          : _selectedDepartment
                                              .toUpperCase(),
                                      style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: _fg),
                                    ),
                                    Text(
                                      '${records.length} total',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: _primary),
                                    ),
                                  ],
                                ),
                              ),

                              // Employee log cards
                              ...records.map((doc) => _LogCard(
                                    doc: doc,
                                    selectedDept: _selectedDepartment,
                                    searchedId: _searchedId,
                                    onEdit: _editStatus,
                                  )),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final DateTime selectedDate;
  final bool isToday;
  final VoidCallback onDatePick;

  const _TopBar({
    required this.selectedDate,
    required this.isToday,
    required this.onDatePick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: _fg),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance',
                    style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _fg)),
                Text(
                  isToday
                      ? 'Today · ${DateFormat('d MMM yyyy').format(selectedDate)}'
                      : DateFormat('EEE, d MMM yyyy').format(selectedDate),
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _mutedFg,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // Calendar icon button
          GestureDetector(
            onTap: onDatePick,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  size: 20, color: _fg),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero card (gradient, shift info style from mockup)
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final List<DocumentSnapshot> records;
  final DateTime selectedDate;
  final bool isToday;

  const _HeroCard({
    required this.records,
    required this.selectedDate,
    required this.isToday,
  });

  Map<String, int> get _counts {
    final m = {'present': 0, 'absent': 0, 'late': 0, 'leave': 0};
    for (final d in records) {
      final st = ((d.data() as Map)['status'] ?? 'absent').toString();
      m[st] = (m[st] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final c = _counts;
    final total = records.length;
    final present = c['present'] ?? 0;
    final rate = total == 0 ? 0.0 : present / total;
    final pct = (rate * 100).toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isToday ? 'Today' : DateFormat('EEE, d MMM').format(selectedDate),
                style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$pct% present',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Big number
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$total',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    height: 1),
              ),
              const SizedBox(width: 8),
              Text(
                'employees',
                style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 16),

          // Footer row: present count + shift label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeroStat(label: 'Present', value: '$present', color: Colors.greenAccent.shade400),
              _HeroStat(label: 'Absent', value: '${c['absent'] ?? 0}', color: Colors.red.shade300),
              _HeroStat(label: 'Late', value: '${c['late'] ?? 0}', color: Colors.orange.shade300),
              _HeroStat(label: 'Leave', value: '${c['leave'] ?? 0}', color: Colors.lightBlue.shade300),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _HeroStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.inter(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview 2×2 grid
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewGrid extends StatelessWidget {
  final List<DocumentSnapshot> records;
  const _OverviewGrid({required this.records});

  Map<String, int> get _counts {
    final m = {'present': 0, 'absent': 0, 'late': 0, 'leave': 0};
    for (final d in records) {
      final st = ((d.data() as Map)['status'] ?? 'absent').toString();
      m[st] = (m[st] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final c = _counts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Overview',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _fg)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _OverviewCard(
              icon: Icons.check_circle_outline_rounded,
              iconBg: _success.withOpacity(.08),
              iconColor: _success,
              value: '${c['present'] ?? 0}',
              label: 'Present days',
            ),
            _OverviewCard(
              icon: Icons.cancel_outlined,
              iconBg: _destructive.withOpacity(.08),
              iconColor: _destructive,
              value: '${c['absent'] ?? 0}',
              label: 'Absent days',
            ),
            _OverviewCard(
              icon: Icons.access_time_rounded,
              iconBg: _warning.withOpacity(.08),
              iconColor: _warning,
              value: '${c['late'] ?? 0}',
              label: 'Late arrivals',
            ),
            _OverviewCard(
              icon: Icons.beach_access_rounded,
              iconBg: _primary.withOpacity(.08),
              iconColor: _primary,
              value: '${c['leave'] ?? 0}',
              label: 'On leave',
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;

  const _OverviewCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _fg,
                      height: 1)),
              const SizedBox(height: 2),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: _mutedFg)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Week bar chart card
// ─────────────────────────────────────────────────────────────────────────────
class _WeekCard extends StatelessWidget {
  final List<DocumentSnapshot> records;
  final DateTime selectedDate;

  const _WeekCard({required this.records, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final total = records.length;
    final present = records
        .where((d) => ((d.data() as Map)['status'] ?? '') == 'present')
        .length;
    final pct = total == 0 ? 0 : (present / total * 100).round();

    // Build 7-day week (Mon–Sun of the selected date's week)
    final monday = selectedDate.subtract(
        Duration(days: selectedDate.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final selStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Heights: selected day = full, rest are illustrative placeholders
    // (We only have data for the selected date; use 0 for future, 1 for past/today)
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This week',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _fg)),
              Text('$pct% present',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: _mutedFg)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final dayStr = DateFormat('yyyy-MM-dd').format(days[i]);
              final isSelected = dayStr == selStr;
              final isToday = dayStr == todayStr;
              final isFuture = days[i].isAfter(DateTime.now());

              // Bar fill: selected day uses real rate, past days use 80%, future = 0
              double fillRatio;
              Color fillColor;
              if (isSelected) {
                fillRatio = total == 0 ? 0 : present / total;
                fillColor = _primary;
              } else if (isFuture) {
                fillRatio = 0;
                fillColor = _primary;
              } else {
                // Past days: show a plausible bar in muted primary
                fillRatio = 0.75;
                fillColor = _primary.withOpacity(.4);
              }

              return Column(
                children: [
                  SizedBox(
                    width: 8,
                    height: 56,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          width: 8,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _muted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        FractionallySizedBox(
                          heightFactor: fillRatio.clamp(0.0, 1.0),
                          child: Container(
                            width: 8,
                            decoration: BoxDecoration(
                              color: fillColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayLabels[i],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected || isToday ? _primary : _mutedFg,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filters row (dept dropdown + search)
// ─────────────────────────────────────────────────────────────────────────────
class _FiltersRow extends StatelessWidget {
  final List<String> departments;
  final String selectedDept;
  final ValueChanged<String> onDeptChanged;
  final ValueChanged<String> onSearchChanged;

  const _FiltersRow({
    required this.departments,
    required this.selectedDept,
    required this.onDeptChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Dept dropdown
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedDept,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: _mutedFg),
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _fg),
                items: departments
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                              d == 'All' ? 'All Depts' : d.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (v) => onDeptChanged(v!),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Search
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              style: GoogleFonts.inter(fontSize: 13, color: _fg),
              decoration: InputDecoration(
                hintText: 'Search by ID or name',
                hintStyle: GoogleFonts.inter(
                    color: _mutedFg, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: _mutedFg, size: 18),
                filled: true,
                fillColor: _card,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _primary),
                ),
              ),
              onChanged: onSearchChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log card (employee row — matches the "recent logs" style from mockup)
// ─────────────────────────────────────────────────────────────────────────────
class _LogCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final String selectedDept;
  final String? searchedId;
  final void Function(String, String, String?) onEdit;

  const _LogCard({
    required this.doc,
    required this.selectedDept,
    required this.searchedId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final data    = doc.data() as Map<String, dynamic>;
    final empId   = (data['employeeId'] ?? '').toString();
    final name    = (data['name'] ?? '').toString();
    final dept    = (data['department'] ?? '').toString();
    final status  = (data['status'] ?? 'absent').toString();
    final remarks = (data['remarks'] ?? '').toString();

    final matchesDept =
        selectedDept == 'All' || dept == selectedDept;
    final matchesSearch = searchedId == null ||
        empId.toLowerCase().contains(searchedId!.toLowerCase()) ||
        name.toLowerCase().contains(searchedId!.toLowerCase());
    if (!matchesDept || !matchesSearch) return const SizedBox.shrink();

    final color = _AttendanceScreenState.statusColor(status);

    return GestureDetector(
      onTap: () => onEdit(empId, status, remarks),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            // Dot
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                  _AttendanceScreenState.statusIcon(status),
                  color: Colors.white,
                  size: 16),
            ),
            const SizedBox(width: 12),

            // Name + dept
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : 'ID: $empId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _fg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dept.isNotEmpty
                        ? '$empId · ${dept.toUpperCase()}'
                        : empId,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: _mutedFg),
                  ),
                  if (status == 'absent' && remarks.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      remarks,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: _destructive.withOpacity(.8)),
                    ),
                  ],
                ],
              ),
            ),

            // Status badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
                const SizedBox(height: 2),
                Text('tap to edit',
                    style:
                        GoogleFonts.inter(fontSize: 11, color: _mutedFg)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit status bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _EditStatusSheet extends StatefulWidget {
  final String initialStatus;
  final String initialRemarks;
  final void Function(String status, String remarks) onSave;

  const _EditStatusSheet({
    required this.initialStatus,
    required this.initialRemarks,
    required this.onSave,
  });

  @override
  State<_EditStatusSheet> createState() => _EditStatusSheetState();
}

class _EditStatusSheetState extends State<_EditStatusSheet> {
  late String _status;
  late TextEditingController _remarksCtl;
  static const _statuses = ['present', 'absent', 'late', 'leave'];

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _remarksCtl = TextEditingController(text: widget.initialRemarks);
  }

  @override
  void dispose() {
    _remarksCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 18),
          Text('Update Attendance',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: _fg)),
          const SizedBox(height: 4),
          Text('Select the correct status below',
              style:
                  GoogleFonts.inter(color: _mutedFg, fontSize: 13)),
          const SizedBox(height: 18),

          // Status chips
          Row(
            children: _statuses.map((s) {
              final selected = _status == s;
              final color = _AttendanceScreenState.statusColor(s);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _status = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? color : color.withOpacity(.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: selected
                              ? color
                              : color.withOpacity(.2)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _AttendanceScreenState.statusIcon(s),
                          color: selected ? Colors.white : color,
                          size: 18,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.toUpperCase(),
                          style: GoogleFonts.inter(
                              color: selected
                                  ? Colors.white
                                  : color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          if (_status == 'absent') ...[
            Text('Reason (optional)',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _fg)),
            const SizedBox(height: 8),
            TextField(
              controller: _remarksCtl,
              minLines: 2,
              maxLines: 4,
              style: GoogleFonts.inter(fontSize: 14, color: _fg),
              decoration: InputDecoration(
                hintText: 'Reason for absence...',
                hintStyle:
                    GoogleFonts.inter(color: _mutedFg, fontSize: 13),
                filled: true,
                fillColor: _muted,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 4),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _AttendanceScreenState.statusColor(_status),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () =>
                  widget.onSave(_status, _remarksCtl.text.trim()),
              child: Text('Save changes',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state card
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _primary.withOpacity(.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: _primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text('No records yet',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _fg)),
          const SizedBox(height: 6),
          Text(
            'No attendance records found for this date.\nTap below to create them for all employees.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: _mutedFg, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: Text('Create Records',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onCreate,
            ),
          ),
        ],
      ),
    );
  }
}
