import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  String _cid = '';
  final _priceController    = TextEditingController();
  final _quantityController = TextEditingController();
  final _supplierController = TextEditingController();
  final _productController  = TextEditingController();
  final _agentController    = TextEditingController();

  String? _selectedInvoice;
  final Color _heroMaroon = const Color(0xFF40062D);

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _supplierController.dispose();
    _productController.dispose();
    _agentController.dispose();
    super.dispose();
  }

  Future<void> _acceptPO(String docId) async {
    if (_cid.isEmpty) return;
    await DB.colSync(_cid, C.purchaseOrders).doc(docId).update({
      'status': 'accepted',
      'acceptedAt': Timestamp.now(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Purchase order accepted'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _rejectPO(String docId) async {
    if (_cid.isEmpty) return;
    String? recommendation;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UddoygiDesign.radiusL)),
        title: Text('Reject Purchase Order', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: TextFormField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason / Recommendation'),
          onChanged: (v) => recommendation = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if ((recommendation ?? '').trim().isEmpty) return;
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Submit'),
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Purchase order rejected'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _submitPurchaseDetails() async {
    if (_productController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _quantityController.text.isEmpty ||
        _supplierController.text.isEmpty ||
        _selectedInvoice == null ||
        _agentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    await DB.colSync(_cid, C.productPrices).add({
      'product':   _productController.text.trim(),
      'price':     double.tryParse(_priceController.text.trim()) ?? 0,
      'quantity':  int.tryParse(_quantityController.text.trim()) ?? 0,
      'supplier':  _supplierController.text.trim(),
      'invoice':   _selectedInvoice,
      'agent':     _agentController.text.trim(),
      'timestamp': Timestamp.now(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📝 Purchase details saved.'), behavior: SnackBarBehavior.floating),
      );
    }

    _priceController.clear();
    _quantityController.clear();
    _supplierController.clear();
    _productController.clear();
    _agentController.clear();
    setState(() => _selectedInvoice = null);
  }

  Future<List<String>> _getInvoiceIDs() async {
    if (_cid.isEmpty) return [];
    final snap = await DB.colSync(_cid, C.invoices).get();
    return snap.docs.map((d) => d.id).toList();
  }

  Future<String?> _getAgentForInvoice(String invoiceId) async {
    if (_cid.isEmpty) return null;
    final doc = await DB.colSync(_cid, C.invoices).doc(invoiceId).get();
    return doc.data()?['submittedBy'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        title: Text('Purchase Orders', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _heroMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(UddoygiDesign.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: _heroMaroon, borderRadius: UddoygiDesign.borderFull)),
                const SizedBox(width: 10),
                Text('Active Orders', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E0040))),
              ],
            ),
            const SizedBox(height: UddoygiDesign.space16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _cid.isEmpty
                  ? const Stream.empty()
                  : DB.colSync(_cid, C.purchaseOrders).orderBy('timestamp', descending: true).snapshots(),
              builder: (ctx, snap) {
                if (_cid.isEmpty || snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return Center(child: Text('No orders found.', style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontWeight: FontWeight.w600)));
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final status = data['status'] as String? ?? 'pending';
                    final ts = data['expectedDate'] as Timestamp?;
                    
                    return UCard(
                      margin: const EdgeInsets.only(bottom: UddoygiDesign.space12),
                      padding: const EdgeInsets.all(UddoygiDesign.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('PO #: ${data['poNo'] ?? doc.id}', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: _heroMaroon)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: UddoygiDesign.borderFull),
                                child: Text(status.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: _getStatusColor(status))),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _OrderRow(Icons.business_rounded, 'Supplier', data['supplierName'] ?? '—'),
                          _OrderRow(Icons.person_rounded, 'Submitted By', data['submittedBy'] ?? '—'),
                          _OrderRow(Icons.event_rounded, 'Expected Date', ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : '—'),
                          _OrderRow(Icons.shopping_bag_rounded, 'Items', '${(data['items'] as List?)?.length ?? 0} items'),
                          if (status == 'pending') ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _ActionBtn(label: 'Accept', icon: Icons.check_rounded, color: Colors.green, onTap: () => _acceptPO(doc.id))),
                                const SizedBox(width: 12),
                                Expanded(child: _ActionBtn(label: 'Reject', icon: Icons.close_rounded, color: Colors.redAccent, outlined: true, onTap: () => _rejectPO(doc.id))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms * i).slideX(begin: 0.1, end: 0);
                  },
                );
              },
            ),
            const SizedBox(height: UddoygiDesign.space32),
            Row(
              children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: _heroMaroon, borderRadius: UddoygiDesign.borderFull)),
                const SizedBox(width: 10),
                Text('Product Price Entry', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E0040))),
              ],
            ),
            const SizedBox(height: UddoygiDesign.space16),
            UCard(
              padding: const EdgeInsets.all(UddoygiDesign.space20),
              child: Column(
                children: [
                  FutureBuilder<List<String>>(
                    future: _getInvoiceIDs(),
                    builder: (ctx, snap) {
                      return DropdownButtonFormField<String>(
                        value: _selectedInvoice,
                        decoration: _inputDeco('Invoice Number', Icons.receipt_long_rounded),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                        items: (snap.data ?? []).map((id) => DropdownMenuItem(value: id, child: Text(id))).toList(),
                        onChanged: (val) async {
                          final agent = await _getAgentForInvoice(val!);
                          setState(() {
                            _selectedInvoice = val;
                            _agentController.text = agent ?? '';
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _EditField(controller: _agentController, label: 'Agent Name', icon: Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _EditField(controller: _productController, label: 'Product Name', icon: Icons.inventory_2_outlined),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _EditField(controller: _quantityController, label: 'Quantity', icon: Icons.numbers_rounded, keyboard: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: _EditField(controller: _priceController, label: 'Unit Price', icon: Icons.attach_money_rounded, keyboard: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _EditField(controller: _supplierController, label: 'Supplier Name', icon: Icons.business_outlined),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _submitPurchaseDetails,
                      icon: const Icon(Icons.save_rounded),
                      label: Text('Save Price Entry', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15)),
                      style: ElevatedButton.styleFrom(backgroundColor: _heroMaroon, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)), elevation: 0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String s) {
    if (s == 'accepted') return Colors.green;
    if (s == 'rejected') return Colors.redAccent;
    return Colors.orange;
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: _heroMaroon),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    labelStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
}

class _OrderRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _OrderRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
      ],
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap, this.outlined = false});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: outlined
        ? OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UddoygiDesign.radiusS))),
          )
        : ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UddoygiDesign.radiusS))),
          ),
  );
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  const _EditField({required this.controller, required this.label, required this.icon, this.keyboard = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboard,
    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF40062D)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}
