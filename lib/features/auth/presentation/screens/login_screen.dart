// lib/features/auth/presentation/screens/login_screen.dart
//
// Multi-tenant login flow:
//   Phase 1 — Enter Company ID (pre-filled from local storage)
//             → fetch + show company logo & name from Firestore
//   Phase 2 — Enter email + password
//             → sign in → route by department
//
// Links: Register Company | Forgot Company ID
// ─────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/company_verification_service.dart';

const Color _brand = Color(0xFF2A0A4B); // app brand purple

// ─────────────────────────────────────────────────────────────
// PUBLIC API — same signature as before so main.dart compiles
// ─────────────────────────────────────────────────────────────
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

// ── Login phases ─────────────────────────────────────────────
enum _Phase { companyId, credentials }

// ── Company info fetched from Firestore ──────────────────────
// Re-export CompanyInfo from the service so the rest of the file
// can use _CompanyInfo as before.
typedef _CompanyInfo = CompanyInfo;

class _LoginScreenState extends State<LoginScreen>
    with WidgetsBindingObserver {
  // ── Phase ────────────────────────────────────────────────
  _Phase _phase = _Phase.companyId;

  // ── Company ID ───────────────────────────────────────────
  final _companyIdCtrl = TextEditingController();
  bool _fetchingCompany = false;
  _CompanyInfo? _company;

  // ── Credentials ──────────────────────────────────────────
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  // ── Video background (mobile only) ───────────────────────
  VideoPlayerController? _videoCtrl;
  Future<void>? _videoInit;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) _initVideo();
    _loadSavedCompanyId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/icons/app_icon.png'), context);
    });
  }

  Future<void> _loadSavedCompanyId() async {
    final saved = await LocalStorageService.getSavedCompanyId();
    if (saved != null && saved.isNotEmpty && mounted) {
      _companyIdCtrl.text = saved;
      // Auto-fetch company info if ID already saved
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
    _videoInit = ctrl
        .initialize()
        .then((_) async {
          await ctrl.setLooping(true);
          await ctrl.setVolume(0);
          await ctrl.play();
        })
        .catchError((_) {});
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

  // ── Verify Company ID via REST (bypasses Firestore rules) ──
  Future<void> _fetchCompany(String id) async {
    final trimmed = id.trim();
    setState(() => _fetchingCompany = true);
    try {
      final info = await CompanyVerificationService.lookup(trimmed);

      if (info == null) {
        _snack("Hmm, we don't recognise that Company ID. Could you double-check the 8-digit number?", error: true);
        setState(() { _fetchingCompany = false; _company = null; });
        return;
      }

      // Persist company ID locally so it pre-fills next time
      await LocalStorageService.saveCompanyId(trimmed);

      setState(() {
        _company          = info;
        _fetchingCompany  = false;
        _phase            = _Phase.credentials;
      });
    } on CompanyVerificationException catch (_) {
      _snack("We couldn't verify that Company ID right now. Please check the number and try again.", error: true);
      setState(() => _fetchingCompany = false);
    } catch (_) {
      _snack("Something went wrong on our end. Please check your connection and try again.", error: true);
      setState(() => _fetchingCompany = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submitCredentials() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _snack('Please enter email and password.', error: true);
      return;
    }
    widget.onLogin(email, password, _company!.companyId);
  }

  Future<void> _launchCall() async {
    final uri = Uri.parse('tel:+8801799499092');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  Widget _buildBackground() {
    if (kIsWeb) {
      // Clean gradient background for web — no video dependency.
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }

    final ctrl = _videoCtrl;
    return FutureBuilder<void>(
      future: _videoInit,
      builder: (_, __) {
        if (ctrl == null || !ctrl.value.isInitialized) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          );
        }
        final size = ctrl.value.size;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: _videoReady ? 1 : 0,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(ctrl),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── Background (video on mobile, gradient on web) ─
        Positioned.fill(child: _buildBackground()),

        // ── Login card ────────────────────────────────────
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _phase == _Phase.companyId
                      ? _buildCompanyIdCard()
                      : _buildCredentialsCard(),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Phase 1: Company ID card ──────────────────────────────
  Widget _buildCompanyIdCard() {
    return _LoginCard(
      key: const ValueKey('companyId'),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App logo + title
            _AppHeader(),
            const SizedBox(height: 18),

            // Company ID field
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(children: [
                Text('Enter Company ID',
                    style: GoogleFonts.ubuntu(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text('8-digit ID provided at registration',
                    style: GoogleFonts.ubuntu(
                        fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 14),
                TextField(
                  controller: _companyIdCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.ubuntu(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: _brand),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '• • • • • • • •',
                    hintStyle: GoogleFonts.ubuntu(
                        fontSize: 18,
                        color: Colors.black26,
                        letterSpacing: 4),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _brand, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _fetchingCompany
                        ? null
                        : () => _fetchCompany(_companyIdCtrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _fetchingCompany
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Continue',
                            style: GoogleFonts.ubuntu(
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // Links row
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _LinkButton(
                label: 'Register Company',
                onTap: () => Navigator.pushNamed(
                    context, '/register-company'),
              ),
              Text('  ·  ',
                  style: TextStyle(color: Colors.grey.shade500)),
              _LinkButton(
                label: 'Forgot Company ID?',
                onTap: () => Navigator.pushNamed(
                    context, '/forgot-company-id'),
              ),
            ]),
          ]),
    );
  }

  // ── Phase 2: Credentials card ─────────────────────────────
  Widget _buildCredentialsCard() {
    final loadingNow = widget.loading;
    return _LoginCard(
      key: const ValueKey('credentials'),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Company branding
            _CompanyHeader(company: _company!),
            const SizedBox(height: 16),

            // Credentials form
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(children: [
                _FrostedField(
                  controller: _emailCtrl,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboard: TextInputType.emailAddress,
                  darkMode: false,
                ),
                const SizedBox(height: 10),
                _FrostedField(
                  controller: _passwordCtrl,
                  label: 'Password',
                  icon: _obscure
                      ? Icons.lock_outline
                      : Icons.lock_open,
                  obscure: _obscure,
                  onIconTap: () =>
                      setState(() => _obscure = !_obscure),
                  darkMode: false,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loadingNow ? null : _submitCredentials,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 3,
                    ),
                    child: loadingNow
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Text('Sign In',
                            style: GoogleFonts.ubuntu(
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // Change company link
            _LinkButton(
              label: '← Change Company ID',
              onTap: () => setState(() {
                _phase = _Phase.companyId;
                _company = null;
              }),
            ),

            const SizedBox(height: 4),
            GestureDetector(
              onTap: _launchCall,
              child: Text(
                'অ্যাকাউন্ট নেই? যোগাযোগ করুন উদ্দোগী সার্ভিসেস-এর সাথে',
                textAlign: TextAlign.center,
                style: GoogleFonts.ubuntu(
                  color: _brand,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ),
          ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _LoginCard extends StatelessWidget {
  final Widget child;
  const _LoginCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(.08)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000),
              blurRadius: 14,
              offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: child,
    );
  }
}

class _AppHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.grey.shade200),
        child: const CircleAvatar(
          radius: 34,
          backgroundImage: AssetImage('assets/icons/app_icon.png'),
          backgroundColor: Colors.transparent,
        ),
      ),
      const SizedBox(height: 8),
      Text('উদ্যোগী',
          style: GoogleFonts.ubuntu(
              color: Colors.black,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
      Text('বহুবিভাগীয় কোম্পানি ব্যবস্থাপনার জন্য স্মার্ট ইআরপি সিস্টেম',
          textAlign: TextAlign.center,
          style: GoogleFonts.ubuntu(
              color: Colors.grey.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

class _CompanyHeader extends StatelessWidget {
  final _CompanyInfo company;
  const _CompanyHeader({required this.company});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Company logo
      Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipOval(
          child: company.logoUrl.isNotEmpty
              ? Image.network(company.logoUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.business_rounded,
                          size: 32, color: _brand))
              : const Icon(Icons.business_rounded,
                  size: 32, color: _brand),
        ),
      ),
      const SizedBox(height: 8),
      Text(company.name,
          textAlign: TextAlign.center,
          style: GoogleFonts.ubuntu(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87)),
      const SizedBox(height: 2),
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: _brand.withOpacity(.08),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text('ID: ${company.companyId}',
            style: GoogleFonts.ubuntu(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _brand,
                letterSpacing: 1)),
      ),
    ]);
  }
}

class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: GoogleFonts.ubuntu(
              color: _brand,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              decoration: TextDecoration.underline)),
    );
  }
}

// ── Frosted input field (unchanged from original) ─────────────
class _FrostedField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onIconTap;
  final TextInputType keyboard;
  final bool darkMode;

  const _FrostedField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.onIconTap,
    this.keyboard = TextInputType.text,
    this.darkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkMode ? Colors.white : Colors.black;
    final hintColor =
        darkMode ? Colors.white70 : Colors.grey.shade600;

    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: TextStyle(
          color: textColor, fontWeight: FontWeight.w600),
      cursorColor: textColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hintColor),
        filled: true,
        fillColor: darkMode
            ? Colors.white.withOpacity(0.10)
            : Colors.grey.shade100,
        prefixIcon: Icon(icon, color: textColor),
        suffixIcon: onIconTap == null
            ? null
            : IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: textColor.withOpacity(0.8),
                ),
                onPressed: onIconTap,
              ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: hintColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _brand, width: 1.2),
        ),
      ),
    );
  }
}
