import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/widgets/u_card.dart';

const Color _brandGreen = Color(0xFF065F46);

class TaxConfigScreen extends StatefulWidget {
  const TaxConfigScreen({super.key});
  @override
  State<TaxConfigScreen> createState() => _TaxConfigScreenState();
}

class _TaxConfigScreenState extends State<TaxConfigScreen> {
  String _cid = '';
  bool _loading = true;
  bool _saving = false;

  final Map<String, TextEditingController> _thresholdCtrl = {};
  final List<TextEditingController> _slabThresholdCtrls = [];
  final List<TextEditingController> _slabRateCtrls = [];
  late TextEditingController _topRateCtrl;

  static const _categories = ['Male', 'Female', 'Senior', 'Disabled', 'Freedom Fighter'];

  @override
  void initState() {
    super.initState();
    _topRateCtrl = TextEditingController(text: '0.30');
    for (final c in _categories) {
      _thresholdCtrl[c] = TextEditingController(text: c == 'Male' ? '350000' : c == 'Female' || c == 'Senior' ? '400000' : c == 'Disabled' ? '475000' : '500000');
    }
    _init();
  }

  Future<void> _init() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (mounted) setState(() => _cid = id ?? '');
    await _loadConfig();
  }

  Future<void> _loadConfig() async {
    if (_cid.isEmpty) return;
    try {
      final snap = await DB.colSync(_cid, C.taxConfig).doc('main').get();
      if (snap.exists) {
        final data = snap.data()!;
        for (final c in _categories) {
          final t = data['threshold_$c'];
          if (t is num) _thresholdCtrl[c]?.text = t.toInt().toString();
        }
        final slabs = data['slabs'] as List<dynamic>? ?? [];
        final rates = data['rates'] as List<dynamic>? ?? [];
        if (slabs.length >= 6) {
          for (int i = 0; i < 6; i++) {
            if (i < _slabThresholdCtrls.length) _slabThresholdCtrls[i].text = (slabs[i] as num).toInt().toString();
            if (i < _slabRateCtrls.length) _slabRateCtrls[i].text = (rates[i] as num).toStringAsFixed(2);
          }
        }
        final top = data['topRate'];
        if (top is num) _topRateCtrl.text = top.toStringAsFixed(2);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final data = <String, dynamic>{};
    for (final c in _categories) {
      data['threshold_$c'] = int.tryParse(_thresholdCtrl[c]?.text ?? '') ?? 350000;
    }
    data['slabs'] = _slabThresholdCtrls.map((c) => int.tryParse(c.text) ?? 350000).toList();
    data['rates'] = _slabRateCtrls.map((c) => double.tryParse(c.text) ?? 0.0).toList();
    data['topRate'] = double.tryParse(_topRateCtrl.text) ?? 0.30;
    data['updatedAt'] = FieldValue.serverTimestamp();

    await DB.colSync(_cid, C.taxConfig).doc('main').set(data, SetOptions(merge: true));
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tax configuration saved')),
      );
    }
  }

  @override
  void dispose() {
    _topRateCtrl.dispose();
    for (final c in _thresholdCtrl.values) c.dispose();
    for (final c in _slabThresholdCtrls) c.dispose();
    for (final c in _slabRateCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Initialize slab controllers if not already
    if (_slabThresholdCtrls.isEmpty) {
      final defThresholds = [350000, 450000, 850000, 1350000, 1850000, 3850000];
      final defRates = [0.0, 0.05, 0.10, 0.15, 0.20, 0.25];
      for (int i = 0; i < 6; i++) {
        _slabThresholdCtrls.add(TextEditingController(text: defThresholds[i].toString()));
        _slabRateCtrls.add(TextEditingController(text: defRates[i].toStringAsFixed(2)));
      }
    }

    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        title: Text('Tax Configuration', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          UCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CATEGORY THRESHOLDS', style: AppFonts.banglaHeading(fontSize: 13, fontWeight: FontWeight.w800, color: _brandGreen)),
                const SizedBox(height: 8),
                Text('Tax-free income limit per taxpayer category', style: AppFonts.banglaBody(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 16),
                ..._categories.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Field(label: c, controller: _thresholdCtrl[c]!, suffix: 'BDT'),
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          UCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TAX SLABS & RATES', style: AppFonts.banglaHeading(fontSize: 13, fontWeight: FontWeight.w800, color: _brandGreen)),
                const SizedBox(height: 8),
                Text('Income slabs and their applicable tax rates', style: AppFonts.banglaBody(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 16),
                for (int i = 0; i < 6; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: _brandGreen, borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text('${i + 1}', style: AppFonts.banglaData(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _Field(controller: _slabThresholdCtrls[i], suffix: 'BDT'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _Field(controller: _slabRateCtrls[i], suffix: '%', isRate: true),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Top Rate (above last slab): ', style: AppFonts.banglaBody(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    SizedBox(
                      width: 100,
                      child: _Field(controller: _topRateCtrl, suffix: '%', isRate: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'SAVING...' : 'SAVE CONFIGURATION', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String? label;
  final TextEditingController controller;
  final String suffix;
  final bool isRate;

  const _Field({this.label, required this.controller, this.suffix = '', this.isRate = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 4),
        ],
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: isRate),
          decoration: InputDecoration(
            suffixText: suffix,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            isDense: true,
          ),
          style: AppFonts.banglaData(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
  }
}
