// lib/services/app_rules_guard.dart
//
// AppRulesGuard — wraps any widget/screen with your app-level rule check.
// Works alongside Firebase rules: AppRules checks first, Firestore checks second.
//
// NAMED CONSTRUCTORS:
//
//   AppRulesGuard.collection(collection: 'invoices', child: InvoicePage())
//   AppRulesGuard.screen(screen: 'payroll', child: PayrollPage())
//   AppRulesGuard.role(roles: ['admin', 'hr'], child: SensitivePage())
//   AppRulesGuard.company(companyId: _cid, child: CompanyDataPage())
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_rules.dart';

class AppRulesGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  final bool Function() _check;

  const AppRulesGuard._({
    required this.child,
    required bool Function() check,
    this.fallback,
    super.key,
  }) : _check = check;

  // Guard by collection + permission
  factory AppRulesGuard.collection({
    required String collection,
    AppPermission permission = AppPermission.read,
    Widget? fallback,
    Key? key,
    required Widget child,
  }) =>
      AppRulesGuard._(
        key: key,
        fallback: fallback,
        check: () => AppRules.instance.can(collection, permission),
        child: child,
      );

  // Guard by screen name
  factory AppRulesGuard.screen({
    required String screen,
    Widget? fallback,
    Key? key,
    required Widget child,
  }) =>
      AppRulesGuard._(
        key: key,
        fallback: fallback,
        check: () => AppRules.instance.canAccessScreen(screen),
        child: child,
      );

  // Guard by role list
  factory AppRulesGuard.role({
    required List<String> roles,
    Widget? fallback,
    Key? key,
    required Widget child,
  }) =>
      AppRulesGuard._(
        key: key,
        fallback: fallback,
        check: () => roles.contains(AppRules.instance.role),
        child: child,
      );

  // Guard by company isolation
  factory AppRulesGuard.company({
    required String companyId,
    Widget? fallback,
    Key? key,
    required Widget child,
  }) =>
      AppRulesGuard._(
        key: key,
        fallback: fallback,
        check: () => AppRules.instance.belongsToCompany(companyId),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    if (_check()) return child;
    return fallback ?? _AccessDeniedPage(role: AppRules.instance.role);
  }
}

// ─────────────────────────────────────────────────────────────
// Default "access denied" UI shown when a guard blocks access
// ─────────────────────────────────────────────────────────────
class _AccessDeniedPage extends StatelessWidget {
  final String role;
  const _AccessDeniedPage({required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded,
                    size: 48, color: Colors.red.shade400),
              ),
              const SizedBox(height: 20),
              Text('Access Denied',
                  style: GoogleFonts.ubuntu(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              Text(
                'Your role${role.isNotEmpty ? ' ($role)' : ''} does not have\n'
                'permission to view this page.',
                textAlign: TextAlign.center,
                style: GoogleFonts.ubuntu(
                    fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text('Go Back',
                    style: GoogleFonts.ubuntu(fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2A0A4B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
