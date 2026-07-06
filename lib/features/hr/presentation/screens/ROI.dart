import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);

// ── Models ────────────────────────────────────────────────────────────────
class _DateRange {
  final DateTime from, to;
  final String label;
  const _DateRange({required this.from, required this.to, required this.label});
  static _DateRange thisMonth() {
    final now = DateTime.now();
    return _DateRange(from: DateTime(now.year, now.month, 1), to: DateTime(now.year, now.month + 1, 0), label: 'This Month');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class ROIPage extends StatefulWidget {
  const ROIPage({super.key});
  @override
  State<ROIPage> createState() => _ROIPageState();
}

class _ROIPageState extends State<ROIPage> {
  String _cid = '';
  _DateRange _range = _DateRange.thisMonth();

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) { if (mounted) setState(() => _cid = id ?? ''); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Investment Analytics', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(UddoygiDesign.space20),
        children: [
          _HeroCard(range: _range).animate().fadeIn().slideY(begin: -0.1, end: 0),
          const SizedBox(height: 28),
          _SectionTitle(title: 'DEPARTMENT PERFORMANCE'),
          const SizedBox(height: 14),
          _DeptRoiCard(dept: 'Marketing', roi: 18.5, color: const Color(0xFF16A34A)),
          const SizedBox(height: 12),
          _DeptRoiCard(dept: 'Operations', roi: 12.2, color: const Color(0xFF2563EB)),
          const SizedBox(height: 12),
          _DeptRoiCard(dept: 'HR & Admin', roi: -2.4, color: const Color(0xFFDC2626)),
          const SizedBox(height: 32),
          _SectionTitle(title: 'TOP PERFORMERS'),
          const SizedBox(height: 12),
          _EmployeeList(cid: _cid),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final _DateRange range;
  const _HeroCard({required this.range});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_brandGreen, Color(0xFF052E16)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: _brandGreen.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AGGREGATE HR ROI', style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Text('14.8%', style: GoogleFonts.outfit(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(range.label, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey[400], letterSpacing: 1.5));
}

class _DeptRoiCard extends StatelessWidget {
  final String dept;
  final double roi;
  final Color color;
  const _DeptRoiCard({required this.dept, required this.roi, required this.color});

  @override
  Widget build(BuildContext context) => UCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(width: 4, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(dept, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800)), Text('ROI Score', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey))])),
        Text('${roi > 0 ? '+' : ''}$roi%', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      ],
    ),
  );
}

class _EmployeeList extends StatelessWidget {
  final String cid;
  const _EmployeeList({required this.cid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: cid.isEmpty ? const Stream.empty() : DB.colSync(cid, C.users).limit(5).snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox();
        return Column(
          children: docs.map((d) {
            final m = d.data() as Map<String, dynamic>;
            return UCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: _brandGreen.withOpacity(0.1), radius: 18, child: Text(m['fullName']?[0] ?? '?', style: GoogleFonts.outfit(color: _brandGreen, fontWeight: FontWeight.w800, fontSize: 12))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['fullName'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800)), Text(m['department'] ?? 'General', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey))])),
                  const Icon(Icons.trending_up_rounded, color: Colors.green, size: 16),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
