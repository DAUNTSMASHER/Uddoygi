import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/local_storage_service.dart';

const Color _primary = Color(0xFF2563EB);
const Color _primaryDk = Color(0xFF1E3A8A);
const Color _bg = Color(0xFFF7F9FC);
const Color _border = Color(0xFFE2E8F0);
const Color _text = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);

class AllInvoicesScreen extends StatefulWidget {
  const AllInvoicesScreen({Key? key}) : super(key: key);

  @override
  State<AllInvoicesScreen> createState() => _AllInvoicesScreenState();
}

class _AllInvoicesScreenState extends State<AllInvoicesScreen> {
  String _cid = '';
  String? agentEmail;
  String? agentUid;

  String _searchQuery = '';
  String _statusFilter = 'All';

  final List<String> _filterChips = [
    'All',
    'Draft',
    'Awaiting HR Approval',
    'HR Verified',
    'Work Order Created',
    'Completed'
  ];

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadUserIdentity();
  }

  Future<void> _loadUserIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    String? email = user?.email;
    String? uid = user?.uid;

    if (email == null || uid == null) {
      final session = await LocalStorageService.getSession();
      email ??= session?['email'] as String?;
      uid ??= session?['uid'] as String?;
    }
    if (mounted) {
      setState(() {
        agentEmail = email;
        agentUid = uid;
      });
    }
  }

  String _money(num v) => v.toStringAsFixed(2);
  String _niceDate(DateTime d) => DateFormat('MMM dd, yyyy').format(d);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Draft':
        return Colors.grey.shade600;
      case 'Awaiting HR Approval':
        return Colors.orange.shade700;
      case 'HR Verified':
        return Colors.blue.shade600;
      case 'Work Order Created':
        return Colors.purple.shade600;
      case 'Completed':
        return Colors.green.shade600;
      default:
        return _primary;
    }
  }

  Widget _statusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: AppFonts.banglaBody(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _createWorkOrder(String invoiceId, Map<String, dynamic> inv) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      final tracking = inv['tracking_number'] ?? 'TRK-${inv['invoiceNo']}';
      final invoiceRef = DB.colSync(_cid, C.invoices).doc(invoiceId);
      final woRef = DB.colSync(_cid, C.workOrders).doc(tracking);

      // Update Invoice Status
      batch.update(invoiceRef, {
        'status': 'Work Order Created',
      });

      // Create Work Order
      batch.set(woRef, {
        'workOrderNo': tracking,
        'relatedInvoiceNo': inv['invoiceNo'],
        'buyerName': inv['customerName'],
        'customerId': inv['customerId'],
        'agentEmail': inv['agentEmail'],
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'items': inv['items'],
        'totalPieces': inv['totalPieces'],
        'status': 'Awaiting Factory',
        'currentStage': 'Production Queue',
        'priority': 'Normal',
        'revenueValue': inv['grandTotal'],
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Work Order Created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error creating work order: $e')),
      );
    }
  }

  void _showDetails(String docId, Map<String, dynamic> inv) {
    final itemsRaw = (inv['items'] as List?) ?? [];
    final items = itemsRaw.cast<Map>().map((e) => e.map((k, v) => MapEntry('$k', v))).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice #${inv['invoiceNo']}', style: AppFonts.banglaHeading(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _statusBadge(inv['status'] ?? 'Unknown'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer', style: AppFonts.banglaBody(color: _muted, fontSize: 13)),
                      Text(inv['customerName'] ?? 'N/A', style: AppFonts.banglaBody(fontWeight: FontWeight.w600, fontSize: 16)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Date', style: AppFonts.banglaBody(color: _muted, fontSize: 13)),
                      Text(
                        _niceDate((inv['timestamp'] is Timestamp) ? (inv['timestamp'] as Timestamp).toDate() : DateTime.now()),
                        style: AppFonts.banglaBody(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Items', style: AppFonts.banglaHeading(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 12),
              ...items.map((it) {
                final qty = (it['qty'] as num?) ?? 0;
                final unit = (it['unitPrice'] ?? 0) as num;
                final total = (it['lineTotal'] ?? (unit * qty)) as num;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${it['model']} (${it['colour']} / ${it['size']})', style: AppFonts.banglaBody(fontWeight: FontWeight.w600)),
                          Text('$qty x ৳${_money(unit)}', style: AppFonts.banglaBody(color: _muted, fontSize: 13)),
                        ],
                      ),
                      Text('৳${_money(total)}', style: AppFonts.banglaData(fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                );
              }),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Grand Total', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('৳${_money((inv['grandTotal'] as num?) ?? 0)}', style: AppFonts.banglaData(fontSize: 22, fontWeight: FontWeight.w900, color: _primaryDk)),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: AppFonts.banglaBody(fontWeight: FontWeight.w700)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryDk,
        foregroundColor: Colors.white,
        title: Text('Invoices', style: AppFonts.banglaHeading(fontWeight: FontWeight.w700)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_primary, _primaryDk], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Invoice No or Customer',
                prefixIcon: const Icon(Icons.search, color: _muted),
                filled: true,
                fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
          
          // Filter Chips
          Container(
            color: Colors.white,
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _filterChips.map((status) {
                  final isSelected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      selectedColor: _primary,
                      labelStyle: AppFonts.banglaBody(
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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: DB.colSync(_cid, C.invoices)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                
                // Filter locally
                final filtered = docs.where((doc) {
                  final data = doc.data();
                  final invoiceNo = (data['invoiceNo'] ?? '').toString().toLowerCase();
                  final customerName = (data['customerName'] ?? '').toString().toLowerCase();
                  final status = (data['status'] ?? 'Draft').toString();

                  // Search Filter
                  if (_searchQuery.isNotEmpty && !invoiceNo.contains(_searchQuery) && !customerName.contains(_searchQuery)) {
                    return false;
                  }

                  // Status Filter
                  if (_statusFilter != 'All' && status != _statusFilter) {
                    return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: _muted.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('No invoices found', style: AppFonts.banglaBody(color: _muted, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();
                    final status = data['status'] ?? 'Draft';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('#${data['invoiceNo']}', style: AppFonts.banglaBody(fontWeight: FontWeight.w800, fontSize: 16)),
                                _statusBadge(status),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 16, color: _muted),
                                const SizedBox(width: 6),
                                Text(data['customerName'] ?? 'Unknown Customer', style: AppFonts.banglaBody(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.event_outlined, size: 16, color: _muted),
                                const SizedBox(width: 6),
                                Text(
                                  _niceDate((data['timestamp'] is Timestamp) ? (data['timestamp'] as Timestamp).toDate() : DateTime.now()),
                                  style: AppFonts.banglaBody(color: _muted, fontSize: 13)
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Grand Total', style: AppFonts.banglaBody(color: _muted, fontSize: 12)),
                                    Text('৳${_money((data['grandTotal'] as num?) ?? 0)}', style: AppFonts.banglaData(fontWeight: FontWeight.w900, fontSize: 18, color: _primaryDk)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (status == 'HR Verified') ...[
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                                        ),
                                        onPressed: () => _createWorkOrder(doc.id, data),
                                        child: Text('Create Work Order', style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 13)),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (status == 'Draft') ...[
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _primary,
                                          side: const BorderSide(color: _primary),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                                        ),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit Draft logic to be implemented next sprint.')));
                                        },
                                        child: Text('Edit', style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 13)),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    IconButton(
                                      icon: const Icon(Icons.arrow_forward_ios, size: 16, color: _primary),
                                      onPressed: () => _showDetails(doc.id, data),
                                    )
                                  ],
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
