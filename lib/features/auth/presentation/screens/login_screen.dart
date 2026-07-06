// lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/company_verification_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
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
      backgroundColor: error ? Colors.red : Colors.green,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Background Video ──────────────────────────────────────────────
          if (!kIsWeb && _videoCtrl != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.1, // Subtle video background
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
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      // ── Logo ──────────────────────────────────────────────
                      Image.asset('assets/icons/app_icon.png', width: 60, height: 60),
                      const SizedBox(height: 12),
                      Text('uddyogi', 
                        style: GoogleFonts.outfit(
                          fontSize: 28, 
                          fontWeight: FontWeight.w900, 
                          color: const Color(0xFF0F172A),
                          letterSpacing: -1
                        )
                      ),
                      const SizedBox(height: 48),

                      // ── Phase Switcher ─────────────────────────────────────
                      AnimatedSwitcher(
                        duration: 400.ms,
                        child: _phase == _Phase.companyId 
                          ? _buildCompanyIdCard() 
                          : _buildCredentialsCard(),
                      ),

                      const SizedBox(height: 48),
                      
                      // ── Social Logins ──────────────────────────────────────
                      Text('Or sign in with', 
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SocialIcon(icon: Icons.g_mobiledata_rounded, color: Colors.red),
                          const SizedBox(width: 24),
                          _SocialIcon(icon: Icons.facebook_rounded, color: Colors.blue.shade900),
                          const SizedBox(width: 24),
                          _SocialIcon(icon: Icons.flutter_dash_rounded, color: Colors.blue.shade400),
                        ],
                      ),
                      
                      const SizedBox(height: 48),
                      Text('Don\'t have an account? Sign up', 
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyIdCard() {
    return Column(
      key: const ValueKey('companyId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verify Company ID', 
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
        const SizedBox(height: 24),
        UInput(
          label: 'Company ID',
          hint: 'Enter your 8-digit ID',
          controller: _companyIdCtrl,
          keyboardType: TextInputType.number,
          maxLength: 8,
          prefixIcon: Icons.business_rounded,
        ),
        const SizedBox(height: 24),
        UButton(
          label: 'Continue',
          isFullWidth: true,
          isLoading: _fetchingCompany,
          onPressed: () => _fetchCompany(_companyIdCtrl.text),
          backgroundColor: const Color(0xFF1E3A8A),
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
            Expanded(
              child: Text('Login to your Account', 
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => setState(() => _phase = _Phase.companyId),
            ),
          ],
        ),
        const SizedBox(height: 24),
        UInput(
          label: 'Email',
          controller: _emailCtrl,
          prefixIcon: Icons.email_rounded,
        ),
        const SizedBox(height: 16),
        UInput(
          label: 'Password',
          controller: _passwordCtrl,
          obscureText: _obscure,
          prefixIcon: Icons.lock_rounded,
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: 24),
        UButton(
          label: 'Sign In',
          isFullWidth: true,
          isLoading: widget.loading,
          onPressed: _submitCredentials,
          backgroundColor: const Color(0xFF1E3A8A),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}
