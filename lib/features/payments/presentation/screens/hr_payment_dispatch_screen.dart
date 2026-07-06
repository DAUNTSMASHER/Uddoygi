// lib/features/payments/presentation/screens/hr_payment_dispatch_screen.dart
//
// HR Payment Dispatch — HR sees all employees, their payment info status,
// and can send salary/payment to any employee via PipraPay.
//
// Flow:
//   1. HR opens this screen
//   2. Sees all employees grouped by: ✅ Ready (verified) / ⚠ Unverified / ❌ No info
//   3. Taps an employee → sees their payment details + amount field
//   4. Taps "Send via PipraPay" → opens InitiatePaymentScreen with pre-filled data
//   5. Transaction is logged in pipra_transactions
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';

import '../../data/piprapay_repository.dart';
import '../../domain/models/beneficiary_model.dart';
import '../../domain/models/payment_settings_model.dart';
import 'initiate_payment_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _brand    = Color(0xFF065F46);
const Color _brandMid = Color(0xFF10B981);
const Color _surface  = Color(0xFFF0FDF4);
const Color _amber    = Color(0xFFD97706);
const Color _red      = Color(0xFFDC2626);
const Color _indigo   = Color(0xFF4F46E5);

// ── Employee payment info snapshot ────────────────────────────────────────────
class _EmpPayInfo {
  final String uid;
  final String name;
  final String department;
  final String designation;
  final String profileUrl;
  final String paymentMethod;
  final String paymentAccount;
  final String paymentName;
  final String bankName;
  final bool   paymentVerified;
  final DateTime? paymentUpdatedAt;

  const _EmpPayInfo({
    required this.uid,
    required this.name,
    required this.department,
    required this.designation,
    required this.profileUrl,
    required this.paymentMethod,
    required this.paymentAccount,
    required this.paymentName,
    required this.bankName,
    required this.paymentVerified,
    this.paymentUpdatedAt,
  });

  bool get hasInfo => paymentMethod.isNotEmpty && paymentAccount.isNotEmpty;

  factory _EmpPayInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return _EmpPayInfo(
      uid:              doc.id,
      name:             (d['fullName'] as String?)?.trim().isNotEmpty == true
          ? d['fullName'] as String
          : (d['name'] as String?) ?? 'Unknown',
      department:       (d['department'] as String?) ?? '',
      designation:      (d['designation'] as String?) ?? '',
      profileUrl:       (d['profilePhotoUrl'] as String?) ?? '',
      paymentMethod:    (d['paymentMethod']  as String?) ?? '',
      paymentAccount:   (d['paymentAccount'] as String?) ?? '',
      paymentName:      (d['paymentName']    as String?) ?? '',
      bankName:         (d['bankName']       as String?) ?? '',
      paymentVerified:  (d['paymentVerified'] as bool?)  ?? false,
      paymentUpdatedAt: (d['paymentUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class HrPaymentDispatchScreen extends StatefulWidget {
  const HrPaymentDispatchScreen({super.key});
  @override
  State<HrPaymentDispatchScreen> createState() =>
      _HrPaymentDispatchScreenState();
}

class _HrPaymentDispatchScreenState extends State<HrPaymentDispatchScreen>
    with SingleTickerProviderStateMixin {
  String _cid = '';
  bool   _cidLoaded = false;
  String _search = '';
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() { _cid = id ?? ''; _cidLoaded = true; });
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cidLoaded) {
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
        title: const Text('Payment Dispatch',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search employees…',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.white70, size: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabs,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: '✅ Ready'),
                Tab(text: '⚠ Unverified'),
                Tab(text: '❌ No Info'),
              ],
            ),
          ]),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DB.colSync(_cid, C.users)
            .where('role', isNotEqualTo: 'admin')
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _brand));
          }

          final all = snap.data!.docs
              .map(_EmpPayInfo.fromDoc)
              .where((e) =>
                  _search.isEmpty ||
                  e.name.toLowerCase().contains(_search) ||
                  e.department.toLowerCase().contains(_search))
              .toList();

          final ready      = all.where((e) => e.hasInfo && e.paymentVerified).toList();
          final unverified = all.where((e) => e.hasInfo && !e.paymentVerified).toList();
          final noInfo     = all.where((e) => !e.hasInfo).toList();

          return Column(children: [
            // Summary bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SumChip(
                      label: 'Ready',
                      count: ready.length,
                      color: _brand),
                  _SumChip(
                      label: 'Unverified',
                      count: unverified.length,
                      color: _amber),
                  _SumChip(
                      label: 'No Info',
                      count: noInfo.length,
                      color: _red),
                  _SumChip(
                      label: 'Total',
                      count: all.length,
                      color: _indigo),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _EmpList(
                    employees: ready,
                    emptyMessage: 'No employees with verified payment info',
                    emptyIcon: Icons.check_circle_outline_rounded,
                    cid: _cid,
                    showSendButton: true,
                  ),
                  _EmpList(
                    employees: unverified,
                    emptyMessage: 'No unverified employees',
                    emptyIcon: Icons.pending_outlined,
                    cid: _cid,
                    showSendButton: false,
                    badge: 'Needs HR verification',
                    badgeColor: _amber,
                  ),
                  _EmpList(
                    employees: noInfo,
                    emptyMessage: 'All employees have payment info',
                    emptyIcon: Icons.celebration_rounded,
                    cid: _cid,
                    showSendButton: false,
                    badge: 'No payment info',
                    badgeColor: _red,
                  ),
                ],
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Employee list ─────────────────────────────────────────────────────────────
class _EmpList extends StatelessWidget {
  final List<_EmpPayInfo> employees;
  final String            emptyMessage;
  final IconData          emptyIcon;
  final String            cid;
  final bool              showSendButton;
  final String?           badge;
  final Color?            badgeColor;

  const _EmpList({
    required this.employees,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.cid,
    required this.showSendButton,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.black12),
            const SizedBox(height: 12),
            Text(emptyMessage,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.black38)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: employees.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _EmpCard(
        emp:           employees[i],
        cid:           cid,
        showSend:      showSendButton,
        badge:         badge,
        badgeColor:    badgeColor,
      ),
    );
  }
}

// ── Employee card ─────────────────────────────────────────────────────────────
class _EmpCard extends StatelessWidget {
  final _EmpPayInfo emp;
  final String      cid;
  final bool        showSend;
  final String?     badge;
  final Color?      badgeColor;

  const _EmpCard({
    required this.emp,
    required this.cid,
    required this.showSend,
    this.badge,
    this.badgeColor,
  });

  void _openDispatch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DispatchSheet(emp: emp, cid: cid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = emp.name.trim().split(' ')
        .map((w) => w.isEmpty ? '' : w[0])
        .take(2)
        .join()
        .toUpperCase();

    return GestureDetector(
      onTap: () => _openDispatch(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: emp.paymentVerified
                  ? _brand.withValues(alpha: 0.2)
                  : Colors.black12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: _brand.withValues(alpha: 0.1),
            backgroundImage: emp.profileUrl.isNotEmpty
                ? NetworkImage(emp.profileUrl)
                : null,
            child: emp.profileUrl.isEmpty
                ? Text(initials,
                    style: const TextStyle(
                        color: _brand,
                        fontWeight: FontWeight.w800,
                        fontSize: 13))
                : null,
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emp.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Row(children: [
                  if (emp.department.isNotEmpty)
                    _Tag(label: emp.department, color: _indigo),
                  if (emp.designation.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Tag(label: emp.designation, color: Colors.grey),
                  ],
                ]),
                if (emp.hasInfo) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.payment_rounded,
                        size: 12, color: Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                      '${emp.paymentMethod} • ${emp.paymentAccount}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45),
                    ),
                  ]),
                ],
                if (badge != null) ...[
                  const SizedBox(height: 4),
                  _Tag(label: badge!, color: badgeColor ?? Colors.grey),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action
          if (showSend)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.send_rounded, size: 14),
              label: const Text('Pay',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: () => _openDispatch(context),
            )
          else
            const Icon(Icons.chevron_right_rounded,
                color: Colors.black26),
        ]),
      ),
    );
  }
}

// ── Dispatch bottom sheet ─────────────────────────────────────────────────────
class _DispatchSheet extends StatefulWidget {
  final _EmpPayInfo emp;
  final String      cid;
  const _DispatchSheet({required this.emp, required this.cid});
  @override
  State<_DispatchSheet> createState() => _DispatchSheetState();
}

class _DispatchSheetState extends State<_DispatchSheet> {
  final _amountCtl = TextEditingController();
  final _notesCtl  = TextEditingController();
  bool _loading    = false;

  @override
  void dispose() {
    _amountCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final amount = double.tryParse(_amountCtl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Load PipraPay settings
      final repo     = PipraPayRepository(cid: widget.cid);
      final settings = await repo.getSettings();

      // Build a beneficiary from the employee's payment info
      final beneficiary = BeneficiaryModel(
        id:            widget.emp.uid,
        name:          widget.emp.name,
        emailOrMobile: widget.emp.paymentAccount,
        type:          BeneficiaryType.employee,
        accountNumber: widget.emp.paymentAccount,
        bankName:      widget.emp.bankName,
        notes:         'Salary payment',
      );

      if (!mounted) return;
      Navigator.pop(context); // close sheet

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PrefilledPaymentScreen(
            cid:         widget.cid,
            settings:    settings,
            beneficiary: beneficiary,
            amount:      amount,
            notes:       _notesCtl.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.emp;
    final dateFmt = DateFormat('d MMM yyyy');

    return Container(
      margin: EdgeInsets.only(
          top: MediaQuery.of(context).size.height * 0.15),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                // Header
                Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _brand.withValues(alpha: 0.1),
                    backgroundImage: emp.profileUrl.isNotEmpty
                        ? NetworkImage(emp.profileUrl)
                        : null,
                    child: emp.profileUrl.isEmpty
                        ? Text(
                            emp.name.isEmpty ? '?' : emp.name[0].toUpperCase(),
                            style: const TextStyle(
                                color: _brand,
                                fontWeight: FontWeight.w800,
                                fontSize: 16))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(emp.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        if (emp.department.isNotEmpty)
                          Text(emp.department,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black38)),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context)),
                ]),

                const SizedBox(height: 16),

                // Payment info card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: emp.paymentVerified
                        ? _brand.withValues(alpha: 0.06)
                        : _amber.withValues(alpha: 0.06),
                    border: Border.all(
                        color: emp.paymentVerified
                            ? _brand.withValues(alpha: 0.2)
                            : _amber.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                          emp.paymentVerified
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded,
                          color: emp.paymentVerified ? _brand : _amber,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          emp.paymentVerified
                              ? 'Verified Payment Info'
                              : 'Unverified — proceed with caution',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: emp.paymentVerified ? _brand : _amber),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      if (emp.paymentMethod.isNotEmpty)
                        _InfoRow(label: 'Method',  value: emp.paymentMethod),
                      if (emp.paymentAccount.isNotEmpty)
                        _InfoRow(label: 'Account', value: emp.paymentAccount),
                      if (emp.paymentName.isNotEmpty)
                        _InfoRow(label: 'Name',    value: emp.paymentName),
                      if (emp.bankName.isNotEmpty)
                        _InfoRow(label: 'Bank',    value: emp.bankName),
                      if (emp.paymentUpdatedAt != null)
                        _InfoRow(
                            label: 'Updated',
                            value: dateFmt.format(emp.paymentUpdatedAt!)),
                      if (!emp.hasInfo)
                        const Text(
                          'No payment information on file.\nAsk the employee to update their payment info.',
                          style: TextStyle(
                              color: _red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),

                if (!emp.hasInfo) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _red.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      'Cannot dispatch payment — employee has not added payment info.',
                      style: TextStyle(
                          color: _red,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ],

                if (emp.hasInfo) ...[
                  const SizedBox(height: 20),

                  // Amount input
                  const Text('Amount to Send',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: _brand.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10)),
                        border: Border.all(
                            color: _brand.withValues(alpha: 0.2)),
                      ),
                      child: const Text('BDT',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _brand,
                              fontSize: 14)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _amountCtl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9]+[.]?[0-9]*'))
                        ],
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: const TextStyle(
                              color: Colors.black12,
                              fontSize: 20,
                              fontWeight: FontWeight.w900),
                          border: OutlineInputBorder(
                            borderRadius:
                                const BorderRadius.horizontal(
                                    right: Radius.circular(10)),
                            borderSide: BorderSide(
                                color: _brand.withValues(alpha: 0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                const BorderRadius.horizontal(
                                    right: Radius.circular(10)),
                            borderSide: BorderSide(
                                color: _brand.withValues(alpha: 0.2)),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _notesCtl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'e.g. March 2025 salary',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 20),

                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _brand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _loading
                          ? 'Preparing…'
                          : 'Proceed to PipraPay',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    onPressed: _loading ? null : _proceed,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pre-filled payment screen wrapper ────────────────────────────────────────
// Wraps InitiatePaymentScreen with pre-filled beneficiary + amount
class _PrefilledPaymentScreen extends StatefulWidget {
  final String              cid;
  final PaymentSettingsModel settings;
  final BeneficiaryModel    beneficiary;
  final double              amount;
  final String              notes;

  const _PrefilledPaymentScreen({
    required this.cid,
    required this.settings,
    required this.beneficiary,
    required this.amount,
    required this.notes,
  });

  @override
  State<_PrefilledPaymentScreen> createState() =>
      _PrefilledPaymentScreenState();
}

class _PrefilledPaymentScreenState
    extends State<_PrefilledPaymentScreen> {
  @override
  Widget build(BuildContext context) {
    // Ensure the beneficiary exists in Firestore before opening
    // the payment screen (upsert by employee uid)
    return FutureBuilder<void>(
      future: _ensureBeneficiary(),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: _surface,
            body: Center(
                child: CircularProgressIndicator(color: _brand)),
          );
        }
        return InitiatePaymentScreen(
          cid:      widget.cid,
          settings: widget.settings,
          // Pass pre-selected beneficiary via a subclass that pre-fills
          preselectedBeneficiary: widget.beneficiary,
          prefilledAmount:        widget.amount,
          prefilledNotes:         widget.notes,
        );
      },
    );
  }

  Future<void> _ensureBeneficiary() async {
    final b = widget.beneficiary;
    // Upsert: use employee uid as the beneficiary doc id
    await DB.colSync(widget.cid, C.beneficiaries).doc(b.id).set(
      {
        ...b.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────
class _SumChip extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;
  const _SumChip(
      {required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Colors.black38)),
        ],
      );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color  color;
  const _Tag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(
            width: 56,
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
