// lib/features/hr/presentation/screens/tax_calculation.dart
//
// Bangladesh Income Tax Slab Calculator — FY 2024-25
// NBR official rates for individual taxpayers
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const Color _navy  = Color(0xFF0B3552);
const Color _navyL = Color(0xFF1B5E8B);
const Color _green = Color(0xFF065F46);
const Color _surf  = Color(0xFFF1F5F9);

final _fmt = NumberFormat('#,##,##0', 'en_IN');
String _tk(double n) => '৳${_fmt.format(n.round())}';

// ── BD FY 2024-25 slabs ───────────────────────────────────────────────────────
const _slabSizes  = [100000.0, 400000.0, 500000.0, 500000.0];
const _slabRates  = [0.05,     0.10,     0.15,     0.20];
const _topRate    = 0.25;

class _SlabResult {
  final double taxableIncome;
  final double tax;
  final List<_SlabLine> lines;
  const _SlabResult({required this.taxableIncome, required this.tax, required this.lines});
}

class _SlabLine {
  final String label;
  final double amount;
  final double rate;
  final double tax;
  const _SlabLine(this.label, this.amount, this.rate, this.tax);
}

_SlabResult _compute(double grossIncome, double threshold) {
  if (grossIncome <= threshold) {
    return _SlabResult(taxableIncome: 0, tax: 0, lines: []);
  }
  double taxable = grossIncome - threshold;
  double tax = 0;
  final lines = <_SlabLine>[];

  for (int i = 0; i < _slabSizes.length; i++) {
    if (taxable <= 0) break;
    final chunk = taxable < _slabSizes[i] ? taxable : _slabSizes[i];
    final t = chunk * _slabRates[i];
    lines.add(_SlabLine(
      'Slab ${i + 1}: ${_tk(_slabSizes[i])} @ ${(_slabRates[i] * 100).toInt()}%',
      chunk, _slabRates[i], t,
    ));
    tax += t;
    taxable -= chunk;
  }
  if (taxable > 0) {
    final t = taxable * _topRate;
    lines.add(_SlabLine('Remaining @ ${(_topRate * 100).toInt()}%', taxable, _topRate, t));
    tax += t;
  }

  return _SlabResult(taxableIncome: grossIncome - threshold, tax: tax, lines: lines);
}

// ─────────────────────────────────────────────────────────────────────────────
class TaxCalculationPage extends StatefulWidget {
  const TaxCalculationPage({super.key});
  @override
  State<TaxCalculationPage> createState() => _TaxCalculationPageState();
}

class _TaxCalculationPageState extends State<TaxCalculationPage> {
  // Income inputs
  final _basicCtrl   = TextEditingController();
  final _hraCtrl     = TextEditingController();
  final _medCtrl     = TextEditingController();
  final _convCtrl    = TextEditingController();
  final _bonusCtrl   = TextEditingController();
  final _otherCtrl   = TextEditingController();

  String _category = 'Male';   // Male | Female | Senior (65+) | Disabled | Freedom Fighter
  bool _showBreakdown = false;
  _SlabResult? _result;

  double get _threshold {
    switch (_category) {
      case 'Female':           return 400000;
      case 'Senior (65+)':    return 400000;
      case 'Disabled':        return 475000;
      case 'Freedom Fighter': return 500000;
      default:                return 350000; // Male
    }
  }

  double _val(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  double get _totalIncome =>
      _val(_basicCtrl) + _val(_hraCtrl) + _val(_medCtrl) +
      _val(_convCtrl)  + _val(_bonusCtrl) + _val(_otherCtrl);

  // BD exemptions (simplified standard)
  double get _hraExempt  => (_val(_hraCtrl)  * 0.5).clamp(0, 300000);
  double get _medExempt  => (_val(_medCtrl)  * 1.0).clamp(0, 120000);
  double get _convExempt => (_val(_convCtrl) * 1.0).clamp(0, 30000);
  double get _netTaxable => (_totalIncome - _hraExempt - _medExempt - _convExempt).clamp(0, double.infinity);

  void _calculate() {
    final result = _compute(_netTaxable, _threshold);
    setState(() {
      _result = result;
      _showBreakdown = true;
    });
  }

  void _reset() {
    _basicCtrl.clear(); _hraCtrl.clear(); _medCtrl.clear();
    _convCtrl.clear();  _bonusCtrl.clear(); _otherCtrl.clear();
    setState(() { _result = null; _showBreakdown = false; });
  }

  @override
  void dispose() {
    _basicCtrl.dispose(); _hraCtrl.dispose(); _medCtrl.dispose();
    _convCtrl.dispose();  _bonusCtrl.dispose(); _otherCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surf,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Tax Calculator — FY 2024-25',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Reset', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Taxpayer category ─────────────────────────────────────────
            _Section(
              title: 'Taxpayer Category',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Male', 'Female', 'Senior (65+)', 'Disabled', 'Freedom Fighter']
                    .map((c) => _CategoryChip(
                          label: c,
                          selected: _category == c,
                          threshold: c == 'Male' ? 350000
                              : c == 'Freedom Fighter' ? 500000
                              : c == 'Disabled' ? 475000 : 400000,
                          onTap: () => setState(() => _category = c),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),

            // ── Income inputs ─────────────────────────────────────────────
            _Section(
              title: 'Annual Income Breakdown',
              child: Column(
                children: [
                  _IncomeRow('Basic Salary',          _basicCtrl),
                  _IncomeRow('House Rent Allowance',  _hraCtrl,  hint: 'Exempt: 50% up to ৳3L'),
                  _IncomeRow('Medical Allowance',     _medCtrl,  hint: 'Exempt: up to ৳1.2L'),
                  _IncomeRow('Conveyance Allowance',  _convCtrl, hint: 'Exempt: up to ৳30K'),
                  _IncomeRow('Festival Bonus',        _bonusCtrl),
                  _IncomeRow('Other Income',          _otherCtrl),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Live summary ──────────────────────────────────────────────
            if (_totalIncome > 0) ...[
              _Section(
                title: 'Income Summary',
                child: Column(
                  children: [
                    _SummaryRow('Total Gross Income',   _tk(_totalIncome),  bold: false),
                    _SummaryRow('HRA Exemption',        '− ${_tk(_hraExempt)}',  bold: false, color: _green),
                    _SummaryRow('Medical Exemption',    '− ${_tk(_medExempt)}',  bold: false, color: _green),
                    _SummaryRow('Conveyance Exemption', '− ${_tk(_convExempt)}', bold: false, color: _green),
                    const Divider(height: 20),
                    _SummaryRow('Net Taxable Income',   _tk(_netTaxable),   bold: true),
                    _SummaryRow('Tax-Free Threshold',   _tk(_threshold),    bold: false, color: _green),
                    _SummaryRow('Income Above Threshold', _tk((_netTaxable - _threshold).clamp(0, double.infinity)), bold: false),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Calculate button ──────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _totalIncome > 0 ? _calculate : null,
              icon: const Icon(Icons.calculate_rounded, size: 18),
              label: const Text('Calculate Tax', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            // ── Result ────────────────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: 20),

              // Tax result hero
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_navy, _navyL],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Text('Total Tax Payable',
                        style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(_tk(_result!.tax),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Monthly: ${_tk(_result!.tax / 12)}',
                        style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _ResultPill('Taxable', _tk(_result!.taxableIncome)),
                        const SizedBox(width: 10),
                        _ResultPill('Eff. Rate',
                            _netTaxable > 0
                                ? '${(_result!.tax / _netTaxable * 100).toStringAsFixed(1)}%'
                                : '0%'),
                        const SizedBox(width: 10),
                        _ResultPill('Monthly TDS', _tk(_result!.tax / 12)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Slab breakdown
              if (_result!.lines.isNotEmpty)
                _Section(
                  title: 'Slab-wise Breakdown',
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: const [
                            Expanded(child: Text('Slab', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey))),
                            SizedBox(width: 8),
                            SizedBox(width: 80, child: Text('Income', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey))),
                            SizedBox(width: 8),
                            SizedBox(width: 80, child: Text('Tax', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey))),
                          ],
                        ),
                      ),
                      // Free threshold row
                      _SlabRow('Free Threshold (0%)', _threshold, 0, isThreshold: true),
                      // Slab rows
                      ..._result!.lines.map((l) => _SlabRow(l.label, l.amount, l.tax)),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Text('Total Tax',
                              style: TextStyle(fontWeight: FontWeight.w900, color: _navy))),
                          Text(_tk(_result!.tax),
                              style: const TextStyle(fontWeight: FontWeight.w900, color: _navy, fontSize: 15)),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 14),

              // Copy result
              OutlinedButton.icon(
                onPressed: () {
                  final text = 'BD Tax FY 2024-25\n'
                      'Category: $_category\n'
                      'Gross Income: ${_tk(_totalIncome)}\n'
                      'Net Taxable: ${_tk(_netTaxable)}\n'
                      'Annual Tax: ${_tk(_result!.tax)}\n'
                      'Monthly TDS: ${_tk(_result!.tax / 12)}';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Result copied to clipboard'),
                        duration: Duration(seconds: 2)));
                },
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Copy Result'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: _navy),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── BD Tax rate reference card ────────────────────────────────
            _Section(
              title: 'FY 2024-25 Tax Rate Reference',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RateTable(),
                  const SizedBox(height: 12),
                  const Text(
                    'Company Tax Rates (FY 2024-25)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _navy),
                  ),
                  const SizedBox(height: 6),
                  _CompanyRateRow('Listed Company',       '22.5%'),
                  _CompanyRateRow('One Person Company',   '25.0%'),
                  _CompanyRateRow('Non-listed Company',   '27.5%'),
                  _CompanyRateRow('Bank / NBFI / Insurance', '37.5%'),
                  _CompanyRateRow('Tobacco Company',      '45.0%'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Text(
                      '⚠ This calculator is for guidance only. Always consult a certified tax consultant '
                      'or NBR for official filings. Rates may change per Finance Act.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 14, decoration: BoxDecoration(
                color: _navy, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _navy)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final double threshold;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.threshold, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _navy : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _navy : Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _navy)),
            Text('Free: ৳${(threshold / 100000).toStringAsFixed(1)}L',
                style: TextStyle(fontSize: 9, color: selected ? Colors.white60 : Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _IncomeRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  const _IncomeRow(this.label, this.ctrl, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
                if (hint != null)
                  Text(hint!, style: const TextStyle(fontSize: 10, color: Colors.green)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _navy),
              decoration: InputDecoration(
                prefixText: '৳ ',
                prefixStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                hintText: '0',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: _surf,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _navy)),
              ),
              onChanged: (_) => (context as Element).markNeedsBuild(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _SummaryRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (bold ? _navy : Colors.grey.shade700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(
              fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: c))),
          Text(value, style: TextStyle(
              fontSize: 12, fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}

class _SlabRow extends StatelessWidget {
  final String label;
  final double amount;
  final double tax;
  final bool isThreshold;
  const _SlabRow(this.label, this.amount, this.tax, {this.isThreshold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(
                fontSize: 12,
                color: isThreshold ? _green : Colors.grey.shade700,
                fontWeight: isThreshold ? FontWeight.w600 : FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(_tk(amount), textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: isThreshold ? _green : _navy, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(isThreshold ? '৳0' : _tk(tax), textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12,
                    color: isThreshold ? _green : _navy,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  final String label;
  final String value;
  const _ResultPill(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

Widget _RateTable() {
  final rows = [
    ('Up to ৳3,50,000 (Male)', '0%'),
    ('Up to ৳4,00,000 (Female/Senior)', '0%'),
    ('Up to ৳4,75,000 (Disabled)', '0%'),
    ('Up to ৳5,00,000 (Freedom Fighter)', '0%'),
    ('Next ৳1,00,000', '5%'),
    ('Next ৳4,00,000', '10%'),
    ('Next ৳5,00,000', '15%'),
    ('Next ৳5,00,000', '20%'),
    ('Remaining', '25%'),
  ];
  return Column(
    children: rows.map((r) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: r.$2 == '0%' ? Colors.green.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(r.$2, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800,
                color: r.$2 == '0%' ? _green : _navy)),
          ),
        ],
      ),
    )).toList(),
  );
}

Widget _CompanyRateRow(String label, String rate) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
          child: Text(rate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6B21A8))),
        ),
      ],
    ),
  );
}
