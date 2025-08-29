import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// =================== CONFIG / HELPERS ===================
const _kPrimary = Colors.indigo;
final _dateFmt = DateFormat('yyyy-MM-dd');
final _money = NumberFormat.currency(locale: 'en_BD', symbol: '৳');

const _accounts = <String>[
  'Cash',
  'Bank',
  'Sales Revenue',
  'Other Income',
  'VAT/Tax Payable',
  'Owner’s Equity',
];

num _toNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
  return 0;
}

/// =================== MAIN SCREEN (CREDITS ONLY) ===================
class GeneralLedgerScreen extends StatefulWidget {
  const GeneralLedgerScreen({super.key});
  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerCreditsScreenState();
}

class _GeneralLedgerCreditsScreenState extends State<GeneralLedgerScreen> {
  late DateTime _periodStart;
  late DateTime _periodEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodStart = DateTime(now.year, now.month, 1);
    _periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  Query _query() {
    // Credits only
    return FirebaseFirestore.instance
        .collection('ledger')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_periodStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd))
        .where('credit', isGreaterThan: 0) // <<< only credits
        .orderBy('date', descending: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 1.15),
      appBarTheme: const AppBarTheme(backgroundColor: _kPrimary, foregroundColor: Colors.white),
      colorScheme: Theme.of(context).colorScheme.copyWith(primary: _kPrimary),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Credits', style: TextStyle(fontWeight: FontWeight.w700))),

        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 22),
                    label: const Text('Add Credit', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _openAddCredit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.history, size: 22, color: _kPrimary),
                    label: const Text('History & Print',
                        style: TextStyle(fontWeight: FontWeight.w700, color: _kPrimary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kPrimary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreditsHistoryScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        body: StreamBuilder<QuerySnapshot>(
          stream: _query().snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data?.docs ?? [];
            // Summary (credits only)
            num credit = 0;
            for (final d in docs) {
              credit += _toNum((d.data() as Map<String, dynamic>)['credit']);
            }

            // Group credits by account
            final Map<String, num> creditBy = {};
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              final acct = (data['account'] as String?) ?? 'Unknown';
              creditBy[acct] = (creditBy[acct] ?? 0) + _toNum(data['credit']);
            }
            final accounts = creditBy.keys.toList()..sort();

            return ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                // period control
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _LargeButton(
                    label: 'Period: ${DateFormat('MMM yyyy').format(_periodStart)}',
                    icon: Icons.calendar_today,
                    onTap: _pickMonth,
                  ),
                ),

                // summary card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Credits Summary',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 12, runSpacing: 8, children: [
                            _PillStat(title: 'Total Credit', value: _money.format(credit)),
                            _PillStat(title: 'Entries', value: '${docs.length}'),
                            _PillStat(title: 'Accounts', value: '${accounts.length}'),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),

                // accounts list (credit totals)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('Accounts in ${DateFormat('MMM yyyy').format(_periodStart)}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                ...accounts.map((a) {
                  final c = creditBy[a] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        title: Text(a, style: const TextStyle(fontWeight: FontWeight.w700)),
                        trailing: Text(
                          _money.format(c),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.green),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }

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

  void _openAddCredit() => showDialog(context: context, builder: (_) => const _AddCreditDialog());
}

/// =================== ADD CREDIT DIALOG (single credit line) ===================
class _AddCreditDialog extends StatefulWidget {
  const _AddCreditDialog({super.key});
  @override
  State<_AddCreditDialog> createState() => _AddCreditDialogState();
}

class _AddCreditDialogState extends State<_AddCreditDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _creditAccount = 'Sales Revenue';
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController(text: 'Credit entry');
  final _costingCtrl = TextEditingController(); // optional
  String? _costCenter;
  DateTime _date = DateTime.now();
  final _refCollCtrl = TextEditingController(); // link to debit collection (optional)
  final _refIdCtrl = TextEditingController();   // link to debit doc id (optional)

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _costingCtrl.dispose();
    _refCollCtrl.dispose();
    _refIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Credit', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(children: [
            _Drop(label: 'Credit Account', value: _creditAccount, items: _accounts, onChanged: (v) {
              setState(() => _creditAccount = v);
            }),
            const SizedBox(height: 10),
            _Text(
              label: 'Amount (BDT)',
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter amount',
            ),
            const SizedBox(height: 10),
            _Text(label: 'Description', controller: _descCtrl),
            const SizedBox(height: 10),
            _Text(label: 'Costing (optional, BDT)', controller: _costingCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _Drop(
              label: 'Cost Center (optional)',
              value: _costCenter,
              items: const ['HR', 'Factory', 'Marketing', 'Accounts', 'R&D'],
              onChanged: (v) => setState(() => _costCenter = v),
              allowNull: true,
            ),
            const SizedBox(height: 10),
            _LargeButton(
              label: 'Date: ${_dateFmt.format(_date)}',
              icon: Icons.calendar_today,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 10),
            // Optional cross-link to where the debit was stored
            _Text(label: 'Linked Debit Collection (optional)', controller: _refCollCtrl),
            const SizedBox(height: 8),
            _Text(label: 'Linked Debit Doc ID (optional)', controller: _refIdCtrl),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_creditAccount == null) return;

    final amount = double.parse(_amountCtrl.text.trim());
    final costing = double.tryParse(_costingCtrl.text.trim());
    final desc = _descCtrl.text.trim();
    final ts = Timestamp.fromDate(DateTime(_date.year, _date.month, _date.day));
    final now = Timestamp.now();

    final db = FirebaseFirestore.instance;
    final doc = {
      'account': _creditAccount!,
      'description': desc,
      'date': ts,
      'debit': 0,                 // credits-only screen
      'credit': amount,           // the only amount we store here
      if (costing != null) 'costing': costing,
      if (_costCenter != null) 'costCenter': _costCenter,
      // Optional links to where debit lives
      if (_refCollCtrl.text.isNotEmpty) 'pairedCollection': _refCollCtrl.text.trim(),
      if (_refIdCtrl.text.isNotEmpty) 'pairedId': _refIdCtrl.text.trim(),
      'createdAt': now,
    };

    await db.collection('ledger').add(doc);
    if (context.mounted) Navigator.pop(context);
  }
}

/// =================== HISTORY & PRINT (CREDITS ONLY) ===================
class CreditsHistoryScreen extends StatelessWidget {
  const CreditsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final months = _lastMonths(12);
    return Scaffold(
      appBar: AppBar(title: const Text('Credits: History & Print', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: months.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final start = months[i];
          final end = DateTime(start.year, start.month + 1, 0, 23, 59, 59);
          final label = DateFormat('MMMM yyyy').format(start);
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black12),
            ),
            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Print'),
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
              onPressed: () => _printMonthCredits(context, start, end),
            ),
          );
        },
      ),
    );
  }

  Future<void> _printMonthCredits(BuildContext context, DateTime start, DateTime end) async {
    final snap = await FirebaseFirestore.instance
        .collection('ledger')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .where('credit', isGreaterThan: 0)
        .orderBy('date')
        .get();

    if (snap.docs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No credits for ${DateFormat('MMM yyyy').format(start)}')),
        );
      }
      return;
    }

    // Group by account
    final entries = snap.docs.map((d) => d.data()).toList();
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final e in entries) {
      final acct = (e['account'] as String?) ?? 'Unknown';
      (grouped[acct] ??= []).add(e);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final da = (a['date'] as Timestamp).toDate();
        final db = (b['date'] as Timestamp).toDate();
        return da.compareTo(db);
      });
    }

    // Build PDF (credits-only)
    final pdf = pw.Document();
    num grandC = 0;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(24)),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Credits Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(DateFormat('MMMM yyyy').format(start), style: const pw.TextStyle(color: PdfColors.grey700)),
            pw.Divider(),
          ],
        ),
        build: (_) {
          final widgets = <pw.Widget>[];

          grouped.forEach((account, list) {
            num cTot = 0;

            widgets.add(pw.SizedBox(height: 8));
            widgets.add(pw.Text('Account: $account', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.SizedBox(height: 4));

            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Description', 'Credit', 'Costing'],
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                border: pw.TableBorder.all(color: PdfColors.grey),
                data: list.map((e) {
                  final c = (e['credit'] ?? 0) as num;
                  final cost = (e['costing'] ?? 0) as num;
                  cTot += c;
                  return [
                    _dateFmt.format((e['date'] as Timestamp).toDate()),
                    (e['description'] ?? '-') as String,
                    _fmt(c),
                    cost == 0 ? '-' : _fmt(cost),
                  ];
                }).toList(),
              ),
            );

            grandC += cTot;

            widgets.add(pw.SizedBox(height: 6));
            widgets.add(
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text('Credit Total: ${_fmt(cTot)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
              ]),
            );
            widgets.add(pw.Divider());
          });

          widgets.add(
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo50,
                  border: pw.Border.all(color: PdfColors.indigo),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text('TOTAL CREDIT: ${_fmt(grandC)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static List<DateTime> _lastMonths(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) => DateTime(now.year, now.month - i, 1));
  }

  static String _fmt(num n) => n.toStringAsFixed(2);
}

/// =================== UI WIDGETS ===================
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
              Icon(icon, color: _kPrimary),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
              const Icon(Icons.arrow_drop_down, color: _kPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillStat extends StatelessWidget {
  final String title;
  final String value;
  final Color? color;
  const _PillStat({required this.title, required this.value, this.color, super.key});
  @override
  Widget build(BuildContext context) {
    final c = color ?? _kPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$title: ', style: TextStyle(color: c, fontWeight: FontWeight.w800)),
        Text(value, style: TextStyle(color: c, fontWeight: FontWeight.w700)),
      ]),
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
      leading: Icon(icon, color: _kPrimary, size: 24),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _Drop extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final bool allowNull;
  final ValueChanged<String?> onChanged;
  const _Drop({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.allowNull = false,
  });
  @override
  Widget build(BuildContext context) {
    final all = allowNull ? [null, ...items] : items;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: all
          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e ?? 'None')))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _Text extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _Text({super.key, required this.label, required this.controller, this.keyboardType, this.validator});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
