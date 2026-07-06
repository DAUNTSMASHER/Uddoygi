import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);
final _money      = UddoygiDesign.moneyFormat;

// ── BD FY 2024-25 Logic ──────────────────────────────────────────────────────
const _slabSizes = [100000.0, 400000.0, 500000.0, 500000.0];
const _slabRates = [0.05, 0.10, 0.15, 0.20];
const _topRate   = 0.25;

// ─────────────────────────────────────────────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Tax Analytics', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
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
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {},
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
    final categories = ['Male', 'Female', 'Senior', 'Disabled'];
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
