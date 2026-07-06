// lib/features/payments/presentation/screens/hr_bank_accounts_screen.dart
//
// HR Company Bank Accounts — manage the company's own outgoing payment accounts.
// These are the accounts HR uses to SEND salary payments (bKash, Nagad, Bank).
//
// Firestore path: data/{companyId}/money_sources/{id}
// This reuses the existing MoneySourceModel + PipraPayRepository.
//
// Features:
//   • List all company money sources with type-colored cards
//   • Add / Edit / Delete accounts
//   • Mark one as Default (used automatically when sending via PipraPay)
//   • Live PipraPay connection status indicator
//   • "Test PipraPay Connection" button
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../data/piprapay_repository.dart';
import '../../domain/models/money_source_model.dart';
import '../../domain/models/payment_settings_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _brand    = Color(0xFF065F46);
const Color _brandMid = Color(0xFF10B981);
const Color _surface  = Color(0xFFF0FDF4);
const Color _red      = Color(0xFFDC2626);
const Color _amber    = Color(0xFFD97706);
const Color _indigo   = Color(0xFF4F46E5);

// Method-specific brand colours
const Map<MoneySourceType, Color> _typeColor = {
  MoneySourceType.bkash:  Color(0xFFE2136E),
  MoneySourceType.nagad:  Color(0xFFEF4444),
  MoneySourceType.rocket: Color(0xFF8B5CF6),
  MoneySourceType.upay:   Color(0xFF059669),
  MoneySourceType.bank:   Color(0xFF0891B2),
  MoneySourceType.card:   Color(0xFF7C3AED),
  MoneySourceType.other:  Color(0xFF6B7280),
};

const Map<MoneySourceType, IconData> _typeIcon = {
  MoneySourceType.bkash:  Icons.phone_android_rounded,
  MoneySourceType.nagad:  Icons.phone_android_rounded,
  MoneySourceType.rocket: Icons.phone_android_rounded,
  MoneySourceType.upay:   Icons.phone_android_rounded,
  MoneySourceType.bank:   Icons.account_balance_rounded,
  MoneySourceType.card:   Icons.credit_card_rounded,
  MoneySourceType.other:  Icons.wallet_rounded,
};

// ─────────────────────────────────────────────────────────────────────────────
class HrBankAccountsScreen extends StatefulWidget {
  final String cid;
  const HrBankAccountsScreen({super.key, required this.cid});
  @override
  State<HrBankAccountsScreen> createState() => _HrBankAccountsScreenState();
}

class _HrBankAccountsScreenState extends State<HrBankAccountsScreen> {
  late final PipraPayRepository _repo;
  bool _testingConn = false;
  String _connStatus = 'disconnected';
  PaymentSettingsModel? _settings;

  @override
  void initState() {
    super.initState();
    _repo = PipraPayRepository(cid: widget.cid);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await _repo.getSettings();
    if (mounted) setState(() { _settings = s; _connStatus = s.connectionStatus; });
  }

  Future<void> _testConnection() async {
    if (_settings == null) return;
    setState(() => _testingConn = true);
    try {
      final ok = await _repo.testConnection(_settings!.backendBaseUrl);
      if (mounted) setState(() => _connStatus = ok ? 'connected' : 'disconnected');
      _snack(ok ? '✅ PipraPay backend connected!' : '❌ Cannot reach backend', error: !ok);
    } catch (e) {
      if (mounted) setState(() => _connStatus = 'disconnected');
      _snack('Connection error: $e', error: true);
    } finally {
      if (mounted) setState(() => _testingConn = false);
    }
  }

  Future<void> _delete(MoneySourceModel src) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Account'),
        content: Text('Remove "${src.label}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove',
                  style: TextStyle(color: _red))),
        ],
      ),
    );
    if (ok == true) await _repo.deleteMoneySource(src.id);
  }

  void _openForm({MoneySourceModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountForm(repo: _repo, existing: existing),
    );
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
        title: const Text('Company Bank Accounts',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Account',
            onPressed: _openForm,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── PipraPay Status Banner ──────────────────────────────────────
          _PipraPayStatusCard(
            settings:     _settings,
            connStatus:   _connStatus,
            testing:      _testingConn,
            onTest:       _testConnection,
            onConfigure:  () => Navigator.pushNamed(
                context, '/payments/piprapay/settings',
                arguments: widget.cid),
          ),

          // ── Account list ────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<MoneySourceModel>>(
              stream: _repo.watchMoneySources(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: _brand));
                }
                final sources = snap.data!;
                if (sources.isEmpty) {
                  return _EmptyState(onAdd: _openForm);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: sources.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _AccountCard(
                    src:      sources[i],
                    onEdit:   () => _openForm(existing: sources[i]),
                    onDelete: () => _delete(sources[i]),
                    onSetDefault: () async {
                      await _repo.updateMoneySource(
                          sources[i].copyWith(isDefault: true));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Account',
            style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: _openForm,
      ),
    );
  }
}

// ── PipraPay Status Card ──────────────────────────────────────────────────────
class _PipraPayStatusCard extends StatelessWidget {
  final PaymentSettingsModel? settings;
  final String    connStatus;
  final bool      testing;
  final VoidCallback onTest;
  final VoidCallback onConfigure;

  const _PipraPayStatusCard({
    required this.settings,
    required this.connStatus,
    required this.testing,
    required this.onTest,
    required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final connected = connStatus == 'connected';
    final enabled   = settings?.enabled ?? false;
    final sandbox   = settings?.sandboxMode ?? true;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (!enabled) {
      statusColor = Colors.grey;
      statusIcon  = Icons.power_off_rounded;
      statusLabel = 'PipraPay Disabled';
    } else if (connected) {
      statusColor = _brand;
      statusIcon  = Icons.check_circle_rounded;
      statusLabel = sandbox ? 'Connected (Sandbox)' : 'Connected (Live)';
    } else {
      statusColor = _amber;
      statusIcon  = Icons.warning_amber_rounded;
      statusLabel = 'Not Connected to Backend';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PipraPay Status',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                  Text(statusLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (sandbox && enabled)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _amber.withValues(alpha: 0.3)),
                ),
                child: const Text('SANDBOX',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: _amber)),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _indigo,
                  side: BorderSide(
                      color: _indigo.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('Configure',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12)),
                onPressed: onConfigure,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: connected ? _brand : _amber,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: testing
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.wifi_tethering_rounded, size: 16),
                label: Text(testing ? 'Testing…' : 'Test Connection',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12)),
                onPressed: testing ? null : onTest,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Account Card ──────────────────────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final MoneySourceModel src;
  final VoidCallback     onEdit;
  final VoidCallback     onDelete;
  final VoidCallback     onSetDefault;

  const _AccountCard({
    required this.src,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final color = _typeColor[src.type] ?? Colors.grey;
    final icon  = _typeIcon[src.type]  ?? Icons.wallet_rounded;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: src.isDefault
                ? color.withValues(alpha: 0.4)
                : Colors.black12,
            width: src.isDefault ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Row(children: [
              Expanded(
                child: Text(src.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              if (src.isDefault)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text('DEFAULT',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: color)),
                ),
            ]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text(src.type.label,
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w700)),
                if (src.accountNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(src.accountNumber,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                ],
                if (src.bankName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(src.bankName,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black38)),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: Colors.black38),
              onSelected: (v) {
                if (v == 'edit')       onEdit();
                if (v == 'delete')     onDelete();
                if (v == 'setDefault') onSetDefault();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ])),
                if (!src.isDefault)
                  const PopupMenuItem(
                      value: 'setDefault',
                      child: Row(children: [
                        Icon(Icons.star_rounded,
                            size: 16, color: _amber),
                        SizedBox(width: 8),
                        Text('Set as Default'),
                      ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 16, color: _red),
                      SizedBox(width: 8),
                      Text('Remove',
                          style: TextStyle(color: _red)),
                    ])),
              ],
            ),
          ),
          // Bottom action row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(
                        color: color.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Edit',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(width: 8),
              if (!src.isDefault)
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding:
                          const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.star_rounded, size: 14),
                    label: const Text('Set Default',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    onPressed: onSetDefault,
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Add / Edit Form ───────────────────────────────────────────────────────────
class _AccountForm extends StatefulWidget {
  final PipraPayRepository _repo;
  final MoneySourceModel?  existing;
  const _AccountForm({required PipraPayRepository repo, this.existing})
      : _repo = repo;
  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _labelCtl       = TextEditingController();
  final _accountCtl     = TextEditingController();
  final _accountNameCtl = TextEditingController();
  final _bankCtl        = TextEditingController();
  final _branchCtl      = TextEditingController();
  final _routingCtl     = TextEditingController();

  MoneySourceType _type      = MoneySourceType.bkash;
  bool            _isDefault = false;
  bool            _saving    = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _labelCtl.text       = e.label;
      _accountCtl.text     = e.accountNumber;
      _accountNameCtl.text = e.accountName;
      _bankCtl.text        = e.bankName;
      _branchCtl.text      = e.branchName;
      _routingCtl.text     = e.routingNumber;
      _type                = e.type;
      _isDefault           = e.isDefault;
    }
  }

  @override
  void dispose() {
    _labelCtl.dispose();
    _accountCtl.dispose();
    _accountNameCtl.dispose();
    _bankCtl.dispose();
    _branchCtl.dispose();
    _routingCtl.dispose();
    super.dispose();
  }

  bool get _isBank => _type == MoneySourceType.bank;

  Future<void> _save() async {
    if (_labelCtl.text.trim().isEmpty) {
      _snack('Account label is required', error: true);
      return;
    }
    if (_accountCtl.text.trim().isEmpty) {
      _snack('Account / mobile number is required', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final src = MoneySourceModel(
        id:            widget.existing?.id ?? '',
        label:         _labelCtl.text.trim(),
        type:          _type,
        accountNumber: _accountCtl.text.trim(),
        accountName:   _accountNameCtl.text.trim(),
        bankName:      _bankCtl.text.trim(),
        branchName:    _branchCtl.text.trim(),
        routingNumber: _routingCtl.text.trim(),
        isDefault:     _isDefault,
      );
      if (widget.existing == null) {
        await widget._repo.addMoneySource(src);
      } else {
        await widget._repo.updateMoneySource(src);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
    final isEdit = widget.existing != null;
    return Container(
      margin: EdgeInsets.only(
          top: MediaQuery.of(context).size.height * 0.12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              Text(
                isEdit ? 'Edit Account' : 'Add Payment Account',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                // ── Type picker ─────────────────────────────────────────
                const Text('Account Type',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.black54)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MoneySourceType.values.map((t) {
                    final sel   = _type == t;
                    final color = _typeColor[t] ?? Colors.grey;
                    final icon  = _typeIcon[t]  ?? Icons.wallet_rounded;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? color.withValues(alpha: 0.12)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: sel ? color : Colors.black12,
                              width: sel ? 1.5 : 1),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon,
                                  color: sel ? color : Colors.black38,
                                  size: 16),
                              const SizedBox(width: 6),
                              Text(t.label,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: sel
                                          ? color
                                          : Colors.black54)),
                            ]),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // ── Label ───────────────────────────────────────────────
                _Field(
                  controller: _labelCtl,
                  label: 'Account Label *',
                  hint: 'e.g. Company bKash, Main Bank',
                  icon: Icons.label_rounded,
                ),
                const SizedBox(height: 12),

                // ── Account / Mobile ────────────────────────────────────
                _Field(
                  controller: _accountCtl,
                  label: _isBank
                      ? 'Bank Account Number *'
                      : 'Mobile Number *',
                  hint: _isBank ? '1234567890' : '01700000000',
                  icon: _isBank
                      ? Icons.account_balance_rounded
                      : Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                // ── Account holder name ─────────────────────────────────
                _Field(
                  controller: _accountNameCtl,
                  label: 'Account Holder Name',
                  hint: 'Name registered with the account',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),

                // ── Bank-specific fields ────────────────────────────────
                if (_isBank) ...[
                  _Field(
                    controller: _bankCtl,
                    label: 'Bank Name',
                    hint: 'e.g. Dutch Bangla Bank',
                    icon: Icons.account_balance_rounded,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _branchCtl,
                    label: 'Branch Name',
                    hint: 'e.g. Gulshan Branch',
                    icon: Icons.location_city_rounded,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _routingCtl,
                    label: 'Routing Number',
                    hint: '123456789',
                    icon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),

                // ── Default toggle ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isDefault
                        ? _amber.withValues(alpha: 0.06)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _isDefault
                            ? _amber.withValues(alpha: 0.3)
                            : Colors.black12),
                  ),
                  child: Row(children: [
                    Icon(
                      Icons.star_rounded,
                      color: _isDefault ? _amber : Colors.black26,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Set as Default',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          Text(
                            'Used automatically when sending payroll',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.black38),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isDefault,
                      activeThumbColor: _amber,
                      activeTrackColor:
                          _amber.withValues(alpha: 0.4),
                      onChanged: (v) =>
                          setState(() => _isDefault = v),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── Save button ─────────────────────────────────────────
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _saving
                        ? 'Saving…'
                        : isEdit
                            ? 'Update Account'
                            : 'Add Account',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  size: 40, color: _brand),
            ),
            const SizedBox(height: 16),
            const Text('No payment accounts yet',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.black54)),
            const SizedBox(height: 6),
            const Text(
              'Add your company bKash, Nagad, or bank account\nto start sending salary payments.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black38),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Account',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: onAdd,
            ),
          ],
        ),
      );
}

// ── Reusable Field ────────────────────────────────────────────────────────────
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
        controller:   controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText:  label,
          hintText:   hint,
          prefixIcon: Icon(icon, size: 18, color: _brand),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
        ),
      );
}
