import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/core/design_system.dart';

const Color _brandRed = UddoygiDesign.factoryBrandRed;
const Color _bg = UddoygiDesign.surface;
const Color _border = Color(0xFFE2E8F0);
const Color _text = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);

class ProgressUpdateScreen extends StatefulWidget {
  final String workOrderId;

  const ProgressUpdateScreen({Key? key, required this.workOrderId}) : super(key: key);

  @override
  State<ProgressUpdateScreen> createState() => _ProgressUpdateScreenState();
}

class _ProgressUpdateScreenState extends State<ProgressUpdateScreen> {
  String _cid = '';
  final _dailyNoteCtrl = TextEditingController();
  final _qcNoteCtrl = TextEditingController();

  final List<String> _stages = [
    'Accepted',
    'Base is Done',
    'Hair is Ready',
    'Knotting Started',
    'Knotting Completed',
    'Styling / Finishing',
    'QC Check',
    'Submit to Head Office'
  ];

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _dailyNoteCtrl.dispose();
    _qcNoteCtrl.dispose();
    super.dispose();
  }

  String _niceDate(dynamic d) {
    if (d == null) return 'N/A';
    if (d is Timestamp) return DateFormat('MMM dd, yyyy - hh:mm a').format(d.toDate());
    if (d is DateTime) return DateFormat('MMM dd, yyyy - hh:mm a').format(d);
    return 'N/A';
  }

  Future<void> _addDailyNote() async {
    final note = _dailyNoteCtrl.text.trim();
    if (note.isEmpty) return;
    
    final user = FirebaseAuth.instance.currentUser;
    await DB.colSync(_cid, C.workOrders).doc(widget.workOrderId).collection('daily_logs').add({
      'note': note,
      'loggedBy': user?.displayName ?? user?.email ?? 'Unknown',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _dailyNoteCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _advanceStage(String currentStage) async {
    int idx = _stages.indexOf(currentStage);
    if (idx == -1) idx = 0; // fallback if unknown stage

    String nextStage;
    if (idx < _stages.length - 1) {
      nextStage = _stages[idx + 1];
    } else {
      return; // already at terminal
    }

    // If moving to 'Submit to Head Office', we need the QC Note if coming from QC Check
    if (nextStage == 'Submit to Head Office') {
      if (_qcNoteCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a QC Note before submitting.')));
        return;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    final batch = FirebaseFirestore.instance.batch();
    final woRef = DB.colSync(_cid, C.workOrders).doc(widget.workOrderId);
    
    // 1. Update WO
    batch.update(woRef, {
      'currentStage': nextStage,
      'status': nextStage == 'Submit to Head Office' ? 'Completed' : 'In Production',
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      if (nextStage == 'Submit to Head Office') 'qcNote': _qcNoteCtrl.text.trim(),
    });

    // 2. Log timeline event
    final tlRef = woRef.collection('timeline').doc();
    batch.set(tlRef, {
      'stage': nextStage,
      'updatedBy': user?.displayName ?? user?.email ?? 'Unknown',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 3. If terminal, send notification to Marketing
    if (nextStage == 'Submit to Head Office') {
      final notifRef = DB.colSync(_cid, C.notifications).doc();
      batch.set(notifRef, {
        'title': 'Production Completed',
        'body': 'Work Order for ${widget.workOrderId} is ready for logistics.',
        'target': 'marketing', // or specific marketing uid if tracked
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('Production Progress', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800)),
        backgroundColor: _brandRed,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: DB.colSync(_cid, C.workOrders).doc(widget.workOrderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text('Work Order Not Found'));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final currentStage = data['currentStage'] ?? 'Accepted';
          final isCompleted = data['status'] == 'Completed';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(UddoygiDesign.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(data).animate().fadeIn().slideY(begin: 0.1),
                const SizedBox(height: UddoygiDesign.space24),
                
                Text('Production Timeline', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w800, color: _text)),
                const SizedBox(height: UddoygiDesign.space12),
                _buildTimeline(currentStage, isCompleted).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1),
                
                const SizedBox(height: UddoygiDesign.space24),
                if (!isCompleted) ...[
                  _buildActionArea(currentStage).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: UddoygiDesign.space32),
                  _buildDailyNotesSection().animate(delay: 300.ms).fadeIn().slideY(begin: 0.1),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: UddoygiDesign.borderM,
        border: Border.all(color: _border),
        boxShadow: UddoygiDesign.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('WO #${data['workOrderNo']}', style: AppFonts.banglaHeading(fontSize: 20, fontWeight: FontWeight.w800, color: _brandRed)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _brandRed.withOpacity(0.1), borderRadius: UddoygiDesign.borderS),
                child: Text(data['priority'] ?? 'Normal', style: AppFonts.banglaHeading(color: _brandRed, fontWeight: FontWeight.w800, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: UddoygiDesign.space12),
          _infoRow(Icons.person, 'Customer', data['buyerName'] ?? 'Unknown'),
          const SizedBox(height: UddoygiDesign.space8),
          _infoRow(Icons.inventory_2_rounded, 'Total Pieces', '${data['totalPieces'] ?? 0}'),
          const SizedBox(height: UddoygiDesign.space8),
          _infoRow(Icons.event_rounded, 'Deadline', _niceDate(data['deadline'])),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 8),
        Text('$label: ', style: AppFonts.banglaBody(color: _muted, fontSize: 13)),
        Text(val, style: AppFonts.banglaHeading(fontWeight: FontWeight.w700, color: _text, fontSize: 13)),
      ],
    );
  }

  Widget _buildTimeline(String currentStage, bool isCompleted) {
    int currIdx = _stages.indexOf(currentStage);
    if (currIdx == -1) currIdx = 0;
    if (isCompleted) currIdx = _stages.length - 1;

    return Container(
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: UddoygiDesign.borderM, border: Border.all(color: _border), boxShadow: UddoygiDesign.shadowSoft),
      child: Column(
        children: List.generate(_stages.length, (i) {
          final stage = _stages[i];
          final isDone = i < currIdx || isCompleted;
          final isCurrent = i == currIdx && !isCompleted;

          Color nodeColor = Colors.grey.shade200;
          if (isDone) nodeColor = Colors.green;
          if (isCurrent) nodeColor = _brandRed;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: 300.ms,
                    curve: Curves.easeOutBack,
                    width: isCurrent ? 28 : 24,
                    height: isCurrent ? 28 : 24,
                    decoration: BoxDecoration(
                      color: nodeColor,
                      shape: BoxShape.circle,
                      border: isCurrent ? Border.all(color: _brandRed.withOpacity(0.2), width: 6) : null,
                      boxShadow: isCurrent ? [BoxShadow(color: _brandRed.withOpacity(0.4), blurRadius: 8)] : null,
                    ),
                    child: isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  if (i != _stages.length - 1)
                    AnimatedContainer(
                      duration: 300.ms,
                      width: 2,
                      height: 36,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isDone ? Colors.green : Colors.grey.shade200,
                    ),
                ],
              ),
              const SizedBox(width: UddoygiDesign.space16),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: isCurrent ? 4.0 : 2.0),
                  child: Text(
                    stage,
                    style: (isCurrent || isDone ? AppFonts.banglaHeading : AppFonts.banglaBody)(
                      fontSize: isCurrent ? 16 : 15,
                      fontWeight: (isCurrent || isDone) ? FontWeight.w700 : FontWeight.w500,
                      color: (isCurrent || isDone) ? _text : _muted,
                    ),
                  ),
                ),
              )
            ],
          ).animate(delay: (i * 50).ms).fadeIn().slideX(begin: 0.1);
        }),
      ),
    );
  }

  Widget _buildActionArea(String currentStage) {
    int currIdx = _stages.indexOf(currentStage);
    if (currIdx == -1) currIdx = 0;
    
    if (currIdx == _stages.length - 1) return const SizedBox.shrink(); // Terminal
    
    final nextStage = _stages[currIdx + 1];
    final isFinalSubmit = nextStage == 'Submit to Head Office';

    return Container(
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: UddoygiDesign.borderM,
        border: Border.all(color: _border),
        boxShadow: UddoygiDesign.shadowFloating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: _brandRed, size: 20),
              const SizedBox(width: 8),
              Text('Advance Production', style: AppFonts.banglaHeading(fontSize: 16, fontWeight: FontWeight.w800, color: _brandRed)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Next Stage: $nextStage', style: AppFonts.banglaBody(color: _text, fontWeight: FontWeight.w600)),
          if (isFinalSubmit) ...[
            const SizedBox(height: UddoygiDesign.space12),
            TextField(
              controller: _qcNoteCtrl,
              decoration: InputDecoration(
                labelText: 'QC Inspector Note (Required)',
                filled: true, fillColor: _bg,
                border: OutlineInputBorder(borderRadius: UddoygiDesign.borderS, borderSide: BorderSide.none),
              ),
              maxLines: 2,
            ),
          ],
          const SizedBox(height: UddoygiDesign.space16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(isFinalSubmit ? Icons.local_shipping : Icons.arrow_forward),
              label: Text(isFinalSubmit ? 'Complete & Notify Marketing' : 'Advance to $nextStage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFinalSubmit ? Colors.green : _brandRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: UddoygiDesign.borderS)
              ),
              onPressed: () => _advanceStage(currentStage),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDailyNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Log / Notes', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w800, color: _text)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dailyNoteCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add progress note...',
                    isDense: true,
                    filled: true, fillColor: _bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: _brandRed),
                onPressed: _addDailyNote,
              )
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: DB.colSync(_cid, C.workOrders).doc(widget.workOrderId).collection('daily_logs').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return Text('No notes yet.', style: AppFonts.banglaBody(color: _muted, fontSize: 12));

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['note'] ?? '', style: AppFonts.banglaBody(fontSize: 14, color: _text)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(data['loggedBy'] ?? 'Unknown', style: AppFonts.banglaHeading(fontSize: 10, color: _muted, fontWeight: FontWeight.w700)),
                            Text(_niceDate(data['timestamp']), style: AppFonts.banglaBody(fontSize: 10, color: _muted)),
                          ],
                        )
                      ],
                    ),
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }
}
