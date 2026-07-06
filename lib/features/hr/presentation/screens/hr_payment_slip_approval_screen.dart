// lib/features/hr/presentation/screens/hr_payment_slip_approval_screen.dart
//
// HR Payment Slip Approval Screen
// ─────────────────────────────────────────────────────────────────────────────
// HR reviews submitted payment slips and can:
//   • View the attached document (image inline, PDF opened via browser)
//   • Edit the amount if it is wrong or mismatched
//   • Approve → cash_in updated with HR-confirmed amount; file expires in 24 h
//   • Reject  → file deleted from Storage immediately; agent notified
//   • Download a professional Times New Roman PDF report of all verified slips
//
// KEY RULE: whatever amount HR confirms on approval is the ONLY amount added
// to cash_in — not the submitted amount, not the invoice total.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uddoygi/services/drive_storage_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ── Design Tokens (Standardized) ─────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);
const _accentGreen = Color(0xFF10B981);
const _surface    = UddoygiDesign.surface;
const _success    = Color(0xFF16A34A);
const _warn       = Color(0xFFF59E0B);
const _danger     = Color(0xFFDC2626);

final _fmt = UddoygiDesign.moneyFormat;

// Returns true if the slip's storage file has passed its expiry time.
bool _isFileExpired(Map<String, dynamic> d) {
  final ts = d['fileExpiresAt'];
  if (ts == null) return false;
  final expiry = ts is Timestamp ? ts.toDate() : null;
  if (expiry == null) return false;
  return DateTime.now().isAfter(expiry);
}

class HrPaymentSlipApprovalScreen extends StatefulWidget {
  const HrPaymentSlipApprovalScreen({super.key});

  @override
  State<HrPaymentSlipApprovalScreen> createState() =>
      _HrPaymentSlipApprovalScreenState();
}

class _HrPaymentSlipApprovalScreenState
    extends State<HrPaymentSlipApprovalScreen>
    with SingleTickerProviderStateMixin {
  String _cid     = '';
  late TabController _tabs;
  String _hrName  = '';
  String _hrEmail = '';
  String _hrUid   = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _tabs = TabController(length: 3, vsync: this);
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
    if (mounted) {
      setState(() {
        _hrUid   = user?.uid   ?? (session?['uid']   as String? ?? '');
        _hrEmail = user?.email ?? (session?['email'] as String? ?? '');
        _hrName  = (session?['name'] as String?) ?? user?.displayName ?? 'HR';
      });
    }
  }

  // ── Open review sheet ─────────────────────────────────────────────────────
  // This is the main entry point for HR to review a slip.
  // The sheet lets HR view the document, edit the amount, and approve/reject.
  void _openReviewSheet(DocumentSnapshot slip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        slip:      slip,
        hrName:    _hrName,
        hrEmail:   _hrEmail,
        hrUid:     _hrUid,
        cid:       _cid,
        readOnly:  false,
        onApproved: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Slip approved. Cash-in recorded with confirmed amount.'),
              backgroundColor: _success,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        onRejected: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Slip rejected. Agent has been notified.'),
              backgroundColor: _warn,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      ),
    );
  }

  /// Opens the same review sheet in read-only mode so HR can view details and payment proof.
  void _openVerifiedSlipDetail(DocumentSnapshot slip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        slip:      slip,
        hrName:    _hrName,
        hrEmail:   _hrEmail,
        hrUid:     _hrUid,
        cid:       _cid,
        readOnly:  true,
        onApproved: () {},
        onRejected: () {},
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Verification Portal',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _brandGreen,
          indicatorWeight: 3,
          labelColor: _brandGreen,
          unselectedLabelColor: Colors.grey[400],
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 24),
          tabs: const [
            Tab(text: 'PENDING'),
            Tab(text: 'VERIFIED'),
            Tab(text: 'REJECTED'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SlipList(
            cid:          _cid,
            statusFilter: 'pending_hr',
            onTap:        _openReviewSheet,
          ),
          // Verified tab — has a "Download Report" FAB; tap slip to view details + proof
          _VerifiedTab(
            cid: _cid,
            hrName: _hrName,
            onSlipTap: _openVerifiedSlipDetail,
          ),
          _SlipList(
            cid:          _cid,
            statusFilter: 'rejected',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEW SHEET
// Full-screen bottom sheet where HR reviews the document and confirms/edits
// the amount before approving.
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewSheet extends StatefulWidget {
  final DocumentSnapshot slip;
  final String hrName, hrEmail, hrUid, cid;
  final bool readOnly;
  final VoidCallback onApproved;
  final VoidCallback onRejected;

  const _ReviewSheet({
    required this.slip,
    required this.hrName,
    required this.hrEmail,
    required this.hrUid,
    required this.cid,
    this.readOnly = false,
    required this.onApproved,
    required this.onRejected,
  });

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final Map<String, dynamic> _d;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  final _rejectCtrl = TextEditingController();

  bool _submitting = false;
  bool _amountEdited = false;
  double _originalAmount = 0;     // raw submitted amount in original currency
  double _originalAmountBDT = 0;  // BDT equivalent (== originalAmount when BDT)
  bool   _isForeignCurrency = false;

  /// When Firestore has filePath but no fileUrl, we resolve the download URL from Storage.
  String? _resolvedProofUrl;
  bool _resolvingProofUrl = false;

  static String _normalizeUrl(dynamic v) {
    if (v == null) return '';
    final s = (v is String ? v : v.toString()).trim();
    return s;
  }

  @override
  void initState() {
    super.initState();
    _d                  = widget.slip.data() as Map<String, dynamic>;
    _originalAmount     = (_d['amount'] as num?)?.toDouble() ?? 0;
    _isForeignCurrency  = _d['isForeignCurrency'] as bool? ?? false;

    // Use amountBDT as the default confirmed amount so HR sees BDT value.
    // Fall back to convertedAmountBDT (legacy field), then raw amount.
    _originalAmountBDT  = (_d['amountBDT'] as num?)?.toDouble()
        ?? (_d['convertedAmountBDT'] as num?)?.toDouble()
        ?? _originalAmount;

    _amountCtrl = TextEditingController(
        text: _originalAmountBDT > 0
            ? _originalAmountBDT.toStringAsFixed(2)
            : '');
    _noteCtrl   = TextEditingController();

    _amountCtrl.addListener(() {
      final v = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
      final edited = (v - _originalAmountBDT).abs() > 0.001;
      if (edited != _amountEdited) setState(() => _amountEdited = edited);
    });

    // If proof file was uploaded (filePath exists) but fileUrl is missing/empty, resolve URL.
    // filePath can be a Google Drive file ID (no slashes) or a Firebase Storage path.
    final fileUrl = _normalizeUrl(_d['fileUrl']);
    final filePath = (_d['filePath'] as String? ?? '').trim();
    if (fileUrl.isEmpty && filePath.isNotEmpty && !_resolvingProofUrl) {
      _resolvingProofUrl = true;
      if (!filePath.contains('/')) {
        // Drive file ID — build view URL directly (no async).
        if (mounted) {
          setState(() {
            _resolvedProofUrl = DriveStorageService.viewUrlFromId(filePath);
            _resolvingProofUrl = false;
          });
        } else {
          _resolvingProofUrl = false;
        }
      } else {
        // Firebase Storage path — fetch download URL.
        FirebaseStorage.instance.ref().child(filePath).getDownloadURL().then((url) {
          if (mounted) {
            setState(() {
              _resolvedProofUrl = url;
              _resolvingProofUrl = false;
            });
          } else {
            _resolvingProofUrl = false;
          }
        }).catchError((_) {
          if (mounted) {
            setState(() => _resolvingProofUrl = false);
          } else {
            _resolvingProofUrl = false;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _rejectCtrl.dispose();
    super.dispose();
  }

  // ── Delete proof file (Drive or Firebase Storage) ─────────────────────────
  Future<void> _deleteStorageFile() async {
    final path = (_d['filePath'] as String? ?? '').trim();
    if (path.isEmpty) return;
    try {
      if (!path.contains('/')) {
        await DriveStorageService.instance.deleteFile(path);
      } else {
        await FirebaseStorage.instance.ref(path).delete();
      }
    } catch (_) {
      // File may already be gone — ignore
    }
  }

  // ── Approve with confirmed amount ─────────────────────────────────────────
  Future<void> _approve() async {
    final confirmedAmount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (confirmedAmount <= 0) {
      _snack('Please enter a valid amount before approving.', error: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      final invoiceId      = _d['invoiceId'] as String? ?? '';
      final invoiceNo      = _d['invoiceNo'] as String? ?? '';
      final currency       = _d['currency'] as String? ?? 'BDT';
      final method         = _d['method'] as String? ?? '';
      final submitterEmail = _d['submittedBy'] as String? ?? '';
      final hrNote         = _noteCtrl.text.trim();
      final slipDate       = _d['slipDate'] is Timestamp
          ? (_d['slipDate'] as Timestamp).toDate()
          : DateTime.now();

      final batch = DB.firestore.batch();

      // The confirmedAmount is always in BDT (HR confirms the BDT value).
      // For foreign-currency slips, the original amount in the slip's currency
      // is stored separately for reference.
      final submittedOriginalAmount = _originalAmount;  // e.g. 1500 USD
      final submittedAmountBDT      = _originalAmountBDT; // e.g. 165000 BDT
      final conversionRate          = (_d['conversionRate'] as num?)?.toDouble();
      final conversionIsLive        = _d['conversionIsLive'] as bool? ?? false;

      // 1. Mark slip verified — store BOTH submitted and confirmed amounts
      final fileExpiresAt = DateTime.now().add(const Duration(hours: 24));
      batch.update(widget.slip.reference, {
        'status':                 'verified',
        'confirmedAmount':        confirmedAmount,        // BDT, HR-confirmed
        'submittedAmount':        submittedOriginalAmount, // original currency
        'submittedAmountBDT':     submittedAmountBDT,     // BDT equivalent at submission
        'amountEdited':           _amountEdited,
        'hrNote':                 hrNote,
        'verifiedBy':             widget.hrEmail,
        'verifiedByUid':          widget.hrUid,
        'verifiedByName':         widget.hrName,
        'verifiedAt':             FieldValue.serverTimestamp(),
        'fileExpiresAt':          Timestamp.fromDate(fileExpiresAt),
        'updatedAt':              FieldValue.serverTimestamp(),
      });

      // 2. Update invoice → Payment Taken
      if (invoiceId.isNotEmpty) {
        final invRef = DB.colSync(widget.cid, C.invoices).doc(invoiceId);
        batch.update(invRef, {
          'status':     'Payment Taken',
          'statusStep': 2,
          'slipStatus': 'verified',
          'slipVerifiedAt': FieldValue.serverTimestamp(),
          'payment': {
            'taken':                true,
            'amount':               confirmedAmount,       // BDT confirmed
            'submittedAmount':      submittedOriginalAmount,
            'submittedAmountBDT':   submittedAmountBDT,
            'currency':             currency,
            'method':               method,
            'date':                 Timestamp.fromDate(slipDate),
            'ref':                  _d['ref'] ?? '',
            'verifiedByHr':         true,
            'amountEdited':         _amountEdited,
            'isForeignCurrency':    _isForeignCurrency,
            if (conversionRate != null) 'conversionRate': conversionRate,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Cash-in: ONLY the HR-confirmed BDT amount is added to cashIn.
      //    For foreign-currency slips this is the converted BDT value, NOT
      //    the raw foreign amount (e.g. 165000 BDT, not 1500 USD).
      final cashRef = DB.colSync(widget.cid, C.companyProfile).doc('main');
      batch.update(cashRef, {
        'cashIn':              FieldValue.increment(confirmedAmount),
        'lastCashInAt':        FieldValue.serverTimestamp(),
        'lastCashInAmount':    confirmedAmount,
        'lastCashInCurrency':  'BDT',  // always BDT in cashIn
        'lastCashInInvoice':   invoiceNo,
      });

      // 4. Cash-flow entry — amount is always BDT
      final cfRef = DB.colSync(widget.cid, C.cashFlow).doc();
      batch.set(cfRef, {
        'type':                  'cash_in',
        'amount':                confirmedAmount,          // BDT
        'submittedAmount':       submittedOriginalAmount,  // original currency
        'submittedAmountBDT':    submittedAmountBDT,
        'amountEdited':          _amountEdited,
        'currency':              'BDT',
        'originalCurrency':      currency,
        'isForeignCurrency':     _isForeignCurrency,
        if (conversionRate != null) 'conversionRate': conversionRate,
        if (conversionIsLive) 'conversionIsLive': true,
        'method':                method,
        'invoiceId':             invoiceId,
        'invoiceNo':             invoiceNo,
        'slipId':                widget.slip.id,
        'description':           'Payment received for Invoice #$invoiceNo'
                                 '${_isForeignCurrency ? ' ($currency ${_fmt.format(submittedOriginalAmount)} → BDT)' : ''}'
                                 '${_amountEdited ? ' (amount corrected by HR)' : ''}',
        'approvedBy':            widget.hrEmail,
        'approvedByName':        widget.hrName,
        'hrNote':                hrNote,
        'date':                  Timestamp.fromDate(slipDate),
        'createdAt':             FieldValue.serverTimestamp(),
      });

      // 5. Ledger credit entry — always BDT
      final ledgerRef = DB.colSync(widget.cid, C.ledger).doc();
      batch.set(ledgerRef, {
        'credit':      confirmedAmount,
        'account':     'Payment Received',
        'description': 'Invoice #$invoiceNo — slip verified'
                       '${_isForeignCurrency ? ' ($currency ${_fmt.format(submittedOriginalAmount)})' : ''}'
                       '${_amountEdited ? ' (HR adjusted)' : ''}',
        'currency':    'BDT',
        'invoiceId':   invoiceId,
        'invoiceNo':   invoiceNo,
        'slipId':      widget.slip.id,
        'verifiedBy':  widget.hrEmail,
        'date':        Timestamp.fromDate(slipDate),
        'createdAt':   FieldValue.serverTimestamp(),
      });

      // 6. Notify marketing agent
      final notifRef = DB.colSync(widget.cid, C.notifications).doc();
      batch.set(notifRef, {
        'type':      'slip_verified',
        'title':     'Payment Slip Verified ✓',
        'body':      'Your payment slip for Invoice #$invoiceNo has been verified. '
                     'Confirmed amount: BDT ${_fmt.format(confirmedAmount)}'
                     '${_isForeignCurrency ? ' (from $currency ${_fmt.format(submittedOriginalAmount)})' : ''}.'
                     '${_amountEdited ? ' (HR adjusted from BDT ${_fmt.format(submittedAmountBDT)})' : ''}',
        'invoiceId': invoiceId,
        'invoiceNo': invoiceNo,
        'targetEmail': submitterEmail,
        'read':      false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        widget.onApproved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack('Error: $e', error: true);
      }
    }
  }

  // ── Reject ────────────────────────────────────────────────────────────────
  Future<void> _reject() async {
    final reason = _rejectCtrl.text.trim().isEmpty
        ? 'No reason provided'
        : _rejectCtrl.text.trim();

    setState(() => _submitting = true);

    try {
      final invoiceId      = _d['invoiceId'] as String? ?? '';
      final invoiceNo      = _d['invoiceNo'] as String? ?? '';
      final submitterEmail = _d['submittedBy'] as String? ?? '';

      final batch = DB.firestore.batch();

      batch.update(widget.slip.reference, {
        'status':         'rejected',
        'hrNote':         reason,
        'rejectedBy':     widget.hrEmail,
        'rejectedByName': widget.hrName,
        'rejectedAt':     FieldValue.serverTimestamp(),
        'updatedAt':      FieldValue.serverTimestamp(),
      });

      if (invoiceId.isNotEmpty) {
        batch.update(
          DB.colSync(widget.cid, C.invoices).doc(invoiceId),
          {'slipStatus': 'rejected', 'updatedAt': FieldValue.serverTimestamp()},
        );
      }

      final notifRef = DB.colSync(widget.cid, C.notifications).doc();
      batch.set(notifRef, {
        'type':        'slip_rejected',
        'title':       'Payment Slip Rejected',
        'body':        'Your payment slip for Invoice #$invoiceNo was rejected. '
                       'Reason: $reason. Please re-submit a valid slip.',
        'invoiceId':   invoiceId,
        'invoiceNo':   invoiceNo,
        'targetEmail': submitterEmail,
        'read':        false,
        'createdAt':   FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Delete the uploaded file from Storage immediately on rejection
      await _deleteStorageFile();

      if (mounted) {
        Navigator.pop(context);
        widget.onRejected();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack('Error: $e', error: true);
      }
    }
  }

  void _showRejectConfirm() {
    _rejectCtrl.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.cancel_rounded, color: _danger, size: 20),
          SizedBox(width: 8),
          Text('Reject Slip', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Provide a reason for rejection:',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: _rejectCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. Amount mismatch, blurry image…',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _danger, width: 1.5)),
            ),
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
              _reject();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _danger, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _danger : _success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final title        = _d['title'] as String? ?? 'Payment Slip';
    final invoiceNo    = _d['invoiceNo'] as String? ?? '—';
    final invoiceTotal = (_d['invoiceTotal'] as num?)?.toDouble() ?? 0;
    final currency     = _d['currency'] as String? ?? 'BDT';
    final method       = _d['method'] as String? ?? '—';
    final submitter    = _d['submittedByName'] as String? ??
        _d['submittedBy'] as String? ?? '—';
    final ref          = _d['ref'] as String? ?? '';
    final note         = _d['note'] as String? ?? '';
    final fileUrl      = _normalizeUrl(_d['fileUrl']).isEmpty && _resolvedProofUrl != null
        ? _resolvedProofUrl!
        : _normalizeUrl(_d['fileUrl']);
    final isPdf        = _d['isPdf'] as bool? ?? false;
    final slipDate     = _d['slipDate'] is Timestamp
        ? (_d['slipDate'] as Timestamp).toDate()
        : DateTime.now();

    final confirmedAmount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    final diff      = confirmedAmount - invoiceTotal;
    final isMatch   = diff.abs() < 1.0;
    final isPartial = !isMatch && confirmedAmount > 0 && confirmedAmount < invoiceTotal;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // ── Drag handle ────────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),

          // ── Sheet header ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fact_check_rounded,
                    color: _brand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('Invoice #$invoiceNo  •  $submitter',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black45)),
                ],
              )),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.black45),
              ),
            ]),
          ),

          // ── Scrollable content ─────────────────────────────────────────
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [

                // ── Document viewer ──────────────────────────────────────
                _SectionLabel('Attached Document'),
                const SizedBox(height: 8),
                _resolvingProofUrl
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _brand,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Loading proof…',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _DocumentViewer(
                        url:       fileUrl,
                        isPdf:     isPdf,
                        isExpired: _isFileExpired(_d),
                      ),
                const SizedBox(height: 20),

                // ── Slip details ─────────────────────────────────────────
                _SectionLabel('Slip Details'),
                const SizedBox(height: 8),
                _DetailsCard(rows: [
                  _Row('Submitted By',  submitter),
                  _Row('Invoice Total', 'BDT ${_fmt.format(invoiceTotal)}'),
                  _Row('Submitted Amount',
                      '$currency ${_fmt.format(_originalAmount)}',
                      valueColor: _isForeignCurrency ? _pending : (isMatch ? _success : _warn)),
                  // Show conversion info if the slip was in a foreign currency
                  if (_isForeignCurrency) ...[
                    _Row(
                      'Converted to BDT',
                      'BDT ${_fmt.format(_originalAmountBDT)}'
                      '${(_d['conversionRate'] as num?) != null ? '  ·  rate: ${(_d['conversionRate'] as num).toStringAsFixed(4)}' : ""}',
                      valueColor: const Color(0xFF2563EB),
                    ),
                    _Row(
                      'Rate Source',
                      (_d['conversionIsLive'] as bool? ?? false)
                          ? 'Live rate at submission'
                          : 'Estimated (offline at submission)',
                      valueColor: (_d['conversionIsLive'] as bool? ?? false)
                          ? _success
                          : _warn,
                    ),
                  ],
                  if ((_d['extractedReferenceCompany'] as String?) != null)
                    _Row('Paid To', _d['extractedReferenceCompany'] as String),
                  _Row('Method',    method),
                  _Row('Slip Date', DateFormat('d MMM yyyy').format(slipDate)),
                  if (ref.isNotEmpty) _Row('Reference', ref),
                  if (note.isNotEmpty) _Row('Note', note),
                ]),

                // ── Read-only: show accepted amount and HR note ───────────
                if (widget.readOnly) ...[
                  const SizedBox(height: 20),
                  _SectionLabel('Accepted Amount'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded,
                            color: _success, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'BDT ${_fmt.format((_d['confirmedAmount'] as num?)?.toDouble() ?? _originalAmountBDT)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((_d['hrNote'] as String?)?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    _SectionLabel('HR Note'),
                    const SizedBox(height: 6),
                    Text(
                      _d['hrNote'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],

                // ── Foreign currency notice (editable mode only) ───────────
                if (!widget.readOnly && _isForeignCurrency) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.currency_exchange_rounded,
                            size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black87, height: 1.5),
                              children: [
                                const TextSpan(
                                  text: 'Foreign currency slip: ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text: 'The marketing team submitted '
                                      '$currency ${_fmt.format(_originalAmount)}. '
                                      'The BDT equivalent (BDT ${_fmt.format(_originalAmountBDT)}) '
                                      'has been pre-filled below. '
                                      'Please verify and adjust if needed before approving.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (!widget.readOnly) ...[
                const SizedBox(height: 20),

                // ── Amount confirmation (editable) ───────────────────────
                _SectionLabel('Confirm Received Amount (BDT)'),
                const SizedBox(height: 4),
                Text(
                  _isForeignCurrency
                      ? 'The amount below is the BDT equivalent of the foreign currency slip. '
                        'Verify against the document and adjust if the rate has changed. '
                        'Only this BDT amount will be added to cash-in.'
                      : 'Review the document and enter the exact amount you are accepting. '
                        'Only this amount will be added to cash-in.',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black45, height: 1.5),
                ),
                const SizedBox(height: 10),

                // Amount field with edit indicator
                Container(
                  decoration: BoxDecoration(
                    color: _amountEdited
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _amountEdited ? _warn : _success,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                          _amountEdited
                              ? Icons.edit_rounded
                              : Icons.check_circle_rounded,
                          size: 14,
                          color: _amountEdited ? _warn : _success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _amountEdited
                              ? 'Amount edited by HR'
                              : _isForeignCurrency
                                  ? 'BDT equivalent pre-filled — verify before approving'
                                  : 'Confirm the amount to accept',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _amountEdited ? _warn : _success,
                          ),
                        ),
                        if (_amountEdited) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              _amountCtrl.text =
                                  _originalAmountBDT.toStringAsFixed(2);
                            },
                            child: const Text('Reset',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _info,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        // Currency label — always BDT for confirmation
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.04),
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(8)),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: const Text('BDT',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                        // Amount input
                        Expanded(
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]')),
                            ],
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: const TextStyle(
                                  color: Colors.black26, fontSize: 20),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.horizontal(
                                    right: Radius.circular(8)),
                                borderSide:
                                    BorderSide(color: Colors.black12),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.horizontal(
                                    right: Radius.circular(8)),
                                borderSide:
                                    BorderSide(color: Colors.black12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(8)),
                                borderSide: BorderSide(
                                    color: _amountEdited ? _warn : _brand,
                                    width: 2),
                              ),
                            ),
                          ),
                        ),
                      ]),

                      // Comparison row
                      if (confirmedAmount > 0) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          _MiniChip(
                            label: 'Invoice: BDT ${_fmt.format(invoiceTotal)}',
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 8),
                          _MiniChip(
                            label: isMatch
                                ? 'Exact match ✓'
                                : isPartial
                                    ? 'Partial: −BDT ${_fmt.format(invoiceTotal - confirmedAmount)}'
                                    : 'Over: +BDT ${_fmt.format(confirmedAmount - invoiceTotal)}',
                            color: isMatch
                                ? _success
                                : isPartial
                                    ? _warn
                                    : _info,
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── HR internal note ─────────────────────────────────────
                _SectionLabel('Internal Note (Optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Partial payment accepted, balance pending…',
                    hintStyle: const TextStyle(
                        color: Colors.black26, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Colors.black12)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Colors.black12)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _brand, width: 1.5)),
                  ),
                ),
              ],
            ],
          ),
          ),

          // ── Sticky action bar ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black12)),
              boxShadow: [
                BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 12,
                    offset: Offset(0, -4)),
              ],
            ),
            child: widget.readOnly
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Close',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : _submitting
                    ? const Center(
                        child: CircularProgressIndicator(color: _brand))
                    : Row(children: [
                        // Reject
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.cancel_rounded, size: 16),
                            label: const Text('Reject'),
                            onPressed: _showRejectConfirm,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _danger,
                              side: const BorderSide(color: _danger),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Approve
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.verified_rounded, size: 16),
                            label: Text(
                              confirmedAmount > 0
                                  ? 'Accept $currency ${_fmt.format(confirmedAmount)}'
                                  : 'Enter Amount First',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            onPressed: confirmedAmount > 0 ? _approve : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _success,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENT VIEWER
// • Images: shown inline (220 px preview), tap to fullscreen
// • PDFs:   shown as a tappable card that opens in the device browser
// • Expired: shows a "file deleted" placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentViewer extends StatelessWidget {
  final String url;
  final bool   isPdf;
  final bool   isExpired;
  const _DocumentViewer({
    required this.url,
    required this.isPdf,
    this.isExpired = false,
  });

  @override
  Widget build(BuildContext context) {
    // ── No proof attached ───────────────────────────────────────────────────
    if (url.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file_rounded, color: Colors.black26, size: 36),
            const SizedBox(height: 8),
            const Text('No proof attached',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black38,
                    fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              'Submitter did not attach a file. Amount was entered manually.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black26),
            ),
          ],
        ),
      );
    }

    // When we have a URL, always show the document so HR can verify.
    // (Expiry is ignored for display; if storage deleted the file, loading may fail.)

    // ── PDF card ─────────────────────────────────────────────────────────────
    if (isPdf) {
      return GestureDetector(
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  color: _danger, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PDF Document',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.black87)),
                const SizedBox(height: 3),
                const Text('Tap to open in browser',
                    style: TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _danger,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text('Open', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.white)),
              ]),
            ),
          ]),
        ),
      );
    }

    // ── Image viewer ─────────────────────────────────────────────────────────
    return GestureDetector(
      onTap: () => _showFullscreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Image.network(
              url,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 240,
                  color: Colors.black.withValues(alpha: 0.04),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: _brand,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (ctx, err, st) => Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.broken_image_rounded,
                        color: Colors.black26, size: 36),
                    SizedBox(height: 6),
                    Text('Could not load image',
                        style: TextStyle(color: Colors.black38, fontSize: 12)),
                  ]),
                ),
              ),
            ),
            // Tap-to-enlarge hint
            Positioned(
              bottom: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.zoom_in_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text('Tap to enlarge',
                      style: TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullscreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Payment Slip',
                style: TextStyle(color: Colors.white)),
            actions: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => const Text(
                  'Could not load image',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERIFIED TAB  — slip list + "Download Report" FAB
// ─────────────────────────────────────────────────────────────────────────────
class _VerifiedTab extends StatefulWidget {
  final String cid;
  final String hrName;
  final void Function(DocumentSnapshot)? onSlipTap;
  const _VerifiedTab({
    required this.cid,
    required this.hrName,
    this.onSlipTap,
  });

  @override
  State<_VerifiedTab> createState() => _VerifiedTabState();
}

class _VerifiedTabState extends State<_VerifiedTab> {
  bool _generating = false;

  Future<void> _downloadReport(List<DocumentSnapshot> slips) async {
    if (slips.isEmpty) return;
    setState(() => _generating = true);
    try {
      final bytes = await _buildSlipReport(slips, widget.hrName);
      final dir  = await getTemporaryDirectory();
      final ts   = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/PaymentSlipReport_$ts.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Payment Slip Report – $ts',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Report error: $e'),
          backgroundColor: _danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(widget.cid, C.paymentSlips)
          .where('status', isEqualTo: 'verified')
          .orderBy('verifiedAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        return Stack(
          children: [
            // ── Slip list ──────────────────────────────────────────────────
            snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator(color: _brand))
                : snap.hasError
                    ? Center(child: Text('Error: ${snap.error}',
                          style: const TextStyle(color: _danger)))
                    : docs.isEmpty
                        ? const _EmptyState(status: 'verified')
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                            itemCount: docs.length,
                            itemBuilder: (_, i) => _SlipCard(
                              slip: docs[i],
                              onTap: widget.onSlipTap,
                            ),
                          ),

            // ── Download Report FAB ────────────────────────────────────────
            Positioned(
              bottom: 16, right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'dl_report',
                onPressed: docs.isEmpty || _generating
                    ? null
                    : () => _downloadReport(docs),
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                icon: _generating
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _generating ? 'Generating…' : 'Download Report',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIP LIST  (pending / rejected tabs)
// ─────────────────────────────────────────────────────────────────────────────
class _SlipList extends StatelessWidget {
  final String cid;
  final String statusFilter;
  final void Function(DocumentSnapshot)? onTap;

  const _SlipList({
    required this.cid,
    required this.statusFilter,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(cid, C.paymentSlips)
          .where('status', isEqualTo: statusFilter)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _brand));
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}',
              style: const TextStyle(color: _danger)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _EmptyState(status: statusFilter);
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) => _SlipCard(slip: docs[i], onTap: onTap),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIP CARD (list item — tap to open review sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _SlipCard extends StatelessWidget {
  final DocumentSnapshot slip;
  final void Function(DocumentSnapshot)? onTap;

  const _SlipCard({required this.slip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final d              = slip.data() as Map<String, dynamic>;
    final title          = d['title'] as String? ?? 'Payment Slip';
    final invoiceNo      = d['invoiceNo'] as String? ?? '—';
    final submittedAmt   = (d['amount'] as num?)?.toDouble() ?? 0;
    final confirmedAmt   = (d['confirmedAmount'] as num?)?.toDouble();
    final currency       = d['currency'] as String? ?? 'BDT';
    final method         = d['method'] as String? ?? '—';
    final submitterRaw   = d['submittedByName'] as String? ?? d['submittedBy'] as String? ?? '';
    final submitter      = submitterRaw.toString().trim().isEmpty ? 'Unknown' : submitterRaw.toString().trim();
    final status         = d['status'] as String? ?? 'pending_hr';
    final isPdf          = d['isPdf'] as bool? ?? false;
    final fileUrl        = d['fileUrl'] as String? ?? '';
    final hrNote         = d['hrNote'] as String? ?? '';
    final invoiceTotal   = (d['invoiceTotal'] as num?)?.toDouble() ?? 0;
    final amountEdited   = d['amountEdited'] as bool? ?? false;

    final createdAt = d['createdAt'] is Timestamp
        ? (d['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    final displayAmount  = confirmedAmt ?? submittedAmt;
    final diff           = displayAmount - invoiceTotal;
    final isMatch        = diff.abs() < 1.0;

    Color    statusColor;
    String   statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'verified':
        statusColor = _success;
        statusLabel = 'Verified';
        statusIcon  = Icons.verified_rounded;
        break;
      case 'rejected':
        statusColor = _danger;
        statusLabel = 'Rejected';
        statusIcon  = Icons.cancel_rounded;
        break;
      default:
        statusColor = _pending;
        statusLabel = 'Pending Review';
        statusIcon  = Icons.hourglass_top_rounded;
    }

    return UCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: (status == 'pending_hr' || status == 'verified') && onTap != null
            ? () => onTap!.call(slip)
            : null,
        borderRadius: BorderRadius.circular(UddoygiDesign.radiusM),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header (proof thumbnail or type icon) ───────────────────
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 48,
                  height: 48,
                  color: statusColor.withValues(alpha: 0.1),
                  child: fileUrl.isNotEmpty && !isPdf
                      ? Image.network(
                          fileUrl,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.image_rounded,
                            color: statusColor,
                            size: 24,
                          ),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                            (progress.expectedTotalBytes ?? 1)
                                      : null,
                                ),
                              ),
                            );
                          },
                        )
                      : Icon(
                          isPdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.image_rounded,
                          color: statusColor,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    'Invoice #$invoiceNo  •  '
                    '${DateFormat('d MMM yyyy').format(createdAt)}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w600)),
                ],
              )),
              _StatusBadge(label: statusLabel, color: statusColor, icon: statusIcon),
            ]),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Amount row ────────────────────────────────────────────
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == 'verified' ? 'Accepted Amount' : 'Submitted Amount',
                    style: const TextStyle(
                        fontSize: 10, color: Colors.black45,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(
                      '$currency ${_fmt.format(displayAmount)}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isMatch ? _success : _warn),
                    ),
                    if (amountEdited) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _warn.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('HR edited',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _warn)),
                      ),
                    ],
                  ]),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Invoice Total',
                    style: TextStyle(
                        fontSize: 10, color: Colors.black45,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('BDT ${_fmt.format(invoiceTotal)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54)),
              ]),
            ]),

            // ── Method & submitter ────────────────────────────────────
            const SizedBox(height: 8),
            Text('$method  •  by $submitter',
                style: const TextStyle(
                    fontSize: 11, color: Colors.black38)),

            // ── HR note ───────────────────────────────────────────────
            if (hrNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (status == 'rejected' ? _danger : _success)
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(
                    status == 'rejected'
                        ? Icons.info_rounded
                        : Icons.sticky_note_2_rounded,
                    size: 13,
                    color: status == 'rejected' ? _danger : _success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(hrNote,
                        style: TextStyle(
                            fontSize: 11,
                            color: status == 'rejected'
                                ? _danger
                                : _success)),
                  ),
                ]),
              ),
            ],

            // ── Tap hint ──────────────────────────────────────────────
            if (status == 'pending_hr' || status == 'verified') ...[
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(
                  status == 'pending_hr' ? 'Tap to review' : 'Tap to view details',
                  style: TextStyle(
                    fontSize: 11,
                    color: status == 'pending_hr' ? _pending : _success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded,
                    size: 13,
                    color: status == 'pending_hr' ? _pending : _success),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF REPORT BUILDER
// Generates a professional Times New Roman report of all verified slips.
// ─────────────────────────────────────────────────────────────────────────────
Future<Uint8List> _buildSlipReport(
  List<DocumentSnapshot> slips,
  String hrName,
) async {
  final pdf = pw.Document();

  // ── Fonts (Times New Roman equivalents bundled with the pdf package) ───────
  // pw.Font.times() is the built-in Times Roman (serif) font.
  final ttRegular = pw.Font.times();
  final ttBold    = pw.Font.timesBold();
  final ttItalic  = pw.Font.timesItalic();

  final now    = DateTime.now();
  final dateFmt = DateFormat('d MMMM yyyy');
  final timeFmt = DateFormat('HH:mm');
  final numFmt  = NumberFormat('#,##0.00');

  // ── Compute summary totals ─────────────────────────────────────────────────
  double totalConfirmed = 0;
  double totalSubmitted = 0;
  int    editedCount    = 0;
  for (final s in slips) {
    final d = s.data() as Map<String, dynamic>;
    totalConfirmed += (d['confirmedAmount'] as num?)?.toDouble() ?? 0;
    totalSubmitted += (d['submittedAmount'] as num?)?.toDouble() ??
                     (d['amount']           as num?)?.toDouble() ?? 0;
    if (d['amountEdited'] == true) editedCount++;
  }

  // ── Colour palette ─────────────────────────────────────────────────────────
  const headerBg  = PdfColor.fromInt(0xFF065F46); // HR green
  const rowAlt    = PdfColor.fromInt(0xFFF0FDF4); // light green tint
  const rowNormal = PdfColor.fromInt(0xFFFFFFFF);
  const textDark  = PdfColor.fromInt(0xFF0F172A);
  const textMuted = PdfColor.fromInt(0xFF64748B);
  const accent    = PdfColor.fromInt(0xFF16A34A);
  const warnClr   = PdfColor.fromInt(0xFFEA580C);
  const lineClr   = PdfColor.fromInt(0xFFE2E8F0);

  // ── Page builder ──────────────────────────────────────────────────────────
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
      theme: pw.ThemeData.withFont(
        base:   ttRegular,
        bold:   ttBold,
        italic: ttItalic,
      ),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Company header bar ─────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const pw.BoxDecoration(color: headerBg),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PAYMENT SLIP VERIFICATION REPORT',
                        style: pw.TextStyle(
                            font: ttBold,
                            fontSize: 14,
                            color: PdfColors.white,
                            letterSpacing: 0.5)),
                    pw.SizedBox(height: 3),
                    pw.Text('Confidential — HR Department',
                        style: pw.TextStyle(
                            font: ttItalic,
                            fontSize: 9,
                            color: PdfColors.white)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated: ${dateFmt.format(now)} ${timeFmt.format(now)}',
                        style: pw.TextStyle(
                            font: ttRegular, fontSize: 9,
                            color: PdfColors.white)),
                    pw.Text('Prepared by: $hrName',
                        style: pw.TextStyle(
                            font: ttRegular, fontSize: 9,
                            color: PdfColors.white)),
                    pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                        style: pw.TextStyle(
                            font: ttRegular, fontSize: 9,
                            color: PdfColors.white)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],
      ),

      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: lineClr, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('This report is system-generated and for internal use only.',
                style: pw.TextStyle(
                    font: ttItalic, fontSize: 8, color: textMuted)),
            pw.Text('Page ${ctx.pageNumber}',
                style: pw.TextStyle(
                    font: ttRegular, fontSize: 8, color: textMuted)),
          ],
        ),
      ),

      build: (ctx) => [
        // ── Summary card ───────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: rowAlt,
            border: pw.Border.all(color: lineClr, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _pdfSummaryCell(ttBold, ttRegular, 'Total Slips',
                  '${slips.length}', textDark),
              _pdfDivider(),
              _pdfSummaryCell(ttBold, ttRegular, 'Total Confirmed (BDT)',
                  numFmt.format(totalConfirmed), accent),
              _pdfDivider(),
              _pdfSummaryCell(ttBold, ttRegular, 'Total Submitted (BDT)',
                  numFmt.format(totalSubmitted), textMuted),
              _pdfDivider(),
              _pdfSummaryCell(ttBold, ttRegular, 'HR Edited',
                  '$editedCount slip${editedCount == 1 ? '' : 's'}', warnClr),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // ── Table header ───────────────────────────────────────────────────
        pw.Table(
          columnWidths: {
            0: const pw.FixedColumnWidth(22),   // #
            1: const pw.FlexColumnWidth(2.2),   // Invoice / Title
            2: const pw.FlexColumnWidth(1.5),   // Submitted By
            3: const pw.FlexColumnWidth(1.2),   // Date
            4: const pw.FlexColumnWidth(1.2),   // Method
            5: const pw.FlexColumnWidth(1.3),   // Submitted
            6: const pw.FlexColumnWidth(1.3),   // Confirmed
            7: const pw.FixedColumnWidth(38),   // Status
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: headerBg),
              children: [
                _th(ttBold, '#'),
                _th(ttBold, 'Invoice / Title'),
                _th(ttBold, 'Submitted By'),
                _th(ttBold, 'Date'),
                _th(ttBold, 'Method'),
                _th(ttBold, 'Submitted\n(BDT)', align: pw.TextAlign.right),
                _th(ttBold, 'Confirmed\n(BDT)', align: pw.TextAlign.right),
                _th(ttBold, 'Note'),
              ],
            ),

            // Data rows
            ...slips.asMap().entries.map((e) {
              final idx = e.key;
              final d   = e.value.data() as Map<String, dynamic>;

              final invoiceNo    = d['invoiceNo']       as String? ?? '—';
              final title        = d['title']           as String? ?? '—';
              final submitter    = d['submittedByName'] as String? ??
                                   d['submittedBy']     as String? ?? '—';
              final method       = d['method']          as String? ?? '—';
              final hrNote       = d['hrNote']          as String? ?? '';
              final amountEdited = d['amountEdited']    as bool?   ?? false;
              final currency     = d['currency']        as String? ?? 'BDT';
              final submitted    = (d['submittedAmount'] as num?)?.toDouble() ??
                                   (d['amount']          as num?)?.toDouble() ?? 0;
              final confirmed    = (d['confirmedAmount'] as num?)?.toDouble() ?? submitted;
              final verifiedAt   = d['verifiedAt'] is Timestamp
                  ? (d['verifiedAt'] as Timestamp).toDate()
                  : DateTime.now();

              final bg = idx.isEven ? rowNormal : rowAlt;
              final amtColor = amountEdited ? warnClr : accent;

              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  _td(ttRegular, '${idx + 1}', color: textMuted),
                  _td(ttBold, '#$invoiceNo\n$title'),
                  _td(ttRegular, submitter),
                  _td(ttRegular, dateFmt.format(verifiedAt), fontSize: 7.5),
                  _td(ttRegular, method, fontSize: 7.5),
                  _td(ttRegular,
                    '$currency\n${numFmt.format(submitted)}',
                    align: pw.TextAlign.right, color: textMuted),
                  _td(ttBold,
                    '$currency\n${numFmt.format(confirmed)}',
                    align: pw.TextAlign.right, color: amtColor),
                  _td(ttItalic,
                    amountEdited
                        ? 'Edited${hrNote.isNotEmpty ? "\n$hrNote" : ""}'
                        : hrNote.isNotEmpty ? hrNote : '—',
                    fontSize: 7.5, color: amountEdited ? warnClr : textMuted),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 20),

        // ── Totals row ─────────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            color: headerBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('TOTAL CONFIRMED:  ',
                  style: pw.TextStyle(
                      font: ttBold, fontSize: 11, color: PdfColors.white)),
              pw.Text('BDT ${numFmt.format(totalConfirmed)}',
                  style: pw.TextStyle(
                      font: ttBold, fontSize: 13, color: PdfColors.white)),
            ],
          ),
        ),

        pw.SizedBox(height: 24),

        // ── Signature block ────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _pdfSignatureBlock(ttBold, ttRegular, ttItalic,
                'Prepared by', hrName),
            _pdfSignatureBlock(ttBold, ttRegular, ttItalic,
                'Authorised by', ''),
          ],
        ),
      ],
    ),
  );

  return pdf.save();
}

// ── PDF helper widgets ────────────────────────────────────────────────────────

pw.Widget _th(pw.Font bold, String text,
    {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              font: bold, fontSize: 8, color: PdfColors.white)),
    );

pw.Widget _td(pw.Font font, String text, {
  pw.TextAlign align = pw.TextAlign.left,
  PdfColor color = const PdfColor.fromInt(0xFF0F172A),
  double fontSize = 8.0,
}) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(font: font, fontSize: fontSize, color: color)),
    );

pw.Widget _pdfSummaryCell(
    pw.Font bold, pw.Font regular, String label, String value, PdfColor color) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                font: regular, fontSize: 8,
                color: const PdfColor.fromInt(0xFF64748B))),
        pw.SizedBox(height: 3),
        pw.Text(value,
            style: pw.TextStyle(font: bold, fontSize: 13, color: color)),
      ],
    );

pw.Widget _pdfDivider() => pw.Container(
      width: 0.5, height: 32,
      color: const PdfColor.fromInt(0xFFE2E8F0),
    );

pw.Widget _pdfSignatureBlock(
    pw.Font bold, pw.Font regular, pw.Font italic,
    String role, String name) =>
    pw.Container(
      width: 180,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 0.5,
            color: const PdfColor.fromInt(0xFF0F172A),
          ),
          pw.SizedBox(height: 4),
          pw.Text(role,
              style: pw.TextStyle(
                  font: bold, fontSize: 9,
                  color: const PdfColor.fromInt(0xFF0F172A))),
          if (name.isNotEmpty)
            pw.Text(name,
                style: pw.TextStyle(
                    font: italic, fontSize: 9,
                    color: const PdfColor.fromInt(0xFF64748B))),
          pw.Text('Date: _______________',
              style: pw.TextStyle(
                  font: regular, fontSize: 9,
                  color: const PdfColor.fromInt(0xFF64748B))),
        ],
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.black54,
          letterSpacing: 0.4));
}

class _Row {
  final String label, value;
  final Color? valueColor;
  const _Row(this.label, this.value, {this.valueColor});
}

class _DetailsCard extends StatelessWidget {
  final List<_Row> rows;
  const _DetailsCard({required this.rows});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: rows.asMap().entries.map((e) {
            final r = e.value;
            return Padding(
              padding: EdgeInsets.only(bottom: e.key < rows.length - 1 ? 8 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(r.label,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                  ),
                  Expanded(
                    child: Text(r.value,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: r.valueColor ?? Colors.black87)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;
  const _StatusBadge(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.5)),
        ]),
      );
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}

class _EmptyState extends StatelessWidget {
  final String status;
  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    String label, sub;
    IconData icon;
    switch (status) {
      case 'verified':
        label = 'No verified slips yet';
        sub   = 'Approved payment slips will appear here.';
        icon  = Icons.verified_rounded;
        break;
      case 'rejected':
        label = 'No rejected slips';
        sub   = 'Rejected payment slips will appear here.';
        icon  = Icons.cancel_rounded;
        break;
      default:
        label = 'No pending slips';
        sub   = 'All payment slips have been reviewed.';
        icon  = Icons.inbox_rounded;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: Colors.grey[300]),
            ),
            const SizedBox(height: 24),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text(sub,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
