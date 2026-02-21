// lib/features/hr/presentation/screens/procurement_screen.dart
//
// Procurement Requests — full approval workflow
//
// Flow:
//   1. Any department (factory / marketing / rnd) submits a request  → status: 'Pending'
//   2. HR reviews and approves                                        → status: 'Approved'
//   3. HR confirms item received / payment done                       → status: 'Received'
//      ↳ AUTO-WRITES to:
//          • data/{cid}/expenses/{newId}   (type: 'procurement')
//          • data/{cid}/cash_flow/{newId}  (type: 'cash_out')
//          • data/{cid}/company_profile/main  cashOut += amount
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────────────────────
const Color _brand   = Color(0xFF1E3A5F);
const Color _mid     = Color(0xFF2563EB);
const Color _bg      = Color(0xFFF4F6FA);
const Color _card    = Colors.white;
const Color _border  = Color(0xFFE2E8F0);
const Color _text1   = Color(0xFF0F172A);
const Color _text2   = Color(0xFF64748B);
const Color _green   = Color(0xFF16A34A);
const Color _amber   = Color(0xFFD97706);
const Color _red     = Color(0xFFDC2626);
const Color _teal    = Color(0xFF0D9488);
const Color _purple  = Color(0xFF7C3AED);

TextStyle _ts(double sz, {FontWeight w = FontWeight.w400, Color c = _text1}) =>
    GoogleFonts.inter(fontSize: sz, fontWeight: w, color: c);

final _money = NumberFormat('#,##0.00', 'en');

// ─────────────────────────────────────────────────────────────
// STATUS HELPERS
// ─────────────────────────────────────────────────────────────
const _statuses = ['Pending', 'Approved', 'Received', 'Cancelled'];

Color _statusColor(String s) {
  switch (s) {
    case 'Approved': return _green;
    case 'Received': return _teal;
    case 'Cancelled': return _red;
    default: return _amber;
  }
}

IconData _statusIcon(String s) {
  switch (s) {
    case 'Approved': return Icons.check_circle_rounded;
    case 'Received': return Icons.inventory_2_rounded;
    case 'Cancelled': return Icons.cancel_rounded;
    default: return Icons.hourglass_top_rounded;
  }
}

// ─────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────
class ProcurementScreen extends StatefulWidget {
  const ProcurementScreen({super.key});
  @override
  State<ProcurementScreen> createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends State<ProcurementScreen>
    with SingleTickerProviderStateMixin {
  String _cid = '';
  String _hrName  = '';
  String _hrEmail = '';
  String _hrUid   = '';
  late TabController _tabs;
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadHr();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadHr() async {
    final session = await LocalStorageService.getSession();
    final user    = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    setState(() {
      _hrUid   = user?.uid   ?? (session?['uid']   as String? ?? '');
      _hrEmail = user?.email ?? (session?['email'] as String? ?? '');
      _hrName  = (session?['name'] as String?) ?? user?.displayName ?? 'HR';
    });
  }

  // ── Approve ─────────────────────────────────────────────────
  Future<void> _approve(DocumentSnapshot doc) async {
    await DB.colSync(_cid, C.procurements).doc(doc.id).update({
      'status':     'Approved',
      'approvedBy': _hrEmail,
      'approvedByName': _hrName,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt':  FieldValue.serverTimestamp(),
    });
    _snack('Procurement approved.', color: _green);

    // Notify requester
    final data = doc.data() as Map<String, dynamic>;
    final requesterEmail = data['requestedByEmail'] as String? ?? '';
    if (requesterEmail.isNotEmpty) {
      await DB.colSync(_cid, C.notifications).add({
        'type':        'procurement_approved',
        'title':       'Procurement Approved ✓',
        'body':        'Your request for "${data['item']}" has been approved by HR.',
        'targetEmail': requesterEmail,
        'read':        false,
        'createdAt':   FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Mark Received (triggers expense + cash_flow write) ──────
  Future<void> _markReceived(DocumentSnapshot doc) async {
    final data   = doc.data() as Map<String, dynamic>;
    final item   = data['item'] as String? ?? 'Procurement';
    final vendor = data['vendor'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final qty    = data['quantity']?.toString() ?? '1';
    final dept   = data['requestedByDept'] as String? ?? '';
    final requesterEmail = data['requestedByEmail'] as String? ?? '';

    final batch = DB.firestore.batch();

    // 1. Update procurement status
    batch.update(DB.colSync(_cid, C.procurements).doc(doc.id), {
      'status':       'Received',
      'receivedBy':   _hrEmail,
      'receivedByName': _hrName,
      'receivedAt':   FieldValue.serverTimestamp(),
      'updatedAt':    FieldValue.serverTimestamp(),
    });

    // 2. Auto-add to expenses
    final expRef = DB.colSync(_cid, C.expenses).doc();
    batch.set(expRef, {
      'vendor':      vendor.isNotEmpty ? vendor : 'Procurement',
      'category':    'Procurement',
      'item':        item,
      'quantity':    qty,
      'amount':      amount,
      'department':  dept,
      'dueDate':     Timestamp.now(),
      'status':      'paid',
      'costCenter':  dept.isNotEmpty ? dept.toUpperCase() : 'GENERAL',
      'notes':       'Auto-added from procurement: $item (Qty: $qty) from $vendor',
      'procurementId': doc.id,
      'addedBy':     _hrEmail,
      'addedByName': _hrName,
      'createdAt':   FieldValue.serverTimestamp(),
    });

    // 3. Auto-add to cash_flow as cash_out
    final cfRef = DB.colSync(_cid, C.cashFlow).doc();
    batch.set(cfRef, {
      'type':          'cash_out',
      'amount':        amount,
      'currency':      'BDT',
      'method':        'procurement',
      'description':   'Procurement payment: $item (Qty: $qty) from $vendor',
      'department':    dept,
      'procurementId': doc.id,
      'approvedBy':    _hrEmail,
      'approvedByName': _hrName,
      'date':          Timestamp.now(),
      'createdAt':     FieldValue.serverTimestamp(),
    });

    // 4. Increment company cashOut total
    if (amount > 0) {
      batch.update(DB.colSync(_cid, C.companyProfile).doc('main'), {
        'cashOut':           FieldValue.increment(amount),
        'lastCashOutAt':     FieldValue.serverTimestamp(),
        'lastCashOutAmount': amount,
        'lastCashOutItem':   item,
      });
    }

    // 5. Notify requester
    if (requesterEmail.isNotEmpty) {
      final notifRef = DB.colSync(_cid, C.notifications).doc();
      batch.set(notifRef, {
        'type':        'procurement_received',
        'title':       'Procurement Received ✓',
        'body':        'Your request for "$item" has been received and payment recorded.',
        'targetEmail': requesterEmail,
        'read':        false,
        'createdAt':   FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    _snack('Marked received. Expense & cash flow updated.', color: _teal);
  }

  // ── Cancel ──────────────────────────────────────────────────
  Future<void> _cancel(DocumentSnapshot doc) async {
    await DB.colSync(_cid, C.procurements).doc(doc.id).update({
      'status':       'Cancelled',
      'cancelledBy':  _hrEmail,
      'cancelledAt':  FieldValue.serverTimestamp(),
      'updatedAt':    FieldValue.serverTimestamp(),
    });
    _snack('Procurement cancelled.', color: _red);
  }

  // ── Delete ──────────────────────────────────────────────────
  Future<void> _delete(String id) async {
    await DB.colSync(_cid, C.procurements).doc(id).delete();
    _snack('Deleted.');
  }

  void _snack(String msg, {Color color = _brand}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _ts(13, w: FontWeight.w600, c: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── New / Edit form ─────────────────────────────────────────
  Future<void> _showForm({DocumentSnapshot? doc}) async {
    final isEdit = doc != null;
    final data   = isEdit ? (doc.data() as Map<String, dynamic>) : <String, dynamic>{};

    final itemCtl   = TextEditingController(text: data['item'] ?? '');
    final qtyCtl    = TextEditingController(text: data['quantity']?.toString() ?? '');
    final vendorCtl = TextEditingController(text: data['vendor'] ?? '');
    final amountCtl = TextEditingController(text: data['amount']?.toString() ?? '');
    final noteCtl   = TextEditingController(text: data['notes'] ?? '');
    String dept = data['requestedByDept'] ?? 'marketing';

    final depts = ['marketing', 'factory', 'rnd', 'hr', 'admin'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20, right: 20, top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: _border,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(isEdit ? 'Edit Procurement' : 'New Procurement Request',
                  style: _ts(16, w: FontWeight.w700)),
              const SizedBox(height: 20),

              _Field(controller: itemCtl,   label: 'Item Name',   icon: Icons.inventory_2_outlined),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Field(controller: qtyCtl, label: 'Quantity',
                    icon: Icons.numbers_rounded, keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _Field(controller: amountCtl, label: 'Estimated Amount (৳)',
                    icon: Icons.attach_money_rounded, keyboard: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              _Field(controller: vendorCtl, label: 'Vendor / Supplier', icon: Icons.store_outlined),
              const SizedBox(height: 12),
              _Field(controller: noteCtl,   label: 'Notes (optional)', icon: Icons.notes_rounded, maxLines: 2),
              const SizedBox(height: 12),

              // Department
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: dept,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _text2),
                    style: _ts(14),
                    items: depts.map((d) => DropdownMenuItem(
                      value: d,
                      child: Row(children: [
                        const Icon(Icons.business_rounded, size: 16, color: _text2),
                        const SizedBox(width: 8),
                        Text(d.toUpperCase(), style: _ts(13, w: FontWeight.w600)),
                      ]),
                    )).toList(),
                    onChanged: (v) => ss(() => dept = v!),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (itemCtl.text.trim().isEmpty) return;
                    final session = await LocalStorageService.getSession();
                    final user    = FirebaseAuth.instance.currentUser;
                    final myEmail = user?.email ?? (session?['email'] as String? ?? '');
                    final myName  = (session?['name'] as String?) ?? user?.displayName ?? 'Unknown';

                    final payload = {
                      'item':     itemCtl.text.trim(),
                      'quantity': int.tryParse(qtyCtl.text.trim()) ?? 1,
                      'vendor':   vendorCtl.text.trim(),
                      'amount':   double.tryParse(amountCtl.text.trim()) ?? 0.0,
                      'notes':    noteCtl.text.trim(),
                      'requestedByDept':  dept,
                      'requestedByEmail': myEmail,
                      'requestedByName':  myName,
                      'requestedAt': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    if (isEdit) {
                      await DB.colSync(_cid, C.procurements).doc(doc.id).update(payload);
                    } else {
                      await DB.colSync(_cid, C.procurements).add({
                        ...payload,
                        'status':    'Pending',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      // Notify HR
                      await DB.colSync(_cid, C.notifications).add({
                        'type':        'procurement_request',
                        'title':       'New Procurement Request',
                        'body':        '$myName requested "${itemCtl.text.trim()}" (Qty: ${qtyCtl.text.trim()}) from $dept.',
                        'targetRole':  'hr',
                        'targetDept':  'hr',
                        'read':        false,
                        'createdAt':   FieldValue.serverTimestamp(),
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(isEdit ? 'Update Request' : 'Submit Request',
                      style: _ts(15, w: FontWeight.w700, c: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Procurement', style: _ts(17, w: FontWeight.w700, c: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Received'),
            Tab(text: 'All'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Request', style: _ts(13, w: FontWeight.w700, c: Colors.white)),
      ),
      body: Column(
        children: [
          // ── Summary strip ──────────────────────────────────────
          _SummaryStrip(cid: _cid),
          // ── Tab views ──────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ProcList(cid: _cid, statusFilter: 'Pending',
                    onApprove: _approve, onReceive: _markReceived,
                    onCancel: _cancel, onEdit: _showForm, onDelete: _delete),
                _ProcList(cid: _cid, statusFilter: 'Approved',
                    onApprove: _approve, onReceive: _markReceived,
                    onCancel: _cancel, onEdit: _showForm, onDelete: _delete),
                _ProcList(cid: _cid, statusFilter: 'Received',
                    onEdit: _showForm, onDelete: _delete),
                _ProcList(cid: _cid, statusFilter: 'All',
                    onApprove: _approve, onReceive: _markReceived,
                    onCancel: _cancel, onEdit: _showForm, onDelete: _delete),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUMMARY STRIP
// ─────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final String cid;
  const _SummaryStrip({required this.cid});

  @override
  Widget build(BuildContext context) {
    if (cid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(cid, C.procurements).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        int pending = 0, approved = 0, received = 0;
        double totalSpend = 0;
        for (final d in docs) {
          final m = d.data() as Map<String, dynamic>;
          final s = m['status'] as String? ?? '';
          if (s == 'Pending')  pending++;
          if (s == 'Approved') approved++;
          if (s == 'Received') {
            received++;
            totalSpend += (m['amount'] as num?)?.toDouble() ?? 0;
          }
        }
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            _Strip('Pending',  '$pending',  _amber),
            _Strip('Approved', '$approved', _green),
            _Strip('Received', '$received', _teal),
            _Strip('Spent',    '৳${_money.format(totalSpend)}', _purple),
          ]),
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Strip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: _ts(10, c: _text2)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROCUREMENT LIST
// ─────────────────────────────────────────────────────────────
class _ProcList extends StatelessWidget {
  final String cid, statusFilter;
  final Future<void> Function(DocumentSnapshot)? onApprove;
  final Future<void> Function(DocumentSnapshot)? onReceive;
  final Future<void> Function(DocumentSnapshot)? onCancel;
  final Future<void> Function({DocumentSnapshot? doc})? onEdit;
  final Future<void> Function(String)? onDelete;

  const _ProcList({
    required this.cid, required this.statusFilter,
    this.onApprove, this.onReceive, this.onCancel, this.onEdit, this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (cid.isEmpty) return const Center(child: CircularProgressIndicator());

    Query<Map<String, dynamic>> q = DB.colSync(cid, C.procurements)
        .orderBy('createdAt', descending: true);
    if (statusFilter != 'All') {
      q = q.where('status', isEqualTo: statusFilter);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _brand));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _EmptyState(status: statusFilter);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) => _ProcCard(
            doc: docs[i],
            onApprove: onApprove,
            onReceive: onReceive,
            onCancel: onCancel,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROCUREMENT CARD
// ─────────────────────────────────────────────────────────────
class _ProcCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function(DocumentSnapshot)? onApprove;
  final Future<void> Function(DocumentSnapshot)? onReceive;
  final Future<void> Function(DocumentSnapshot)? onCancel;
  final Future<void> Function({DocumentSnapshot? doc})? onEdit;
  final Future<void> Function(String)? onDelete;

  const _ProcCard({
    required this.doc,
    this.onApprove, this.onReceive, this.onCancel, this.onEdit, this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final d       = doc.data();
    final item    = d['item'] as String? ?? 'Unknown Item';
    final qty     = d['quantity']?.toString() ?? '—';
    final vendor  = d['vendor'] as String? ?? '—';
    final amount  = (d['amount'] as num?)?.toDouble() ?? 0.0;
    final dept    = (d['requestedByDept'] as String? ?? '').toUpperCase();
    final notes   = d['notes'] as String? ?? '';
    final status  = d['status'] as String? ?? 'Pending';
    final reqBy   = d['requestedByName'] as String? ?? d['requestedByEmail'] as String? ?? '—';
    final reqAt   = d['requestedAt'] as String? ?? '—';
    final approvedBy = d['approvedByName'] as String? ?? '';
    final receivedBy = d['receivedByName'] as String? ?? '';

    final sColor = _statusColor(status);
    final sIcon  = _statusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: sColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(sIcon, size: 20, color: sColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item, style: _ts(15, w: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Qty: $qty  ·  $vendor', style: _ts(12, c: _text2)),
                ]),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: sColor.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(sIcon, size: 11, color: sColor),
                  const SizedBox(width: 4),
                  Text(status, style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: sColor)),
                ]),
              ),
              // Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: _text2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) async {
                  if (v == 'edit')   await onEdit?.call(doc: doc);
                  if (v == 'delete') await onDelete?.call(doc.id);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit',
                      child: Row(children: [
                        const Icon(Icons.edit_outlined, size: 16), const SizedBox(width: 8),
                        Text('Edit', style: _ts(13)),
                      ])),
                  PopupMenuItem(value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline_rounded, size: 16, color: _red),
                        const SizedBox(width: 8),
                        Text('Delete', style: _ts(13, c: _red)),
                      ])),
                ],
              ),
            ]),
          ),

          // ── Details ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(spacing: 16, runSpacing: 8, children: [
              if (amount > 0)
                _Detail('Amount', '৳${_money.format(amount)}', color: _purple),
              if (dept.isNotEmpty)
                _Detail('Department', dept),
              _Detail('Requested By', reqBy),
              _Detail('Date', reqAt),
              if (approvedBy.isNotEmpty)
                _Detail('Approved By', approvedBy, color: _green),
              if (receivedBy.isNotEmpty)
                _Detail('Received By', receivedBy, color: _teal),
            ]),
          ),

          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.notes_rounded, size: 13, color: _text2),
                  const SizedBox(width: 6),
                  Expanded(child: Text(notes, style: _ts(12, c: _text2))),
                ]),
              ),
            ),

          // ── Received info banner ─────────────────────────────
          if (status == 'Received')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _teal.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: _teal),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    'Expense & cash-out auto-recorded.',
                    style: _ts(12, w: FontWeight.w600, c: _teal),
                  )),
                ]),
              ),
            ),

          // ── Action buttons ───────────────────────────────────
          if (status == 'Pending' || status == 'Approved')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(children: [
                if (status == 'Pending') ...[
                  Expanded(
                    child: _ActionBtn(
                      label: 'Approve',
                      icon: Icons.check_rounded,
                      color: _green,
                      onTap: () => onApprove?.call(doc),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Cancel',
                      icon: Icons.close_rounded,
                      color: _red,
                      outlined: true,
                      onTap: () => onCancel?.call(doc),
                    ),
                  ),
                ],
                if (status == 'Approved') ...[
                  Expanded(
                    child: _ActionBtn(
                      label: 'Mark Received & Done',
                      icon: Icons.inventory_2_rounded,
                      color: _teal,
                      onTap: () => _confirmReceive(context, doc),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Cancel',
                      icon: Icons.close_rounded,
                      color: _red,
                      outlined: true,
                      onTap: () => onCancel?.call(doc),
                    ),
                  ),
                ],
              ]),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  void _confirmReceive(BuildContext context, DocumentSnapshot doc) {
    final d      = doc.data() as Map<String, dynamic>;
    final item   = d['item'] as String? ?? 'Item';
    final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.inventory_2_rounded, color: _teal, size: 20),
          const SizedBox(width: 8),
          const Text('Confirm Receipt', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Mark "$item" as received?', style: _ts(14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _teal.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.receipt_long_rounded, size: 14, color: _teal),
                const SizedBox(width: 6),
                Text('This will automatically:', style: _ts(12, w: FontWeight.w700, c: _teal)),
              ]),
              const SizedBox(height: 6),
              Text('• Add ৳${_money.format(amount)} to Expenses', style: _ts(12, c: _text2)),
              Text('• Record as Cash Out in Cash Flow', style: _ts(12, c: _text2)),
              Text('• Update company financial summary', style: _ts(12, c: _text2)),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onReceive?.call(doc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm & Record'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.label, required this.icon, required this.color,
    this.outlined = false, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        icon: Icon(icon, size: 15),
        label: Text(label, style: _ts(12, w: FontWeight.w700)),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return ElevatedButton.icon(
      icon: Icon(icon, size: 15),
      label: Text(label, style: _ts(12, w: FontWeight.w700, c: Colors.white)),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FORM FIELD HELPER
// ─────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final int maxLines;

  const _Field({
    required this.controller, required this.label, required this.icon,
    this.keyboard = TextInputType.text, this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      inputFormatters: keyboard == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      style: _ts(14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _ts(13, c: _text2),
        prefixIcon: Icon(icon, size: 18, color: _text2),
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _brand, width: 1.5)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DETAIL CHIP
// ─────────────────────────────────────────────────────────────
class _Detail extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _Detail(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: _ts(10, w: FontWeight.w600, c: _text2)),
      const SizedBox(height: 2),
      Text(value, style: _ts(13, w: FontWeight.w700, c: color ?? _text1)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String status;
  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inventory_2_outlined, size: 52, color: _text2.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            status == 'All' ? 'No procurement requests yet.'
                : 'No ${status.toLowerCase()} requests.',
            style: _ts(15, w: FontWeight.w700, c: _text2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text('Tap "+ New Request" to add one.',
              style: _ts(13, c: _text2), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
