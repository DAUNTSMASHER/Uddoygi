// lib/features/admin/presentation/screens/admin_settings_screen.dart
//
// Admin Settings — Reset / Backup / Import
// Verification flow: Email OTP → Password → Full Legal Name
// ─────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/email_otp_service.dart';
import 'package:uddoygi/features/admin/presentation/screens/smtp_settings_screen.dart';
import 'package:uddoygi/theme/app_fonts.dart';

// ── Palette (matches admin brand) ────────────────────────────
const Color _brand   = Color(0xFF2A0A4B);
const Color _surface = Color(0xFFF5F3FF);
const Color _accent  = Color(0xFF7C3AED);
const Color _danger  = Color(0xFFDC2626);
const Color _safe    = Color(0xFF16A34A);

// ── All Firestore collections that can be reset / backed up ──
const List<String> _allCollections = [
  'users', 'notices', 'invoices', 'expenses', 'salaries',
  'welfare', 'complaints', 'messages', 'notifications',
  'rnd_projects', 'rnd_requests', 'rnd_updates', 'rnd_milestones',
  'rnd_scores', 'orders', 'work_orders', 'campaigns', 'clients',
  'products', 'attendance', 'loans', 'company',
];

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});
  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  String _cid = '';
  // Verification state
  _VerifStep _step = _VerifStep.idle;
  bool _verified   = false;

  // Pending action after verification
  _SettingsAction? _pendingAction;

  // Email OTP
  final _emailOtp  = EmailOtpService();
  final _otpCtrl   = TextEditingController();
  bool _sendingOtp  = false;
  bool _verifyingOtp = false;
  bool _otpSent     = false;

  // Password
  final _passCtrl = TextEditingController();
  bool _checkingPass = false;
  bool _passVisible  = false;

  // Legal name
  final _nameCtrl = TextEditingController();
  bool _checkingName = false;

  // Operation state
  bool _operating = false;
  String _opLog   = '';

  // Import
  final List<String> _selectedCollections = List.from(_allCollections);

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (!mounted) return;
      setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _otpCtrl.dispose(); _passCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  // ── Trigger a protected action ──────────────────────────────
  void _requireVerification(_SettingsAction action) {
    if (_verified) {
      _runAction(action);
      return;
    }
    setState(() {
      _pendingAction = action;
      _step = _VerifStep.otp;
    });
  }

  // ── Step 1a: Send email OTP ─────────────────────────────────
  Future<void> _sendOtp() async {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) {
      _snack('No email found for your account.', error: true);
      return;
    }
    setState(() => _sendingOtp = true);
    final ok = await _emailOtp.sendOtp(
      toEmail: email,
      purpose: 'Admin Settings Verification',
    );
    if (!mounted) return;
    setState(() => _sendingOtp = false);
    if (ok) {
      setState(() => _otpSent = true);
      _snack('OTP sent to $email. Check your inbox.');
    } else if (_emailOtp.lastError == 'no_smtp') {
      _snack(
        'SMTP not configured. Go to Admin → Settings → SMTP to set up email first.',
        error: true,
      );
    } else {
      _snack('Failed to send OTP: ${_emailOtp.lastError}', error: true);
    }
  }

  // ── Step 1b: Verify email OTP ───────────────────────────────
  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) { _snack('Enter the 6-digit OTP.', error: true); return; }
    setState(() => _verifyingOtp = true);
    await Future.delayed(const Duration(milliseconds: 300));
    final ok = _emailOtp.verify(code);
    if (!mounted) return;
    setState(() => _verifyingOtp = false);
    if (ok) {
      setState(() { _step = _VerifStep.password; _otpSent = false; });
      _otpCtrl.clear();
    } else {
      _snack(_emailOtp.lastError ?? 'Invalid OTP. Please try again.', error: true);
    }
  }

  // ── Step 2: Verify password ─────────────────────────────────
  Future<void> _verifyPassword() async {
    final pass = _passCtrl.text;
    if (pass.isEmpty) { _snack('Enter your password.', error: true); return; }
    setState(() => _checkingPass = true);
    try {
      final user  = FirebaseAuth.instance.currentUser!;
      final email = user.email!;
      final cred  = EmailAuthProvider.credential(email: email, password: pass);
      await user.reauthenticateWithCredential(cred);
      setState(() { _step = _VerifStep.legalName; _checkingPass = false; });
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'wrong-password' || e.code == 'invalid-credential'
          ? "That password doesn't seem right. Please try again."
          : "We couldn't verify your identity right now. Please try again.";
      _snack(msg, error: true);
    } finally {
      if (mounted) setState(() => _checkingPass = false);
    }
  }

  // ── Step 3: Verify legal name ───────────────────────────────
  Future<void> _verifyLegalName() async {
    final entered = _nameCtrl.text.trim();
    if (entered.isEmpty) { _snack('Enter your full legal name.', error: true); return; }
    setState(() => _checkingName = true);
    try {
      final uid  = FirebaseAuth.instance.currentUser?.uid;
      final snap = await DB.colSync(_cid, C.users).doc(uid).get();
      final stored = ((snap.data()?['fullName'] as String?) ?? '').trim().toLowerCase();
      if (entered.toLowerCase() == stored) {
        setState(() {
          _verified = true;
          _step     = _VerifStep.idle;
          _checkingName = false;
        });
        _snack('Identity verified. You may now proceed.', error: false);
        if (_pendingAction != null) {
          final action = _pendingAction!;
          _pendingAction = null;
          _runAction(action);
        }
      } else {
        _snack('Name does not match our records.', error: true);
      }
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _checkingName = false);
    }
  }

  // ── Run the actual action ────────────────────────────────────
  void _runAction(_SettingsAction action) {
    switch (action) {
      case _SettingsAction.resetAll:    _confirmReset();    break;
      case _SettingsAction.backup:      _runBackup();       break;
      case _SettingsAction.importData:  _runImport();       break;
    }
  }

  // ── RESET ────────────────────────────────────────────────────
  void _confirmReset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_rounded, color: _danger),
          SizedBox(width: 8),
          Text('Reset All Data', style: AppFonts.banglaBody(color: _danger,
              fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: Text(
          'This will permanently delete ALL data across every department.\n\n'
          'This action CANNOT be undone. Are you absolutely sure?',
          style: AppFonts.banglaBody(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppFonts.banglaBody(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _doReset(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Yes, Delete All', style: AppFonts.banglaBody(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _doReset() async {
    setState(() { _operating = true; _opLog = 'Starting reset...\n'; });
    final db = DB.firestore;
    for (final col in _allCollections) {
      try {
        final snap = await db.collection(col).get();
        final batch = db.batch();
        for (final doc in snap.docs) batch.delete(doc.reference);
        await batch.commit();
        _appendLog('✓ Cleared: $col (${snap.docs.length} docs)');
      } catch (e) {
        _appendLog('✗ Error on $col: $e');
      }
    }
    _appendLog('\nReset complete.');
    setState(() => _operating = false);
    _snack('All data has been reset.');
  }

  // ── BACKUP ───────────────────────────────────────────────────
  Future<void> _runBackup() async {
    setState(() { _operating = true; _opLog = 'Collecting data...\n'; });
    try {
      final db      = DB.firestore;
      final archive = Archive();
      final now     = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      for (final col in _allCollections) {
        try {
          final snap = await db.collection(col).get();
          final docs = snap.docs.map((d) {
            final m = d.data();
            // Convert Timestamps to ISO strings for JSON serialisation
            return {'id': d.id, ...m.map((k, v) =>
                MapEntry(k, v is Timestamp ? v.toDate().toIso8601String() : v))};
          }).toList();
          final jsonBytes = utf8.encode(jsonEncode(docs));
          archive.addFile(ArchiveFile('$col.json', jsonBytes.length, jsonBytes));
          _appendLog('✓ Backed up: $col (${docs.length} docs)');
        } catch (e) {
          _appendLog('✗ Skipped $col: $e');
        }
      }

      // Write zip to temp dir
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/uddoygi_backup_$now.zip';
      final file = File(path);
      final encoder = ZipEncoder();
      file.writeAsBytesSync(encoder.encode(archive)!);

      _appendLog('\nBackup saved. Sharing...');
      setState(() => _operating = false);

      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/zip')],
        subject: 'Uddoygi Backup — $now',
        text: 'Complete data backup from Uddoygi ERP ($now)',
      );
    } catch (e) {
      _appendLog('\nBackup failed: $e');
      setState(() => _operating = false);
      _snack('Backup error: $e', error: true);
    }
  }

  // ── IMPORT ───────────────────────────────────────────────────
  Future<void> _runImport() async {
    // Show collection selector first
    final confirmed = await _showImportDialog();
    if (!confirmed) return;

    setState(() { _operating = true; _opLog = 'Picking backup file...\n'; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _operating = false);
        _snack('No file selected.', error: true);
        return;
      }

      final bytes   = result.files.first.bytes!;
      final archive = ZipDecoder().decodeBytes(bytes);
      final db      = DB.firestore;

      for (final file in archive) {
        final colName = file.name.replaceAll('.json', '');
        if (!_selectedCollections.contains(colName)) {
          _appendLog('⏭ Skipped: $colName (not selected)');
          continue;
        }
        try {
          final jsonStr = utf8.decode(file.content as List<int>);
          final docs    = (jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>();
          final batch   = db.batch();
          for (final doc in docs) {
            final id = doc['id'] as String?;
            final data = Map<String, dynamic>.from(doc)..remove('id');
            // Convert ISO strings back to Timestamps
            final converted = data.map((k, v) {
              if (v is String) {
                final dt = DateTime.tryParse(v);
                if (dt != null) return MapEntry(k, Timestamp.fromDate(dt));
              }
              return MapEntry(k, v);
            });
            final ref = id != null
                ? db.collection(colName).doc(id)
                : db.collection(colName).doc();
            batch.set(ref, converted, SetOptions(merge: true));
          }
          await batch.commit();
          _appendLog('✓ Imported: $colName (${docs.length} docs)');
        } catch (e) {
          _appendLog('✗ Error on $colName: $e');
        }
      }

      _appendLog('\nImport complete.');
      setState(() => _operating = false);
      _snack('Data imported successfully.');
    } catch (e) {
      _appendLog('\nImport failed: $e');
      setState(() => _operating = false);
      _snack('Import error: $e', error: true);
    }
  }

  Future<bool> _showImportDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Select Collections to Import',
              style: AppFonts.banglaBody(fontSize: 16, fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: Column(children: [
              Row(children: [
                TextButton(
                  onPressed: () => setSt(() => _selectedCollections
                      ..clear()..addAll(_allCollections)),
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: () => setSt(() => _selectedCollections.clear()),
                  child: const Text('Clear All'),
                ),
              ]),
              Expanded(
                child: ListView(
                  children: _allCollections.map((col) => CheckboxListTile(
                    dense: true,
                    activeColor: _brand,
                    title: Text(col, style: AppFonts.banglaBody(fontSize: 13)),
                    value: _selectedCollections.contains(col),
                    onChanged: (v) => setSt(() {
                      if (v == true) _selectedCollections.add(col);
                      else _selectedCollections.remove(col);
                    }),
                  )).toList(),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Import', style: AppFonts.banglaBody(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  // ── Helpers ──────────────────────────────────────────────────
  void _appendLog(String line) {
    if (mounted) setState(() => _opLog += '$line\n');
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: AppFonts.banglaBody(fontSize: 14)),
      backgroundColor: error ? _danger : _safe,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brand, Color(0xFF6D28D9)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Text('Settings',
            style: AppFonts.banglaBody(color: Colors.white, fontWeight: FontWeight.w700,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _step != _VerifStep.idle
          ? _buildVerificationFlow()
          : _buildMainSettings(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // VERIFICATION FLOW
  // ─────────────────────────────────────────────────────────────
  Widget _buildVerificationFlow() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Progress indicator
        _VerifProgress(step: _step),
        const SizedBox(height: 32),

        if (_step == _VerifStep.otp)    _buildOtpStep(),
        if (_step == _VerifStep.password) _buildPasswordStep(),
        if (_step == _VerifStep.legalName) _buildLegalNameStep(),
      ]),
    );
  }

  Widget _buildOtpStep() {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final maskedEmail = _maskEmail(email);

    return _VerifCard(
      icon: Icons.mark_email_unread_rounded,
      title: 'Step 1 — Email Verification',
      subtitle: 'A one-time code will be sent to your account email.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),

        // Email info chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _brand.withOpacity(.15)),
          ),
          child: Row(children: [
            const Icon(Icons.email_outlined, size: 18, color: _brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text(maskedEmail,
                  style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w600,
                      color: _brand)),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        if (!_otpSent) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sendingOtp ? null : _sendOtp,
              icon: _sendingOtp
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_sendingOtp ? 'Sending...' : 'Send OTP to Email',
                  style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ] else ...[
          _InfoBox('OTP sent to $maskedEmail. Check your inbox (and spam folder).'),
          const SizedBox(height: 14),
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppFonts.banglaData(fontSize: 28, fontWeight: FontWeight.w900,
                letterSpacing: 14, color: _brand),
            decoration: _inputDec('• • • • • •').copyWith(counterText: ''),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _verifyingOtp ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _verifyingOtp
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Verify OTP',
                      style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _sendingOtp ? null : () {
              setState(() { _otpSent = false; _otpCtrl.clear(); });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text('Resend OTP',
                style: AppFonts.banglaBody(color: _accent, fontWeight: FontWeight.w600)),
          ),
        ],

        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _step = _VerifStep.idle;
            _otpSent = false;
            _otpCtrl.clear();
          }),
          child: Text('Cancel',
              style: AppFonts.banglaBody(color: Colors.black45, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  /// Masks email for display: john.doe@gmail.com → j*****e@gmail.com
  static String _maskEmail(String email) {
    if (email.isEmpty) return 'your email';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) return '${local[0]}*@$domain';
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@$domain';
  }

  Widget _buildPasswordStep() {
    return _VerifCard(
      icon: Icons.lock_rounded,
      title: 'Step 2 — Password Verification',
      subtitle: 'Enter your account password to continue.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        TextField(
          controller: _passCtrl,
          obscureText: !_passVisible,
          decoration: _inputDec('Account password').copyWith(
            suffixIcon: IconButton(
              icon: Icon(_passVisible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
                  color: _brand),
              onPressed: () => setState(() => _passVisible = !_passVisible),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _checkingPass ? null : _verifyPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _checkingPass
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: Colors.white))
                : Text('Verify Password',
                    style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _step = _VerifStep.idle),
          child: Text('Cancel',
              style: AppFonts.banglaBody(color: Colors.black45, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildLegalNameStep() {
    return _VerifCard(
      icon: Icons.badge_rounded,
      title: 'Step 3 — Legal Name Confirmation',
      subtitle: 'Enter your full legal name exactly as registered in the system.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        _InfoBox('Your name must match the record in Employee Management exactly, '
            'including capitalisation.'),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDec('Full legal name (e.g. Mohammad Rafiqul Islam)'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _checkingName ? null : _verifyLegalName,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _checkingName
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: Colors.white))
                : Text('Confirm Identity',
                    style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _step = _VerifStep.idle),
          child: Text('Cancel',
              style: AppFonts.banglaBody(color: Colors.black45, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MAIN SETTINGS
  // ─────────────────────────────────────────────────────────────
  Widget _buildMainSettings() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Verified badge
        if (_verified)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _safe.withOpacity(0.4)),
            ),
            child: Row(children: [
              Icon(Icons.verified_rounded, color: _safe, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Identity verified. Protected actions are unlocked.',
                  style: AppFonts.banglaBody(fontSize: 13, color: _safe,
                      fontWeight: FontWeight.w600))),
            ]),
          ),

        // ── Data Management ──────────────────────────────────
        _SectionHeader('Data Management'),
        const SizedBox(height: 12),

        _SettingsTile(
          icon: Icons.download_rounded,
          iconColor: _accent,
          title: 'Backup All Data',
          subtitle: 'Export all department data as a ZIP file and share or save it.',
          onTap: () => _requireVerification(_SettingsAction.backup),
          trailing: _operating && _pendingAction == _SettingsAction.backup
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _accent))
              : null,
        ),

        _SettingsTile(
          icon: Icons.upload_rounded,
          iconColor: const Color(0xFF0891B2),
          title: 'Import Data',
          subtitle: 'Restore data from a previously exported ZIP backup file.',
          onTap: () => _requireVerification(_SettingsAction.importData),
        ),

        const SizedBox(height: 24),

        // ── Email / SMTP ──────────────────────────────────────
        _SectionHeader('Email Server'),
        const SizedBox(height: 12),

        _SettingsTile(
          icon: Icons.email_rounded,
          iconColor: const Color(0xFF7C3AED),
          title: 'SMTP Email Setup',
          subtitle: 'Configure Gmail, Outlook, or custom SMTP to send OTP '
              'verification codes and notifications to employees.',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const SmtpSettingsScreen()),
          ),
        ),

        const SizedBox(height: 24),

        // ── Danger Zone ──────────────────────────────────────
        _SectionHeader('Danger Zone', color: _danger),
        const SizedBox(height: 12),

        _InfoBox(
          'The actions below are irreversible. Your identity must be verified '
          'before proceeding. Always create a backup first.',
          color: _danger,
        ),
        const SizedBox(height: 12),

        _SettingsTile(
          icon: Icons.delete_forever_rounded,
          iconColor: _danger,
          title: 'Reset All Data',
          subtitle: 'Permanently delete ALL records across every department. '
              'This cannot be undone.',
          onTap: () => _requireVerification(_SettingsAction.resetAll),
          danger: true,
        ),

        const SizedBox(height: 24),

        // ── Operation Log ────────────────────────────────────
        if (_opLog.isNotEmpty) ...[
          _SectionHeader('Operation Log'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Log Output',
                    style: AppFonts.banglaBody(color: Colors.white70, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 16),
                  onPressed: () => Clipboard.setData(ClipboardData(text: _opLog)),
                  tooltip: 'Copy log',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 8),
              if (_operating)
                const LinearProgressIndicator(
                    backgroundColor: Colors.white12,
                    color: _accent),
              const SizedBox(height: 8),
              Text(_opLog,
                  style: AppFonts.banglaBody(color: Color(0xFF98C379),
                      fontSize: 12, height: 1.6)),
            ]),
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppFonts.banglaBody(color: Colors.black26, fontSize: 14),
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _brand, width: 1.5)),
  );
}

// ─────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────
enum _VerifStep  { idle, otp, password, legalName }
enum _SettingsAction { resetAll, backup, importData }

// ─────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  final Color? color;
  const _SectionHeader(this.text, {this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 4, height: 20,
        decoration: BoxDecoration(
          color: color ?? _brand,
          borderRadius: BorderRadius.circular(2),
        )),
    const SizedBox(width: 10),
    Text(text, style: AppFonts.banglaBody(fontSize: 16, fontWeight: FontWeight.w800,
        color: color ?? _brand)),
  ]);
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title, subtitle;
  final VoidCallback onTap;
  final bool     danger;
  final Widget?  trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger   = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: danger ? _danger.withOpacity(0.3) : Colors.black),
        boxShadow: const [BoxShadow(color: Color(0x08000000),
            blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title,
            style: AppFonts.banglaBody(fontSize: 15, fontWeight: FontWeight.w700,
                color: danger ? _danger : Colors.black87)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle,
              style: AppFonts.banglaBody(fontSize: 13, color: Colors.black45,
                  height: 1.4)),
        ),
        trailing: trailing ?? Icon(
          Icons.chevron_right_rounded,
          color: danger ? _danger.withOpacity(0.5) : Colors.black26,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _VerifCard extends StatelessWidget {
  final IconData icon;
  final String   title, subtitle;
  final Widget   child;
  const _VerifCard({required this.icon, required this.title,
      required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _brand.withOpacity(0.15)),
      boxShadow: const [BoxShadow(color: Color(0x0A000000),
          blurRadius: 12, offset: Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_brand, Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppFonts.banglaBody(fontSize: 15,
                fontWeight: FontWeight.w800, color: _brand)),
            const SizedBox(height: 3),
            Text(subtitle, style: AppFonts.banglaBody(fontSize: 13,
                color: Colors.black45, height: 1.4)),
          ],
        )),
      ]),
      const SizedBox(height: 4),
      child,
    ]),
  );
}

class _VerifProgress extends StatelessWidget {
  final _VerifStep step;
  const _VerifProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('OTP',      _VerifStep.otp),
      ('Password', _VerifStep.password),
      ('Identity', _VerifStep.legalName),
    ];
    return Row(children: steps.asMap().entries.map((e) {
      final i      = e.key;
      final label  = e.value.$1;
      final sStep  = e.value.$2;
      final done   = step.index > sStep.index;
      final active = step == sStep;
      final color  = done ? _safe : active ? _brand : Colors.black12;

      return Expanded(child: Row(children: [
        Expanded(child: Column(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              done ? Icons.check_rounded : Icons.circle,
              size: done ? 16 : 10,
              color: (done || active) ? Colors.white : Colors.black26,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w600,
              color: active ? _brand : done ? _safe : Colors.black38)),
        ])),
        if (i < steps.length - 1)
          Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 20),
              color: done ? _safe : Colors.black12)),
      ]));
    }).toList());
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  final Color  color;
  const _InfoBox(this.text, {this.color = _accent});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline_rounded, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: AppFonts.banglaBody(fontSize: 13, color: color.withOpacity(0.85),
              height: 1.45))),
    ]),
  );
}
