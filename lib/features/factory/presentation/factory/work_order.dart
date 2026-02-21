// lib/features/factory/presentation/screens/work_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'work_order_details_screen.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

/// ব্র্যান্ড প্যালেট (ড্যাশবোর্ডের সাথে সামঞ্জস্য)
const Color _brandTeal  = Color(0xFF40062D);
const Color _indigoCard = Color(0xFFA82295);
const Color _surface    = Color(0xFFF4FBFB);
const Color _boardDark  = Color(0xFFB63838);

enum _StatusFilter { all, pending, accepted, rejected }
enum _SortMode { newest, oldest }

class WorkOrdersScreen extends StatefulWidget {
  const WorkOrdersScreen({Key? key}) : super(key: key);

  @override
  State<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

/// Reusable compact dashboard metric card (same visual language as Progress page)
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.subtitle,
  }) : super(key: key);

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 10,
            top: 10,
            child: Icon(icon, size: 22, color: accent.withOpacity(0.22)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label — cap at 8sp
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 6),
                // Value — can be larger for emphasis
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkOrdersScreenState extends State<WorkOrdersScreen> {
  String _cid = '';


  // ---------- UI State ----------
  String _search = '';                         // 🔎 সার্চ টেক্সট
  _StatusFilter _filter = _StatusFilter.all;   // 🚦 স্ট্যাটাস ফিল্টার
  _SortMode _sort = _SortMode.newest;          // ↕️ সোর্টিং মোড

  // ---------- Actions ----------
  /// ✅ অর্ডার গ্রহণ করা
  Future<void> _acceptOrder(String id) async {
    final ok = await _confirm(
      title: 'ওয়ার্ক অর্ডার গ্রহণ করবেন?',
      message: 'এটি অর্ডারটিকে “গ্রহণকৃত” হিসেবে চিহ্নিত করবে।',
      confirmText: 'গ্রহণ করুন',
      confirmColor: Colors.green,
    );
    if (ok != true) return;

    try {
      await (await DB.col(C.workOrders)).doc(id).update({
        'status': 'Accepted',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('অর্ডার গ্রহণ করা হয়েছে')),
        );
      }
    } catch (e) {
      _toast('গ্রহণ করতে সমস্যা: $e');
    }
  }

  /// ❌ অর্ডার বাতিল করা (সাথে সুপারিশ/কারণ নেওয়া)
  Future<void> _rejectOrder(String id) async {
    final recCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ওয়ার্ক অর্ডার বাতিল'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'সংক্ষিপ্ত সুপারিশ/কারণ লিখুন (আবশ্যক)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: recCtl,
              decoration: const InputDecoration(
                hintText: 'সুপারিশ/কারণ লিখুন…',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('বাতিল করুন'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (recCtl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('নিশ্চিত'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await (await DB.col(C.workOrders)).doc(id).update({
        'status': 'Rejected',
        'recommendation': recCtl.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      _toast('সুপারিশ সংরক্ষণ করা হয়েছে');
    } catch (e) {
      _toast('সুপারিশ সংরক্ষণে সমস্যা: $e');
    }
  }

  /// ✅/❌ কনফার্মেশন ডায়ালগ
  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor ?? _brandTeal),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 🧃 Snackbar টোস্ট
  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------- Helpers ----------
  /// 🗓️ টাইমস্ট্যাম্প → সুন্দর ফরম্যাট
  String _formatTs(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    return DateFormat('dd MMM, hh:mm a').format(d);
  }

  /// 🎨 স্ট্যাটাস কালার
  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'accepted':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      case 'in_progress':
      case 'open':
      case 'pending':
      default:
        return Colors.orange.shade700;
    }
  }

  /// 🔤 স্ট্যাটাসের বাংলা টেক্সট
  String _bnStatusText(String s) {
    switch (s.toLowerCase()) {
      case 'accepted':
        return 'গ্রহণকৃত';
      case 'rejected':
        return 'বাতিল';
      case 'in_progress':
      case 'open':
      case 'pending':
      default:
        return 'অপেক্ষমাণ';
    }
  }

  /// 🔖 স্ট্যাটাস চিপ (বাংলা) — tiny variant (≤ 8sp)
  Widget _statusChip(String status) {
    final c = _statusColor(status);
    final t = _bnStatusText(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        border: Border.all(color: c.withOpacity(.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 8),
      ),
    );
  }

  /// 🚦 ফিল্টার অনুযায়ী মিল আছে কি না
  bool _matchesFilter(String status) {
    switch (_filter) {
      case _StatusFilter.all:
        return true;
      case _StatusFilter.pending:
        return (status.toLowerCase() == 'pending' ||
            status.toLowerCase() == 'open' ||
            status.toLowerCase() == 'in_progress');
      case _StatusFilter.accepted:
        return status.toLowerCase() == 'accepted';
      case _StatusFilter.rejected:
        return status.toLowerCase() == 'rejected';
    }
  }

  /// 🔎 সার্চ মিল
  bool _matchesSearch(String woNo, Map<String, dynamic> data) {
    if (_search.trim().isEmpty) return true;
    final q = _search.toLowerCase();
    final buf = StringBuffer();
    buf.write(woNo.toLowerCase());
    void add(Object? v) {
      if (v == null) return;
      buf.write(' ${v.toString().toLowerCase()}');
    }

    // ✅ কমন ফিল্ড গুলো সার্চে ধরা হচ্ছে
    add(data['title']);
    add(data['buyer']);
    add(data['department']);
    add(data['priority']);
    add(data['model']);
    add(data['assignedTo']);

    return buf.toString().contains(q);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _brandTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('ওয়ার্ক অর্ডার', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // 🔁 লাইভ ডেটা স্ট্রীম (টাইমস্ট্যাম্প-অনুযায়ী)
        stream: DB.colSync(_cid, C.workOrders).orderBy('timestamp', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];

          // 📊 সামারি কাউন্টস
          int total = docs.length;
          int pend = 0, acc = 0, rej = 0;
          for (final d in docs) {
            final st = (d.data()['status'] as String? ?? 'pending').toLowerCase();
            if (st == 'accepted') acc++;
            else if (st == 'rejected') rej++;
            else pend++;
          }

          // 🔎 ফিল্টার + সার্চ + সোর্ট
          final items = docs.where((d) {
            final data = d.data();
            final status = data['status'] as String? ?? 'Pending';
            final woNo = data['workOrderNo'] as String? ?? d.id;
            return _matchesFilter(status) && _matchesSearch(woNo, data);
          }).toList()
            ..sort((a, b) {
              final at = (a.data()['timestamp'] as Timestamp?);
              final bt = (b.data()['timestamp'] as Timestamp?);
              final cmp = (at?.toDate() ?? DateTime(1970)).compareTo(bt?.toDate() ?? DateTime(1970));
              return _sort == _SortMode.newest ? -cmp : cmp;
            });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ===== 🧭 Dashboard (compact 2×2 grid) =====
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.9, // compact height like the other screen
                ),
                children: const [],
              ),
              _buildDashboard(total: total, pending: pend, accepted: acc, rejected: rej),
              const SizedBox(height: 14),

              // ===== 🔎 টুলবার: সার্চ + ফিল্টার + সোর্ট =====
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Search
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText: 'সার্চ করুন: WO নম্বর, ক্রেতা, মডেল…',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Filter
                      PopupMenuButton<_StatusFilter>(
                        tooltip: 'স্ট্যাটাস ফিল্টার',
                        onSelected: (v) => setState(() => _filter = v),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: _StatusFilter.all, child: Text('সব')),
                          PopupMenuItem(value: _StatusFilter.pending, child: Text('অপেক্ষমাণ')),
                          PopupMenuItem(value: _StatusFilter.accepted, child: Text('গ্রহণকৃত')),
                          PopupMenuItem(value: _StatusFilter.rejected, child: Text('বাতিল')),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.filter_list),
                              const SizedBox(width: 6),
                              Text(
                                _filter == _StatusFilter.all
                                    ? 'ফিল্টার: সব'
                                    : _filter == _StatusFilter.pending
                                    ? 'ফিল্টার: অপেক্ষমাণ'
                                    : _filter == _StatusFilter.accepted
                                    ? 'ফিল্টার: গ্রহণকৃত'
                                    : 'ফিল্টার: বাতিল',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Sort
                      PopupMenuButton<_SortMode>(
                        tooltip: 'সাজান',
                        onSelected: (v) => setState(() => _sort = v),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: _SortMode.newest, child: Text('নতুন আগে')),
                          PopupMenuItem(value: _SortMode.oldest, child: Text('পুরোনো আগে')),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.sort),
                              const SizedBox(width: 6),
                              Text(
                                _sort == _SortMode.newest ? 'সাজান: নতুন আগে' : 'সাজান: পুরোনো আগে',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Helper line (Bengali explanation)
                  Text(
                    'ইঙ্গিত: ওপরের সার্চ/ফিল্টার/সাজান বদলালেই নিচের অর্ডার তালিকা সাথে সাথে বদলাবে।',
                    style: TextStyle(color: Colors.grey[700], fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Center(
                    child: Text('কোনো মিল পাওয়া যায়নি।', style: TextStyle(fontSize: 10)),
                  ),
                ),

              // ===== 📄 কার্ডসমূহ (fonts 6–8sp) =====
              ...items.map((doc) {
                final data  = doc.data();
                final woNo  = data['workOrderNo'] as String? ?? doc.id;
                final status= data['status'] as String? ?? 'Pending';
                final ts    = data['timestamp'] as Timestamp?;
                final last  = data['lastUpdated'] as Timestamp?;
                final buyer = data['buyer'] as String?;            // optional
                final dept  = data['department'] as String?;       // optional
                final title = data['title'] as String?;            // optional
                final model = data['model'] as String?;            // optional
                final qty   = data['quantity'] as num?;            // optional
                final prio  = data['priority'] as String?;         // optional
                final assg  = data['assignedTo'] as String?;       // optional
                final rec   = data['recommendation'] as String?;   // optional

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // gradient header (tiny text)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                          gradient: LinearGradient(
                            colors: [_indigoCard, Color(0xFF1D5DF1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                woNo,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8,
                                  letterSpacing: .2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _statusChip(status),
                          ],
                        ),
                      ),

                      // content (compact)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Column(
                          children: [
                            _kvRow('সর্বশেষ হালনাগাদ', _formatTs(last)),
                            if (rec != null && rec.isNotEmpty) _kvRow('সুপারিশ', rec, multi: true),
                          ],
                        ),
                      ),

                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bengali helper line above actions (tiny)
                            Text(
                              'অ্যাকশন: প্রয়োজন অনুযায়ী গ্রহণ/বাতিল করুন বা বিস্তারিত দেখুন।',
                              style: TextStyle(color: Colors.grey[700], fontSize: 8, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (status.toLowerCase() != 'accepted' && status.toLowerCase() != 'rejected') ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _acceptOrder(doc.id),
                                    icon: const Icon(Icons.check_circle, size: 16),
                                    label: const Text('গ্রহণ করুন', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _rejectOrder(doc.id),
                                    icon: const Icon(Icons.cancel, size: 16),
                                    label: const Text('বাতিল করুন', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => WorkOrderDetailsScreen(orderId: doc.id)),
                                      );
                                    },
                                    icon: const Icon(Icons.open_in_new, size: 16),
                                    label: const Text('বিস্তারিত', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                ] else if (status.toLowerCase() == 'accepted') ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _brandTeal,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => WorkOrderDetailsScreen(orderId: doc.id)),
                                      );
                                    },
                                    icon: const Icon(Icons.update, size: 16),
                                    label: const Text('আপডেট দেখুন', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => WorkOrderDetailsScreen(orderId: doc.id)),
                                      );
                                    },
                                    icon: const Icon(Icons.description, size: 16),
                                    label: const Text('বিস্তারিত', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                ] else ...[
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => WorkOrderDetailsScreen(orderId: doc.id)),
                                      );
                                    },
                                    icon: const Icon(Icons.description, size: 16),
                                    label: const Text('বিস্তারিত', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // ===== Dashboard builder (2×2 grid) =====
  Widget _buildDashboard({
    required int total,
    required int pending,
    required int accepted,
    required int rejected,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.9,
        ),
        children: [
          _MetricCard(
            title: 'মোট অর্ডার',
            value: '$total',
            icon: Icons.list_alt,
            accent: _boardDark,
          ),
          _MetricCard(
            title: 'গ্রহণকৃত',
            value: '$accepted',
            icon: Icons.verified,
            accent: Colors.green.shade700,
          ),
          _MetricCard(
            title: 'অপেক্ষমাণ',
            value: '$pending',
            icon: Icons.timelapse,
            accent: Colors.orange.shade700,
          ),
          _MetricCard(
            title: 'বাতিল',
            value: '$rejected',
            icon: Icons.block,
            accent: Colors.red.shade700,
          ),
        ],
      ),
    );
  }

  // 🔑-🔸 কী-ভ্যালু সারি (বাংলা লেবেল) — tiny font (≤ 8sp)
  Widget _kvRow(String k, String? v, {bool multi = false}) {
    final value = (v == null || v.isEmpty) ? '—' : v;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: multi ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w800, fontSize: 8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 8),
              maxLines: multi ? 4 : 1,
              overflow: multi ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
