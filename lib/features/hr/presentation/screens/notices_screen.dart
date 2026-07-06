import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);

// ─────────────────────────────────────────────────────────────────────────────
class HRNoticeScreen extends StatefulWidget {
  const HRNoticeScreen({super.key});
  @override
  State<HRNoticeScreen> createState() => _HRNoticeScreenState();
}

class _HRNoticeScreenState extends State<HRNoticeScreen> {
  String _cid = '';
  final _titleController = TextEditingController();
  final _descController  = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Notices & Bulletins', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: Column(
        children: [
          _NoticeForm(
            titleC: _titleController,
            descC: _descController,
            loading: _loading,
            onPublish: _publish,
          ).animate().fadeIn().slideY(begin: -0.1, end: 0),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: DB.colSync(_cid, C.notices).orderBy('timestamp', descending: true).snapshots(),
              builder: (ctx, snap) {
                final docs = snap.data?.docs ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.all(UddoygiDesign.space20),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) => _NoticeCard(doc: docs[i]).animate().fadeIn(delay: (i * 50).ms),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publish() async {
    if (_titleController.text.isEmpty) return;
    setState(() => _loading = true);
    await DB.colSync(_cid, C.notices).add({
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'publishedBy': 'HR Management',
    });
    _titleController.clear();
    _descController.clear();
    setState(() => _loading = false);
  }
}

class _NoticeForm extends StatelessWidget {
  final TextEditingController titleC, descC;
  final bool loading;
  final VoidCallback onPublish;
  const _NoticeForm({required this.titleC, required this.descC, required this.loading, required this.onPublish});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: titleC,
            decoration: InputDecoration(
              hintText: 'Notice Title',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descC,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Description...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onPublish,
              style: ElevatedButton.styleFrom(backgroundColor: _brandGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('PUBLISH NOTICE', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _NoticeCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final time = d['timestamp'] is Timestamp ? (d['timestamp'] as Timestamp).toDate() : DateTime.now();

    return UCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('OFFICIAL', style: GoogleFonts.outfit(color: _brandGreen, fontSize: 9, fontWeight: FontWeight.w900))),
              const Spacer(),
              Text(DateFormat('MMM d, yyyy').format(time), style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Text(d['title'] ?? 'Untitled Notice', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text(d['description'] ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey[600], height: 1.5)),
          const Divider(height: 32),
          Row(
            children: [
              const Icon(Icons.person_pin_rounded, size: 16, color: _brandGreen),
              const SizedBox(width: 8),
              Text(d['publishedBy'] ?? 'Management', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: _brandGreen)),
              const Spacer(),
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
