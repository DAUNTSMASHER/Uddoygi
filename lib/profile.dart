import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../storage/drive.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _primaryGreen = Color(0xFF0A4128);
const _backgroundColor = Color(0xFFF4F7F6);
const _surfaceColor = Color(0xFFFFFFFF);
const _accentGreen = Color(0xFF10B981);
const _mutedText = Color(0xFF64748B);

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _cid = '';

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _profileStream {
    if (_cid.isEmpty) return const Stream.empty();
    return DB.colSync(_cid, C.users).doc(widget.userId).snapshots();
  }

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  Future<void> _pickAndUpload(String field, DocumentReference<Map<String, dynamic>> ref, String empId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result?.files.single.path == null) return;
    final url = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => DrivePage(
          uid: widget.userId,
          field: field,
          userEmail: '',
          employeeId: empId,
        ),
      ),
    );
    if (url != null && url.isNotEmpty) {
      await ref.update({field: url});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profileStream,
        builder: (ctx, snap) {
          if (snap.hasError) return const Center(child: Text('Error loading profile'));
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final d = snap.data!.data()!;
          final ref = snap.data!.reference;
          final fullName = (d['fullName'] ?? '').toString();
          final name = (d['name'] ?? fullName).toString();
          final designation = (d['designation'] ?? 'Employee').toString();
          final profileUrl = (d['profilePhotoUrl'] ?? '').toString();
          final empId = (d['employeeId'] ?? '').toString();

          return CustomScrollView(
            slivers: [
              _buildSliverHeader(name, designation, profileUrl, ref, empId),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildManagementGrid(),
                      const SizedBox(height: 32),
                      _buildOfficeDetailsCard(empId, d),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms);
        },
      ),
    );
  }

  Widget _buildSliverHeader(String name, String designation, String profileUrl, DocumentReference ref, String empId) {
    return SliverToBoxAdapter(
      child: Container(
        height: 380,
        child: Stack(
          children: [
            Container(
              height: 320,
              decoration: const BoxDecoration(
                color: _primaryGreen,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(48)),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text('Employee Profile', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: 0, right: 0,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _pickAndUpload('profilePhotoUrl', ref as DocumentReference<Map<String, dynamic>>, empId),
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: CircleAvatar(
                              radius: 64,
                              backgroundColor: Colors.grey[100],
                              backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                              child: profileUrl.isEmpty
                                  ? Text(name.isNotEmpty ? name[0] : '?',
                                      style: GoogleFonts.dmSans(fontSize: 48, color: _primaryGreen, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4, right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: _accentGreen, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(name, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text(designation, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Management', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryGreen)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildGridItem('Documents', Icons.folder_open_rounded, const Color(0xFFEEF2FF), Colors.indigo),
            _buildGridItem('Attendance', Icons.calendar_today_rounded, const Color(0xFFFFF7ED), Colors.orange),
            _buildGridItem('Payslips', Icons.payments_outlined, const Color(0xFFF0FDF4), _accentGreen),
            _buildGridItem('Leave Request', Icons.time_to_leave_rounded, const Color(0xFFFEF2F2), Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _buildGridItem(String title, IconData icon, Color bg, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 12),
                Text(title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryGreen)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeDetailsCard(String empId, Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_center_rounded, color: _primaryGreen, size: 20),
              const SizedBox(width: 12),
              Text('Office Details', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryGreen)),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Employee ID', empId),
          _buildDivider(),
          _buildInfoRow('Department', (d['department'] ?? 'N/A').toString().toUpperCase()),
          _buildDivider(),
          _buildInfoRow('Official Email', d['officeEmail'] ?? d['email'] ?? 'N/A'),
          _buildDivider(),
          _buildInfoRow('Joined Date', '12 Jan 2021'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 14, color: _mutedText, fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryGreen)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey[100]);
  }
}
