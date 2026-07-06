// lib/features/hr/presentation/screens/review_payroll_screen.dart
//
// Review Payroll Screen — Screen 2 of 3
//
// Features:
//   • Select individual employees to pay (checkbox per row)
//   • Already-paid employees are locked — cannot be selected or double-paid
//   • "Pay Selected" pays only the checked employees
//   • Reverse button on each paid employee — undoes the transaction:
//       - Sets status back to 'pending'
//       - Deletes the linked expense + cash_flow entries
//       - Decrements company cashOut total
//   • Period picker to view any month
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'edit_payroll_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _green    = Color(0xFF065F46); // HR Green
const Color _greenDk  = Color(0xFF064E3B); // Deep Green
const Color _greenLt  = Color(0xFFF0FDF4); // Green 50
const Color _orange   = Color(0xFFEA580C); // Warning
const Color _red      = Color(0xFFDC2626); // Error
const Color _bg       = Color(0xFFF8FAFC); // Slate 50
const Color _card     = Color(0xFFFFFFFF);
const Color _border   = Color(0x14000000);
const Color _fg       = Color(0xFF0F172A);
const Color _muted    = Color(0xFF64748B);


class ReviewPayrollScreen extends StatefulWidget {
  final String? initialDocId;
  const ReviewPayrollScreen({super.key, this.initialDocId});
  @override
  State<ReviewPayrollScreen> createState() => _ReviewPayrollScreenState();
}

class _ReviewPayrollScreenState extends State<ReviewPayrollScreen> {
  String _cid    = '';
  String _period = DateFormat('MMMM yyyy').format(DateTime.now());
  final _money   = NumberFormat.currency(locale: 'en', symbol: '৳', decimalDigits: 0);
  bool _saving   = false;

  // Selected (checked) doc IDs for batch payment
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
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

  String get _nextPayday {
    final now = DateTime.now();
    var last = DateTime(now.year, now.month + 1, 0);
    while (last.weekday == DateTime.saturday || last.weekday == DateTime.sunday) {
      last = last.subtract(const Duration(days: 1));
    }
    return DateFormat('MMM d').format(last);
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      helpText: 'Select payroll period',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _green),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _period   = DateFormat('MMMM yyyy').format(picked);
        _selected.clear();
      });
    }
  }

  // ── Select / deselect all unpaid ─────────────────────────────────────────
  void _toggleSelectAll(List<QueryDocumentSnapshot<Map<String, dynamic>>> unpaid) {
    setState(() {
      if (_selected.length == unpaid.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(unpaid.map((d) => d.id));
      }
    });
  }

  // ── Pay selected employees ────────────────────────────────────────────────
  // Each employee gets their OWN expense doc + cash_flow doc so that
  // reversing one employee only removes that employee's records.
  Future<void> _paySelected(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) async {
    if (_cid.isEmpty || _selected.isEmpty) return;

    final toPay = allDocs
        .where((d) =>
            _selected.contains(d.id) &&
            (d.data()['status'] ?? '') != 'disbursed')
        .toList();

    if (toPay.isEmpty) {
      _snack('All selected employees are already paid.', error: true);
      return;
    }

    double selTotal = 0;
    for (final d in toPay) {
      selTotal += _num(d.data()['netSalary']);
    }

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PaymentMethodSheet(
        totalNet: selTotal,
        period: _period,
        employeeCount: toPay.length,
        money: _money,
      ),
    );

    if (result == null || !mounted) return;

    final method    = result['method']    ?? 'Cash';
    final reference = result['reference'] ?? '';
    final notes     = result['notes']     ?? '';

    setState(() => _saving = true);
    try {
      final hrEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final now     = Timestamp.now();
      final batch   = DB.firestore.batch();

      // One expense doc + one cash_flow doc PER employee so each can be
      // independently reversed without affecting other employees.
      for (final d in toPay) {
        final m      = d.data();
        final net    = _num(m['netSalary']);
        final name   = (m['employeeName'] ?? 'Employee').toString();
        final dept   = (m['department']   ?? 'HR').toString();

        final expRef = DB.colSync(_cid, C.expenses).doc();
        final cfRef  = DB.colSync(_cid, C.cashFlow).doc();

        // Mark payroll record disbursed — store per-employee linked doc IDs
        batch.update(d.reference, {
          'status':           'disbursed',
          'disbursedAt':      FieldValue.serverTimestamp(),
          'paymentMethod':    method,
          'paymentReference': reference,
          '_expenseDocId':    expRef.id,
          '_cashFlowDocId':   cfRef.id,
          '_paidBy':          hrEmail,
        });

        // Per-employee expense entry
        batch.set(expRef, {
          'vendor':        'Payroll – $_period',
          'category':      'Payroll',
          'item':          'Salary – $name ($_period)',
          'amount':        net,
          'employeeName':  name,
          'department':    dept,
          'paymentMethod': method,
          'reference':     reference,
          'notes':         notes.isNotEmpty
              ? notes
              : 'Salary disbursement for $name via $method',
          'period':        _period,
          'dueDate':       now,
          'status':        'paid',
          'costCenter':    dept,
          'addedBy':       hrEmail,
          'createdAt':     FieldValue.serverTimestamp(),
          '_payrollDocId': d.id,
          '_reversible':   true,
        });

        // Per-employee cash-flow entry
        batch.set(cfRef, {
          'type':          'cash_out',
          'amount':        net,
          'currency':      'BDT',
          'method':        method,
          'reference':     reference,
          'description':   'Salary – $name ($_period)',
          'category':      'Payroll',
          'department':    dept,
          'employeeName':  name,
          'approvedBy':    hrEmail,
          'date':          now,
          'createdAt':     FieldValue.serverTimestamp(),
          '_payrollDocId': d.id,
          '_reversible':   true,
        });
      }

      // Increment company cashOut by the full batch total
      if (selTotal > 0) {
        batch.update(
          DB.colSync(_cid, C.companyProfile).doc('main'),
          {
            'cashOut':           FieldValue.increment(selTotal),
            'lastCashOutAt':     FieldValue.serverTimestamp(),
            'lastCashOutAmount': selTotal,
            'lastCashOutItem':   'Payroll – $_period',
          },
        );
      }

      await batch.commit();

      if (mounted) {
        setState(() => _selected.clear());
        _snack('Paid ${toPay.length} employee${toPay.length > 1 ? 's' : ''} via $method. Expense recorded.');
      }
    } catch (e) {
      if (mounted) _snack('Payment failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Reverse a single employee's payment ───────────────────────────────────
  // What happens on reversal:
  //   • Payroll record → back to 'pending'
  //   • Linked expense doc → deleted  (expense list shrinks)
  //   • Linked cash_flow doc → deleted (cash-out entry removed)
  //   • A new cash_flow 'reversal' entry is added for audit trail
  //   • cashOut decrements by netSalary  → balance increases
  //   • cashIn is NOT touched (reversal is not income; balance = cashIn - cashOut)
  Future<void> _reverseSingle(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (_cid.isEmpty) return;
    final m      = doc.data();
    final name   = (m['employeeName'] ?? 'this employee').toString();
    final netAmt = _num(m['netSalary']);
    final period = (m['period'] ?? _period).toString();
    final method = (m['paymentMethod'] ?? '').toString();

    // ── Confirmation dialog ──────────────────────────────────────────────
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.undo_rounded, color: _red, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Reverse Payment',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reversing the payroll payment for $name will:',
              style: GoogleFonts.inter(
                  fontSize: 13, color: _fg, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _BulletPoint('Remove the expense entry (${_money.format(netAmt)})'),
            _BulletPoint('Reduce total expenses by ${_money.format(netAmt)}'),
            _BulletPoint('Increase balance by ${_money.format(netAmt)}'),
            _BulletPoint('Mark $name as unpaid again'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                'A reversal record will be kept in the cash-flow history for audit.',
                style: GoogleFonts.inter(
                    fontSize: 11, color: _orange, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reverse',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final hrEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final batch   = DB.firestore.batch();

      // 1. Mark payroll record as reversed — NOT 'pending'.
      //    Using a distinct 'reversed' status prevents this record from being
      //    counted in totals, unpaid lists, or employee counts anywhere.
      batch.update(doc.reference, {
        'status':           'reversed',
        'disbursedAt':      FieldValue.delete(),
        'paymentMethod':    FieldValue.delete(),
        'paymentReference': FieldValue.delete(),
        '_expenseDocId':    FieldValue.delete(),
        '_cashFlowDocId':   FieldValue.delete(),
        '_paidBy':          FieldValue.delete(),
        '_reversedAt':      FieldValue.serverTimestamp(),
        '_reversedBy':      hrEmail,
      });

      // 2. Void the linked expense doc (SOFT DELETE)
      //    Financial records should never be physically deleted for audit integrity.
      final expId = (m['_expenseDocId'] as String?)?.trim() ?? '';
      if (expId.isNotEmpty) {
        batch.update(DB.colSync(_cid, C.expenses).doc(expId), {
          'status': 'voided',
          'voidedAt': FieldValue.serverTimestamp(),
          'voidedBy': hrEmail,
          'reversalNote': 'Linked payroll reversed'
        });
      }

      // 3. Void the linked cash_flow doc (SOFT DELETE)
      final cfId = (m['_cashFlowDocId'] as String?)?.trim() ?? '';
      if (cfId.isNotEmpty) {
        batch.update(DB.colSync(_cid, C.cashFlow).doc(cfId), {
          'status': 'voided',
          'voidedAt': FieldValue.serverTimestamp(),
          'voidedBy': hrEmail,
        });
      }

      // 4. Add a reversal audit entry in cash_flow
      final reversalRef = DB.colSync(_cid, C.cashFlow).doc();
      batch.set(reversalRef, {
        'type':          'reversal',
        'amount':        FinanceUtils.round(netAmt),
        'currency':      'BDT',
        'method':        method,
        'description':   'Payroll reversal – $name ($period)',
        'category':      'Payroll',
        'department':    (m['department'] ?? 'HR').toString(),
        'employeeName':  name,
        'reversedBy':    hrEmail,
        'originalPayrollDocId': doc.id,
        'date':          Timestamp.now(),
        'createdAt':     FieldValue.serverTimestamp(),
      });

      // 5. Atomic Balance Restoration
      if (netAmt > 0) {
        batch.update(
          DB.colSync(_cid, C.companyProfile).doc('main'),
          {
            'cashOut':              FieldValue.increment(-FinanceUtils.round(netAmt)),
            'lastReversalAt':       FieldValue.serverTimestamp(),
            'lastReversalAmount':   FinanceUtils.round(netAmt),
            'lastReversalEmployee': name,
          },
        );
      }


      await batch.commit();
      if (mounted) {
        _snack('Payment reversed for $name. '
            'Expense removed, balance restored by ${_money.format(netAmt)}.');
      }
    } catch (e) {
      if (mounted) _snack('Reverse failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Sends payslips to all disbursed employees for this period.
  Future<void> _sendPayslips(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_cid.isEmpty) return;
    final disbursed =
        docs.where((d) => (d.data()['status'] ?? '') == 'disbursed').toList();
    if (disbursed.isEmpty) {
      _snack('No paid employees to send payslips to.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final batch       = DB.firestore.batch();
      final payslipsCol = DB.colSync(_cid, 'payslips');
      for (final d in disbursed) {
        final m = d.data();
        batch.set(
          payslipsCol.doc(d.id),
          {
            'payrollId':       d.id,
            'employeeUid':     m['employeeUid']     ?? '',
            'employeeId':      m['employeeId']      ?? '',
            'employeeName':    m['employeeName']    ?? '',
            // Store both email fields so the salary screen can find this
            // payslip whether it looks up by UID or by email
            'officeEmail':     m['officeEmail']     ?? m['employeeEmail'] ?? '',
            'email':           m['email']           ?? m['officeEmail']   ?? m['employeeEmail'] ?? '',
            'department':      m['department']      ?? '',
            'profilePhotoUrl': m['profilePhotoUrl'] ?? '',
            'period':          m['period']          ?? _period,
            'grossSalary':     m['grossSalary']     ?? 0,
            'bonus':           m['bonus']           ?? 0,
            'loanDeduction':   m['loanDeduction']   ?? 0,
            'extraDeductions': m['extraDeductions'] ?? [],
            'netSalary':       m['netSalary']       ?? 0,
            'paymentMethod':   m['paymentMethod']   ?? '',
            'status':          'sent',
            'disbursedAt':     m['disbursedAt']     ?? FieldValue.serverTimestamp(),
            'sentAt':          FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        batch.update(d.reference, {'payslipSent': true});
      }
      await batch.commit();
      if (mounted) {
        _snack('Payslips sent to ${disbursed.length} employee${disbursed.length > 1 ? 's' : ''}!');
      }
    } catch (e) {
      if (mounted) _snack('Failed to send payslips: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: Colors.white, size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: error ? _red : _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
        title: Text('Review Payroll',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800, fontSize: 18, color: _fg)),
        actions: [
          TextButton(
            onPressed: _pickPeriod,
            child: Text(_period,
                style: GoogleFonts.plusJakartaSans(
                    color: _green, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],

      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _green))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: DB.colSync(_cid, C.payrolls)
                  .where('period', isEqualTo: _period)
                  .orderBy('generatedAt', descending: true)
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: _green));
                }

                final docs = snap.data!.docs;

                // Exclude reversed records from all calculations and lists.
                // Reversed docs keep their history in Firestore but must not
                // appear in totals, pending lists, or employee counts.
                final activeDocs = docs
                    .where((d) => (d.data()['status'] ?? '') != 'reversed')
                    .toList();
                final reversedDocs = docs
                    .where((d) => (d.data()['status'] ?? '') == 'reversed')
                    .toList();

                // Partition active docs only
                final paid   = activeDocs.where((d) => (d.data()['status'] ?? '') == 'disbursed').toList();
                final unpaid = activeDocs.where((d) => (d.data()['status'] ?? '') == 'pending').toList();

                // Totals calculation optimized with FinanceUtils
                double totalGross = 0, totalDeductions = 0, totalNet = 0;
                double paidNet = 0, unpaidNet = 0;
                
                // Using a single pass for efficiency
                for (final d in activeDocs) {
                  final m = d.data();
                  final gross = FinanceUtils.toDouble(m['grossSalary']) + FinanceUtils.toDouble(m['bonus']);
                  final ded   = FinanceUtils.toDouble(m['loanDeduction']);
                  final net   = FinanceUtils.toDouble(m['netSalary']);
                  
                  totalGross      = FinanceUtils.round(totalGross + gross);
                  totalDeductions = FinanceUtils.round(totalDeductions + ded);
                  totalNet        = FinanceUtils.round(totalNet + net);
                  
                  if ((m['status'] ?? '') == 'disbursed') {
                    paidNet = FinanceUtils.round(paidNet + net);
                  } else {
                    unpaidNet = FinanceUtils.round(unpaidNet + net);
                  }
                }


                // Selected net (from unpaid active docs only)
                double selectedNet = 0;
                for (final d in unpaid) {
                  if (_selected.contains(d.id)) {
                    selectedNet += _num(d.data()['netSalary']);
                  }
                }

                final allUnpaidSelected =
                    unpaid.isNotEmpty && _selected.length == unpaid.length;

                String runStatus = 'Draft';
                if (activeDocs.isNotEmpty) {
                  if (paid.length == activeDocs.length) {
                    runStatus = 'Processed';
                  } else if (paid.isNotEmpty) {
                    runStatus = 'Partial';
                  }
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        children: [
                          // ── Summary card ───────────────────────────────
                          _MonthlySummaryCard(
                            period:         _period,
                            status:         runStatus,
                            totalGross:     totalGross,
                            payDate:        _nextPayday,
                            totalEmployees: activeDocs.length,
                            paidCount:      paid.length,
                            unpaidCount:    unpaid.length,
                            totalDeductions:totalDeductions,
                            paidNet:        paidNet,
                            unpaidNet:      unpaidNet,
                            money:          _money,
                          ),
                          const SizedBox(height: 16),

                          // ── Unpaid section ─────────────────────────────
                          if (unpaid.isNotEmpty) ...[
                             _SectionHeader(
                                label: 'Pending Payment (${unpaid.length})',
                                trailing: TextButton.icon(
                                  onPressed: () => _toggleSelectAll(unpaid),
                                  icon: Icon(
                                    allUnpaidSelected
                                        ? Icons.deselect_rounded
                                        : Icons.select_all_rounded,
                                    size: 15,
                                    color: _green,
                                  ),
                                  label: Text(
                                    allUnpaidSelected ? 'Deselect All' : 'Select All',
                                    style: GoogleFonts.plusJakartaSans(
                                        color: _green,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4)),
                                ),
                              ),
                              const SizedBox(height: 12),

                            ...unpaid.map((d) => _EmployeeBreakdownCard(
                                  doc:        d,
                                  money:      _money,
                                  initials:   _initials,
                                  isPaid:     false,
                                  isSelected: _selected.contains(d.id),
                                  onToggle:   () => setState(() {
                                    if (_selected.contains(d.id)) {
                                      _selected.remove(d.id);
                                    } else {
                                      _selected.add(d.id);
                                    }
                                  }),
                                  onEdit: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditPayrollScreen(
                                        docId: d.id,
                                        cid: _cid,
                                        period: _period,
                                      ),
                                    ),
                                  ),
                                  onReverse: null,
                                )),
                            const SizedBox(height: 16),
                          ],

                          // ── Paid section ───────────────────────────────
                          if (paid.isNotEmpty) ...[
                            _SectionHeader(
                              label: 'Paid (${paid.length})',
                              color: _green,
                            ),
                            const SizedBox(height: 8),
                            ...paid.map((d) => _EmployeeBreakdownCard(
                                  doc:        d,
                                  money:      _money,
                                  initials:   _initials,
                                  isPaid:     true,
                                  isSelected: false,
                                  onToggle:   null,
                                  onEdit:     null,
                                  onReverse:  () => _reverseSingle(d),
                                )),
                          ],

                          // ── Reversed section (audit trail) ─────────────
                          if (reversedDocs.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _SectionHeader(
                              label: 'Reversed (${reversedDocs.length})',
                              color: _red,
                            ),
                            const SizedBox(height: 8),
                            ...reversedDocs.map((d) => _EmployeeBreakdownCard(
                                  doc:        d,
                                  money:      _money,
                                  initials:   _initials,
                                  isPaid:     false,
                                  isSelected: false,
                                  onToggle:   null,
                                  onEdit:     null,
                                  onReverse:  null,
                                )),
                          ],

                          if (activeDocs.isEmpty && reversedDocs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.payments_outlined,
                                        size: 40, color: _muted),
                                    const SizedBox(height: 12),
                                    Text('No payroll records for $_period.',
                                        style: GoogleFonts.inter(
                                            color: _muted, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── Bottom action bar ──────────────────────────────────
                    _BottomActionBar(
                      selectedCount: _selected.length,
                      selectedNet:   selectedNet,
                      totalNet:      totalNet,
                      paidNet:       paidNet,
                      money:         _money,
                      saving:        _saving,
                      runStatus:     runStatus,
                      hasPaid:       paid.isNotEmpty,
                      onPaySelected: _selected.isEmpty
                          ? null
                          : () => _paySelected(docs),
                      onSendPayslips: paid.isEmpty
                          ? null
                          : () => _sendPayslips(docs),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final Color? color;
  final Widget? trailing;
  const _SectionHeader({required this.label, this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 4, height: 16,
            decoration: BoxDecoration(
              color: color ?? _orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color ?? _fg)),
        ]),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Monthly Summary Card ──────────────────────────────────────────────────────
class _MonthlySummaryCard extends StatelessWidget {
  final String period, status, payDate;
  final double totalGross, totalDeductions, paidNet, unpaidNet;
  final int totalEmployees, paidCount, unpaidCount;
  final NumberFormat money;

  const _MonthlySummaryCard({
    required this.period,
    required this.status,
    required this.totalGross,
    required this.payDate,
    required this.totalEmployees,
    required this.paidCount,
    required this.unpaidCount,
    required this.totalDeductions,
    required this.paidNet,
    required this.unpaidNet,
    required this.money,
  });

  Color get _statusColor {
    switch (status) {
      case 'Processed': return _green;
      case 'Partial':   return _orange;
      default:          return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(period.toUpperCase(),
                  style: GoogleFonts.inter(
                      color: _muted, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              _StatusChip(label: status, color: _statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text('Total Payroll (Gross)',
              style: GoogleFonts.inter(color: _muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(money.format(totalGross),
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 28,
                  color: _fg, letterSpacing: -0.5)),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 12),
          Row(children: [
            _MetaItem(label: 'Pay Date',   value: payDate),
            _MetaItem(label: 'Employees',  value: '$totalEmployees'),
            _MetaItem(label: 'Deductions', value: money.format(totalDeductions)),
          ]),
          const SizedBox(height: 12),
          // Paid / Unpaid progress bar
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Paid: $paidCount / $totalEmployees',
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: _green)),
                      Text(money.format(paidNet),
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: _green)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalEmployees > 0
                          ? paidCount / totalEmployees
                          : 0,
                      backgroundColor: _greenLt,
                      color: _green,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (unpaidCount > 0)
                    Text('Pending: $unpaidCount  •  ${money.format(unpaidNet)}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _orange,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final String label, value;
  const _MetaItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(color: _muted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 14, color: _fg)),
        ],
      ),
    );
  }
}

// ── Employee Breakdown Card ───────────────────────────────────────────────────
class _EmployeeBreakdownCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final NumberFormat money;
  final String Function(String) initials;
  final bool isPaid;
  final bool isSelected;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onReverse;

  const _EmployeeBreakdownCard({
    required this.doc,
    required this.money,
    required this.initials,
    required this.isPaid,
    required this.isSelected,
    required this.onToggle,
    required this.onEdit,
    required this.onReverse,
  });

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final m        = doc.data();
    final name     = (m['employeeName'] ?? 'Unknown').toString();
    final dept     = (m['department']   ?? '').toString();
    final gross    = _num(m['grossSalary']) + _num(m['bonus']);
    final loan     = _num(m['loanDeduction']);
    final net      = _num(m['netSalary']);
    final photo    = (m['profilePhotoUrl'] ?? '').toString();
    final method   = (m['paymentMethod'] ?? '').toString();
    final isReversed = (m['status'] ?? '') == 'reversed';

    final borderColor = isReversed
        ? _red.withValues(alpha: 0.25)
        : isPaid
            ? _green.withValues(alpha: 0.25)
            : isSelected
                ? _green.withValues(alpha: 0.5)
                : _border;

    final bgColor = isReversed
        ? _red.withValues(alpha: 0.04)
        : isPaid
            ? _greenLt.withValues(alpha: 0.3)
            : isSelected
                ? _green.withValues(alpha: 0.04)
                : _card;

    return GestureDetector(
      onTap: isPaid ? null : onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isPaid || isSelected ? 1.5 : 1),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
              child: Row(children: [
                // Checkbox (unpaid) or paid icon
                if (!isPaid)
                  Checkbox(
                    value: isSelected,
                    onChanged: onToggle == null ? null : (_) => onToggle!(),
                    activeColor: _green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Container(
                    width: 28, height: 28,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: _green, size: 16),
                  ),

                const SizedBox(width: 6),

                // Avatar
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isPaid ? _greenLt : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: photo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(photo, fit: BoxFit.cover))
                      : Center(
                          child: Text(initials(name),
                              style: GoogleFonts.inter(
                                  color: isPaid ? _greenDk : const Color(0xFF1E40AF),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                ),
                const SizedBox(width: 10),

                // Name + dept + method
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14, color: _fg)),
                      Row(children: [
                        Text(dept.isNotEmpty ? dept : 'Employee',
                            style: GoogleFonts.inter(
                                color: _muted, fontSize: 11)),
                        if (isPaid && method.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(method,
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _greenDk)),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),

                // Actions
                if (isPaid && onReverse != null)
                  Tooltip(
                    message: 'Reverse payment',
                    child: IconButton(
                      icon: const Icon(Icons.undo_rounded, color: _red, size: 18),
                      onPressed: onReverse,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  )
                else if (!isPaid && onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: _muted, size: 18),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Edit payroll',
                  ),
              ]),
            ),

            // Breakdown row
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isReversed
                    ? _red.withValues(alpha: 0.04)
                    : isPaid
                        ? _green.withValues(alpha: 0.05)
                        : _bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                _BreakdownCell(
                    label: 'GROSS',
                    value: money.format(gross),
                    color: isReversed ? _muted : _fg),
                _BreakdownCell(
                    label: 'DEDUCTIONS',
                    value: loan > 0 ? '-${money.format(loan)}' : '৳0',
                    color: loan > 0 ? _red : _muted),
                _BreakdownCell(
                    label: 'NET',
                    value: money.format(net),
                    color: isReversed ? _red : isPaid ? _green : _fg,
                    bold: true),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCell extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;

  const _BreakdownCell({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: _muted, fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.inter(
                  color: color,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Bottom Action Bar ─────────────────────────────────────────────────────────
class _BottomActionBar extends StatelessWidget {
  final int selectedCount;
  final double selectedNet, totalNet, paidNet;
  final NumberFormat money;
  final bool saving, hasPaid;
  final String runStatus;
  final VoidCallback? onPaySelected;
  final VoidCallback? onSendPayslips;

  const _BottomActionBar({
    required this.selectedCount,
    required this.selectedNet,
    required this.totalNet,
    required this.paidNet,
    required this.money,
    required this.saving,
    required this.hasPaid,
    required this.runStatus,
    required this.onPaySelected,
    required this.onSendPayslips,
  });

  @override
  Widget build(BuildContext context) {
    final isFullyProcessed = runStatus == 'Processed';

    return Container(
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Amount row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedCount > 0
                    ? '$selectedCount selected'
                    : 'Total Payroll',
                style: GoogleFonts.inter(
                    color: _muted, fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                money.format(selectedCount > 0 ? selectedNet : totalNet),
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 18, color: _fg),
              ),
            ],
          ),
          if (paidNet > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.check_circle_rounded, size: 12, color: _green),
                const SizedBox(width: 4),
                Text('${money.format(paidNet)} already paid',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _green,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Send payslips (shown when any are paid)
          if (hasPaid) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: saving ? null : onSendPayslips,
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text('Send Payslips',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Pay selected button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isFullyProcessed
                    ? _green.withValues(alpha: 0.5)
                    : selectedCount > 0
                        ? _green
                        : _muted,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (saving || onPaySelected == null) ? null : onPaySelected,
              icon: saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(
                      isFullyProcessed
                          ? Icons.check_circle_rounded
                          : Icons.payments_rounded,
                      size: 18),
              label: Text(
                saving
                    ? 'Processing…'
                    : isFullyProcessed
                        ? 'All Paid ✓'
                        : selectedCount > 0
                            ? 'Pay $selectedCount Employee${selectedCount > 1 ? 's' : ''}'
                            : 'Select Employees to Pay',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment Method Sheet ──────────────────────────────────────────────────────
class _PaymentMethodSheet extends StatefulWidget {
  final double totalNet;
  final String period;
  final int employeeCount;
  final NumberFormat money;

  const _PaymentMethodSheet({
    required this.totalNet,
    required this.period,
    required this.employeeCount,
    required this.money,
  });

  @override
  State<_PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<_PaymentMethodSheet> {
  String _method  = 'Bank Transfer';
  final _refCtl   = TextEditingController();
  final _notesCtl = TextEditingController();

  static const _methods = [
    ('Bank Transfer', Icons.account_balance_rounded,  Color(0xFF2563EB)),
    ('Cash',          Icons.payments_rounded,          Color(0xFF16A34A)),
    ('bKash',         Icons.phone_android_rounded,     Color(0xFFE91E8C)),
    ('Nagad',         Icons.mobile_friendly_rounded,   Color(0xFFF97316)),
    ('Cheque',        Icons.receipt_long_rounded,      Color(0xFF7C3AED)),
  ];

  @override
  void dispose() {
    _refCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Text('Confirm Payroll Payment',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 17, color: _fg)),
          const SizedBox(height: 4),
          Text(
            '${widget.employeeCount} employee${widget.employeeCount > 1 ? 's' : ''} • ${widget.period}',
            style: GoogleFonts.inter(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Amount
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                Text('Total Amount to Pay',
                    style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13)),
                Text(widget.money.format(widget.totalNet),
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Payment Method',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 14, color: _fg)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _methods.map((m) {
              final selected = _method == m.$1;
              return GestureDetector(
                onTap: () => setState(() => _method = m.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? m.$3.withValues(alpha: 0.12)
                        : const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? m.$3 : const Color(0x14000000),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(m.$2, size: 16,
                        color: selected ? m.$3 : _muted),
                    const SizedBox(width: 6),
                    Text(m.$1,
                        style: GoogleFonts.inter(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                            color: selected ? m.$3 : _fg)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          _SheetField(
            label: 'Transaction / Reference ID (optional)',
            hint: 'e.g. TXN123456, Cheque #001',
            ctl: _refCtl,
          ),
          const SizedBox(height: 10),
          _SheetField(
            label: 'Notes (optional)',
            hint: 'Any additional notes…',
            ctl: _notesCtl,
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, {
                'method':    _method,
                'reference': _refCtl.text.trim(),
                'notes':     _notesCtl.text.trim(),
              }),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text('Confirm & Pay',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet Field ───────────────────────────────────────────────────────────────
class _SheetField extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctl;
  const _SheetField(
      {required this.label, required this.hint, required this.ctl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: _fg)),
        const SizedBox(height: 6),
        TextField(
          controller: ctl,
          style: GoogleFonts.inter(fontSize: 14, color: _fg),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF7F9FC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

// ── Bullet point for dialogs ──────────────────────────────────────────────────
class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ',
              style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 12, color: _fg, height: 1.4)),
          ),
        ]),
      );
}

// ── Status Chip ───────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
