// lib/features/payments/presentation/screens/money_sources_screen.dart
//
// List, add, edit, and delete company money sources (wallets / bank accounts).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../data/piprapay_repository.dart';
import '../../domain/models/money_source_model.dart';

const Color _brand    = Color(0xFF0891B2); // cyan
const Color _brandMid = Color(0xFF06B6D4);
const Color _surface  = Color(0xFFF0F9FF);
const Color _red      = Color(0xFFDC2626);

class MoneySourcesScreen extends StatefulWidget {
  final String cid;
  const MoneySourcesScreen({super.key, required this.cid});
  @override
  State<MoneySourcesScreen> createState() => _MoneySourcesScreenState();
}

class _MoneySourcesScreenState extends State<MoneySourcesScreen> {
  late final PipraPayRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = PipraPayRepository(cid: widget.cid);
  }

  Future<void> _delete(MoneySourceModel src) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Money Source'),
        content: Text('Remove "${src.label}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
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
      builder: (_) => _MoneySourceForm(
        repo:     _repo,
        existing: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
          title: const Text('Money Sources',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Source',
              style: TextStyle(fontWeight: FontWeight.w700)),
          onPressed: () => _openForm(),
        ),
        body: StreamBuilder<List<MoneySourceModel>>(
          stream: _repo.watchMoneySources(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: _brand));
            }
            final sources = snap.data!;
            if (sources.isEmpty) {
              return _EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                message: 'No money sources yet',
                sub: 'Add a bKash, Nagad, bank account, or card',
                onAdd: () => _openForm(),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: sources.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _SourceCard(
                source: sources[i],
                onEdit: () => _openForm(existing: sources[i]),
                onDelete: () => _delete(sources[i]),
              ),
            );
          },
        ),
      );
}

// ── Source Card ───────────────────────────────────────────────────────────────
class _SourceCard extends StatelessWidget {
  final MoneySourceModel source;
  final VoidCallback     onEdit;
  final VoidCallback     onDelete;
  const _SourceCard(
      {required this.source, required this.onEdit, required this.onDelete});

  static const _typeColors = {
    MoneySourceType.bkash:  Color(0xFFE2136E),
    MoneySourceType.nagad:  Color(0xFFEF4444),
    MoneySourceType.rocket: Color(0xFF8B5CF6),
    MoneySourceType.upay:   Color(0xFF059669),
    MoneySourceType.bank:   Color(0xFF0891B2),
    MoneySourceType.card:   Color(0xFF4F46E5),
    MoneySourceType.other:  Color(0xFF6B7280),
  };

  static const _typeIcons = {
    MoneySourceType.bkash:  Icons.phone_android_rounded,
    MoneySourceType.nagad:  Icons.phone_android_rounded,
    MoneySourceType.rocket: Icons.phone_android_rounded,
    MoneySourceType.upay:   Icons.phone_android_rounded,
    MoneySourceType.bank:   Icons.account_balance_rounded,
    MoneySourceType.card:   Icons.credit_card_rounded,
    MoneySourceType.other:  Icons.wallet_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[source.type] ?? Colors.grey;
    final icon  = _typeIcons[source.type]  ?? Icons.wallet_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: source.isDefault
                ? color.withValues(alpha: 0.4)
                : Colors.black12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(source.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                if (source.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Default',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(source.type.label,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
              if (source.accountNumber.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(source.accountNumber,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black45)),
              ],
              if (source.accountName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(source.accountName,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38)),
              ],
            ],
          ),
        ),
        Column(children: [
          IconButton(
            icon: const Icon(Icons.edit_rounded,
                size: 18, color: Colors.black38),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded,
                size: 18, color: _red),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ]),
      ]),
    );
  }
}

// ── Add/Edit Form ─────────────────────────────────────────────────────────────
class _MoneySourceForm extends StatefulWidget {
  final PipraPayRepository repo;
  final MoneySourceModel?  existing;
  const _MoneySourceForm({required this.repo, this.existing});
  @override
  State<_MoneySourceForm> createState() => _MoneySourceFormState();
}

class _MoneySourceFormState extends State<_MoneySourceForm> {
  final _labelCtl   = TextEditingController();
  final _acctCtl    = TextEditingController();
  final _nameCtl    = TextEditingController();
  final _bankCtl    = TextEditingController();
  final _branchCtl  = TextEditingController();
  final _routingCtl = TextEditingController();

  MoneySourceType _type      = MoneySourceType.bkash;
  bool            _isDefault = false;
  bool            _saving    = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _labelCtl.text   = e.label;
      _acctCtl.text    = e.accountNumber;
      _nameCtl.text    = e.accountName;
      _bankCtl.text    = e.bankName;
      _branchCtl.text  = e.branchName;
      _routingCtl.text = e.routingNumber;
      _type            = e.type;
      _isDefault       = e.isDefault;
    }
  }

  @override
  void dispose() {
    _labelCtl.dispose();
    _acctCtl.dispose();
    _nameCtl.dispose();
    _bankCtl.dispose();
    _branchCtl.dispose();
    _routingCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_labelCtl.text.trim().isEmpty || _acctCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label and account number are required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final src = MoneySourceModel(
        id:            widget.existing?.id ?? '',
        label:         _labelCtl.text.trim(),
        type:          _type,
        accountNumber: _acctCtl.text.trim(),
        accountName:   _nameCtl.text.trim(),
        bankName:      _bankCtl.text.trim(),
        branchName:    _branchCtl.text.trim(),
        routingNumber: _routingCtl.text.trim(),
        isDefault:     _isDefault,
      );
      if (widget.existing == null) {
        await widget.repo.addMoneySource(src);
      } else {
        await widget.repo.updateMoneySource(src);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBank = _type == MoneySourceType.bank;

    return Container(
      margin: EdgeInsets.only(
          top: MediaQuery.of(context).size.height * 0.12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Text(
                widget.existing == null
                    ? 'Add Money Source'
                    : 'Edit Money Source',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                // Type picker
                const Text('Type',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.black54)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MoneySourceType.values.map((t) {
                    final sel = _type == t;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? _brand.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel
                                  ? _brand
                                  : Colors.transparent),
                        ),
                        child: Text(t.label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: sel ? _brand : Colors.black54)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                _FormField(controller: _labelCtl, label: 'Label / Nickname *',
                    hint: 'e.g. My bKash'),
                const SizedBox(height: 12),
                _FormField(controller: _acctCtl,
                    label: isBank ? 'Account Number *' : 'Mobile Number *',
                    hint: isBank ? '1234567890' : '01700000000',
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _FormField(controller: _nameCtl,
                    label: 'Account Holder Name',
                    hint: 'Full name'),
                if (isBank) ...[
                  const SizedBox(height: 12),
                  _FormField(controller: _bankCtl,
                      label: 'Bank Name', hint: 'e.g. Dutch Bangla Bank'),
                  const SizedBox(height: 12),
                  _FormField(controller: _branchCtl,
                      label: 'Branch', hint: 'Branch name'),
                  const SizedBox(height: 12),
                  _FormField(controller: _routingCtl,
                      label: 'Routing Number', hint: '123456789',
                      keyboardType: TextInputType.number),
                ],
                const SizedBox(height: 12),

                // Default toggle
                Row(children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Set as Default',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('Use this source by default for payments',
                            style: TextStyle(
                                fontSize: 11, color: Colors.black38)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                    activeThumbColor: _brand,
                    activeTrackColor: _brand.withValues(alpha: 0.4),
                  ),
                ]),
                const SizedBox(height: 20),

                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          widget.existing == null ? 'Add Source' : 'Save Changes',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final String                hint;
  final TextInputType         keyboardType;
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });
  @override
  Widget build(BuildContext context) => TextField(
        controller:   controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText:  hint,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData     icon;
  final String       message;
  final String       sub;
  final VoidCallback onAdd;
  const _EmptyState(
      {required this.icon,
      required this.message,
      required this.sub,
      required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.black12),
              const SizedBox(height: 16),
              Text(message,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.black38)),
              const SizedBox(height: 6),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black26)),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _brand),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Source'),
                onPressed: onAdd,
              ),
            ],
          ),
        ),
      );
}
