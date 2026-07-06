import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

const Color _primary = Color(0xFF0F766E); // Teal for Finance
const Color _primaryDk = Color(0xFF0D9488);
const Color _bg = Color(0xFFF0FDF4); // Very light mint
const Color _border = Color(0xFFE2E8F0);
const Color _text = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);

class InvoiceManagementScreen extends StatefulWidget {
  const InvoiceManagementScreen({Key? key}) : super(key: key);

  @override
  State<InvoiceManagementScreen> createState() => _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends State<InvoiceManagementScreen> {
  String _cid = '';
  String _statusFilter = 'Awaiting HR Approval';

  final List<String> _filterChips = [
    'Awaiting HR Approval',
    'HR Verified',
    'Rejected'
  ];

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  String _money(num v) => v.toStringAsFixed(2);
  String _niceDate(DateTime d) => DateFormat('MMM dd, yyyy').format(d);

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: _text)),
          const SizedBox(height: 2),
          Text(title, style: GoogleFonts.inter(color: _muted, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showReviewModal(String docId, Map<String, dynamic> inv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FinanceReviewSheet(docId: docId, inv: inv, cid: _cid),
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
        title: Text('Invoice Review & Finance', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Top Metrics
          StreamBuilder<QuerySnapshot>(
            stream: DB.colSync(_cid, C.invoices).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
              
              int pending = 0;
              int verified = 0;
              double totalValue = 0;
              double estimatedProfit = 0;

              for (var doc in snapshot.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                final status = d['status'] ?? '';
                if (status == 'Awaiting HR Approval') pending++;
                if (status == 'HR Verified') verified++;
                
                final val = (d['grandTotal'] as num?)?.toDouble() ?? 0.0;
                if (status != 'Rejected' && status != 'Draft') totalValue += val;

                if (status == 'HR Verified' || status == 'Work Order Created' || status == 'Completed') {
                  estimatedProfit += (d['hrNetProfit'] as num?)?.toDouble() ?? 0.0;
                }
              }

              return Container(
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _metricCard('Pending Review', '$pending', Icons.pending_actions, Colors.orange),
                    _metricCard('Verified', '$verified', Icons.verified_outlined, Colors.blue),
                    _metricCard('Total Value', '৳${_money(totalValue)}', Icons.account_balance_wallet_outlined, _primary),
                    _metricCard('Est. Profit', '৳${_money(estimatedProfit)}', Icons.trending_up, Colors.green),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: DB.colSync(_cid, C.invoices)
                  .where('status', isEqualTo: _statusFilter)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: _muted.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('No invoices found for this status', style: GoogleFonts.inter(color: _muted, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _border)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('#${data['invoiceNo']}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('৳${_money((data['grandTotal'] as num?) ?? 0)}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _primary)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('Customer: ${data['customerName'] ?? 'Unknown'}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _text)),
                            Text('Date: ${_niceDate((data['timestamp'] is Timestamp) ? (data['timestamp'] as Timestamp).toDate() : DateTime.now())}', style: GoogleFonts.inter(fontSize: 12, color: _muted)),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: _primary),
                        onTap: () => _showReviewModal(doc.id, data),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class _FinanceReviewSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> inv;
  final String cid;

  const _FinanceReviewSheet({required this.docId, required this.inv, required this.cid});

  @override
  State<_FinanceReviewSheet> createState() => _FinanceReviewSheetState();
}

class _FinanceReviewSheetState extends State<_FinanceReviewSheet> {
  final _costController = TextEditingController();
  final _otherCostController = TextEditingController();
  final _hrNoteController = TextEditingController();
  
  bool _paymentVerified = false;
  double _grandTotal = 0;
  double _netProfit = 0;
  double _profitMargin = 0;

  @override
  void initState() {
    super.initState();
    _grandTotal = (widget.inv['grandTotal'] as num?)?.toDouble() ?? 0.0;
    
    _costController.text = ((widget.inv['hrEstimatedCost'] as num?) ?? 0).toString();
    if (_costController.text == '0') _costController.text = '';
    
    _otherCostController.text = ((widget.inv['hrOtherCost'] as num?) ?? 0).toString();
    if (_otherCostController.text == '0') _otherCostController.text = '';

    _hrNoteController.text = widget.inv['hrNote'] ?? '';
    _paymentVerified = widget.inv['hrPaymentVerified'] == true;

    _calculateProfit();
  }

  void _calculateProfit() {
    final cost = double.tryParse(_costController.text) ?? 0.0;
    final other = double.tryParse(_otherCostController.text) ?? 0.0;
    final totalCost = cost + other;
    
    setState(() {
      _netProfit = _grandTotal - totalCost;
      if (_grandTotal > 0) {
        _profitMargin = (_netProfit / _grandTotal) * 100;
      } else {
        _profitMargin = 0;
      }
    });
  }

  String _money(num v) => v.toStringAsFixed(2);

  Future<void> _updateStatus(String status) async {
    final cost = double.tryParse(_costController.text) ?? 0.0;
    final other = double.tryParse(_otherCostController.text) ?? 0.0;

    if (status == 'HR Verified' && cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an estimated product cost to verify.')));
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final invRef = DB.colSync(widget.cid, C.invoices).doc(widget.docId);

      batch.update(invRef, {
        'status': status,
        'hrEstimatedCost': cost,
        'hrOtherCost': other,
        'hrNetProfit': _netProfit,
        'hrProfitMargin': _profitMargin,
        'hrPaymentVerified': _paymentVerified,
        'hrNote': _hrNoteController.text.trim(),
        'hrVerifiedAt': FieldValue.serverTimestamp(),
      });

      // If updating to HR Verified, we also update the Work Order if it exists
      // Wait, the workflow says Marketing creates the work order AFTER HR Verified.
      // So HR just approves the invoice.

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Invoice marked as $status')));
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
    labelStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
  );

  @override
  Widget build(BuildContext context) {
    final itemsRaw = (widget.inv['items'] as List?) ?? [];
    final items = itemsRaw.cast<Map>().map((e) => e.map((k, v) => MapEntry('$k', v))).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Finance Verification', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _primaryDk)),
              const SizedBox(height: 20),
              
              // LEFT CARD equivalent (Marketing Details)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Marketing Details', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _muted)),
                        Text('#${widget.inv['invoiceNo']}', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Divider(height: 24),
                    Text('Customer: ${widget.inv['customerName']}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ...items.map((it) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${it['model']} x${it['qty']}', style: GoogleFonts.inter(fontSize: 13)),
                          Text('৳${_money(((it['unitPrice'] ?? 0) as num) * ((it['qty'] ?? 1) as num))}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Invoice Total', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('৳${_money(_grandTotal)}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: _primary)),
                      ],
                    ),
                    if ((widget.inv['note'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes, size: 16, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(child: Text(widget.inv['note'], style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade900))),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // RIGHT CARD equivalent (Finance Calculation)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Finance Calculation', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _primary)),
                    const Divider(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costController,
                            keyboardType: TextInputType.number,
                            decoration: _decor('Est. Product Cost *'),
                            onChanged: (_) => _calculateProfit(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _otherCostController,
                            keyboardType: TextInputType.number,
                            decoration: _decor('Other Costs'),
                            onChanged: (_) => _calculateProfit(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Net Profit', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                              Text('৳${_money(_netProfit)}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: _netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Profit Margin', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _muted)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: _profitMargin >= 0 ? Colors.green.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                                child: Text('${_profitMargin.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _profitMargin >= 0 ? Colors.green.shade800 : Colors.red.shade800)),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Payment Verified', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      subtitle: Text('I have checked the bank/cash records', style: GoogleFonts.inter(fontSize: 12, color: _muted)),
                      value: _paymentVerified,
                      activeColor: _primary,
                      onChanged: (v) => setState(() => _paymentVerified = v ?? false),
                    ),
                    
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _hrNoteController,
                      maxLines: 2,
                      decoration: _decor('HR/Finance Note (Visible to Marketing)'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: () => _updateStatus('Rejected'),
                      child: Text('Reject / Request Correction', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Confirm Verification'),
                        content: const Text('This will lock the financial calculation and notify Marketing to create the Work Order. Proceed?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _primary),
                            onPressed: () {
                              Navigator.pop(c);
                              _updateStatus('HR Verified');
                            },
                            child: const Text('Verify & Send Back', style: TextStyle(color: Colors.white)),
                          )
                        ],
                      )
                    );
                  },
                  child: Text('Verify & Send to Marketing', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      )
    );
  }
}
