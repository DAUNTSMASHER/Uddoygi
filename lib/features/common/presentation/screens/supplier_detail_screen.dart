import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/drive_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SupplierDetailScreen extends StatefulWidget {
  final String supplierId;
  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  String _cid = '';
  final _picker = ImagePicker();

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

    return StreamBuilder<DocumentSnapshot>(
      stream: DB.colSync(_cid, C.suppliers).doc(widget.supplierId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final data = snapshot.data!.data() as Map<String, dynamic>;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(data['name'] ?? 'Supplier Details', 
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          floatingActionButton: _buildFAB(data),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIdentityCard(data),
                const SizedBox(height: 20),
                _buildBusinessDealCard(data),
                const SizedBox(height: 20),
                _buildFinancialSnapshot(data),
                const SizedBox(height: 20),
                Text('Accountability Ledger', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                const SizedBox(height: 12),
                _buildLedgerTable(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  // —— 1. Identity Card ——
  Widget _buildIdentityCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text((data['name'] ?? 'S')[0], style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    Text(data['category'] ?? 'General', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(Icons.phone, 'Call', Colors.green, () => launchUrl(Uri.parse('tel:${data['phone']}'))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(Icons.message, 'WhatsApp', const Color(0xFF25D366), () => launchUrl(Uri.parse('whatsapp://send?phone=${data['phone']}'))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.person_outline, 'Primary Contact', data['contactPerson'] ?? 'N/A'),
          _buildInfoRow(Icons.warehouse_outlined, 'Monthly Capacity', '${data['capacity'] ?? 0} units'),
        ],
      ),
    );
  }

  // —— 2. Business Deal Card ——
  Widget _buildBusinessDealCard(Map<String, dynamic> data) {
    final status = data['dealStatus'] ?? 'Active';
    final statusColor = status == 'Active' ? Colors.green : (status == 'On Hold' ? Colors.orange : Colors.grey);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Business Deal', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Agreed Materials'),
          Text(data['agreedItems'] ?? 'No materials listed', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700])),
          const SizedBox(height: 16),
          _buildSectionHeader('"Handshake" Terms (Verbal)'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(12)),
            child: Text(data['handshakeTerms']?.isEmpty == true ? 'No verbal terms recorded' : data['handshakeTerms'], 
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.brown[700], fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }

  // —— 3. Financial Snapshot ——
  Widget _buildFinancialSnapshot(Map<String, dynamic> data) {
    final balance = (data['balance'] ?? 0.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFinanceMetric('Total Purchases', '৳${data['totalPurchases'] ?? 0}', Colors.white70),
              _buildFinanceMetric('Amount Paid', '৳${data['totalPaid'] ?? 0}', Colors.white70),
            ],
          ),
          const Divider(color: Colors.white12, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Balance Owed', style: GoogleFonts.outfit(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
              Text('৳${balance.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 24, color: balance > 0 ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  // —— 4. Ledger Table ——
  Widget _buildLedgerTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(_cid, C.suppliers).doc(widget.supplierId).collection('ledger').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) return Center(child: Text('No transactions yet', style: GoogleFonts.outfit(color: Colors.grey)));

        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
          child: Column(
            children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final isPurchase = d['type'] == 'purchase';
              final date = d['timestamp'] != null ? (d['timestamp'] as Timestamp).toDate() : DateTime.now();

              return ListTile(
                onTap: d['invoiceUrl'] != null ? () => _viewInvoice(d['invoiceUrl']) : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: isPurchase ? Colors.red[50] : Colors.green[50], borderRadius: BorderRadius.circular(8)),
                  child: Icon(isPurchase ? Icons.arrow_downward : Icons.arrow_upward, size: 20, color: isPurchase ? Colors.red : Colors.green),
                ),
                title: Text(d['description'] ?? (isPurchase ? 'Purchase' : 'Payment'), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(date), style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${isPurchase ? "" : "-" }৳${d['amount']}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: isPurchase ? Colors.red : Colors.green)),
                    Text(d['status'] ?? 'Completed', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[400])),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // —— Helpers ——
  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Text('$label: ', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500])),
          Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 0.5)),
    );
  }

  Widget _buildFinanceMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 12, color: color)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildFAB(Map<String, dynamic> supplier) {
    return FloatingActionButton.extended(
      onPressed: () => _showActionSheet(supplier),
      label: const Text('Actions', style: TextStyle(color: Colors.white)),
      icon: const Icon(Icons.bolt, color: Colors.white),
      backgroundColor: const Color(0xFF2563EB),
    );
  }

  void _showActionSheet(Map<String, dynamic> supplier) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionItem(Icons.add_photo_alternate, 'Add Purchase / Invoice', Colors.red, () { Navigator.pop(context); _logPurchase(supplier); }),
            _buildActionItem(Icons.payments, 'Log Payment', Colors.green, () { Navigator.pop(context); _logPayment(supplier); }),
            _buildActionItem(Icons.handshake, 'Update Deal Terms', Colors.blue, () { Navigator.pop(context); _editDealTerms(supplier); }),
            _buildActionItem(Icons.warehouse, 'Update Capacity', Colors.orange, () { Navigator.pop(context); _updateCapacity(supplier); }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)),
      title: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }

  // —— Transaction Logics ——

  void _logPurchase(Map<String, dynamic> supplier) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedStockId;
    File? invoiceFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Purchase'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: DB.colSync(_cid, C.stocks).orderBy('name').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const CircularProgressIndicator();
                    return DropdownButtonFormField<String>(
                      value: selectedStockId,
                      decoration: const InputDecoration(labelText: 'Raw Material'),
                      items: snap.data!.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d['name'] ?? ''))).toList(),
                      onChanged: (v) => setDialogState(() => selectedStockId = v),
                    );
                  }
                ),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount (৳)'), keyboardType: TextInputType.number),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Quantity/Description')),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final img = await _picker.pickImage(source: ImageSource.camera);
                    if (img != null) setDialogState(() => invoiceFile = File(img.path));
                  },
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                    child: invoiceFile == null 
                      ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt), Text('Snap Invoice Photo')])
                      : Image.file(invoiceFile!, fit: BoxFit.cover),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (amountCtrl.text.isEmpty || selectedStockId == null) return;
                Navigator.pop(context);
                
                String? url;
                if (invoiceFile != null) {
                  final result = await DriveStorageService.instance.uploadFile(invoiceFile!, pathPrefix: 'invoices');
                  url = result.viewUrl;
                }

                final amount = double.parse(amountCtrl.text);
                final ledgerRef = DB.colSync(_cid, C.suppliers).doc(widget.supplierId).collection('ledger').doc();
                
                await ledgerRef.set({
                  'type': 'purchase',
                  'amount': amount,
                  'description': descCtrl.text,
                  'stockId': selectedStockId,
                  'invoiceUrl': url,
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'Invoiced',
                });

                // Update Supplier Totals
                await DB.colSync(_cid, C.suppliers).doc(widget.supplierId).update({
                  'totalPurchases': FieldValue.increment(amount),
                  'balance': FieldValue.increment(amount),
                });

                // ERP Integration: Update Stock
                // We'll extract numeric value from description if possible, or just log activity
                await _updateStock(selectedStockId!, descCtrl.text, supplier['name']);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _logPayment(Map<String, dynamic> supplier) async {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Payment'),
        content: TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount Paid (৳)'), keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (amountCtrl.text.isEmpty) return;
              Navigator.pop(context);
              final amount = double.parse(amountCtrl.text);
              
              await DB.colSync(_cid, C.suppliers).doc(widget.supplierId).collection('ledger').add({
                'type': 'payment',
                'amount': amount,
                'description': 'Payment',
                'timestamp': FieldValue.serverTimestamp(),
                'status': 'Paid',
              });

              await DB.colSync(_cid, C.suppliers).doc(widget.supplierId).update({
                'totalPaid': FieldValue.increment(amount),
                'balance': FieldValue.increment(-amount),
              });
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _editDealTerms(Map<String, dynamic> supplier) {
    final termsCtrl = TextEditingController(text: supplier['handshakeTerms']);
    String status = supplier['dealStatus'] ?? 'Active';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Deal Terms'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: status,
                items: ['Active', 'On Hold', 'Completed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setDialogState(() => status = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: termsCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Verbal Terms / Handshake', border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                DB.colSync(_cid, C.suppliers).doc(widget.supplierId).update({
                  'dealStatus': status,
                  'handshakeTerms': termsCtrl.text.trim(),
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateCapacity(Map<String, dynamic> supplier) {
    final capCtrl = TextEditingController(text: (supplier['capacity'] ?? 0).toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Capacity'),
        content: TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Monthly Limit'), keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              DB.colSync(_cid, C.suppliers).doc(widget.supplierId).update({'capacity': double.tryParse(capCtrl.text) ?? 0.0});
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStock(String stockId, String desc, String supplierName) async {
    // Attempt to extract quantity (e.g. "500kg Steel" -> 500)
    final match = RegExp(r'(\d+)').firstMatch(desc);
    double qty = 0;
    if (match != null) qty = double.parse(match.group(0)!);

    final ref = DB.colSync(_cid, C.stocks).doc(stockId);
    await ref.update({'qty': FieldValue.increment(qty)});
    
    // Log in stock subcollection
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await ref.collection('logs').doc(today).set({
      'delta': qty,
      'note': 'Purchased from $supplierName',
      'ts': FieldValue.serverTimestamp(),
      'type': 'in',
    }, SetOptions(merge: true));
  }

  void _viewInvoice(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(url, loadingBuilder: (_, child, prog) => prog == null ? child : const CircularProgressIndicator()),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}
