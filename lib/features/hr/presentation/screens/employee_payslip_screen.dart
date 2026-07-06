// lib/features/hr/presentation/screens/employee_payslip_screen.dart
//
// Employee Payslip Screen — Self-service view for employees
// Shows payslips sent by HR after payroll disbursement
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _green    = Color(0xFF25BC5F);
const Color _greenDk  = Color(0xFF065F46);
const Color _greenLt  = Color(0xFFD1FAE5);
const Color _blue     = Color(0xFF2563EB);
const Color _blueLt   = Color(0xFFEFF6FF);
const Color _orange   = Color(0xFFF97316);
const Color _red      = Color(0xFFDC2626);
const Color _bg       = Color(0xFFF7F9FC);
const Color _card     = Color(0xFFFFFFFF);
const Color _border   = Color(0x14000000);
const Color _fg       = Color(0xFF0F172A);
const Color _muted    = Color(0xFF94A3B8);

class EmployeePayslipScreen extends StatefulWidget {
  const EmployeePayslipScreen({super.key});

  @override
  State<EmployeePayslipScreen> createState() => _EmployeePayslipScreenState();
}

class _EmployeePayslipScreenState extends State<EmployeePayslipScreen> {
  String _cid       = '';
  String _uid       = '';
  String _realEmail = '';
  final _money = NumberFormat.currency(locale: 'en', symbol: '৳', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Strips the +CID suffix from a namespaced auth email.
  static String _stripCidSuffix(String authEmail, String cid) {
    final marker = '+$cid@';
    final idx = authEmail.indexOf(marker);
    if (idx < 0) return authEmail;
    final local  = authEmail.substring(0, idx);
    final domain = authEmail.substring(idx + marker.length);
    return '$local@$domain';
  }

  Future<void> _init() async {
    final id      = await LocalStorageService.getSavedCompanyId();
    final session = await LocalStorageService.getSession();
    final user    = FirebaseAuth.instance.currentUser;
    final uid     = user?.uid ?? '';
    final cid     = id ?? '';

    // Resolve real email: prefer session email, else strip +CID suffix
    String realEmail = (session?['email'] as String?)?.trim() ?? '';
    if (realEmail.isEmpty && user?.email != null && cid.isNotEmpty) {
      realEmail = _stripCidSuffix(user!.email!, cid);
    }

    if (mounted) setState(() { _cid = cid; _uid = uid; _realEmail = realEmail; });
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    final dt = ts is Timestamp ? ts.toDate() : DateTime.tryParse(ts.toString());
    if (dt == null) return '—';
    return DateFormat('d MMM yyyy, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        foregroundColor: _fg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Payslips',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800, fontSize: 18, color: _fg)),
      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _green))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Order by createdAt so payslips with sentAt=null are still shown
              stream: _uid.isNotEmpty
                  ? DB.colSync(_cid, 'payslips')
                      .where('employeeUid', isEqualTo: _uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots()
                  : _realEmail.isNotEmpty
                      ? DB.colSync(_cid, 'payslips')
                          .where('officeEmail', isEqualTo: _realEmail)
                          .orderBy('createdAt', descending: true)
                          .snapshots()
                      : const Stream.empty(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _green));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No payslips yet',
                    subtitle:
                        'Your payslips will appear here once HR sends them after payroll is processed.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _PayslipCard(
                    doc: docs[i],
                    money: _money,
                    num: _num,
                    initials: _initials,
                    formatDate: _formatDate,
                  ),
                );
              },
            ),
    );
  }
}

// ── Payslip Card ──────────────────────────────────────────────────────────────
class _PayslipCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final NumberFormat money;
  final double Function(dynamic) num;
  final String Function(String) initials;
  final String Function(dynamic) formatDate;

  const _PayslipCard({
    required this.doc,
    required this.money,
    required this.num,
    required this.initials,
    required this.formatDate,
  });

  @override
  State<_PayslipCard> createState() => _PayslipCardState();
}

class _PayslipCardState extends State<_PayslipCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m        = widget.doc.data();
    final name     = (m['employeeName'] ?? 'Employee').toString();
    final dept     = (m['department']   ?? '').toString();
    final period   = (m['period'] ?? m['month'] ?? '').toString();
    final photo    = (m['profilePhotoUrl'] ?? '').toString();
    final gross    = widget.num(m['grossSalary'] ?? m['basicSalary']);
    final bonus    = widget.num(m['bonus']);
    final loan     = widget.num(m['loanDeduction'] ?? m['deductions']);
    final net      = widget.num(m['netSalary']);
    final sentAt   = m['sentAt'];
    final extras   = (m['extraDeductions'] as List?)?.cast<Map>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _greenLt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _green.withValues(alpha: 0.2), width: 1.5),
                ),
                child: photo.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(photo, fit: BoxFit.cover))
                    : Center(
                        child: Text(widget.initials(name),
                            style: GoogleFonts.inter(
                                color: _greenDk,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _fg)),
                    const SizedBox(height: 2),
                    Text(dept.isNotEmpty ? dept : 'Employee',
                        style: GoogleFonts.inter(
                            color: _muted, fontSize: 12)),
                  ],
                ),
              ),
              // Period badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _blueLt,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: _blue.withValues(alpha: 0.25)),
                ),
                child: Text(period,
                    style: GoogleFonts.inter(
                        color: _blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Net Pay hero ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF25BC5F), Color(0xFF065F46)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Net Pay',
                        style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(widget.money.format(net),
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: Colors.white70, size: 20),
                    const SizedBox(height: 4),
                    Text('Paid',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Summary row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _SummaryCell(
                  label: 'GROSS',
                  value: widget.money.format(gross),
                  color: _fg),
              _SummaryCell(
                  label: 'BONUS',
                  value: bonus > 0 ? '+${widget.money.format(bonus)}' : '৳0',
                  color: bonus > 0 ? _green : _muted),
              _SummaryCell(
                  label: 'DEDUCTION',
                  value: loan > 0 ? '-${widget.money.format(loan)}' : '৳0',
                  color: loan > 0 ? _red : _muted),
            ]),
          ),

          // ── Expand toggle ────────────────────────────────────────────────
          if (extras.isNotEmpty || true) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(children: [
                  Text(_expanded ? 'Hide details' : 'View details',
                      style: GoogleFonts.inter(
                          color: _blue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _blue,
                    size: 18,
                  ),
                ]),
              ),
            ),
          ],

          // ── Expanded detail ──────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Earnings',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _fg)),
                  const SizedBox(height: 8),
                  _DetailRow(
                      label: 'Base Salary',
                      value: widget.money.format(gross),
                      color: _fg),
                  if (bonus > 0)
                    _DetailRow(
                        label: 'Bonus',
                        value: '+${widget.money.format(bonus)}',
                        color: _green),
                  if (loan > 0 || extras.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Deductions',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _fg)),
                    const SizedBox(height: 8),
                  ],
                  if (loan > 0)
                    _DetailRow(
                        label: 'Loan EMI',
                        value: '-${widget.money.format(loan)}',
                        color: _red),
                  ...extras.map((ex) => _DetailRow(
                        label: (ex['label'] ?? 'Deduction').toString(),
                        value: '-${widget.money.format(
                            double.tryParse(ex['amount']?.toString() ?? '0') ?? 0)}',
                        color: _orange,
                      )),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: _border),
                  const SizedBox(height: 10),
                  _DetailRow(
                      label: 'Net Pay',
                      value: widget.money.format(net),
                      color: _green,
                      bold: true),
                ],
              ),
            ),
          ],

          // ── Footer ───────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.schedule_rounded,
                  size: 13, color: _muted),
              const SizedBox(width: 5),
              Text('Sent ${widget.formatDate(sentAt)}',
                  style: GoogleFonts.inter(
                      color: _muted, fontSize: 11)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Summary Cell ──────────────────────────────────────────────────────────────
class _SummaryCell extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryCell(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(label,
            style: GoogleFonts.inter(
                color: _muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 3),
        FittedBox(
          child: Text(value,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color)),
        ),
      ]),
    );
  }
}

// ── Detail Row ────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _DetailRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: bold ? _fg : _muted,
                  fontSize: 13,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w500)),
          Text(value,
              style: GoogleFonts.inter(
                  color: color,
                  fontSize: 13,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 34, color: _green),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 16, color: _fg)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _muted, fontSize: 13)),
        ]),
      ),
    );
  }
}
