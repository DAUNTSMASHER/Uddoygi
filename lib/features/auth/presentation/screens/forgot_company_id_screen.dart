// lib/features/auth/presentation/screens/forgot_company_id_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/email_otp_service.dart';
import 'package:uddoygi/services/company_verification_service.dart';
import 'package:uddoygi/widgets/u_button.dart';
import 'package:uddoygi/widgets/u_input.dart';
import 'package:uddoygi/widgets/u_card.dart';

const Color _brand   = Color(0xFF1E3A8A); // Premium Navy
const Color _accent  = Color(0xFF14B8A6); // Teal for buttons/links
const Color _bg      = Colors.white;
const Color _fg      = Color(0xFF0F172A);
const Color _muted   = Color(0xFF64748B);

enum _RecoveryStep { input, otpSent, verified }

class ForgotCompanyIdScreen extends StatefulWidget {
  const ForgotCompanyIdScreen({super.key});
  @override
  State<ForgotCompanyIdScreen> createState() => _ForgotCompanyIdScreenState();
}

class _ForgotCompanyIdScreenState extends State<ForgotCompanyIdScreen> {
  _RecoveryStep _step = _RecoveryStep.input;
  bool _busy = false;

  final _inputCtrl = TextEditingController();
  final _emailOtp  = EmailOtpService();
  final _otpCtrl   = TextEditingController();
  
  String _resolvedEmail = '';
  String _recoveredCompanyId   = '';
  String _recoveredCompanyName = '';

  @override
  void dispose() {
    _inputCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _lookup() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      _snack('Please enter your registered email.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final info = await CompanyVerificationService.queryByField(
        field: 'email',
        value: input.toLowerCase(),
      );

      if (info == null) {
        _snack("No company found linked to that email.", error: true);
        setState(() => _busy = false);
        return;
      }

      _recoveredCompanyId   = info.companyId;
      _recoveredCompanyName = info.name;
      _resolvedEmail = info.email.trim().toLowerCase();

      final sent = await _emailOtp.sendOtp(toEmail: _resolvedEmail, purpose: 'Company ID Recovery');
      if (sent) {
        _snack("Verification code sent to $_resolvedEmail");
        setState(() { _step = _RecoveryStep.otpSent; _busy = false; });
      } else {
        _snack("Failed to send OTP: ${_emailOtp.lastError}", error: true);
        setState(() => _busy = false);
      }
    } catch (e) {
      _snack("An error occurred. Please try again.", error: true);
      setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 6) {
      _snack('Please enter the 6-digit code.', error: true);
      return;
    }
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 800)); // Smooth transitions
    if (_emailOtp.verify(code)) {
      setState(() { _step = _RecoveryStep.verified; _busy = false; });
    } else {
      _snack("Invalid or expired OTP.", error: true);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _fg, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: AnimatedSwitcher(
            duration: 400.ms,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _RecoveryStep.input:   return _buildInputStep();
      case _RecoveryStep.otpSent: return _buildOtpStep();
      case _RecoveryStep.verified: return _buildSuccessStep();
    }
  }

  Widget _buildInputStep() {
    return Column(
      key: const ValueKey('input'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Recover\nCompany ID', 
          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: _fg, height: 1.1)),
        const SizedBox(height: 12),
        Text('Enter your registered email address to receive a recovery code.', 
          style: GoogleFonts.inter(fontSize: 14, color: _muted)),
        const SizedBox(height: 48),
        UInput(
          label: 'Email Address',
          controller: _inputCtrl,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_rounded,
        ),
        const SizedBox(height: 32),
        UButton(
          label: 'Send Code',
          isFullWidth: true,
          isLoading: _busy,
          onPressed: _lookup,
          backgroundColor: _brand,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Verify Code', 
          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: _fg)),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(fontSize: 14, color: _muted),
            children: [
              const TextSpan(text: 'Please enter the code we just sent to email\n'),
              TextSpan(text: _resolvedEmail, style: const TextStyle(color: _accent, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 48),
        
        // ── OTP Field ───────────────────────────────────────────────────
        UInput(
          label: 'Verification Code',
          hint: '000000',
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 12, color: _brand),
        ),
        
        const SizedBox(height: 32),
        UButton(
          label: 'Verify',
          isFullWidth: true,
          isLoading: _busy,
          onPressed: _verifyOtp,
          backgroundColor: _accent,
        ),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              Text('Didn\'t receive OTP?', style: GoogleFonts.inter(fontSize: 12, color: _muted)),
              TextButton(
                onPressed: _busy ? null : _lookup,
                child: Text('Resend code', style: GoogleFonts.inter(color: _accent, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_rounded, color: _accent, size: 80).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        Text('Account Verified', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: _fg)),
        const SizedBox(height: 12),
        Text('Here is your company identification information.', style: GoogleFonts.inter(fontSize: 14, color: _muted)),
        const SizedBox(height: 48),
        UCard(
          color: _brand.withOpacity(0.05),
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text(_recoveredCompanyName, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: _brand)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text(_recoveredCompanyId, 
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: _fg, letterSpacing: 4)),
              ),
              const SizedBox(height: 12),
              Text('COMPANY ID', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 2)),
            ],
          ),
        ),
        const SizedBox(height: 48),
        UButton(
          label: 'Back to Login',
          isFullWidth: true,
          onPressed: () => Navigator.pop(context),
          backgroundColor: _brand,
        ),
      ],
    ).animate().fadeIn();
  }
}
