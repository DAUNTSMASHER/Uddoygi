// lib/features/hr/presentation/screens/accounts_payable_screen.dart
//
// Accounts Payable Screen — filters 'expenses' collection for unpaid/planned entries.
//  • Live Stream from Firestore
//  • Premium HR Green UI (Taste Skill)
//  • Quick actions for payment approval
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

class AccountsPayableScreen extends StatefulWidget {
  const AccountsPayableScreen({super.key});

  @override
  State<AccountsPayableScreen> createState() => _AccountsPayableScreenState();
}

class _AccountsPayableScreenState extends State<AccountsPayableScreen> {
  String _cid = '';
  final _money = UddoygiDesign.moneyFormat;
  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  Stream<QuerySnapshot> _payableStream() {
    return DB.colSync(_cid, C.expenses)
        .where('status', whereIn: ['planned', 'pending'])
        .orderBy('dueDate', descending: false)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [UddoygiDesign.hrBrandGreen, Color(0xFF059669)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Accounts Payable',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator(color: UddoygiDesign.hrBrandGreen))
          : StreamBuilder<QuerySnapshot>(
              stream: _payableStream(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: UddoygiDesign.hrBrandGreen));
                }

                final docs = snap.data?.docs ?? [];
                num totalPayable = 0;
                num dueToday = 0;
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                for (final d in docs) {
                  final m = d.data() as Map<String, dynamic>;
                  final amt = _toNum(m['amount']);
                  totalPayable += amt;

                  final ts = m['dueDate'];
                  if (ts is Timestamp) {
                    final dt = ts.toDate();
                    final dOnly = DateTime(dt.year, dt.month, dt.day);
                    if (dOnly.isAtSameMomentAs(today)) {
                      dueToday += amt;
                    }
                  }
                }

                return Column(
                  children: [
                    // Summary Row
                    Padding(
                      padding: const EdgeInsets.all(UddoygiDesign.space16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: 'Total Payables',
                              amount: '৳${_money.format(totalPayable)}',
                              icon: Icons.account_balance_wallet_rounded,
                              color: UddoygiDesign.hrBrandGreen,
                            ),
                          ),
                          const SizedBox(width: UddoygiDesign.space12),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Due Today',
                              amount: '৳${_money.format(dueToday)}',
                              icon: Icons.today_rounded,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                    ),

                    Expanded(
                      child: docs.isEmpty
                          ? _EmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final d = docs[index].data() as Map<String, dynamic>;
                                return _PayableTile(
                                  data: d,
                                  money: _money,
                                  dateFmt: _dateFmt,
                                ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }
}

class _SummaryCard extends StatelessWidget {
  final String title, amount;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.title, required this.amount, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return UCard(
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(amount, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _PayableTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat money;
  final DateFormat dateFmt;

  const _PayableTile({required this.data, required this.money, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final vendor = data['vendor'] as String? ?? 'Unknown Vendor';
    final category = data['category'] as String? ?? 'Expense';
    final amt = data['amount'] ?? 0;
    final dueTs = data['dueDate'];
    final due = dueTs is Timestamp ? dueTs.toDate() : DateTime.now();
    final isOverdue = due.isBefore(DateTime.now());

    return UCard(
      margin: const EdgeInsets.only(bottom: UddoygiDesign.space12),
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: UddoygiDesign.hrBrandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.business_rounded, color: UddoygiDesign.hrBrandGreen, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vendor, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E0040))),
                const SizedBox(height: 2),
                Text('$category • Due ${dateFmt.format(due)}', 
                     style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: isOverdue ? const Color(0xFFDC2626) : Colors.grey[500])),
              ],
            ),
          ),
          Text('৳${money.format(amt)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: UddoygiDesign.hrBrandGreen)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('All caught up!', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey[400])),
          Text('No pending payables found.', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[400])),
        ],
      ),
    );
  }
}
