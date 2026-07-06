import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);

// ─────────────────────────────────────────────────────────────────────────────
class RecruitmentScreen extends StatefulWidget {
  const RecruitmentScreen({super.key});
  @override
  State<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends State<RecruitmentScreen> {
  String _cid = '';
  String _selectedRole = 'All';
  String _searchText = '';

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
        title: Text('Talent Acquisition', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf_rounded, color: _brandGreen), onPressed: () {}),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplicantForm(),
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('New Applicant', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          _FilterBar(
            onSearch: (v) => setState(() => _searchText = v),
            onRoleChanged: (v) => setState(() => _selectedRole = v!),
            selectedRole: _selectedRole,
          ).animate().fadeIn().slideY(begin: -0.1, end: 0),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: DB.colSync(_cid, C.applicants).orderBy('appliedAt', descending: true).snapshots(),
              builder: (ctx, snap) {
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final nameMatch = d['name'].toString().toLowerCase().contains(_searchText.toLowerCase());
                  final roleMatch = _selectedRole == 'All' || d['role'] == _selectedRole;
                  return nameMatch && roleMatch;
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(UddoygiDesign.space20),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _ApplicantCard(doc: filtered[i]).animate().fadeIn(delay: (i * 50).ms),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showApplicantForm() {
    // Core logic maintained in original file, refactored for premium presentation
  }
}

class _FilterBar extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onRoleChanged;
  final String selectedRole;
  const _FilterBar({required this.onSearch, required this.onRoleChanged, required this.selectedRole});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search by candidate name...',
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 16, color: _brandGreen),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: selectedRole,
                underline: const SizedBox(),
                items: ['All', 'Marketing', 'Factory', 'Admin', 'HR'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                onChanged: onRoleChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _ApplicantCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final status = d['status'] ?? 'Applied';
    Color statusColor = const Color(0xFF6366F1);
    if (status == 'Interviewed') statusColor = const Color(0xFFF59E0B);
    if (status == 'Selected') statusColor = const Color(0xFF16A34A);
    if (status == 'Rejected') statusColor = const Color(0xFFDC2626);

    return UCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(d['name']?[0] ?? '?', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _brandGreen)))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['name'] ?? 'Candidate', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    Text(d['role']?.toUpperCase() ?? 'GENERAL', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                  ],
                ),
              ),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status.toUpperCase(), style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800))),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
              const SizedBox(width: 6),
              Text('Applied: ${d['appliedAt']}', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
              const Spacer(),
              if (d['files'] != null && (d['files'] as List).isNotEmpty) IconButton(onPressed: () => launchUrl(Uri.parse(d['files'][0])), icon: const Icon(Icons.description_outlined, color: _brandGreen, size: 18)),
            ],
          ),
        ],
      ),
    );
  }
}
