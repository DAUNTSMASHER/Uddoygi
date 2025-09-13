// lib/features/marketing/presentation/order_tracking/factory_tracking.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const Color _peach = Color(0xFFFF8A65);
const Color _surface = Color(0xFFF8F6F5);

/// Shows factory updates for the CURRENT user's work-orders only,
/// provides copy buttons for Invoice / WO / Tracking,
/// and renders a detailed tracking path per order.
class FactoryTrackingPage extends StatelessWidget {
  const FactoryTrackingPage({Key? key}) : super(key: key);

  // Canonical stage path (edit to match your workflow)
  static const List<String> _stages = [
    'Invoice created',
    'Payment taken',
    'Submitted to factory',
    'Factory update 1 (base is done)',
    'Hair is ready',
    'Knotting is going on',
    'Putting',
    'Molding',
    'Submit to the Head office',
    'Address validation',
    'Shipped to FedEx',
    'Final tracking code',
  ];

  int _stageIndex(String? s) => s == null ? -1 : _stages.indexOf(s);

  // ————— Streams —————

  /// Only the logged-in user's work-orders.
  /// We write `agentEmail` when creating orders, so we filter on that.
  Stream<QuerySnapshot<Map<String, dynamic>>> _myOrdersStream() {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('work_orders')
        .where('agentEmail', isEqualTo: email)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _updatesFor(String woNo) {
    return FirebaseFirestore.instance
        .collection('work_order_tracking')
        .where('workOrderNo', isEqualTo: woNo)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ————— Helpers —————

  String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat.yMMMd().add_jm().format(t);
  }

  void _copyToClipboard(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _chip(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? _darkBlue).withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color ?? _darkBlue,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _copyPill({
    required BuildContext context,
    required IconData icon,
    required String label,         // visible label (e.g., "WO")
    required String value,         // visible value (e.g., "WO_2024...")
    String? copyLabelOverride,     // shown in snackbar; defaults to label
  }) {
    final canCopy = value.trim().isNotEmpty && value.trim() != '—';
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _darkBlue),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
                fontSize: 12,
              )),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 6),
          Icon(Icons.copy, size: 14, color: canCopy ? _darkBlue : Colors.grey),
        ],
      ),
    );

    if (!canCopy) return pill;

    return InkWell(
      onTap: () => _copyToClipboard(context, copyLabelOverride ?? label, value),
      borderRadius: BorderRadius.circular(999),
      child: pill,
    );
  }

  // Timeline row (dot + connector + content)
  Widget _timelineRow({
    required String title,
    required String subtitle,
    required bool isFirst,
    required bool isLast,
    bool highlighted = false,
  }) {
    final Color bullet = highlighted ? _peach : _darkBlue;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: connectors + dot
        SizedBox(
          width: 26,
          child: Column(
            children: [
              if (!isFirst)
                Container(width: 2, height: 10, color: Colors.grey.shade300),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: bullet, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 26, color: Colors.grey.shade300),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Right: content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
        border: Border.all(color: Colors.black12.withOpacity(.06)),
      ),
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    );
  }

  // Detailed path visual (done/current/upcoming)
  Widget _detailPath({required String currentStage}) {
    final curr = _stageIndex(currentStage);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_stages.length, (i) {
          final s = _stages[i];
          final bool done = i < curr;
          final bool currFlag = i == curr;
          final Color dot = currFlag
              ? _peach
              : (done ? Colors.green.shade600 : Colors.grey.shade400);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // rail
              SizedBox(
                width: 22,
                child: Column(
                  children: [
                    if (i != 0) Container(width: 2, height: 8, color: Colors.grey.shade300),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: currFlag ? Colors.white : (done ? Colors.green.shade600 : Colors.white),
                        border: Border.all(color: dot, width: 2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i != _stages.length - 1)
                      Container(width: 2, height: 20, color: Colors.grey.shade300),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // label
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade900,
                            fontWeight: currFlag ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (done || currFlag)
                        Icon(
                          done ? Icons.check_circle : Icons.radio_button_checked,
                          size: 16,
                          color: done ? Colors.green.shade600 : _peach,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ————— UI —————

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Factory Tracker'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_peach, Color(0xFFFFA680)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _myOrdersStream(), // ← only current user's orders
        builder: (ctx, orderSnap) {
          if (orderSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = orderSnap.data?.docs ?? [];
          if (orders.isEmpty) {
            return Center(
              child: _card(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inbox_outlined, color: _darkBlue),
                    const SizedBox(width: 10),
                    Text('No work-orders found',
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final doc = orders[i];
              final data = doc.data();

              final woNo = data['workOrderNo'] as String? ?? '—';
              final tracking = (data['tracking_number'] as String?)?.trim() ?? '—';
              final currentStage = (data['currentStage'] as String?) ?? 'Submitted to factory';
              final lastTs = (data['lastUpdated'] as Timestamp?)?.toDate();
              final lastStr = lastTs == null ? '-' : _relativeTime(lastTs);
              final invoiceId = (data['invoiceId'] as String?);

              // We may need invoiceNo; load it lazily per card if invoiceId exists.
              final invoiceFuture = (invoiceId == null || invoiceId.isEmpty)
                  ? null
                  : FirebaseFirestore.instance.collection('invoices').doc(invoiceId).get();

              Widget copyRow({String? invoiceNo}) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((invoiceNo ?? '').isNotEmpty)
                      _copyPill(
                        context: ctx,
                        icon: Icons.receipt_long,
                        label: 'Invoice',
                        value: invoiceNo!,
                        copyLabelOverride: 'Invoice No',
                      ),
                    _copyPill(
                      context: ctx,
                      icon: Icons.assignment_turned_in,
                      label: 'WO',
                      value: woNo,
                      copyLabelOverride: 'Work Order No',
                    ),
                    _copyPill(
                      context: ctx,
                      icon: Icons.qr_code_2,
                      label: 'TRK',
                      value: tracking,
                      copyLabelOverride: 'Tracking No',
                    ),
                  ],
                );
              }

              return _card(
                padding: const EdgeInsets.all(0),
                child: Column(
                  children: [
                    // Header band
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _peach.withOpacity(.15),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black12.withOpacity(.06)),
                            ),
                            child: const Icon(Icons.factory, color: _darkBlue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WO# $woNo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _darkBlue,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text('Last update • $lastStr',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                              ],
                            ),
                          ),
                          _chip(currentStage, color: _darkBlue),
                        ],
                      ),
                    ),

                    // Copy pills row (Invoice / WO / TRK)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: invoiceFuture == null
                          ? copyRow()
                          : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: invoiceFuture,
                        builder: (ctx, invSnap) {
                          String? invoiceNo;
                          if (invSnap.connectionState == ConnectionState.done && invSnap.hasData) {
                            invoiceNo = (invSnap.data!.data()?['invoiceNo'] as String?)?.trim();
                          }
                          return copyRow(invoiceNo: invoiceNo);
                        },
                      ),
                    ),

                    // Title row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: Row(
                        children: const [
                          Expanded(
                            child: Text(
                              'Task tracker',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _darkBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Updates timeline (live)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _updatesFor(woNo),
                        builder: (ctx, updSnap) {
                          if (updSnap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final updates = updSnap.data?.docs ?? [];
                          if (updates.isEmpty) {
                            return Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('No updates yet.',
                                  style: TextStyle(color: Colors.grey.shade600)),
                            );
                          }

                          return Column(
                            children: List.generate(updates.length, (idx) {
                              final d = updates[idx].data();
                              final stage = d['stage'] as String? ?? '—';
                              final status = (d['status'] as String? ?? '').toUpperCase();
                              final ts =
                                  (d['lastUpdated'] as Timestamp?)?.toDate() ??
                                      (d['createdAt'] as Timestamp?)?.toDate() ??
                                      DateTime.now();
                              final timeStr = _relativeTime(ts);
                              final highlighted = idx == 0; // latest

                              return _timelineRow(
                                title: stage,
                                subtitle: status.isEmpty ? timeStr : '$status • $timeStr',
                                isFirst: idx == 0,
                                isLast: idx == updates.length - 1,
                                highlighted: highlighted,
                              );
                            }),
                          );
                        },
                      ),
                    ),

                    // Detailed tracking path
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: _detailPath(currentStage: currentStage),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
