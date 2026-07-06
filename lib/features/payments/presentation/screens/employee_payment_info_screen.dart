// lib/features/payments/presentation/screens/employee_payment_info_screen.dart
//
// Allows an employee to view and update their own bank / mobile-wallet
// payment details so HR can dispatch salary payments to them.
//
// Accessible from any employee-facing dashboard via route:
//   /payments/my-payment-info
//
// Firestore path: data/{companyId}/users/{uid}
// Fields written: paymentMethod, paymentAccount, paymentName,
//                 bankName, branchName, routingNumber, paymentUpdatedAt
//                 paymentVerified is reset to false on any edit (HR must re-verify)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _brand    = Color(0xFF065F46);
const Color _brandMid = Color(0xFF10B981);
const Color _surface  = Color(0xFFF0FDF4);
const Color _amber    = Color(0xFFD97706);
const Color _red      = Color(0xFFDC2626);

const List<String> _paymentMethods = [
  'bKash',
  'Nagad',
  'Rocket',
  'Upay',
  'Bank Transfer',
  'Other',
];

const Map<String, IconData> _methodIcons = {
  'bKash':         Icons.phone_android_rounded,
  'Nagad':         Icons.phone_android_rounded,
  'Rocket':        Icons.phone_android_rounded,
  'Upay':          Icons.phone_android_rounded,
  'Bank Transfer': Icons.account_balance_rounded,
  'Other':         Icons.wallet_rounded,
};

const Map<String, Color> _methodColors = {
  'bKash':         Color(0xFFE2136E),
  'Nagad':         Color(0xFFEF4444),
  'Rocket':        Color(0xFF8B5CF6),
  'Upay':          Color(0xFF059669),
  'Bank Transfer': Color(0xFF0891B2),
  'Other':         Color(0xFF6B7280),
};

// ─────────────────────────────────────────────────────────────────────────────
class EmployeePaymentInfoScreen extends StatefulWidget {
  const EmployeePaymentInfoScreen({super.key});
  @override
  State<EmployeePaymentInfoScreen> createState() =>
      _EmployeePaymentInfoScreenState();
}

class _EmployeePaymentInfoScreenState
    extends State<EmployeePaymentInfoScreen> {
  String _cid = '';
  bool   _cidLoaded = false;

  final _accountCtl = TextEditingController();
  final _nameCtl    = TextEditingController();
  final _bankCtl    = TextEditingController();
  final _branchCtl  = TextEditingController();
  final _routingCtl = TextEditingController();

  String _selectedMethod = '';
  bool   _saving         = false;
  bool   _paymentVerified = false;
  DateTime? _lastUpdated;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>>? get _docRef =>
      _cid.isEmpty ? null : DB.colSync(_cid, C.users).doc(_uid);

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() { _cid = id ?? ''; _cidLoaded = true; });
    });
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

  void _populate(Map<String, dynamic> d) {
    _selectedMethod  = (d['paymentMethod']  as String?) ?? '';
    _accountCtl.text = (d['paymentAccount'] as String?) ?? '';
    _nameCtl.text    = (d['paymentName']    as String?) ?? '';
    _bankCtl.text    = (d['bankName']       as String?) ?? '';
    _branchCtl.text  = (d['branchName']     as String?) ?? '';
    _routingCtl.text = (d['routingNumber']  as String?) ?? '';
    _paymentVerified = (d['paymentVerified'] as bool?)  ?? false;
    _lastUpdated     = (d['paymentUpdatedAt'] as Timestamp?)?.toDate();
  }

  Future<void> _save() async {
    if (_docRef == null) return;
    if (_selectedMethod.isEmpty) {
      _snack('Please select a payment method', error: true);
      return;
    }
    if (_accountCtl.text.trim().isEmpty) {
      _snack('Account / mobile number is required', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await _docRef!.update({
        'paymentMethod':    _selectedMethod,
        'paymentAccount':   _accountCtl.text.trim(),
        'paymentName':      _nameCtl.text.trim(),
        'bankName':         _bankCtl.text.trim(),
        'branchName':       _branchCtl.text.trim(),
        'routingNumber':    _routingCtl.text.trim(),
        'paymentVerified':  false, // reset — HR must re-verify after any edit
        'paymentUpdatedAt': FieldValue.serverTimestamp(),
      });
      _snack('Payment info saved ✅  HR will verify before next payment.');
    } catch (e) {
      _snack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _red : _brand,
    ));
  }

  bool get _isBank => _selectedMethod == 'Bank Transfer';

  @override
  Widget build(BuildContext context) {
    if (!_cidLoaded || _uid.isEmpty) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: CircularProgressIndicator(color: _brand)),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brand, _brandMid],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: const Text('My Payment Info',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _docRef?.snapshots(),
        builder: (ctx, snap) {
          if (snap.hasData && snap.data!.exists) {
            final d = snap.data!.data()!;
            // Populate controllers once from Firestore (only if not editing)
            if (!_saving) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _populate(d));
              });
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              // ── Info banner ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.07),
                  border: Border.all(color: _brand.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _brand, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'HR uses this information to send your salary payment. Keep it accurate and up to date.',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _brand),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              // ── Verification status ───────────────────────────────────
              _StatusBanner(
                verified:    _paymentVerified,
                lastUpdated: _lastUpdated,
              ),

              const SizedBox(height: 20),

              // ── Method picker ─────────────────────────────────────────
              _SectionHeader(
                  icon: Icons.payment_rounded,
                  title: 'Payment Method',
                  color: _brand),
              const SizedBox(height: 10),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _paymentMethods.map((m) {
                  final sel   = _selectedMethod == m;
                  final color = _methodColors[m] ?? Colors.grey;
                  final icon  = _methodIcons[m]  ?? Icons.wallet_rounded;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMethod = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: sel
                            ? color.withValues(alpha: 0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? color : Colors.black12,
                            width: sel ? 1.5 : 1),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                    color: color.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]
                            : null,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon,
                            color: sel ? color : Colors.black38, size: 18),
                        const SizedBox(width: 8),
                        Text(m,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: sel ? color : Colors.black54)),
                      ]),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── Account details ───────────────────────────────────────
              _SectionHeader(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Account Details',
                  color: const Color(0xFF0891B2)),
              const SizedBox(height: 10),

              _Card(
                child: Column(children: [
                  _Field(
                    controller: _accountCtl,
                    label: _isBank
                        ? 'Bank Account Number *'
                        : 'Mobile Number *',
                    hint: _isBank ? '1234567890' : '01700000000',
                    icon: _isBank
                        ? Icons.account_balance_rounded
                        : Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _nameCtl,
                    label: 'Account Holder Name',
                    hint: 'Your full name as on the account',
                    icon: Icons.person_outline_rounded,
                  ),
                  if (_isBank) ...[
                    const SizedBox(height: 12),
                    _Field(
                      controller: _bankCtl,
                      label: 'Bank Name',
                      hint: 'e.g. Dutch Bangla Bank',
                      icon: Icons.account_balance_rounded,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _branchCtl,
                      label: 'Branch Name',
                      hint: 'e.g. Gulshan Branch',
                      icon: Icons.location_city_rounded,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _routingCtl,
                      label: 'Routing Number',
                      hint: '123456789',
                      icon: Icons.numbers_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ]),
              ),

              const SizedBox(height: 24),

              // ── Save button ───────────────────────────────────────────
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving…' : 'Save Payment Info',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                onPressed: _saving ? null : _save,
              ),

              const SizedBox(height: 12),

              // ── Note about verification ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.07),
                  border: Border.all(
                      color: _amber.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: _amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After saving, HR will verify your details before the next payment is sent.',
                      style: TextStyle(
                          fontSize: 11,
                          color: _amber,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Status Banner ─────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final bool      verified;
  final DateTime? lastUpdated;
  const _StatusBanner({required this.verified, this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    final color  = verified ? _brand : _amber;
    final icon   = verified
        ? Icons.verified_rounded
        : Icons.pending_actions_rounded;
    final label  = verified ? 'Verified by HR' : 'Pending HR Verification';
    final dateFmt = DateFormat('d MMM yyyy, hh:mm a');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: color)),
              if (lastUpdated != null)
                Text('Last updated: ${dateFmt.format(lastUpdated!)}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Color    color;
  const _SectionHeader(
      {required this.icon, required this.title, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color)),
      ]);
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final String                hint;
  final IconData              icon;
  final TextInputType         keyboardType;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });
  @override
  Widget build(BuildContext context) => TextField(
        controller:   controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText:  label,
          hintText:   hint,
          prefixIcon: Icon(icon, size: 18, color: _brand),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
        ),
      );
}
