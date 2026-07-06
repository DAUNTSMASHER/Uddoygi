// lib/features/factory/presentation/factory/work_order.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'work_order_details_screen.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/theme/app_fonts.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/features/factory/presentation/widgets/factory_metric_card.dart';
import 'package:uddoygi/core/design_system.dart';

const Color _brandRed = UddoygiDesign.factoryBrandRed;
const Color _surface = UddoygiDesign.surface;
enum _SortMode { newest, oldest }
enum _StatusFilter { all, pending, accepted, rejected }

class WorkOrdersScreen extends StatefulWidget {
  const WorkOrdersScreen({Key? key}) : super(key: key);

  @override
  State<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}
class _WorkOrdersScreenState extends State<WorkOrdersScreen> {
  String _cid = '';
  String _search = '';
  _StatusFilter _filter = _StatusFilter.all;
  _SortMode _sort = _SortMode.newest;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  Future<void> _acceptOrder(String id) async {
    if (_cid.isEmpty) {
      _toast('কোম্পানি আইডি পাওয়া যায়নি। পুনরায় লগইন করুন।');
      return;
    }

    final ok = await _confirm(
      title: 'ওয়ার্ক অর্ডার গ্রহণ করবেন?',
      message: 'এটি অর্ডারটিকে “গ্রহণকৃত” হিসেবে চিহ্নিত করবে এবং উৎপাদন শুরু করার অনুমতি দেবে।',
      confirmText: 'গ্রহণ করুন',
      confirmColor: Colors.green,
    );
    if (ok != true) return;

    try {
      await DB.colSync(_cid, C.workOrders).doc(id).update({
        'status': 'Accepted by Factory',
        'acceptedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'currentStage': 'Prep & Sorting',
        'currentStageIndex': 0,
      });
      _toast('অর্ডার গ্রহণ করা হয়েছে');
    } catch (e) {
      _toast('ত্রুটি: $e');
    }
  }

  Future<void> _rejectOrder(String id) async {
    if (_cid.isEmpty) {
      _toast('কোম্পানি আইডি পাওয়া যায়নি।');
      return;
    }
    final recCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ওয়ার্ক অর্ডার বাতিল'),
        content: TextField(
          controller: recCtl,
          decoration: const InputDecoration(labelText: 'বাতিল করার কারণ/সুপারিশ', border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (recCtl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('নিশ্চিত করুন'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await DB.colSync(_cid, C.workOrders).doc(id).update({
        'status': 'Rejected',
        'recommendation': recCtl.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      _toast('অর্ডার বাতিল করা হয়েছে');
    } catch (e) {
      _toast('ত্রুটি: $e');
    }
  }

  Future<bool?> _confirm({required String title, required String message, required String confirmText, Color? confirmColor}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor ?? _brandRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _formatTs(Timestamp? ts) {
    if (ts == null) return '—';
    return DateFormat('dd MMM, hh:mm a').format(ts.toDate());
  }

  Color _statusColor(String s) {
    if (s == 'Accepted by Factory') return Colors.blue.shade600;
    if (s == 'In Production') return Colors.purple.shade600;
    if (s == 'Completed') return Colors.green.shade600;
    if (s == 'Rejected') return Colors.red.shade600;
    return Colors.orange.shade700; // Awaiting Factory
  }

  String _bnStatusText(String s) {
    if (s == 'Accepted by Factory') return 'গৃহীত';
    if (s == 'In Production') return 'উৎপাদনে আছে';
    if (s == 'Completed') return 'সম্পন্ন';
    if (s == 'Rejected') return 'বাতিল';
    return 'অপেক্ষমাণ';
  }

  Widget _statusChip(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(.1), border: Border.all(color: c.withOpacity(.3)), borderRadius: BorderRadius.circular(20)),
      child: Text(_bnStatusText(status), style: AppFonts.banglaHeading(color: c, fontWeight: FontWeight.w800, fontSize: 10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('ওয়ার্ক অর্ডার ম্যানেজমেন্ট', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF8B0000), // Dark Red
                    Color(0xFFD2042D), // Cherry Red
                    Color(0xFFE57373), // Light Red/Pink
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.workOrders).orderBy('timestamp', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snap.data?.docs ?? [];
          
          int total = docs.length;
          int pend = 0, acc = 0, prod = 0, comp = 0, rej = 0;
          for (final d in docs) {
            final st = (d.data()['status'] as String? ?? 'Awaiting Factory');
            if (st == 'Accepted by Factory') acc++;
            else if (st == 'In Production') prod++;
            else if (st == 'Completed') comp++;
            else if (st == 'Rejected') rej++;
            else pend++;
          }

          final items = docs.where((d) {
            final data = d.data();
            final woNo = (data['workOrderNo'] ?? '').toString();
            final trk = (data['tracking_number'] ?? '').toString();
            final buyer = (data['buyerName'] ?? '').toString();
            final searchStr = '$woNo $trk $buyer'.toLowerCase();
            return searchStr.contains(_search.toLowerCase());
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDashboard(total: total, pending: pend, accepted: acc, prod: prod, comp: comp),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: 'অর্ডার নং, ট্র্যাকিং বা ক্রেতা খুঁজুন...',
                    hintStyle: AppFonts.banglaBody(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: _brandRed, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              if (items.isEmpty) 
                _buildOrderCard({
                  'status': 'Awaiting Factory',
                  'workOrderNo': 'MOCK-1001',
                  'buyerName': 'John Doe (Sample)',
                  'tracking_number': 'TRK-987654321',
                  'items': [1, 2, 3], // 3 items
                  'lastUpdated': Timestamp.now(),
                }, 'mock_id').animate().fadeIn().slideY(begin: 0.1, end: 0)
              else
                ...items.map((doc) => _buildOrderCard(doc.data()!, doc.id).animate().fadeIn().slideY(begin: 0.1, end: 0)),
            ],
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard({required int total, required int pending, required int accepted, required int prod, required int comp}) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.9,
      children: [
        _compactGridMetric('মোট', '$total', Icons.assignment_rounded, _brandRed),
        _compactGridMetric('অপেক্ষমাণ', '$pending', Icons.pending_actions_rounded, Colors.orange),
        _compactGridMetric('গৃহীত', '$accepted', Icons.thumb_up_rounded, Colors.blue),
        _compactGridMetric('উৎপাদনে', '$prod', Icons.precision_manufacturing_rounded, Colors.purple),
      ].animate(interval: 50.ms).fadeIn().slideY(begin: 0.1, end: 0),
    );
  }

  Widget _compactGridMetric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(value, style: AppFonts.banglaHeading(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(title, style: AppFonts.banglaBody(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> data, String docId) {
    final status = data['status'] as String? ?? 'Pending';
    final woNo = data['workOrderNo'] ?? 'N/A';
    final buyer = data['buyerName'] ?? 'N/A';
    final trk = data['tracking_number'] ?? 'N/A';
    final items = (data['items'] as List?)?.length ?? 0;
    final lastUpdate = data['lastUpdated'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.6)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _brandRed.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('WO #$woNo', style: AppFonts.banglaHeading(fontSize: 12, fontWeight: FontWeight.w800, color: _brandRed)),
                _statusChip(status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.person, 'ক্রেতা:', buyer),
                          _infoRow(Icons.local_shipping, 'ট্র্যাকিং:', trk),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.inventory, 'আইটেম:', '$items প্রকার'),
                          _infoRow(Icons.update, 'আপডেট:', _formatTs(lastUpdate)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (status == 'Awaiting Factory') ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => docId == 'mock_id' ? _toast('This is a mock order') : _acceptOrder(docId),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0),
                          child: Text('গ্রহণ করুন', style: AppFonts.banglaBody(fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => docId == 'mock_id' ? _toast('This is a mock order') : _rejectOrder(docId),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade800, padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0),
                          child: Text('বাতিল', style: AppFonts.banglaBody(fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => docId == 'mock_id' ? _toast('This is a mock order') : Navigator.push(context, MaterialPageRoute(builder: (_) => WorkOrderDetailsScreen(orderId: docId))),
                          icon: const Icon(Icons.edit_note, size: 14),
                          label: Text('আপডেট করুন', style: AppFonts.banglaBody(fontWeight: FontWeight.bold, fontSize: 10)),
                          style: ElevatedButton.styleFrom(backgroundColor: _brandRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(color: _brandRed.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                      child: IconButton(
                        onPressed: () => docId == 'mock_id' ? _toast('This is a mock order') : Navigator.push(context, MaterialPageRoute(builder: (_) => WorkOrderDetailsScreen(orderId: docId))),
                        icon: const Icon(Icons.visibility, size: 14),
                        color: _brandRed,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppFonts.banglaBody(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                Text(value, style: AppFonts.banglaHeading(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
