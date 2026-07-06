import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/document_extractor/document_extractor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/drive_storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uddoygi/services/local_storage_service.dart';

// ── Design system: consistent, professional slip submission UX ───────────────
const Color _brand   = Color(0xFF0D47A1);
const Color _accent  = Color(0xFF448AFF);
const Color _surface = Color(0xFFF7F9FC);
const Color _cardBg  = Color(0xFFFFFFFF);
const Color _success = Color(0xFF16A34A);
const Color _warn    = Color(0xFFEA580C);
const Color _danger  = Color(0xFFDC2626);
const Color _info    = Color(0xFF0369A1);
const Color _border  = Color(0xFFE5E7EB);
const Color _textMuted = Color(0xFF6B7280);
const Color _shadow  = Color(0x08000000);
const double _radiusSm  = 10.0;
const double _radiusMd  = 12.0;
const double _radiusLg  = 14.0;
const double _spaceMd = 14.0;

// ── Supported currencies ──────────────────────────────────────────────────────
const _currencies = ['BDT', 'USD', 'EUR', 'GBP', 'AED', 'SGD', 'CNY', 'JPY'];

// ── Payment methods ───────────────────────────────────────────────────────────
const _methods = [
  'Bank Transfer',
  'Mobile Banking (bKash)',
  'Mobile Banking (Nagad)',
  'Mobile Banking (Rocket)',
  'Cash',
  'Card',
  'Cheque',
  'Wire Transfer',
  'PayPal',
  'Other',
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PaymentSlipScreen extends StatefulWidget {
  final String invoiceId;
  final String invoiceNo;
  final double invoiceTotal;

  const PaymentSlipScreen({
    super.key,
    required this.invoiceId,
    required this.invoiceNo,
    required this.invoiceTotal,
  });

  @override
  State<PaymentSlipScreen> createState() => _PaymentSlipScreenState();
}

class _PaymentSlipScreenState extends State<PaymentSlipScreen> {
  String _cid = '';

  int _step = 0;

  final _formKey    = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _refCtrl    = TextEditingController();
  final _noteCtrl   = TextEditingController();
  final _amountFocus = FocusNode();

  String   _currency = 'BDT';
  String   _method   = 'Bank Transfer';
  DateTime _slipDate = DateTime.now();

  File?   _pickedFile;
  String  _fileName = '';
  bool    _isPdf    = false;

  static const String _invoiceCurrency = 'BDT';

  bool _submitting = false;

  // ── User ──────────────────────────────────────────────────────────────────
  String _userEmail = '';
  String _userName  = '';
  String _userUid   = '';

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.invoiceTotal.toStringAsFixed(2);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadUser();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final session = await LocalStorageService.getSession();
    final user    = FirebaseAuth.instance.currentUser;
    if (mounted) {
      setState(() {
        _userUid   = user?.uid   ?? (session?['uid']   as String? ?? '');
        _userEmail = user?.email ?? (session?['email'] as String? ?? '');
        _userName  = (session?['name'] as String?) ?? user?.displayName ?? '';
      });
    }
  }

  // ── File picking ───────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.first;
    if (pf.path == null) return;
    setState(() {
      _pickedFile = File(pf.path!);
      _fileName   = pf.name;
      _isPdf      = pf.extension?.toLowerCase() == 'pdf';
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (xf == null) return;
    setState(() {
      _pickedFile = File(xf.path);
      _fileName   = p.basename(xf.path);
      _isPdf      = false;
    });
  }

  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (xf == null) return;
    setState(() {
      _pickedFile = File(xf.path);
      _fileName   = p.basename(xf.path);
      _isPdf      = false;
    });
  }

  // ── Upload to Google Drive ──────────────────────────────────────────────────
  // Returns (viewUrl, fileId). View URL loads in Image.network or browser (PDF).
  // fileId is stored so HR can reference or delete from Drive if needed.
  Future<(String?, String?)> _uploadFile() async {
    if (_pickedFile == null) return (null, null);
    try {
      final result = await DriveStorageService.instance.uploadFile(
        _pickedFile!,
        pathPrefix: 'payment_slips',
        customName: '${widget.invoiceId}_${DateTime.now().millisecondsSinceEpoch}${p.extension(_fileName)}',
        onProgress: (p) => setState(() {}),
      );
      return (result.viewUrl, result.fileId);
    } catch (_) {
      return (null, null);
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    try {
      final (fileUrl, filePath) = await _uploadFile();
      final amount  = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

      // The amount in the slip's original currency (e.g. 1500 USD).
      // If the slip is in a foreign currency, also store the BDT equivalent
      // so HR sees the correct value in BDT and cash-in is recorded correctly.
      final isForeignCurrency = _currency != _invoiceCurrency;
      final amountBDT = amount;

      final slipRef = await DB.colSync(_cid, C.paymentSlips).add({
        'invoiceId':       widget.invoiceId,
        'invoiceNo':       widget.invoiceNo,
        'invoiceTotal':    widget.invoiceTotal,
        'title':           _titleCtrl.text.trim(),
        // Original submitted amount in the slip's currency (e.g. 1500 USD)
        'amount':          amount,
        'currency':        _currency,
        // BDT equivalent — this is what HR should confirm for cash-in
        // When currency == BDT, amountBDT == amount
        'amountBDT':       amountBDT,
        'isForeignCurrency': isForeignCurrency,
        'method':          _method,
        'ref':             _refCtrl.text.trim(),
        'note':            _noteCtrl.text.trim(),
        'slipDate':        Timestamp.fromDate(_slipDate),
        'fileUrl':         fileUrl ?? '',
        'filePath':        filePath ?? '',
        'fileExpiresAt':   _pickedFile != null ? Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))) : null,
        'fileName':        _fileName,
        'isPdf':           _isPdf,
        'submittedBy':     _userEmail,
        'submittedByUid':  _userUid,
        'submittedByName': _userName,
        'status':          'pending_hr',
        'hrNote':          '',
        'createdAt':       FieldValue.serverTimestamp(),
        'updatedAt':       FieldValue.serverTimestamp(),
      });

      await DB.colSync(_cid, C.notifications).add({
        'type':       'payment_slip_review',
        'title':      'Payment Slip Submitted',
        'body':       '$_userName submitted a payment slip for Invoice #${widget.invoiceNo}. '
                      'Amount: $_currency ${NumberFormat('#,##0.00').format(amount)}'
                      '${isForeignCurrency ? ' (≈ BDT ${NumberFormat('#,##0.00').format(amountBDT)})' : ''}. Please review.',
        'invoiceId':  widget.invoiceId,
        'invoiceNo':  widget.invoiceNo,
        'slipId':     slipRef.id,
        'targetRole': 'hr',
        'targetDept': 'hr',
        'read':       false,
        'createdAt':  FieldValue.serverTimestamp(),
      });

      await DB.colSync(_cid, C.invoices).doc(widget.invoiceId).update({
        'slipSubmitted': true,
        'slipId':        slipRef.id,
        'slipStatus':    'pending_hr',
        'updatedAt':     FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _submitting = false;
          _step       = 2;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
      _snack('Error submitting slip: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _danger : _success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusSm)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brand, _accent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: const Text(
          'Payment Slip Validation',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _step == 2 ? _buildDone() : _buildForm(),
    );
  }

  // ── Step 2: Done ───────────────────────────────────────────────────────────
  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: _success, size: 48),
          ),
          const SizedBox(height: 20),
          const Text('Slip Submitted!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _brand)),
          const SizedBox(height: 10),
          Text(
            'Your payment slip for Invoice #${widget.invoiceNo} has been submitted to HR for verification.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _warn.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _warn.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.hourglass_top_rounded, size: 16, color: _warn),
              const SizedBox(width: 6),
              const Text('Pending HR Approval',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _warn)),
            ]),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Back to Invoice',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  // ── Steps 0 & 1 ────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          // ── Invoice reference banner ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(_spaceMd),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_brand, _accent]),
              borderRadius: BorderRadius.circular(_radiusMd),
              boxShadow: [
                BoxShadow(
                  color: _brand.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invoice #${widget.invoiceNo}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(
                    'Total: ${NumberFormat('#,##0.00').format(widget.invoiceTotal)} BDT',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                ],
              )),
            ]),
          ),

          const SizedBox(height: 20),

          _SectionCard(
            icon: Icons.label_rounded,
            title: 'Slip Title',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Give this payment slip a descriptive title.',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleCtrl,
                decoration: _inputDec('e.g. Wire Transfer – July 2025'),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
              ),
            ]),
          ),

          const SizedBox(height: 16),

          _SectionCard(
            icon: Icons.attach_money_rounded,
            title: 'Payment Details',
            child: Column(children: [
              Row(children: [
                Expanded(
                  flex: 3,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _FieldLabel('Amount'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountCtrl,
                      focusNode: _amountFocus,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _amountInputDec(),
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        if ((double.tryParse(v!.replaceAll(',', '')) ?? 0) <= 0) {
                          return 'Invalid amount';
                        }
                        return null;
                      },
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _FieldLabel('Currency'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _currency,
                      items: _currencies
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _currency = v!),
                      decoration: _inputDec(''),
                    ),
                  ]),
                ),
              ]),

              const SizedBox(height: 14),

              const _FieldLabel('Payment Method'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _method,
                items: _methods
                    .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m, style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (v) => setState(() => _method = v!),
                decoration: _inputDec(''),
              ),

              const SizedBox(height: 14),

              const _FieldLabel('Transaction Date'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _slipDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    builder: (c, w) => Theme(
                      data: Theme.of(c).copyWith(
                          colorScheme:
                              const ColorScheme.light(primary: _brand)),
                      child: w!,
                    ),
                  );
                  if (d != null) setState(() => _slipDate = d);
                },
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(_radiusSm),
                    border: Border.all(color: _border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 18, color: _brand),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('d MMMM yyyy').format(_slipDate),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 14),

              const _FieldLabel('Transaction Reference / ID'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _refCtrl,
                decoration: _inputDec('e.g. TXN123456789'),
              ),

              const SizedBox(height: 14),

              const _FieldLabel('Note (Optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: _inputDec('Any additional information…'),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          _SectionCard(
            icon: Icons.upload_file_rounded,
            title: 'Attach Proof (Optional)',
            child: Column(children: [
              const Text(
                'You can attach a PDF or image as proof. Amount and details are entered above.',
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 16),
              if (_pickedFile != null) ...[
                _FilePreview(file: _pickedFile!, isPdf: _isPdf, name: _fileName),
                const SizedBox(height: 12),
              ],
              Row(children: [
                Expanded(child: _UploadBtn(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'PDF / File',
                  onTap: _pickFile,
                )),
                const SizedBox(width: 10),
                Expanded(child: _UploadBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: _pickImage,
                )),
                const SizedBox(width: 10),
                Expanded(child: _UploadBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: _pickCamera,
                )),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          _VerificationSummary(
            invoiceTotal: widget.invoiceTotal,
            slipAmount:
                double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
            currency: _currency,
            method: _method,
            date: _slipDate,
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : const Text('Submit for HR Approval',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.7), fontSize: 13),
        filled: true,
        fillColor: _cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radiusSm),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radiusSm),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radiusSm),
            borderSide: const BorderSide(color: _brand, width: 1.5)),
      );

  InputDecoration _amountInputDec() {
    return InputDecoration(
      hintText: '0.00',
      hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.7), fontSize: 13),
      filled: true,
      fillColor: _cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: const BorderSide(color: _border, width: 1)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: const BorderSide(color: _brand, width: 2)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTRACTION RESULT CARD
// Shows the AI extraction summary with confidence indicators and raw amounts.
// ─────────────────────────────────────────────────────────────────────────────
class _ExtractionResultCard extends StatefulWidget {
  final ExtractionResult  result;
  final VoidCallback?     onEditAmount;
  final ConversionResult? conversion;
  final bool              converting;
  const _ExtractionResultCard({
    required this.result,
    this.onEditAmount,
    this.conversion,
    this.converting = false,
  });

  @override
  State<_ExtractionResultCard> createState() => _ExtractionResultCardState();
}

class _ExtractionResultCardState extends State<_ExtractionResultCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r    = widget.result;
    final conf = r.confidenceOverall;
    final confColor = conf >= 0.75
        ? _success
        : conf >= 0.45
            ? _warn
            : _danger;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_radiusLg),
        border: Border.all(color: confColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: _shadow,
              blurRadius: 12,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: confColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusLg)),
            border: Border(bottom: BorderSide(color: confColor.withValues(alpha: 0.2))),
          ),
          child: Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: confColor),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('AI Extraction Result',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
            // Confidence: pill + progress bar
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: confColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: confColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      conf >= 0.75
                          ? Icons.verified_rounded
                          : conf >= 0.45
                              ? Icons.warning_amber_rounded
                              : Icons.error_outline_rounded,
                      size: 13,
                      color: confColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(conf * 100).round()}%',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: confColor),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: conf,
                      backgroundColor: confColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(confColor),
                      minHeight: 5,
                    ),
                  ),
                ),
              ],
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Primary amount ─────────────────────────────────────────
            if (r.actualAmountPaid != null) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Detected Amount',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black45,
                            letterSpacing: 0.3)),
                    const SizedBox(height: 4),
                    Text(
                      '${r.actualAmountPaid!.currency} ${NumberFormat('#,##0.00').format(r.actualAmountPaid!.value)}',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: confColor),
                    ),
                    Text(
                      '"${r.actualAmountPaid!.text}"',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black38, fontStyle: FontStyle.italic),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _ConfidencePill(confidence: r.actualAmountPaid!.confidence),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: widget.onEditAmount,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _warn.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _warn.withValues(alpha: 0.35)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.edit_rounded, size: 13, color: _warn),
                        SizedBox(width: 4),
                        Text('Edit',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _warn)),
                      ]),
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
            ],

            // ── Currency conversion banner ─────────────────────────────
            if (widget.converting) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Row(children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _warn),
                  ),
                  SizedBox(width: 8),
                  Text('Fetching live exchange rate…',
                      style: TextStyle(fontSize: 12, color: _warn,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 10),
            ] else if (widget.conversion != null) ...[
              _CurrencyConversionBanner(conversion: widget.conversion!),
              const SizedBox(height: 10),
            ],

            // ── Key fields grid ────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (r.documentType != DocumentType.unknown)
                  _InfoChip(
                    icon: Icons.description_rounded,
                    label: r.documentType.label.replaceAll('_', ' '),
                    color: _info,
                  ),
                // Reference company (merchant/payee the payment went TO)
                if (r.referenceCompany != null)
                  _InfoChip(
                    icon: Icons.business_rounded,
                    label: r.referenceCompany!,
                    color: const Color(0xFF7C3AED),
                  ),
                if (r.providerOrMerchant != null &&
                    r.providerOrMerchant != r.referenceCompany)
                  _InfoChip(
                    icon: Icons.store_rounded,
                    label: r.providerOrMerchant!,
                    color: _brand,
                  ),
                if (r.status != null)
                  _InfoChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: r.status!,
                    color: r.status == 'paid' || r.status == 'completed'
                        ? _success
                        : _warn,
                  ),
                if (r.date != null)
                  _InfoChip(
                    icon: Icons.calendar_today_rounded,
                    label: r.date!,
                    color: Colors.black54,
                  ),
                if (r.paymentMethod != null)
                  _InfoChip(
                    icon: Icons.payment_rounded,
                    label: r.paymentMethod!,
                    color: Colors.black54,
                  ),
              ],
            ),

            // ── Fee / subtotal breakdown ───────────────────────────────
            if (r.fee != null || r.subtotal != null || r.tax != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              const Text('Breakdown',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.black45,
                      letterSpacing: 0.3)),
              const SizedBox(height: 8),
              if (r.subtotal != null)
                _BreakdownRow('Subtotal', r.subtotal!),
              if (r.fee != null)
                _BreakdownRow('Fee / Charges', r.fee!),
              if (r.tax != null)
                _BreakdownRow('Tax', r.tax!),
            ],

            // ── Notes / ambiguities ────────────────────────────────────
            if (r.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _warn.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _warn.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 14, color: _warn),
                      const SizedBox(width: 6),
                      const Text('Notes',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _warn)),
                    ]),
                    const SizedBox(height: 6),
                    ...r.notes.map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('• $n',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black54, height: 1.4)),
                        )),
                  ],
                ),
              ),
            ],

            // ── Raw amounts toggle ─────────────────────────────────────
            if (r.rawDetectedAmounts.length > 1) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(children: [
                  Text(
                    'All detected amounts (${r.rawDetectedAmounts.length})',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _brand),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: _brand,
                  ),
                ]),
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                ...r.rawDetectedAmounts.take(8).map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            '${a.label}: ${a.currency} ${NumberFormat('#,##0.00').format(a.value)}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ),
                        _ConfidencePill(confidence: a.confidence, small: true),
                      ]),
                    )),
              ],
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Currency conversion banner ────────────────────────────────────────────────
class _CurrencyConversionBanner extends StatelessWidget {
  final ConversionResult conversion;
  const _CurrencyConversionBanner({required this.conversion});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final from = conversion.fromCurrency;
    final to   = conversion.toCurrency;
    final rate = conversion.rate;
    final converted = conversion.convertedAmount;
    final isLive = conversion.isLive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFF0FDF4)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.currency_exchange_rounded,
              size: 14, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(
            isLive ? 'Live Rate Conversion' : 'Estimated Conversion (offline)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isLive ? const Color(0xFF2563EB) : _warn,
            ),
          ),
          const Spacer(),
          if (!isLive)
            const Icon(Icons.wifi_off_rounded, size: 12, color: _warn),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$from ${fmt.format(conversion.originalAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '  →  '),
                  TextSpan(
                    text: '$to ${fmt.format(converted)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF16A34A),
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 3),
        Text(
          '1 $from = ${rate.toStringAsFixed(4)} $to'
          '${conversion.rateDate != null ? "  ·  ${conversion.rateDate}" : ""}',
          style: const TextStyle(fontSize: 10, color: Colors.black45),
        ),
      ]),
    );
  }
}

// ── Breakdown row ─────────────────────────────────────────────────────────────
class _BreakdownRow extends StatelessWidget {
  final String label;
  final AmountField amount;
  const _BreakdownRow(this.label, this.amount);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const Spacer(),
          Text(
            '${amount.currency} ${NumberFormat('#,##0.00').format(amount.value)}',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(width: 8),
          _ConfidencePill(confidence: amount.confidence, small: true),
        ]),
      );
}

// ── Confidence pill ───────────────────────────────────────────────────────────
class _ConfidencePill extends StatelessWidget {
  final double confidence;
  final bool small;
  const _ConfidencePill({required this.confidence, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.75
        ? _success
        : confidence >= 0.45
            ? _warn
            : _danger;
    final pct = (confidence * 100).round();
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
            fontSize: small ? 9 : 10,
            fontWeight: FontWeight.w700,
            color: color),
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER WIDGETS (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Widget   child;
  const _SectionCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(_radiusLg),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
                color: _shadow, blurRadius: 10, offset: Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(children: [
              Icon(icon, size: 18, color: _brand),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ]),
      );
}

class _InvoicePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InvoicePill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      ]);
}

class _UploadBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  const _UploadBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _brand.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _brand.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: _brand, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _brand)),
          ]),
        ),
      );
}

class _FilePreview extends StatelessWidget {
  final File   file;
  final bool   isPdf;
  final String name;
  const _FilePreview({required this.file, required this.isPdf, required this.name});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _success.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _success.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          isPdf
              ? const Icon(Icons.picture_as_pdf_rounded, color: _danger, size: 36)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(file, width: 48, height: 48, fit: BoxFit.cover)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            const Text('File attached ✓',
                style: TextStyle(
                    fontSize: 11, color: _success, fontWeight: FontWeight.w600)),
          ])),
        ]),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
          letterSpacing: 0.3));
}

class _VerificationSummary extends StatelessWidget {
  final double   invoiceTotal;
  final double   slipAmount;
  final String   currency;
  final String   method;
  final DateTime date;
  const _VerificationSummary({
    required this.invoiceTotal,
    required this.slipAmount,
    required this.currency,
    required this.method,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final diff      = slipAmount - invoiceTotal;
    final isMatch   = diff.abs() < 1.0;
    final isPartial = !isMatch && slipAmount > 0 && slipAmount < invoiceTotal;
    final isOver    = diff > 1.0;

    Color    statusColor;
    String   statusLabel;
    IconData statusIcon;
    if (isMatch) {
      statusColor = _success;
      statusLabel = 'Amount Matches Invoice';
      statusIcon  = Icons.check_circle_rounded;
    } else if (isPartial) {
      statusColor = _warn;
      statusLabel = 'Partial Payment';
      statusIcon  = Icons.warning_rounded;
    } else if (isOver) {
      statusColor = _warn;
      statusLabel = 'Overpayment Detected';
      statusIcon  = Icons.info_rounded;
    } else {
      statusColor = Colors.grey;
      statusLabel = 'Enter amount to verify';
      statusIcon  = Icons.help_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          const Text('Verification Summary',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        _summaryRow('Invoice Total',
            'BDT ${NumberFormat('#,##0.00').format(invoiceTotal)}'),
        const SizedBox(height: 6),
        _summaryRow(
          'Slip Amount',
          '$currency ${NumberFormat('#,##0.00').format(slipAmount)}',
          valueColor: statusColor,
        ),
        if (!isMatch && slipAmount > 0) ...[
          const SizedBox(height: 6),
          _summaryRow(
            isPartial ? 'Pending Balance' : 'Difference',
            'BDT ${NumberFormat('#,##0.00').format(diff.abs())}',
            valueColor: _warn,
          ),
        ],
        const SizedBox(height: 6),
        _summaryRow('Method', method),
        const SizedBox(height: 6),
        _summaryRow('Date', DateFormat('d MMM yyyy').format(date)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 6),
            Text(statusLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
          ]),
        ),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) =>
      Row(children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? Colors.black87)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// AMOUNT PICKER DIALOG
// Shown when OCR confidence is low (< 75%) and multiple amounts were detected.
// Presents up to 5 candidates so the user can confirm the correct one.
// ─────────────────────────────────────────────────────────────────────────────
class _AmountPickerDialog extends StatefulWidget {
  final List<DetectedAmount> candidates;
  final String currency;

  const _AmountPickerDialog({
    required this.candidates,
    required this.currency,
  });

  @override
  State<_AmountPickerDialog> createState() => _AmountPickerDialogState();
}

class _AmountPickerDialogState extends State<_AmountPickerDialog> {
  int _selected = 0; // index into candidates

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _warn.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.help_outline_rounded,
                    color: _warn, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Confirm the Correct Amount',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text(
                      'We\'re sorry — the AI detected multiple amounts and isn\'t sure '
                      'which is the actual paid amount. Please select the correct one.',
                      style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Candidate options ────────────────────────────────────────
            ...widget.candidates.asMap().entries.map((entry) {
              final i   = entry.key;
              final amt = entry.value;
              final isSelected = _selected == i;
              final confColor = amt.confidence >= 0.75
                  ? _success
                  : amt.confidence >= 0.45
                      ? _warn
                      : _danger;
              final ccy = amt.currency.isNotEmpty
                  ? amt.currency
                  : widget.currency;

              return GestureDetector(
                onTap: () => setState(() => _selected = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _brand.withValues(alpha: 0.07)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _brand : Colors.black12,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    // Radio indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? _brand : Colors.black26,
                          width: isSelected ? 5 : 1.5,
                        ),
                        color: isSelected ? _brand : Colors.transparent,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Amount + label
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$ccy ${fmt.format(amt.value)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? _brand : Colors.black87,
                            ),
                          ),
                          if (amt.label.isNotEmpty &&
                              amt.label != '(unlabeled)')
                            Text(
                              '"${amt.label}"',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                  fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),

                    // Confidence pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: confColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: confColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${(amt.confidence * 100).round()}%',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: confColor),
                      ),
                    ),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 4),

            // ── Actions ──────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black54,
                    side: const BorderSide(color: Colors.black26),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Enter Manually',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                      context, widget.candidates[_selected].value),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('This is Correct',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
