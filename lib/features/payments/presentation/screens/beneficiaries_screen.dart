// lib/features/payments/presentation/screens/beneficiaries_screen.dart
//
// List, add, edit, and delete payment beneficiaries.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../data/piprapay_repository.dart';
import '../../domain/models/beneficiary_model.dart';

const Color _brand    = Color(0xFF7C3AED); // violet
const Color _brandMid = Color(0xFF8B5CF6);
const Color _surface  = Color(0xFFF5F3FF);
const Color _red      = Color(0xFFDC2626);

class BeneficiariesScreen extends StatefulWidget {
  final String cid;
  const BeneficiariesScreen({super.key, required this.cid});
  @override
  State<BeneficiariesScreen> createState() => _BeneficiariesScreenState();
}

class _BeneficiariesScreenState extends State<BeneficiariesScreen> {
  late final PipraPayRepository _repo;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _repo = PipraPayRepository(cid: widget.cid);
  }

  Future<void> _delete(BeneficiaryModel b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Beneficiary'),
        content: Text('Remove "${b.name}"?'),
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
    if (ok == true) await _repo.deleteBeneficiary(b.id);
  }

  void _openForm({BeneficiaryModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BeneficiaryForm(repo: _repo, existing: existing),
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
          title: const Text('Beneficiaries',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search beneficiaries…',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Add Beneficiary',
              style: TextStyle(fontWeight: FontWeight.w700)),
          onPressed: () => _openForm(),
        ),
        body: StreamBuilder<List<BeneficiaryModel>>(
          stream: _repo.watchBeneficiaries(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: _brand));
            }
            var list = snap.data!;
            if (_search.isNotEmpty) {
              list = list
                  .where((b) =>
                      b.name.toLowerCase().contains(_search) ||
                      b.emailOrMobile.toLowerCase().contains(_search))
                  .toList();
            }
            if (list.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline_rounded,
                          size: 64, color: Colors.black12),
                      const SizedBox(height: 16),
                      Text(
                        _search.isNotEmpty
                            ? 'No results for "$_search"'
                            : 'No beneficiaries yet',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black38),
                      ),
                      if (_search.isEmpty) ...[
                        const SizedBox(height: 6),
                        const Text('Add people or vendors to pay',
                            style: TextStyle(
                                fontSize: 13, color: Colors.black26)),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: _brand),
                          icon: const Icon(Icons.person_add_rounded),
                          label: const Text('Add Beneficiary'),
                          onPressed: () => _openForm(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: list.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _BenCard(
                b:        list[i],
                onEdit:   () => _openForm(existing: list[i]),
                onDelete: () => _delete(list[i]),
              ),
            );
          },
        ),
      );
}

// ── Beneficiary Card ──────────────────────────────────────────────────────────
class _BenCard extends StatelessWidget {
  final BeneficiaryModel b;
  final VoidCallback     onEdit;
  final VoidCallback     onDelete;
  const _BenCard(
      {required this.b, required this.onEdit, required this.onDelete});

  static const _typeColors = {
    BeneficiaryType.individual: Color(0xFF4F46E5),
    BeneficiaryType.vendor:     Color(0xFF0891B2),
    BeneficiaryType.employee:   Color(0xFF059669),
    BeneficiaryType.other:      Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[b.type] ?? Colors.grey;
    final initials = b.name.trim().isEmpty
        ? '?'
        : b.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Text(initials,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(b.type.label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(b.emailOrMobile,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45)),
                ),
              ]),
              if (b.notes.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(b.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded,
                size: 18, color: _red),
            onPressed: onDelete,
          ),
        ]),
      ]),
    );
  }
}

// ── Add/Edit Form ─────────────────────────────────────────────────────────────
class _BeneficiaryForm extends StatefulWidget {
  final PipraPayRepository repo;
  final BeneficiaryModel?  existing;
  const _BeneficiaryForm({required this.repo, this.existing});
  @override
  State<_BeneficiaryForm> createState() => _BeneficiaryFormState();
}

class _BeneficiaryFormState extends State<_BeneficiaryForm> {
  final _nameCtl  = TextEditingController();
  final _mobCtl   = TextEditingController();
  final _acctCtl  = TextEditingController();
  final _bankCtl  = TextEditingController();
  final _notesCtl = TextEditingController();

  BeneficiaryType _type   = BeneficiaryType.individual;
  bool            _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtl.text  = e.name;
      _mobCtl.text   = e.emailOrMobile;
      _acctCtl.text  = e.accountNumber;
      _bankCtl.text  = e.bankName;
      _notesCtl.text = e.notes;
      _type          = e.type;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _mobCtl.dispose();
    _acctCtl.dispose();
    _bankCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtl.text.trim().isEmpty || _mobCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Name and email/mobile are required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final b = BeneficiaryModel(
        id:            widget.existing?.id ?? '',
        name:          _nameCtl.text.trim(),
        emailOrMobile: _mobCtl.text.trim(),
        type:          _type,
        accountNumber: _acctCtl.text.trim(),
        bankName:      _bankCtl.text.trim(),
        notes:         _notesCtl.text.trim(),
      );
      if (widget.existing == null) {
        await widget.repo.addBeneficiary(b);
      } else {
        await widget.repo.updateBeneficiary(b);
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
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.1),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
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
                      ? 'Add Beneficiary'
                      : 'Edit Beneficiary',
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
                  // Type
                  const Text('Type',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.black54)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BeneficiaryType.values.map((t) {
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

                  _FF(controller: _nameCtl, label: 'Full Name *',
                      hint: 'John Doe'),
                  const SizedBox(height: 12),
                  _FF(controller: _mobCtl,
                      label: 'Email or Mobile *',
                      hint: 'email@example.com or 01700000000'),
                  const SizedBox(height: 12),
                  _FF(controller: _acctCtl,
                      label: 'Account / Wallet Number',
                      hint: 'Optional'),
                  const SizedBox(height: 12),
                  _FF(controller: _bankCtl,
                      label: 'Bank Name',
                      hint: 'Optional'),
                  const SizedBox(height: 12),
                  _FF(controller: _notesCtl,
                      label: 'Notes',
                      hint: 'Any additional info',
                      maxLines: 3),
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
                            widget.existing == null
                                ? 'Add Beneficiary'
                                : 'Save Changes',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _FF extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final String                hint;
  final int                   maxLines;
  const _FF({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines:   maxLines,
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
