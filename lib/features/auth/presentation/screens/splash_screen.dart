import 'dart:async';
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
    _initVideo();
    // Fallback: always navigate after 4 seconds regardless of video state
    Timer(const Duration(seconds: 4), _goToLogin);
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
      // Video unavailable — fallback timer will handle navigation
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
