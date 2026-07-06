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
import 'package:intl/intl.dart';

class POListScreen extends StatefulWidget {
  const POListScreen({Key? key}) : super(key: key);

  @override
  State<POListScreen> createState() => _POListScreenState();
}

class _POListScreenState extends State<POListScreen> {
  String _cid = '';
  String? _photoUrl;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
  }

  Future<void> _updateStatus(String docId, String newStatus, BuildContext ctx) async {
    if (_cid.isEmpty) return;

    if (newStatus == 'rejected') {
      String? recommendation;
      await showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
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
              onPressed: () => Navigator.pop(dCtx), 
              child: Text('Cancel', style: AppFonts.banglaBody(color: Colors.grey.shade700, fontWeight: FontWeight.w600))
            ),
            ElevatedButton(
              onPressed: () {
                if ((recommendation ?? '').trim().isEmpty) return;
                Navigator.pop(dCtx);
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
    
    if (mounted) {
      Navigator.pop(ctx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: _buildSearchBar(),
          ),
          Expanded(
            child: _buildList(),
          ),
        ],
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
                    'PO List',
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: const Color(0xFF8B0000).withOpacity(0.6), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      style: AppFonts.banglaBody(fontSize: 12, color: Color(0xFF161C22), fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Search PO number or agent...',
                        hintStyle: AppFonts.banglaBody(
                          fontSize: 12,
                          color: const Color(0xFF8E706C).withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          Container(
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B0000), Color(0xFF5A0000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B0000).withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.filter_list_rounded, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text(
                    'Filter',
                    style: AppFonts.banglaBody(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
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

        if (_searchQuery.isNotEmpty) {
          itemsList = itemsList.where((data) {
            final po = (data['poNo'] ?? data['_id']).toString().toLowerCase();
            final agent = (data['submittedBy'] ?? '').toString().toLowerCase();
            return po.contains(_searchQuery) || agent.contains(_searchQuery);
          }).toList();
        }

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Purchase Orders',
                    style: AppFonts.banglaHeading(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1B1B),
                    ),
                  ),
                  Text(
                    '${itemsList.length} Total Orders',
                    style: AppFonts.banglaBody(
                      fontSize: 10,
                      color: const Color(0xFF5A413D),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  16, 0, 16, 80),
                itemCount: itemsList.length,
                itemBuilder: (ctx, i) {
                  final data = itemsList[i];
                  return _buildPOItem(data, data['_id'], i);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPOItem(Map<String, dynamic> data, String id, int index) {
    final status = data['status'] as String? ?? 'pending';
    final ts = data['timestamp'] as Timestamp?;
    final timeString = ts != null ? DateFormat('dd MMM, hh:mm a').format(ts.toDate()) : '';
    
    double totalValue = 0;
    int totalItems = 0;
    final items = data['items'] as List<dynamic>? ?? [];
    for (var item in items) {
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      final price = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
      totalValue += (qty * price);
      totalItems += qty;
    }

    Color statusColor;
    Color statusBg;
    String displayStatus = status.replaceAll('_', ' ').toUpperCase();

    if (status == 'sent_to_marketing') {
      statusColor = Colors.green.shade700;
      statusBg = Colors.green.shade100;
    } else if (status == 'in_factory_for_modification') {
      statusColor = Colors.orange.shade700;
      statusBg = Colors.orange.shade100;
    } else if (status == 'bought_from_supplier') {
      statusColor = Colors.purple.shade700;
      statusBg = Colors.purple.shade100;
    } else if (status == 'supplier_found') {
      statusColor = Colors.blue.shade700;
      statusBg = Colors.blue.shade100;
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFBA1A1A);
      statusBg = const Color(0xFFFFDAD6);
    } else { // order_received
      statusColor = const Color(0xFFBA002E);
      statusBg = const Color(0xFFE31C40).withOpacity(0.1);
      displayStatus = 'ORDER RECEIVED';
    }

    return GestureDetector(
      onTap: () => _showPODetails(context, data, id, status, totalItems, totalValue, ts),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEAE7E7)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
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
                      data['poNo'] ?? id,
                      style: AppFonts.banglaHeading(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1B1B),
                      ),
                    ),
                    Text(
                      'By ${data['submittedBy'] ?? 'Unknown'}',
                      style: AppFonts.banglaBody(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      SizedBox(width: 4),
                      Text(
                        displayStatus,
                        style: AppFonts.banglaHeading(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0EDED)))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ITEMS',
                          style: AppFonts.banglaBody(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: const Color(0xFFA6A7A8),
                          ),
                        ),
                        Text(
                          '$totalItems pcs',
                          style: AppFonts.banglaBody(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1C1B1B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL VALUE',
                          style: AppFonts.banglaBody(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: const Color(0xFFA6A7A8),
                          ),
                        ),
                        Text(
                          '\$${totalValue.toStringAsFixed(2)}',
                          style: AppFonts.banglaData(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8B0000),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: const Color(0xFF5A413D)),
                SizedBox(width: 4),
                Text(
                  timeString,
                  style: AppFonts.banglaBody(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF5A413D),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: 100 * (index % 5))).slideY(begin: 0.1),
    );
  }

  void _showPODetails(BuildContext context, Map<String, dynamic> data, String id, String status, int totalItems, double totalValue, Timestamp? ts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: Responsive.height(context) * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF570000), Color(0xFFBA002E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ORDER DETAILS',
                          style: AppFonts.banglaBody(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.8), size: 24),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      data['poNo'] ?? id,
                      style: AppFonts.banglaHeading(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                              'SUBMITTED BY',
                                style: AppFonts.banglaHeading(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              Text(
                                data['submittedBy'] ?? 'Unknown',
                                style: AppFonts.banglaBody(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                              'DATE',
                                style: AppFonts.banglaHeading(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              Text(
                                ts != null ? DateFormat('dd Oct, hh:mm a').format(ts.toDate()) : '',
                                style: AppFonts.banglaBody(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item List',
                        style: AppFonts.banglaHeading(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1C1B1B),
                        ),
                      ),
                      SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowHeight: 40,
                          dataRowMaxHeight: 50,
                          dataRowMinHeight: 50,
                          dividerThickness: 1,
                          columns: [
                            DataColumn(label: Text('Model', style: _colStyle())),
                            DataColumn(label: Text('Colour', style: _colStyle())),
                            DataColumn(label: Text('Size', style: _colStyle()), numeric: true),
                            DataColumn(label: Text('Qty', style: _colStyle()), numeric: true),
                            DataColumn(label: Text('Price', style: _colStyle()), numeric: true),
                          ],
                          rows: (data['items'] as List<dynamic>? ?? []).map((item) {
                            return DataRow(cells: [
                              DataCell(Text(item['model'] ?? '', style: _cellStyle(bold: true))),
                              DataCell(Text(item['colour'] ?? '', style: _cellStyle())),
                              DataCell(Text(item['size'] ?? '', style: _cellStyle())),
                              DataCell(Text('${item['qty'] ?? 0}', style: _cellStyle())),
                              DataCell(Text('\$${item['unitPrice'] ?? 0}', style: _cellStyle())),
                            ]);
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 24),
                      if (data['instructions'] != null && data['instructions'].toString().isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F3F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border(left: BorderSide(color: const Color(0xFFBA002E), width: 4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INSTRUCTIONS',
                                style: AppFonts.banglaHeading(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFBA002E),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                              data['instructions'],
                                style: AppFonts.banglaBody(
                                  fontSize: 14,
                                  color: const Color(0xFF5A413D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                      ],
                      Container(
                        padding: EdgeInsets.only(top: 16),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0EDED)))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'APPROVAL SIGNATURE',
                                  style: AppFonts.banglaBody(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFA6A7A8),
                                  ),
                                ),
                                Container(
                                  margin: EdgeInsets.only(top: 8),
                                  width: 120,
                                  height: 32,
                                  alignment: Alignment.bottomLeft,
                                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2BFB9)))),
                                  child: Text(
                                    '${data['submittedBy']?.toString().split('@').first}',
                                    style: AppFonts.banglaBody(
                                      fontSize: 16,
                                      color: const Color(0xFF5A413D).withOpacity(0.6),
                                    ).copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'GRAND TOTAL',
                                  style: AppFonts.banglaBody(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFA6A7A8),
                                  ),
                                ),
                                Text(
                                  '\$${totalValue.toStringAsFixed(2)}',
                                  style: AppFonts.banglaData(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFBA002E),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: EdgeInsets.all(24),
                decoration: const BoxDecoration(color: Color(0xFFF6F3F2)),
                child: Row(
                  children: [
                    if (status == 'order_received' || status == null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updateStatus(id, 'rejected', ctx),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFFBA1A1A), width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'REJECT',
                            style: AppFonts.banglaHeading(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: const Color(0xFFBA1A1A),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(id, 'supplier_found', ctx),
                          icon: Icon(Icons.search_rounded, color: Colors.white, size: 18),
                          label: Text(
                            'SUPPLIER FOUND',
                            style: AppFonts.banglaHeading(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 8,
                            shadowColor: Colors.blue.shade700.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ] else if (status == 'supplier_found') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(id, 'bought_from_supplier', ctx),
                          icon: Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 18),
                          label: Text(
                            'BOUGHT FROM SUPPLIER',
                            style: AppFonts.banglaHeading(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.purple.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 8,
                            shadowColor: Colors.purple.shade700.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ] else if (status == 'bought_from_supplier') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(id, 'in_factory_for_modification', ctx),
                          icon: Icon(Icons.precision_manufacturing_rounded, color: Colors.white, size: 18),
                          label: Text(
                            'IN FACTORY FOR MODIFICATION',
                            style: AppFonts.banglaHeading(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.orange.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 8,
                            shadowColor: Colors.orange.shade700.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ] else if (status == 'in_factory_for_modification') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(id, 'sent_to_marketing', ctx),
                          icon: Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
                          label: Text(
                            'SEND TO MARKETING',
                            style: AppFonts.banglaHeading(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 8,
                            shadowColor: Colors.green.shade700.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFF570000), width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'CLOSE',
                            style: AppFonts.banglaHeading(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: const Color(0xFF570000),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.download_rounded, color: Colors.white, size: 18),
                          label: Text(
                            'EXPORT PDF',
                            style: AppFonts.banglaHeading(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFFBA002E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 8,
                            shadowColor: const Color(0xFFBA002E).withOpacity(0.5),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  TextStyle _colStyle() => AppFonts.banglaBody(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFA6A7A8),
        letterSpacing: 1,
      );

  TextStyle _cellStyle({bool bold = false}) => AppFonts.banglaBody(
        fontSize: 14,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        color: const Color(0xFF1C1B1B),
      );
}

