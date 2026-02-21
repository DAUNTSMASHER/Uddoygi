import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/email_otp_service.dart';
import 'package:uddoygi/features/admin/presentation/screens/smtp_settings_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _bg       = Color(0xFFF7F9FC);
const Color _primary  = Color(0xFF2563EB);
const Color _primaryDk= Color(0xFF1E3A8A);
const Color _card     = Color(0xFFFFFFFF);
const Color _border   = Color(0x14000000);
const Color _fg       = Color(0xFF0F172A);
const Color _muted    = Color(0xFF94A3B8);
const Color _success  = Color(0xFF16A34A);
const Color _danger   = Color(0xFFDC2626);

class AddEmployeePage extends StatefulWidget {
  const AddEmployeePage({super.key});
  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage>
    with SingleTickerProviderStateMixin {
  String _cid = '';
  final _auth = FirebaseAuth.instance;

  // Add tab
  final _formKey    = GlobalKey<FormState>();
  final _idCtl      = TextEditingController();
  final _emailCtl   = TextEditingController();
  final _passCtl    = TextEditingController();
  String _addDept   = 'marketing';
  bool _passVisible = false;

  // Reset tab
  final _newPassCtl     = TextEditingController();
  final _confirmPassCtl = TextEditingController();
  String _recoverDept   = 'marketing';
  String? _selectedUid;
  _Emp?   _selectedEmp;
  bool _newPassVisible     = false;
  bool _confirmPassVisible = false;

  bool    _loading    = false;
  String? _adminEmail;

  // OTP verification state
  final _otpSvc          = EmailOtpService();
  final _otpCtl          = TextEditingController();
  bool   _otpSent        = false;
  bool   _otpVerified    = false;
  bool   _otpSending     = false;
  String _otpVerifiedFor = ''; // email that was verified

  late final TabController _tab;

  static const _depts = ['admin', 'hr', 'marketing', 'factory', 'rnd'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    LocalStorageService.getSession().then((s) {
      if (!mounted) return;
      setState(() => _adminEmail = (s?['email'] as String?) ?? _auth.currentUser?.email);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _idCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _otpCtl.dispose();
    _newPassCtl.dispose();
    _confirmPassCtl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int? _parseIdNum(String s) {
    final digits = RegExp(r'\d+').allMatches(s).map((m) => m.group(0)).join();
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24)   return '${d.inHours}h ago';
    if (d.inDays < 7)     return '${d.inDays}d ago';
    final w = (d.inDays / 7).floor();
    if (w < 5)            return '${w}w ago';
    return DateFormat('yMMMd').format(t);
  }

  // Compound email for Firebase Auth (prevents cross-company collisions)
  String _authEmail(String realEmail, String cid) {
    final parts = realEmail.split('@');
    if (parts.length != 2) return realEmail;
    return '${parts[0]}+$cid@${parts[1]}';
  }

  Future<bool> _emailExistsInCompany(String realEmail) async {
    if (_cid.isEmpty) return false;
    final s1 = await DB.colSync(_cid, C.users)
        .where('email', isEqualTo: realEmail).limit(1).get();
    if (s1.docs.isNotEmpty) return true;
    final s2 = await DB.colSync(_cid, C.users)
        .where('officeEmail', isEqualTo: realEmail).limit(1).get();
    return s2.docs.isNotEmpty;
  }

  // ── OTP helpers ───────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final email = _emailCtl.text.trim();
    if (!email.contains('@')) {
      _snack('Please enter a valid email address first.', error: true);
      return;
    }
    setState(() => _otpSending = true);
    final ok = await _otpSvc.sendOtp(
      toEmail: email,
      purpose: 'Employee Account Verification',
    );
    if (!mounted) return;
    setState(() {
      _otpSending  = false;
      _otpSent     = ok || _otpSvc.lastError == 'no_smtp';
      _otpVerified = false;
      _otpCtl.clear();
    });
    if (ok) {
      _snack('OTP sent to $email. Check your inbox.');
    } else if (_otpSvc.lastError == 'no_smtp') {
      _showSmtpSetupDialog();
    } else {
      _snack('Could not send OTP: ${_otpSvc.lastError}', error: true);
    }
  }

  void _verifyOtp() {
    final code = _otpCtl.text.trim();
    if (code.length != 6) {
      _snack('Please enter the 6-digit code.', error: true);
      return;
    }
    if (_otpSvc.verify(code)) {
      setState(() {
        _otpVerified    = true;
        _otpVerifiedFor = _emailCtl.text.trim();
      });
      _snack('Email verified! You can now add the employee.');
    } else {
      _snack(_otpSvc.lastError ?? 'Incorrect code. Please try again.', error: true);
    }
  }

  // Reset OTP state when email changes
  void _onEmailChanged(String val) {
    if (_otpVerified && val.trim() != _otpVerifiedFor) {
      setState(() {
        _otpSent     = false;
        _otpVerified = false;
        _otpCtl.clear();
      });
    }
  }

  // ── Add employee ──────────────────────────────────────────────────────────

  Future<void> _submitAdd() async {
    if (!_formKey.currentState!.validate()) return;
    final realEmail = _emailCtl.text.trim();

    // Require OTP verification before creating the account
    if (!_otpVerified || _otpVerifiedFor != realEmail) {
      _showInfo(
        title: 'Email Not Verified',
        message: 'Please verify the employee\'s email address with an OTP '
            'before creating the account. Tap "Send OTP" below the email field.',
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);
    final alreadyUsed = await _emailExistsInCompany(realEmail);
    setState(() => _loading = false);

    if (alreadyUsed) {
      if (!mounted) return;
      _showInfo(
        title: 'Email already in use',
        message: 'This email is already registered to an employee in your company. '
            'Please use a different email address.',
        isError: true,
      );
      return;
    }

    final ok = await _confirm(realEmail);
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final idText    = _idCtl.text.trim();
      final authEmail = _authEmail(realEmail, _cid);

      final cred = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: _passCtl.text.trim(),
      );

      await DB.colSync(_cid, C.users).doc(cred.user!.uid).set({
        'employeeId':       idText,
        'employeeIdNum':    _parseIdNum(idText),
        'email':            realEmail,
        'officeEmail':      realEmail,
        'authEmail':        authEmail,
        'companyId':        _cid,
        'department':       _addDept,
        'addedBy':          _adminEmail,
        'fullName':         'Unnamed',
        'isHead':           false,
        'createdAt':        FieldValue.serverTimestamp(),
        '_initialPassword': _passCtl.text.trim(), // used for admin-forced password reset
      });

      if (!mounted) return;
      _showInfo(title: 'Employee Added', message: 'Employee added successfully.');
      _idCtl.clear();
      _emailCtl.clear();
      _passCtl.clear();
      _otpCtl.clear();
      setState(() {
        _otpSent        = false;
        _otpVerified    = false;
        _otpVerifiedFor = '';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showInfo(
          title: 'Could not add employee',
          message: _friendlyAuthError(e.code),
          isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _friendlyAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return "That email is already taken. Please use a different one.";
      case 'invalid-email':
        return "That doesn't look like a valid email address.";
      case 'weak-password':
        return "Password is too simple — please use at least 6 characters.";
      case 'network-request-failed':
        return "You appear to be offline. Please check your connection.";
      case 'too-many-requests':
        return "Too many attempts. Please wait a moment and try again.";
      default:
        return "Something went wrong while adding the employee. Please try again.";
    }
  }

  // ── Reset password ────────────────────────────────────────────────────────
  //
  // Two-path strategy:
  //
  // PATH A — Direct update (preferred, instant):
  //   Works when _initialPassword is stored in Firestore.
  //   Signs in temporarily as the employee, calls updatePassword(), then
  //   signs back as admin. Updates _initialPassword for next time.
  //
  // PATH B — Firebase password-reset email (reliable fallback):
  //   Used when _initialPassword is missing (admin accounts, legacy employees,
  //   or employees who changed their own password).
  //   Calls sendPasswordResetEmail() to the employee's REAL email.
  //   Firebase delivers the reset link for free — no SMTP needed.
  //   The new-password fields are ignored in this path; the employee sets
  //   their own password via the link.
  Future<void> _resetPassword() async {
    if (_selectedUid == null || _selectedEmp == null) {
      _snack('Please select an employee first.', error: true);
      return;
    }
    final newPass = _newPassCtl.text.trim();

    // Step 1: Confirm admin identity
    final adminPass = await _promptAdminPassword();
    if (adminPass == null || adminPass.isEmpty) return;

    setState(() => _loading = true);
    try {
      final adminUser  = _auth.currentUser;
      final adminEmail = adminUser?.email ?? _adminEmail;
      if (adminUser == null || adminEmail == null) throw Exception('No admin session');

      // Re-authenticate admin to confirm identity
      await adminUser.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: adminEmail, password: adminPass));

      // Step 2: Fetch employee data
      final empDoc  = await DB.colSync(_cid, C.users).doc(_selectedUid).get();
      final empData = empDoc.data() ?? {};

      // Resolve real email (shown to user, used for reset link)
      final realEmail = ((empData['officeEmail'] ?? empData['email']) as String?)?.trim() ?? '';

      // Resolve Firebase Auth email (namespaced for employees, raw for admin)
      String empAuthEmail = (empData['authEmail'] as String?)?.trim() ?? '';
      if (empAuthEmail.isEmpty && realEmail.isNotEmpty) {
        // Determine if this is the admin (role == 'admin' or isAdmin == true)
        final isAdmin = (empData['isAdmin'] as bool?) == true ||
            (empData['role'] as String?) == 'admin';
        empAuthEmail = isAdmin ? realEmail : _authEmail(realEmail, _cid);
        // Persist so future resets don't need to reconstruct
        await DB.colSync(_cid, C.users).doc(_selectedUid!).update({
          'authEmail': empAuthEmail,
        });
      }

      if (realEmail.isEmpty) {
        if (!mounted) return;
        _showInfo(
          title: 'Cannot Reset Password',
          message: 'This employee has no email address on record. '
              'Please edit their profile to add an email first.',
          isError: true,
        );
        return;
      }

      // ── PATH A: Direct update using stored password ──────────────────────
      final stored  = (empData['_initialPassword']     as String?)?.trim() ?? '';
      final pending = (empData['_pendingPasswordReset'] as String?)?.trim() ?? '';
      final candidates = <String>{
        if (stored.isNotEmpty)  stored,
        if (pending.isNotEmpty) pending,
      };

      // Only attempt PATH A if we have a new password entered AND candidates
      if (newPass.length >= 6 && candidates.isNotEmpty) {
        bool updated  = false;
        String? lastErr;

        for (final candidatePass in candidates) {
          try {
            final empCred = await FirebaseAuth.instance
                .signInWithEmailAndPassword(
                    email: empAuthEmail, password: candidatePass);

            await empCred.user!.updatePassword(newPass);

            // Sign back in as admin immediately
            await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: adminEmail, password: adminPass);

            // Persist new password for future resets
            await DB.colSync(_cid, C.users).doc(_selectedUid!).update({
              '_initialPassword':      newPass,
              '_pendingPasswordReset': null,
              '_passwordResetAt':      FieldValue.serverTimestamp(),
              '_passwordResetBy':      adminEmail,
            });

            updated = true;
            break;
          } on FirebaseAuthException catch (e) {
            lastErr = e.code;
            // Ensure we are signed back in as admin even on failure
            try {
              await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: adminEmail, password: adminPass);
            } catch (_) {}
          } catch (e) {
            lastErr = e.toString();
          }
        }

        if (updated) {
          if (!mounted) return;
          _showInfo(
            title: 'Password Updated',
            message: 'The password for ${_selectedEmp!.emailShown} has been '
                'updated successfully. They can now log in with the new password.',
          );
          _newPassCtl.clear();
          _confirmPassCtl.clear();
          setState(() { _selectedUid = null; _selectedEmp = null; });
          return;
        }

        // PATH A failed — log and fall through to PATH B
        debugPrint('[ResetPassword] PATH A failed ($lastErr), falling back to reset email');
      }

      // ── PATH B: Send Firebase password-reset email ───────────────────────
      // Firebase delivers this for free to the employee's real email.
      // No SMTP config needed. The employee clicks the link and sets their
      // own new password.
      await FirebaseAuth.instance.sendPasswordResetEmail(email: realEmail);

      if (!mounted) return;
      _showInfo(
        title: 'Reset Email Sent',
        message: 'A password reset link has been sent to:\n\n'
            '${_selectedEmp!.emailShown}\n\n'
            'The employee should check their inbox (and spam folder) and '
            'click the link to set a new password. The link expires in 1 hour.',
      );
      _newPassCtl.clear();
      _confirmPassCtl.clear();
      setState(() { _selectedUid = null; _selectedEmp = null; });

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential')
          ? "The admin password you entered doesn't match. Please try again."
          : e.code == 'user-not-found'
              ? "No account found for this employee's email. They may need to be re-added."
              : "We couldn't verify your identity (${e.code}). Please try again.";
      _showInfo(title: "Couldn't update password", message: msg, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showInfo(
          title: 'Something went wrong',
          message: "We couldn't update the password right now. Please try again.",
          isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _danger : _success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<String?> _promptAdminPassword() async {
    final ctl = TextEditingController();
    bool obs  = true;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Confirm as Admin',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter your admin password to authorise this change.',
                  style: GoogleFonts.inter(color: _muted, fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: ctl,
                obscureText: obs,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Admin password',
                  hintStyle: GoogleFonts.inter(color: _muted),
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(obs ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18, color: _muted),
                    onPressed: () => ss(() => obs = !obs),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: Text('Confirm',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirm(String email) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Review & Confirm',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _ReviewRow('Added by',   _adminEmail ?? '—'),
        _ReviewRow('Employee ID', _idCtl.text.trim()),
        _ReviewRow('Email',       email),
        _ReviewRow('Department',  _addDept.toUpperCase()),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Add Employee',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  /// Shows a rich dialog when no SMTP server is configured, with a direct
  /// "Set Up Now" button that navigates to the SMTP settings screen.
  void _showSmtpSetupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.email_outlined,
                color: Color(0xFF7C3AED), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Email Server Not Set Up',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Explanation
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Text(
                'To send OTP verification emails to employees, you need to '
                'connect a free email account (Gmail, Outlook, or Yahoo).\n\n'
                'It only takes 2 minutes to set up!',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF92400E),
                    height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            // Quick steps
            _SmtpStep(
              number: '1',
              text: 'Go to Email Server Setup (button below)',
            ),
            _SmtpStep(
              number: '2',
              text: 'Choose Gmail, Outlook, or Yahoo',
            ),
            _SmtpStep(
              number: '3',
              text: 'Enter your email + App Password',
            ),
            _SmtpStep(
              number: '4',
              text: 'Tap Test → Save — done!',
            ),
            const SizedBox(height: 16),
            // Primary action — go to SMTP screen
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2A0A4B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: Text('Set Up Email Server Now',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SmtpSettingsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Secondary — dismiss
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Set Up Later',
                    style: GoogleFonts.inter(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo({required String title, required String message, bool isError = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: (isError ? _danger : _success).withOpacity(.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: isError ? _danger : _success, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
        content: Text(message,
            style: GoogleFonts.inter(color: _fg, fontSize: 14, height: 1.5)),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isError ? _danger : _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryDk,
        foregroundColor: Colors.white,
        title: Text('Manage Employees',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primaryDk],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.person_add_rounded, size: 18), text: 'Add Employee'),
            Tab(icon: Icon(Icons.lock_reset_rounded, size: 18), text: 'Reset Password'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildAddTab(), _buildResetTab()],
      ),
    );
  }

  // ── Tab 1: Add Employee ───────────────────────────────────────────────────

  Widget _buildAddTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info banner
        _InfoBanner(
          icon: Icons.info_outline_rounded,
          text: 'Fill in the details below to create a new employee account. '
              'They can log in using their email and the password you set.',
        ),
        const SizedBox(height: 16),

        // Form card
        _SectionCard(
          title: 'Employee Details',
          icon: Icons.badge_rounded,
          child: Form(
            key: _formKey,
            child: Column(children: [
              _Field(
                label: 'Employee ID',
                hint: 'e.g. EMP-001',
                icon: Icons.badge_outlined,
                controller: _idCtl,
                validator: (v) => (v != null && v.trim().isNotEmpty) ? null : 'Required',
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Email Address',
                hint: 'employee@example.com',
                icon: Icons.email_outlined,
                controller: _emailCtl,
                keyboardType: TextInputType.emailAddress,
                onChanged: _onEmailChanged,
                validator: (v) => (v != null && v.contains('@')) ? null : 'Enter a valid email',
              ),
              const SizedBox(height: 10),

              // ── OTP verification row ─────────────────────────────────
              if (_otpVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _success.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _success.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.verified_rounded, color: _success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Email verified',
                          style: GoogleFonts.inter(
                              color: _success,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _otpSent = false; _otpVerified = false; _otpCtl.clear();
                      }),
                      child: Text('Change',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: _muted)),
                    ),
                  ]),
                )
              else ...[
                // Send OTP button
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: _otpSent ? _success : _primary,
                          width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _otpSending ? null : _sendOtp,
                    icon: _otpSending
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _primary))
                        : Icon(
                            _otpSent
                                ? Icons.refresh_rounded
                                : Icons.send_rounded,
                            size: 16,
                            color: _otpSent ? _success : _primary),
                    label: Text(
                      _otpSending
                          ? 'Sending…'
                          : (_otpSent ? 'Resend OTP' : 'Send OTP to Email'),
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _otpSent ? _success : _primary),
                    ),
                  ),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 10),
                  // OTP input + verify
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _otpCtl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8,
                            color: _fg),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '— — — — — —',
                          hintStyle: GoogleFonts.inter(
                              color: _muted,
                              fontSize: 16,
                              letterSpacing: 6),
                          filled: true,
                          fillColor: _bg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        onPressed: _verifyOtp,
                        child: Text('Verify',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('Enter the 6-digit code sent to the employee\'s email.',
                      style: GoogleFonts.inter(fontSize: 11, color: _muted)),
                ],
              ],

              const SizedBox(height: 12),
              _Field(
                label: 'Password',
                hint: 'Min 6 characters',
                icon: Icons.lock_outlined,
                controller: _passCtl,
                obscure: !_passVisible,
                validator: (v) => (v != null && v.length >= 6) ? null : 'Min 6 characters',
                suffix: IconButton(
                  icon: Icon(
                    _passVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18, color: _muted),
                  onPressed: () => setState(() => _passVisible = !_passVisible),
                ),
              ),
              const SizedBox(height: 12),

              // Department selector
              _DeptSelector(
                label: 'Department',
                value: _addDept,
                depts: _depts,
                onChanged: (v) => setState(() => _addDept = v),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _submitAdd,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.person_add_rounded, size: 18),
                  label: Text(_loading ? 'Adding…' : 'Add Employee',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Recently added
        if (_cid.isNotEmpty) _RecentlyAdded(cid: _cid, timeAgo: _timeAgo),
      ],
    );
  }

  // ── Tab 2: Reset Password ─────────────────────────────────────────────────

  Widget _buildResetTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoBanner(
          icon: Icons.shield_outlined,
          text: 'Select an employee and set a new password. '
              'Your admin password is required to authorise this change.',
          color: _primary.withOpacity(.06),
          borderColor: _primary.withOpacity(.15),
          textColor: _primaryDk,
        ),
        const SizedBox(height: 16),

        _SectionCard(
          title: 'Select Employee',
          icon: Icons.manage_accounts_rounded,
          child: Column(children: [
            // Department
            _DeptSelector(
              label: 'Filter by Department',
              value: _recoverDept,
              depts: _depts,
              onChanged: (v) => setState(() {
                _recoverDept  = v;
                _selectedUid  = null;
                _selectedEmp  = null;
              }),
            ),
            const SizedBox(height: 12),

            // Employee list
            if (_cid.isNotEmpty)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: DB.colSync(_cid, C.users)
                    .where('department', isEqualTo: _recoverDept)
                    .snapshots(),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    );
                  }
                  final docs  = snap.data?.docs ?? [];
                  final items = docs.map((d) {
                    final m = d.data();
                    return _Emp(
                      uid:        d.id,
                      employeeId: (m['employeeId'] ?? '').toString(),
                      fullName:   (m['fullName']   ?? 'Unnamed').toString(),
                      emailShown: (m['officeEmail'] ?? m['email'] ?? '').toString(),
                      department: (m['department'] ?? '').toString(),
                      isHead:     (m['isHead'] ?? false) == true,
                    );
                  }).toList();

                  if (_selectedUid != null &&
                      !items.any((e) => e.uid == _selectedUid)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() { _selectedUid = null; _selectedEmp = null; });
                    });
                  }

                  if (items.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(children: [
                        const Icon(Icons.inbox_rounded, color: _muted, size: 18),
                        const SizedBox(width: 10),
                        Text('No employees in this department.',
                            style: GoogleFonts.inter(color: _muted, fontSize: 13)),
                      ]),
                    );
                  }

                  return Column(
                    children: items.map((emp) {
                      final selected = _selectedUid == emp.uid;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedUid = emp.uid;
                          _selectedEmp = emp;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? _primary.withOpacity(.06)
                                : _card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? _primary.withOpacity(.4)
                                  : _border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: selected
                                    ? _primary.withOpacity(.12)
                                    : _bg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  _initials(emp.fullName.isNotEmpty
                                      ? emp.fullName
                                      : emp.emailShown),
                                  style: GoogleFonts.inter(
                                    color: selected ? _primary : _muted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                      child: Text(
                                        emp.fullName.isNotEmpty && emp.fullName != 'Unnamed'
                                            ? emp.fullName
                                            : emp.employeeId,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: _fg,
                                        ),
                                      ),
                                    ),
                                    if (emp.isHead)
                                      const Icon(Icons.verified_rounded,
                                          size: 14, color: _success),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text(
                                    emp.emailShown.isNotEmpty
                                        ? emp.emailShown
                                        : emp.employeeId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        color: _muted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle_rounded,
                                  color: _primary, size: 20),
                          ]),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ]),
        ),
        const SizedBox(height: 16),

        // Selected employee indicator
        if (_selectedEmp != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _success.withOpacity(.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _success.withOpacity(.2)),
            ),
            child: Row(children: [
              const Icon(Icons.person_rounded, color: _success, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Resetting password for: ${_selectedEmp!.emailShown.isNotEmpty ? _selectedEmp!.emailShown : _selectedEmp!.fullName}',
                  style: GoogleFonts.inter(
                      color: _success, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        if (_selectedEmp != null) const SizedBox(height: 16),

        // New password card
        _SectionCard(
          title: 'New Password',
          icon: Icons.lock_rounded,
          child: Column(children: [
            // Info about the two-path strategy
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primary.withValues(alpha: 0.15)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: _primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'If a stored password is available, the new password below is applied instantly. '
                    'Otherwise a reset link is sent to the employee\'s email for free.',
                    style: GoogleFonts.inter(fontSize: 12, color: _primaryDk, height: 1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            _Field(
              label: 'New Password (optional — leave blank to send reset link)',
              hint: 'Min 6 characters',
              icon: Icons.lock_outlined,
              controller: _newPassCtl,
              obscure: !_newPassVisible,
              suffix: IconButton(
                icon: Icon(
                  _newPassVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18, color: _muted),
                onPressed: () => setState(() => _newPassVisible = !_newPassVisible),
              ),
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'Confirm New Password',
              hint: 'Re-enter the password',
              icon: Icons.lock_outlined,
              controller: _confirmPassCtl,
              obscure: !_confirmPassVisible,
              suffix: IconButton(
                icon: Icon(
                  _confirmPassVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18, color: _muted),
                onPressed: () => setState(() => _confirmPassVisible = !_confirmPassVisible),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _selectedEmp != null ? _primary : _muted,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (_loading || _selectedEmp == null) ? null : _resetPassword,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.lock_reset_rounded, size: 18),
                label: Text(_loading ? 'Updating…' : 'Reset Password',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your admin password will be required to confirm.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: _muted),
            ),
          ]),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final Color? borderColor;
  final Color? textColor;

  const _InfoBanner({
    required this.icon,
    required this.text,
    this.color,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = color       ?? const Color(0xFF2563EB).withOpacity(.05);
    final border = borderColor ?? const Color(0xFF2563EB).withOpacity(.12);
    final tc     = textColor   ?? _primaryDk;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(icon, color: tc, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                  fontSize: 13, color: tc, fontWeight: FontWeight.w500, height: 1.4)),
        ),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _primary, size: 17),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: _fg)),
            ]),
          ),
          Divider(height: 1, color: _border),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _fg)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: GoogleFonts.inter(fontSize: 14, color: _fg),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
            prefixIcon: Icon(icon, color: _muted, size: 18),
            suffixIcon: suffix,
            filled: true,
            fillColor: _bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _danger)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _danger, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

class _DeptSelector extends StatelessWidget {
  final String label;
  final String value;
  final List<String> depts;
  final ValueChanged<String> onChanged;

  const _DeptSelector({
    required this.label,
    required this.value,
    required this.depts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: _fg)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: _card,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _muted, size: 20),
              style: GoogleFonts.inter(
                  fontSize: 14, color: _fg, fontWeight: FontWeight.w600),
              items: depts.map((d) => DropdownMenuItem(
                value: d,
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _deptColor(d),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(d.toUpperCase()),
                ]),
              )).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }

  static Color _deptColor(String d) {
    switch (d) {
      case 'admin':     return const Color(0xFF7C3AED);
      case 'hr':        return const Color(0xFF2563EB);
      case 'marketing': return const Color(0xFF16A34A);
      case 'factory':   return const Color(0xFFF97316);
      case 'rnd':       return const Color(0xFFDC2626);
      default:          return _muted;
    }
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: Text('$label:',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, color: _muted, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: _fg, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _RecentlyAdded extends StatelessWidget {
  final String cid;
  final String Function(DateTime) timeAgo;
  const _RecentlyAdded({required this.cid, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(cid, C.users)
          .orderBy('createdAt', descending: true)
          .limit(8)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        final all = snap.data?.docs ?? [];
        final withTs = all.where((d) {
          final v = d.data()['createdAt'];
          return v is Timestamp || v is DateTime;
        }).toList();
        if (withTs.isEmpty) return const SizedBox.shrink();

        DateTime? asDate(dynamic v) =>
            v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

        return _SectionCard(
          title: 'Recently Added',
          icon: Icons.history_rounded,
          child: Column(
            children: withTs.take(6).map((d) {
              final m    = d.data();
              final id   = (m['employeeId'] ?? '—').toString();
              final email= (m['officeEmail'] ?? m['email'] ?? '—').toString();
              final dept = (m['department']  ?? '').toString();
              final dt   = asDate(m['createdAt']);
              final when = dt != null ? timeAgo(dt) : 'just now';
              final name = (m['fullName'] ?? '').toString();
              final initials = name.isNotEmpty && name != 'Unnamed'
                  ? name.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase()
                  : id.length >= 2 ? id.substring(id.length - 2).toUpperCase() : 'ID';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(initials,
                          style: GoogleFonts.inter(
                              color: _primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(id,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _fg)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _deptChipColor(dept).withOpacity(.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(dept.toUpperCase(),
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _deptChipColor(dept))),
                          ),
                        ]),
                        const SizedBox(height: 2),
                        Text(email,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: _muted),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Text(when,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _muted)),
                ]),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  static Color _deptChipColor(String d) {
    switch (d) {
      case 'admin':     return const Color(0xFF7C3AED);
      case 'hr':        return const Color(0xFF2563EB);
      case 'marketing': return const Color(0xFF16A34A);
      case 'factory':   return const Color(0xFFF97316);
      case 'rnd':       return const Color(0xFFDC2626);
      default:          return _muted;
    }
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────
class _Emp {
  final String uid, employeeId, fullName, emailShown, department;
  final bool isHead;
  _Emp({
    required this.uid,
    required this.employeeId,
    required this.fullName,
    required this.emailShown,
    required this.department,
    required this.isHead,
  });
  String get email => emailShown;
}

// ── SMTP setup step row (used in the no-SMTP dialog) ─────────────────────────
class _SmtpStep extends StatelessWidget {
  final String number;
  final String text;
  const _SmtpStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF7C3AED))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 13, color: _fg, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
