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
class HRWelfareScreen extends StatefulWidget {
  const HRWelfareScreen({super.key});
  @override
  State<HRWelfareScreen> createState() => _HRWelfareScreenState();
}

class _HRWelfareScreenState extends State<HRWelfareScreen> {
  String _cid = '';
  String _filter = 'All';

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
        title: Text('Welfare Oversight', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: Column(
        children: [
          _WelfareStats(cid: _cid).animate().fadeIn().slideY(begin: -0.1, end: 0),
          _FilterBar(selected: _filter, onSelected: (v) => setState(() => _filter = v)),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: DB.firestore.collection('welfare_requests').orderBy('submittedAt', descending: true).snapshots(),
              builder: (ctx, snap) {
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) => _filter == 'All' || d['status'] == _filter).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(UddoygiDesign.space20),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _WelfareRequestCard(doc: filtered[i]).animate().fadeIn(delay: (i * 50).ms),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WelfareStats extends StatelessWidget {
  final String cid;
  const _WelfareStats({required this.cid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: StreamBuilder<QuerySnapshot>(
        stream: DB.firestore.collection('welfare_requests').snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? [];
          final pending = docs.where((d) => d['status'] == 'Pending HR').length;
          return Row(
            children: [
              _StatBit(label: 'URGENT REVIEW', value: '$pending', color: const Color(0xFFF59E0B)),
              const SizedBox(width: 32),
              _StatBit(label: 'TOTAL REQUESTS', value: '${docs.length}', color: _brandGreen),
              const Spacer(),
              const Icon(Icons.volunteer_activism_rounded, color: _brandGreen, size: 40),
            ],
          );
        },
      ),
    );
  }
}

class _StatBit extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBit({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey)),
      Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
    ],
  );
}

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const _FilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = ['All', 'Pending HR', 'Pending Admin', 'Approved', 'Rejected'];
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final active = selected == items[i];
          return GestureDetector(
            onTap: () => onSelected(items[i]),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: active ? _brandGreen : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? _brandGreen : Colors.grey.withOpacity(0.1))),
              alignment: Alignment.center,
              child: Text(items[i].toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.grey[600])),
            ),
          );
        },
      ),
    );
  }
}

class _WelfareRequestCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _WelfareRequestCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final status = d['status'] ?? 'Pending HR';
    Color statusColor = const Color(0xFFF59E0B);
    if (status == 'Approved') statusColor = const Color(0xFF16A34A);
    if (status == 'Rejected' || status == 'Declined') statusColor = const Color(0xFFDC2626);
    if (status == 'Pending Admin') statusColor = const Color(0xFF6366F1);

    return UCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(d['employeeName']?[0] ?? '?', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _brandGreen)))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['employeeName'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    Text(d['schemeTitle']?.toString().toUpperCase() ?? 'WELFARE SCHEME', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                  ],
                ),
              ),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status.toUpperCase(), style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800))),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(d['reason'] ?? 'Employee welfare assistance request.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey[600]))),
              if (status == 'Pending HR') ...[
                IconButton(onPressed: () {}, icon: const Icon(Icons.verified_rounded, color: Color(0xFF16A34A))),
                IconButton(onPressed: () {}, icon: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
