import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../storage/drive.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _users = FirebaseFirestore.instance.collection('users');

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _profileStream =>
      _users.doc(widget.userId).snapshots();

  Future<void> _pickAndUpload(
      String field,
      DocumentReference<Map<String, dynamic>> ref,
      String empId,
      FileType type,
      ) async {
    final result = await FilePicker.platform.pickFiles(type: type);
    if (result?.files.single.path == null) return;
    final url = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => DrivePage(
          uid: widget.userId,
          field: field,
          userEmail: '',      // DrivePage only needs uid & field here
          employeeId: empId,
        ),
      ),
    );
    if (url != null && url.isNotEmpty) {
      await ref.update({field: url});
    }
  }

  Future<void> _editField(
      DocumentReference<Map<String, dynamic>> ref,
      String key,
      String label,
      String currentValue,
      ) async {
    if (key == 'dateOfBirth') {
      DateTime initial = DateTime.now();
      final parts = currentValue.split('/');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          initial = DateTime(y, m, d);
        }
      }
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
      );
      if (picked != null && mounted) {
        await ref.update({key: Timestamp.fromDate(picked)});
      }
      return;
    }

    final ctrl = TextEditingController(text: currentValue);
    final updated = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (updated != null && updated != currentValue && mounted) {
      await ref.update({key: updated});
    }
  }

  String _fmtDate(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Widget _header(String title) {
    return Container(
      width: double.infinity,
      color: _darkBlue,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _row(String label, String value, {VoidCallback? onTap, IconData? icon}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon ?? Icons.info, color: _darkBlue, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(value, style: const TextStyle(fontSize: 12)),
      trailing: onTap != null ? Icon(Icons.edit, color: _darkBlue, size: 18) : null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('My Profile'), backgroundColor: _darkBlue),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profileStream,
        builder: (ctx, snap) {
          if (snap.hasError) return const Center(child: Text('Error loading profile'));
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snap.data!;
          final data = doc.data()!;
          final ref = doc.reference;
          final empId = (data['employeeId'] as String?) ?? '';

          final fullName = (data['fullName'] as String?)?.trim() ?? '';
          final name     = (data['name'] as String?) ?? fullName;
          final phone    = (data['personalPhone'] as String?) ?? '';
          final dob      = data['dateOfBirth'] is Timestamp
              ? _fmtDate(data['dateOfBirth'])
              : (data['dateOfBirth'] as String?) ?? '';
          final photoUrl = (data['profilePhotoUrl'] as String?) ?? '';

          final cvUrl        = (data['cvUrl'] as String?) ?? '';
          final ndaUrl       = (data['ndaUrl'] as String?) ?? '';
          final certs        = (data['certifications'] as List?)?.join(', ') ?? '';
          final trainingRecs = (data['trainingRecords'] as List?)?.join(', ') ?? '';
          final prevEmps     = (data['previousEmployers'] as List?)?.join(', ') ?? '';
          final reviews      = (data['probationReviews'] as List?)?.join(', ') ?? '';

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: _darkBlue,
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Text(name.isNotEmpty ? name[0] : '?',
                      style: const TextStyle(fontSize: 36, color: Colors.white))
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.camera_alt, color: _darkBlue),
                  label: const Text('Change Photo', style: TextStyle(color: _darkBlue, fontSize: 14)),
                  onPressed: () => _pickAndUpload('profilePhotoUrl', ref, empId, FileType.image),
                ),
              ),
              const SizedBox(height: 16),
              _header('Personal Information'),
              _row('Full Name', fullName,
                  onTap: () => _editField(ref, 'fullName', 'Full Name', fullName), icon: Icons.person),
              _row('Name', name,
                  onTap: () => _editField(ref, 'name', 'Name', name), icon: Icons.account_circle),
              _row('Date of Birth', dob,
                  onTap: () => _editField(ref, 'dateOfBirth', 'Date of Birth', dob),
                  icon: Icons.cake),
              _row('Phone', phone,
                  onTap: () => _editField(ref, 'personalPhone', 'Personal Phone', phone),
                  icon: Icons.phone),
              _header('Documents & Certifications'),
              _row('CV', cvUrl,
                  onTap: () => _pickAndUpload('cvUrl', ref, empId, FileType.any),
                  icon: Icons.insert_drive_file),
              _row('NDA', ndaUrl,
                  onTap: () => _pickAndUpload('ndaUrl', ref, empId, FileType.any),
                  icon: Icons.description),
              _row('Certifications', certs,
                  onTap: () => _editField(ref, 'certifications', 'Certifications', certs),
                  icon: Icons.school),
              _row('Training Records', trainingRecs,
                  onTap: () =>
                      _editField(ref, 'trainingRecords', 'Training Records', trainingRecs),
                  icon: Icons.history_edu),
              _row('Previous Employers', prevEmps,
                  onTap: () => _editField(
                      ref, 'previousEmployers', 'Previous Employers', prevEmps),
                  icon: Icons.business_center),
              _row('Probation Reviews', reviews,
                  onTap: () => _editField(
                      ref, 'probationReviews', 'Probation Reviews', reviews),
                  icon: Icons.rate_review),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
