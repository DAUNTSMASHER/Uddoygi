// lib/features/admin/presentation/screens/admin_order_analysis_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

const Color _brandPurple = Color(0xFF2A0A4B);
const Color _accentPurple = Color(0xFF7C3AED);

class AdminOrderAnalysisScreen extends StatefulWidget {
  const AdminOrderAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<AdminOrderAnalysisScreen> createState() => _AdminOrderAnalysisScreenState();
}

class _AdminOrderAnalysisScreenState extends State<AdminOrderAnalysisScreen> {
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
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        title: Text('Order Analysis', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _brandPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: DB.colSync(_cid, C.workOrders).orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_late_rounded, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No work orders found.', style: AppFonts.banglaBody(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: UddoygiDesign.space20, vertical: UddoygiDesign.space24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data() as Map<String, dynamic>;
                    return _OrderAnalysisCard(orderData: d, cid: _cid, docId: docs[index].id)
                        .animate(delay: (index * 50).ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
                  },
                );
              },
            ),
    );
  }
}

class _OrderAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final String cid;
  final String docId;

  const _OrderAnalysisCard({required this.orderData, required this.cid, required this.docId});

  @override
  Widget build(BuildContext context) {
    final woNo = orderData['workOrderNo'] ?? 'N/A';
    final buyer = orderData['buyerName'] ?? 'Unknown Buyer';
    final totalAmount = (orderData['revenueValue'] ?? orderData['grandTotal'] ?? 0.0).toDouble();
    
    // Try real cost data from linked invoice, fall back to 60% estimate
    final hrCost = (orderData['hrEstimatedCost'] as num?)?.toDouble();
    final hrOtherCost = (orderData['hrOtherCost'] as num?)?.toDouble();
    final estimatedCost = (hrCost != null && hrOtherCost != null)
        ? hrCost + hrOtherCost
        : totalAmount * 0.6;
    final estimatedProfit = totalAmount - estimatedCost;
    final profitMargin = totalAmount > 0 ? (estimatedProfit / totalAmount) * 100 : 0.0;

    final timestamp = orderData['timestamp'] as Timestamp?;
    final deadline = orderData['finalDate'] as Timestamp?;
    
    String timeNeeded = 'N/A';
    Color timeColor = _brandPurple;

    if (deadline != null) {
      final diff = deadline.toDate().difference(DateTime.now());
      if (diff.isNegative) {
        timeNeeded = 'Overdue by ${diff.inDays.abs()}d';
        timeColor = Colors.redAccent;
      } else {
        timeNeeded = '${diff.inDays} days remaining';
        timeColor = diff.inDays < 7 ? Colors.orange : _brandPurple;
      }
    }

    final startTime = timestamp?.toDate() ?? DateTime.now();
    final processingDays = DateTime.now().difference(startTime).inDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: UddoygiDesign.space16),
      child: UCard(
        padding: const EdgeInsets.all(UddoygiDesign.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WO: $woNo',
                        style: AppFonts.banglaBody(fontWeight: FontWeight.w800, fontSize: 16, color: _brandPurple, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        buyer,
                        style: AppFonts.banglaBody(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: orderData['currentStage'] ?? 'Pending'),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            Row(
              children: [
                _StatItem(label: 'Profit', value: '৳${NumberFormat('#,###').format(estimatedProfit)}', color: Colors.green),
                _StatItem(label: 'Margin', value: '${profitMargin.toStringAsFixed(1)}%', color: profitMargin > 20 ? Colors.green : Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatItem(label: 'Total Cost', value: '৳${NumberFormat('#,###').format(estimatedCost)}', color: _brandPurple.withOpacity(0.7)),
                _StatItem(label: 'Revenue', value: '৳${NumberFormat('#,###').format(totalAmount)}', color: _accentPurple),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatItem(label: 'Processing Time', value: '$processingDays Days', color: _accentPurple),
                _StatItem(label: 'Time Status', value: timeNeeded, color: timeColor),
              ],
            ),
            const SizedBox(height: UddoygiDesign.space24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showSpeedUpDialog(context),
                icon: const Icon(Icons.bolt_rounded, size: 20),
                label: Text('SPEED UP THIS ORDER', style: AppFonts.banglaBody(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedUpDialog(BuildContext context) {
    final buyer = orderData['buyerName'] ?? 'Unknown Buyer';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UddoygiDesign.radiusL)),
        title: Text('Priority Speed Up', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800)),
        content: Text('Notify the production floor to prioritize Work Order $docId for $buyer?', style: AppFonts.banglaBody(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppFonts.banglaBody(fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await DB.colSync(cid, C.notifications).add({
                'title': 'Priority Request: WO ${orderData['workOrderNo']}',
                'body': 'Admin requested to speed up this order for $buyer.',
                'type': 'priority',
                'timestamp': FieldValue.serverTimestamp(),
                'target': 'factory',
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Priority request sent to production floor!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
            ),
            child: Text('Request Priority', style: AppFonts.banglaBody(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.banglaBody(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppFonts.banglaBody(fontSize: 16, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _brandPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(UddoygiDesign.radiusFull),
        border: Border.all(color: _brandPurple.withOpacity(0.15)),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppFonts.banglaBody(fontSize: 10, fontWeight: FontWeight.w900, color: _brandPurple, letterSpacing: 0.5),
      ),
    );
  }
}

