// lib/features/admin/presentation/screens/smtp_settings_screen.dart
//
// SMTP / Email Server configuration screen.
//
// Saves credentials to Firestore at smtp_config/default (root-level, not
// company-scoped so the OTP service can read it before login).
//
// Free providers supported out-of-the-box:
//   • Gmail   — smtp.gmail.com:465  (needs App Password, not account password)
//   • Outlook — smtp.office365.com:587
//   • Yahoo   — smtp.mail.yahoo.com:465
//   • Custom  — any host/port the user specifies
//
// The "Test Connection" button sends a real test email to the admin's own
// address so they can confirm delivery before saving.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg      = Color(0xFFF5F3FF);
const _brand   = Color(0xFF2A0A4B);
const _accent  = Color(0xFF7C3AED);
const _card    = Color(0xFFFFFFFF);
const _success = Color(0xFF16A34A);
const _danger  = Color(0xFFDC2626);
const _muted   = Color(0xFF94A3B8);
const _fg      = Color(0xFF0F172A);
const _border  = Color(0xFFE5E7EB);

// ── Provider presets ──────────────────────────────────────────────────────────
class _Preset {
  final String name;
  final String icon;
  final String host;
  final int    port;
  final bool   ssl;
  final String hint; // password hint
  final String helpUrl;

  const _Preset({
    required this.name,
    required this.icon,
    required this.host,
    required this.port,
    required this.ssl,
    required this.hint,
    required this.helpUrl,
  });
}

const _presets = [
  _Preset(
    name: 'Gmail',
    icon: 'G',
    host: 'smtp.gmail.com',
    port: 465,
    ssl: true,
    hint: 'Use a Gmail App Password (not your account password)',
    helpUrl: 'https://myaccount.google.com/apppasswords',
  ),
  _Preset(
    name: 'Outlook / Microsoft 365',
    icon: 'O',
    host: 'smtp.office365.com',
    port: 587,
    ssl: false,
    hint: 'Use your Microsoft account password',
    helpUrl: 'https://support.microsoft.com/en-us/office/pop-imap-and-smtp-settings',
  ),
  _Preset(
    name: 'Yahoo Mail',
    icon: 'Y',
    host: 'smtp.mail.yahoo.com',
    port: 465,
    ssl: true,
    hint: 'Use a Yahoo App Password',
    helpUrl: 'https://help.yahoo.com/kb/generate-third-party-passwords-sln15241.html',
  ),
  _Preset(
    name: 'Custom SMTP',
    icon: '⚙',
    host: '',
    port: 587,
    ssl: false,
    hint: 'Enter your SMTP server credentials',
    helpUrl: '',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class SmtpSettingsScreen extends StatefulWidget {
  const SmtpSettingsScreen({super.key});

  @override
  State<SmtpSettingsScreen> createState() => _SmtpSettingsScreenState();
}

class _SmtpSettingsScreenState extends State<SmtpSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _hostCtl     = TextEditingController();
  final _portCtl     = TextEditingController();
  final _userCtl     = TextEditingController(); // login username (usually email)
  final _passCtl     = TextEditingController();
  final _fromCtl     = TextEditingController(); // "From" display email
  final _nameCtl     = TextEditingController(); // "From" display name

  bool _ssl          = true;
  bool _passVisible  = false;
  bool _loading      = true;   // initial load
  bool _saving       = false;
  bool _testing      = false;
  bool _saved        = false;

  _Preset? _selectedPreset;
  String?  _testResult;
  bool     _testOk   = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _hostCtl.dispose(); _portCtl.dispose(); _userCtl.dispose();
    _passCtl.dispose(); _fromCtl.dispose(); _nameCtl.dispose();
    super.dispose();
  }

  // ── Load existing config ──────────────────────────────────────────────────
  Future<void> _loadExisting() async {
    try {
      final snap = await DB.firestore
          .collection(C.smtpConfig)
          .doc('default')
          .get();
      if (snap.exists && mounted) {
        final d = snap.data()!;
        _hostCtl.text = (d['host']      as String?) ?? '';
        _portCtl.text = ((d['port']     as num?)?.toString()) ?? '587';
        _userCtl.text = (d['username']  as String?) ?? '';
        _passCtl.text = (d['password']  as String?) ?? '';
        _fromCtl.text = (d['fromEmail'] as String?) ?? '';
        _nameCtl.text = (d['fromName']  as String?) ?? 'Uddoygi ERP';
        _ssl          = (d['useSsl']    as bool?)   ?? true;
        // Try to match a preset
        for (final p in _presets) {
          if (p.host.isNotEmpty && p.host == _hostCtl.text) {
            _selectedPreset = p;
            break;
          }
        }
        _selectedPreset ??= _presets.last; // Custom
      } else {
        _portCtl.text = '587';
        _nameCtl.text = 'Uddoygi ERP';
      }
    } catch (_) {
      _portCtl.text = '587';
      _nameCtl.text = 'Uddoygi ERP';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Apply preset ──────────────────────────────────────────────────────────
  void _applyPreset(_Preset p) {
    setState(() {
      _selectedPreset = p;
      if (p.host.isNotEmpty) {
        _hostCtl.text = p.host;
        _portCtl.text = p.port.toString();
        _ssl          = p.ssl;
      }
      _saved      = false;
      _testResult = null;
    });
  }

  // ── Test connection ───────────────────────────────────────────────────────
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    final testTo = FirebaseAuth.instance.currentUser?.email ?? _userCtl.text.trim();

    setState(() { _testing = true; _testResult = null; });
    try {
      final server = SmtpServer(
        _hostCtl.text.trim(),
        port:     int.tryParse(_portCtl.text.trim()) ?? 587,
        ssl:      _ssl,
        username: _userCtl.text.trim(),
        password: _passCtl.text.trim(),
      );

      final from = _fromCtl.text.trim().isNotEmpty
          ? _fromCtl.text.trim()
          : _userCtl.text.trim();
      final name = _nameCtl.text.trim().isNotEmpty
          ? _nameCtl.text.trim()
          : 'Uddoygi ERP';

      final msg = Message()
        ..from       = Address(from, name)
        ..recipients = [testTo]
        ..subject    = 'Uddoygi ERP — SMTP Test'
        ..html       = _testEmailHtml(name);

      await send(msg, server);
      if (mounted) {
        setState(() {
          _testOk     = true;
          _testResult = 'Test email sent to $testTo. Check your inbox!';
        });
      }
    } on MailerException catch (e) {
      if (mounted) {
        setState(() {
          _testOk     = false;
          _testResult = _friendlySmtpError(e.message);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testOk     = false;
          _testResult = 'Connection failed: ${e.toString().split('\n').first}';
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  // ── Save to Firestore ─────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await DB.firestore.collection(C.smtpConfig).doc('default').set({
        'host':      _hostCtl.text.trim(),
        'port':      int.tryParse(_portCtl.text.trim()) ?? 587,
        'useSsl':    _ssl,
        'username':  _userCtl.text.trim(),
        'password':  _passCtl.text.trim(),
        'fromEmail': _fromCtl.text.trim().isNotEmpty
            ? _fromCtl.text.trim()
            : _userCtl.text.trim(),
        'fromName':  _nameCtl.text.trim().isNotEmpty
            ? _nameCtl.text.trim()
            : 'Uddoygi ERP',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() { _saved = true; _saving = false; });
        _snack('Email server settings saved successfully.', ok: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Could not save: $e');
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _snack(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: ok ? _success : _danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  static String _friendlySmtpError(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('535') || r.contains('authentication') || r.contains('credentials')) {
      return 'Wrong username or password. For Gmail, make sure you\'re using an App Password.';
    }
    if (r.contains('connection refused') || r.contains('connect')) {
      return 'Could not connect to the server. Check the host and port.';
    }
    if (r.contains('timeout')) {
      return 'Connection timed out. The server may be blocking this port.';
    }
    if (r.contains('certificate') || r.contains('ssl') || r.contains('tls')) {
      return 'SSL/TLS error. Try toggling the SSL switch or changing the port.';
    }
    return 'SMTP error: $raw';
  }

  static String _testEmailHtml(String appName) => '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family:Arial,sans-serif;background:#f5f5f5;padding:20px;">
  <div style="background:#fff;border-radius:12px;max-width:480px;margin:0 auto;
              padding:32px;box-shadow:0 2px 12px rgba(0,0,0,.08);">
    <div style="font-size:22px;font-weight:800;color:#2A0A4B;margin-bottom:8px;">
      $appName
    </div>
    <div style="font-size:16px;color:#374151;margin-bottom:20px;">
      SMTP Configuration Test
    </div>
    <p style="color:#374151;font-size:14px;line-height:1.6;">
      ✅ Your email server is configured correctly.<br>
      OTP emails and notifications will now be delivered to your employees.
    </p>
    <div style="margin-top:24px;padding:16px;background:#F0FDF4;border-radius:8px;
                border:1px solid #BBF7D0;">
      <strong style="color:#166534;">Everything looks good!</strong><br>
      <span style="color:#166534;font-size:13px;">
        You can now use OTP verification for employee onboarding and admin actions.
      </span>
    </div>
    <div style="font-size:12px;color:#9CA3AF;margin-top:24px;border-top:1px solid #E5E7EB;
                padding-top:16px;">
      This is an automated test message from Uddoygi ERP.
    </div>
  </div>
</body>
</html>
''';

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Email Server Setup',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brand, Color(0xFF6D28D9)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Info banner ──────────────────────────────────────
                  _InfoCard(
                    icon: Icons.info_outline_rounded,
                    color: _accent,
                    text: 'Set up a free email server to send OTP verification '
                        'codes to employees. Gmail and Outlook both work for free.',
                  ),
                  const SizedBox(height: 16),

                  // ── Provider selector ────────────────────────────────
                  _SectionLabel('Choose Email Provider'),
                  const SizedBox(height: 10),
                  _ProviderGrid(
                    presets:  _presets,
                    selected: _selectedPreset,
                    onSelect: _applyPreset,
                  ),
                  const SizedBox(height: 16),

                  // ── Provider help ────────────────────────────────────
                  if (_selectedPreset != null &&
                      _selectedPreset!.helpUrl.isNotEmpty) ...[
                    _HelpBanner(preset: _selectedPreset!),
                    const SizedBox(height: 16),
                  ],

                  // ── SMTP fields ──────────────────────────────────────
                  _SectionLabel('Server Settings'),
                  const SizedBox(height: 10),
                  _Card(
                    child: Column(children: [
                      // Host
                      _SmtpField(
                        label: 'SMTP Host',
                        hint: 'e.g. smtp.gmail.com',
                        controller: _hostCtl,
                        icon: Icons.dns_rounded,
                        onChanged: (_) => setState(() { _saved = false; _testResult = null; }),
                        validator: (v) => (v != null && v.trim().isNotEmpty)
                            ? null : 'Host is required',
                      ),
                      const SizedBox(height: 12),

                      // Port + SSL row
                      Row(children: [
                        Expanded(
                          flex: 2,
                          child: _SmtpField(
                            label: 'Port',
                            hint: '465 or 587',
                            controller: _portCtl,
                            icon: Icons.electrical_services_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState(() { _saved = false; _testResult = null; }),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return (n != null && n > 0) ? null : 'Valid port required';
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F7FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _border),
                            ),
                            child: Row(children: [
                              const Icon(Icons.lock_outline_rounded,
                                  size: 18, color: _muted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Use SSL/TLS',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _fg)),
                              ),
                              Switch.adaptive(
                                value: _ssl,
                                activeThumbColor: _accent,
                                activeTrackColor: _accent.withValues(alpha: 0.4),
                                onChanged: (v) => setState(() {
                                  _ssl = v;
                                  _saved = false;
                                  _testResult = null;
                                }),
                              ),
                            ]),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Username
                      _SmtpField(
                        label: 'Username (Email)',
                        hint: 'your@gmail.com',
                        controller: _userCtl,
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => setState(() { _saved = false; _testResult = null; }),
                        validator: (v) => (v != null && v.trim().isNotEmpty)
                            ? null : 'Username is required',
                      ),
                      const SizedBox(height: 12),

                      // Password
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Password / App Password',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _fg)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passCtl,
                            obscureText: !_passVisible,
                            style: GoogleFonts.inter(fontSize: 14, color: _fg),
                            onChanged: (_) => setState(() {
                              _saved = false; _testResult = null;
                            }),
                            validator: (v) => (v != null && v.trim().isNotEmpty)
                                ? null : 'Password is required',
                            decoration: InputDecoration(
                              hintText: _selectedPreset?.hint ?? 'SMTP password',
                              hintStyle: GoogleFonts.inter(
                                  color: _muted, fontSize: 13),
                              prefixIcon: const Icon(Icons.key_rounded,
                                  color: _muted, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18, color: _muted),
                                onPressed: () =>
                                    setState(() => _passVisible = !_passVisible),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F7FF),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: _border)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: _border)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: _accent, width: 1.5)),
                            ),
                          ),
                        ],
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── Sender identity ──────────────────────────────────
                  _SectionLabel('Sender Identity (optional)'),
                  const SizedBox(height: 10),
                  _Card(
                    child: Column(children: [
                      _SmtpField(
                        label: 'From Email',
                        hint: 'noreply@yourcompany.com (leave blank to use username)',
                        controller: _fromCtl,
                        icon: Icons.outgoing_mail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      _SmtpField(
                        label: 'From Name',
                        hint: 'Uddoygi ERP',
                        controller: _nameCtl,
                        icon: Icons.badge_outlined,
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── Test result ──────────────────────────────────────
                  if (_testResult != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (_testOk ? _success : _danger)
                            .withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_testOk ? _success : _danger)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _testOk
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            color: _testOk ? _success : _danger,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_testResult!,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: _testOk ? _success : _danger,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Action buttons ───────────────────────────────────
                  Row(children: [
                    // Test
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: _testing ? _muted : _accent, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: (_testing || _saving) ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _accent))
                            : const Icon(Icons.send_rounded,
                                size: 16, color: _accent),
                        label: Text(
                          _testing ? 'Testing…' : 'Test',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _testing ? _muted : _accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Save
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _saved ? _success : _brand,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: (_saving || _testing) ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Icon(
                                _saved
                                    ? Icons.check_rounded
                                    : Icons.save_rounded,
                                size: 16),
                        label: Text(
                          _saving
                              ? 'Saving…'
                              : (_saved ? 'Saved ✓' : 'Save Settings'),
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // ── Setup guide ──────────────────────────────────────
                  _SetupGuide(preset: _selectedPreset),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ── Provider grid ─────────────────────────────────────────────────────────────
class _ProviderGrid extends StatelessWidget {
  final List<_Preset> presets;
  final _Preset?      selected;
  final ValueChanged<_Preset> onSelect;

  const _ProviderGrid({
    required this.presets,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: presets.map((p) {
        final active = selected?.name == p.name;
        return GestureDetector(
          onTap: () => onSelect(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active ? _brand : _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: active ? _brand : _border, width: active ? 2 : 1),
              boxShadow: active
                  ? [BoxShadow(
                      color: _brand.withValues(alpha: 0.2),
                      blurRadius: 8, offset: const Offset(0, 3))]
                  : [],
            ),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.2)
                      : _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(p.icon,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : _accent)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.name.split(' ').first, // short name
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : _fg),
                ),
              ),
              if (active)
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: Colors.white),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ── Help banner ───────────────────────────────────────────────────────────────
class _HelpBanner extends StatelessWidget {
  final _Preset preset;
  const _HelpBanner({required this.preset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lightbulb_outline_rounded,
                size: 16, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Text('${preset.name} Setup Tip',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E))),
          ]),
          const SizedBox(height: 6),
          Text(preset.hint,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF92400E),
                  height: 1.4)),
          if (preset.helpUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              child: Text('Open setup guide →',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD97706),
                      decoration: TextDecoration.underline)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Setup guide ───────────────────────────────────────────────────────────────
class _SetupGuide extends StatelessWidget {
  final _Preset? preset;
  const _SetupGuide({this.preset});

  @override
  Widget build(BuildContext context) {
    final steps = preset?.name == 'Gmail'
        ? _gmailSteps
        : preset?.name.startsWith('Outlook') == true
            ? _outlookSteps
            : preset?.name == 'Yahoo Mail'
                ? _yahooSteps
                : _genericSteps;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.menu_book_rounded, size: 18, color: _accent),
            const SizedBox(width: 8),
            Text('Setup Guide',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _fg)),
          ]),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((e) => _StepRow(
                number: e.key + 1,
                text: e.value,
              )),
        ],
      ),
    );
  }

  static const _gmailSteps = [
    'Go to myaccount.google.com → Security → 2-Step Verification and enable it.',
    'Then go to myaccount.google.com/apppasswords.',
    'Select "Mail" as the app and "Other" as the device. Give it a name like "Uddoygi".',
    'Copy the 16-character App Password shown (no spaces).',
    'Paste it in the Password field above. Use your full Gmail address as the Username.',
    'Host: smtp.gmail.com  •  Port: 465  •  SSL: ON',
    'Tap "Test" to verify, then "Save Settings".',
  ];

  static const _outlookSteps = [
    'Use your full Microsoft/Outlook email address as the Username.',
    'Use your regular Microsoft account password.',
    'If you have 2FA enabled, create an App Password at account.microsoft.com/security.',
    'Host: smtp.office365.com  •  Port: 587  •  SSL: OFF (uses STARTTLS)',
    'Tap "Test" to verify, then "Save Settings".',
  ];

  static const _yahooSteps = [
    'Go to Yahoo Account Security and enable 2-Step Verification.',
    'Then generate an App Password for "Other App".',
    'Use your full Yahoo email address as the Username.',
    'Host: smtp.mail.yahoo.com  •  Port: 465  •  SSL: ON',
    'Tap "Test" to verify, then "Save Settings".',
  ];

  static const _genericSteps = [
    'Contact your email provider for SMTP host, port, and authentication details.',
    'Enter the SMTP host (e.g. mail.yourdomain.com) and port (usually 465 or 587).',
    'Enable SSL for port 465; disable it for port 587 (uses STARTTLS).',
    'Enter your email address as the Username and your email password.',
    'Tap "Test" to send a test email, then "Save Settings".',
  ];
}

class _StepRow extends StatelessWidget {
  final int    number;
  final String text;
  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$number',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _accent)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 13, color: _fg, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 4, height: 16,
      decoration: BoxDecoration(
          color: _accent, borderRadius: BorderRadius.circular(2)),
    ),
    const SizedBox(width: 8),
    Text(text,
        style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w800, color: _fg)),
  ]);
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: const [
        BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
      ],
    ),
    child: child,
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;
  const _InfoCard({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 13, color: color, height: 1.45)),
      ),
    ]),
  );
}

class _SmtpField extends StatelessWidget {
  final String                  label;
  final String                  hint;
  final TextEditingController   controller;
  final IconData                icon;
  final TextInputType?          keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>?   onChanged;

  const _SmtpField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: _fg)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          style: GoogleFonts.inter(fontSize: 14, color: _fg),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
            prefixIcon: Icon(icon, color: _muted, size: 18),
            filled: true,
            fillColor: const Color(0xFFF8F7FF),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _accent, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _danger)),
          ),
        ),
      ],
    );
  }
}
