import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../storage/drive.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _cid = '';
  static const Color _brandColor = Color(0xFF2A0A4B);

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
      backgroundColor: const Color(0xFFF8F9FE),
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
              SliverToBoxAdapter(
                child: Container(
                  height: 340,
                  child: Stack(
                    children: [
                      Container(
                        height: 300,
                        decoration: const BoxDecoration(
                          color: _brandColor,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                        ),
                      ),
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
                              Text('My Profile', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                              const Spacer(),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 80,
                        left: 0, right: 0,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _pickAndUpload('profilePhotoUrl', ref, empId),
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
                                          ? Text(name.isNotEmpty ? name[0] : '?',
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
                            Text(name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(designation, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StatBit(label: 'Experience', value: '4.5 Years'),
                                const SizedBox(width: 48),
                                _StatBit(label: 'Performance', value: 'Exceeds'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: UCard(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        _ActionRow(icon: Icons.person_outline_rounded, title: 'Personal Information'),
                        _Divider(),
                        _ActionRow(icon: Icons.business_center_outlined, title: 'Work Experience'),
                        _Divider(),
                        _ActionRow(icon: Icons.account_balance_wallet_outlined, title: 'Payment Details'),
                        _Divider(),
                        _ActionRow(icon: Icons.lock_outline_rounded, title: 'Security Settings'),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: UCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account Overview', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: _brandColor)),
                        const SizedBox(height: 16),
                        _InfoItem(label: 'Employee ID', value: empId),
                        _InfoItem(label: 'Office Email', value: d['officeEmail'] ?? d['email'] ?? ''),
                        _InfoItem(label: 'Joining Date', value: '12 Jan 2021'),
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

class _StatBit extends StatelessWidget {
  final String label, value;
  const _StatBit({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w400)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  const _ActionRow({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700], size: 22),
      title: Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
      onTap: () {},
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Colors.grey[100], indent: 56, endIndent: 20);
  }
}

class _InfoItem extends StatelessWidget {
  final String label, value;
  const _InfoItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
