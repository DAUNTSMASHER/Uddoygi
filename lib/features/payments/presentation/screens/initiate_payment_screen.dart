// lib/features/payments/presentation/screens/initiate_payment_screen.dart
//
// Initiate a new PipraPay payment — pick beneficiary, enter amount, send.
// Opens the PipraPay checkout URL in the browser after charge creation.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/piprapay_repository.dart';
import '../../domain/models/beneficiary_model.dart';
import '../../domain/models/payment_settings_model.dart';

const Color _brand    = Color(0xFF4F46E5);
const Color _brandMid = Color(0xFF6366F1);
const Color _surface  = Color(0xFFF5F3FF);
const Color _green    = Color(0xFF059669);
const Color _red      = Color(0xFFDC2626);
const Color _amber    = Color(0xFFD97706);

final _money = NumberFormat('#,##0.00', 'en');

class InitiatePaymentScreen extends StatefulWidget {
  final String              cid;
  final PaymentSettingsModel settings;
  /// Optional: pre-select a beneficiary (e.g. from HR dispatch)
  final BeneficiaryModel?   preselectedBeneficiary;
  /// Optional: pre-fill amount
  final double?             prefilledAmount;
  /// Optional: pre-fill notes
  final String?             prefilledNotes;

  const InitiatePaymentScreen({
    super.key,
    required this.cid,
    required this.settings,
    this.preselectedBeneficiary,
    this.prefilledAmount,
    this.prefilledNotes,
  });
  @override
  State<InitiatePaymentScreen> createState() => _InitiatePaymentScreenState();
}

class _InitiatePaymentScreenState extends State<InitiatePaymentScreen> {
  late final PipraPayRepository _repo;

  final _amountCtl = TextEditingController();
  final _notesCtl  = TextEditingController();

  BeneficiaryModel? _selectedBeneficiary;
  List<BeneficiaryModel> _beneficiaries = [];
  bool _loadingBen = true;
  bool _sending    = false;
  String _error    = '';

  @override
  void initState() {
    super.initState();
    _repo = PipraPayRepository(cid: widget.cid);

    // Pre-fill from dispatch if provided
    if (widget.prefilledAmount != null) {
      _amountCtl.text = widget.prefilledAmount!.toStringAsFixed(2);
    }
    if (widget.prefilledNotes != null) {
      _notesCtl.text = widget.prefilledNotes!;
    }
    if (widget.preselectedBeneficiary != null) {
      _selectedBeneficiary = widget.preselectedBeneficiary;
    }

    _repo.watchBeneficiaries().first.then((list) {
      if (mounted) {
        setState(() {
          _beneficiaries = list;
          _loadingBen    = false;
          // If pre-selected beneficiary not in list, add it temporarily
          if (_selectedBeneficiary != null &&
              !list.any((b) => b.id == _selectedBeneficiary!.id)) {
            _beneficiaries = [_selectedBeneficiary!, ...list];
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final amountStr = _amountCtl.text.trim();
    final amount    = double.tryParse(amountStr);

    if (_selectedBeneficiary == null) {
      setState(() => _error = 'Please select a beneficiary');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (!widget.settings.enabled) {
      setState(() => _error = 'PipraPay is not enabled. Go to Settings.');
      return;
    }

    setState(() { _sending = true; _error = ''; });

    try {
      final result = await _repo.initiatePayment(
        beneficiary: _selectedBeneficiary!,
        amount:      amount,
        settings:    widget.settings,
        notes:       _notesCtl.text.trim(),
      );

      if (!mounted) return;

      // Show checkout URL dialog
      await _showCheckoutDialog(result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showCheckoutDialog(InitiatePaymentResult result) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: _green, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Payment Initiated',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.settings.sandboxMode)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _amber.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.science_rounded,
                      color: _amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Sandbox mode — no real money moved',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _amber)),
                  ),
                ]),
              ),
            _InfoRow(label: 'Order ID', value: result.orderId),
            if (result.invoiceId.isNotEmpty)
              _InfoRow(label: 'Invoice ID', value: result.invoiceId),
            const SizedBox(height: 12),
            const Text(
              'Open the checkout URL to complete payment:',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _brand.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _brand.withValues(alpha: 0.2)),
              ),
              child: Text(
                result.checkoutUrl,
                style: const TextStyle(
                    fontSize: 11,
                    color: _brand,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _brand),
            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
            label: const Text('Open Checkout'),
            onPressed: () async {
              final uri = Uri.tryParse(result.checkoutUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );

    // Navigate back after dialog closes
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
          title: const Text('Send Payment',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // ── Sandbox banner ────────────────────────────────────────────
            if (widget.settings.sandboxMode)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.08),
                  border: Border.all(
                      color: _amber.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.science_rounded,
                      color: _amber, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Sandbox mode — test transactions only',
                      style: TextStyle(
                          color: _amber,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ]),
              ),

            // ── Disabled banner ───────────────────────────────────────────
            if (!widget.settings.enabled)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.06),
                  border: Border.all(
                      color: _red.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.power_off_rounded,
                      color: _red, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'PipraPay is disabled. Enable it in Settings.',
                      style: TextStyle(
                          color: _red,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ]),
              ),

            // ── Select beneficiary ────────────────────────────────────────
            _SectionHeader(
                icon: Icons.person_rounded,
                title: 'Beneficiary',
                color: const Color(0xFF7C3AED)),
            const SizedBox(height: 10),

            if (_loadingBen)
              const Center(
                  child: CircularProgressIndicator(color: _brand))
            else if (_beneficiaries.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Text(
                  'No beneficiaries found. Add one first.',
                  style: TextStyle(color: Colors.black45),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _selectedBeneficiary != null
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.4)
                          : Colors.black12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<BeneficiaryModel>(
                    value: _selectedBeneficiary,
                    isExpanded: true,
                    hint: const Text('Select beneficiary…',
                        style: TextStyle(color: Colors.black38)),
                    items: _beneficiaries
                        .map((b) => DropdownMenuItem(
                              value: b,
                              child: Row(children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.1),
                                  child: Text(
                                    b.name.isEmpty
                                        ? '?'
                                        : b.name[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Color(0xFF7C3AED),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(b.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                      Text(b.emailOrMobile,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black38)),
                                    ],
                                  ),
                                ),
                              ]),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedBeneficiary = v),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── Amount ────────────────────────────────────────────────────
            _SectionHeader(
                icon: Icons.payments_rounded,
                title: 'Amount',
                color: _brand),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(children: [
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
                    child: Text(widget.settings.currency,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _brand,
                            fontSize: 14)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _amountCtl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9]+[.]?[0-9]*'))
                      ],
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: const TextStyle(
                            color: Colors.black12,
                            fontSize: 22,
                            fontWeight: FontWeight.w900),
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(10)),
                          borderSide: BorderSide(
                              color: _brand.withValues(alpha: 0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(10)),
                          borderSide: BorderSide(
                              color: _brand.withValues(alpha: 0.2)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
                if (_amountCtl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Amount: ${widget.settings.currency} ${_money.format(double.tryParse(_amountCtl.text) ?? 0)}',
                    style: const TextStyle(
                        color: Colors.black38, fontSize: 12),
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 16),

            // ── Notes ─────────────────────────────────────────────────────
            TextField(
              controller: _notesCtl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Payment reference or description',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),

            // ── Error ─────────────────────────────────────────────────────
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _red.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: _red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error,
                        style: const TextStyle(
                            color: _red, fontSize: 12)),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            // ── Send button ───────────────────────────────────────────────
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: widget.settings.enabled
                    ? _brand
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(
                _sending ? 'Initiating…' : 'Send Payment',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      );
}

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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black45)),
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
