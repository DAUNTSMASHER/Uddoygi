import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// ========================= EXPENSES (count & add) =========================
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _money = NumberFormat.currency(locale: 'en_BD', symbol: '৳');
  final _dateFmt = DateFormat('yyyy-MM-dd');

  // default period: this month
  late DateTime _periodStart;
  late DateTime _periodEnd;
  String? _categoryFilter; // optional simple filter

  static const _categories = <String>[
    'Rent', 'Utilities', 'Payroll', 'Supplies', 'Maintenance', 'Transport', 'Marketing', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodStart = DateTime(now.year, now.month, 1);
    _periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  Query _query() {
    // Only reads expenses and counts/sums them; no payments involved.
    return FirebaseFirestore.instance
        .collection('expenses')
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_periodStart))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd))
        .orderBy('dueDate');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 1.15),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      colorScheme: Theme.of(context).colorScheme.copyWith(primary: Colors.indigo),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Expenses', style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              tooltip: 'History',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpensesHistoryScreen()),
              ),
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.indigo,
          icon: const Icon(Icons.add),
          label: const Text('Add Expense'),
          onPressed: _openAddExpense,
        ),

        body: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<QuerySnapshot>(
            stream: _query().snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];

              // Optional category filter (client side — simple)
              final filtered = docs.where((d) {
                if (_categoryFilter == null) return true;
                final cat = (d['category'] as String?) ?? '';
                return cat == _categoryFilter;
              }).toList();

              // Summary (counts + totals only)
              num total = 0;
              for (final d in filtered) {
                final m = d.data() as Map<String, dynamic>;
                total += _n(m['amount']);
              }

              return Column(
                children: [
                  // Period + Category controls (big tap targets)
                  Row(
                    children: [
                      Expanded(
                        child: _LargeButton(
                          label: 'Period: ${DateFormat('MMM yyyy').format(_periodStart)}',
                          icon: Icons.calendar_today,
                          onTap: _pickMonth,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _categoryFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: [null, ..._categories]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e ?? 'All')))
                              .toList(),
                          onChanged: (v) => setState(() => _categoryFilter = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Summary row (counts + total only)
                  Row(
                    children: [
                      Expanded(child: _summaryCard(context, 'Total Amount', _money.format(total), Icons.summarize)),
                      Expanded(child: _summaryCard(context, 'Entries', '${filtered.length}', Icons.list_alt)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // List (simple, senior friendly)
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No expenses in this period.'))
                        : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final doc = filtered[i];
                        final m = doc.data() as Map<String, dynamic>;
                        final vendor = (m['vendor'] as String?) ?? 'Vendor';
                        final category = (m['category'] as String?) ?? 'Other';
                        final amt = _n(m['amount']);
                        final due = (m['dueDate'] as Timestamp).toDate();
                        final isOverdue = due.isBefore(DateTime.now());

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isOverdue ? Icons.warning_amber_rounded : Icons.receipt_long,
                              color: isOverdue ? Colors.red : Colors.indigo,
                            ),
                            title: Text(vendor, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('$category • Due: ${_dateFmt.format(due)}'),
                            trailing: Text(
                              _money.format(amt),
                              style: TextStyle(
                                color: isOverdue ? Colors.red : Colors.indigo,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------- Actions ----------
  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final thisStart = DateTime(now.year, now.month, 1);
    final lastStart = DateTime(now.year, now.month - 1, 1);
    final lastEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Choose Period', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _BigOption(
              icon: Icons.today,
              label: 'This Month',
              onTap: () {
                setState(() {
                  _periodStart = thisStart;
                  _periodEnd = DateTime(thisStart.year, thisStart.month + 1, 0, 23, 59, 59);
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _BigOption(
              icon: Icons.history,
              label: 'Last Month',
              onTap: () {
                setState(() {
                  _periodStart = lastStart;
                  _periodEnd = lastEnd;
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _BigOption(
              icon: Icons.calendar_month_outlined,
              label: 'Custom Range',
              onTap: () async {
                Navigator.pop(context);
                final s = await showDatePicker(
                  context: context,
                  initialDate: _periodStart,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (s == null) return;
                final e = await showDatePicker(
                  context: context,
                  initialDate: _periodEnd,
                  firstDate: s,
                  lastDate: DateTime.now(),
                );
                if (e == null) return;
                setState(() {
                  _periodStart = DateTime(s.year, s.month, s.day);
                  _periodEnd = DateTime(e.year, e.month, e.day, 23, 59, 59);
                });
              },
            ),
            const SizedBox(height: 6),
          ]),
        ),
      ),
    );
  }

  void _openAddExpense() {
    showDialog(context: context, builder: (_) => const _AddExpenseDialog());
  }

  // Small helper
  Widget _summaryCard(BuildContext context, String title, String value, IconData icon,
      {Color color = Colors.indigo}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  static num _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }
}

/// ========================= ADD EXPENSE DIALOG =========================
class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog({super.key});
  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _vendor = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String _category = 'Other';
  String? _costCenter;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  static const _categories = <String>[
    'Rent', 'Utilities', 'Payroll', 'Supplies', 'Maintenance', 'Transport', 'Marketing', 'Other'
  ];

  @override
  void dispose() {
    _vendor.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _vendor,
              decoration: const InputDecoration(labelText: 'Vendor', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter vendor' : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _category = v ?? 'Other'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (BDT)', border: OutlineInputBorder()),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter amount',
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _costCenter,
              decoration: const InputDecoration(labelText: 'Cost Center (optional)', border: OutlineInputBorder()),
              items: const ['HR','Factory','Marketing','Accounts','R&D']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList()
                ..insert(0, const DropdownMenuItem(value: null, child: Text('None'))),
              onChanged: (v) => setState(() => _costCenter = v),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text('Due: ${DateFormat('yyyy-MM-dd').format(_dueDate)}'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final db = FirebaseFirestore.instance;
    final now = Timestamp.now();
    final amount = double.parse(_amount.text.trim());

    await db.collection('expenses').add({
      'vendor': _vendor.text.trim(),
      'category': _category,
      'amount': amount,
      'dueDate': Timestamp.fromDate(DateTime(_dueDate.year, _dueDate.month, _dueDate.day)),
      'status': 'planned', // (optional) just for display; no payment logic here
      'costCenter': _costCenter,
      'notes': _notes.text.trim(),
      'createdAt': now,
    });

    if (context.mounted) Navigator.pop(context);
  }
}

/// ========================= HISTORY (read-only) =========================
class ExpensesHistoryScreen extends StatelessWidget {
  const ExpensesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final months = _lastMonths(12);
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses History', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: months.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final start = months[i];
          final end = DateTime(start.year, start.month + 1, 0, 23, 59, 59);
          final label = DateFormat('MMMM yyyy').format(start);
          return _MonthTile(label: label, start: start, end: end);
        },
      ),
    );
  }

  static List<DateTime> _lastMonths(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) => DateTime(now.year, now.month - i, 1));
  }
}

class _MonthTile extends StatelessWidget {
  final String label;
  final DateTime start;
  final DateTime end;
  const _MonthTile({required this.label, required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_BD', symbol: '৳');

    final q = FirebaseFirestore.instance
        .collection('expenses')
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('dueDate');

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        num total = 0;
        int count = 0;
        if (snap.hasData) {
          count = snap.data!.docs.length;
          for (final d in snap.data!.docs) {
            total += _n((d.data() as Map<String, dynamic>)['amount']);
          }
        }
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.black12),
          ),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Entries: $count'),
          trailing: Text(
            money.format(total),
            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.indigo),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _MonthDetailPage(start: start, end: end, label: label),
            ),
          ),
        );
      },
    );
  }

  static num _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }
}

/// Simple detail page to view that month’s expenses (read-only)
class _MonthDetailPage extends StatelessWidget {
  final DateTime start, end;
  final String label;
  _MonthDetailPage({required this.start, required this.end, required this.label, super.key});

  final _money = NumberFormat.currency(locale: 'en_BD', symbol: '৳');
  final _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('expenses')
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('dueDate');

    return Scaffold(
      appBar: AppBar(title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          num total = 0;
          for (final d in docs) {
            total += _n((d.data() as Map<String, dynamic>)['amount']);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: _SummaryCardBig(
                  title: 'Total for $label',
                  value: _money.format(total),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final m = docs[i].data() as Map<String, dynamic>;
                    final vendor = (m['vendor'] as String?) ?? 'Vendor';
                    final category = (m['category'] as String?) ?? 'Other';
                    final amt = _n(m['amount']);
                    final due = (m['dueDate'] as Timestamp).toDate();

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long, color: Colors.indigo),
                        title: Text(vendor, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('$category • Due: ${_dateFmt.format(due)}'),
                        trailing: Text(
                          _money.format(amt),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.indigo),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static num _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }
}

/// ========================= Small UI bits =========================
class _LargeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _LargeButton({required this.label, required this.icon, required this.onTap, super.key});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black26),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.indigo),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
              const Icon(Icons.arrow_drop_down, color: Colors.indigo),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BigOption({required this.icon, required this.label, required this.onTap, super.key});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
      leading: Icon(icon, color: Colors.indigo, size: 24),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _SummaryCardBig extends StatelessWidget {
  final String title;
  final String value;
  const _SummaryCardBig({required this.title, required this.value, super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.indigo.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.indigo)),
          ],
        ),
      ),
    );
  }
}
