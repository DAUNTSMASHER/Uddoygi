import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────
final _money      = UddoygiDesign.moneyFormat;
const _brandGreen = Color(0xFF065F46);

// ─────────────────────────────────────────────────────────────────────────────
class LoanApprovalScreen extends StatefulWidget {
  const LoanApprovalScreen({super.key});
  @override
  State<LoanApprovalScreen> createState() => _LoanApprovalScreenState();
}

class _LoanApprovalScreenState extends State<LoanApprovalScreen> with SingleTickerProviderStateMixin {
  String _cid = '';
  late TabController _tabs;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
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
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Loan Management', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14),
          tabs: const [Tab(text: 'PENDING'), Tab(text: 'HISTORY')],
        ),
      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                _StatsOverview(cid: _cid).animate().fadeIn().slideY(begin: -0.1, end: 0),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _LoanList(cid: _cid, pendingOnly: true, search: _search),
                      _LoanList(cid: _cid, pendingOnly: false, search: _search),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatsOverview extends StatelessWidget {
  final String cid;
  const _StatsOverview({required this.cid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: _brandGreen,
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: DB.colSync(cid, C.loans).where('status', whereIn: ['approved', 'disbursed']).snapshots(),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              double total = 0;
              for (var d in docs) total += (d['amount'] as num? ?? 0).toDouble();
              return Row(
                children: [
                  _SummaryBit(label: 'ACTIVE PRINCIPAL', value: '৳ ${_money.format(total)}', color: Colors.white),
                  const Spacer(),
                  _SummaryBit(label: 'PENDING TASKS', value: '${docs.length}', color: Colors.white.withOpacity(0.7)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryBit extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryBit({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: color.withOpacity(0.6))),
      Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
    ],
  );
}

class _LoanList extends StatelessWidget {
  final String cid, search;
  final bool pendingOnly;
  const _LoanList({required this.cid, required this.pendingOnly, required this.search});

  @override
  Widget build(BuildContext context) {
    Query q = DB.colSync(cid, C.loans).orderBy('requestedAt', descending: true);
    if (pendingOnly) q = q.where('status', isEqualTo: 'pending');

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        return ListView.builder(
          padding: const EdgeInsets.all(UddoygiDesign.space20),
          itemCount: docs.length,
          itemBuilder: (ctx, i) => _LoanRequestCard(doc: docs[i]).animate().fadeIn(delay: (i * 50).ms),
        );
      },
    );
  }
}

class _LoanRequestCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _LoanRequestCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final status = d['status'] ?? 'pending';
    Color statusColor = const Color(0xFFF59E0B);
    if (status == 'approved' || status == 'disbursed') statusColor = const Color(0xFF16A34A);
    if (status == 'rejected') statusColor = const Color(0xFFDC2626);

    return UCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(d['userEmail']?[0].toUpperCase() ?? '?', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _brandGreen)))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['userEmail'] ?? 'Unknown Employee', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    Text('${d['type']?.toUpperCase() ?? 'LOAN'} • ${d['durationMonths']} MONTHS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('৳ ${_money.format(d['amount'] ?? 0)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: _brandGreen)),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(status.toUpperCase(), style: GoogleFonts.outfit(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800))),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(d['purpose'] ?? 'General financial assistance', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey[600]))),
              if (status == 'pending') ...[
                IconButton(onPressed: () {}, icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A))),
                IconButton(onPressed: () {}, icon: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
