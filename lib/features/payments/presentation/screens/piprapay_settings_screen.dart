// lib/features/payments/presentation/screens/piprapay_settings_screen.dart
//
// PipraPay integration settings for the company owner.
// API keys are NEVER stored here — only the backend URL is stored.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../data/piprapay_repository.dart';
import '../../domain/models/payment_settings_model.dart';

const Color _brand    = Color(0xFF4F46E5);
const Color _brandMid = Color(0xFF6366F1);
const Color _surface  = Color(0xFFF5F3FF);
const Color _green    = Color(0xFF059669);
const Color _red      = Color(0xFFDC2626);
const Color _amber    = Color(0xFFD97706);

class PipraPaySettingsScreen extends StatefulWidget {
  final String cid;
  const PipraPaySettingsScreen({super.key, required this.cid});
  @override
  State<PipraPaySettingsScreen> createState() => _PipraPaySettingsScreenState();
}

class _PipraPaySettingsScreenState extends State<PipraPaySettingsScreen> {
  late final PipraPayRepository _repo;

  final _backendCtl     = TextEditingController();
  final _redirectCtl    = TextEditingController();
  final _cancelCtl      = TextEditingController();
  final _webhookCtl     = TextEditingController();
  final _currencyCtl    = TextEditingController(text: 'BDT');

  bool _enabled     = false;
  bool _sandbox     = true;
  bool _saving      = false;
  bool _testing     = false;
  String _connStatus = 'disconnected';

  @override
  void initState() {
    super.initState();
    _repo = PipraPayRepository(cid: widget.cid);
    _load();
  }

  @override
  void dispose() {
    _backendCtl.dispose();
    _redirectCtl.dispose();
    _cancelCtl.dispose();
    _webhookCtl.dispose();
    _currencyCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await _repo.getSettings();
    if (!mounted) return;
    setState(() {
      _enabled     = s.enabled;
      _sandbox     = s.sandboxMode;
      _connStatus  = s.connectionStatus;
      _backendCtl.text  = s.backendBaseUrl;
      _redirectCtl.text = s.defaultRedirectUrl;
      _cancelCtl.text   = s.defaultCancelUrl;
      _webhookCtl.text  = s.defaultWebhookUrl;
      _currencyCtl.text = s.currency.isEmpty ? 'BDT' : s.currency;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.saveSettings(PaymentSettingsModel(
        enabled:            _enabled,
        sandboxMode:        _sandbox,
        backendBaseUrl:     _backendCtl.text.trim(),
        currency:           _currencyCtl.text.trim().toUpperCase(),
        defaultRedirectUrl: _redirectCtl.text.trim(),
        defaultCancelUrl:   _cancelCtl.text.trim(),
        defaultWebhookUrl:  _webhookCtl.text.trim(),
        connectionStatus:   _connStatus,
      ));
      _snack('Settings saved ✅');
    } catch (e) {
      _snack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      final ok = await _repo.testConnection(_backendCtl.text.trim());
      if (!mounted) return;
      setState(() => _connStatus = ok ? 'connected' : 'disconnected');
      _snack(ok ? 'Backend connected ✅' : 'Could not reach backend ❌',
          error: !ok);
    } catch (e) {
      _snack('Test failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _red : _brand,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final connColor = _connStatus == 'connected' ? _green : _red;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brand, _brandMid],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: const Text('PipraPay Settings',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── Security notice ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.08),
              border: Border.all(color: _amber.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.security_rounded, color: _amber, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Your PipraPay API key is stored securely on your backend server — never in this app.',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _amber),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Enable / Sandbox toggles ──────────────────────────────────
          _SectionCard(
            child: Column(children: [
              _ToggleRow(
                icon: Icons.power_settings_new_rounded,
                label: 'Enable PipraPay',
                sub: 'Allow payment processing via PipraPay',
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                activeColor: _brand,
              ),
              const Divider(height: 1),
              _ToggleRow(
                icon: Icons.science_rounded,
                label: 'Sandbox Mode',
                sub: 'Use sandbox.piprapay.com for testing',
                value: _sandbox,
                onChanged: (v) => setState(() => _sandbox = v),
                activeColor: _amber,
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Backend URL ───────────────────────────────────────────────
          _SectionHeader(
              icon: Icons.dns_rounded,
              title: 'Backend Configuration',
              color: _brand),
          const SizedBox(height: 10),

          _SectionCard(
            child: Column(children: [
              _Field(
                controller: _backendCtl,
                label: 'Backend Base URL',
                hint: 'https://api.yourserver.com',
                icon: Icons.link_rounded,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brand,
                      side: const BorderSide(color: _brand),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _testing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _brand))
                        : const Icon(Icons.wifi_tethering_rounded, size: 16),
                    label: Text(_testing ? 'Testing…' : 'Test Connection'),
                    onPressed: _testing ? null : _testConnection,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: connColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: connColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: connColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _connStatus == 'connected'
                          ? 'Connected'
                          : 'Not Connected',
                      style: TextStyle(
                          color: connColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          // ── URL configuration ─────────────────────────────────────────
          _SectionHeader(
              icon: Icons.language_rounded,
              title: 'Default URLs',
              color: const Color(0xFF0891B2)),
          const SizedBox(height: 10),

          _SectionCard(
            child: Column(children: [
              _Field(
                controller: _redirectCtl,
                label: 'Redirect URL (after payment)',
                hint: 'https://yourapp.com/payment/success',
                icon: Icons.open_in_new_rounded,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _cancelCtl,
                label: 'Cancel URL',
                hint: 'https://yourapp.com/payment/cancel',
                icon: Icons.cancel_outlined,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _webhookCtl,
                label: 'Webhook URL',
                hint: 'https://yourserver.com/api/piprapay/webhook',
                icon: Icons.webhook_rounded,
                keyboardType: TextInputType.url,
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Currency ──────────────────────────────────────────────────
          _SectionHeader(
              icon: Icons.currency_exchange_rounded,
              title: 'Currency',
              color: const Color(0xFF7C3AED)),
          const SizedBox(height: 10),

          _SectionCard(
            child: _Field(
              controller: _currencyCtl,
              label: 'Default Currency',
              hint: 'BDT',
              icon: Icons.attach_money_rounded,
            ),
          ),

          const SizedBox(height: 24),

          // ── Save button ───────────────────────────────────────────────
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving…' : 'Save Settings',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            onPressed: _saving ? null : _save,
          ),

          const SizedBox(height: 16),

          // ── Info card ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Colors.black45),
                  SizedBox(width: 6),
                  Text('How to activate PipraPay',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.black54)),
                ]),
                const SizedBox(height: 8),
                ...[
                  '1. Deploy the Node.js backend (see piprapay-backend/ folder)',
                  '2. Add PIPRAPAY_API_KEY to your backend .env file',
                  '3. Enter your backend URL above and test the connection',
                  '4. Set your redirect, cancel, and webhook URLs',
                  '5. Toggle "Enable PipraPay" and save',
                ].map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(s,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45)),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Color    color;
  const _SectionHeader(
      {required this.icon, required this.title, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color)),
      ]);
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   sub;
  final bool     value;
  final ValueChanged<bool> onChanged;
  final Color    activeColor;
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon,
              color: value ? activeColor : Colors.black26, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeColor,
            activeTrackColor: activeColor.withValues(alpha: 0.4),
          ),
        ]),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final String                hint;
  final IconData              icon;
  final TextInputType         keyboardType;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });
  @override
  Widget build(BuildContext context) => TextField(
        controller:  controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText:  hint,
          prefixIcon: Icon(icon, size: 18, color: _brand),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
        ),
      );
}
