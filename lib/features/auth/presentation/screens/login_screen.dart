// lib/features/auth/presentation/screens/login_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/company_verification_service.dart';
import 'package:uddoygi/services/language_service.dart';
import 'package:uddoygi/widgets/u_button.dart';
import 'package:uddoygi/widgets/u_input.dart';

class LoginScreen extends StatefulWidget {
  final bool loading;
  final Function(String email, String password, String companyId) onLogin;

  const LoginScreen({
    super.key,
    required this.loading,
    required this.onLogin,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Phase { companyId, credentials }

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  _Phase _phase = _Phase.companyId;

  final _companyIdCtrl = TextEditingController();
  bool _fetchingCompany = false;
  CompanyInfo? _company;

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  VideoPlayerController? _videoCtrl;
  Future<void>? _videoInit;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) _initVideo();
    _loadSavedCompanyId();
  }

  Future<void> _loadSavedCompanyId() async {
    final saved = await LocalStorageService.getSavedCompanyId();
    if (saved != null && saved.isNotEmpty && mounted) {
      _companyIdCtrl.text = saved;
      await _fetchCompany(saved);
    }
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.asset(
      'assets/videos/login_bg.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    ctrl.addListener(() {
      if (mounted && ctrl.value.isInitialized && !_videoReady) {
        setState(() => _videoReady = true);
      }
    });
    _videoCtrl = ctrl;
    _videoInit = ctrl.initialize().then((_) async {
      await ctrl.setLooping(true);
      await ctrl.setVolume(0);
      await ctrl.play();
    }).catchError((_) {});
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _videoCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.paused) {
      ctrl.pause();
    } else if (state == AppLifecycleState.resumed) {
      ctrl.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoCtrl?.dispose();
    _companyIdCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCompany(String id) async {
    final trimmed = id.trim();
    if (trimmed.length < 4) return;
    setState(() => _fetchingCompany = true);
    try {
      final info = await CompanyVerificationService.lookup(trimmed);
      if (info == null) {
        _snack("Company ID not recognized.", error: true);
        setState(() { _fetchingCompany = false; _company = null; });
        return;
      }
      await LocalStorageService.saveCompanyId(trimmed);
      setState(() {
        _company = info;
        _fetchingCompany = false;
        _phase = _Phase.credentials;
      });
    } catch (_) {
      _snack("Verification failed.", error: true);
      setState(() => _fetchingCompany = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _submitCredentials() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _snack('Please enter email and password.', error: true);
      return;
    }
    widget.onLogin(email, password, _company!.companyId);
  }

  void _fillDemo(String email, String password, String companyId) {
    _companyIdCtrl.text = companyId;
    _fetchCompany(companyId).then((_) {
      _emailCtrl.text = email;
      _passwordCtrl.text = password;
      _submitCredentials();
    });
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1B4B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('পছন্দের ভাষা নির্বাচন করুন', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 2),
            Text('Choose your preferred language', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 24),
            _LangOption(
              code: 'bn',
              label: 'বাংলা',
              subtitle: 'Bangla',
              icon: Icons.translate_rounded,
              isSelected: LanguageService.instance.isBangla,
              onTap: () {
                LanguageService.instance.setLanguage('bn');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _LangOption(
              code: 'en',
              label: 'English',
              subtitle: 'ইংরেজি',
              icon: Icons.text_fields_rounded,
              isSelected: !LanguageService.instance.isBangla,
              onTap: () {
                LanguageService.instance.setLanguage('en');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Rich Premium Gradient Background ──────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E1B4B),
                  Color(0xFF311042),
                ],
              ),
            ),
          ),
          
          // ── Background Video Overlay ──────────────────────────────────────
          if (!kIsWeb && _videoCtrl != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoCtrl!.value.size.width,
                    height: _videoCtrl!.value.size.height,
                    child: VideoPlayer(_videoCtrl!),
                  ),
                ),
              ),
            ),
          
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Language Toggle ─────────────────────────────────────
                      Align(
                        alignment: Alignment.centerRight,
                        child: ValueListenableBuilder<Locale>(
                          valueListenable: LanguageService.instance.locale,
                          builder: (_, locale, __) => Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showLanguagePicker(),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.language_rounded, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                                    const SizedBox(width: 6),
                                    Text(locale.languageCode == 'bn' ? 'বাংলা' : 'English', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                                    const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.white70),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ── Brand Header ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20),
                          ],
                        ),
                        child: Image.asset('assets/icons/app_icon.png', width: 64, height: 64),
                      ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 16),
                      Text('UDDYOGI', 
                        style: GoogleFonts.outfit(
                          fontSize: 32, 
                          fontWeight: FontWeight.w900, 
                          color: Colors.white,
                          letterSpacing: 2
                        )
                      ).animate().fadeIn(delay: 200.ms),
                      Text('Enterprise Management Portal', 
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 0.5)
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 36),

                      // ── The Login Card Div Container ────────────────────────
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            AnimatedSwitcher(
                              duration: 400.ms,
                              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim), child: child)),
                              child: _phase == _Phase.companyId 
                                ? _buildCompanyIdCard() 
                                : _buildCredentialsCard(),
                            ),
                            const SizedBox(height: 32),
                            
                            // ── Divider ─────────────────────────────────────────
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.2))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('Or continue with', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                                ),
                                Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.2))),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // ── Social Logins ───────────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SocialIcon(icon: Icons.g_mobiledata_rounded, color: const Color(0xFFEA4335)),
                                const SizedBox(width: 16),
                                _SocialIcon(icon: Icons.facebook_rounded, color: const Color(0xFF1877F2)),
                                const SizedBox(width: 16),
                                _SocialIcon(icon: Icons.business_center_rounded, color: const Color(0xFF0A66C2)),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
                      
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Need enterprise assistance?', style: GoogleFonts.outfit(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                          TextButton(
                            onPressed: () {},
                            child: Text('Contact Support', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF60A5FA))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Demo Access ──────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          children: [
                            Text('ডেমো অ্যাক্সেস (Demo Access)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
                            const SizedBox(height: 2),
                            Text('Company ID: 12345678', style: GoogleFonts.outfit(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _DemoChip(label: 'Admin', email: 'admin@uddoygi.com', companyId: '12345678', password: 'admin123', onTap: _fillDemo),
                                const SizedBox(width: 6),
                                _DemoChip(label: 'HR', email: 'hr@uddoygi.com', companyId: '12345678', password: 'hr123', onTap: _fillDemo),
                                const SizedBox(width: 6),
                                _DemoChip(label: 'Factory', email: 'factory@uddoygi.com', companyId: '12345678', password: 'factory123', onTap: _fillDemo),
                                const SizedBox(width: 6),
                                _DemoChip(label: 'Marketing', email: 'marketing@uddoygi.com', companyId: '12345678', password: 'marketing123', onTap: _fillDemo),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 500.ms),
                    ],
                  ),
                ),  // ConstrainedBox
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),  // SingleChildScrollView
            ),  // Center
          ],  // inner Stack children
        ),  // inner Stack
      ),  // SafeArea
    ],  // outer Stack children
  ),  // outer Stack
);
  }

  Widget _buildCompanyIdCard() {
    return Column(
      key: const ValueKey('companyId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.business_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Company Verification', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                  Text('Enter your organizational code', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        UInput(
          label: 'Company ID',
          hint: 'Enter your 8-digit ID',
          controller: _companyIdCtrl,
          keyboardType: TextInputType.number,
          maxLength: 8,
          prefixIcon: Icons.qr_code_rounded,
        ),
        const SizedBox(height: 24),
        UButton(
          label: 'Verify & Continue',
          isFullWidth: true,
          isLoading: _fetchingCompany,
          onPressed: () => _fetchCompany(_companyIdCtrl.text),
          backgroundColor: const Color(0xFF2563EB),
        ),
      ],
    );
  }

  Widget _buildCredentialsCard() {
    return Column(
      key: const ValueKey('credentials'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome Back', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                  Text(_company?.name ?? 'Secure Enterprise Login', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF10B981), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
              ),
              onPressed: () => setState(() => _phase = _Phase.companyId),
            ),
          ],
        ),
        const SizedBox(height: 24),
        UInput(
          label: 'Work Email',
          hint: 'name@company.com',
          controller: _emailCtrl,
          prefixIcon: Icons.alternate_email_rounded,
        ),
        const SizedBox(height: 16),
        UInput(
          label: 'Password',
          hint: '••••••••',
          controller: _passwordCtrl,
          obscureText: _obscure,
          prefixIcon: Icons.lock_outline_rounded,
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: Text('Forgot Password?', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
          ),
        ),
        const SizedBox(height: 16),
        UButton(
          label: 'Sign In to Portal',
          isFullWidth: true,
          isLoading: widget.loading,
          onPressed: _submitCredentials,
          backgroundColor: const Color(0xFF2563EB),
        ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _SocialIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  final String label;
  final String email;
  final String companyId;
  final String password;
  final void Function(String, String, String) onTap;
  const _DemoChip({required this.label, required this.email, required this.companyId, required this.password, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(email, password, companyId),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _themeColor().withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _themeColor().withValues(alpha: 0.4)),
        ),
        child: Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: _themeColor())),
      ),
    );
  }

  Color _themeColor() {
    switch (label.toLowerCase()) {
      case 'admin': return const Color(0xFF311042);
      case 'hr': return const Color(0xFF0A4128);
      case 'factory': return const Color(0xFF8B0000);
      case 'marketing': return const Color(0xFF0D47A1);
      default: return const Color(0xFF2563EB);
    }
  }
}

class _LangOption extends StatelessWidget {
  final String code;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _LangOption({required this.code, required this.label, required this.subtitle, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? const Color(0xFF2563EB) : Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isSelected ? const Color(0xFF60A5FA) : Colors.white70, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60)),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
