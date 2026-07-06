import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminHREfficiencyScreen extends StatefulWidget {
  const AdminHREfficiencyScreen({super.key});

  @override
  State<AdminHREfficiencyScreen> createState() => _AdminHREfficiencyScreenState();
}

class _AdminHREfficiencyScreenState extends State<AdminHREfficiencyScreen> {
  String _cid = '';
  int _totalEmployees = 0;
  int _activeWorkOrders = 0;
  double _productionRate = 0;
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
      FirebaseFirestore.instance.collection('companies').doc(id).collection('users').get(),
      FirebaseFirestore.instance.collection('companies').doc(id).collection('workOrders').where('status', isEqualTo: 'In-Progress').get(),
      FirebaseFirestore.instance.collection('companies').doc(id).collection(C.leaves).where('status', isEqualTo: 'Approved').get(),
    ]);

    _totalEmployees = results[0].docs.length;
    _activeWorkOrders = results[1].docs.length;
    
    // Gap G2: Adjust workforce by approved absences
    int onLeave = 0;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (var doc in results[2].docs) {
      final data = doc.data() as Map<String, dynamic>;
      final from = data['fromDate'] as String? ?? '';
      final to   = data['toDate'] as String? ?? '';
      if (todayStr.compareTo(from) >= 0 && todayStr.compareTo(to) <= 0) {
        onLeave++;
      }
    }

    final activeWorkforce = (_totalEmployees - onLeave).clamp(0, _totalEmployees);
    
    // Logic: 1 employee per 2 active orders is ideal.
    _productionRate = _activeWorkOrders > 0 ? (activeWorkforce / _activeWorkOrders) : 0;

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Logic: 1 employee per 2 active orders is ideal.
    // If > 2: Overstaffed. If < 0.5: Understaffed.
    String status = 'Balanced';
    Color statusColor = Colors.green;
    if (_productionRate > 3) {
      status = 'Overstaffed';
      statusColor = Colors.orange;
    } else if (_productionRate < 1) {
      status = 'Understaffed';
      statusColor = Colors.red;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Workforce Efficiency', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEfficiencyHero(status, statusColor),
            const SizedBox(height: 24),
            Text('Sync: Labor vs. Production', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildMetricTile('Total Workforce', '$_totalEmployees Personnel', Icons.groups_rounded, Colors.blue),
            _buildMetricTile('Active Work Orders', '$_activeWorkOrders Units', Icons.precision_manufacturing_rounded, Colors.purple),
            _buildMetricTile('Staffing Ratio', '${_productionRate.toStringAsFixed(1)} per Order', Icons.balance_rounded, Colors.teal),
            const SizedBox(height: 24),
            _buildRecommendationCard(status),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildEfficiencyHero(String status, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.speed_rounded, color: color, size: 48),
          ),
          const SizedBox(height: 16),
          Text(status.toUpperCase(), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: color, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text('Based on current Factory Output', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[100]!)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(String status) {
    String msg = 'Maintain current operations. Your workforce matches the production demand.';
    if (status == 'Understaffed') msg = 'Increase shift hours or hire temporary staff to meet the current work order volume.';
    else if (status == 'Overstaffed') msg = 'Optimize labor costs by reassigning idle staff to R&D or maintenance tasks.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text('Admin Recommendation', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(msg, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}
