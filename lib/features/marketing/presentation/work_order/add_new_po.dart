// lib/features/marketing/presentation/screens/work_order/add_new_po.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const Color _chipBg = Color(0xFFEFF3FF);

class AddNewPurchaseOrderScreen extends StatefulWidget {
  const AddNewPurchaseOrderScreen({Key? key}) : super(key: key);

  @override
  State<AddNewPurchaseOrderScreen> createState() => _AddNewPurchaseOrderScreenState();
}

class _AddNewPurchaseOrderScreenState extends State<AddNewPurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  // Invoices
  String? _selectedInvoiceId;
  String? _invoiceNo;
  List<DocumentSnapshot<Map<String, dynamic>>> _invoices = [];

  // Products (for cascading selectors)
  List<DocumentSnapshot<Map<String, dynamic>>> _products = [];

  // Items (invoice-like)
  // each item: {model, colour, size, qty, unitPrice, (optional) base, curl, density}
  final List<Map<String, dynamic>> _items = [];

  DateTime _expectedDate = DateTime.now();
  final TextEditingController _instructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _loadProducts();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    final snap = await FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: userEmail)
        .orderBy('timestamp', descending: true)
        .get();
    setState(() => _invoices = snap.docs);
  }

  Future<void> _loadProducts() async {
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .orderBy('model_name')
        .get();
    setState(() => _products = snap.docs);
  }

  // ---------- Product derivation helpers (like WO) ----------
  List<String> _models() =>
      _products.map((p) => (p.data()!['model_name'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  List<String> _colours(String m) => _products
      .where((p) => (p.data()!['model_name'] ?? '') == m)
      .map((p) => (p.data()!['colour'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<String> _sizes(String m, String c) => _products
      .where((p) => (p.data()!['model_name'] ?? '') == m && (p.data()!['colour'] ?? '') == c)
      .map((p) => (p.data()!['size'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<String> _vals(String m, String c, String s, String key) => _products
      .where((p) =>
  (p.data()!['model_name'] ?? '') == m &&
      (p.data()!['colour'] ?? '') == c &&
      (p.data()!['size'] ?? '') == s)
      .map((p) => (p.data()![key] ?? '').toString())
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  // ---------- Item editor (bottom sheet with StatefulBuilder) ----------
  Future<void> _openItemEditor({int? index}) async {
    String? model;
    String? colour;
    String? size;
    String? base;
    String? curl;
    String? density;
    int qty = 1;
    double unitPrice = 0.0;

    if (index != null) {
      final it = _items[index];
      model = (it['model'] ?? '') as String?;
      colour = (it['colour'] ?? '') as String?;
      size = (it['size'] ?? '') as String?;
      base = (it['base'] ?? '') as String?;
      curl = (it['curl'] ?? '') as String?;
      density = (it['density'] ?? '') as String?;
      qty = (it['qty'] as int?) ?? 1;
      unitPrice = ((it['unitPrice'] as num?) ?? 0).toDouble();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final models = _models();
            final colours = (model != null) ? _colours(model!) : <String>[];
            final sizes = (model != null && colour != null) ? _sizes(model!, colour!) : <String>[];
            final bases = (model != null && colour != null && size != null) ? _vals(model!, colour!, size!, 'base') : <String>[];
            final curls = (model != null && colour != null && size != null) ? _vals(model!, colour!, size!, 'curl') : <String>[];
            final densities = (model != null && colour != null && size != null) ? _vals(model!, colour!, size!, 'density') : <String>[];

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(index == null ? 'Add Item' : 'Edit Item',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: model,
                    items: models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) {
                      setLocal(() {
                        model = v;
                        colour = null;
                        size = null;
                        base = null;
                        curl = null;
                        density = null;
                      });
                    },
                    decoration: _fieldDeco('Model *'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: colour,
                    items: colours.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      setLocal(() {
                        colour = v;
                        size = null;
                        base = null;
                        curl = null;
                        density = null;
                      });
                    },
                    decoration: _fieldDeco('Colour *'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: size,
                    items: sizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      setLocal(() {
                        size = v;
                        base = null;
                        curl = null;
                        density = null;
                      });
                    },
                    decoration: _fieldDeco('Size *'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: base?.isEmpty == true ? null : base,
                    items: (bases.isEmpty ? [''] : bases)
                        .map((b) => DropdownMenuItem(value: b, child: Text(b.isEmpty ? '(none)' : b)))
                        .toList(),
                    onChanged: (v) => setLocal(() => base = (v ?? '').isEmpty ? null : v),
                    decoration: _fieldDeco('Base'),
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: curl?.isEmpty == true ? null : curl,
                    items: (curls.isEmpty ? [''] : curls)
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.isEmpty ? '(none)' : c)))
                        .toList(),
                    onChanged: (v) => setLocal(() => curl = (v ?? '').isEmpty ? null : v),
                    decoration: _fieldDeco('Curl'),
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: density?.isEmpty == true ? null : density,
                    items: (densities.isEmpty ? [''] : densities)
                        .map((d) => DropdownMenuItem(value: d, child: Text(d.isEmpty ? '(none)' : d)))
                        .toList(),
                    onChanged: (v) => setLocal(() => density = (v ?? '').isEmpty ? null : v),
                    decoration: _fieldDeco('Density'),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '$qty',
                          decoration: _fieldDeco('Qty'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final q = int.tryParse(v) ?? 1;
                            setLocal(() => qty = q <= 0 ? 1 : q);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: unitPrice.toStringAsFixed(2),
                          decoration: _fieldDeco('Unit Price'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) {
                            final p = double.tryParse(v) ?? 0.0;
                            setLocal(() => unitPrice = p < 0 ? 0.0 : p);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _darkBlue, foregroundColor: Colors.white),
                        onPressed: (model == null || colour == null || size == null)
                            ? null
                            : () {
                          final m = <String, dynamic>{
                            'model': model!,
                            'colour': colour!,
                            'size': size!,
                            'qty': qty,
                            'unitPrice': unitPrice,
                          };
                          if ((base ?? '').isNotEmpty) m['base'] = base!;
                          if ((curl ?? '').isNotEmpty) m['curl'] = curl!;
                          if ((density ?? '').isNotEmpty) m['density'] = density!;

                          setState(() {
                            if (index == null) {
                              _items.add(m);
                            } else {
                              _items[index] = m;
                            }
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------- Submit ----------
  Future<void> _submitPO() async {
    if (!_formKey.currentState!.validate() || _selectedInvoiceId == null) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item.')),
      );
      return;
    }

    // Validate minimal fields
    for (final it in _items) {
      if ((it['model'] ?? '').toString().isEmpty ||
          (it['colour'] ?? '').toString().isEmpty ||
          (it['size'] ?? '').toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each item must have Model, Colour and Size.')),
        );
        return;
      }
    }

    final dateStr = DateFormat('yyyyMMdd').format(_expectedDate);
    final poNo = '${_invoiceNo!.toLowerCase()}_po_$dateStr';

    final poData = {
      'poNo': poNo,
      'invoiceId': _selectedInvoiceId,
      'invoiceNo': _invoiceNo,
      'items': _items,
      'expectedDate': _expectedDate, // Firestore will store as Timestamp
      'instructions': _instructionsController.text.trim(),
      'submittedBy': FirebaseAuth.instance.currentUser?.email,
      'timestamp': Timestamp.now(),
    };

    await FirebaseFirestore.instance
        .collection('purchase_orders')
        .doc(poNo)
        .set(poData);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase order submitted!')),
    );
    Navigator.of(context).pop();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        title: const Text('New Purchase Order'),
        backgroundColor: _darkBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Invoice dropdown
              DropdownButtonFormField<String>(
                value: _selectedInvoiceId,
                decoration: const InputDecoration(
                  labelText: 'Select Invoice',
                  border: OutlineInputBorder(),
                ),
                items: _invoices.map((d) {
                  final invNo = d.data()?['invoiceNo'] as String? ?? d.id;
                  return DropdownMenuItem(value: d.id, child: Text(invNo));
                }).toList(),
                onChanged: (v) {
                  final sel = _invoices.firstWhere((d) => d.id == v);
                  setState(() {
                    _selectedInvoiceId = v;
                    _invoiceNo = sel.data()?['invoiceNo'] as String? ?? sel.id;
                  });
                },
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Items section (invoice-like)
              _section(
                title: 'Items (Qty & Unit Price)',
                trailing: OutlinedButton.icon(
                  icon: const Icon(Icons.add, color: _darkBlue),
                  label: const Text('Add Item', style: TextStyle(color: _darkBlue)),
                  onPressed: () => _openItemEditor(),
                ),
                child: Column(
                  children: [
                    if (_items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: _panelDeco(),
                        child: const Text('No items yet. Tap "Add Item".'),
                      ),

                    ...List.generate(_items.length, (i) {
                      final it = _items[i];

                      final model   = (it['model'] ?? '').toString();
                      final colour  = (it['colour'] ?? '-').toString();
                      final size    = (it['size'] ?? '-').toString();
                      final base    = (it['base'] ?? '').toString();
                      final curl    = (it['curl'] ?? '').toString();
                      final density = (it['density'] ?? '').toString();

                      final qty  = (it['qty'] as int?) ?? 1;
                      final unit = ((it['unitPrice'] as num?) ?? 0).toDouble();

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      model.isEmpty ? '(Unnamed model)' : model,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'edit') {
                                        await _openItemEditor(index: i);
                                        setState(() {}); // ensure refresh
                                      }
                                      if (v == 'del') {
                                        setState(() => _items.removeAt(i));
                                      }
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
                              const SizedBox(height: 6),

                              // Attributes
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _chip('Colour: $colour'),
                                  _chip('Size: $size'),
                                  if (base.isNotEmpty) _chip('Base: $base'),
                                  if (curl.isNotEmpty) _chip('Curl: $curl'),
                                  if (density.isNotEmpty) _chip('Density: $density'),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Qty + Unit Price
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: '$qty',
                                      decoration: const InputDecoration(
                                        labelText: 'Qty',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        final q = int.tryParse(v) ?? 1;
                                        setState(() => _items[i]['qty'] = q <= 0 ? 1 : q);
                                      },
                                      validator: (v) => (v == null || v.isEmpty) ? 'Req' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: unit.toStringAsFixed(2),
                                      decoration: const InputDecoration(
                                        labelText: 'Unit Price',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (v) {
                                        final p = double.tryParse(v) ?? 0.0;
                                        setState(() => _items[i]['unitPrice'] = p < 0 ? 0.0 : p);
                                      },
                                      validator: (v) => (double.tryParse(v ?? '') ?? 0) < 0 ? 'Invalid' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Line Total: ৳${(((_items[i]['unitPrice'] as num?) ?? 0).toDouble() * ((_items[i]['qty'] as int?) ?? 0)).toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Builder(
                          builder: (_) {
                            final subtotal = _items.fold<double>(0, (s, it) {
                              final q = (it['qty'] as int?) ?? 0;
                              final p = ((it['unitPrice'] as num?) ?? 0).toDouble();
                              return s + (q * p);
                            });
                            return Text('Subtotal: ৳${subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w900));
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Expected date
              Text('Expected Date: ${DateFormat('yyyy-MM-dd').format(_expectedDate)}'),
              TextButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _expectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _expectedDate = d);
                },
                child: const Text('Select Date'),
              ),

              const SizedBox(height: 16),

              // Instructions
              TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Special Instructions',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
                  onPressed: _submitPO,
                  child: const Text('Submit PO'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------- small UI helpers ----------
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
      borderSide: BorderSide(color: _darkBlue, width: 1.5),
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
      decoration: _panelDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 6, height: 18, decoration: BoxDecoration(color: _darkBlue, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
