// lib/features/hr/presentation/screens/add_payroll_screen.dart
//
// Add Payroll Screen
// Lists all company employees. Tapping one either opens their existing payroll
// record for the current period (in EditPayrollScreen) or creates a fresh one
// and then opens it.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'edit_payroll_screen.dart';

// ── Palette (matches payroll screens) ────────────────────────────────────────
const Color _green   = Color(0xFF25BC5F);
const Color _greenDk = Color(0xFF065F46);
const Color _greenLt = Color(0xFFD1FAE5);
const Color _bg      = Color(0xFFF7F9FC);
const Color _card    = Color(0xFFFFFFFF);
const Color _border  = Color(0x14000000);
const Color _fg      = Color(0xFF0F172A);
const Color _muted   = Color(0xFF94A3B8);

class AddPayrollScreen extends StatefulWidget {
  const AddPayrollScreen({super.key});

  @override
  State<AddPayrollScreen> createState() => _AddPayrollScreenState();
}

class _AddPayrollScreenState extends State<AddPayrollScreen> {
  String _cid    = '';
  String _search = '';
  final _searchCtl = TextEditingController();

  String get _currentPeriod => DateFormat('MMMM yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  // ── Open or create payroll record then push to EditPayrollScreen ──────────
  Future<void> _openPayroll(Map<String, dynamic> emp, String uid) async {
    if (_cid.isEmpty) return;

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _green),
      ),
    );

    try {
      final payrollCol = DB.colSync(_cid, C.payrolls);

      // Check for an existing record this period
      final existing = await payrollCol
          .where('employeeUid', isEqualTo: uid)
          .where('period', isEqualTo: _currentPeriod)
          .limit(1)
          .get();

      String docId;

      if (existing.docs.isNotEmpty) {
        docId = existing.docs.first.id;
      } else {
        // Create a fresh payroll document
        final name  = (emp['fullName'] ?? emp['name'] ?? 'Unknown').toString();
        final dept  = (emp['department'] ?? '').toString();
        final photo = (emp['profilePhotoUrl'] ?? '').toString();
        final base  = _toDouble(emp['salary'] ?? emp['baseSalary'] ?? 0);

        // Gap C3: Auto-calculate loan deduction
        double loanDeduction = 0;
        try {
          final loansSnap = await DB.colSync(_cid, C.loans)
              .where('userId', isEqualTo: uid)
              .where('status', isEqualTo: 'disbursed')
              .get();

          double totalOutstanding = 0;
          for (final lDoc in loansSnap.docs) {
            final principal = (lDoc.data()['amount'] as num? ?? 0).toDouble();
            final repaysSnap = await lDoc.reference.collection('repayments').get();
            final repaid = repaysSnap.docs.fold<double>(0, (sum, d) => sum + (d.data()['amount'] as num? ?? 0).toDouble());
            totalOutstanding += (principal - repaid).clamp(0, double.infinity);
          }

          if (totalOutstanding > 0) {
            // Default deduction: 10% of base salary or total outstanding if less
            loanDeduction = (base * 0.1).clamp(0, totalOutstanding);
          }
        } catch (e) {
          print('Error calculating loan deduction: $e');
        }

        final ref = await payrollCol.add({
          'employeeUid':     uid,
          'employeeName':    name,
          'department':      dept,
          'profilePhotoUrl': photo,
          'period':          _currentPeriod,
          'grossSalary':     base,
          'bonus':           0.0,
          'loanDeduction':   loanDeduction,
          'extraDeductions': [],
          'netSalary':       base - loanDeduction,
          'status':          'pending',
          'generatedAt':     FieldValue.serverTimestamp(),
          'updatedAt':       FieldValue.serverTimestamp(),
        });
        docId = ref.id;
      }

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditPayrollScreen(
            docId:  docId,
            cid:    _cid,
            period: _currentPeriod,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Something went wrong. Please try again.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Payroll',
                style: AppFonts.banglaHeading(
                    fontWeight: FontWeight.w800, fontSize: 17, color: _fg)),
            Text(_currentPeriod,
                style: AppFonts.banglaBody(
                    fontSize: 11,
                    color: _muted,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _green))
          : Column(
              children: [
                // ── Search bar ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: TextField(
                    controller: _searchCtl,
                    onChanged: (v) =>
                        setState(() => _search = v.trim().toLowerCase()),
                    style: AppFonts.banglaBody(fontSize: 14, color: _fg),
                    decoration: InputDecoration(
                      hintText: 'Search employee…',
                      hintStyle:
                          AppFonts.banglaBody(color: _muted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: _muted),
                      filled: true,
                      fillColor: _card,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _green, width: 1.5)),
                    ),
                  ),
                ),

                // ── Info banner ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _green.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: _green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select an employee to add or edit their payroll for $_currentPeriod.',
                          style: AppFonts.banglaBody(
                              fontSize: 12,
                              color: _greenDk,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Employee list ──────────────────────────────────────
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: DB.colSync(_cid, C.users).snapshots(),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(color: _green));
                      }

                      var docs = snap.data?.docs ?? [];

                      // Filter out non-employee roles if needed, then search
                      if (_search.isNotEmpty) {
                        docs = docs.where((d) {
                          final m    = d.data();
                          final name = (m['fullName'] ?? m['name'] ?? '')
                              .toString()
                              .toLowerCase();
                          final dept = (m['department'] ?? '')
                              .toString()
                              .toLowerCase();
                          return name.contains(_search) ||
                              dept.contains(_search);
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: _green.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.people_outline,
                                    size: 30, color: _green),
                              ),
                              const SizedBox(height: 14),
                              Text('No employees found',
                                  style: AppFonts.banglaHeading(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: _fg)),
                              const SizedBox(height: 4),
                              Text(
                                  'Add employees first from the Employee Management section.',
                                  textAlign: TextAlign.center,
                                  style: AppFonts.banglaBody(
                                      color: _muted, fontSize: 13)),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: docs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final doc  = docs[i];
                          final emp  = doc.data();
                          final uid  = doc.id;
                          final name = (emp['fullName'] ?? emp['name'] ?? 'Unknown')
                              .toString();
                          final dept =
                              (emp['department'] ?? '').toString();
                          final photo =
                              (emp['profilePhotoUrl'] ?? '').toString();
                          final base = _toDouble(
                              emp['salary'] ?? emp['baseSalary'] ?? 0);

                          return _EmployeeTile(
                            name: name,
                            dept: dept,
                            photo: photo,
                            baseSalary: base,
                            initials: _initials(name),
                            cid: _cid,
                            uid: uid,
                            period: _currentPeriod,
                            onTap: () => _openPayroll(emp, uid),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Employee Tile ─────────────────────────────────────────────────────────────
class _EmployeeTile extends StatelessWidget {
  final String name, dept, photo, initials, cid, uid, period;
  final double baseSalary;
  final VoidCallback onTap;

  const _EmployeeTile({
    required this.name,
    required this.dept,
    required this.photo,
    required this.baseSalary,
    required this.initials,
    required this.cid,
    required this.uid,
    required this.period,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
        locale: 'en', symbol: '৳', decimalDigits: 0);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(cid, C.payrolls)
          .where('employeeUid', isEqualTo: uid)
          .where('period', isEqualTo: period)
          .limit(1)
          .snapshots(),
      builder: (_, snap) {
        final hasRecord =
            snap.hasData && snap.data!.docs.isNotEmpty;
        final status = hasRecord
            ? (snap.data!.docs.first.data()['status'] ?? 'pending')
                .toString()
            : null;

        Color statusColor;
        String statusLabel;
        IconData statusIcon;
        if (status == null) {
          statusColor = _muted;
          statusLabel = 'Not added';
          statusIcon  = Icons.add_circle_outline_rounded;
        } else if (status == 'disbursed') {
          statusColor = _green;
          statusLabel = 'Paid';
          statusIcon  = Icons.check_circle_rounded;
        } else {
          statusColor = const Color(0xFFF97316);
          statusLabel = 'Draft';
          statusIcon  = Icons.edit_note_rounded;
        }

        return Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: hasRecord
                    ? statusColor.withValues(alpha: 0.25)
                    : _border),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x07000000),
                  blurRadius: 6,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(children: [
                  // Avatar
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _greenLt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: photo.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(photo,
                                fit: BoxFit.cover))
                        : Center(
                            child: Text(initials,
                                style: AppFonts.banglaHeading(
                                    color: _greenDk,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                          ),
                  ),
                  const SizedBox(width: 12),

                  // Name + dept
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.banglaHeading(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _fg)),
                        const SizedBox(height: 2),
                        Text(
                          dept.isNotEmpty ? dept : 'Employee',
                          style: AppFonts.banglaBody(
                              color: _muted, fontSize: 12),
                        ),
                        if (baseSalary > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Base: ${money.format(baseSalary)}',
                            style: AppFonts.banglaBody(
                                color: _green,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status badge + arrow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(statusIcon, size: 11, color: statusColor),
                          const SizedBox(width: 4),
                          Text(statusLabel,
                              style: AppFonts.banglaHeading(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10)),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: _muted),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
