import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

const Color _primary = Color(0xFF0D47A1);
const Color _bg = Color(0xFFF4F6F9);
const Color _border = Color(0xFFE2E8F0);
const Color _text = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);

class OrderProgressScreen extends StatefulWidget {
  const OrderProgressScreen({Key? key}) : super(key: key);

  @override
  State<OrderProgressScreen> createState() => _OrderProgressScreenState();
}

class _OrderProgressScreenState extends State<OrderProgressScreen> {
  String _cid = '';
  String _searchQuery = '';
  String _statusFilter = 'All';

  final List<String> _filters = ['All', 'In Production', 'Ready for Delivery', 'Shipped'];

  // Factory Stages for progress calculation
  final List<String> _factoryStages = [
    'Accepted', 'Base is Done', 'Hair is Ready', 'Knotting Started',
    'Knotting Completed', 'Styling / Finishing', 'QC Check', 'Submit to Head Office'
  ];

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  String _niceDate(dynamic d) {
    if (d == null) return 'N/A';
    if (d is Timestamp) return DateFormat('MMM dd, yyyy').format(d.toDate());
    if (d is DateTime) return DateFormat('MMM dd, yyyy').format(d);
    return 'N/A';
  }

  double _calcProgress(String stage, String status) {
    if (status == 'Shipped' || status == 'Completed') return 1.0;
    int idx = _factoryStages.indexOf(stage);
    if (idx == -1) return 0.1;
    return ((idx + 1) / _factoryStages.length).clamp(0.0, 1.0);
  }

  void _openCourierForm(String docId, Map<String, dynamic> data) {
    final trackingCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String courier = 'FedEx';
    DateTime shipDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 24, right: 24, top: 24
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assign Courier & Complete Order', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('WO #${data['workOrderNo']} • Inv #${data['relatedInvoiceNo']}', style: GoogleFonts.inter(color: _muted)),
                  const SizedBox(height: 24),
                  
                  DropdownButtonFormField<String>(
                    value: courier,
                    decoration: InputDecoration(labelText: 'Courier Company', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: ['FedEx', 'DHL', 'UPS', 'USPS', 'Local Courier'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setLocal(() => courier = v!),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: trackingCtrl,
                    decoration: InputDecoration(labelText: 'Tracking Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),

                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: shipDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (d != null) setLocal(() => shipDate = d);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: 'Shipping Date', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(_niceDate(shipDate)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(labelText: 'Customer Notification Note (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.local_shipping),
                      label: const Text('Provide Tracking & Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: () async {
                        if (trackingCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Tracking number is required.')));
                          return;
                        }

                        final batch = FirebaseFirestore.instance.batch();
                        final woRef = DB.colSync(_cid, C.workOrders).doc(docId);
                        
                        batch.update(woRef, {
                          'status': 'Shipped',
                          'courier': courier,
                          'trackingNumber': trackingCtrl.text.trim(),
                          'shippingDate': Timestamp.fromDate(shipDate),
                          'shippingNote': noteCtrl.text.trim(),
                          'shippedAt': FieldValue.serverTimestamp(),
                        });

                        // Attempt to update original invoice
                        final invNo = data['relatedInvoiceNo'];
                        if (invNo != null && invNo.toString().isNotEmpty) {
                          final invQ = await DB.colSync(_cid, C.invoices).where('invoiceNo', isEqualTo: invNo).limit(1).get();
                          if (invQ.docs.isNotEmpty) {
                            batch.update(invQ.docs.first.reference, {'status': 'Shipped', 'trackingNumber': trackingCtrl.text.trim()});
                          }
                        }

                        await batch.commit();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Order Marked as Shipped!')));
                      },
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
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
        title: Text('Order Progress', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Top Metrics
          StreamBuilder<QuerySnapshot>(
            stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.workOrders).snapshots(),
            builder: (context, snapshot) {
              int inProd = 0, ready = 0, shipped = 0;
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final st = data['status'];
                  if (st == 'In Production') inProd++;
                  if (st == 'Completed') ready++;
                  if (st == 'Shipped') shipped++;
                }
              }

              return Container(
                height: 100,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _metricCard('In Production', '$inProd', Icons.precision_manufacturing, Colors.purple),
                    _metricCard('Ready for Delivery', '$ready', Icons.inventory_2, Colors.orange),
                    _metricCard('Shipped / Done', '$shipped', Icons.local_shipping, Colors.green),
                  ],
                ),
              );
            },
          ),
          
          // Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final isSel = _statusFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: isSel,
                      selectedColor: _primary,
                      labelStyle: TextStyle(color: isSel ? Colors.white : _text, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500),
                      onSelected: (v) {
                        if (v) setState(() => _statusFilter = f);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search WO#, Invoice#, or Customer',
                prefixIcon: const Icon(Icons.search),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),

          // List
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: _text)),
          Text(title, style: GoogleFonts.inter(color: _muted, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.workOrders)
          .where('status', whereIn: ['Accepted by Factory', 'In Production', 'Completed', 'Shipped'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        var docs = snapshot.data?.docs ?? [];

        // Apply Status Filter (local)
        if (_statusFilter != 'All') {
          docs = docs.where((d) {
            final st = (d.data() as Map)['status'];
            if (_statusFilter == 'In Production') return st == 'In Production' || st == 'Accepted by Factory';
            if (_statusFilter == 'Ready for Delivery') return st == 'Completed';
            if (_statusFilter == 'Shipped') return st == 'Shipped';
            return true;
          }).toList();
        }

        // Apply Search Filter (local)
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            final str = '${m['workOrderNo']} ${m['relatedInvoiceNo']} ${m['buyerName']}'.toLowerCase();
            return str.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) return const Center(child: Text('No orders found matching criteria.'));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final st = data['status'];
            final currentStage = data['currentStage'] ?? 'Unknown';
            final isReady = st == 'Completed';
            final isShipped = st == 'Shipped';
            
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isReady ? Colors.orange : _border, width: isReady ? 2 : 1)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('WO #${data['workOrderNo']}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isReady ? Colors.orange.withOpacity(0.1) : (isShipped ? Colors.green.withOpacity(0.1) : Colors.purple.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: Text(
                            isReady ? 'Ready for Delivery' : (isShipped ? 'Shipped' : 'In Factory'),
                            style: GoogleFonts.inter(
                              color: isReady ? Colors.orange : (isShipped ? Colors.green : Colors.purple),
                              fontWeight: FontWeight.w700, fontSize: 11
                            )
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Customer: ${data['buyerName']} (Inv #${data['relatedInvoiceNo']})', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _primary)),
                    const SizedBox(height: 12),

                    if (!isShipped) ...[
                      // Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Factory Progress: $currentStage', style: GoogleFonts.inter(fontSize: 12, color: _muted)),
                          Text('${(_calcProgress(currentStage, st) * 100).toInt()}%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _calcProgress(currentStage, st),
                          minHeight: 6,
                          backgroundColor: _border,
                          color: isReady ? Colors.orange : Colors.purple,
                        ),
                      ),
                    ] else ...[
                      // Shipping details
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${data['courier']} • Trk# ${data['trackingNumber']}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                                Text('Shipped: ${_niceDate(data['shippingDate'])}', style: GoogleFonts.inter(color: _muted, fontSize: 11)),
                              ],
                            )
                          ],
                        ),
                      )
                    ],

                    if (isReady) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.airport_shuttle),
                          label: const Text('Add Courier & Ship'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange, foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ),
                          onPressed: () => _openCourierForm(doc.id, data),
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
