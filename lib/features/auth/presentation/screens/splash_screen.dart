// lib/features/auth/presentation/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
    Navigator.of(context).pushReplacementNamed('/login');
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
        ],
      ),
    );
  }
}
