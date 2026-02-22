import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/payments/data/piprapay_repository.dart';
import 'package:uddoygi/features/payments/domain/models/beneficiary_model.dart';

class PayrollProcessingScreen extends StatefulWidget {
  const PayrollProcessingScreen({super.key});

  @override
  State<PayrollProcessingScreen> createState() => _PayrollProcessingScreenState();
}

class _PayrollProcessingScreenState extends State<PayrollProcessingScreen> {
  String _cid = '';
  /* ======================= Theme ======================= */
  static const Color _primary = Color(0xFF25BC5F);   // green
  static const Color _primaryDark = Color(0xFF065F46);
  static const Color _surface = Color(0xFFF1F8F4);   // near white
  static const Color _cardBorder = Color(0x1A065F46);
  static const _shadow = BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4));

  /* ======================= State ======================= */
  // Month shown as "MMMM yyyy" (e.g., "September 2025")
  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());

  // Filters (top panel)
  String filterDepartment = ''; // server-side filter
  String filterEmployeeId = ''; // client-side contains filter

  // Inputs (bottom-sheet)
  final _empIdController = TextEditingController();
  final _salaryController = TextEditingController();

  // Paged list state
  final List<DocumentSnapshot<Map<String, dynamic>>> _docs = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  static const int _pageSize = 15;

  final _money = NumberFormat.currency(locale: 'en', symbol: '৳', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _resetAndLoad();
  }

  @override
  void dispose() {
    _empIdController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  /* ==================== Firestore Load ==================== */

  void _resetAndLoad() {
    setState(() {
      _docs.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    _loadNextPage();
  }

  Query<Map<String, dynamic>> _baseQuery() {
    var q = DB.colSync(_cid, C.payrolls)
        .where('period', isEqualTo: selectedMonth);

    if (filterDepartment.trim().isNotEmpty) {
      q = q.where('department', isEqualTo: filterDepartment.trim());
    }

    return q.orderBy('generatedAt', descending: true).limit(_pageSize);
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    var q = _baseQuery();
    if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);

    final snap = await q.get();
    if (snap.docs.isNotEmpty) {
      _docs.addAll(snap.docs);
      _lastDoc = snap.docs.last;
    }
    if (snap.docs.length < _pageSize) _hasMore = false;

    setState(() => _isLoading = false);
  }

  /* ==================== Generate Payroll ==================== */

  void _openGenerateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
        ),
        child: _GeneratePayrollForm(
          empIdController: _empIdController,
          salaryController: _salaryController,
          onPickEmployee: _pickEmployee,
          onSubmit: () async {
            final empId = _empIdController.text.trim();
            final gross = double.tryParse(_salaryController.text.trim()) ?? 0;
            if (empId.isEmpty || gross <= 0) return;
            Navigator.pop(context);
            await _generatePayrollForEmployee(empId, gross);
          },
        ),
      ),
    );
  }

  Future<void> _pickEmployee() async {
    final chosen = await showModalBottomSheet<_PickedEmployee>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _EmployeePickerSheet(),
    );
    if (chosen != null) {
      _empIdController.text = chosen.employeeId;
      if (chosen.baseSalary != null && chosen.baseSalary! > 0) {
        _salaryController.text = chosen.baseSalary!.toStringAsFixed(0);
      }
    }
  }

  double _asNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }

  Future<void> _generatePayrollForEmployee(String employeeId, double grossSalary) async {
    try {
      // Enrich from users
      final userSnap = await DB.colSync(_cid, C.users)
          .where('employeeId', isEqualTo: employeeId)
          .limit(1)
          .get();

      String? employeeUid;
      String? employeeName;
      String department = 'General';
      String? officeEmail;

      if (userSnap.docs.isNotEmpty) {
        final m = userSnap.docs.first.data();
        employeeUid = userSnap.docs.first.id;
        employeeName = (m['fullName'] as String?)?.trim();
        department = (m['department'] as String?) ?? 'General';
        officeEmail = (m['officeEmail'] as String?) ?? (m['email'] as String?);
      }

      // Loans
      final loansSnap = await DB.colSync(_cid, C.loans)
          .where('employeeId', isEqualTo: employeeId)
          .where('status', whereIn: ['Approved', 'Active'])
          .get();

      double totalDeduction = 0.0;
      final List<Map<String, dynamic>> loanBreakdown = [];

      for (final doc in loansSnap.docs) {
        final loan = doc.data();
        final double amount = _asNum(loan['amount']);
        final double deducted = _asNum(loan['deductedAmount']);
        final double remaining = (amount - deducted).clamp(0, double.infinity);
        final double emi = loan['emi'] != null ? _asNum(loan['emi']) : 2000.0;
        final double thisMonth = remaining >= emi ? emi : remaining;

        if (thisMonth > 0) {
          totalDeduction += thisMonth;
          loanBreakdown.add({
            'loanId': doc.id,
            'amount': amount,
            'deducted': deducted,
            'thisMonth': thisMonth,
          });

          await doc.reference.update({'deductedAmount': FieldValue.increment(thisMonth)});
          if ((deducted + thisMonth) >= amount) {
            await doc.reference.update({'status': 'Closed'});
          }
        }
      }

      final netSalary = (grossSalary - totalDeduction).clamp(0, double.infinity);

      await (await DB.col(C.payrolls)).add({
        'employeeUid': employeeUid,
        'employeeId': employeeId,
        'employeeName': employeeName ?? employeeId,
        'officeEmail': officeEmail,
        'department': department,
        'period': selectedMonth,
        'grossSalary': grossSalary,
        'loanDeduction': totalDeduction,
        'netSalary': netSalary,
        'loanBreakdown': loanBreakdown,
        'generatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Payroll generated for $employeeId')),
      );

      _empIdController.clear();
      _salaryController.clear();
      _resetAndLoad();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate payroll: $e')),
      );
    }
  }

  /* ==================== Export ==================== */

  Future<void> exportPayrollToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Payroll'];

    sheet.appendRow(['Employee ID', 'Name', 'Department', 'Gross', 'Loan', 'Net', 'Period']);
    for (final doc in _filteredDocs()) {
      final d = doc.data()!;
      sheet.appendRow([
        d['employeeId'] ?? '',
        d['employeeName'] ?? '',
        d['department'] ?? '',
        d['grossSalary'] ?? 0,
        d['loanDeduction'] ?? 0,
        d['netSalary'] ?? 0,
        d['period'] ?? '',
      ]);
    }

    final List<int>? raw = excel.encode();
    if (raw == null) return;
    final bytes = Uint8List.fromList(raw);
    await Printing.sharePdf(bytes: bytes, filename: 'payroll_${selectedMonth.replaceAll(' ', '_')}.xlsx');
  }

  Future<void> exportPayrollToPDF() async {
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: pw.Font.times(), bold: pw.Font.timesBold(), italic: pw.Font.timesItalic(), boldItalic: pw.Font.timesBoldItalic()));
    pdf.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Payroll Report - $selectedMonth', style: pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Employee ID', 'Name', 'Gross', 'Loan', 'Net', 'Department'],
              data: _filteredDocs().map((doc) {
                final d = doc.data()!;
                return [
                  d['employeeId'] ?? '',
                  d['employeeName'] ?? '',
                  (d['grossSalary'] ?? 0).toString(),
                  (d['loanDeduction'] ?? 0).toString(),
                  (d['netSalary'] ?? 0).toString(),
                  d['department'] ?? '',
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  /* ==================== Helpers ==================== */

  List<DocumentSnapshot<Map<String, dynamic>>> _filteredDocs() {
    final q = filterEmployeeId.trim().toLowerCase();
    if (q.isEmpty) return _docs;
    return _docs.where((doc) {
      final d = doc.data()!;
      final id = (d['employeeId'] ?? '').toString().toLowerCase();
      final nm = (d['employeeName'] ?? '').toString().toLowerCase();
      return id.contains(q) || nm.contains(q);
    }).toList();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 4, 1),
      lastDate: DateTime(now.year + 4, 12),
      helpText: 'Choose any date in the target month',
    );
    if (picked != null) {
      setState(() => selectedMonth = DateFormat('MMMM yyyy').format(picked));
      _resetAndLoad();
    }
  }

  String _when(dynamic ts) {
    DateTime? t;
    if (ts is Timestamp) t = ts.toDate();
    if (ts is DateTime) t = ts;
    if (t == null) return '—';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('yMMMd').format(t);
  }

  /* ==================== UI ==================== */

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDocs();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        title: Text('Payroll • $selectedMonth', style: const TextStyle(fontWeight: FontWeight.w800)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_primary, _primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), tooltip: 'Change month', onPressed: _pickMonth),
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: exportPayrollToPDF),
          IconButton(icon: const Icon(Icons.file_copy), onPressed: exportPayrollToExcel),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryDark,
        icon: const Icon(Icons.add),
        label: const Text('Generate'),
        onPressed: _openGenerateSheet,
      ),
      body: Column(
        children: [
          _TopFilterPanel(
            monthLabel: selectedMonth,
            onChangeMonth: _pickMonth,
            department: filterDepartment,
            onDepartmentChanged: (v) {
              setState(() => filterDepartment = v.trim());
              _resetAndLoad(); // server-side filter
            },
            employeeText: filterEmployeeId,
            onEmployeeTextChanged: (v) => setState(() => filterEmployeeId = v.trim()),
            onPickEmployee: () async {
              final picked = await showModalBottomSheet<_PickedEmployee>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => const _EmployeePickerSheet(),
              );
              if (picked != null) setState(() => filterEmployeeId = picked.employeeId);
            },
          ),
          _SummaryStrip(docs: filtered, money: _money),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              color: _primaryDark,
              onRefresh: () async => _resetAndLoad(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                itemCount: filtered.length + 1,
                itemBuilder: (context, index) {
                  if (index == filtered.length) {
                    if (_hasMore) {
                      _loadNextPage();
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  final doc = filtered[index];
                  final d = doc.data()!;
                  final breakdown = (d['loanBreakdown'] as List<dynamic>? ?? const []);

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _cardBorder),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [_shadow],
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: CircleAvatar(
                          backgroundColor: _primary.withOpacity(.15),
                          foregroundColor: _primaryDark,
                          child: Text(
                            (d['employeeName'] ?? d['employeeId'] ?? '??')
                                .toString()
                                .characters
                                .take(2)
                                .join()
                                .toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(
                          '${d['employeeName'] ?? d['employeeId']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          'Net ${_money.format(d['netSalary'] ?? 0)} • '
                              'Gross ${_money.format(d['grossSalary'] ?? 0)} • '
                              'Loan ${_money.format(d['loanDeduction'] ?? 0)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        children: [
                          _kv('Employee ID', d['employeeId'] ?? '—'),
                          _kv('Department', (d['department'] ?? '').toString().toUpperCase()),
                          _kv('Email', d['officeEmail'] ?? '—'),
                          const SizedBox(height: 6),
                          if (breakdown.isEmpty)
                            _pill('No loan deductions this period', Colors.grey.shade200, _primaryDark.withOpacity(.6))
                          else
                            ...breakdown.map<Widget>((e) {
                              final m = (e is Map<String, dynamic>) ? e : <String, dynamic>{};
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _primary.withOpacity(.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _primary.withOpacity(.15)),
                                ),
                                child: Text(
                                  'Loan ${m['loanId'] ?? '—'}  •  '
                                      'Original ${_money.format(m['amount'] ?? 0)}  •  '
                                      'Deducted ${_money.format(m['deducted'] ?? 0)}  •  '
                                      'This Month ${_money.format(m['thisMonth'] ?? 0)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Generated ${_when(d['generatedAt'])}',
                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // ── Send via PipraPay ──────────────────────────
                          _SendPayrollButton(
                            cid:          _cid,
                            employeeUid:  (d['employeeUid'] as String?) ?? '',
                            employeeName: (d['employeeName'] ?? d['employeeId'] ?? '').toString(),
                            netSalary:    (d['netSalary'] is num)
                                ? (d['netSalary'] as num).toDouble()
                                : double.tryParse(d['netSalary']?.toString() ?? '0') ?? 0,
                            period:       (d['period'] ?? selectedMonth).toString(),
                            payrollDocId: doc.id,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(v, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

/* ==================== Top Filter Panel ==================== */

class _TopFilterPanel extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onChangeMonth;

  final String department;
  final ValueChanged<String> onDepartmentChanged;

  final String employeeText;
  final ValueChanged<String> onEmployeeTextChanged;
  final VoidCallback onPickEmployee;

  const _TopFilterPanel({
    required this.monthLabel,
    required this.onChangeMonth,
    required this.department,
    required this.onDepartmentChanged,
    required this.employeeText,
    required this.onEmployeeTextChanged,
    required this.onPickEmployee,
  });

  static const Color _primary = _PayrollProcessingScreenState._primary;
  static const Color _cardBorder = _PayrollProcessingScreenState._cardBorder;
  static const _shadow = _PayrollProcessingScreenState._shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [_shadow],
      ),
      child: Column(
        children: [
          // Row 1: Month
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Month: $monthLabel',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              TextButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Change'),
                style: TextButton.styleFrom(foregroundColor: _primary),
                onPressed: onChangeMonth,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Department
          Row(
            children: [
              const Icon(Icons.apartment_rounded, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: department.isEmpty ? null : department,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'hr', child: Text('HR')),
                    DropdownMenuItem(value: 'marketing', child: Text('Marketing')),
                    DropdownMenuItem(value: 'factory', child: Text('Factory')),
                  ],
                  onChanged: (v) => onDepartmentChanged(v ?? ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 3: Employee search / picker
          Row(
            children: [
              const Icon(Icons.person_search_rounded, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: employeeText)
                    ..selection = TextSelection.fromPosition(TextPosition(offset: employeeText.length)),
                  decoration: InputDecoration(
                    labelText: 'Search by Name/ID',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: employeeText.isEmpty
                        ? null
                        : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear),
                      onPressed: () => onEmployeeTextChanged(''),
                    ),
                  ),
                  onChanged: onEmployeeTextChanged,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onPickEmployee,
                icon: const Icon(Icons.list_alt),
                label: const Text('Pick'),
                style: ElevatedButton.styleFrom(backgroundColor: _primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ==================== Summary Strip ==================== */

class _SummaryStrip extends StatelessWidget {
  final List<DocumentSnapshot<Map<String, dynamic>>> docs;
  final NumberFormat money;

  const _SummaryStrip({required this.docs, required this.money});

  @override
  Widget build(BuildContext context) {
    num gross = 0, loan = 0, net = 0;
    for (final d in docs) {
      final m = d.data()!;
      gross += (m['grossSalary'] ?? 0) as num;
      loan  += (m['loanDeduction'] ?? 0) as num;
      net   += (m['netSalary'] ?? 0) as num;
    }

    Widget cell(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _PayrollProcessingScreenState._cardBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          cell('Gross', money.format(gross)),
          const SizedBox(width: 8),
          cell('Loan', money.format(loan)),
          const SizedBox(width: 8),
          cell('Net', money.format(net)),
        ],
      ),
    );
  }
}

/* ==================== Generate Payroll Form ==================== */

class _GeneratePayrollForm extends StatelessWidget {
  final TextEditingController empIdController;
  final TextEditingController salaryController;
  final VoidCallback onPickEmployee;
  final VoidCallback onSubmit;

  const _GeneratePayrollForm({
    required this.empIdController,
    required this.salaryController,
    required this.onPickEmployee,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    const Color _primary = _PayrollProcessingScreenState._primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('New Payroll', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: empIdController,
                decoration: const InputDecoration(labelText: 'Employee ID', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onPickEmployee,
              icon: const Icon(Icons.person_search),
              label: const Text('Pick'),
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: salaryController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Gross Salary', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.payments),
            onPressed: onSubmit,
            label: const Text('Generate'),
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
          ),
        ),
      ],
    );
  }
}

/* ==================== Employee Picker Sheet ==================== */

class _PickedEmployee {
  final String uid;
  final String employeeId;
  final String name;
  final String department;
  final String? email;
  final double? baseSalary;
  const _PickedEmployee({
    required this.uid,
    required this.employeeId,
    required this.name,
    required this.department,
    this.email,
    this.baseSalary,
  });
}

class _EmployeePickerSheet extends StatefulWidget {
  const _EmployeePickerSheet();

  @override
  State<_EmployeePickerSheet> createState() => _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<_EmployeePickerSheet> {
  String _cid = '';
  String _q = '';
  String _dept = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = DB.colSync(_cid, C.users);
    if (_dept.isNotEmpty) q = q.where('department', isEqualTo: _dept);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search + Dept filter row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search name/email/ID',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _dept.isEmpty ? null : _dept,
                  hint: const Text('Dept'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'hr', child: Text('HR')),
                    DropdownMenuItem(value: 'marketing', child: Text('Marketing')),
                    DropdownMenuItem(value: 'factory', child: Text('Factory')),
                  ],
                  onChanged: (v) => setState(() => _dept = v ?? ''),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: q.orderBy('fullName').limit(100).snapshots(),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs.where((d) {
                    final m = d.data();
                    final id = (m['employeeId'] ?? '').toString().toLowerCase();
                    final nm = (m['fullName'] ?? '').toString().toLowerCase();
                    final em = (m['officeEmail'] ?? m['email'] ?? '').toString().toLowerCase();
                    if (_q.isEmpty) return true;
                    return id.contains(_q) || nm.contains(_q) || em.contains(_q);
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text('No matching employees'));
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d = docs[i];
                      final m = d.data();
                      final empId = (m['employeeId'] ?? d.id).toString();
                      final name = (m['fullName'] ?? 'Unknown').toString();
                      final dept = (m['department'] ?? '').toString();
                      final email = (m['officeEmail'] ?? m['email'] ?? '').toString();
                      final baseSalary = (m['baseSalary'] is num)
                          ? (m['baseSalary'] as num).toDouble()
                          : double.tryParse('${m['baseSalary'] ?? ''}');

                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text('$name • $empId'),
                        subtitle: Text('${dept.toUpperCase()} • $email'),
                        onTap: () {
                          Navigator.pop(
                            context,
                            _PickedEmployee(
                              uid: d.id,
                              employeeId: empId,
                              name: name,
                              department: dept,
                              email: email,
                              baseSalary: baseSalary,
                            ),
                          );
                        },
                      );
                    },
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

/* ==================== Send via PipraPay Button ==================== */

class _SendPayrollButton extends StatefulWidget {
  final String cid;
  final String employeeUid;
  final String employeeName;
  final double netSalary;
  final String period;
  final String payrollDocId;

  const _SendPayrollButton({
    required this.cid,
    required this.employeeUid,
    required this.employeeName,
    required this.netSalary,
    required this.period,
    required this.payrollDocId,
  });

  @override
  State<_SendPayrollButton> createState() => _SendPayrollButtonState();
}

class _SendPayrollButtonState extends State<_SendPayrollButton> {
  bool _loading = false;

  static const Color _green = Color(0xFF065F46);
  static const Color _red   = Color(0xFFDC2626);

  Future<void> _send() async {
    if (widget.cid.isEmpty) return;
    setState(() => _loading = true);

    try {
      final repo     = PipraPayRepository(cid: widget.cid);
      final settings = await repo.getSettings();

      if (!settings.enabled) {
        _snack('PipraPay is not enabled. Configure it in Payment Settings.', error: true);
        return;
      }

      // Look up employee payment info from users collection
      Map<String, dynamic>? empData;
      if (widget.employeeUid.isNotEmpty) {
        final snap = await DB.colSync(widget.cid, C.users)
            .doc(widget.employeeUid)
            .get();
        empData = snap.data();
      }

      final paymentMethod  = (empData?['paymentMethod']  as String?) ?? '';
      final paymentAccount = (empData?['paymentAccount'] as String?) ?? '';
      final paymentName    = (empData?['paymentName']    as String?) ?? widget.employeeName;
      final bankName       = (empData?['bankName']       as String?) ?? '';
      final paymentVerified = (empData?['paymentVerified'] as bool?) ?? false;

      if (!mounted) return;

      if (paymentAccount.isEmpty) {
        _snack('Employee has no payment info. Ask them to update it.', error: true);
        return;
      }

      // Show confirmation sheet
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PayrollSendConfirmSheet(
          employeeName:    widget.employeeName,
          netSalary:       widget.netSalary,
          period:          widget.period,
          paymentMethod:   paymentMethod,
          paymentAccount:  paymentAccount,
          paymentName:     paymentName,
          bankName:        bankName,
          paymentVerified: paymentVerified,
          currency:        settings.currency,
          sandboxMode:     settings.sandboxMode,
        ),
      );

      if (confirmed != true || !mounted) return;

      // Build beneficiary from employee payment info
      final beneficiary = BeneficiaryModel(
        id:            widget.employeeUid.isNotEmpty
            ? widget.employeeUid
            : widget.payrollDocId,
        name:          paymentName,
        emailOrMobile: paymentAccount,
        type:          BeneficiaryType.employee,
        accountNumber: paymentAccount,
        bankName:      bankName,
        notes:         'Salary ${widget.period}',
      );

      // Upsert beneficiary in Firestore
      await DB.colSync(widget.cid, C.beneficiaries)
          .doc(beneficiary.id)
          .set({
        ...beneficiary.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Initiate payment
      final result = await repo.initiatePayment(
        beneficiary: beneficiary,
        amount:      widget.netSalary,
        settings:    settings,
        notes:       'Salary ${widget.period} — ${widget.employeeName}',
      );

      if (!mounted) return;

      // Show checkout URL
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CheckoutDialog(
          result:      result,
          sandboxMode: settings.sandboxMode,
        ),
      );
    } catch (e) {
      if (mounted) _snack('Payment failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _red : _green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        icon: _loading
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_rounded, size: 16),
        label: Text(
          _loading ? 'Preparing…' : 'Send via PipraPay',
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
        ),
        onPressed: _loading ? null : _send,
      ),
    );
  }
}

/* ==================== Payroll Send Confirmation Sheet ==================== */

class _PayrollSendConfirmSheet extends StatelessWidget {
  final String employeeName;
  final double netSalary;
  final String period;
  final String paymentMethod;
  final String paymentAccount;
  final String paymentName;
  final String bankName;
  final bool   paymentVerified;
  final String currency;
  final bool   sandboxMode;

  const _PayrollSendConfirmSheet({
    required this.employeeName,
    required this.netSalary,
    required this.period,
    required this.paymentMethod,
    required this.paymentAccount,
    required this.paymentName,
    required this.bankName,
    required this.paymentVerified,
    required this.currency,
    required this.sandboxMode,
  });

  static const Color _green = Color(0xFF065F46);
  static const Color _amber = Color(0xFFD97706);
  static final _money = NumberFormat.currency(
      locale: 'en', symbol: '৳', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
          top: MediaQuery.of(context).size.height * 0.2),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Confirm Payment',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),

                // Amount hero
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF065F46), Color(0xFF10B981)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    Text(
                      _money.format(netSalary),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '$currency • $period Salary',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                    if (sandboxMode) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('SANDBOX MODE',
                            style: TextStyle(
                                color: _amber,
                                fontSize: 10,
                                fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ]),
                ),

                const SizedBox(height: 14),

                // Recipient info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: paymentVerified
                        ? const Color(0xFF065F46).withValues(alpha: 0.06)
                        : _amber.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: paymentVerified
                            ? const Color(0xFF065F46).withValues(alpha: 0.2)
                            : _amber.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                          paymentVerified
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded,
                          color: paymentVerified
                              ? _green
                              : _amber,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          paymentVerified
                              ? 'Verified payment info'
                              : 'Unverified — double-check before sending',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: paymentVerified ? _green : _amber),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      _Row('To',      employeeName),
                      _Row('Method',  paymentMethod.isEmpty ? '—' : paymentMethod),
                      _Row('Account', paymentAccount),
                      if (paymentName.isNotEmpty)
                        _Row('Name',  paymentName),
                      if (bankName.isNotEmpty)
                        _Row('Bank',  bankName),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Send Payment',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(
            width: 60,
            child: Text('$label:',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black38)),
          ),
          Expanded(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

/* ==================== Checkout Dialog ==================== */

class _CheckoutDialog extends StatelessWidget {
  final InitiatePaymentResult result;
  final bool sandboxMode;
  const _CheckoutDialog(
      {required this.result, required this.sandboxMode});

  static const Color _green = Color(0xFF065F46);
  static const Color _amber = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: _green, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Payment Initiated',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sandboxMode)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _amber.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.science_rounded,
                    color: _amber, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Sandbox — no real money moved',
                      style: TextStyle(
                          fontSize: 11,
                          color: _amber,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          _DRow('Order ID', result.orderId),
          if (result.invoiceId.isNotEmpty)
            _DRow('Invoice', result.invoiceId),
          const SizedBox(height: 10),
          const Text('Complete payment at:',
              style: TextStyle(
                  fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _green.withValues(alpha: 0.2)),
            ),
            child: SelectableText(
              result.checkoutUrl,
              style: const TextStyle(
                  fontSize: 11,
                  color: _green,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _green),
          icon: const Icon(Icons.open_in_browser_rounded, size: 14),
          label: const Text('Open Checkout'),
          onPressed: () async {
            final uri = Uri.tryParse(result.checkoutUrl);
            if (uri != null) {
              // ignore: deprecated_member_use
              // url_launcher is already a dependency
            }
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class _DRow extends StatelessWidget {
  final String label;
  final String value;
  const _DRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black45)),
          Expanded(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}
