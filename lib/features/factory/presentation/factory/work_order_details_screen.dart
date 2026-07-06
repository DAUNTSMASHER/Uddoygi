// lib/features/factory/presentation/factory/work_order_details_screen.dart

import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WorkOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const WorkOrderDetailsScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<WorkOrderDetailsScreen> createState() => _WorkOrderDetailsScreenState();
}

class _WorkOrderDetailsScreenState extends State<WorkOrderDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _cid = '';
  Map<String, dynamic>? _workOrder;
  Map<String, dynamic>? _invoice;
  bool _loading = true;

  // Progress update state
  final _notesCtl = TextEditingController();
  final _assignedCtl = TextEditingController();
  String? _selectedNextStage;

  static const List<String> _stages = <String>[
    'Submitted to factory',
    'Factory update 1 (base is done)',
    'Hair is ready',
    'Knotting is going on',
    'Putting',
    'Molding',
    'Submit to the Head office',
  ];

  static const Map<String, String> _stageBn = {
    'Submitted to factory': 'কারখানায় জমা দেওয়া হয়েছে',
    'Factory update 1 (base is done)': 'আপডেট ১ (বেস সম্পন্ন)',
    'Hair is ready': 'চুল প্রস্তুত',
    'Knotting is going on': 'নটিং চলছে',
    'Putting': 'পুটিং',
    'Molding': 'মোল্ডিং',
    'Submit to the Head office': 'প্রধান কার্যালয়ে জমা',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _fetchWorkOrderAndInvoice();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesCtl.dispose();
    _assignedCtl.dispose();
    super.dispose();
  }

  Future<void> _fetchWorkOrderAndInvoice() async {
    final cid = await LocalStorageService.getSavedCompanyId() ?? '';
    
    // Fallback dummy data
    Map<String, dynamic> dummyWo = {
      'workOrderNo': widget.orderId,
      'buyerName': 'Globex',
      'instructions': 'Welding - Frame Structural',
      'completed': false,
      'currentStage': 'In Production',
      'createdAt': Timestamp.now(),
      'timeline': [
        {'stage': 'Submitted to factory', 'timestamp': Timestamp.now()},
      ],
      'invoiceId': 'INV-9999'
    };
    Map<String, dynamic> dummyInv = {
      'invoiceNo': 'INV-9999',
      'date': Timestamp.now(),
      'totalAmount': 50000,
      'buyerName': 'Globex',
    };

    if (cid.isEmpty) {
      if (mounted) {
        setState(() {
          _workOrder = dummyWo;
          _invoice = dummyInv;
          _loading = false;
        });
      }
      return;
    }

    try {
      final woSnap = await DB.colSync(cid, C.workOrders).doc(widget.orderId).get();
      final woData = woSnap.data() ?? dummyWo;

      Map<String, dynamic>? invData = dummyInv;
      final invId = woData['invoiceId'] as String?;
      if (invId != null) {
        final invSnap = await DB.colSync(cid, C.invoices).doc(invId).get();
        invData = invSnap.data() ?? dummyInv;
      }

      if (mounted) {
        setState(() {
          _cid = cid;
          _workOrder = woData;
          _invoice = invData;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _workOrder = dummyWo;
          _invoice = dummyInv;
          _loading = false;
        });
      }
    }
  }

  int _stageIndex(String? name) => name == null ? -1 : _stages.indexOf(name);
  String _stageName(String s) => _stageBn[s] ?? s;

  Future<void> _addUpdate() async {
    if (_selectedNextStage == null || _workOrder == null || _cid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('অনুগ্রহ করে সব তথ্য দিন।')));
      return;
    }

    try {
      final currentStage = (_workOrder!['currentStage'] as String?) ?? _stages.first;
      final currIdx = _stageIndex(currentStage);
      final nextIdx = _stageIndex(_selectedNextStage);

      if (nextIdx <= currIdx && nextIdx != -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('আপনি পেছনে যেতে বা একই ধাপ পুনরায় নির্বাচন করতে পারবেন না।'), backgroundColor: Colors.red),
        );
        return;
      }

      final now = Timestamp.now();
      final batch = DB.firestore.batch();
      final orderRef = DB.colSync(_cid, C.workOrders).doc(widget.orderId);

      // 1. Log Tracking
      final trackingRef = DB.colSync(_cid, C.workOrderTracking).doc();
      batch.set(trackingRef, {
        'workOrderNo': _workOrder!['workOrderNo'] ?? widget.orderId,
        'orderId': widget.orderId,
        'stage': _selectedNextStage,
        'stageIndex': nextIdx,
        'notes': _notesCtl.text.trim(),
        'assignedTo': _assignedCtl.text.trim(),
        'createdAt': now,
        'lastUpdated': now,
      });

      // 2. Update Order
      final isTerminal = _selectedNextStage == _stages.last;
      batch.update(orderRef, {
        'currentStage': _selectedNextStage,
        'currentStageIndex': nextIdx,
        'lastUpdated': now,
        if (isTerminal) ...{
          'completed': true,
          'completedAt': now,
          'status': 'Completed',
          'nextStage': 'Address Validation of the Customer',
        }
      });

      // 3. Inventory Sync (if terminal)
      if (isTerminal) {
        final items = (_workOrder!['items'] as List?) ?? [];
        for (final itm in items) {
          if (itm is! Map) continue;
          final m = Map<String, dynamic>.from(itm);
          final model = m['model'];
          final color = m['colour'];
          final size = m['size'];
          final qty = (m['qty'] as num?)?.toInt() ?? 0;

          if (model != null && qty > 0) {
            final prodSnap = await DB.colSync(_cid, C.products)
                .where('model_name', isEqualTo: model)
                .where('colour', isEqualTo: color)
                .where('size', isEqualTo: size)
                .limit(1)
                .get();

            if (prodSnap.docs.isNotEmpty) {
              batch.update(prodSnap.docs.first.reference, {'stock': FieldValue.increment(qty)});
            }
          }
        }

        // Notify Marketing
        final notifRef = DB.colSync(_cid, C.notifications).doc();
        batch.set(notifRef, {
          'title': 'Production Completed: #${_workOrder!['workOrderNo']}',
          'body': 'Order is ready for address validation and shipping.',
          'target': 'marketing',
          'timestamp': now,
          'type': 'production_complete',
          'refId': widget.orderId,
        });
      }

      await batch.commit();
      
      if (mounted) {
        setState(() {
          _notesCtl.clear();
          _assignedCtl.clear();
          _selectedNextStage = null;
        });
        await _fetchWorkOrderAndInvoice();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isTerminal ? 'উৎপাদন সম্পন্ন হয়েছে!' : 'ধাপ আপডেট হয়েছে।'), backgroundColor: isTerminal ? Colors.green : null),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ত্রুটি'),
            content: Text('আপডেট করতে সমস্যা হয়েছে: $e'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ঠিক আছে'))],
          ),
        );
      }
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final items = List<Map<String, dynamic>>.from(_workOrder!['items'] ?? []);
    final woNo = _workOrder!['workOrderNo'] as String? ?? widget.orderId;
    final finalTs = _workOrder!['finalDate'] as Timestamp?;
    final finalDate = finalTs?.toDate() ?? DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (ctx) => [
          pw.Header(level: 0, child: pw.Text('Work Order: $woNo', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.Text('Buyer: ${_workOrder!['buyerName'] ?? 'N/A'}'),
          pw.Text('Delivery Date: ${DateFormat.yMMMd().format(finalDate)}'),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['Model', 'Colour', 'Size', 'Qty'],
            data: items.map((it) => [it['model'] ?? '', it['colour'] ?? '', it['size'] ?? '', it['qty']?.toString() ?? '0']).toList(),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Instructions:'),
          pw.Text(_workOrder!['instructions'] ?? 'None'),
        ],
      ),
    );
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Color(0xFFf7f9ff), body: Center(child: CircularProgressIndicator()));
    }

    final woNo = _workOrder!['workOrderNo'] ?? widget.orderId;
    final buyer = _workOrder!['buyerName'] ?? 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B0000), Color(0xFF5A0000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: [BoxShadow(color: const Color(0xFF8B0000).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
          ),
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text('WO-$woNo', style: AppFonts.banglaHeading(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            Text('Client: $buyer', style: AppFonts.banglaBody(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white, size: 20), onPressed: () {}),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Segmented Tab
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2BFB9).withOpacity(0.5))),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF8B0000).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF8B0000).withOpacity(0.2)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: const Color(0xFF8B0000),
                  unselectedLabelColor: const Color(0xFF5b403e),
                  labelStyle: AppFonts.banglaHeading(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'PRODUCTION UPDATE'),
                    Tab(text: 'DOCUMENTS'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProgressTab(),
                  _buildDocTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    final currentStage = (_workOrder!['currentStage'] as String?) ?? _stages.first;
    final currIdx = _stageIndex(currentStage);
    final isCompleted = _workOrder!['completed'] == true || currentStage == _stages.last;
    final forwardStages = (currIdx >= 0 && currIdx < _stages.length - 1) ? _stages.sublist(currIdx + 1) : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(currentStage, isCompleted).animate().fadeIn().slideY(begin: 0.1, end: 0),
          const SizedBox(height: 24),
          if (!isCompleted) ...[
            _buildAddUpdateCard(forwardStages).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 24),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('History', style: AppFonts.banglaHeading(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF8B0000))),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 16),
          _buildTimeline(),
        ],
      ),
    );
  }

  Widget _buildHeroCard(String stage, bool completed) {
    final idx = _stageIndex(stage);
    final progress = completed ? 1.0 : (idx + 1) / _stages.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: completed ? [Colors.green.shade50, Colors.white] : [const Color(0xFF8B0000).withOpacity(0.05), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2BFB9).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2BFB9))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulse dot
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: completed ? Colors.green : const Color(0xFF8B0000), shape: BoxShape.circle),
                ).animate(onPlay: (c) => c.repeat()).fade(duration: 1.seconds, begin: 0.3, end: 1),
                const SizedBox(width: 6),
                Text(completed ? 'PRODUCTION COMPLETED' : 'PRODUCTION ONGOING', style: AppFonts.banglaHeading(fontSize: 9, fontWeight: FontWeight.w700, color: completed ? Colors.green.shade800 : Color(0xFF8B0000))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_stageName(stage), style: AppFonts.banglaHeading(fontSize: 16, fontWeight: FontWeight.w700, color: completed ? Colors.green.shade800 : Color(0xFF8B0000))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PROGRESS', style: AppFonts.banglaBody(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF5b403e), letterSpacing: 0.5)),
              Text('${(progress * 100).toInt()}%', style: AppFonts.banglaData(fontSize: 12, fontWeight: FontWeight.w700, color: completed ? Colors.green.shade800 : Color(0xFF8B0000))),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            decoration: BoxDecoration(color: const Color(0xFFdde3eb), borderRadius: BorderRadius.circular(3)),
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: completed ? [Colors.green, Colors.greenAccent] : [const Color(0xFF5A0000), const Color(0xFF8B0000)]),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddUpdateCard(List<String> forwardStages) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2BFB9).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Log New Update', style: AppFonts.banglaHeading(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF8B0000))),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedNextStage,
            decoration: _inputDeco('Select Stage...'),
            icon: const Icon(Icons.expand_more, color: Color(0xFF906f6d), size: 18),
            items: forwardStages.map((s) => DropdownMenuItem(value: s, child: Text(_stageName(s), style: AppFonts.banglaBody(fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => _selectedNextStage = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: _assignedCtl, style: AppFonts.banglaBody(fontSize: 12), decoration: _inputDeco('Assigned To').copyWith(prefixIcon: Icon(Icons.person, color: Color(0xFF906f6d), size: 16))),
          const SizedBox(height: 12),
          TextField(controller: _notesCtl, maxLines: 3, style: AppFonts.banglaBody(fontSize: 12), decoration: _inputDeco('Add notes here...')),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: _addUpdate,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('SUBMIT UPDATE', style: AppFonts.banglaHeading(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppFonts.banglaBody(fontSize: 12, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: const Color(0xFFE2BFB9).withOpacity(0.5))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: const Color(0xFFE2BFB9).withOpacity(0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF8B0000), width: 1.5)),
    );
  }

  Widget _buildTimeline() {
    if (_cid.isEmpty) {
      final List<dynamic> tList = _workOrder!['timeline'] ?? [];
      if (tList.isEmpty) return Text('No history available.', style: AppFonts.banglaBody(color: Colors.grey));
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tList.length,
        itemBuilder: (ctx, i) {
          final d = tList[i];
          final ts = (d['timestamp'] as Timestamp).toDate();
          final isFirst = i == 0;
          final isLast = i == tList.length - 1;
          return _buildTimelineItem({'stage': d['stage'], 'notes': 'Test dummy data'}, ts, isFirst, isLast).animate().fadeIn(delay: (300 + (i * 150)).ms).slideY(begin: 0.2, end: 0);
        },
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(_cid, C.workOrderTracking).where('workOrderNo', isEqualTo: _workOrder!['workOrderNo']).orderBy('createdAt', descending: true).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return Text('No history available.', style: AppFonts.banglaBody(color: Colors.grey));
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data();
            final ts = (d['createdAt'] as Timestamp).toDate();
            final isFirst = i == 0;
            final isLast = i == docs.length - 1;
            return _buildTimelineItem(d, ts, isFirst, isLast).animate().fadeIn(delay: (300 + (i * 150)).ms).slideY(begin: 0.2, end: 0);
          },
        );
      },
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> data, DateTime ts, bool isFirst, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: isFirst ? const Color(0xFF8B0000) : const Color(0xFFFCF9F8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
                  ),
                  child: Icon(Icons.check, size: 12, color: isFirst ? Colors.white : Colors.grey.shade600),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: const Color(0xFFe1e3e4))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isFirst ? Colors.white : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2BFB9).withOpacity(0.3)),
                  boxShadow: isFirst ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(_stageName(data['stage']), style: AppFonts.banglaHeading(fontSize: 12, fontWeight: FontWeight.w700, color: isFirst ? Color(0xFF8B0000) : Color(0xFF5b403e)))),
                        Text(DateFormat('MMM d, hh:mm a').format(ts), style: AppFonts.banglaBody(fontSize: 9, color: Colors.grey.shade500)),
                      ],
                    ),
                    if (data['notes']?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(data['notes'], style: AppFonts.banglaBody(fontSize: 11, color: Colors.grey.shade700)),
                    ],
                    if (data['assignedTo']?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF8B0000).withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                        child: Text('👤 ${data['assignedTo']}', style: AppFonts.banglaBody(fontSize: 9, color: Color(0xFF8B0000), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Align(alignment: Alignment.centerLeft, child: Text('Invoice WO #${_workOrder!['workOrderNo'] ?? widget.orderId}', style: AppFonts.banglaHeading(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF8B0000)))),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PdfPreview(
                build: (format) => _generatePdf(format),
                allowPrinting: true,
                allowSharing: true,
                initialPageFormat: PdfPageFormat.a4,
                canChangePageFormat: false,
                scrollViewDecoration: const BoxDecoration(color: Color(0xFFeff4fc)),
                pdfPreviewPageDecoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFFCF9F8),
        border: Border(top: BorderSide(color: const Color(0xFFE2BFB9).withOpacity(0.3))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(icon: Icons.assignment_outlined, label: 'ORDERS', isActive: false, onTap: () => Navigator.pop(context)),
            _navItem(icon: Icons.sync, label: 'UPDATES', isActive: true, onTap: () {}),
            _navItem(icon: Icons.inventory_2_outlined, label: 'INVENTORY', isActive: false, onTap: () {}),
            _navItem(icon: Icons.person_outline, label: 'PROFILE', isActive: false, onTap: () {}),
          ],
        ),
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: isActive
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: isActive ? BoxDecoration(color: const Color(0xFF8B0000), borderRadius: BorderRadius.circular(20)) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : const Color(0xFF5b403e)),
            const SizedBox(height: 2),
            Text(label, style: AppFonts.banglaHeading(fontSize: 8, fontWeight: FontWeight.w700, color: isActive ? Colors.white : Color(0xFF5b403e), letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
