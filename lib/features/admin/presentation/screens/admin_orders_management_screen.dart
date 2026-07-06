import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminOrdersManagementScreen extends StatefulWidget {
  const AdminOrdersManagementScreen({super.key});

  @override
  State<AdminOrdersManagementScreen> createState() => _AdminOrdersManagementScreenState();
}

class _AdminOrdersManagementScreenState extends State<AdminOrdersManagementScreen> {
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
        title: Text('Fulfillment Hub', style: AppFonts.banglaBody(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DB.colSync(_cid, C.workOrders).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final orders = snapshot.data!.docs;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPendingApprovals(orders),
                const SizedBox(height: 24),
                _buildPipelineOverview(orders),
                const SizedBox(height: 24),
                _buildBottleneckDetector(orders),
                const SizedBox(height: 24),
                _buildResourceAllocation(),
                const SizedBox(height: 24),
                _buildDeliveryCommitments(orders),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingApprovals(List<QueryDocumentSnapshot> orders) {
    final pending = orders.where((o) => (o.data() as Map)['status'] == 'Pending Admin Review').toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.assignment_turned_in_rounded, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text('Pending Approval (${pending.length})', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ...pending.map((o) {
          final d = o.data() as Map;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WO: ${d['workOrderNo']}', style: AppFonts.banglaBody(fontWeight: FontWeight.bold)),
                      Text('Customer: ${d['buyerName']}', style: AppFonts.banglaBody(fontSize: 12, color: Colors.blue[800])),
                      Text('Value: ৳${d['revenueValue']}', style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _releaseToFactory(o.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text('Release to Factory', style: AppFonts.banglaBody(fontSize: 12)),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Future<void> _releaseToFactory(String docId) async {
    try {
      await DB.colSync(_cid, C.workOrders).doc(docId).update({
        'status': 'In Production',
        'currentStage': 'Raw Material',
        'releasedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Order released to production line')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Release failed: $e')),
        );
      }
    }
  }

  Widget _buildPipelineOverview(List<QueryDocumentSnapshot> orders) {
    final stages = ['Raw Material', 'Assembly', 'QC Testing', 'Ready'];
    Map<String, int> counts = {for (var s in stages) s: 0};
    
    for (var o in orders) {
      final stage = (o.data() as Map)['currentStage'] ?? 'Raw Material';
      if (counts.containsKey(stage)) counts[stage] = counts[stage]! + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Production Pipeline', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: stages.map((s) => _pipelineStageCard(s, counts[s] ?? 0)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _pipelineStageCard(String stage, int count) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
      child: Column(
        children: [
          Text('$count', style: AppFonts.banglaData(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(stage, textAlign: TextAlign.center, style: AppFonts.banglaBody(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildBottleneckDetector(List<QueryDocumentSnapshot> orders) {
    final stuckOrders = orders.where((o) => (o.data() as Map)['currentStage'] == 'QC Testing').take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text('Bottleneck Alerts', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (stuckOrders.isEmpty) Text('No bottlenecks detected', style: AppFonts.banglaBody(color: Colors.grey)),
        ...stuckOrders.map((o) {
          final d = o.data() as Map;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange[100]!)),
            child: Row(
              children: [
                const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.timer, color: Colors.white, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('WO: ${d['workOrderNo']}', style: AppFonts.banglaBody(fontWeight: FontWeight.bold)),
                    Text('Stuck in QC Testing for 48h+', style: AppFonts.banglaBody(fontSize: 12, color: Colors.orange[800])),
                  ]),
                ),
                TextButton(onPressed: () {}, child: const Text('Resolve')),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildResourceAllocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Line Utilization', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _utilizationRow('Production Line A', 0.95, Colors.red),
              const SizedBox(height: 16),
              _utilizationRow('Production Line B', 0.45, Colors.blue),
              const SizedBox(height: 16),
              _utilizationRow('Packaging Unit', 0.70, Colors.orange),
            ],
          ),
        ),
      ],
    );
  }

  Widget _utilizationRow(String label, double val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppFonts.banglaBody(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('${(val * 100).toStringAsFixed(0)}%', style: AppFonts.banglaBody(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: val, minHeight: 6, backgroundColor: color.withOpacity(0.1), color: color),
        ),
      ],
    );
  }

  Widget _buildDeliveryCommitments(List<QueryDocumentSnapshot> orders) {
    final highPriority = orders.where((o) => (o.data() as Map)['priority'] == 'High').take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority Countdowns', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...highPriority.map((o) {
          final d = o.data() as Map;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['buyerName'] ?? 'Priority Order', style: AppFonts.banglaBody(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('WO: ${d['workOrderNo']}', style: AppFonts.banglaBody(color: Colors.white60, fontSize: 12)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('4h : 12m', style: AppFonts.banglaBody(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 18)),
                  Text('Until Ship Deadline', style: AppFonts.banglaBody(color: Colors.white38, fontSize: 10)),
                ]),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
