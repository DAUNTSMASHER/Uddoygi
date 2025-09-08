// lib/features/marketing/presentation/screens/add_new_wo.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

const _indigo  = Color(0xFF0D47A1);
const _chipBg  = Color(0xFFEFF3FF);
const _surface = Color(0xFFF7F9FC);

class AddNewWorkOrderScreen extends StatefulWidget {
  const AddNewWorkOrderScreen({Key? key}) : super(key: key);

  @override
  State<AddNewWorkOrderScreen> createState() => _AddNewWorkOrderScreenState();
}

class _AddNewWorkOrderScreenState extends State<AddNewWorkOrderScreen> {
  // Create form state
  final _formKey       = GlobalKey<FormState>();
  final _makerNameCtrl = TextEditingController();
  final _notesCtrl     = TextEditingController();

  /// Source dropdown value: 'stock' or an invoice document id
  String _sourceId = 'stock';
  Map<String, dynamic>? _invoiceData; // null when source is 'stock'

  final List<Map<String, dynamic>> _items = [];
  final List<TextEditingController> _qtyCtrls = [];

  int _deliveryDays = 7;
  DateTime _finalDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    _makerNameCtrl.text = u?.displayName ?? '';
  }

  @override
  void dispose() {
    _makerNameCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _qtyCtrls) c.dispose();
    super.dispose();
  }

  String _niceDate(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  // ------------------------- UI -------------------------

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Work Orders', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Work Order'),
        onPressed: _openCreateSheet,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // All of MY work orders, regardless of status.
              stream: FirebaseFirestore.instance
                  .collection('work_orders')
                  .where('agentEmail', isEqualTo: userEmail)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = (snap.data?.docs ?? []).toList();

                // Sort by timestamp DESC (client-side)
                all.sort((a, b) {
                  final ta = a.data()['timestamp'];
                  final tb = b.data()['timestamp'];
                  final da = (ta is Timestamp) ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                  final db = (tb is Timestamp) ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                  return db.compareTo(da);
                });

                if (all.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_outlined, size: 64, color: Colors.blueGrey.shade300),
                          const SizedBox(height: 10),
                          const Text('No work orders yet', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('Tap “New Work Order” to create one.',
                              style: TextStyle(color: Colors.blueGrey.shade600)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: all.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _orderCard(all[i].data()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------- Widgets -------------------------

  Widget _orderCard(Map<String, dynamic> m) {
    final wo     = (m['workOrderNo'] ?? '').toString();
    final status = (m['status'] ?? 'Pending').toString();
    final items  = (m['items'] as List?)?.fold<int>(0, (s, it) => s + (it['qty'] as int? ?? 0)) ?? 0;
    final fdTs   = m['finalDate'];
    final finalDate = (fdTs is Timestamp) ? fdTs.toDate() : DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: ListTile(
        leading: Container(
          width: 42, height: 42, alignment: Alignment.center,
          decoration: BoxDecoration(color: _chipBg, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.assignment_turned_in, color: _indigo),
        ),
        title: Text(wo, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _pill('$items pcs'),
              _pill('Due ${_niceDate(finalDate)}'),
              _statusPill(status),
            ],
          ),
        ),
        onTap: () {},
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusPill(String s) {
    // Support many possible status values
    final v = s.toLowerCase();
    Color c;
    switch (v) {
      case 'submitted':   c = Colors.indigo;      break;
      case 'in progress': c = Colors.deepPurple;  break;
      case 'completed':   c = Colors.green;       break;
      case 'accepted':    c = Colors.green;       break;
      case 'rejected':    c = Colors.redAccent;   break;
      case 'cancelled':   c = Colors.redAccent;   break;
      default:            c = Colors.orange;      // pending/others
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)),
    );
  }

  // ------------------------- Create Sheet -------------------------

  void _openCreateSheet() {
    _resetFormEphemeral();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16, right: 16, top: 12,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(
                  width: 48, height: 5,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Text('Create Work Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),

              // Maker
              _section(
                title: 'Maker',
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: TextFormField(
                        controller: _makerNameCtrl,
                        decoration: _fieldDeco('Your Name *'),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextFormField(
                        readOnly: true,
                        initialValue: FirebaseAuth.instance.currentUser?.email ?? '',
                        decoration: _fieldDeco('Your Email (auto)'),
                      ),
                    ),
                  ],
                ),
              ),

              // Source (Stock or My Invoices)
              _section(
                title: 'Source',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSourceDropdown(),
                    if (_invoiceData != null) ...[
                      const SizedBox(height: 8),
                      _invoicePreview(_invoiceData!),
                    ],
                  ],
                ),
              ),

              // Items
              _section(
                title: 'Items',
                trailing: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                  onPressed: () => _addOrEditItem(),
                ),
                child: Column(
                  children: [
                    if (_items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: _panelDeco(),
                        child: const Text('No items yet. Select an invoice or tap "Add Item".'),
                      ),
                    // Ensure controllers exist
                    Builder(builder: (_) {
                      while (_qtyCtrls.length < _items.length) {
                        final i = _qtyCtrls.length;
                        _qtyCtrls.add(TextEditingController(text: '${_items[i]['qty'] ?? 1}'));
                      }
                      return const SizedBox.shrink();
                    }),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final it = _items[i];
                        final model  = (it['model']  ?? '').toString();
                        final colour = (it['colour'] ?? '-').toString();
                        final size   = (it['size']   ?? '-').toString();

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: _panelDeco(),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      model.isEmpty ? '(Unnamed model)' : model,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(spacing: 6, children: [
                                      _pill('Colour: $colour'),
                                      _pill('Size: $size'),
                                    ]),
                                  ],
                                ),
                              ),
                              _qtyStepper(i),
                              const SizedBox(width: 6),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _addOrEditItem(index: i);
                                  if (v == 'del')  _removeItem(i);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(leading: Icon(Icons.edit), title: Text('Edit')),
                                  ),
                                  PopupMenuItem(
                                    value: 'del',
                                    child: ListTile(leading: Icon(Icons.delete), title: Text('Remove')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Delivery
              _section(
                title: 'Delivery',
                child: Column(children: [
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<int>(
                      value: _deliveryDays,
                      decoration: _fieldDeco('Delivery Time (days)'),
                      items: const [7, 14, 21, 28]
                          .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _deliveryDays = v;
                          _finalDate = DateTime.now().add(Duration(days: _deliveryDays));
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Text('Final Date: ${_niceDate(_finalDate)}')),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today, color: _indigo),
                        label: const Text('Change', style: TextStyle(color: _indigo)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _finalDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _finalDate = picked;
                              _deliveryDays = picked.difference(DateTime.now()).inDays.clamp(1, 365);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ]),
              ),

              // Instructions
              _section(
                title: 'Special Instructions',
                child: SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: _fieldDeco('e.g. pack colour-wise, include QC note…'),
                  ),
                ),
              ),

              // Review
              _section(title: 'Review', child: _previewCard()),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Submit Work Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: 10),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------- helpers for sheet / source dropdown ----------

  /// Stream + client filtering so we only show **my** invoices,
  /// even if the collection uses different keys for owner identity.
  Widget _buildSourceDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('invoices').snapshots(),
      builder: (ctx, snap) {
        final base = const [
          DropdownMenuItem<String>(value: 'stock', child: Text('Stock (no invoice)')),
        ];

        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return DropdownButtonFormField<String>(
            isExpanded: true,
            value: _sourceId,
            decoration: _fieldDeco('Select Source').copyWith(
              suffixIcon: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            items: base,
            onChanged: (v) { if (v != null) _onSelectSource(v); },
          );
        }

        final user = FirebaseAuth.instance.currentUser;
        final email = user?.email ?? '';
        final uid   = user?.uid ?? '';

        // Post-filter the snapshot for several common ownership markers
        final docs = (snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .where((d) {
          final m = d.data();
          final ownerEmail = (m['agentEmail'] ?? m['makerEmail'] ?? m['createdByEmail'] ?? '').toString();
          final ownerUid   = (m['agentUid']   ?? m['ownerUid']   ?? m['createdByUid']   ?? '').toString();
          return (email.isNotEmpty && ownerEmail == email) || (uid.isNotEmpty && ownerUid == uid);
        })
            .toList()
          ..sort((a, b) {
            DateTime toDate(dynamic x) {
              if (x is Timestamp) return x.toDate();
              if (x is int) return DateTime.fromMillisecondsSinceEpoch(x);
              return DateTime.fromMillisecondsSinceEpoch(0);
            }
            final da = toDate(a.data()['timestamp']);
            final db = toDate(b.data()['timestamp']);
            return db.compareTo(da);
          });

        final items = [
          ...base,
          ...docs.map((d) {
            final m     = d.data();
            final invNo = (m['invoiceNo'] as String?) ?? d.id;
            final cust  = (m['customerName'] as String?) ?? 'N/A';
            return DropdownMenuItem<String>(
              value: d.id,
              child: Text('Inv $invNo • $cust', maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }),
        ];

        // keep selection valid
        final ids = items.map((e) => e.value).whereType<String>().toSet();
        if (!ids.contains(_sourceId)) _sourceId = 'stock';

        return DropdownButtonFormField<String>(
          isExpanded: true,
          value: _sourceId,
          decoration: _fieldDeco('Select Source'),
          items: items,
          onChanged: (v) { if (v != null) _onSelectSource(v); },
        );
      },
    );
  }

  /// Robustly extract items from many possible invoice shapes.
  List<Map<String, dynamic>> _extractInvoiceItems(Map<String, dynamic> data) {
    List<dynamic> rawList = const [];
    dynamic raw = data['items'] ?? data['lineItems'] ?? data['products'] ?? data['orderItems'];

    if (raw is List) {
      rawList = raw;
    } else if (raw is Map) {
      rawList = raw.values.toList();
    } else {
      rawList = const [];
    }

    final mapped = rawList.map<Map<String, dynamic>>((e) {
      final m = (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{};

      // Nested product object support
      final prod = (m['product'] is Map) ? Map<String, dynamic>.from(m['product']) : <String, dynamic>{};

      String model = (m['model'] ??
          m['productName'] ??
          m['name'] ??
          m['item'] ??
          prod['model'] ??
          prod['name'] ??
          '').toString();

      String colour = (m['colour'] ?? m['color'] ?? prod['colour'] ?? prod['color'] ?? '').toString();
      String size   = (m['size'] ?? m['variant'] ?? prod['size'] ?? prod['variant'] ?? '').toString();

      final qtyRaw = m['qty'] ?? m['quantity'] ?? m['pcs'] ?? m['count'] ?? 1;
      final qty = (qtyRaw is num) ? qtyRaw.toInt() : int.tryParse('$qtyRaw') ?? 1;

      return {
        'model' : model.trim(),
        'colour': colour.trim(),
        'size'  : size.trim(),
        'qty'   : qty <= 0 ? 1 : qty,
      };
    }).where((m) => (m['model'] as String).isNotEmpty).toList();

    return mapped;
  }

  Future<void> _onSelectSource(String v) async {
    setState(() => _sourceId = v);

    if (v == 'stock') {
      // clear items (manual entry)
      for (final c in _qtyCtrls) c.dispose();
      _qtyCtrls.clear();
      _items.clear();
      setState(() => _invoiceData = null);
      return;
    }

    // Load selected invoice and map its items
    final doc  = await FirebaseFirestore.instance.collection('invoices').doc(v).get();
    final data = doc.data();
    if (data == null) return;

    final mapped = _extractInvoiceItems(data);

    // If nothing mapped, let the user know (common cause: field names differ)
    if (mapped.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items found on the invoice to add automatically.')),
      );
    }

    // Update state in one setState so UI refreshes reliably
    setState(() {
      for (final c in _qtyCtrls) c.dispose();
      _qtyCtrls.clear();

      _items
        ..clear()
        ..addAll(mapped);

      _qtyCtrls.addAll(_items.map((it) => TextEditingController(text: '${it['qty']}')));
      _invoiceData = data;
    });
  }

  // ---------- generic helpers ----------

  InputDecoration _fieldDeco(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.blueGrey.shade100),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: _indigo, width: 1.5),
    ),
  );

  BoxDecoration _panelDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.blueGrey.shade100),
  );

  Widget _section({required String title, Widget? trailing, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 6, height: 18, decoration: BoxDecoration(color: _indigo, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _qtyStepper(int i) {
    return Row(
      children: [
        _roundBtn(Icons.remove, () {
          final cur = int.tryParse(_qtyCtrls[i].text) ?? 1;
          _qtyCtrls[i].text = '${(cur - 1).clamp(1, 999)}';
          setState(() {});
        }),
        const SizedBox(width: 6),
        SizedBox(
          width: 64,
          child: TextFormField(
            controller: _qtyCtrls[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: _fieldDeco('Qty'),
            validator: (v) => ((int.tryParse(v ?? '') ?? 0) <= 0) ? 'Req' : null,
          ),
        ),
        const SizedBox(width: 6),
        _roundBtn(Icons.add, () {
          final cur = int.tryParse(_qtyCtrls[i].text) ?? 1;
          _qtyCtrls[i].text = '${(cur + 1).clamp(1, 999)}';
          setState(() {});
        }),
      ],
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blueGrey.shade100),
        ),
        child: Icon(icon, color: _indigo, size: 20),
      ),
    );
  }

  Widget _invoicePreview(Map<String, dynamic> m) {
    final inv   = (m['invoiceNo'] ?? '').toString();
    final cust  = (m['customerName'] ?? '—').toString();
    final total = ((m['grandTotal'] as num?) ?? 0).toDouble();

    // Count items robustly
    final cnt = _extractInvoiceItems(m).length;

    DateTime date;
    final ts = m['timestamp'];
    if (m['date'] is Timestamp) {
      date = (m['date'] as Timestamp).toDate();
    } else if (ts is Timestamp) {
      date = ts.toDate();
    } else {
      date = DateTime.now();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _panelDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long, color: _indigo),
          const SizedBox(width: 8),
          Text('Invoice $inv', style: const TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          _pill(_niceDate(date)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 10, children: [
          _pill('Customer: $cust'),
          _pill('Items: $cnt'),
          _pill('৳${total.toStringAsFixed(2)}'),
        ]),
      ]),
    );
  }

  Widget _previewCard() {
    final totalItems = _items.fold<int>(0, (s, it) => s + (it['qty'] as int? ?? 0));
    final invNo      = (_invoiceData?['invoiceNo'] ?? '').toString();

    final woNo = _invoiceData == null
        ? 'WO_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}'
        : 'INV${invNo}_WO_${DateFormat('yyyyMMdd').format(_finalDate)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDeco(),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          Text('WO No: $woNo', style: const TextStyle(fontWeight: FontWeight.w800)),
          _pill('Items: $totalItems'),
          _pill('Delivery: $_deliveryDays day(s)'),
          _pill('Final: ${_niceDate(_finalDate)}'),
        ],
      ),
    );
  }

  void _resetFormEphemeral() {
    _formKey.currentState?.reset();
    _sourceId = 'stock';
    _invoiceData = null;
    _items.clear();
    for (final c in _qtyCtrls) c.dispose();
    _qtyCtrls.clear();
    _deliveryDays = 7;
    _finalDate = DateTime.now().add(const Duration(days: 7));
    _notesCtrl.clear();
    setState(() {});
  }

  Future<void> _addOrEditItem({int? index}) async {
    final isEdit = index != null;
    final model  = TextEditingController(text: isEdit ? (_items[index!]['model']  ?? '') : '');
    final colour = TextEditingController(text: isEdit ? (_items[index!]['colour'] ?? '') : '');
    final size   = TextEditingController(text: isEdit ? (_items[index!]['size']   ?? '') : '');
    final qty    = TextEditingController(text: isEdit ? '${_items[index!]['qty'] ?? 1}' : '1');
    final key    = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Item' : 'Add Item'),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: model,  decoration: _fieldDeco('Model *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 8),
            TextFormField(controller: colour, decoration: _fieldDeco('Colour')),
            const SizedBox(height: 8),
            TextFormField(controller: size,   decoration: _fieldDeco('Size')),
            const SizedBox(height: 8),
            TextFormField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: _fieldDeco('Qty *'),
              validator: (v) => ((int.tryParse(v ?? '') ?? 0) <= 0) ? 'Invalid' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!key.currentState!.validate()) return;
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    final m = {
      'model' : model.text.trim(),
      'colour': colour.text.trim(),
      'size'  : size.text.trim(),
      'qty'   : int.tryParse(qty.text) ?? 1,
    };

    setState(() {
      if (isEdit) {
        _items[index!] = m;
        _qtyCtrls[index].text = '${m['qty']}';
      } else {
        _items.add(m);
        _qtyCtrls.add(TextEditingController(text: '${m['qty']}'));
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _qtyCtrls.removeAt(index).dispose();
    });
  }

  Future<void> _submit() async {
    final user  = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final uid   = user?.uid ?? '';

    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item.')));
      return;
    }

    // sync qty from editors
    for (int i = 0; i < _items.length; i++) {
      final q = int.tryParse(_qtyCtrls[i].text) ?? 1;
      _items[i]['qty'] = q <= 0 ? 1 : q;
    }

    final workNo = _invoiceData == null
        ? 'WO_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}'
        : '${_invoiceData!['invoiceNo']}_WO_${DateFormat('yyyyMMdd').format(_finalDate)}';

    final doc = <String, dynamic>{
      'workOrderNo'      : workNo,
      'invoiceId'        : _sourceId == 'stock' ? null : _sourceId,
      'linkedToInvoice'  : _sourceId != 'stock',
      'items'            : _items.map((e) => {
        'model' : e['model'],
        'colour': e['colour'],
        'size'  : e['size'],
        'qty'   : e['qty'],
      }).toList(),

      // maker identity
      'makerName'  : _makerNameCtrl.text.trim(),
      'makerEmail' : email,
      'makerUid'   : uid,
      // legacy for other screens
      'agentEmail' : email,

      'deliveryDays'      : _deliveryDays,
      'finalDate'         : Timestamp.fromDate(_finalDate),
      'instructions'      : _notesCtrl.text.trim(),
      'status'            : 'Pending',
      'submittedToFactory': false,
      'timestamp'         : FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('work_orders').doc(workNo).set(doc);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work order submitted')));
  }
}
