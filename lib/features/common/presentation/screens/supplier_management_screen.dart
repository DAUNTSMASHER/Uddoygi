import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:intl/intl.dart';

class SupplierManagementScreen extends StatefulWidget {
  const SupplierManagementScreen({super.key});

  @override
  State<SupplierManagementScreen> createState() => _SupplierManagementScreenState();
}

class _SupplierManagementScreenState extends State<SupplierManagementScreen> {
  String _cid = '';
  final _searchCtrl = TextEditingController();
  String _filterCategory = 'All';
  String _sortBy = 'Name';

  final List<String> _categories = ['All', 'Raw Materials', 'Packaging', 'Logistics', 'Hardware', 'Other'];
  final List<String> _sortOptions = ['Name', 'Highest Owed', 'Highest Capacity'];

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Supplier Directory', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSupplierDialog(),
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(child: _buildSupplierList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search suppliers...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Sort by: ', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _sortOptions.map((opt) {
                      final isSel = _sortBy == opt;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _sortBy = opt),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF2563EB) : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(opt, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: _categories.map((cat) {
          final isSel = _filterCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat, style: GoogleFonts.outfit(
                fontSize: 12, 
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                color: isSel ? Colors.white : Colors.grey[700],
              )),
              selected: isSel,
              onSelected: (val) => setState(() => _filterCategory = cat),
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: isSel ? Colors.transparent : Colors.grey[200]!),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSupplierList() {
    if (_cid.isEmpty) return const Center(child: CircularProgressIndicator());

    Query<Map<String, dynamic>> query = DB.colSync(_cid, C.suppliers);
    if (_filterCategory != 'All') {
      query = query.where('category', isEqualTo: _filterCategory);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        var filtered = docs.where((doc) {
          final name = (doc['name'] ?? '').toString().toLowerCase();
          final contact = (doc['contactPerson'] ?? '').toString().toLowerCase();
          final search = _searchCtrl.text.toLowerCase();
          return name.contains(search) || contact.contains(search);
        }).toList();

        // Sort logic
        if (_sortBy == 'Highest Owed') {
          filtered.sort((a, b) => ((b.data() as Map)['balance'] ?? 0.0).compareTo((a.data() as Map)['balance'] ?? 0.0));
        } else if (_sortBy == 'Highest Capacity') {
          filtered.sort((a, b) => ((b.data() as Map)['capacity'] ?? 0.0).compareTo((a.data() as Map)['capacity'] ?? 0.0));
        } else {
          filtered.sort((a, b) => (a.data() as Map)['name'].toString().compareTo((b.data() as Map)['name'].toString()));
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No suppliers found', style: GoogleFonts.outfit(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data() as Map<String, dynamic>;
            return _SupplierCard(
              id: doc.id,
              data: data,
              onTap: () => Navigator.pushNamed(context, '/common/suppliers/detail', arguments: doc.id),
              onEdit: () => _showSupplierDialog(id: doc.id, data: data),
              onDelete: () => _deleteSupplier(doc.id),
            );
          },
        );
      },
    );
  }

  void _showSupplierDialog({String? id, Map<String, dynamic>? data}) {
    final nameCtrl = TextEditingController(text: data?['name']);
    final contactCtrl = TextEditingController(text: data?['contactPerson']);
    final phoneCtrl = TextEditingController(text: data?['phone']);
    final capacityCtrl = TextEditingController(text: (data?['capacity'] ?? 0).toString());
    final itemsCtrl = TextEditingController(text: data?['agreedItems']);
    String cat = data?['category'] ?? 'Raw Materials';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(id == null ? 'Add New Supplier' : 'Edit Supplier', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameCtrl, 'Company Name', Icons.business),
                const SizedBox(height: 12),
                _buildTextField(contactCtrl, 'Primary Contact Person', Icons.person),
                const SizedBox(height: 12),
                _buildTextField(phoneCtrl, 'Phone (WhatsApp)', Icons.phone, keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: cat,
                  decoration: _inputDecoration('Group / Category', Icons.category),
                  items: _categories.where((c) => c != 'All').map((c) => 
                    DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.outfit(fontSize: 14)))
                  ).toList(),
                  onChanged: (v) => setDialogState(() => cat = v!),
                ),
                const SizedBox(height: 12),
                _buildTextField(capacityCtrl, 'Monthly Capacity (e.g. 5000)', Icons.warehouse, keyboard: TextInputType.number),
                const SizedBox(height: 12),
                _buildTextField(itemsCtrl, 'Agreed Materials (e.g. Steel, Fabric)', Icons.list, maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final payload = {
                  'name': nameCtrl.text.trim(),
                  'contactPerson': contactCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'category': cat,
                  'capacity': double.tryParse(capacityCtrl.text) ?? 0.0,
                  'agreedItems': itemsCtrl.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  if (id == null) ...{
                    'createdAt': FieldValue.serverTimestamp(),
                    'balance': 0.0,
                    'totalPurchases': 0.0,
                    'totalPaid': 0.0,
                    'dealStatus': 'Active',
                    'handshakeTerms': '',
                  }
                };

                if (id == null) {
                  await DB.colSync(_cid, C.suppliers).add(payload);
                } else {
                  await DB.colSync(_cid, C.suppliers).doc(id).update(payload);
                }
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: Text(id == null ? 'Add' : 'Save', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboard, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: GoogleFonts.outfit(fontSize: 14),
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500]),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey[400]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  void _deleteSupplier(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) await DB.colSync(_cid, C.suppliers).doc(id).delete();
  }
}

class _SupplierCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({required this.id, required this.data, required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final balance = (data['balance'] ?? 0.0).toDouble();
    final capacity = (data['capacity'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(data['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                      child: Text(data['category'] ?? 'General', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(data['contactPerson'] ?? 'N/A', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                    const Spacer(),
                    if (balance > 0)
                      Text('Owed: ৳${balance.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.warehouse_outlined, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text('Cap: ${capacity.toStringAsFixed(0)} units/mo', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
