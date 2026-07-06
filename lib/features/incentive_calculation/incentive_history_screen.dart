import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

const Color _brandGreen = Color(0xFF065F46);

class IncentiveHistoryScreen extends StatefulWidget {
  const IncentiveHistoryScreen({super.key});

  @override
  State<IncentiveHistoryScreen> createState() => _IncentiveHistoryScreenState();
}

class _IncentiveHistoryScreenState extends State<IncentiveHistoryScreen> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final incentivesRef = _cid.isEmpty ? null : DB.colSync(_cid, C.marketingIncentives);

    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        title: Text('Payout Archives', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: incentivesRef?.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _brandGreen));

          final docs = snapshot.data!.docs
              .where((doc) =>
          doc.id.contains('_sales') &&
              (doc.data() as Map<String, dynamic>)['totalIncentive'] != null)
              .toList();

          if (docs.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final totalIncentive = (data['totalIncentive'] ?? 0.0).toDouble();
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? (data['lastCalculatedAt'] as Timestamp?)?.toDate();
              
              final agentId = doc.id.split('_sales').first;
              final parts = agentId.split('_');
              final email = parts.first;
              final month = parts.length >= 2 ? parts[1] : 'Unknown';
              final year = parts.length >= 3 ? parts[2] : 'Unknown';

              final formattedDate = timestamp != null
                  ? DateFormat.yMMMMd().format(timestamp.toLocal())
                  : 'N/A';

              return UCard(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                onTap: () => _showBreakdownDialog(context, data, email),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.receipt_long_outlined, color: _brandGreen),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                          Text('$month $year | $formattedDate', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('৳${totalIncentive.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: _brandGreen)),
                        Text('TOTAL', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('No payouts archived yet', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[400])),
        ],
      ),
    );
  }

  void _showBreakdownDialog(BuildContext context, Map<String, dynamic> data, String agent) {
    final rows = (data['rows'] as List<dynamic>? ?? []);
    final rate = (data['incentiveRate'] ?? 0.15).toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payout Breakdown', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                    Text('For $agent', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _brandGreen.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: _brandGreen.withOpacity(0.1))),
              child: Row(
                children: [
                  const Icon(Icons.percent_rounded, color: _brandGreen, size: 16),
                  const SizedBox(width: 8),
                  Text('CALCULATION RATE:', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w900, color: _brandGreen, letterSpacing: 1)),
                  const Spacer(),
                  Text('${(rate * 100).toStringAsFixed(1)}%', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: _brandGreen)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (ctx, i) {
                  final row = rows[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row['productName'] ?? 'Product', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                              Text('Qty: ${row['quantity']} | Profit: ৳${(row['netProfit'] ?? 0).toStringAsFixed(0)}', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Text('৳${(row['incentive'] ?? 0).toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: _brandGreen)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
