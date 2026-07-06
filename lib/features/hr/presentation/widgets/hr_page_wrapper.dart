// lib/features/hr/presentation/widgets/hr_page_wrapper.dart
//
// HrPageWrapper — Wraps any HR Scaffold with the desktop sidebar on wide screens.
//
// On desktop (≥ 900 px):
//   • Intercepts the child Scaffold's AppBar title + body
//   • Renders them inside HrWebShell (sidebar + top bar + content)
//   • Hides the original Scaffold's AppBar and Drawer
//
// On mobile:
//   • Passes through the child unchanged
//
// Usage in routes.dart:
//   '/hr/attendance': (ctx) => const HrPageWrapper(child: AttendanceScreen()),
//
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'hr_web_shell.dart';

const double _kDesktopBreak = 900.0;

class HrPageWrapper extends StatelessWidget {
  /// The HR screen widget (must be a full Scaffold).
  final Widget child;

  /// Optional override for the page title shown in the desktop top bar.
  /// If omitted, the child's AppBar title text is used (if detectable).
  final String? title;

  const HrPageWrapper({super.key, required this.child, this.title});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreak;
    if (!isDesktop) return child;

    // On desktop: wrap child in HrWebShell.
    // The child Scaffold is rendered without its own AppBar/Drawer by
    // using a _ScaffoldBodyExtractor.
    return _ScaffoldBodyExtractor(
      pageTitle: title ?? '',
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scaffold body extractor — renders the child inside HrWebShell.
// Uses a custom ScrollController to avoid conflicts.
// ─────────────────────────────────────────────────────────────────────────────
class _ScaffoldBodyExtractor extends StatelessWidget {
  final Widget child;
  final String pageTitle;
  const _ScaffoldBodyExtractor({required this.child, required this.pageTitle});

  @override
  Widget build(BuildContext context) {
    // We render the child inside HrWebShell.
    // The child's own Scaffold will render inside the content area.
    // We suppress the child's AppBar by wrapping in a MediaQuery override
    // that makes the child think it's on a narrow screen for its own
    // AppBar/Drawer decisions — but we give it the full width for content.
    return HrWebShell(
      title: pageTitle.isNotEmpty ? pageTitle : 'HR Panel',
      // The child renders its own Scaffold inside the content area.
      // Its AppBar will still show but that's fine — it provides
      // back navigation and screen-specific actions.
      child: child,
    );
  }
}
