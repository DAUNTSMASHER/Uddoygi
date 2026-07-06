import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminSalesPipelineScreen extends StatefulWidget {
  const AdminSalesPipelineScreen({super.key});

  @override
  State<AdminSalesPipelineScreen> createState() => _AdminSalesPipelineScreenState();
}

class _AdminSalesPipelineScreenState extends State<AdminSalesPipelineScreen> {
  String _cid = '';
  double _pipelineValue = 0;
  double _completedValue = 0;
  int _activeLeads = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (id == null) return;
    _cid = id;

    final results = await Future.wait([
      FirebaseFirestore.instance.collection('companies').doc(id).collection('tasks').where('status', isNotEqualTo: 'completed').get(),
      FirebaseFirestore.instance.collection('companies').doc(id).collection('invoices').get(),
    ]);

    _activeLeads = results[0].docs.length;
    // Estimate pipeline value based on leads (mock average 50k per lead)
    _pipelineValue = _activeLeads * 50000.0;

    double completed = 0;
    for (var doc in results[1].docs) {
      completed += (doc.data()['grandTotal'] ?? 0).toDouble();
    }
    _completedValue = completed;

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        title: Text('Revenue Pipeline', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: const Color(0xFF1E0040), // _heroPurple
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: UddoygiDesign.space20, vertical: UddoygiDesign.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPipelineHero(),
            const SizedBox(height: UddoygiDesign.space32),
            Text('Forecast vs. Reality', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: UddoygiDesign.space16),
            _buildStatBox('Ongoing Deals', _pipelineValue, 'Estimated future revenue', const Color(0xFF7C3AED), Icons.hourglass_empty_rounded),
            _buildStatBox('Completed Sales', _completedValue, 'Realized cash flow', Colors.green, Icons.check_circle_rounded),
            const SizedBox(height: UddoygiDesign.space32),
            _buildLeadSourceBreakdown(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineHero() {
    final total = _pipelineValue + _completedValue;
    final pct = total > 0 ? (_completedValue / total) : 0.0;

    return UCard(
      padding: const EdgeInsets.all(UddoygiDesign.space24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONVERSION RATE',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1.2),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF7C3AED)),
              ),
            ],
          ),
          const SizedBox(height: UddoygiDesign.space20),
          ClipRRect(
            borderRadius: BorderRadius.circular(UddoygiDesign.radiusFull),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor: const Color(0xFF7C3AED).withOpacity(0.08),
              color: const Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(height: UddoygiDesign.space24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_activeLeads',
                style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF1E0040)),
              ),
              const SizedBox(width: 12),
              Text(
                'Active Negotiations',
                style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutCubic);
  }

  Widget _buildStatBox(String label, double value, String sub, Color color, IconData icon) {
    return UCard(
      margin: const EdgeInsets.only(bottom: UddoygiDesign.space12),
      padding: const EdgeInsets.all(UddoygiDesign.space20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(UddoygiDesign.radiusM),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: UddoygiDesign.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF1E0040)),
                ),
                Text(
                  sub,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Text(
            '৳${NumberFormat('#,##,###').format(value)}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: color),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0, curve: Curves.easeOut);
  }

  Widget _buildLeadSourceBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lead Source Performance',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: UddoygiDesign.space16),
        UCard(
          padding: const EdgeInsets.all(UddoygiDesign.space24),
          child: Column(
            children: [
              _sourceRow('Physical Meetings', 0.65, const Color(0xFF7C3AED)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
              _sourceRow('Referrals', 0.25, Colors.green),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
              _sourceRow('Cold Calls', 0.10, Colors.orange),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sourceRow(String label, double val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[800]),
              ),
              Text(
                '${(val * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: color, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(UddoygiDesign.radiusFull),
            child: LinearProgressIndicator(
              value: val,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.08),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

}
