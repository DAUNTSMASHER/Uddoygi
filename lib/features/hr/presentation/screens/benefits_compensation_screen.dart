import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/theme/app_fonts.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);
final _money      = UddoygiDesign.moneyFormat;

// ─────────────────────────────────────────────────────────────────────────────
class BenefitsCompensationScreen extends StatefulWidget {
  const BenefitsCompensationScreen({super.key});
  @override
  State<BenefitsCompensationScreen> createState() => _BenefitsCompensationScreenState();
}

class _BenefitsCompensationScreenState extends State<BenefitsCompensationScreen> {
  String _cid = '';
  String _selectedType = 'All';
  String _searchEmployee = '';
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Benefits Registry', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf_rounded, color: _brandGreen), onPressed: _exportPdf),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBenefitSheet(context),
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Issue Benefit', style: AppFonts.banglaHeading(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          _BenefitHeader(
            selectedType: _selectedType,
            onTypeChanged: (v) => setState(() => _selectedType = v),
            onSearch: (v) => setState(() => _searchEmployee = v),
          ).animate().fadeIn().slideY(begin: -0.1, end: 0),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: DB.colSync(_cid, C.benefits).orderBy('date', descending: true).snapshots(),
              builder: (ctx, snap) {
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final matchesType = _selectedType == 'All' || data['type'] == _selectedType;
                  final matchesEmp  = data['employee'].toString().toLowerCase().contains(_searchEmployee.toLowerCase());
                  return matchesType && matchesEmp;
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(UddoygiDesign.space20),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _BenefitCard(doc: filtered[i]).animate().fadeIn(delay: (i * 50).ms),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBenefitSheet(BuildContext context) {}
  Future<void> _exportPdf() async {}
}

class _BenefitHeader extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onSearch;
  const _BenefitHeader({required this.selectedType, required this.onTypeChanged, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final types = ['All', 'Bonus', 'Incentive', 'Allowance'];
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search employee...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: types.map((t) {
                final active = selectedType == t;
                return GestureDetector(
                  onTap: () => onTypeChanged(t),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: active ? _brandGreen : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? _brandGreen : Colors.grey.withOpacity(0.2))),
                    child: Text(t.toUpperCase(), style: AppFonts.banglaHeading(fontSize: 10, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.grey[600])),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _BenefitCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final type = d['type'] ?? 'Bonus';
    Color typeColor = Colors.green;
    if (type == 'Incentive') typeColor = Colors.orange;
    if (type == 'Allowance') typeColor = Colors.indigo;

    return UCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: Icon(Icons.stars_rounded, color: typeColor))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['employee'] ?? 'Unknown', style: AppFonts.banglaHeading(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                Text(type.toString().toUpperCase(), style: AppFonts.banglaHeading(fontSize: 10, fontWeight: FontWeight.w800, color: typeColor)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('৳ ${_money.format(d['amount'] ?? 0)}', style: AppFonts.banglaData(fontSize: 16, fontWeight: FontWeight.w900, color: _brandGreen)),
              Text(DateFormat('MMM d, yyyy').format((d['date'] as Timestamp).toDate()), style: AppFonts.banglaHeading(fontSize: 9, color: Colors.grey[400], fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
