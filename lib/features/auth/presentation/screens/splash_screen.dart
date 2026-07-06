// lib/features/auth/presentation/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:uddoygi/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToLogin());
    } else {
      _initVideo();
      Timer(const Duration(seconds: 4), _goToLogin);
    }
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.asset('assets/videos/app_loader.mp4');
    try {
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() => _controller = ctrl);
      ctrl.setLooping(true);
      ctrl.play();
    } catch (_) {
      ctrl.dispose();
    }
  }

  void _goToLogin() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreenWrapper()),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // ── Video Background ──────────────────────────────────────────────
          if (_controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
          
          // ── Dark Overlay ──────────────────────────────────────────────────
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4))),

          // ── Centered Content ──────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 20))
                    ],
                  ),
                  child: Image.asset('assets/icons/app_icon.png', width: 80, height: 80),
                ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack).fadeIn(),
                
                const SizedBox(height: 32),
                
                Text('uddyogi', 
                  style: GoogleFonts.outfit(
                    color: Colors.white, 
                    fontSize: 48, 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: -2
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 8),
                
                Text('PREMIUM ERP SOLUTIONS', 
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.6), 
                    fontSize: 12, 
                    fontWeight: FontWeight.w700, 
                    letterSpacing: 4
                  ),
                ).animate().fadeIn(delay: 600.ms),
              ],
            ),
          ),

          // ── Bottom Progress ───────────────────────────────────────────────
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: const Center(
              child: SizedBox(
                width: 40, height: 40,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ).animate().fadeIn(delay: 1.seconds),
          ),
        ],
      ),
    );
  }
}
