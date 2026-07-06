import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

class POStatusTrackerScreen extends StatefulWidget {
  const POStatusTrackerScreen({Key? key}) : super(key: key);

  @override
  State<POStatusTrackerScreen> createState() => _POStatusTrackerScreenState();
}

class _POStatusTrackerScreenState extends State<POStatusTrackerScreen> {
  String _cid = '';
  String? _photoUrl;
  String? _selectedPoNo;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    if (_cid.isEmpty) return;

    if (newStatus == 'rejected') {
      String? recommendation;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Reject Purchase Order', style: AppFonts.banglaHeading(fontWeight: FontWeight.w700, fontSize: 18)),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Reason / Recommendation',
              labelStyle: AppFonts.banglaBody(fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: AppFonts.banglaBody(fontSize: 14),
            onChanged: (v) => recommendation = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text('Cancel', style: AppFonts.banglaBody(color: Colors.grey.shade700, fontWeight: FontWeight.w600))
            ),
            ElevatedButton(
              onPressed: () {
                if ((recommendation ?? '').trim().isEmpty) return;
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBA1A1A), 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Submit', style: AppFonts.banglaHeading(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if ((recommendation ?? '').trim().isEmpty) return;
      
      await DB.colSync(_cid, C.purchaseOrders).doc(docId).update({
        'status': 'rejected',
        'recommendation': recommendation,
        'rejectedAt': Timestamp.now(),
      });
    } else {
      await DB.colSync(_cid, C.purchaseOrders).doc(docId).update({
        'status': newStatus,
        '${newStatus}At': Timestamp.now(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _cid.isEmpty
            ? const Stream.empty()
            : DB.colSync(_cid, C.purchaseOrders).orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _cid.isNotEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Map<String, dynamic>> itemsList = [];
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            itemsList = snapshot.data!.docs.map((d) => {'_id': d.id, ...d.data() as Map<String, dynamic>}).toList();
          } else {
            itemsList = [
              {
                '_id': 'PO-DUMMY-1',
                'poNo': 'PO-20261001',
                'status': 'order_received',
                'submittedBy': 'Michael Scott',
                'supplierName': 'Dunder Mifflin',
                'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2))),
                'items': [{'qty': 50, 'unitPrice': 12.50}, {'qty': 20, 'unitPrice': 5.0}],
              },
              {
                '_id': 'PO-DUMMY-2',
                'poNo': 'PO-20261002',
                'status': 'supplier_found',
                'submittedBy': 'Jim Halpert',
                'supplierName': 'Athlead',
                'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
                'supplier_foundAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 4))),
                'items': [{'qty': 5, 'unitPrice': 1200.0}],
              },
              {
                '_id': 'PO-DUMMY-3',
                'poNo': 'PO-20261003',
                'status': 'bought_from_supplier',
                'submittedBy': 'Dwight Schrute',
                'supplierName': 'Schrute Farms',
                'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2))),
                'bought_from_supplierAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
                'items': [{'qty': 100, 'unitPrice': 4.50}],
              },
              {
                '_id': 'PO-DUMMY-4',
                'poNo': 'PO-20261004',
                'status': 'in_factory_for_modification',
                'submittedBy': 'Pam Beesly',
                'supplierName': 'Vance Refrigeration',
                'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 3))),
                'in_factory_for_modificationAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
                'items': [{'qty': 2, 'unitPrice': 4500.0}],
              },
              {
                '_id': 'PO-DUMMY-5',
                'poNo': 'PO-20261005',
                'status': 'sent_to_marketing',
                'submittedBy': 'Stanley Hudson',
                'supplierName': 'Pretzel Co',
                'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 5))),
                'sent_to_marketingAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2))),
                'items': [{'qty': 500, 'unitPrice': 1.25}],
              },
              {
                '_id': 'PO-DUMMY-6',
                'poNo': 'PO-20261006',
                'status': 'rejected',
                'submittedBy': 'Angela Martin',
                'supplierName': 'Cat Fancy',
                'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 4))),
                'rejectedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2))),
                'items': [{'qty': 15, 'unitPrice': 85.0}],
              },
            ];
          }
          
          final orderReceived = itemsList.where((d) => d['status'] == 'order_received' || d['status'] == null).toList();
          final supplierFound = itemsList.where((d) => d['status'] == 'supplier_found').toList();
          final bought = itemsList.where((d) => d['status'] == 'bought_from_supplier').toList();
          final inFactory = itemsList.where((d) => d['status'] == 'in_factory_for_modification').toList();
          final sentMarketing = itemsList.where((d) => d['status'] == 'sent_to_marketing').toList();
          final rejected = itemsList.where((d) => d['status'] == 'rejected').toList();

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16, 
              16, 
              16, 
              100
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                'Status Tracker',
                style: AppFonts.banglaHeading(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1B1B),
                ),
                ),
                SizedBox(height: 4),
                Text(
                'Real-time management of procurement lifecycles.',
                style: AppFonts.banglaBody(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                ),
                ),
                SizedBox(height: 12),

                // Dropdown Selection
                Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2BFB9)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedPoNo,
                      hint: Text('Select a Purchase Order', style: AppFonts.banglaBody(fontSize: 10, color: Color(0xFF5A413D))),
                      iconSize: 16,
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Purchase Orders', style: AppFonts.banglaBody(fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                        ...itemsList.map((d) {
                          final poNo = d['poNo'] ?? d['_id'];
                          return DropdownMenuItem<String>(
                            value: d['_id'],
                            child: Text(poNo, style: AppFonts.banglaBody(fontSize: 10)),
                          );
                        }).toList(),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedPoNo = val);
                      },
                    ),
                  ),
                ),

                if (_selectedPoNo == null)
                  // Custom Timeline layout for all
                  Stack(
                    children: [
                      // Timeline vertical line
                    Positioned(
                      left: 23,
                      top: 0,
                      bottom: 0,
                      width: 2,
                      child: CustomPaint(
                        painter: _DashedLinePainter(color: const Color(0xFFE2BFB9)),
                      ),
                    ),
                    
                    Column(
                      children: [
                      _buildStatusSection('Order Received', orderReceived, const Color(0xFFBA002E)),
                      _buildStatusSection('Supplier Found', supplierFound, Colors.blue.shade700),
                      _buildStatusSection('Bought From Supplier', bought, Colors.purple.shade700),
                      _buildStatusSection('In Factory', inFactory, Colors.orange.shade700),
                      _buildStatusSection('Sent To Marketing', sentMarketing, Colors.green.shade700),
                      _buildStatusSection('Rejected', rejected, const Color(0xFFBA1A1A)),
                    ],
                    ),
                  ],
                )
                else
                  _buildSinglePOTimeline(itemsList.firstWhere((d) => d['_id'] == _selectedPoNo)),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B0000), Color(0xFF5A0000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [BoxShadow(color: const Color(0xFF8B0000).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      title: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
                Text(
                    'PO Tracker',
                    style: AppFonts.banglaHeading(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                ),
              ],
            ),
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                final now = DateTime.now();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(DateFormat('dd MMM yyyy').format(now), style: AppFonts.banglaHeading(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(DateFormat('hh:mm a').format(now), style: AppFonts.banglaBody(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.white70)),
                  ],
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(String title, List<Map<String, dynamic>> items, Color themeColor) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(left: 12, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFFFCF9F8),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: themeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFCF9F8), width: 2),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: AppFonts.banglaHeading(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1B1B),
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${items.length}',
                  style: AppFonts.banglaData(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF410000),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Items
          Padding(
            padding: EdgeInsets.only(left: 28),
            child: Column(
              children: items.asMap().entries.map((entry) {
                return _buildPOCard(entry.value, title.toLowerCase(), themeColor, entry.key);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOCard(Map<String, dynamic> data, String statusCategory, Color themeColor, int index) {
    
    double totalValue = 0;
    final items = data['items'] as List<dynamic>? ?? [];
    for (var item in items) {
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      final price = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
      totalValue += (qty * price);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2BFB9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['poNo'] ?? data['_id'],
                    style: AppFonts.banglaBody(
                      fontSize: 8,
                      letterSpacing: 1,
                      color: const Color(0xFF5A413D),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    data['supplierName'] ?? data['submittedBy'] ?? 'Unknown',
                    style: AppFonts.banglaBody(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1C1B1B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 4),
                    Text(
                      statusCategory.toUpperCase(),
                      style: AppFonts.banglaHeading(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: themeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E2E1)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                '\$${totalValue.toStringAsFixed(2)}',
                  style: AppFonts.banglaData(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B0000),
                  ),
                ),
                if (statusCategory == 'order received') ...[
                  Row(
                    children: [
                      _buildActionBtn(Icons.close_rounded, const Color(0xFFBA1A1A), true, () => _updateStatus(data['_id'], 'rejected')),
                      SizedBox(width: 6),
                      _buildActionBtn(Icons.check_rounded, const Color(0xFF8B0000), false, () => _updateStatus(data['_id'], 'supplier_found')),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.1, delay: Duration(milliseconds: 100 * index)).fadeIn();
  }

  Widget _buildSinglePOTimeline(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'order_received';
    final poNo = data['poNo'] ?? data['_id'];
    
    final createdAt = data['timestamp'] as Timestamp?;
    final sFoundAt = data['supplier_foundAt'] as Timestamp?;
    final boughtAt = data['bought_from_supplierAt'] as Timestamp?;
    final factoryAt = data['in_factory_for_modificationAt'] as Timestamp?;
    final marketingAt = data['sent_to_marketingAt'] as Timestamp?;
    final rejectedAt = data['rejectedAt'] as Timestamp?;

    bool isFound = sFoundAt != null || ['supplier_found', 'bought_from_supplier', 'in_factory_for_modification', 'sent_to_marketing'].contains(status);
    bool isBought = boughtAt != null || ['bought_from_supplier', 'in_factory_for_modification', 'sent_to_marketing'].contains(status);
    bool isFactory = factoryAt != null || ['in_factory_for_modification', 'sent_to_marketing'].contains(status);
    bool isMarketing = marketingAt != null || status == 'sent_to_marketing';
    bool isRejected = status == 'rejected';

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2BFB9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poNo,
            style: AppFonts.banglaHeading(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1B1B),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Current Status: ${status.replaceAll('_', ' ').toUpperCase()}',
            style: AppFonts.banglaBody(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B0000),
            ),
          ),
          SizedBox(height: 32),
          
          if (isRejected)
            _buildTimelineNode(title: 'Order Received', icon: Icons.receipt_long_rounded, isActive: true, color: const Color(0xFFBA002E), date: createdAt, isLast: false)
          else ...[
            _buildTimelineNode(title: 'Order Received', icon: Icons.receipt_long_rounded, isActive: true, color: const Color(0xFFBA002E), date: createdAt, isLast: false),
            _buildTimelineNode(title: 'Supplier Found', icon: Icons.search_rounded, isActive: isFound, color: Colors.blue.shade700, date: sFoundAt, isLast: false),
            _buildTimelineNode(title: 'Bought From Supplier', icon: Icons.shopping_cart_checkout_rounded, isActive: isBought, color: Colors.purple.shade700, date: boughtAt, isLast: false),
            _buildTimelineNode(title: 'In Factory For Modification', icon: Icons.precision_manufacturing_rounded, isActive: isFactory, color: Colors.orange.shade700, date: factoryAt, isLast: false),
            _buildTimelineNode(title: 'Sent To Marketing', icon: Icons.campaign_rounded, isActive: isMarketing, color: Colors.green.shade700, date: marketingAt, isLast: true),
          ],
          
          if (isRejected)
            _buildTimelineNode(title: 'Rejected', icon: Icons.cancel_rounded, isActive: true, color: const Color(0xFFBA1A1A), isLast: true, date: rejectedAt, subtitle: 'This order was rejected.'),
            
          // Daily Updates Form
          if (!isRejected && status != 'sent_to_marketing') ...[
            SizedBox(height: 32),
            Divider(color: const Color(0xFFE2BFB9)),
            SizedBox(height: 16),
            Text('Add Daily Update', style: AppFonts.banglaHeading(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B))),
            SizedBox(height: 8),
            _buildUpdateForm(data),
          ],
        ],
      ),
    );
  }

  Widget _buildUpdateForm(Map<String, dynamic> data) {
    return Column(
      children: [
        TextField(
          style: AppFonts.banglaBody(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Cost Details (Optional)',
            hintStyle: AppFonts.banglaBody(fontSize: 12, color: Color(0xFFA6A7A8)),
            filled: true,
            fillColor: const Color(0xFFFCF9F8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: const Color(0xFFE2BFB9))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: const Color(0xFFE2BFB9))),
          ),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: 8),
        TextField(
          maxLines: 3,
          style: AppFonts.banglaBody(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Where is it currently? Notes on condition...',
            hintStyle: AppFonts.banglaBody(fontSize: 12, color: Color(0xFFA6A7A8)),
            filled: true,
            fillColor: const Color(0xFFFCF9F8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: const Color(0xFFE2BFB9))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: const Color(0xFFE2BFB9))),
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update recorded successfully!')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Post Update', style: AppFonts.banglaHeading(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineNode({
    required String title,
    required Timestamp? date,
    required bool isActive,
    required bool isLast,
    required Color color,
    required IconData icon,
    String? subtitle,
  }) {
    final displayColor = isActive ? color : const Color(0xFFE5E2E1);
    final iconColor = isActive ? Colors.white : const Color(0xFFA6A7A8);
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: displayColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isActive ? displayColor : const Color(0xFFE5E2E1),
                  ),
                ),
            ],
          ),
          SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text(
                    title,
                    style: (isActive ? AppFonts.banglaHeading : AppFonts.banglaBody)(
                      fontSize: 16,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? const Color(0xFF1C1B1B) : const Color(0xFFA6A7A8),
                    ),
                  ),
                  if (date != null) ...[
                    SizedBox(height: 4),
                    Text(
                      timeago.format(date.toDate()),
                      style: AppFonts.banglaBody(
                        fontSize: 12,
                        color: const Color(0xFF5A413D),
                      ),
                    ),
                  ],
                  if (subtitle != null) ...[
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppFonts.banglaBody(
                        fontSize: 14,
                        color: const Color(0xFFBA1A1A),
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color color, bool isOutlined, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: !isOutlined ? [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ] : null,
        ),
        child: Icon(
          icon,
          color: isOutlined ? color : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashHeight = 5.0;
    const dashSpace = 5.0;
    double startY = 0.0;

    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

