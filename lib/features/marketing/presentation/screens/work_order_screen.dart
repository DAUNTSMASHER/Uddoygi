import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/marketing/presentation/work_order/add_new_wo.dart';

const Color _primary = Color(0xFF0D47A1);
const Color _bg = Color(0xFFF4F6F9);
const Color _border = Color(0xFFE2E8F0);
const Color _text = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);

class WorkOrderScreen extends StatefulWidget {
  const WorkOrderScreen({Key? key}) : super(key: key);

  @override
  State<WorkOrderScreen> createState() => _WorkOrderScreenState();
}

class _WorkOrderScreenState extends State<WorkOrderScreen> {
  String _cid = '';
  String _statusFilter = 'HR Verified Invoices';

  final List<String> _filterChips = [
    'HR Verified Invoices',
    'Draft Work Orders',
    'Sent to Factory',
    'In Production',
    'Completed'
  ];

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  String _niceDate(DateTime d) => DateFormat('MMM dd, yyyy').format(d);

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: _text)),
          const SizedBox(height: 2),
          Text(title, style: GoogleFonts.inter(color: _muted, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'HR Verified') color = Colors.blue;
    if (status == 'Draft') color = Colors.orange;
    if (status == 'Awaiting Factory') color = Colors.purple;
    if (status == 'In Production') color = Colors.deepPurple;
    if (status == 'Completed') color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _dispatchToFactory(String woId) async {
    try {
      await DB.colSync(_cid, C.workOrders).doc(woId).update({
        'status': 'Awaiting Factory',
        'dispatchedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Dispatched to Factory')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  Future<void> _quickCreateWO(String invoiceId, Map<String, dynamic> inv) async {
    // Navigate to AddNewWorkOrderScreen with Invoice data prefilled
    // We assume AddNewWorkOrderScreen is adapted to receive this, but if not we can push it.
    // For now, we push as requested by user ("Keep navigation connected with add_new_wo.dart")
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddNewWorkOrderScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Text('Work Orders', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddNewWorkOrderScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          // Top Metrics (We read from C.workOrders)
          StreamBuilder<QuerySnapshot>(
            stream: DB.colSync(_cid, C.workOrders).snapshots(),
            builder: (context, snapshot) {
              int draft = 0;
              int sent = 0;
              int production = 0;
              int completed = 0;

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final d = doc.data() as Map<String, dynamic>;
                  final status = d['status'] ?? '';
                  if (status == 'Draft') draft++;
                  if (status == 'Awaiting Factory') sent++;
                  if (status == 'In Production') production++;
                  if (status == 'Completed') completed++;
                }
              }

              return Container(
                height: 110,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _metricCard('Draft / Ready', '$draft', Icons.note_alt_outlined, Colors.orange),
                    _metricCard('Sent to Factory', '$sent', Icons.send_outlined, Colors.purple),
                    _metricCard('In Production', '$production', Icons.precision_manufacturing_outlined, Colors.deepPurple),
                    _metricCard('Completed', '$completed', Icons.check_circle_outline, Colors.green),
                  ],
                ),
              );
            },
          ),
          
          // Filters
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterChips.map((status) {
                  final isSelected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      selectedColor: _primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : _text,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _statusFilter = status);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // List
          Expanded(
            child: _buildList(),
          )
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_statusFilter == 'HR Verified Invoices') {
      return StreamBuilder<QuerySnapshot>(
        stream: DB.colSync(_cid, C.invoices).where('status', isEqualTo: 'HR Verified').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No HR Verified invoices pending WO creation.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final itemsRaw = (data['items'] as List?) ?? [];
              final itemCount = itemsRaw.length;
              int totalQty = 0;
              for (var it in itemsRaw) {
                totalQty += ((it as Map)['qty'] as num?)?.toInt() ?? 0;
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Invoice #${data['invoiceNo']}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                          _statusBadge('HR Verified'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Customer: ${data['customerName']}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      Text('$itemCount Product(s) • $totalQty Total Pieces', style: GoogleFonts.inter(fontSize: 13, color: _muted)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_box, size: 18),
                          label: const Text('Create Work Order'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ),
                          onPressed: () => _quickCreateWO(doc.id, data),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } else {
      // Show Work Orders based on status
      String targetStatus = 'Draft';
      if (_statusFilter == 'Sent to Factory') targetStatus = 'Awaiting Factory';
      if (_statusFilter == 'In Production') targetStatus = 'In Production';
      if (_statusFilter == 'Completed') targetStatus = 'Completed';

      return StreamBuilder<QuerySnapshot>(
        stream: DB.colSync(_cid, C.workOrders).where('status', isEqualTo: targetStatus).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return Center(child: Text('No $_statusFilter found.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('WO #${data['workOrderNo']}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                          _statusBadge(data['status'] ?? 'Draft'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Linked Invoice: #${data['relatedInvoiceNo'] ?? 'N/A'}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _primary)),
                      Text('Created: ${_niceDate((data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : DateTime.now())}', style: GoogleFonts.inter(fontSize: 12, color: _muted)),
                      if (data['currentStage'] != null) ...[
                        const SizedBox(height: 4),
                        Text('Factory Stage: ${data['currentStage']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                      if (targetStatus == 'Draft') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.send),
                            label: const Text('Dispatch to Factory'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.purple,
                              side: const BorderSide(color: Colors.purple),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                            ),
                            onPressed: () => _dispatchToFactory(doc.id),
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }
}
