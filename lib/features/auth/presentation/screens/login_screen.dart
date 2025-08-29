// lib/features/auth/presentation/screens/login_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:uddoygi/services/local_storage_service.dart';

const Color _brand = Color(0xFF0D47A1);

class LoginScreen extends StatefulWidget {
  final bool loading;
  final Function(String, String) onLogin;

  const LoginScreen({
    super.key,
    required this.loading,
    required this.onLogin,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  // form
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  // video
  late final VideoPlayerController _videoCtrl;
  Future<void>? _videoInit;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Background video (looping + muted)
    _videoCtrl = VideoPlayerController.asset(
      'assets/videos/login_bg.mp4',
      // NOTE: DO NOT mark as const — not a const constructor on some SDKs
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..addListener(() {
      if (mounted && _videoCtrl.value.isInitialized && !_videoReady) {
        setState(() => _videoReady = true);
      }
    });

    _videoInit = _initVideo();

    // Precache the logo after the first frame to avoid context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/icons/app_icon.png'), context);
    });
  }

  Future<void> _initVideo() async {
    try {
      await _videoCtrl.initialize();
      await _videoCtrl.setLooping(true);
      await _videoCtrl.setVolume(0);
      await _videoCtrl.play();
    } catch (_) {
      // If playback fails, gradient fallback will be shown
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_videoCtrl.value.isInitialized) return;
    if (state == AppLifecycleState.paused) {
      _videoCtrl.pause();
    } else if (state == AppLifecycleState.resumed) {
      _videoCtrl.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = cred.user;

      if (user != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final role = snap.data()?['role'] ?? 'unknown';
        await LocalStorageService.saveSession(user.uid, email, role);
        widget.onLogin(email, password);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: ${e.message}")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchCall() async {
    const phone = 'tel:+8801799499092';
    final uri = Uri.parse(phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch phone dialer")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadingNow = widget.loading || _isLoading;

    return Scaffold(
      backgroundColor: Colors.black, // fallback behind video
      body: Stack(
        children: [
          // --------- FULLSCREEN VIDEO BG ---------
          Positioned.fill(
            child: FutureBuilder<void>(
              future: _videoInit,
              builder: (context, snap) {
                if (!_videoCtrl.value.isInitialized) {
                  // Graceful fallback gradient
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
                final size = _videoCtrl.value.size;
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _videoReady ? 1 : 0,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: VideoPlayer(_videoCtrl),
                    ),
                  ),
                );
              },
            ),
          ),

          // --------- CENTERED SECTION PANEL (only this has opacity) ---------
          // This sits in the middle area and does NOT change the whole video.
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 400,
                    maxHeight: 550,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white, // white background
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo + title
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                          ),
                          child: const CircleAvatar(
                            radius: 36,
                            backgroundImage: AssetImage('assets/icons/app_icon.png'),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "উদ্যোগী",
                          style: TextStyle(
                            color: Colors.black, // black text now
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          "বহুবিভাগীয় কোম্পানি ব্যবস্থাপনার জন্য স্মার্ট ইআরপি সিস্টেম",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Glass card replaced with simple white inner box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              _FrostedField(
                                controller: _emailController,
                                label: 'Email',
                                icon: Icons.email_outlined,
                                keyboard: TextInputType.emailAddress,
                                darkMode: false, // 👈 new param for white theme
                              ),
                              const SizedBox(height: 10),

                              _FrostedField(
                                controller: _passwordController,
                                label: 'Password',
                                icon: _obscure ? Icons.lock_outline : Icons.lock_open,
                                obscure: _obscure,
                                onIconTap: () => setState(() => _obscure = !_obscure),
                                darkMode: false,
                              ),
                              const SizedBox(height: 12),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: loadingNow ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _brand, // brand color
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 3,
                                  ),
                                  child: loadingNow
                                      ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                      : const Text(
                                    "Sign In",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        GestureDetector(
                          onTap: _launchCall,
                          child: Text(
                            "অ্যাকাউন্ট নেই? যোগাযোগ করুন উদ্দোগী সার্ভিসেস-এর সাথে",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _brand,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )

        ],
      ),
    );
  }
}

/* ---------- Frosted input field ---------- */
class _FrostedField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onIconTap;
  final TextInputType keyboard;
  final bool darkMode; // 👈 new

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
    final hintColor = darkMode ? Colors.white70 : Colors.grey.shade600;

    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      cursorColor: textColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hintColor),
        filled: true,
        fillColor: darkMode ? Colors.white.withOpacity(0.10) : Colors.grey.shade100,
        prefixIcon: Icon(icon, color: textColor),
        suffixIcon: onIconTap == null
            ? null
            : IconButton(
          icon: Icon(
            obscure ? Icons.visibility : Icons.visibility_off,
            color: textColor.withOpacity(0.8),
          ),
          onPressed: onIconTap,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: hintColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _brand, width: 1.2),
        ),
      ),
    );
  }
}

