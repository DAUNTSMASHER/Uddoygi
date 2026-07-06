import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────
final _money      = UddoygiDesign.moneyFormat;

// ── Main Screen ─────────────────────────────────────────────────────────────
class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key});
  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> with SingleTickerProviderStateMixin {
  String _cid = '';
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Tax Management', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'TDS Registry'), Tab(text: 'Challans'), Tab(text: 'Filing'), Tab(text: 'TINs')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TdsTab(cid: _cid),
          _ChallanTab(cid: _cid),
          _FilingTab(cid: _cid),
          _TinTab(cid: _cid),
        ],
      ),
    );
  }
}

class _TdsTab extends StatelessWidget {
  final String cid;
  const _TdsTab({required this.cid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(cid, C.taxes).where('category', isEqualTo: 'tds').snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(UddoygiDesign.space20),
          children: [
            _TabHeader(title: 'TDS Deductions', subtitle: 'Monthly salary tax tracking', icon: Icons.receipt_long_rounded, color: const Color(0xFF0F172A)),
            const SizedBox(height: 20),
            if (docs.isEmpty) const _EmptyState() else ...docs.map((d) => _TaxCard(data: d.data()).animate().fadeIn().slideY(begin: 0.1, end: 0)),
          ],
        );
      },
    );
  }
}

class _ChallanTab extends StatelessWidget {
  final String cid;
  const _ChallanTab({required this.cid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(cid, C.taxes).where('category', isEqualTo: 'challan').snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(UddoygiDesign.space20),
          children: [
            _TabHeader(title: 'Treasury Challans', subtitle: 'NBR deposit records', icon: Icons.account_balance_rounded, color: const Color(0xFF16A34A)),
            const SizedBox(height: 20),
            if (docs.isEmpty) const _EmptyState() else ...docs.map((d) => _TaxCard(data: d.data(), isChallan: true).animate().fadeIn().slideY(begin: 0.1, end: 0)),
          ],
        );
      },
    );
  }
}

class _FilingTab extends StatelessWidget {
  final String cid;
  const _FilingTab({required this.cid});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Annual Filing Module', style: GoogleFonts.outfit(color: Colors.grey)));
  }
}

class _TinTab extends StatelessWidget {
  final String cid;
  const _TinTab({required this.cid});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('TIN Registry Module', style: GoogleFonts.outfit(color: Colors.grey)));
  }
}

class _TabHeader extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  const _TabHeader({required this.title, required this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
            Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

class _TaxCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isChallan;
  const _TaxCard({required this.data, this.isChallan = false});

  @override
  Widget build(BuildContext context) {
    final amount = (data['amount'] ?? data['tdsAmount'] ?? 0.0).toDouble();
    return UCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['employeeName'] ?? data['challanNo'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    Text(data['month'] ?? data['taxYear'] ?? 'Current Period', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('৳ ${_money.format(amount)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFDC2626))),
                  Text(isChallan ? 'CHALLAN' : 'TDS', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[300])),
                ],
              ),
            ],
          ),
          if (data['bankName'] != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.account_balance_outlined, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Text(data['bankName'], style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                const Spacer(),
                Text(data['depositDate'] ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.receipt_outlined, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('No tax records found', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[400])),
        ],
      ),
    );
  }
}
