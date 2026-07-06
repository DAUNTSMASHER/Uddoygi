import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/theme/app_fonts.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);

// ─────────────────────────────────────────────────────────────────────────────
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _cid = '';
  DateTime _selectedDate = DateTime.now();
  String _selectedDept = 'All';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final colRef = DB.colSync(_cid, C.attendance).doc(formattedDate).collection('records');

    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Attendance Log', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: _brandGreen), onPressed: _pickDate),
        ],
      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _HeaderSection(date: _selectedDate, colRef: colRef).animate().fadeIn().slideY(begin: -0.1, end: 0),
                _FilterTabs(selected: _selectedDept, onSelected: (v) => setState(() => _selectedDept = v)),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: colRef.snapshots(),
                    builder: (ctx, snap) {
                      final docs = snap.data?.docs ?? [];
                      final filtered = docs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return _selectedDept == 'All' || data['department']?.toString().toLowerCase() == _selectedDept.toLowerCase();
                      }).toList();

                      return ListView.builder(
                        padding: const EdgeInsets.all(UddoygiDesign.space20),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _AttendanceCard(doc: filtered[i]).animate().fadeIn(delay: (i * 50).ms),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2023), lastDate: DateTime(2027));
    if (picked != null) setState(() => _selectedDate = picked);
  }
}

class _HeaderSection extends StatelessWidget {
  final DateTime date;
  final CollectionReference colRef;
  const _HeaderSection({required this.date, required this.colRef});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('EEEE, d MMMM').format(date).toUpperCase(), style: AppFonts.banglaHeading(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: colRef.snapshots(),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              final present = docs.where((d) => (d.data() as Map)['status'] == 'present').length;
              return Row(
                children: [
                  _SummaryStat(label: 'PRESENT', value: '$present', color: const Color(0xFF16A34A)),
                  const SizedBox(width: 32),
                  _SummaryStat(label: 'ON LEAVE', value: '${docs.where((d) => (d.data() as Map)['status'] == 'leave').length}', color: const Color(0xFF6366F1)),
                  const Spacer(),
                  CircularProgressIndicator(value: docs.isEmpty ? 0 : present / docs.length, strokeWidth: 6, backgroundColor: _brandGreen.withOpacity(0.1), color: _brandGreen),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppFonts.banglaHeading(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey)),
      Text(value, style: AppFonts.banglaData(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
    ],
  );
}

class _FilterTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const _FilterTabs({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = ['All', 'Factory', 'Admin', 'HR', 'Marketing'];
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final active = selected == items[i];
          return GestureDetector(
            onTap: () => onSelected(items[i]),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: active ? _brandGreen : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? _brandGreen : Colors.grey.withOpacity(0.1))),
              alignment: Alignment.center,
              child: Text(items[i].toUpperCase(), style: AppFonts.banglaHeading(fontSize: 10, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.grey[600])),
            ),
          );
        },
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _AttendanceCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final status = (d['status'] ?? 'absent').toString();
    final name = (d['name'] ?? 'Unknown').toString();
    Color statusColor = const Color(0xFFDC2626);
    if (status == 'present') statusColor = const Color(0xFF16A34A);
    if (status == 'late') statusColor = const Color(0xFFF59E0B);
    if (status == 'leave') statusColor = const Color(0xFF6366F1);

    return UCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: statusColor.withOpacity(0.1), child: Text(name[0], style: AppFonts.banglaHeading(color: statusColor, fontWeight: FontWeight.w800))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppFonts.banglaHeading(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                Text(d['department']?.toString().toUpperCase() ?? 'GENERAL', style: AppFonts.banglaHeading(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
              ],
            ),
          ),
          Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status.toUpperCase(), style: AppFonts.banglaHeading(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
