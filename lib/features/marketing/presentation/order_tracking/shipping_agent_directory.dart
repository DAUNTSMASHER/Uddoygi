// lib/features/factory/presentation/screens/shipped_to_fedex_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const String _stageShippedFedex = 'Shipped to FedEx agent';

class shippingAgentDirectoryPage extends StatefulWidget {
  const shippingAgentDirectoryPage({Key? key}) : super(key: key);

  @override
  State<shippingAgentDirectoryPage> createState() => _ShippedToFedexPageState();
}

class _ShippedToFedexPageState extends State<shippingAgentDirectoryPage> {
  String _search = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _shippedOrders() {
    return FirebaseFirestore.instance
        .collection('work_orders')
        .where('currentStage', isEqualTo: _stageShippedFedex)
        .orderBy('lastUpdated', descending: true)
        .snapshots();
  }

  String _fedexUrl(String tracking) =>
      'https://www.fedex.com/fedextrack?trknbr=$tracking';

  String _composeCustomerMsg(Map<String, dynamic> m) {
    final name = (m['customerName'] ?? 'Customer').toString();
    final tracking = (m['trackingNo'] ?? '').toString();
    final wo = (m['workOrderNo'] ?? '').toString();
    final b = StringBuffer()
      ..writeln('Hello $name,')
      ..writeln()
      ..writeln('✅ Your order (WO $wo) has been shipped to FedEx.')
      ..writeln('🔎 Tracking number: $tracking')
      ..writeln('Open FedEx: ${_fedexUrl(tracking)}')
      ..writeln()
      ..writeln('How to track on FedEx:')
      ..writeln('1) Go to fedex.com and tap “Track”.')
      ..writeln('2) Paste your tracking number above.')
      ..writeln()
      ..writeln('Thank you!');
    return b.toString();
  }

  Future<void> _openFedex(String tracking) async {
    final uri = Uri.parse(_fedexUrl(tracking));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_darkBlue, Color(0xFF1D5DF1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        titleSpacing: 0,
        title: const Text('Shipped to FedEx', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Tracking active • $today',
                  style: TextStyle(color: Colors.white.withOpacity(.9))),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search WO# / customer / tracking…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _search = ''),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _shippedOrders(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = snap.data!.docs;

                final s = _search.trim().toLowerCase();
                if (s.isNotEmpty) {
                  docs = docs.where((d) {
                    final m = d.data();
                    final wo = (m['workOrderNo'] ?? '').toString().toLowerCase();
                    final cust = (m['customerName'] ?? '').toString().toLowerCase();
                    final trk = (m['trackingNo'] ?? '').toString().toLowerCase();
                    return wo.contains(s) || cust.contains(s) || trk.contains(s);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text('No shipped orders yet.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final m = d.data();
                    final wo = (m['workOrderNo'] ?? '—').toString();
                    final customer = (m['customerName'] ?? 'Customer').toString();
                    final tracking = (m['trackingNo'] ?? '').toString();
                    final updated = (m['lastUpdated'] as Timestamp?)?.toDate();
                    final updatedStr = updated == null
                        ? '—'
                        : DateFormat('dd MMM, HH:mm').format(updated);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12.withOpacity(.06)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4))
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // header
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'WO# $wo',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _darkBlue,
                                    ),
                                  ),
                                ),
                                _badge('Shipped to FedEx', Colors.indigo),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.person, size: 16, color: Colors.black54),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    customer,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(updatedStr,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // tracking row + actions
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black12.withOpacity(.08)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_shipping_outlined, color: _darkBlue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tracking,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _darkBlue,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Copy',
                                    icon: const Icon(Icons.copy_rounded, size: 18),
                                    onPressed: () async {
                                      await Clipboard.setData(ClipboardData(text: tracking));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Copied')),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Open FedEx',
                                    icon: const Icon(Icons.open_in_new_rounded),
                                    onPressed: () => _openFedex(tracking),
                                  ),
                                  IconButton(
                                    tooltip: 'Share',
                                    icon: const Icon(Icons.share),
                                    onPressed: () {
                                      final msg = _composeCustomerMsg(m);
                                      Share.share(msg, subject: 'Your FedEx tracking details');
                                    },
                                  ),
                                ],
                              ),
                            ),
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

  Widget _badge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Text(text, style: TextStyle(color: color.shade700, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}
