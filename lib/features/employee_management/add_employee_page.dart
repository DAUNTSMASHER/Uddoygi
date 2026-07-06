import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/email_otp_service.dart';
import 'package:uddoygi/features/admin/presentation/screens/smtp_settings_screen.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _primaryGreen = Color(0xFF0A4128);
const _backgroundColor = Color(0xFFF4F7F6);
const _surfaceColor = Color(0xFFFFFFFF);
const _inputFillColor = Color(0xFFF1F5F9);
const _accentGreen = Color(0xFF10B981);
const _errorRed = Color(0xFFEF4444);
const _mutedText = Color(0xFF64748B);

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
      final empDoc  = await DB.colSync(_cid, C.users).doc(_selectedUid!).get();
      final empData = empDoc.data() ?? {};

      // Resolve real email (shown to user, used for reset link)
      final realEmail = ((empData['officeEmail'] ?? empData['email']) as String?)?.trim() ?? '';

      // Resolve Firebase Auth email (namespaced for employees, raw for admin)
      String empAuthEmail = (empData['authEmail'] as String?)?.trim() ?? '';
      if (empAuthEmail.isEmpty && realEmail.isNotEmpty) {
        final isAdmin = (empData['isAdmin'] as bool?) == true ||
            (empData['role'] as String?) == 'admin';
        empAuthEmail = isAdmin ? realEmail : _authEmail(realEmail, _cid);
        await DB.colSync(_cid, C.users).doc(_selectedUid!).update({
          'authEmail': empAuthEmail,
        });
      }

      if (realEmail.isEmpty) {
        if (!mounted) return;
        _showInfo(
          title: 'Cannot Reset Password',
          message: 'This employee has no email address on record.',
          isError: true,
      );
      return;
    }

      // PATH A: Direct update
      final stored  = (empData['_initialPassword']     as String?)?.trim() ?? '';
      final candidates = <String>{ if (stored.isNotEmpty) stored };

      if (newPass.length >= 6 && candidates.isNotEmpty) {
        bool updated  = false;
        for (final candidatePass in candidates) {
          try {
            final empCred = await FirebaseAuth.instance
                .signInWithEmailAndPassword(email: empAuthEmail, password: candidatePass);
            await empCred.user!.updatePassword(newPass);
            await FirebaseAuth.instance.signInWithEmailAndPassword(email: adminEmail, password: adminPass);
            await DB.colSync(_cid, C.users).doc(_selectedUid!).update({
              '_initialPassword':      newPass,
              '_passwordResetAt':      FieldValue.serverTimestamp(),
              '_passwordResetBy':      adminEmail,
            });
            updated = true;
            break;
          } catch (_) {
            try { await FirebaseAuth.instance.signInWithEmailAndPassword(email: adminEmail, password: adminPass); } catch (_) {}
          }
        }
        if (updated) {
          if (!mounted) return;
          _showInfo(title: 'Password Updated', message: 'Password updated successfully.');
          _newPassCtl.clear(); _confirmPassCtl.clear();
          setState(() { _selectedUid = null; _selectedEmp = null; });
          return;
        }
      }

      // PATH B: Send reset link
      await FirebaseAuth.instance.sendPasswordResetEmail(email: realEmail);
      if (!mounted) return;
      _showInfo(title: 'Reset Email Sent', message: 'A reset link has been sent to $realEmail.');
      _newPassCtl.clear(); _confirmPassCtl.clear();
      setState(() { _selectedUid = null; _selectedEmp = null; });

    } catch (e) {
      if (!mounted) return;
      _showInfo(title: 'Error', message: e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _errorRed : _accentGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<String?> _promptAdminPassword() async {
    final ctl = TextEditingController();
    bool obs  = true;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Confirm as Admin', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter your admin password to authorize this change.', style: GoogleFonts.dmSans(color: _mutedText, fontSize: 14)),
              const SizedBox(height: 20),
              _buildField(controller: ctl, hint: 'Admin Password', icon: Icons.lock_outline, obscure: obs,
                suffix: IconButton(icon: Icon(obs ? Icons.visibility : Icons.visibility_off, size: 18), onPressed: () => ss(() => obs = !obs))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.dmSans(color: _mutedText))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Confirm', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirm(String email) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Review Details', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReviewRow('Employee ID', _idCtl.text.trim()),
          _ReviewRow('Email', email),
          _ReviewRow('Department', _addDept.toUpperCase()),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.dmSans(color: _mutedText))),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Add Employee', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

  void _showSmtpSetupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email Server Not Set Up'),
        content: const Text('Connect a free email account (Gmail/Outlook) to send OTPs.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SmtpSettingsScreen()));
          }, child: const Text('Set Up')),
        ],
      ),
    );
  }

  void _showInfo({required String title, required String message, bool isError = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: isError ? _errorRed : _primaryGreen)),
        content: Text(message, style: GoogleFonts.dmSans(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_buildAddTab(), _buildResetTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _primaryGreen,
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                const Spacer(),
                Text('Manage Employees', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tab,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelColor: Colors.white.withOpacity(0.6),
            labelColor: Colors.white,
            tabs: const [Tab(text: 'Add Employee'), Tab(text: 'Reset Password')],
          ),
        ],
      ),
    );
  }

  Widget _buildAddTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildInfoBanner('Fill in the details below to create a new employee account. They can log in using their email and the password you set.'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField(controller: _idCtl, hint: 'Employee ID', icon: Icons.badge_outlined),
                const SizedBox(height: 16),
                _buildField(controller: _emailCtl, hint: 'Email Address', icon: Icons.email_outlined, onChanged: _onEmailChanged),
                const SizedBox(height: 12),
                if (_otpVerified)
                  _buildVerifiedBadge()
                else ...[
                  Row(
                    children: [
                      Expanded(child: _buildOtpField()),
                      const SizedBox(width: 12),
                      _buildOtpButton(),
                    ],
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 8),
                    Text('Enter the 6-digit code sent to the email.', style: GoogleFonts.dmSans(fontSize: 11, color: _mutedText)),
                  ],
                ],
                const SizedBox(height: 16),
                _buildField(controller: _passCtl, hint: 'Password', icon: Icons.lock_outline, obscure: !_passVisible,
                  suffix: IconButton(icon: Icon(_passVisible ? Icons.visibility : Icons.visibility_off, size: 18), onPressed: () => setState(() => _passVisible = !_passVisible))),
                const SizedBox(height: 16),
                _buildDeptDropdown(),
                const SizedBox(height: 32),
                _buildActionButton('Add Employee', Icons.person_add_rounded, _submitAdd),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_cid.isNotEmpty) _RecentlyAdded(cid: _cid, timeAgo: _timeAgo),
      ],
    );
  }

  Widget _buildResetTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildInfoBanner('Select an employee and set a new password. Your admin password is required to authorise this change.', isReset: true),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              _buildDeptDropdown(isReset: true),
              const SizedBox(height: 16),
              _buildEmployeeSelector(),
              const SizedBox(height: 24),
              if (_selectedEmp != null) _buildSelectedEmpCard(),
              if (_selectedEmp != null) ...[
                const SizedBox(height: 24),
                _buildField(controller: _newPassCtl, hint: 'New Password', icon: Icons.lock_outline, obscure: !_newPassVisible,
                  suffix: IconButton(icon: Icon(_newPassVisible ? Icons.visibility : Icons.visibility_off, size: 18), onPressed: () => setState(() => _newPassVisible = !_newPassVisible))),
                const SizedBox(height: 16),
                _buildField(controller: _confirmPassCtl, hint: 'Confirm Password', icon: Icons.lock_outline, obscure: !_confirmPassVisible,
                  suffix: IconButton(icon: Icon(_confirmPassVisible ? Icons.visibility : Icons.visibility_off, size: 18), onPressed: () => setState(() => _confirmPassVisible = !_confirmPassVisible))),
              ],
              const SizedBox(height: 32),
              _buildActionButton('Reset Password', Icons.lock_reset_rounded, _resetPassword),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner(String text, {bool isReset = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReset ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, color: isReset ? Colors.indigo : _accentGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.dmSans(fontSize: 13, color: isReset ? Colors.indigo[900] : _primaryGreen, height: 1.5))),
        ],
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, Widget? suffix, ValueChanged<String>? onChanged}) {
    return Container(
      decoration: BoxDecoration(color: _inputFillColor, borderRadius: BorderRadius.circular(16)),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        style: GoogleFonts.dmSans(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: _accentGreen.withOpacity(0.3))),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: _accentGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Email Verified', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: _accentGreen))),
          TextButton(onPressed: () => setState(() { _otpSent = false; _otpVerified = false; _otpCtl.clear(); }),
            child: Text('Change', style: GoogleFonts.dmSans(fontSize: 12, color: _mutedText))),
        ],
      ),
    );
  }

  Widget _buildOtpField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(color: _inputFillColor, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _otpCtl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'Enter OTP',
          hintStyle: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildOtpButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _otpSending ? null : (_otpSent ? _verifyOtp : _sendOtp),
        style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        child: _otpSending ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(_otpSent ? 'Verify' : 'Send OTP', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildDeptDropdown({bool isReset = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: _inputFillColor, borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: isReset ? _recoverDept : _addDept,
          isExpanded: true,
          items: _depts.map((d) => DropdownMenuItem(value: d, child: Text(d.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold)))).toList(),
          onChanged: (v) => setState(() { if (isReset) { _recoverDept = v!; _selectedUid = null; _selectedEmp = null; } else { _addDept = v!; } }),
        ),
      ),
    );
  }

  Widget _buildEmployeeSelector() {
    if (_cid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(_cid, C.users).where('department', isEqualTo: _recoverDept).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return Text('No employees found', style: GoogleFonts.dmSans(color: _mutedText));
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: _inputFillColor, borderRadius: BorderRadius.circular(16)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedUid,
              hint: Text('Select Employee', style: GoogleFonts.dmSans(fontSize: 14)),
              isExpanded: true,
              items: docs.map((d) {
                final m = d.data();
                return DropdownMenuItem(value: d.id, child: Text(m['fullName'] ?? m['employeeId'], style: GoogleFonts.dmSans(fontSize: 14)));
              }).toList(),
              onChanged: (v) {
                final d = docs.firstWhere((e) => e.id == v);
                final m = d.data();
                setState(() {
                  _selectedUid = v;
                  _selectedEmp = _Emp(uid: d.id, employeeId: m['employeeId'], fullName: m['fullName'], emailShown: m['officeEmail'] ?? m['email'], department: m['department'], isHead: m['isHead'] ?? false);
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedEmpCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(20), border: Border.all(color: _accentGreen.withOpacity(0.3))),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: _accentGreen, child: Text(_selectedEmp!.fullName[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedEmp!.fullName, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                Text(_selectedEmp!.emailShown, style: GoogleFonts.dmSans(fontSize: 12, color: _mutedText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton.icon(
        onPressed: (_loading || (label.contains('Reset') && _selectedEmp == null)) ? null : onTap,
        icon: _loading ? const SizedBox.shrink() : Icon(icon, color: Colors.white, size: 20),
        label: _loading ? const CircularProgressIndicator(color: Colors.white) : Text(label, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
      ),
    );
  }

  String _initials(String name) => name.split(' ').take(2).map((e) => e[0].toUpperCase()).join();
}

class _ReviewRow extends StatelessWidget {
  final String label, value;
  const _ReviewRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: GoogleFonts.dmSans(color: _mutedText, fontSize: 13))),
        Expanded(child: Text(value, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13))),
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
      stream: DB.colSync(cid, C.users).orderBy('createdAt', descending: true).limit(5).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recently Added', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryGreen)),
            const SizedBox(height: 12),
            ...docs.map((d) {
              final m = d.data();
              final dt = (m['createdAt'] as Timestamp?)?.toDate();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
                child: Row(
                  children: [
                    CircleAvatar(radius: 18, backgroundColor: _primaryGreen.withOpacity(0.1), child: Text((m['fullName'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 12, color: _primaryGreen))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m['fullName'] ?? 'Unnamed', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(m['email'] ?? 'No email', style: GoogleFonts.dmSans(fontSize: 11, color: _mutedText)),
                    ])),
                    if (dt != null) Text(timeAgo(dt), style: GoogleFonts.dmSans(fontSize: 10, color: _mutedText)),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

class _Emp {
  final String uid, employeeId, fullName, emailShown, department;
  final bool isHead;
  _Emp({required this.uid, required this.employeeId, required this.fullName, required this.emailShown, required this.department, required this.isHead});
}

class _SmtpStep extends StatelessWidget {
  final String number, text;
  const _SmtpStep({required this.number, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        CircleAvatar(radius: 10, backgroundColor: _primaryGreen.withOpacity(0.1), child: Text(number, style: const TextStyle(fontSize: 10, color: _primaryGreen))),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.dmSans(fontSize: 12))),
      ]),
    );
  }
}
