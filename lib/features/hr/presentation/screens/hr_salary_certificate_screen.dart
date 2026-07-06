import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);

// ─────────────────────────────────────────────────────────────────────────────
class HrSalaryCertificateScreen extends StatefulWidget {
  const HrSalaryCertificateScreen({super.key});
  @override
  State<HrSalaryCertificateScreen> createState() => _HrSalaryCertificateScreenState();
}

class _HrSalaryCertificateScreenState extends State<HrSalaryCertificateScreen> {
  final _certNoCtrl = TextEditingController();
  final _basicCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    // company id loading placeholder
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Certificate Center', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(UddoygiDesign.space20),
        children: [
          _StepHeader(number: '01', title: 'IDENTIFY RECIPIENT').animate().fadeIn(),
          const SizedBox(height: 12),
          _EmployeeSelector(onSelected: (v) {}).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 24),
          _StepHeader(number: '02', title: 'FINANCIAL DATA').animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          UCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _ModernField(label: 'Certificate Reference', controller: _certNoCtrl, hint: 'SC/2024/789'),
                const SizedBox(height: 16),
                _ModernField(label: 'Basic Salary (Confirmed)', controller: _basicCtrl, hint: '50,000', prefix: '৳ '),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.verified_user_rounded),
              label: Text('ISSUE CERTIFICATE', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
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

class _EmployeeSelector extends StatelessWidget {
  final ValueChanged<Map<String, dynamic>> onSelected;
  const _EmployeeSelector({required this.onSelected});
  @override
  Widget build(BuildContext context) => UCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const Icon(Icons.supervised_user_circle_rounded, color: _brandGreen),
        const SizedBox(width: 14),
        Expanded(child: Text('Search active employee...', style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontWeight: FontWeight.w600))),
        const Icon(Icons.search_rounded, color: Colors.grey),
      ],
    ),
  );
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
