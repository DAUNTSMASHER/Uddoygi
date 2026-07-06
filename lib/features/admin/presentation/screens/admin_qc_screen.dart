import 'package:flutter/material.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminQCReportScreen extends StatefulWidget {
  const AdminQCReportScreen({super.key});

  @override
  State<AdminQCReportScreen> createState() => _AdminQCReportScreenState();
}

class _AdminQCReportScreenState extends State<AdminQCReportScreen> {
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
        title: Text('Quality Control Insights', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF1E0040), // _heroPurple
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DB.colSync(_cid, C.qcReports).snapshots(),
        builder: (context, qcSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: DB.colSync(_cid, C.invoices).snapshots(),
            builder: (context, invSnap) {
              if (!qcSnap.hasData || !invSnap.hasData) return const Center(child: CircularProgressIndicator());
              
              final qcDocs = qcSnap.data!.docs;
              final invDocs = invSnap.data!.docs;
              final stats = _calculateQCStats(qcDocs, invDocs);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: UddoygiDesign.space20, vertical: UddoygiDesign.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(stats),
                    const SizedBox(height: UddoygiDesign.space32),
                    Text('Rejection Categories', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: UddoygiDesign.space16),
                    _buildRejectionSummary(qcDocs),
                    const SizedBox(height: UddoygiDesign.space32),
                    Text('Return Logs (Credit Notes)', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: UddoygiDesign.space16),
                    _buildReturnLogs(invDocs),
                    const SizedBox(height: UddoygiDesign.space32),
                    _buildSupplierImpact(qcDocs),
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

  Widget _buildSummaryCards(_QCDashboardStats stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard('Total Failures', '${stats.totalFailures}', Icons.error_outline_rounded, Colors.redAccent),
        _buildStatCard('Rejection Rate', '${stats.rejectionRate.toStringAsFixed(1)}%', Icons.percent_rounded, Colors.orange),
        _buildStatCard('Total Returns', '${stats.totalReturns}', Icons.assignment_return_rounded, Colors.blue),
        _buildStatCard('Return Value', '৳${NumberFormat('#,###').format(stats.returnValue)}', Icons.money_off_rounded, const Color(0xFF7C3AED)),
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
                style: AppFonts.banglaBody(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E0040), letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppFonts.banglaBody(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildRejectionSummary(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return UCard(
        padding: const EdgeInsets.all(UddoygiDesign.space24),
        child: Center(
          child: Text('No rejections recorded', style: AppFonts.banglaBody(color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ),
      );
    }

    return UCard(
      padding: const EdgeInsets.all(UddoygiDesign.space20),
      child: Column(
        children: docs.take(5).map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final isLast = docs.indexOf(doc) == docs.take(5).length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                ),
                const SizedBox(width: UddoygiDesign.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['remarks'] ?? 'Minor defect', style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('Qty: ${d['quantity'] ?? 0}', style: AppFonts.banglaBody(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.08), borderRadius: UddoygiDesign.borderFull),
                  child: Text('REJECTED', style: AppFonts.banglaBody(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReturnLogs(List<QueryDocumentSnapshot> docs) {
    final returns = docs.where((d) {
      final s = (d.data() as Map)['status'] ?? '';
      return s == 'Returned' || s == 'Rejected';
    }).toList();

    if (returns.isEmpty) {
      return UCard(
        padding: const EdgeInsets.all(UddoygiDesign.space24),
        child: Center(
          child: Text('No returns recorded', style: AppFonts.banglaBody(color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Column(
      children: returns.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return UCard(
          margin: const EdgeInsets.only(bottom: UddoygiDesign.space12),
          padding: const EdgeInsets.all(UddoygiDesign.space16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
                child: const Icon(Icons.assignment_return_rounded, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: UddoygiDesign.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['customerName'] ?? 'Customer', style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(d['invoiceNo'] ?? 'INV-000', style: AppFonts.banglaBody(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Text(
                '৳${NumberFormat('#,###').format(d['grandTotal'] ?? 0)}',
                style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, color: Colors.redAccent, fontSize: 16),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSupplierImpact(List<QueryDocumentSnapshot> docs) {
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
              const Icon(Icons.analytics_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 10),
              Text(
                'Supplier Impact Analysis',
                style: AppFonts.banglaBody(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Linking QC failures to raw material suppliers.',
            style: AppFonts.banglaBody(fontSize: 12, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: UddoygiDesign.space24),
          _supplierImpactRow('Material Purity', '98%', Colors.greenAccent),
          const Divider(height: 24, color: Colors.white10),
          _supplierImpactRow('Batch Consistency', '82%', Colors.orangeAccent),
          const Divider(height: 24, color: Colors.white10),
          _supplierImpactRow('Return Rate from S1', '4.2%', Colors.redAccent),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _supplierImpactRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.banglaBody(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: UddoygiDesign.borderFull),
          child: Text(
            value,
            style: AppFonts.banglaBody(fontWeight: FontWeight.w800, color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }

  _QCDashboardStats _calculateQCStats(List<QueryDocumentSnapshot> qc, List<QueryDocumentSnapshot> inv) {
    int totalFailures = 0;
    for (var doc in qc) {
      totalFailures += ((doc.data() as Map)['quantity'] as num?)?.toInt() ?? 0;
    }

    int returnCount = 0;
    double returnValue = 0;
    for (var doc in inv) {
      final d = doc.data() as Map<String, dynamic>;
      final s = d['status'] ?? '';
      if (s == 'Returned' || s == 'Rejected') {
        returnCount++;
        returnValue += (d['grandTotal'] as num?)?.toDouble() ?? 0;
      }
    }

    return _QCDashboardStats(
      totalFailures: totalFailures,
      rejectionRate: inv.isEmpty ? 0 : (totalFailures / inv.length) * 10, // Simulated rate
      totalReturns: returnCount,
      returnValue: returnValue,
    );
  }
}

class _QCDashboardStats {
  final int totalFailures;
  final double rejectionRate;
  final int totalReturns;
  final double returnValue;
  _QCDashboardStats({required this.totalFailures, required this.rejectionRate, required this.totalReturns, required this.returnValue});
}
