import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminCampaignsScreen extends StatefulWidget {
  const AdminCampaignsScreen({super.key});

  @override
  State<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends State<AdminCampaignsScreen> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    _loadCid();
  }

  Future<void> _loadCid() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (mounted) setState(() => _cid = id ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        title: Text('Marketing Campaigns', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF1E0040), // _heroPurple
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DB.colSync(_cid, C.campaigns).snapshots(),
        builder: (context, campSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: DB.colSync(_cid, C.customers).snapshots(),
            builder: (context, custSnap) {
              if (!campSnap.hasData || !custSnap.hasData) return const Center(child: CircularProgressIndicator());
              
              final campaigns = campSnap.data!.docs;
              final customers = custSnap.data!.docs;
              final stats = _calculateCampaignStats(campaigns, customers);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: UddoygiDesign.space20, vertical: UddoygiDesign.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(stats),
                    const SizedBox(height: UddoygiDesign.space32),
                    Text('Active Promotions', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: UddoygiDesign.space16),
                    _buildActivePromotions(campaigns),
                    const SizedBox(height: UddoygiDesign.space32),
                    Text('Lead Sources', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: UddoygiDesign.space16),
                    _buildLeadSourceBreakdown(customers),
                    const SizedBox(height: UddoygiDesign.space32),
                    _buildROITracker(campaigns),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(_CampaignStats stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard('Active Promos', '${stats.activeCount}', Icons.campaign_rounded, const Color(0xFF7C3AED)),
        _buildStatCard('Total Leads', '${stats.totalLeads}', Icons.group_add_rounded, Colors.blue),
        _buildStatCard('Avg ROI', '${stats.avgROI.toStringAsFixed(1)}x', Icons.pie_chart_rounded, Colors.green),
        _buildStatCard('Total Spend', '৳${NumberFormat('#,###').format(stats.totalSpend)}', Icons.payments_rounded, Colors.redAccent),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return UCard(
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF1E0040), letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildActivePromotions(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return UCard(
        padding: const EdgeInsets.all(UddoygiDesign.space24),
        child: Center(
          child: Text('No active campaigns', style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ),
      );
    }
    
    return Column(
      children: docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return UCard(
          margin: const EdgeInsets.only(bottom: UddoygiDesign.space12),
          padding: const EdgeInsets.all(UddoygiDesign.space16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
                child: const Icon(Icons.star_rounded, color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: UddoygiDesign.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['name'] ?? 'Promo', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(d['description'] ?? 'Ongoing deal', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Text(
                '৳${NumberFormat('#,###').format(d['spend'] ?? 0)}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.redAccent, fontSize: 15),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeadSourceBreakdown(List<QueryDocumentSnapshot> docs) {
    Map<String, int> sources = {};
    for (var doc in docs) {
      final s = (doc.data() as Map)['source'] ?? 'Referrals';
      sources[s] = (sources[s] ?? 0) + 1;
    }

    return UCard(
      padding: const EdgeInsets.all(UddoygiDesign.space24),
      child: Column(
        children: sources.entries.map((e) {
          final val = e.value / (docs.isEmpty ? 1 : docs.length);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(e.key, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
                    const Spacer(),
                    Text('${e.value} leads', style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(UddoygiDesign.radiusFull),
                  child: LinearProgressIndicator(
                    value: val,
                    minHeight: 8,
                    color: Colors.blue,
                    backgroundColor: Colors.blue.withOpacity(0.08),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildROITracker(List<QueryDocumentSnapshot> campaigns) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(UddoygiDesign.space24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E0040), Color(0xFF4C1D95)],
        ),
        borderRadius: BorderRadius.circular(UddoygiDesign.radiusXL),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E0040).withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 10),
              Text(
                'ROI Tracker',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: UddoygiDesign.space24),
          if (campaigns.isEmpty)
            Text('No data for ROI analysis', style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 14)),
          ...campaigns.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final spend = (d['spend'] as num?)?.toDouble() ?? 1;
            final rev = (d['revenueGenerated'] as num?)?.toDouble() ?? 0;
            final roi = rev / (spend == 0 ? 1 : spend);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    d['name'] ?? 'Campaign',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), borderRadius: UddoygiDesign.borderFull),
                    child: Text(
                      '${roi.toStringAsFixed(1)}x ROI',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.greenAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0);
  }

  _CampaignStats _calculateCampaignStats(List<QueryDocumentSnapshot> camp, List<QueryDocumentSnapshot> cust) {
    double totalSpend = 0;
    double totalRev = 0;
    for (var c in camp) {
      final d = c.data() as Map;
      totalSpend += (d['spend'] as num?)?.toDouble() ?? 0;
      totalRev += (d['revenueGenerated'] as num?)?.toDouble() ?? 0;
    }
    return _CampaignStats(
      activeCount: camp.length,
      totalLeads: cust.length,
      avgROI: totalSpend == 0 ? 0 : totalRev / totalSpend,
      totalSpend: totalSpend,
    );
  }
}

class _CampaignStats {
  final int activeCount;
  final int totalLeads;
  final double avgROI;
  final double totalSpend;
  _CampaignStats({required this.activeCount, required this.totalLeads, required this.avgROI, required this.totalSpend});
}


  _CampaignStats _calculateCampaignStats(List<QueryDocumentSnapshot> camp, List<QueryDocumentSnapshot> cust) {
    double totalSpend = 0;
    double totalRev = 0;
    for (var c in camp) {
      final d = c.data() as Map;
      totalSpend += (d['spend'] as num?)?.toDouble() ?? 0;
      totalRev += (d['revenueGenerated'] as num?)?.toDouble() ?? 0;
    }
    return _CampaignStats(
      activeCount: camp.length,
      totalLeads: cust.length,
      avgROI: totalSpend == 0 ? 0 : totalRev / totalSpend,
      totalSpend: totalSpend,
    );
  }
}

class _CampaignStats {
  final int activeCount;
  final int totalLeads;
  final double avgROI;
  final double totalSpend;
  _CampaignStats({required this.activeCount, required this.totalLeads, required this.avgROI, required this.totalSpend});
}
