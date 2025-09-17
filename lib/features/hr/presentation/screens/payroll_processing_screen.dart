import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PayrollProcessingScreen extends StatefulWidget {
  const PayrollProcessingScreen({super.key});

  @override
  State<PayrollProcessingScreen> createState() => _PayrollProcessingScreenState();
}

class _PayrollProcessingScreenState extends State<PayrollProcessingScreen> {
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
    var q = FirebaseFirestore.instance
        .collection('payrolls')
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
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
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
      final loansSnap = await FirebaseFirestore.instance
          .collection('loans')
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

      await FirebaseFirestore.instance.collection('payrolls').add({
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
    final pdf = pw.Document();
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
  String _q = '';
  String _dept = '';

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('users');
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
                    separatorBuilder: (_, __) => const Divider(height: 1),
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
