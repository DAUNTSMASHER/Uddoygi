// lib/features/marketing/presentation/screens/add_new_wo.dart
//
// Work Orders — create from stock or from an invoice.
// - Buyer name field (+ auto-fill from invoice)
// - Tracking number REQUIRED (auto from invoice or manual/generate; unique per WO)
// - Item selector via dropdowns from `products` (model → colour → size + optional base/curl/density)
// - Instant preview of items
// - Clean, mobile-first UI
//
// Firestore writes include:
//   workOrderNo, invoiceId (nullable), linkedToInvoice,
//   items[{model, colour, size, qty, (optional) base, curl, density}],
//   buyerName, makerName/makerEmail/makerUid, agentEmail,
//   deliveryDays, finalDate, instructions,
//   status, submittedToFactory, timestamp,
//   tracking_number (REQUIRED & UNIQUE).
//
// Uniqueness is enforced by a transaction that first creates
// tracking_index/{tracking_number}. If it already exists, submit is rejected.

import 'dart:collection';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _indigo = Color(0xFF0D47A1);
const _chipBg = Color(0xFFEFF3FF);
const _surface = Color(0xFFF7F9FC);

class AddNewWorkOrderScreen extends StatefulWidget {
  const AddNewWorkOrderScreen({Key? key}) : super(key: key);

  @override
  State<AddNewWorkOrderScreen> createState() => _AddNewWorkOrderScreenState();
}

class _AddNewWorkOrderScreenState extends State<AddNewWorkOrderScreen> {
  // Create form state
  final _formKey = GlobalKey<FormState>();
  final _buyerNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _trackingCtrl = TextEditingController();

  /// Source dropdown value: 'stock' or an invoice document id
  String _sourceId = 'stock';
  Map<String, dynamic>? _invoiceData; // null when source is 'stock'

  final List<Map<String, dynamic>> _items = [];

  int _deliveryDays = 7;
  DateTime _finalDate = DateTime.now().add(const Duration(days: 7));

  // Products for dropdowns
  List<DocumentSnapshot<Map<String, dynamic>>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    // Default buyer name from current user (as a convenience)
    final u = FirebaseAuth.instance.currentUser;
    _buyerNameCtrl.text = u?.displayName ?? '';
  }

  @override
  void dispose() {
    _buyerNameCtrl.dispose();
    _notesCtrl.dispose();
    _trackingCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .orderBy('model_name')
        .get();
    setState(() => _products = snap.docs);
  }

  String _niceDate(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  // ---------- helpers (tracking) ----------

  String _deriveTrackingFromInvoice(Map<String, dynamic> inv) {
    final fromField = (inv['tracking_number'] ?? '').toString().trim();
    if (fromField.isNotEmpty) return fromField;
    final invNo = (inv['invoiceNo'] ?? '').toString();
    if (invNo.isNotEmpty) {
      return 'TRK-${invNo.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '').toUpperCase()}';
    }
    // ultimate fallback, time-based
    final ts = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    final rnd = (Random().nextInt(900) + 100).toString();
    return 'TRK-WO-$ts$rnd';
  }

  String _generateTracking() {
    final ts = DateFormat('yyyyMMddHHmm').format(DateTime.now());
    final rnd = (Random().nextInt(9000) + 1000).toString();
    return 'TRK-WO-$ts$rnd';
  }

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
          _onboardingBanner(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('work_orders')
                  .where('agentEmail', isEqualTo: userEmail)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // base list
                final allDocs = (snap.data?.docs ?? []).toList();

                // Map → filter out docs without tracking_number (empty / missing)
                final list = allDocs
                    .map((d) => d.data())
                    .where((m) => (m['tracking_number'] ?? '').toString().trim().isNotEmpty)
                    .toList();

                // Sort by timestamp DESC
                list.sort((a, b) {
                  DateTime toDate(dynamic x) {
                    if (x is Timestamp) return x.toDate();
                    return DateTime.fromMillisecondsSinceEpoch(0);
                  }
                  final da = toDate(a['timestamp']);
                  final db = toDate(b['timestamp']);
                  return db.compareTo(da);
                });

                // De-duplicate by tracking_number (show latest only if legacy dupes exist)
                final byTrk = LinkedHashMap<String, Map<String, dynamic>>();
                for (final m in list) {
                  final trk = (m['tracking_number'] ?? '').toString();
                  if (!byTrk.containsKey(trk)) byTrk[trk] = m;
                }
                final finalList = byTrk.values.toList();

                if (finalList.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_outlined, size: 64, color: Colors.blueGrey.shade300),
                          const SizedBox(height: 10),
                          const Text('No tracked work orders yet', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('Create a work order with a tracking number to see it here.',
                              style: TextStyle(color: Colors.blueGrey.shade600)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: finalList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _orderCard(finalList[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------- Widgets -------------------------

  Widget _onboardingBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _indigo.withOpacity(.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: _indigo),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Tracking number is required and must be unique. Linking invoices will auto-fill it, or you can paste/generate.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> m) {
    final buyer = (m['buyerName'] ?? m['makerName'] ?? 'Buyer').toString();
    final trk = (m['tracking_number'] ?? '').toString();
    final items = (m['items'] as List?)?.fold<int>(0, (s, it) => s + (it['qty'] as int? ?? 0)) ?? 0;
    final fdTs = m['finalDate'];
    final finalDate = (fdTs is Timestamp) ? fdTs.toDate() : DateTime.now();

    int daysLeft = finalDate.difference(DateTime.now()).inDays;
    String dueLabel;
    if (daysLeft > 0) {
      dueLabel = '$daysLeft day${daysLeft == 1 ? '' : 's'} left';
    } else if (daysLeft == 0) {
      dueLabel = 'Due today';
    } else {
      dueLabel = 'Overdue ${-daysLeft}d';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _chipBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Text(
            '$items',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _indigo),
          ),
        ),
        title: Text(
          buyer,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(trk),
              _pill(dueLabel),
            ],
          ),
        ),
        onTap: () {},
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
          left: 16,
          right: 16,
          top: 12,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Text('Create Work Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),

              // Buyer
              _section(
                title: 'Buyer',
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: TextFormField(
                        controller: _buyerNameCtrl,
                        decoration: _fieldDeco('Buyer Name *'),
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

              // Tracking
              _section(
                title: 'Tracking (required)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _trackingCtrl,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: _fieldDeco('Tracking Number (paste or generate)').copyWith(
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Generate',
                              icon: const Icon(Icons.auto_awesome, color: _indigo),
                              onPressed: () => setState(() => _trackingCtrl.text = _generateTracking()),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Tracking number is required';
                        if (t.length < 4) return 'Too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    _hintStrip(
                      'One work order per tracking number. If you selected an invoice, the number is auto-filled. '
                          'Otherwise paste one or tap Generate.',
                    ),
                  ],
                ),
              ),

              // Items — self-refreshing inside the create sheet
              StatefulBuilder(
                builder: (ctx, setLocal) => _section(
                  title: 'Items (Qty & Unit Price)',
                  trailing: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                    onPressed: () async {
                      await _openItemSheet();   // wait for add/edit
                      setLocal(() {});          // refresh the sheet immediately
                    },
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

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: _panelDeco(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: product name + actions
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
                                  const SizedBox(width: 6),
                                  PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'edit') {
                                        await _openItemSheet(index: i);
                                        setLocal(() {}); // refresh after edit
                                      }
                                      if (v == 'del') {
                                        _removeItem(i);
                                        setLocal(() {}); // refresh after delete
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

                              // Visible product attributes
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _pill('Colour: $colour'),
                                  _pill('Size: $size'),
                                  if (base.isNotEmpty) _pill('Base: $base'),
                                  if (curl.isNotEmpty) _pill('Curl: $curl'),
                                  if (density.isNotEmpty) _pill('Density: $density'),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Editable Qty + Unit Price
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: '$qty',
                                      decoration: _fieldDeco('Qty'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        final q = int.tryParse(v) ?? 1;
                                        _items[i]['qty'] = q <= 0 ? 1 : q;
                                        setLocal(() {}); // live recompute
                                      },
                                      validator: (v) => (v == null || v.isEmpty) ? 'Req' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: unit.toStringAsFixed(2),
                                      decoration: _fieldDeco('Unit Price'),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (v) {
                                        final p = double.tryParse(v) ?? 0.0;
                                        _items[i]['unitPrice'] = p < 0 ? 0.0 : p;
                                        setLocal(() {}); // live recompute
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
                              return Text(
                                'Subtotal: ৳${subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
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
            onChanged: (v) {
              if (v != null) _onSelectSource(v);
            },
          );
        }

        final user = FirebaseAuth.instance.currentUser;
        final email = user?.email ?? '';
        final uid = user?.uid ?? '';

        final docs = (snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .where((d) {
          final m = d.data();
          final ownerEmail = (m['ownerEmail'] ?? m['agentEmail'] ?? '').toString();
          final ownerUid = (m['ownerUid'] ?? m['agentId'] ?? '').toString();
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
            final m = d.data();
            final invNo = (m['invoiceNo'] as String?) ?? d.id;
            final cust = (m['customerName'] as String?) ?? 'N/A';
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
          onChanged: (v) {
            if (v != null) _onSelectSource(v);
          },
        );
      },
    );
  }

  /// Extract items from invoices using your common schema keys:
  /// model/model_name/modelName/productModel, colour/color, size, base, curl, density,
  /// and qty/quantity/pcs/count. Also supports nested `product{...}`.
  List<Map<String, dynamic>> _extractInvoiceItems(Map<String, dynamic> data) {
    List<dynamic> rawList = const [];
    dynamic raw = data['items'] ?? data['lineItems'] ?? data['products'] ?? data['orderItems'];

    if (raw is List) {
      rawList = raw;
    } else if (raw is Map) {
      rawList = raw.values.toList();
    }

    String _getStr(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
      }
      return '';
    }

    int _getQty(Map<String, dynamic> m) {
      final q = m['qty'] ?? m['quantity'] ?? m['pcs'] ?? m['count'] ?? 1;
      if (q is num) return q.toInt().clamp(1, 999999);
      return int.tryParse('$q')?.clamp(1, 999999) ?? 1;
    }

    return rawList.map<Map<String, dynamic>>((e) {
      final m = (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      final prod = (m['product'] is Map) ? Map<String, dynamic>.from(m['product']) : <String, dynamic>{};

      final pick = {...prod, ...m};

      final model   = _getStr(pick, ['model', 'model_name', 'modelName', 'productModel', 'name', 'productName', 'item']);
      final colour  = _getStr(pick, ['colour', 'color']);
      final size    = _getStr(pick, ['size', 'variant']);
      final base    = _getStr(pick, ['base']);
      final curl    = _getStr(pick, ['curl']);
      final density = _getStr(pick, ['density']);
      final qty     = _getQty(pick);

      final out = <String, dynamic>{
        'model': model,
        'colour': colour,
        'size': size,
        'qty': qty,
      };
      if (base.isNotEmpty) out['base'] = base;
      if (curl.isNotEmpty) out['curl'] = curl;
      if (density.isNotEmpty) out['density'] = density;

      return out;
    }).where((m) => (m['model'] as String).isNotEmpty).toList();
  }

  Future<void> _onSelectSource(String v) async {
    setState(() => _sourceId = v);

    if (v == 'stock') {
      _items.clear();
      _invoiceData = null;
      _trackingCtrl.clear();
      setState(() {});
      return;
    }

    // Load selected invoice and map its items
    final doc = await FirebaseFirestore.instance.collection('invoices').doc(v).get();
    final data = doc.data();
    if (data == null) return;

    final mapped = _extractInvoiceItems(data);

    if (mapped.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items found on the invoice to add automatically.')),
      );
    }

    setState(() {
      _items
        ..clear()
        ..addAll(mapped);

      _invoiceData = data;

      // auto-fill tracking & buyer
      _trackingCtrl.text = _deriveTrackingFromInvoice(data);
      _buyerNameCtrl.text = (data['customerName'] ?? _buyerNameCtrl.text).toString();
    });
  }

  // ---------- Item bottom sheet ----------

  Future<void> _openItemSheet({int? index}) async {
    // Local state for the sheet
    String? model;
    String? colour;
    String? size;
    String? base;
    String? curl;
    String? density;
    int qty = 1;

    if (index != null) {
      final it = _items[index];
      model = (it['model'] ?? '') as String?;
      colour = (it['colour'] ?? '') as String?;
      size = (it['size'] ?? '') as String?;
      base = (it['base'] ?? '') as String?;
      curl = (it['curl'] ?? '') as String?;
      density = (it['density'] ?? '') as String?;
      qty = (it['qty'] as int?) ?? 1;
    }

    List<String> _models() =>
        _products.map((p) => (p.data()!['model_name'] ?? '').toString()).where((s) => s.isNotEmpty).toSet().toList()
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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
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
                const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w900)),
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
                  items: (bases.isEmpty ? [''] : bases).map((b) => DropdownMenuItem(value: b, child: Text(b.isEmpty ? '(none)' : b))).toList(),
                  onChanged: (v) => setLocal(() => base = (v ?? '').isEmpty ? null : v),
                  decoration: _fieldDeco('Base'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: curl?.isEmpty == true ? null : curl,
                  items: (curls.isEmpty ? [''] : curls).map((c) => DropdownMenuItem(value: c, child: Text(c.isEmpty ? '(none)' : c))).toList(),
                  onChanged: (v) => setLocal(() => curl = (v ?? '').isEmpty ? null : v),
                  decoration: _fieldDeco('Curl'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: density?.isEmpty == true ? null : density,
                  items: (densities.isEmpty ? [''] : densities).map((d) => DropdownMenuItem(value: d, child: Text(d.isEmpty ? '(none)' : d))).toList(),
                  onChanged: (v) => setLocal(() => density = (v ?? '').isEmpty ? null : v),
                  decoration: _fieldDeco('Density'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Qty', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    _qtyMiniStepper(
                      qty: qty,
                      onChanged: (v) => setLocal(() => qty = v),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: (model == null || colour == null || size == null)
                          ? null
                          : () {
                        final m = <String, dynamic>{
                          'model': model!,
                          'colour': colour!,
                          'size': size!,
                          'qty': qty.clamp(1, 999),
                        };
                        if ((base ?? '').isNotEmpty) m['base'] = base!;
                        if ((curl ?? '').isNotEmpty) m['curl'] = curl!;
                        if ((density ?? '').isNotEmpty) m['density'] = density!;
                        setState(() {
                          if (index != null) {
                            _items[index] = m;
                          } else {
                            _items.add(m);
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _qtyMiniStepper({required int qty, required ValueChanged<int> onChanged}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roundBtn(Icons.remove, () => onChanged((qty - 1).clamp(1, 999))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        _roundBtn(Icons.add, () => onChanged((qty + 1).clamp(1, 999))),
      ],
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blueGrey.shade100),
        ),
        child: Icon(icon, color: _indigo, size: 18),
      ),
    );
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
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

  Widget _hintStrip(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: _chipBg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _invoicePreview(Map<String, dynamic> m) {
    final inv = (m['invoiceNo'] ?? '').toString();
    final cust = (m['customerName'] ?? '—').toString();
    final total = ((m['grandTotal'] as num?) ?? 0).toDouble();
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

    final trk = _deriveTrackingFromInvoice(m);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _panelDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long, color: _indigo),
          const SizedBox(width: 8),
          Text('Invoice $inv', style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 10, runSpacing: 6, children: [
          _pill('Customer: $cust'),
          _pill('Items: $cnt'),
          _pill('৳${total.toStringAsFixed(2)}'),
          _pill(_niceDate(date)),
          _pill('Tracking: $trk'),
        ]),
      ]),
    );
  }

  Widget _previewCard() {
    final totalItems = _items.fold<int>(0, (s, it) => s + (it['qty'] as int? ?? 0));
    final invNo = (_invoiceData?['invoiceNo'] ?? '').toString();

    final woNo = _invoiceData == null
        ? 'WO_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}'
        : 'INV${invNo}_WO_${DateFormat('yyyyMMdd').format(_finalDate)}';

    final trk = _trackingCtrl.text.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDeco(),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          Text('WO No: $woNo', style: const TextStyle(fontWeight: FontWeight.w800)),
          _pill('Buyer: ${_buyerNameCtrl.text.trim().isEmpty ? '—' : _buyerNameCtrl.text.trim()}'),
          _pill('Items: $totalItems'),
          _pill('Delivery: $_deliveryDays day(s)'),
          _pill('Final: ${_niceDate(_finalDate)}'),
          _pill(trk.isEmpty ? 'Tracking: — (required)' : 'Tracking: $trk'),
        ],
      ),
    );
  }

  void _resetFormEphemeral() {
    _formKey.currentState?.reset();
    _sourceId = 'stock';
    _invoiceData = null;
    _items.clear();
    _deliveryDays = 7;
    _finalDate = DateTime.now().add(const Duration(days: 7));
    _notesCtrl.clear();
    _trackingCtrl.clear();
    setState(() {});
  }

  // ---------- Submit (with hard uniqueness) ----------

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final uid = user?.uid ?? '';

    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item.')));
      return;
    }

    final tracking = _trackingCtrl.text.trim();
    if (tracking.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tracking number is required.')));
      return;
    }

    final workNo = _invoiceData == null
        ? 'WO_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}'
        : '${_invoiceData!['invoiceNo']}_WO_${DateFormat('yyyyMMdd').format(_finalDate)}';

    // build items list; include optional fields only if present
    final itemsForWrite = _items.map((e) {
      final m = <String, dynamic>{
        'model': e['model'],
        'colour': e['colour'],
        'size': e['size'],
        'qty': e['qty'],
      };
      if ((e['base'] ?? '').toString().isNotEmpty) m['base'] = e['base'];
      if ((e['curl'] ?? '').toString().isNotEmpty) m['curl'] = e['curl'];
      if ((e['density'] ?? '').toString().isNotEmpty) m['density'] = e['density'];
      return m;
    }).toList();

    final woData = <String, dynamic>{
      'workOrderNo': workNo,
      'invoiceId': _sourceId == 'stock' ? null : _sourceId,
      'linkedToInvoice': _sourceId != 'stock',
      'items': itemsForWrite,

      // identities
      'buyerName': _buyerNameCtrl.text.trim(),
      'makerName': _buyerNameCtrl.text.trim(), // legacy compatibility
      'makerEmail': email,
      'makerUid': uid,
      'agentEmail': email, // legacy

      'deliveryDays': _deliveryDays,
      'finalDate': Timestamp.fromDate(_finalDate),
      'instructions': _notesCtrl.text.trim(),
      'status': 'Pending',
      'submittedToFactory': false,
      'timestamp': FieldValue.serverTimestamp(),
      'tracking_number': tracking, // REQUIRED
    };

    final woRef = FirebaseFirestore.instance.collection('work_orders').doc(workNo);
    final idxRef = FirebaseFirestore.instance.collection('tracking_index').doc(tracking);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final idxSnap = await tx.get(idxRef);
        if (idxSnap.exists) {
          throw StateError('TRACKING_TAKEN');
        }
        // Reserve the tracking first (acts like a uniqueness lock).
        tx.set(idxRef, {
          'workOrderNo': workNo,
          'makerEmail': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Then create the work order.
        tx.set(woRef, woData);
      });
    } on StateError catch (e) {
      if (e.message == 'TRACKING_TAKEN') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A work order already exists for tracking “$tracking”.')),
        );
        return;
      }
      rethrow;
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Work order submitted • Tracking: $tracking')),
    );
  }
}
