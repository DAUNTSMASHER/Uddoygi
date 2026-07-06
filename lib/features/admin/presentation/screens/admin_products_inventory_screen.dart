import 'package:flutter/material.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminProductsInventoryScreen extends StatefulWidget {
  const AdminProductsInventoryScreen({super.key});

  @override
  State<AdminProductsInventoryScreen> createState() => _AdminProductsInventoryScreenState();
}

class _AdminProductsInventoryScreenState extends State<AdminProductsInventoryScreen> {
  String _cid = '';
  String _search = '';

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

    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        title: Text(
          'Inventory & Costing',
          style: AppFonts.banglaBody(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E0040), // _heroPurple
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: UddoygiDesign.space20, vertical: UddoygiDesign.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGlobalStats(),
            const SizedBox(height: UddoygiDesign.space24),
            _buildSearchBar(),
            const SizedBox(height: UddoygiDesign.space16),
            _buildProductList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalStats() {
    return Row(
      children: [
        Expanded(child: _globalStatCard('Total Stock', '4,250', Icons.inventory_2_rounded, const Color(0xFF7C3AED))),
        const SizedBox(width: UddoygiDesign.space12),
        Expanded(child: _globalStatCard('Avg Wastage', '3.8%', Icons.delete_sweep_rounded, Colors.redAccent)),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.02, end: 0);
  }

  Widget _globalStatCard(String label, String value, IconData icon, Color color) {
    return UCard(
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(UddoygiDesign.radiusM),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: UddoygiDesign.space12),
          Text(
            value,
            style: AppFonts.banglaHeading(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          Text(
            label,
            style: AppFonts.banglaBody(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return UCard(
      padding: EdgeInsets.zero,
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search product BOM, specs, costing...',
          hintStyle: AppFonts.banglaBody(fontSize: 14, color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF7C3AED)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    // Simulated product data
    final products = [
      {'name': 'Executive Office Chair', 'sku': 'CH-001', 'stock': 120, 'cost': 4500, 'wastage': '2.1%', 'img': '🪑'},
      {'name': 'Gaming Desk Pro', 'sku': 'DK-052', 'stock': 45, 'cost': 8200, 'wastage': '4.5%', 'img': '🎮'},
      {'name': 'Mesh Back Task Chair', 'sku': 'CH-088', 'stock': 310, 'cost': 3200, 'wastage': '1.8%', 'img': '💺'},
    ];

    final filtered = products.where((p) => p['name'].toString().toLowerCase().contains(_search.toLowerCase())).toList();

    return Column(
      children: filtered.map((p) => _productCard(p)).toList(),
    );
  }

  Widget _productCard(Map<String, dynamic> p) {
    return UCard(
      margin: const EdgeInsets.only(bottom: UddoygiDesign.space16),
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(UddoygiDesign.radiusM),
                ),
                child: Center(child: Text(p['img'], style: AppFonts.banglaBody(fontSize: 28))),
              ),
              const SizedBox(width: UddoygiDesign.space16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['name'], style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('SKU: ${p['sku']}', style: AppFonts.banglaBody(fontSize: 12, color: Colors.grey[500])),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('৳${p['cost']}', style: AppFonts.banglaData(fontWeight: FontWeight.w900, color: Color(0xFF1E0040))),
                Text('Unit Cost', style: AppFonts.banglaBody(fontSize: 10, color: Colors.grey[500])),
              ]),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: UddoygiDesign.space12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _specItem('Stock', '${p['stock']}', const Color(0xFF7C3AED)),
              _specItem('Wastage', p['wastage'], Colors.redAccent),
              TextButton.icon(
                onPressed: () => _showBOMDialog(p['name']),
                icon: const Icon(Icons.list_alt_rounded, size: 16),
                label: Text('BOM Breakdown', style: AppFonts.banglaBody(fontSize: 13, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _specItem(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppFonts.banglaBody(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600)),
        Text(val, style: AppFonts.banglaData(fontWeight: FontWeight.w800, color: color, fontSize: 15)),
      ],
    );
  }

  void _showBOMDialog(String productName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      isScrollControlled: true,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: DB.colSync(_cid, C.stocks).snapshots(),
        builder: (context, snap) {
          final stockMap = { for (var d in (snap.data?.docs ?? [])) (d.data() as Map)['itemName']: d.data() as Map };

          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bill of Materials (BOM)', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('Live Stock Sync', style: AppFonts.banglaBody(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(productName, style: AppFonts.banglaBody(color: Colors.grey)),
                const SizedBox(height: 20),
                _bomRow('Steel Frame (Main)', '1 unit', '৳1,200', stockMap['Steel Frame (Main)']),
                _bomRow('Mesh Fabric (Black)', '2.5m', '৳450', stockMap['Mesh Fabric (Black)']),
                _bomRow('Gas Lift (Class 4)', '1 unit', '৳850', stockMap['Gas Lift (Class 4)']),
                _bomRow('Wheels (Set of 5)', '1 unit', '৳300', stockMap['Wheels (Set of 5)']),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Material Cost', style: AppFonts.banglaBody(fontWeight: FontWeight.bold)),
                    Text('৳2,800', style: AppFonts.banglaBody(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Close Breakdown'),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _bomRow(String label, String qty, String cost, Map? stockItem) {
    final double available = (stockItem?['quantity'] ?? 0).toDouble();
    final bool isLow = available < 1.0; // Simplified logic for demo

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppFonts.banglaBody(fontSize: 13, fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    Icon(isLow ? Icons.error_outline : Icons.check_circle_outline, 
                         size: 10, color: isLow ? Colors.red : Colors.green),
                    const SizedBox(width: 4),
                    Text(isLow ? 'Stock Low: $available' : 'In Stock: $available', 
                         style: AppFonts.banglaBody(fontSize: 10, color: isLow ? Colors.red : Colors.green)),
                  ],
                ),
              ],
            ),
          ),
          Row(children: [
            Text(qty, style: AppFonts.banglaBody(color: Colors.grey, fontSize: 12)),
            const SizedBox(width: 12),
            Text(cost, style: AppFonts.banglaBody(fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }
}
