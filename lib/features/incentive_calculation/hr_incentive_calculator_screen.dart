import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

const Color _brandGreen = Color(0xFF065F46);
const Color _surface = Color(0xFFF8FAFC);

class HRIncentiveCalculatorScreen extends StatefulWidget {
  const HRIncentiveCalculatorScreen({super.key});

  @override
  State<HRIncentiveCalculatorScreen> createState() => _HRIncentiveCalculatorScreenState();
}

class _HRIncentiveCalculatorScreenState extends State<HRIncentiveCalculatorScreen> {
  String _cid = '';
  String? _selectedReportId;
  List<DocumentSnapshot> _salesReports = [];
  List<_IncentiveRow> _rows = [];
  bool _isLoading = false;
  final TextEditingController _rateController = TextEditingController(text: '0.15');
  bool _useTiered = false;
  List<_TierConfig> _tiers = [
    _TierConfig(minMargin: 0, rate: 0.05),
    _TierConfig(minMargin: 15, rate: 0.10),
    _TierConfig(minMargin: 25, rate: 0.15),
    _TierConfig(minMargin: 35, rate: 0.20),
  ];
  final List<TextEditingController> _tierMarginCtrls = [];
  final List<TextEditingController> _tierRateCtrls = [];

  void _initTierCtrls() {
    if (_tierMarginCtrls.isEmpty) {
      for (final t in _tiers) {
        _tierMarginCtrls.add(TextEditingController(text: t.minMargin.toString()));
        _tierRateCtrls.add(TextEditingController(text: t.rate.toStringAsFixed(2)));
      }
    }
  }

  double _effectiveRate(double grossMarginPercent) {
    if (!_useTiered) {
      return double.tryParse(_rateController.text.trim()) ?? 0.15;
    }
    double applied = _tiers.last.rate;
    for (final t in _tiers) {
      if (grossMarginPercent >= t.minMargin) {
        applied = t.rate;
      }
    }
    return applied;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    final id = await LocalStorageService.getSavedCompanyId();
    if (mounted) setState(() => _cid = id ?? '');
    await _loadSalesReports();
    setState(() => _isLoading = false);
  }

  Future<void> _loadSalesReports() async {
    final snapshot = await DB.colSync(_cid, C.marketingIncentives).get();
    if (mounted) {
      setState(() {
        _salesReports = snapshot.docs.where((doc) => doc.id.contains('_sales')).toList();
      });
    }
  }

  void _onReportSelected(String? docId) async {
    if (docId == null) return;
    setState(() => _isLoading = true);

    final snapshot = await DB.colSync(_cid, C.marketingIncentives).doc(docId).get();
    final data = snapshot.data();
    
    final rowsList = (data?['rows'] as List<dynamic>? ?? []).map((row) {
      return _IncentiveRow(
        product: row['productName'] ?? '',
        quantity: (row['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (row['sellingPrice'] as num?)?.toDouble() ?? 0,
        productCost: (row['purchaseCost'] as num?)?.toDouble() ?? 0,
        fixedCost: (row['fixedCost'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    setState(() {
      _selectedReportId = docId;
      _rows = rowsList;
      _isLoading = false;
    });
  }

  Future<void> _submit() async {
    if (_selectedReportId == null) return;

    if (_useTiered) _syncTiersFromCtrls();

    double totalIncentive = 0;
    double flatRate = double.tryParse(_rateController.text.trim()) ?? 0.15;

    final updatedRows = _rows.map((row) {
      final totalPrice = row.quantity * row.unitPrice;
      final prodCost = row.quantity * row.productCost;
      final profit = totalPrice - prodCost;
      final grossMargin = totalPrice > 0 ? (profit / totalPrice) * 100 : 0.0;
      final netProfit = profit * ((100 - row.fixedCost) / 100);
      final rate = _useTiered ? _effectiveRate(grossMargin) : flatRate;
      final incentive = netProfit * rate;
      totalIncentive += incentive;

      return {
        'productName': row.product,
        'quantity': row.quantity,
        'sellingPrice': row.unitPrice,
        'purchaseCost': row.productCost,
        'fixedCost': row.fixedCost,
        'grossMargin': grossMargin,
        'netProfit': netProfit,
        'appliedRate': rate,
        'incentive': incentive,
      };
    }).toList();

    await DB.colSync(_cid, C.marketingIncentives).doc(_selectedReportId!).update({
      'rows': updatedRows,
      'totalIncentive': totalIncentive,
      'incentiveRate': flatRate,
      'useTiered': _useTiered,
      'tiers': _tiers.map((t) => {'minMargin': t.minMargin, 'rate': t.rate}).toList(),
      'lastCalculatedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Incentive report updated successfully")),
    );

    _loadSalesReports();
  }

  @override
  Widget build(BuildContext context) {
    _initTierCtrls();
    double flatRate = double.tryParse(_rateController.text.trim()) ?? 0.15;
    double totalSales = 0;
    double totalIncentive = 0;
    double totalNetProfit = 0;

    for (var row in _rows) {
      final totalPrice = row.quantity * row.unitPrice;
      final prodCost = row.quantity * row.productCost;
      final profit = totalPrice - prodCost;
      final grossMargin = totalPrice > 0 ? (profit / totalPrice) * 100 : 0.0;
      final netProfit = profit * ((100 - row.fixedCost) / 100);
      final rate = _useTiered ? _effectiveRate(grossMargin) : flatRate;
      final incentive = netProfit * rate;
      totalSales += totalPrice;
      totalIncentive += incentive;
      totalNetProfit += netProfit;
    }

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text('Incentive Intelligence', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTopControls(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: _brandGreen)))
          else if (_selectedReportId == null)
            _buildEmptyState()
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                children: [
                  _SummaryDashboard(
                    totalSales: totalSales,
                    netProfit: totalNetProfit,
                    totalIncentive: totalIncentive,
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Product Breakdown', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                  ),
                  const SizedBox(height: 16),
                  ..._rows.map((row) {
                    final tp = row.quantity * row.unitPrice;
                    final pc = row.quantity * row.productCost;
                    final pft = tp - pc;
                    final gm = tp > 0 ? (pft / tp) * 100 : 0.0;
                    final nr = _useTiered ? _effectiveRate(gm) : flatRate;
                    return _IncentiveItemCard(
                      row: row,
                      rate: nr,
                      grossMargin: gm,
                      showTier: _useTiered,
                      onChanged: () => setState(() {}),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedReportId != null
          ? FloatingActionButton.extended(
              onPressed: _submit,
              backgroundColor: _brandGreen,
              label: Text('Save Calculation', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.check_circle_rounded),
            ).animate().scale()
          : null,
    );
  }

  void _syncTiersFromCtrls() {
    for (int i = 0; i < _tiers.length && i < _tierMarginCtrls.length; i++) {
      _tiers[i].minMargin = double.tryParse(_tierMarginCtrls[i].text) ?? _tiers[i].minMargin;
      _tiers[i].rate = double.tryParse(_tierRateCtrls[i].text) ?? _tiers[i].rate;
    }
  }

  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedReportId,
                  decoration: InputDecoration(
                    labelText: 'Select Sales Report',
                    labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _salesReports.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final incentive = data['totalIncentive'];
                    final label = incentive == null ? "${doc.id} (Pending)" : "${doc.id} (৳${incentive.toStringAsFixed(0)})";
                    return DropdownMenuItem(value: doc.id, child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: incentive == null ? Colors.black : _brandGreen, fontWeight: FontWeight.w600)));
                  }).toList(),
                  onChanged: _onReportSelected,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _rateController,
                  enabled: !_useTiered,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Rate',
                    labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _useTiered = !_useTiered),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _useTiered ? _brandGreen : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_useTiered ? 'TIERED' : 'FLAT RATE',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: _useTiered ? Colors.white : Colors.grey[600])),
                ),
              ),
              if (_useTiered) ...[
                const SizedBox(width: 8),
                Text('Gross Margin Tiers', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500])),
              ],
            ],
          ),
          if (_useTiered) ...[
            const SizedBox(height: 12),
            ...List.generate(_tiers.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: TextField(
                              controller: _tierMarginCtrls[i],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text('%+', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: TextField(
                              controller: _tierRateCtrls[i],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text('×', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('≥${_tierMarginCtrls[i].text}% → ${(double.tryParse(_tierRateCtrls[i].text) ?? 0) * 100}%',
                      style: GoogleFonts.dmSans(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text('Select a sales report to begin', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[400])),
          ],
        ).animate().fadeIn(),
      ),
    );
  }
}

class _SummaryDashboard extends StatelessWidget {
  final double totalSales, netProfit, totalIncentive;
  const _SummaryDashboard({required this.totalSales, required this.netProfit, required this.totalIncentive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_brandGreen, Color(0xFF0F643F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: _brandGreen.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryItem(label: 'TOTAL SALES', value: '৳${totalSales.toStringAsFixed(0)}'),
              _SummaryItem(label: 'NET PROFIT', value: '৳${netProfit.toStringAsFixed(0)}'),
            ],
          ),
          const Divider(height: 32, color: Colors.white24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFBDB4C), size: 32),
              const SizedBox(width: 12),
              Column(
                children: [
                  Text('ESTIMATED INCENTIVE', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.7), letterSpacing: 1.2)),
                  Text('৳${totalIncentive.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  const _SummaryItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.6), letterSpacing: 1)),
      Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
    ],
  );
}

class _IncentiveItemCard extends StatelessWidget {
  final _IncentiveRow row;
  final double rate;
  final double grossMargin;
  final bool showTier;
  final VoidCallback onChanged;
  const _IncentiveItemCard({required this.row, required this.rate, required this.grossMargin, this.showTier = false, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final totalPrice = row.quantity * row.unitPrice;
    final prodCost = row.quantity * row.productCost;
    final profit = totalPrice - prodCost;
    final netProfit = profit * ((100 - row.fixedCost) / 100);
    final incentive = netProfit * rate;

    return UCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.inventory_2_outlined, color: _brandGreen)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.product, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    Text('Qty: ${row.quantity} | Margin: ${grossMargin.toStringAsFixed(1)}% | Rate: ${(rate * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.dmSans(fontSize: 11, color: showTier ? _brandGreen : Colors.grey[500], fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('৳${incentive.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: _brandGreen)),
                  Text('INCENTIVE', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey[400])),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              _EditableField(label: 'Price', value: row.unitPrice.toString(), onChanged: (v) { row.unitPrice = double.tryParse(v) ?? 0; onChanged(); }),
              const SizedBox(width: 12),
              _EditableField(label: 'Cost', value: row.productCost.toString(), onChanged: (v) { row.productCost = double.tryParse(v) ?? 0; onChanged(); }),
              const SizedBox(width: 12),
              _EditableField(label: 'Fixed%', value: row.fixedCost.toString(), onChanged: (v) { row.fixedCost = double.tryParse(v) ?? 0; onChanged(); }),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final String label, value;
  final ValueChanged<String> onChanged;
  const _EditableField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
            TextField(
              controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
              onChanged: onChanged,
              keyboardType: TextInputType.number,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncentiveRow {
  final String product;
  int quantity;
  double unitPrice;
  double productCost;
  double fixedCost;

  _IncentiveRow({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.productCost,
    required this.fixedCost,
  });
}

class _TierConfig {
  double minMargin;
  double rate;
  _TierConfig({required this.minMargin, required this.rate});
}
