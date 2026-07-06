import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/core/utils/finance_utils.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/widgets/u_card.dart';

const _brandGreen = Color(0xFF065F46);

class TaxCalculationPage extends StatefulWidget {
  const TaxCalculationPage({super.key});
  @override
  State<TaxCalculationPage> createState() => _TaxCalculationPageState();
}

class _TaxCalculationPageState extends State<TaxCalculationPage> {
  final _basicCtrl = TextEditingController();
  final _hraCtrl   = TextEditingController();
  final _medCtrl   = TextEditingController();
  String _category = 'Male';
  double? _taxResult;
  double? _effectiveRate;

  String _cid = '';
  Map<String, dynamic> _config = {};
  bool _configLoaded = false;

  double get _threshold {
    final t = _config['threshold_$_category'];
    if (t is num) return t.toDouble();
    switch (_category) {
      case 'Female': case 'Senior': return 400000;
      case 'Disabled': return 475000;
      case 'Freedom Fighter': return 500000;
      default: return 350000;
    }
  }

  List<double> get _slabThresholds {
    final slabs = _config['slabs'] as List<dynamic>?;
    if (slabs != null && slabs.length >= 6) {
      return slabs.map((e) => (e as num).toDouble()).toList();
    }
    return [350000, 450000, 850000, 1350000, 1850000, 3850000];
  }

  List<double> get _slabRates {
    final rates = _config['rates'] as List<dynamic>?;
    if (rates != null && rates.length >= 6) {
      return rates.map((e) => (e as num).toDouble()).toList();
    }
    return [0.0, 0.05, 0.10, 0.15, 0.20, 0.25];
  }

  double get _topRate {
    final r = _config['topRate'];
    if (r is num) return r.toDouble();
    return 0.30;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (mounted) setState(() => _cid = id ?? '');
    if (_cid.isNotEmpty) {
      try {
        final snap = await DB.colSync(_cid, C.taxConfig).doc('main').get();
        if (snap.exists) {
          if (mounted) setState(() => _config = snap.data()!);
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _configLoaded = true);
  }

  double _calcTax(double income) {
    final threshold = _threshold;
    final thresholds = _slabThresholds;
    final rates = _slabRates;
    final adjusted = thresholds.map((t) => t - 350000 + threshold).toList();

    double tax = 0;
    double prev = 0;

    for (int i = 0; i < adjusted.length; i++) {
      if (income > adjusted[i]) {
        tax += (adjusted[i] - prev) * rates[i];
        prev = adjusted[i];
      } else {
        tax += (income - prev) * rates[i];
        return FinanceUtils.round(tax);
      }
    }

    if (income > prev) {
      tax += (income - prev) * _topRate;
    }

    return FinanceUtils.round(tax);
  }

  @override
  void dispose() {
    _basicCtrl.dispose();
    _hraCtrl.dispose();
    _medCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final basic = FinanceUtils.toDouble(_basicCtrl.text);
    final hra   = FinanceUtils.toDouble(_hraCtrl.text);
    final med   = FinanceUtils.toDouble(_medCtrl.text);
    final total = basic + hra + med;
    final tax   = _calcTax(total);
    setState(() {
      _taxResult = tax;
      _effectiveRate = total > 0 ? FinanceUtils.round((tax / total) * 100) : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_configLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Tax Analytics', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const _TaxConfigScreen(),
            )),
            tooltip: 'Configure Tax Slabs',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(UddoygiDesign.space20),
        children: [
          _StepHeader(number: '01', title: 'TAXPAYER PROFILE').animate().fadeIn(),
          const SizedBox(height: 12),
          _CategorySelector(selected: _category, onSelected: (v) => setState(() => _category = v)).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 24),
          _StepHeader(number: '02', title: 'INCOME COMPONENTS').animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          UCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _ModernField(label: 'Annual Basic Salary', controller: _basicCtrl, hint: '1,200,000', prefix: '৳ '),
                const SizedBox(height: 16),
                _ModernField(label: 'House Rent (HRA)', controller: _hraCtrl, hint: '300,000', prefix: '৳ '),
                const SizedBox(height: 16),
                _ModernField(label: 'Medical Allowance', controller: _medCtrl, hint: '50,000', prefix: '৳ '),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 24),
          if (_taxResult != null)
            UCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('TAX LIABILITY', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('৳ ${NumberFormat('#,##0').format(_taxResult!.toInt())}', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: _brandGreen)),
                  const SizedBox(height: 4),
                  Text('Effective Rate: ${_effectiveRate}%', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ).animate().fadeIn(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.analytics_rounded),
              label: Text('RUN TAX SIMULATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
              style: ElevatedButton.styleFrom(backgroundColor: _brandGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}

// Re-export TaxConfigScreen as an inline page
class _TaxConfigScreen extends StatefulWidget {
  const _TaxConfigScreen();
  @override
  State<_TaxConfigScreen> createState() => _TaxConfigScreenState();
}

class _TaxConfigScreenState extends State<_TaxConfigScreen> {
  String _cid = '';
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
    final defThresholds = [350000, 450000, 850000, 1350000, 1850000, 3850000];
    final defRates = [0.0, 0.05, 0.10, 0.15, 0.20, 0.25];
    for (int i = 0; i < 6; i++) {
      _slabThresholdCtrls.add(TextEditingController(text: defThresholds[i].toString()));
      _slabRateCtrls.add(TextEditingController(text: defRates[i].toStringAsFixed(2)));
    }
    _init();
  }

  Future<void> _init() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (mounted) setState(() => _cid = id ?? '');
    if (_cid.isNotEmpty) {
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
              _slabThresholdCtrls[i].text = (slabs[i] as num).toInt().toString();
              _slabRateCtrls[i].text = (rates[i] as num).toStringAsFixed(2);
            }
          }
          final top = data['topRate'];
          if (top is num) _topRateCtrl.text = top.toStringAsFixed(2);
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
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
      Navigator.pop(context);
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
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        title: Text('Tax Configuration', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
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
                Text('CATEGORY THRESHOLDS', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: _brandGreen)),
                const SizedBox(height: 8),
                Text('Tax-free income limit per taxpayer category', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 16),
                ..._categories.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ConfigField(label: c, controller: _thresholdCtrl[c]!, suffix: 'BDT'),
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
                Text('TAX SLABS & RATES', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: _brandGreen)),
                const SizedBox(height: 8),
                Text('Income slabs and their applicable tax rates', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 16),
                for (int i = 0; i < 6; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: _brandGreen, borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text('${i + 1}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: _ConfigField(controller: _slabThresholdCtrls[i], suffix: 'BDT')),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: _ConfigField(controller: _slabRateCtrls[i], suffix: '%', isRate: true)),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Top Rate: ', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    SizedBox(
                      width: 100,
                      child: _ConfigField(controller: _topRateCtrl, suffix: '%', isRate: true),
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
              label: Text(_saving ? 'SAVING...' : 'SAVE CONFIGURATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
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

class _ConfigField extends StatelessWidget {
  final String? label;
  final TextEditingController controller;
  final String suffix;
  final bool isRate;
  const _ConfigField({this.label, required this.controller, this.suffix = '', this.isRate = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700])),
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
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String number, title;
  const _StepHeader({required this.number, required this.title});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _brandGreen, borderRadius: BorderRadius.circular(6)), child: Text(number, style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
      const SizedBox(width: 10),
      Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[600], letterSpacing: 1.2)),
    ],
  );
}

class _CategorySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const _CategorySelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final categories = ['Male', 'Female', 'Senior', 'Disabled', 'Freedom Fighter'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((c) {
          final active = selected == c;
          return GestureDetector(
            onTap: () => onSelected(c),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: active ? _brandGreen : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? _brandGreen : Colors.grey.withOpacity(0.2))),
              child: Text(c.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.grey[600])),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ModernField extends StatelessWidget {
  final String label, hint;
  final String? prefix;
  final TextEditingController controller;
  const _ModernField({required this.label, required this.hint, this.prefix, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[600])),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
