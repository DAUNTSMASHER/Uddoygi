// lib/features/auth/presentation/screens/company_registration_screen.dart
//
// Multi-tenant company onboarding:
//   Step 1 — Company details (name, email, phone, address, industry)
//   Step 2 — Admin account (full name + email; password is auto-generated)
//   Step 3 — Payment (FREE for now — bKash 01799499092, 0 taka)
//   Step 4 — Success: shows generated Company ID + auto-generated admin
//             email & password. User must save all three.
//
// On completion this screen writes to Firestore:
//   companies/{companyId}  — company profile + payment record
//   users/{uid}            — admin user document (created by Firebase Auth)
// ─────────────────────────────────────────────────────────────
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/email_otp_service.dart';

// ── Palette ──────────────────────────────────────────────────
const Color _bg      = Color(0xFFF6F8FF); // Matches Marketing surface
const Color _brand   = Color(0xFF0D47A1); // Brand Blue
const Color _brand2  = Color(0xFF1D5DF1); // Blue Mid
const Color _success = Color(0xFF16A34A);
const Color _danger  = Color(0xFFDC2626);
const Color _border  = Color(0xFFD1D5DB);
const Color _muted   = Color(0xFF6B7280);
const Color _card    = Colors.white;

// bKash receiving number (testing)
const String _bkashNumber = '01799499092';

// ── Wizard steps ─────────────────────────────────────────────
enum _Step { details, admin, payment, success }

// ─────────────────────────────────────────────────────────────
class CompanyRegistrationScreen extends StatefulWidget {
  const CompanyRegistrationScreen({super.key});
  @override
  State<CompanyRegistrationScreen> createState() =>
      _CompanyRegistrationScreenState();
}

class _CompanyRegistrationScreenState
    extends State<CompanyRegistrationScreen> {
  _Step _step = _Step.details;
  bool  _busy = false;

  // ── Step 1: Company details ──────────────────────────────
  final _companyNameCtrl   = TextEditingController();
  final _companyEmailCtrl  = TextEditingController();
  final _companyPhoneCtrl  = TextEditingController();
  final _companyAddrCtrl   = TextEditingController();
  String _industry = 'Manufacturing';
  static const _industries = [
    'Manufacturing', 'Textile', 'Electronics', 'IT & Software',
    'Retail', 'Healthcare', 'Education', 'Logistics', 'Other',
  ];

  // ── Step 2: Admin account ────────────────────────────────
  final _adminNameCtrl  = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  // Password is auto-generated — not entered by user

  // ── Step 4: Result ───────────────────────────────────────
  String _generatedCompanyId   = '';
  String _generatedAdminPass   = '';

  @override
  void dispose() {
    for (final c in [
      _companyNameCtrl, _companyEmailCtrl, _companyPhoneCtrl,
      _companyAddrCtrl, _adminNameCtrl, _adminEmailCtrl,
    ]) c.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────
  static String _generateCompanyId() {
    final rng = Random.secure();
    return (10000000 + rng.nextInt(90000000)).toString();
  }

  /// Generates a strong 12-char alphanumeric password automatically.
  static String _generatePassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789@#!';
    final rng = Random.secure();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static String _friendlyRegAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return "That email is already registered with us. Try logging in instead.";
      case 'invalid-email':
        return "That doesn't look like a valid email address. Could you check it?";
      case 'weak-password':
        return "That password is a bit too simple. Please use at least 6 characters.";
      case 'network-request-failed':
        return "Looks like you're offline. Please check your connection and try again.";
      case 'too-many-requests':
        return "Too many attempts — please wait a moment and try again.";
      default:
        return "Something went wrong during registration. Please try again.";
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

  bool _validateDetails() {
    if (_companyNameCtrl.text.trim().isEmpty) {
      _snack('Company name is required.', error: true); return false;
    }
    if (_companyPhoneCtrl.text.trim().isEmpty) {
      _snack('Company phone is required.', error: true); return false;
    }
    if (_companyEmailCtrl.text.trim().isEmpty ||
        !_companyEmailCtrl.text.contains('@')) {
      _snack('Valid company email is required.', error: true); return false;
    }
    return true;
  }

  bool _validateAdmin() {
    if (_adminNameCtrl.text.trim().isEmpty) {
      _snack('Admin full name is required.', error: true); return false;
    }
    if (_adminEmailCtrl.text.trim().isEmpty ||
        !_adminEmailCtrl.text.contains('@')) {
      _snack('Valid admin email is required.', error: true); return false;
    }
    return true;
  }

  // ── Final registration ────────────────────────────────────
  Future<void> _register() async {
    setState(() => _busy = true);

    try {
      // 1. Auto-generate a secure password for the admin
      final autoPass = _generatePassword();

      // 2. Create Firebase Auth user for the admin
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _adminEmailCtrl.text.trim(),
        password: autoPass,
      );
      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(_adminNameCtrl.text.trim());

      // 3. Generate unique company ID (retry if collision)
      String companyId = _generateCompanyId();
      while ((await DB.companiesCol.doc(companyId).get()).exists) {
        companyId = _generateCompanyId();
      }

      final now   = FieldValue.serverTimestamp();
      final phone = _companyPhoneCtrl.text.trim();

      // 4. Write company document (root-level registry — for login lookup)
      await DB.companiesCol.doc(companyId).set({
        'companyId':    companyId,
        'companyName':  _companyNameCtrl.text.trim(),
        'legalName':    _companyNameCtrl.text.trim(),
        'brandName':    _companyNameCtrl.text.trim(),
        'email':        _companyEmailCtrl.text.trim(),
        'phone':        phone,
        'address':      _companyAddrCtrl.text.trim(),
        'industry':     _industry,
        'logoUrl':      '',
        'signatureUrl': '',
        'sealUrl':      '',
        'isVerified':   false,
        'isActive':     true,
        'plan':         'starter',
        'adminUid':     uid,
        'adminEmail':   _adminEmailCtrl.text.trim(),
        'createdAt':    now,
        'updatedAt':    now,
        // Payment — free for testing
        'payment': {
          'method':    'free',
          'reference': 'FREE_TESTING',
          'amount':    '0',
          'status':    'complimentary',
          'paidAt':    now,
        },
      });

      // 5. Write admin user document — under data/{companyId}/users/{uid}
      //    authEmail = raw email (admin is NOT namespaced with +CID)
      //    _initialPassword stored so admin-forced password reset works
      await DB.colSync(companyId, C.users).doc(uid).set({
        'uid':              uid,
        'fullName':         _adminNameCtrl.text.trim(),
        'email':            _adminEmailCtrl.text.trim(),
        'officeEmail':      _adminEmailCtrl.text.trim(),
        'authEmail':        _adminEmailCtrl.text.trim(), // raw — not namespaced
        'phone':            phone,
        'role':             'admin',
        'department':       'admin',
        'companyId':        companyId,
        'isAdmin':          true,
        'isActive':         true,
        '_initialPassword': autoPass, // enables admin-forced password reset
        'createdAt':        now,
        'updatedAt':        now,
      });

      // 6. Bootstrap the company's core Firestore structure
      await _bootstrapCompanyCollections(DB.firestore, companyId, uid);

      // 7. Save company ID locally so login screen pre-fills it
      await LocalStorageService.saveCompanyId(companyId);

      // 8. Send Company ID + admin credentials to the admin email
      _sendWelcomeEmail(
        toEmail:   _adminEmailCtrl.text.trim(),
        companyName: _companyNameCtrl.text.trim(),
        companyId:  companyId,
        adminEmail: _adminEmailCtrl.text.trim(),
        adminPass:  autoPass,
      );

      setState(() {
        _generatedCompanyId = companyId;
        _generatedAdminPass = autoPass;
        _step = _Step.success;
        _busy = false;
      });
    } on FirebaseAuthException catch (e) {
      _snack(_friendlyRegAuthError(e.code), error: true);
      setState(() => _busy = false);
    } catch (_) {
      _snack("We ran into a problem completing your registration. Please try again.", error: true);
      setState(() => _busy = false);
    }
  }

  /// Sends welcome email with Company ID + admin credentials.
  /// Fire-and-forget — does not block registration success screen.
  void _sendWelcomeEmail({
    required String toEmail,
    required String companyName,
    required String companyId,
    required String adminEmail,
    required String adminPass,
  }) {
    final formattedId = '${companyId.substring(0, 4)} ${companyId.substring(4)}';
    final html = '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8">
<style>
  body{font-family:Arial,sans-serif;background:#f5f5f5;margin:0;padding:20px}
  .card{background:#fff;border-radius:12px;max-width:520px;margin:0 auto;padding:32px;
        box-shadow:0 2px 12px rgba(0,0,0,.08)}
  .logo{font-size:22px;font-weight:800;color:#2A0A4B;margin-bottom:4px}
  .sub{font-size:13px;color:#6B7280;margin-bottom:24px}
  .hero{background:linear-gradient(135deg,#2A0A4B,#5C2EA0);border-radius:12px;
        padding:24px;text-align:center;margin:20px 0}
  .cid{font-size:38px;font-weight:900;color:#fff;letter-spacing:8px}
  .cid-label{font-size:11px;color:rgba(255,255,255,.65);margin-bottom:8px}
  .row{background:#F7F4FF;border-radius:8px;padding:12px 16px;margin:8px 0}
  .key{font-size:12px;color:#6B7280;display:block}
  .val{font-size:13px;font-weight:700;color:#2A0A4B;display:block;margin-top:2px}
  .warn{background:#FEF3C7;border-radius:8px;padding:12px 16px;font-size:12px;
        color:#92400E;margin-top:16px}
  .footer{font-size:11px;color:#9CA3AF;margin-top:24px;border-top:1px solid #E5E7EB;
          padding-top:16px}
</style></head>
<body>
<div class="card">
  <div class="logo">Uddoygi ERP</div>
  <div class="sub">Company Registration Successful</div>
  <p style="color:#374151;font-size:14px">
    Welcome, <strong>$companyName</strong>! Your company has been registered.
    Save the details below — you will need them every time you log in.
  </p>
  <div class="hero">
    <div class="cid-label">YOUR COMPANY ID</div>
    <div class="cid">$formattedId</div>
  </div>
  <div class="row">
    <span class="key">Admin Email</span>
    <span class="val">$adminEmail</span>
  </div>
  <div class="row">
    <span class="key">Temporary Password</span>
    <span class="val">$adminPass</span>
  </div>
  <div class="warn">
    ⚠️ Change your password after your first login.<br>
    Keep this email safe — it contains your login credentials.
  </div>
  <div class="footer">
    Automated message from Uddoygi ERP. Do not reply.
  </div>
</div>
</body></html>
''';

    EmailOtpService().sendEmail(
      toEmail: toEmail,
      subject: 'Welcome to Uddoygi ERP — Your Company ID & Login Details',
      htmlBody: html,
    ).then((ok) {
      debugPrint('[Registration] Welcome email ${ok ? "sent" : "failed"}: '
          '${ok ? "" : EmailOtpService().lastError}');
    });
  }

  /// Seeds empty placeholder documents for all core collections
  /// under the new path: data/{companyId}/{collection}/_init
  Future<void> _bootstrapCompanyCollections(
      FirebaseFirestore db, String companyId, String adminUid) async {
    final batch = db.batch();
    final now   = Timestamp.now();
    final root  = db.collection('data').doc(companyId);

    // company_profile/main — company profile singleton
    batch.set(root.collection(C.companyProfile).doc('main'), {
      'companyId':   companyId,
      'companyName': _companyNameCtrl.text.trim(),
      'legalName':   _companyNameCtrl.text.trim(),
      'brandName':   _companyNameCtrl.text.trim(),
      'email':       _companyEmailCtrl.text.trim(),
      'phone':       _companyPhoneCtrl.text.trim(),
      'industry':    _industry,
      'logoUrl':     '',
      'isVerified':  false,
      'isActive':    true,
      'cashIn':      0,
      'cashOut':     0,
      'createdAt':   now,
      'updatedAt':   now,
    }, SetOptions(merge: true));

    // Seed sentinel docs for every module collection
    const collections = [
      C.notices, C.invoices, C.expenses, C.salaries, C.welfare,
      C.complaints, C.messages, C.notifications, C.rndProjects,
      C.rndRequests, C.rndUpdates, C.rndMilestones,
      C.workOrders, C.campaigns, C.products, C.attendance,
      C.loans, C.payrolls, C.cashFlow, C.hrDocuments, C.paymentSlips,
      C.customers, C.stocks, C.tasks, C.budgets, C.marketingIncentives,
    ];
    for (final col in collections) {
      batch.set(root.collection(col).doc('_init'), {
        'companyId': companyId,
        'createdAt': now,
        '_sentinel': true,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Register Your Company',
            style: GoogleFonts.ubuntu(
                fontWeight: FontWeight.w700, fontSize: 17)),
        leading: _step != _Step.success
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (_step == _Step.details) {
                    Navigator.maybePop(context);
                  } else {
                    setState(() => _step = _Step.values[_step.index - 1]);
                  }
                },
              )
            : null,
      ),
      body: Column(
        children: [
          if (_step != _Step.success) _StepBar(current: _step),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _Step.details: return _buildDetailsStep();
      case _Step.admin:   return _buildAdminStep();
      case _Step.payment: return _buildPaymentStep();
      case _Step.success: return _buildSuccessStep();
    }
  }

  // ── Step 1: Company Details ───────────────────────────────
  Widget _buildDetailsStep() {
    return _StepCard(
      title: 'Company Information',
      icon: Icons.business_rounded,
      child: Column(children: [
        _Field(ctrl: _companyNameCtrl,  label: 'Company Name *',
            icon: Icons.business_outlined),
        _Field(ctrl: _companyEmailCtrl, label: 'Company Email *',
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress),
        _Field(ctrl: _companyPhoneCtrl, label: 'Company Phone *',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
            hint: '+8801XXXXXXXXX'),
        _Field(ctrl: _companyAddrCtrl,  label: 'Registered Address',
            icon: Icons.location_on_outlined, maxLines: 2),
        _DropdownField(
          label: 'Industry',
          value: _industry,
          items: _industries,
          onChanged: (v) => setState(() => _industry = v),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Continue',
          icon: Icons.arrow_forward_rounded,
          onTap: () {
            if (_validateDetails()) setState(() => _step = _Step.admin);
          },
        ),
      ]),
    );
  }

  // ── Step 2: Admin Account ─────────────────────────────────
  Widget _buildAdminStep() {
    return _StepCard(
      title: 'Admin Account Setup',
      icon: Icons.admin_panel_settings_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Info banner — password will be auto-generated
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: _brand.withOpacity(.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _brand.withOpacity(.2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.auto_awesome_rounded, size: 18, color: _brand),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'A secure admin password will be auto-generated and shown '
              'on the next screen. Please save it carefully — '
              'you will use it to log in.',
              style: GoogleFonts.ubuntu(
                  fontSize: 12, color: _brand, height: 1.5),
            )),
          ]),
        ),

        _Field(ctrl: _adminNameCtrl,  label: 'Admin Full Name *',
            icon: Icons.person_outline),
        _Field(ctrl: _adminEmailCtrl, label: 'Admin Email *',
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress),

        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Continue to Payment',
          icon: Icons.payment_rounded,
          onTap: () {
            if (_validateAdmin()) setState(() => _step = _Step.payment);
          },
        ),
      ]),
    );
  }

  // ── Step 3: Payment ───────────────────────────────────────
  Widget _buildPaymentStep() {
    return _StepCard(
      title: 'Subscription Payment',
      icon: Icons.receipt_long_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // FREE badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF15803D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _success.withOpacity(.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.celebration_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text('FREE — Testing Period',
                  style: GoogleFonts.ubuntu(
                      fontWeight: FontWeight.w900, fontSize: 18,
                      color: Colors.white)),
            ]),
            const SizedBox(height: 6),
            Text('৳ 0  (No payment required right now)',
                style: GoogleFonts.ubuntu(
                    fontSize: 13, color: Colors.white70,
                    fontWeight: FontWeight.w600)),
          ]),
        ),

        const SizedBox(height: 20),

        // Plan summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _brand.withOpacity(.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _brand.withOpacity(.15)),
          ),
          child: Row(children: [
            const Icon(Icons.star_rounded, color: _brand, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Starter Plan — Complimentary',
                    style: GoogleFonts.ubuntu(
                        fontWeight: FontWeight.w800, fontSize: 13,
                        color: _brand)),
                Text('Full ERP access · 1 company · Up to 50 users',
                    style: GoogleFonts.ubuntu(
                        fontSize: 11, color: _muted)),
              ],
            )),
            Text('FREE', style: GoogleFonts.ubuntu(
                fontWeight: FontWeight.w900, fontSize: 15,
                color: _success)),
          ]),
        ),

        const SizedBox(height: 16),

        // bKash info (for future reference)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE2136E).withOpacity(.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFE2136E).withOpacity(.2)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.mobile_friendly_rounded,
                  size: 16, color: Color(0xFFE2136E)),
              const SizedBox(width: 8),
              Text('bKash Payment (when billing starts)',
                  style: GoogleFonts.ubuntu(
                      fontWeight: FontWeight.w700, fontSize: 12,
                      color: const Color(0xFFE2136E))),
            ]),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.phone_rounded,
              label: 'Receiving bKash Number',
              value: _bkashNumber,
              copyable: true,
            ),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.currency_exchange_rounded,
              label: 'Current Charge',
              value: '৳ 0  (Free for testing)',
            ),
          ]),
        ),

        const SizedBox(height: 24),
        _PrimaryButton(
          label: _busy ? 'Registering…' : 'Complete Registration',
          icon: _busy ? null : Icons.check_circle_rounded,
          loading: _busy,
          onTap: _busy ? null : _register,
        ),
      ]),
    );
  }

  // ── Step 4: Success ───────────────────────────────────────
  Widget _buildSuccessStep() {
    final formatted = _generatedCompanyId.length == 8
        ? '${_generatedCompanyId.substring(0, 4)} '
          '${_generatedCompanyId.substring(4)}'
        : _generatedCompanyId;

    return Column(children: [
      const SizedBox(height: 20),

      // Success icon
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: _success.withOpacity(.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle_rounded,
            size: 48, color: _success),
      ),
      const SizedBox(height: 16),
      Text('Registration Successful!',
          style: GoogleFonts.ubuntu(
              fontSize: 20, fontWeight: FontWeight.w900,
              color: _success)),
      const SizedBox(height: 6),
      Text('Save the credentials below — you will need them to log in.',
          textAlign: TextAlign.center,
          style: GoogleFonts.ubuntu(fontSize: 13, color: _muted)),
      const SizedBox(height: 28),

      // ── Credentials card ─────────────────────────────────
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1D5DF1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _brand.withOpacity(.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(children: [

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              const Icon(Icons.vpn_key_rounded,
                  size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text('Your Login Credentials',
                  style: GoogleFonts.ubuntu(
                      fontSize: 13, color: Colors.white70,
                      fontWeight: FontWeight.w700)),
            ]),
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white12,
              margin: const EdgeInsets.symmetric(horizontal: 20)),
          const SizedBox(height: 14),

          // Company ID
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _CredRow(
              icon: Icons.fingerprint_rounded,
              label: 'Company ID',
              value: formatted,
              rawValue: _generatedCompanyId,
              large: true,
            ),
          ),

          const SizedBox(height: 10),
          Container(height: 1, color: Colors.white12,
              margin: const EdgeInsets.symmetric(horizontal: 20)),
          const SizedBox(height: 10),

          // Admin Email
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _CredRow(
              icon: Icons.email_outlined,
              label: 'Admin Email',
              value: _adminEmailCtrl.text.trim(),
              rawValue: _adminEmailCtrl.text.trim(),
            ),
          ),

          const SizedBox(height: 10),
          Container(height: 1, color: Colors.white12,
              margin: const EdgeInsets.symmetric(horizontal: 20)),
          const SizedBox(height: 10),

          // Auto-generated password
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _CredRow(
              icon: Icons.lock_rounded,
              label: 'Auto-Generated Password',
              value: _generatedAdminPass,
              rawValue: _generatedAdminPass,
              mono: true,
            ),
          ),

          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white12,
              margin: const EdgeInsets.symmetric(horizontal: 20)),
          const SizedBox(height: 14),

          // Copy all button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: GestureDetector(
              onTap: () {
                final text =
                    'Company ID: $_generatedCompanyId\n'
                    'Email: ${_adminEmailCtrl.text.trim()}\n'
                    'Password: $_generatedAdminPass';
                Clipboard.setData(ClipboardData(text: text));
                _snack('All credentials copied to clipboard!');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.copy_all_rounded,
                      size: 15, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Copy All Credentials',
                      style: GoogleFonts.ubuntu(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ]),
              ),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 16),

      // Warning banner
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'This password will NOT be shown again. '
            'Please copy and save it now before closing this screen.',
            style: GoogleFonts.ubuntu(
                fontSize: 12, color: const Color(0xFF92400E),
                height: 1.5, fontWeight: FontWeight.w600),
          )),
        ]),
      ),

      const SizedBox(height: 14),

      // SMS notice
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.sms_rounded, size: 18, color: Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Your Company ID and credentials have been saved on this device. '
            'An SMS will be sent to ${_companyPhoneCtrl.text.trim()} '
            'for future reference.',
            style: GoogleFonts.ubuntu(
                fontSize: 12, color: const Color(0xFF166534),
                height: 1.5),
          )),
        ]),
      ),

      const SizedBox(height: 24),
      _PrimaryButton(
        label: 'Go to Login',
        icon: Icons.login_rounded,
        onTap: () => Navigator.pushNamedAndRemoveUntil(
            context, '/login', (_) => false),
      ),
      const SizedBox(height: 40),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// STEP PROGRESS BAR
// ─────────────────────────────────────────────────────────────
class _StepBar extends StatelessWidget {
  final _Step current;
  const _StepBar({required this.current});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.business_rounded,             'Company'),
      (Icons.admin_panel_settings_rounded, 'Admin'),
      (Icons.payment_rounded,              'Payment'),
    ];
    return Container(
      color: _brand,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: steps.asMap().entries.map((e) {
          final i      = e.key;
          final label  = e.value.$2;
          final icon   = e.value.$1;
          final done   = current.index > i;
          final active = current.index == i;
          final color  = done || active ? Colors.white : Colors.white38;

          return Expanded(child: Row(children: [
            Expanded(child: Column(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? Colors.white
                      : active
                          ? Colors.white.withOpacity(.25)
                          : Colors.transparent,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(
                  done ? Icons.check_rounded : icon,
                  size: 15,
                  color: done ? _brand : color,
                ),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.ubuntu(
                      fontSize: 10, color: color,
                      fontWeight: FontWeight.w600)),
            ])),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: done ? Colors.white : Colors.white24,
                ),
              ),
          ]));
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP CARD
// ─────────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _StepCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _brand.withOpacity(.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: _brand),
          ),
          const SizedBox(width: 12),
          Text(title,
              style: GoogleFonts.ubuntu(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827))),
        ]),
        const SizedBox(height: 20),
        child,
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CREDENTIAL ROW (success screen)
// ─────────────────────────────────────────────────────────────
class _CredRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String rawValue;
  final bool large;
  final bool mono;

  const _CredRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.rawValue,
    this.large = false,
    this.mono  = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.white60),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.ubuntu(
                  fontSize: 10, color: Colors.white54,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: mono
                  ? const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.5)
                  : GoogleFonts.ubuntu(
                      fontSize: large ? 26 : 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: large ? 5 : 0)),
        ],
      )),
      // Individual copy button
      GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: rawValue));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$label copied!'),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.copy_rounded,
              size: 13, color: Colors.white),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// INFO ROW (payment step)
// ─────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: const Color(0xFFE2136E)),
      const SizedBox(width: 8),
      Expanded(child: RichText(
        text: TextSpan(
          style: GoogleFonts.ubuntu(
              fontSize: 12, color: const Color(0xFF9F1239)),
          children: [
            TextSpan(text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      )),
      if (copyable)
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('bKash number copied!'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 1),
            ));
          },
          child: const Icon(Icons.copy_rounded,
              size: 13, color: Color(0xFFE2136E)),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// REUSABLE FORM WIDGETS
// ─────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final int maxLines;
  final String? hint;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.maxLines = 1,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: GoogleFonts.ubuntu(
            fontSize: 14, color: const Color(0xFF111827)),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.ubuntu(fontSize: 13, color: _muted),
          prefixIcon: Icon(icon, size: 18, color: _muted),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
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
              borderSide: const BorderSide(color: _brand, width: 1.5)),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _DropdownField(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: (v) { if (v != null) onChanged(v); },
        items: items
            .map((i) => DropdownMenuItem(
                value: i,
                child: Text(i, style: GoogleFonts.ubuntu(fontSize: 14))))
            .toList(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.ubuntu(fontSize: 13, color: _muted),
          prefixIcon:
              const Icon(Icons.category_outlined, size: 18, color: _muted),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
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
              borderSide: const BorderSide(color: _brand, width: 1.5)),
        ),
        style: GoogleFonts.ubuntu(
            fontSize: 14, color: const Color(0xFF111827)),
        dropdownColor: _card,
        icon: const Icon(Icons.expand_more_rounded, color: _muted),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  const _PrimaryButton(
      {required this.label,
      this.icon,
      this.onTap,
      this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        icon: loading
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : (icon != null
                ? Icon(icon, size: 18)
                : const SizedBox.shrink()),
        label: Text(label,
            style: GoogleFonts.ubuntu(
                fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}
