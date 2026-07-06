import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);

// ─────────────────────────────────────────────────────────────────────────────
class HrAuthorizationScreen extends StatelessWidget {
  const HrAuthorizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Authorization Portal', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(UddoygiDesign.space20),
        children: [
          _HeroBanner().animate().fadeIn().slideY(begin: -0.1, end: 0),
          const SizedBox(height: 28),
          _SectionTitle(title: 'DOCUMENTS REQUIRING AUTH'),
          const SizedBox(height: 14),
          _DocTypeCard(
            icon: Icons.workspace_premium_rounded,
            title: 'Salary Certificate',
            subtitle: 'Official financial certification for bank/visa needs.',
            onTap: () => Navigator.pushNamed(context, '/hr/salary_certificate'),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 16),
          _DocTypeCard(
            icon: Icons.assignment_ind_rounded,
            title: 'Appointment Letter',
            subtitle: 'Legally binding offers for workforce onboarding.',
            onTap: () => Navigator.pushNamed(context, '/hr/appointment_letter'),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 32),
          _SectionTitle(title: 'RECENTLY ISSUED'),
          const SizedBox(height: 12),
          const _RecentDocs(),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(gradient: LinearGradient(colors: [_brandGreen, _brandGreen.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
    child: Row(
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Document Issuance', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('Generate and verify official HR documents with high precision.', style: GoogleFonts.plusJakartaSans(color: Colors.white.withOpacity(0.8), fontSize: 13))])),
        Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28)),
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

class _DocTypeCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _DocTypeCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => UCard(
    onTap: onTap,
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: _brandGreen)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))), const SizedBox(height: 2), Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500]))])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      ],
    ),
  );
}

class _RecentDocs extends StatefulWidget {
  const _RecentDocs();
  @override
  State<_RecentDocs> createState() => _RecentDocsState();
}

class _RecentDocsState extends State<_RecentDocs> {
  String _cid = '';
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) { if (mounted) setState(() => _cid = id ?? ''); });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.hrDocuments).orderBy('createdAt', descending: true).limit(5).snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return Center(child: Text('No historical data found.', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)));
        return Column(
          children: docs.map((d) {
            final m = d.data() as Map<String, dynamic>;
            return UCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: _brandGreen.withOpacity(0.1), radius: 18, child: Text(m['employeeName']?.characters.first ?? '?', style: GoogleFonts.outfit(color: _brandGreen, fontWeight: FontWeight.w800, fontSize: 12))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['employeeName'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800)), Text(m['type'] ?? 'Document', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey))])),
                  Text(DateFormat('MMM d').format((m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()), style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
