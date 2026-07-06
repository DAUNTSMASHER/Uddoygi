// lib/features/factory/presentation/factory/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:intl/intl.dart';

const Color _brandRed = Color(0xFF991B1B);
const Color _surface = Color(0xFFFDF2F2);
const Color _accentRed = Color(0xFFDC2626);

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _cid = '';
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) {
        setState(() {
          _cid = id ?? '';
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text('ইনভেন্টরি ম্যানেজমেন্ট', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800)),
        backgroundColor: _brandRed,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'বিক্রয়যোগ্য পণ্য', icon: Icon(Icons.inventory_2)),
            Tab(text: 'কাঁচামাল ও সম্পদ', icon: Icon(Icons.reorder)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Analytics Hero Section
          _buildAnalyticsHero(),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'পণ্য বা কাঁচামাল খুঁজুন...',
                prefixIcon: const Icon(Icons.search, color: _brandRed),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFinishedGoodsList(),
                _buildRawMaterialsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsHero() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(_cid, C.products).snapshots(),
      builder: (context, prodSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: DB.colSync(_cid, C.stocks).snapshots(),
          builder: (context, stockSnap) {
            final products = prodSnap.data?.docs ?? [];
            final stocks = stockSnap.data?.docs ?? [];

            double totalValue = 0;
            int lowStockCount = 0;

            for (var doc in products) {
              final data = doc.data();
              final qty = (data['stock'] as num?) ?? 0;
              final price = (data['unit_price'] as num?) ?? 0;
              totalValue += (qty * price);
              if (qty < 10) lowStockCount++;
            }

            for (var doc in stocks) {
              final data = doc.data();
              final qty = (data['qty'] as num?) ?? 0;
              final min = (data['minThreshold'] as num?) ?? 0;
              if (qty < min) lowStockCount++;
            }

            return Container(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2,
                children: [
                  _SummaryCard(
                    title: 'মোট স্টকের মূল্য',
                    value: '৳${NumberFormat.compact().format(totalValue)}',
                    icon: Icons.account_balance_wallet,
                    color: _brandRed,
                  ),
                  _SummaryCard(
                    title: 'স্বল্প স্টক অ্যালার্ট',
                    value: '$lowStockCount',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange.shade800,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFinishedGoodsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(_cid, C.products).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snap.data!.docs.where((d) {
          final name = (d.data()['model_name'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery.toLowerCase());
        }).toList();

        if (docs.isEmpty) return _buildEmptyState('কোনো পণ্য পাওয়া যায়নি');

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final stock = (data['stock'] as num?) ?? 0;
            final isLow = stock < 10;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isLow ? Colors.red.shade200 : Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _brandRed.withOpacity(0.1),
                  child: const Icon(Icons.inventory_2, color: _brandRed, size: 20),
                ),
                title: Text(data['model_name'] ?? 'N/A', style: AppFonts.banglaHeading(fontWeight: FontWeight.w700)),
                subtitle: Text('রঙ: ${data['colour'] ?? '-'} | সাইজ: ${data['size'] ?? '-'}', style: AppFonts.banglaBody(fontSize: 12)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$stock Pcs', style: AppFonts.banglaData(fontWeight: FontWeight.w900, color: isLow ? Colors.red : Colors.black)),
                    Text('৳${data['unit_price'] ?? 0}', style: AppFonts.banglaData(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRawMaterialsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(_cid, C.stocks).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snap.data!.docs.where((d) {
          final name = (d.data()['name'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery.toLowerCase());
        }).toList();

        if (docs.isEmpty) return _buildEmptyState('কোনো কাঁচামাল পাওয়া যায়নি');

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final qty = (data['qty'] as num?) ?? 0;
            final min = (data['minThreshold'] as num?) ?? 0;
            final isLow = qty < min;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isLow ? Colors.red.shade200 : Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(Icons.reorder, color: Colors.blue, size: 20),
                ),
                title: Text(data['name'] ?? 'N/A', style: AppFonts.banglaHeading(fontWeight: FontWeight.w700)),
                subtitle: Text('SKU: ${data['sku'] ?? '-'}', style: AppFonts.banglaBody(fontSize: 12)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$qty ${data['unit'] ?? ''}', style: AppFonts.banglaData(fontWeight: FontWeight.w900, color: isLow ? Colors.red : Colors.black)),
                    Text('মিনিমাম: $min', style: AppFonts.banglaBody(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg, style: AppFonts.banglaBody(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: AppFonts.banglaBody(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: AppFonts.banglaData(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
