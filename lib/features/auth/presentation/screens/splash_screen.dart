import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:uddoygi/main.dart';

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
      // On web, skip video entirely — go straight to login immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToLogin());
    } else {
      _initVideo();
      // Fallback: always navigate after 4 seconds regardless of video state.
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
      ctrl.play();
      ctrl.addListener(() {
        if (ctrl.value.position >= ctrl.value.duration) {
          _goToLogin();
        }
      });
    } catch (_) {
      ctrl.dispose();
      // Video unavailable — fallback timer will handle navigation.
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
    // On web this renders briefly before the post-frame callback fires.
    if (kIsWeb) {
      return const Scaffold(
        backgroundColor: Color(0xFF065F46),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.business_center_rounded,
                  color: Colors.white, size: 56),
              SizedBox(height: 16),
              Text('Uddyogi',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              SizedBox(height: 8),
              Text('HR & Company Management',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 14)),
              SizedBox(height: 32),
              CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ],
          ),
        ),
      );
    }

    final ctrl = _controller;
    return Scaffold(
      backgroundColor: Colors.white,
      body: (ctrl != null && ctrl.value.isInitialized)
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: ctrl.value.size.width,
                  height: ctrl.value.size.height,
                  child: VideoPlayer(ctrl),
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
