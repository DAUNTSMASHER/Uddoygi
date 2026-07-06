// lib/widgets/u_inventory_analytics.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:intl/intl.dart';

class UInventoryAnalytics extends StatefulWidget {
  final Color themeColor;
  const UInventoryAnalytics({Key? key, this.themeColor = const Color(0xFF991B1B)}) : super(key: key);

  @override
  State<UInventoryAnalytics> createState() => _UInventoryAnalyticsState();
}

class _UInventoryAnalyticsState extends State<UInventoryAnalytics> {
  String _cid = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() { _cid = id ?? ''; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.products).snapshots(),
      builder: (context, prodSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.stocks).snapshots(),
          builder: (context, stockSnap) {
            final products = prodSnap.data?.docs ?? [];
            final stocks = stockSnap.data?.docs ?? [];

            double finishedValue = 0;
            int lowStockCount = 0;
            int totalItems = products.length + stocks.length;

            for (var doc in products) {
              final data = doc.data();
              final qty = (data['stock'] as num?) ?? 0;
              final price = (data['unit_price'] as num?) ?? 0;
              finishedValue += (qty * price);
              if (qty < 10) lowStockCount++;
            }

            for (var doc in stocks) {
              final data = doc.data();
              final qty = (data['qty'] as num?) ?? 0;
              final min = (data['minThreshold'] as num?) ?? 0;
              if (qty < min) lowStockCount++;
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ইনভেন্টরি সারাংশ', style: AppFonts.banglaHeading(fontWeight: FontWeight.bold, fontSize: 14, color: widget.themeColor)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _AnalyticsItem(
                        label: 'বিক্রয়যোগ্য মূল্য',
                        value: ('৳${NumberFormat.compact().format(finishedValue)}').toBanglaDigits,
                        color: widget.themeColor,
                      ),
                      const SizedBox(width: 8),
                      _AnalyticsItem(
                        label: 'স্বল্প স্টক',
                        value: ('$lowStockCount আইটেম').toBanglaDigits,
                        color: widget.themeColor,
                      ),
                      const SizedBox(width: 8),
                      _AnalyticsItem(
                        label: 'মোট পণ্য',
                        value: ('$totalItems').toBanglaDigits,
                        color: widget.themeColor,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AnalyticsItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnalyticsItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppFonts.banglaBody(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Text(value, style: AppFonts.banglaData(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}