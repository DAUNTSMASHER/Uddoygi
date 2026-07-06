import 'package:flutter/material.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class AdminRDScreen extends StatefulWidget {
  const AdminRDScreen({super.key});

  @override
  State<AdminRDScreen> createState() => _AdminRDScreenState();
}

class _AdminRDScreenState extends State<AdminRDScreen> {
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Innovation & R&D', style: AppFonts.banglaBody(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProjectTimeline(),
            const SizedBox(height: 24),
            _buildPrototypeTracking(),
            const SizedBox(height: 24),
            _buildFeedbackLoop(),
            const SizedBox(height: 24),
            _buildCostOptimizationDashboard(),
            const SizedBox(height: 24),
            _buildProductOptimization(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectTimeline() {
    final milestones = [
      {'title': 'New Polymer Trial', 'date': '12 May', 'status': 'Next Up', 'color': Colors.blue},
      {'title': 'Ergonomic Base v2.0', 'date': '08 May', 'status': 'Testing', 'color': Colors.orange},
      {'title': 'Eco-Fabric Sourcing', 'date': '02 May', 'status': 'Done', 'color': Colors.green},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('R&D Timeline', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: milestones.map((m) => _timelineItem(m)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _timelineItem(Map<String, dynamic> m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Column(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: m['color'], shape: BoxShape.circle)),
            Container(width: 2, height: 30, color: Colors.grey[200]),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['title'], style: AppFonts.banglaBody(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(m['date'], style: AppFonts.banglaBody(fontSize: 11, color: Colors.grey)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: (m['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(m['status'], style: AppFonts.banglaBody(color: m['color'], fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrototypeTracking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prototype Status', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _prototypeCard('Chair Armrest v3.1', 'Stress Testing Stage', 0.65, Colors.orange),
        const SizedBox(height: 12),
        _prototypeCard('Bamboo Mesh V1', 'Sample Approved', 1.0, Colors.green),
      ],
    );
  }

  Widget _prototypeCard(String title, String status, double progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppFonts.banglaBody(fontWeight: FontWeight.bold)),
              Icon(Icons.biotech_rounded, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(status, style: AppFonts.banglaBody(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: color.withOpacity(0.1), color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackLoop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Design Feedback Loop', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red[100]!)),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.feedback_rounded, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text('QC Alert: High failure rate in Base Welding', style: AppFonts.banglaBody(fontWeight: FontWeight.bold, color: Colors.red[900]))),
                ],
              ),
              const SizedBox(height: 12),
              Text('R&D fix required for the next production batch to reinforce joint strength.', style: AppFonts.banglaBody(fontSize: 12, color: Colors.red[800])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCostOptimizationDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cost Optimization', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Project: Reduce Plastic Waste', style: AppFonts.banglaBody(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('72%', style: AppFonts.banglaBody(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: 0.72, minHeight: 10, backgroundColor: Colors.white10, color: Colors.greenAccent),
              ),
              const SizedBox(height: 12),
              Text('Target: 10% reduction in scrap. Current: 7.2% achieved.', style: AppFonts.banglaBody(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildProductOptimization() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Product Optimization (Sync)', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey[100]!)),
          child: Column(
            children: [
              _optimizationItem('Waste Redesign', 'High Impact', Icons.recycling_rounded, Colors.green),
              const Divider(height: 32),
              _optimizationItem('Failure Rate Reduction', '7.5% Improvement', Icons.trending_down_rounded, Colors.blue),
              const Divider(height: 32),
              _optimizationItem('Cost vs. Design', 'Optimized', Icons.design_services_rounded, Colors.purple),
            ],
          ),
        ),
      ],
    );
  }

  Widget _optimizationItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 16),
        Expanded(child: Text(label, style: AppFonts.banglaBody(fontWeight: FontWeight.w600, color: Colors.grey[700]))),
        Text(value, style: AppFonts.banglaBody(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }
}
