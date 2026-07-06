// lib/services/email_otp_service.dart
//
// Email-based OTP service — completely free, no billing required.
//
// Uses the SMTP config stored in Firestore at smtp_config/default.
// Falls back to a visible on-screen code if SMTP is not configured.
//
// Usage:
//   final svc = EmailOtpService();
//   await svc.sendOtp(toEmail: 'admin@company.com', purpose: 'Data Reset');
//   final ok = svc.verify('123456');
// ─────────────────────────────────────────────────────────────
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:uddoygi/services/db.dart';

class EmailOtpService {
  // ── State ──────────────────────────────────────────────────
  String? _pendingOtp;
  String? _pendingEmail;
  DateTime? _expiresAt;

  static const _ttlMinutes = 10;

  // ── Public API ─────────────────────────────────────────────

  /// Generates a 6-digit OTP and sends it to [toEmail].
  /// Returns `true` on success, `false` on failure.
  /// On failure [lastError] contains the human-readable message.
  String? lastError;

  Future<bool> sendOtp({
    required String toEmail,
    String purpose = 'Verification',
    String appName  = 'Uddoygi ERP',
  }) async {
    lastError = null;
    if (toEmail.trim().isEmpty) {
      lastError = 'Email address is required.';
      return false;
    }

    // Generate OTP
    final otp = _generateOtp();
    _pendingOtp   = otp;
    _pendingEmail = toEmail.trim().toLowerCase();
    _expiresAt    = DateTime.now().add(const Duration(minutes: _ttlMinutes));

    // Build email body
    final subject = '$appName — $purpose OTP';
    final body    = _buildBody(otp: otp, purpose: purpose, appName: appName);

    // Try SMTP send
    try {
      final cfg = await _loadSmtpConfig();
      if (cfg == null) {
        // No SMTP configured — still "succeed" so the UI can show the code
        // in dev/test mode (the caller decides how to handle this)
        lastError = 'no_smtp';
        return false;
      }

      final server = SmtpServer(
        cfg['host'] as String,
        port:     (cfg['port'] as num).toInt(),
        ssl:      (cfg['useSsl'] as bool?) ?? true,
        username: cfg['username'] as String,
        password: cfg['password'] as String,
      );

      final fromEmail = (cfg['fromEmail'] as String?) ?? cfg['username'] as String;
      final fromName  = (cfg['fromName']  as String?) ?? appName;

      final message = Message()
        ..from       = Address(fromEmail, fromName)
        ..recipients = [toEmail.trim()]
        ..subject    = subject
        ..html       = body;

      await send(message, server);
      return true;
    } on MailerException catch (e) {
      lastError = 'SMTP error: ${e.message}';
      debugPrint('[EmailOtpService] MailerException: $e');
      return false;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[EmailOtpService] Error: $e');
      return false;
    }
  }

  /// Verifies the [code] entered by the user.
  /// Returns `true` if correct and not expired.
  bool verify(String code) {
    if (_pendingOtp == null) return false;
    if (_expiresAt != null && DateTime.now().isAfter(_expiresAt!)) {
      lastError = 'OTP has expired. Please request a new one.';
      _clear();
      return false;
    }
    final match = code.trim() == _pendingOtp;
    if (match) _clear();
    return match;
  }

  /// Whether an OTP has been sent and is still valid.
  bool get isActive =>
      _pendingOtp != null &&
      _expiresAt != null &&
      DateTime.now().isBefore(_expiresAt!);

  /// The email the OTP was sent to (for display).
  String? get sentToEmail => _pendingEmail;

  /// Remaining seconds before expiry.
  int get secondsRemaining {
    if (_expiresAt == null) return 0;
    final diff = _expiresAt!.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  void invalidate() => _clear();

  // ── Private helpers ────────────────────────────────────────

  String _generateOtp() {
    final rng = Random.secure();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }

  void _clear() {
    _pendingOtp   = null;
    _pendingEmail = null;
    _expiresAt    = null;
  }

  /// Sends a fully custom HTML email (not an OTP).
  /// Returns `true` on success.
  Future<bool> sendEmail({
    required String toEmail,
    required String subject,
    required String htmlBody,
  }) async {
    lastError = null;
    try {
      final cfg = await _loadSmtpConfig();
      if (cfg == null) {
        lastError = 'no_smtp';
        return false;
      }

      final server = SmtpServer(
        cfg['host'] as String,
        port:     (cfg['port'] as num).toInt(),
        ssl:      (cfg['useSsl'] as bool?) ?? true,
        username: cfg['username'] as String,
        password: cfg['password'] as String,
      );

      final fromEmail = (cfg['fromEmail'] as String?) ?? cfg['username'] as String;
      final fromName  = (cfg['fromName']  as String?) ?? 'Uddoygi ERP';

      final message = Message()
        ..from       = Address(fromEmail, fromName)
        ..recipients = [toEmail.trim()]
        ..subject    = subject
        ..html       = htmlBody;

      await send(message, server);
      return true;
    } on MailerException catch (e) {
      lastError = 'SMTP error: ${e.message}';
      debugPrint('[EmailOtpService] MailerException: $e');
      return false;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[EmailOtpService] Error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _loadSmtpConfig() async {
    try {
      final snap = await DB.firestore
          .collection(C.smtpConfig)
          .doc('default')
          .get();
      if (!snap.exists) return null;
      final d = snap.data()!;
      // Validate required fields
      if ((d['host'] as String?)?.isNotEmpty != true) return null;
      if ((d['username'] as String?)?.isNotEmpty != true) return null;
      if ((d['password'] as String?)?.isNotEmpty != true) return null;
      return d;
    } catch (e) {
      debugPrint('[EmailOtpService] Failed to load SMTP config: $e');
      return null;
    }
  }

  String _buildBody({
    required String otp,
    required String purpose,
    required String appName,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
    .card { background: #fff; border-radius: 12px; max-width: 480px; margin: 0 auto;
            padding: 32px; box-shadow: 0 2px 12px rgba(0,0,0,.08); }
    .logo { font-size: 22px; font-weight: 800; color: #2A0A4B; margin-bottom: 8px; }
    .title { font-size: 16px; color: #374151; margin-bottom: 24px; }
    .otp-box { background: #F7F4FF; border: 2px dashed #5C2EA0; border-radius: 10px;
               text-align: center; padding: 20px; margin: 24px 0; }
    .otp { font-size: 40px; font-weight: 900; letter-spacing: 12px; color: #2A0A4B; }
    .expiry { font-size: 13px; color: #6B7280; text-align: center; margin-top: 4px; }
    .footer { font-size: 12px; color: #9CA3AF; margin-top: 28px; border-top: 1px solid #E5E7EB;
              padding-top: 16px; }
    .warning { background: #FEF3C7; border-radius: 8px; padding: 12px 16px;
               font-size: 13px; color: #92400E; margin-top: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">$appName</div>
    <div class="title">$purpose — One-Time Password</div>

    <p style="color:#374151;font-size:14px;">
      You requested a verification code for <strong>$purpose</strong>.
      Use the code below to proceed:
    </p>

    <div class="otp-box">
      <div class="otp">$otp</div>
      <div class="expiry">Valid for $_ttlMinutes minutes</div>
    </div>

    <div class="warning">
      ⚠️ Never share this code with anyone. $appName staff will never ask for it.
    </div>

    <div class="footer">
      If you did not request this, please ignore this email.<br>
      This is an automated message — do not reply.
    </div>
  </div>
</body>
</html>
''';
  }
}
