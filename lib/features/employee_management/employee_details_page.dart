import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../storage/drive.dart';
import 'package:uddoygi/widgets/u_card.dart';

class EmployeeDetailsPage extends StatefulWidget {
  final String uid;
  final String userEmail;
  final String employeeId;

  const EmployeeDetailsPage({
    super.key,
    required this.uid,
    required this.userEmail,
    required this.employeeId,
  });

  @override
  _EmployeeDetailsPageState createState() => _EmployeeDetailsPageState();
}

class _EmployeeDetailsPageState extends State<EmployeeDetailsPage> {
  String _cid = '';
  static const Color _brandColor = Color(0xFF2A0A4B);

  DocumentReference<Map<String, dynamic>>? get _docRef =>
      _cid.isEmpty ? null : DB.colSync(_cid, C.users).doc(widget.uid);

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  Future<void> _pickAndUploadPhoto(String employeeId) async {
    if (_docRef == null) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result?.files.single.path == null) return;
    if (!mounted) return;

    final url = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => DrivePage(
          uid: widget.uid,
          field: 'profilePhotoUrl',
          userEmail: widget.userEmail,
          employeeId: employeeId,
        ),
      ),
    );

    if (url != null && url.isNotEmpty) {
      await _docRef!.update({'profilePhotoUrl': url});
    }
  }

  String _fmtDate(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _docRef!.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData || !snap.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }

                final d = snap.data!.data()!;
                final fullName = (d['fullName'] ?? '').toString();
                final designation = (d['designation'] ?? 'Employee').toString();
                final profileUrl = (d['profilePhotoUrl'] ?? '').toString();
                final department = (d['department'] ?? '').toString().toUpperCase();
                final employeeId = (d['employeeId'] ?? widget.employeeId).toString();
                final officeEmail = (d['officeEmail'] ?? widget.userEmail).toString();
                final personalPhone = (d['personalPhone'] ?? '').toString();
                
                return CustomScrollView(
                  slivers: [
                    // ── Header Section ──────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Container(
                        height: 340,
                        child: Stack(
                          children: [
                            // Curved Background
                            Container(
                              height: 300,
                              decoration: const BoxDecoration(
                                color: _brandColor,
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                              ),
                            ),
                            
                            // App Bar Mock
                            SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Profile Content
                            Positioned(
                              top: 80,
                              left: 0, right: 0,
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => _pickAndUploadPhoto(employeeId),
                                    child: Stack(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                          child: CircleAvatar(
                                            radius: 54,
                                            backgroundColor: Colors.grey[200],
                                            backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                                            child: profileUrl.isEmpty
                                                ? Text(fullName.isEmpty ? '?' : fullName[0],
                                                    style: GoogleFonts.outfit(fontSize: 40, color: _brandColor, fontWeight: FontWeight.w900))
                                                : null,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0, right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: _brandColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    fullName,
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    designation,
                                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Time Mock
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _TimeInfo(label: 'Clock In', time: '09:00'),
                                      const SizedBox(width: 48),
                                      _TimeInfo(label: 'Clock Out', time: '18:00'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Actions Card ─────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: UCard(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              _ActionItem(icon: Icons.person_rounded, title: 'Profile', onTap: () {}),
                              const _Divider(),
                              _ActionItem(icon: Icons.folder_rounded, title: 'Documents', onTap: () {}),
                              const _Divider(),
                              _ActionItem(icon: Icons.description_rounded, title: 'Payslips', onTap: () {}),
                              const _Divider(),
                              _ActionItem(icon: Icons.flight_takeoff_rounded, title: 'Leave Management', onTap: () {}),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Info Card ────────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: UCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Office Details', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: _brandColor)),
                              const SizedBox(height: 16),
                              _InfoBit(label: 'Employee ID', value: employeeId),
                              _InfoBit(label: 'Department', value: department),
                              _InfoBit(label: 'Work Email', value: officeEmail),
                              _InfoBit(label: 'Phone', value: personalPhone),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ).animate().fadeIn(duration: 400.ms);
              },
            ),
    );
  }
}

class _TimeInfo extends StatelessWidget {
  final String label;
  final String time;
  const _TimeInfo({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w400)),
        const SizedBox(height: 4),
        Text(time, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[700], size: 22),
            const SizedBox(width: 16),
            Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Colors.grey[100], indent: 56, endIndent: 20);
  }
}

class _InfoBit extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBit({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }
}

