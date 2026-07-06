import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);

// ─────────────────────────────────────────────────────────────────────────────
class ProcurementScreen extends StatefulWidget {
  const ProcurementScreen({super.key});
  @override
  State<ProcurementScreen> createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends State<ProcurementScreen> with SingleTickerProviderStateMixin {
  String _cid = '';
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) { if (mounted) setState(() => _cid = id ?? ''); });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Procurement Hub', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _brandGreen,
          indicatorWeight: 3,
          labelColor: _brandGreen,
          unselectedLabelColor: Colors.grey[400],
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
          tabs: const [Tab(text: 'PENDING'), Tab(text: 'APPROVED'), Tab(text: 'RECEIVED')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProcList(cid: _cid, status: 'Pending'),
          _ProcList(cid: _cid, status: 'Approved'),
          _ProcList(cid: _cid, status: 'Received'),
        ],
      ),
    );
  }
}

class _ProcList extends StatelessWidget {
  final String cid, status;
  const _ProcList({required this.cid, required this.status});

  @override
  Widget build(BuildContext context) {
    if (cid.isEmpty) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(cid, C.procurements).where('status', isEqualTo: status).snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _EmptyState(status: status);
        return ListView.builder(
          padding: const EdgeInsets.all(UddoygiDesign.space20),
          itemCount: docs.length,
          itemBuilder: (_, i) => _ProcCard(doc: docs[i]).animate().fadeIn(delay: (i * 50).ms).slideX(begin: 0.1, end: 0),
        );
      },
    );
  }
}

class _ProcCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _ProcCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    return UCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.inventory_2_rounded, color: _brandGreen, size: 22)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d['item'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800)), Text('Qty: ${d['quantity']}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey))])),
              Text('৳${d['amount']}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: _brandGreen)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Meta(label: 'REQUESTED BY', value: d['requestedByName'] ?? 'Admin'),
              _Meta(label: 'DEPARTMENT', value: (d['requestedByDept'] ?? 'HR').toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final String label, value;
  const _Meta({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 0.5)), Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)))]);
}

class _EmptyState extends StatelessWidget {
  final String status;
  const _EmptyState({required this.status});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[200]), const SizedBox(height: 16), Text('No $status requests', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[400]))]));
}
