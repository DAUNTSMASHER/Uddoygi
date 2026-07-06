import 'package:flutter/material.dart';
import 'u_ai_assistant.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/navigation_service.dart';

class GlobalAiAssistant extends StatefulWidget {
  final Widget? child;
  const GlobalAiAssistant({super.key, this.child});

  @override
  State<GlobalAiAssistant> createState() => _GlobalAiAssistantState();
}

class _GlobalAiAssistantState extends State<GlobalAiAssistant> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() => _isLoggedIn = user != null);
      }
    });
    _isLoggedIn = FirebaseAuth.instance.currentUser != null;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          if (widget.child != null) widget.child!,
          if (_isLoggedIn) _AiFloatingButton(),
        ],
      ),
    );
  }
}

class _AiFloatingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: NavigationService.instance.currentRouteNotifier,
      builder: (context, route, _) {
        // Only hide on explicit Splash or Login screens
        if (route == '/' || route == '/login') {
          return const SizedBox.shrink();
        }

        return Positioned(
          right: 20,
          bottom: 20,
          child: GestureDetector(
            onTap: () => _showAssistant(context),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ],
                image: const DecorationImage(
                  image: AssetImage('assets/images/ai_assistant_icon.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ).animate()
           .scale(duration: 400.ms, curve: Curves.easeOutBack)
           .shimmer(delay: 3.seconds, duration: 2.seconds),
        );
      },
    );
  }

  void _showAssistant(BuildContext context) {
    final navContext = NavigationService.instance.navigatorKey.currentContext;
    if (navContext != null) {
      showModalBottomSheet(
        context: navContext,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const UAiAssistant(),
      );
    }
  }
}
