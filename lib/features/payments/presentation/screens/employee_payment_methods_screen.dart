// lib/features/payments/presentation/screens/employee_payment_methods_screen.dart
//
// Employee Payment Methods — card-based, multi-method screen.
// Used by ALL departments (Marketing, Admin, Factory, R&D) via the Salary screen.
//
// Firestore path: data/{companyId}/users/{employeeUid}/payment_methods/{methodId}
// Mirror fields on parent doc for quick HR reads:
//   defaultPaymentMethodId, paymentMethod, paymentAccount, paymentName, paymentVerified
//
// Features:
//   • View all saved payment methods as cards
//   • Add new method (bottom sheet form)
//   • Edit existing method
//   • Delete method
//   • Set default method (used for salary dispatch)
//   • Shows HR verification status per method
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import '../../../payments/domain/models/employee_payment_method_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _brand   = Color(0xFF065F46);
const Color _brandLt = Color(0xFFD1FAE5);
const Color _bg       = Color(0xFFF0FDF4);
const Color _card     = Color(0xFFFFFFFF);
const Color _border   = Color(0x14000000);
const Color _fg       = Color(0xFF0F172A);
const Color _muted    = Color(0xFF94A3B8);
const Color _red      = Color(0xFFDC2626);
const Color _amber    = Color(0xFFD97706);

// ── Method brand colors ───────────────────────────────────────────────────────
Color _methodColor(EmpPayMethodType t) => switch (t) {
      EmpPayMethodType.bkash  => const Color(0xFFE2136E),
      EmpPayMethodType.nagad  => const Color(0xFFEF4444),
      EmpPayMethodType.rocket => const Color(0xFF8B5CF6),
      EmpPayMethodType.upay   => const Color(0xFF059669),
      EmpPayMethodType.bank   => const Color(0xFF0891B2),
      EmpPayMethodType.cash   => const Color(0xFF16A34A),
      EmpPayMethodType.other  => const Color(0xFF6B7280),
    };

IconData _methodIcon(EmpPayMethodType t) => switch (t) {
      EmpPayMethodType.bkash  => Icons.phone_android_rounded,
      EmpPayMethodType.nagad  => Icons.phone_android_rounded,
      EmpPayMethodType.rocket => Icons.phone_android_rounded,
      EmpPayMethodType.upay   => Icons.phone_android_rounded,
      EmpPayMethodType.bank   => Icons.account_balance_rounded,
      EmpPayMethodType.cash   => Icons.payments_rounded,
      EmpPayMethodType.other  => Icons.wallet_rounded,
    };

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class EmployeePaymentMethodsScreen extends StatefulWidget {
  const EmployeePaymentMethodsScreen({super.key});
  @override
  State<EmployeePaymentMethodsScreen> createState() =>
      _EmployeePaymentMethodsScreenState();
}

class _EmployeePaymentMethodsScreenState
    extends State<EmployeePaymentMethodsScreen> {
  String _cid = '';
  String _uid = '';
  bool   _cidLoaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cid = await LocalStorageService.getSavedCompanyId();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (mounted) {
      setState(() {
        _cid       = cid ?? '';
        _uid       = uid;
        _cidLoaded = true;
      });
    }
  }

  // ── Firestore helpers ──────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _methodsCol =>
      DB.colSync(_cid, C.users).doc(_uid).collection('payment_methods');

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      DB.colSync(_cid, C.users).doc(_uid);

  Stream<List<EmployeePaymentMethod>> _methodsStream() {
    if (_cid.isEmpty || _uid.isEmpty) return Stream.value([]);
    return _methodsCol
        .orderBy('isDefault', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => EmployeePaymentMethod.fromDoc(d))
            .toList());
  }

  // ── Set default ────────────────────────────────────────────────────────────
  Future<void> _setDefault(EmployeePaymentMethod method,
      List<EmployeePaymentMethod> all) async {
    final batch = DB.firestore.batch();

    // Clear default on all others
    for (final m in all) {
      if (m.id != method.id && m.isDefault) {
        batch.update(_methodsCol.doc(m.id), {'isDefault': false});
      }
    }
    // Set this one as default
    batch.update(_methodsCol.doc(method.id), {'isDefault': true});

    // Mirror to parent users doc for HR quick-read
    batch.update(_userDoc, {
      'defaultPaymentMethodId': method.id,
      'paymentMethod':          method.type.label,
      'paymentAccount':         method.accountNumber,
      'paymentName':            method.accountName,
      'paymentVerified':        false, // HR must re-verify after change
      'paymentUpdatedAt':       FieldValue.serverTimestamp(),
    });

    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${method.type.label} set as default'),
          backgroundColor: _brand,
        ),
      );
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _delete(EmployeePaymentMethod method) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Payment Method',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Remove ${method.type.label} (${method.maskedAccount})? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final batch = DB.firestore.batch();
    batch.delete(_methodsCol.doc(method.id));

    // If this was the default, clear mirror fields
    if (method.isDefault) {
      batch.update(_userDoc, {
        'defaultPaymentMethodId': FieldValue.delete(),
        'paymentMethod':          FieldValue.delete(),
        'paymentAccount':         FieldValue.delete(),
        'paymentName':            FieldValue.delete(),
        'paymentVerified':        false,
      });
    }
    await batch.commit();
  }

  // ── Open add/edit sheet ────────────────────────────────────────────────────
  void _openForm({EmployeePaymentMethod? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaymentMethodForm(
        cid:      _cid,
        uid:      _uid,
        existing: existing,
        onSaved:  (method) async {
          // Mirror default to parent doc if this is/was default
          if (method.isDefault) {
            await _userDoc.update({
              'defaultPaymentMethodId': method.id,
              'paymentMethod':          method.type.label,
              'paymentAccount':         method.accountNumber,
              'paymentName':            method.accountName,
              'paymentVerified':        false,
              'paymentUpdatedAt':       FieldValue.serverTimestamp(),
            });
          }
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Payment Methods',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Add Method',
            onPressed: () => _openForm(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Method',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: !_cidLoaded
          ? const Center(child: CircularProgressIndicator(color: _brand))
          : _cid.isEmpty || _uid.isEmpty
              ? const Center(
                  child: Text('Please log in to manage payment methods'))
              : StreamBuilder<List<EmployeePaymentMethod>>(
                  stream: _methodsStream(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: _brand));
                    }
                    final methods = snap.data ?? [];

                    if (methods.isEmpty) {
                      return _EmptyState(onAdd: () => _openForm());
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        // Info banner
                        _InfoBanner(),
                        const SizedBox(height: 16),

                        // Method cards
                        ...methods.map((m) => _MethodCard(
                              method:    m,
                              onSetDefault: methods.length > 1
                                  ? () => _setDefault(m, methods)
                                  : null,
                              onEdit:    () => _openForm(existing: m),
                              onDelete:  () => _delete(m),
                            )),
                      ],
                    );
                  },
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _brandLt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _brand.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: _brand, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Your default method is used when HR sends your salary. '
              'HR must verify each method before it can be used for payment.',
              style: TextStyle(
                  fontSize: 12, color: _brand, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// METHOD CARD
// ─────────────────────────────────────────────────────────────────────────────
class _MethodCard extends StatelessWidget {
  final EmployeePaymentMethod method;
  final VoidCallback?         onSetDefault;
  final VoidCallback          onEdit;
  final VoidCallback          onDelete;

  const _MethodCard({
    required this.method,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _methodColor(method.type);
    final icon  = _methodIcon(method.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: method.isDefault
              ? color.withValues(alpha: 0.5)
              : _border,
          width: method.isDefault ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(children: [
              // Method icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              // Method type + account name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(method.type.label,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: color)),
                      if (method.isDefault) ...[
                        const SizedBox(width: 8),
                        _Chip(
                          label: 'Default',
                          color: _brand,
                          icon: Icons.star_rounded,
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      method.accountName.isNotEmpty
                          ? method.accountName
                          : 'No name set',
                      style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              // Verification badge
              _Chip(
                label: method.isVerifiedByHr ? 'Verified' : 'Unverified',
                color: method.isVerifiedByHr ? _brand : _amber,
                icon: method.isVerifiedByHr
                    ? Icons.verified_rounded
                    : Icons.pending_actions_rounded,
              ),
            ]),
          ),

          // ── Account number ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.credit_card_rounded,
                    size: 14, color: color.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Text(
                  method.maskedAccount,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _fg,
                      letterSpacing: 1),
                ),
                const Spacer(),
                Text(method.accountNumber,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ),

          // ── Bank details (if bank transfer) ──────────────────────────────
          if (method.isBank &&
              (method.bankName.isNotEmpty ||
                  method.branchName.isNotEmpty)) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                if (method.bankName.isNotEmpty)
                  _DetailPill(
                      icon: Icons.account_balance_rounded,
                      text: method.bankName),
                if (method.bankName.isNotEmpty &&
                    method.branchName.isNotEmpty)
                  const SizedBox(width: 6),
                if (method.branchName.isNotEmpty)
                  _DetailPill(
                      icon: Icons.location_city_rounded,
                      text: method.branchName),
              ]),
            ),
          ],

          const SizedBox(height: 10),

          // ── Action row ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              // Set as Default
              if (!method.isDefault && onSetDefault != null)
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: _brand,
                        padding: const EdgeInsets.symmetric(vertical: 10)),
                    onPressed: onSetDefault,
                    icon: const Icon(Icons.star_outline_rounded, size: 15),
                    label: const Text('Set Default',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (!method.isDefault && onSetDefault != null)
                Container(
                    width: 1, height: 20, color: _border),
              // Edit
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                      foregroundColor: _brand,
                      padding: const EdgeInsets.symmetric(vertical: 10)),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('Edit',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              Container(width: 1, height: 20, color: _border),
              // Delete
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                      foregroundColor: _red,
                      padding: const EdgeInsets.symmetric(vertical: 10)),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('Remove',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD / EDIT FORM (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentMethodForm extends StatefulWidget {
  final String                    cid;
  final String                    uid;
  final EmployeePaymentMethod?    existing;
  final Future<void> Function(EmployeePaymentMethod) onSaved;

  const _PaymentMethodForm({
    required this.cid,
    required this.uid,
    required this.onSaved,
    this.existing,
  });

  @override
  State<_PaymentMethodForm> createState() => _PaymentMethodFormState();
}

class _PaymentMethodFormState extends State<_PaymentMethodForm> {
  final _formKey      = GlobalKey<FormState>();
  final _accountCtl   = TextEditingController();
  final _nameCtl      = TextEditingController();
  final _bankCtl      = TextEditingController();
  final _branchCtl    = TextEditingController();
  final _routingCtl   = TextEditingController();

  EmpPayMethodType _type      = EmpPayMethodType.bkash;
  bool             _isDefault = false;
  bool             _saving    = false;

  bool get _isBank => _type == EmpPayMethodType.bank;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type         = e.type;
      _accountCtl.text = e.accountNumber;
      _nameCtl.text    = e.accountName;
      _bankCtl.text    = e.bankName;
      _branchCtl.text  = e.branchName;
      _routingCtl.text = e.routingNumber;
      _isDefault       = e.isDefault;
    }
  }

  @override
  void dispose() {
    _accountCtl.dispose();
    _nameCtl.dispose();
    _bankCtl.dispose();
    _branchCtl.dispose();
    _routingCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final col = DB.colSync(widget.cid, C.users)
          .doc(widget.uid)
          .collection('payment_methods');

      final batch = DB.firestore.batch();

      // If setting as default, clear existing defaults first
      if (_isDefault) {
        final existing = await col.where('isDefault', isEqualTo: true).get();
        for (final d in existing.docs) {
          if (d.id != (widget.existing?.id ?? '')) {
            batch.update(d.reference, {'isDefault': false});
          }
        }
      }

      final data = {
        'type':          _type.label,
        'accountNumber': _accountCtl.text.trim(),
        'accountName':   _nameCtl.text.trim(),
        'bankName':      _isBank ? _bankCtl.text.trim() : '',
        'branchName':    _isBank ? _branchCtl.text.trim() : '',
        'routingNumber': _isBank ? _routingCtl.text.trim() : '',
        'isDefault':     _isDefault,
        'isVerifiedByHr': widget.existing?.isVerifiedByHr ?? false,
        'updatedAt':     FieldValue.serverTimestamp(),
      };

      DocumentReference<Map<String, dynamic>> ref;
      if (widget.existing != null) {
        ref = col.doc(widget.existing!.id);
        batch.update(ref, data);
      } else {
        ref = col.doc();
        batch.set(ref, {
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      final saved = EmployeePaymentMethod(
        id:            ref.id,
        type:          _type,
        accountNumber: _accountCtl.text.trim(),
        accountName:   _nameCtl.text.trim(),
        bankName:      _isBank ? _bankCtl.text.trim() : '',
        branchName:    _isBank ? _branchCtl.text.trim() : '',
        routingNumber: _isBank ? _routingCtl.text.trim() : '',
        isDefault:     _isDefault,
      );
      await widget.onSaved(saved);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 4,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              widget.existing == null
                  ? 'Add Payment Method'
                  : 'Edit Payment Method',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: _fg),
            ),
            const SizedBox(height: 16),

            // ── Method type selector ─────────────────────────────────────
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Payment Type',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _fg)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EmpPayMethodType.values.map((t) {
                final selected = _type == t;
                final color    = _methodColor(t);
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.12)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: selected
                              ? color
                              : Colors.transparent,
                          width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_methodIcon(t),
                          size: 14,
                          color: selected ? color : _muted),
                      const SizedBox(width: 6),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected ? color : _muted)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Account number ───────────────────────────────────────────
            TextFormField(
              controller: _accountCtl,
              keyboardType: TextInputType.phone,
              decoration: _dec(
                _isBank ? 'Account Number' : 'Wallet Number',
                _methodIcon(_type),
              ),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // ── Account holder name ──────────────────────────────────────
            TextFormField(
              controller: _nameCtl,
              decoration: _dec('Account Holder Name', Icons.person_rounded),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // ── Bank-specific fields ─────────────────────────────────────
            if (_isBank) ...[
              TextFormField(
                controller: _bankCtl,
                decoration: _dec('Bank Name', Icons.account_balance_rounded),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _branchCtl,
                decoration: _dec('Branch Name', Icons.location_city_rounded),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _routingCtl,
                keyboardType: TextInputType.number,
                decoration: _dec('Routing Number', Icons.numbers_rounded),
              ),
              const SizedBox(height: 12),
            ],

            // ── Set as default toggle ────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isDefault
                    ? _brand.withValues(alpha: 0.06)
                    : const Color(0xFFF8FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _isDefault
                        ? _brand.withValues(alpha: 0.3)
                        : _border),
              ),
              child: Row(children: [
                Icon(
                  _isDefault
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: _isDefault ? _brand : _muted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Set as Default',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _fg)),
                      Text('Used for salary payments',
                          style: TextStyle(
                              fontSize: 11, color: _muted)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isDefault,
                  activeThumbColor: _brand,
                  activeTrackColor: _brand.withValues(alpha: 0.4),
                  onChanged: (v) => setState(() => _isDefault = v),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Save button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _saving
                      ? 'Saving…'
                      : widget.existing == null
                          ? 'Add Method'
                          : 'Save Changes',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _brand, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;
  const _Chip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ]),
      );
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _DetailPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: _muted),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 10,
                  color: _fg,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _brandLt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  size: 36, color: _brand),
            ),
            const SizedBox(height: 16),
            const Text('No payment methods yet',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _fg)),
            const SizedBox(height: 8),
            const Text(
              'Add your bKash, Nagad, or bank account\nso HR can send your salary directly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Payment Method',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );
}
