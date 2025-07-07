import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../storage/drive.dart';

const Color _darkBlue = Color(0xFF0D47A1);

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
  late final DocumentReference<Map<String, dynamic>> _docRef;

  @override
  void initState() {
    super.initState();
    _docRef = FirebaseFirestore.instance.collection('users').doc(widget.uid);
  }

  Future<void> _pickAndUploadPhoto(String employeeId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result?.files.single.path == null) return;

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
      await _docRef.update({'profilePhotoUrl': url});
    }
  }

  Future<void> _pickAndUploadCV(String employeeId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result?.files.single.path == null) return;

    final url = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => DrivePage(
          uid: widget.uid,
          field: 'cvUrl',
          userEmail: widget.userEmail,
          employeeId: employeeId,
        ),
      ),
    );

    if (url != null && url.isNotEmpty) {
      await _docRef.update({'cvUrl': url});
    }
  }

  Future<void> _editField(String key, String label, String currentValue) async {
    if (key == 'dateOfBirth' || key == 'joiningDate') {
      final parts = currentValue.split('/');
      DateTime initial = DateTime.now();
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
      if (picked != null) {
        await _docRef.update({key: Timestamp.fromDate(picked)});
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
    if (updated != null && updated != currentValue) {
      await _docRef.update({key: updated});
    }
  }

  String _fmtDate(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      color: _darkBlue,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(title,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(String key, IconData icon, String label, String value,
      {VoidCallback? onTap}) =>
      ListTile(
        leading: Icon(icon, color: _darkBlue),
        title: Text(label),
        subtitle: Text(value),
        trailing: const Icon(Icons.edit, color: _darkBlue),
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
      AppBar(title: const Text('Employee Details'), backgroundColor: _darkBlue),
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _docRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('Error loading'));
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final d = snap.data!.data()!;
          // -- PERSONAL
          final fullName      = (d['fullName'] as String? ?? '').toString();
          final name          = (d['name'] as String? ?? fullName).toString();
          final personalEmail = (d['personalEmail'] as String? ?? '').toString();
          final personalPhone = (d['personalPhone'] ?? '').toString();
          final governmentId  = (d['governmentIdUrl'] as String? ?? '').toString();
          // -- OFFICE
          final employeeId      = (d['employeeId'] as String? ?? widget.employeeId).toString();
          final officeEmail     = (d['officeEmail'] as String? ?? widget.userEmail).toString();
          final department      = (d['department'] as String? ?? '').toString().toUpperCase();
          final jobTitle        = (d['jobTitle'] as String? ?? '').toString();
          final designation     = (d['designation'] as String? ?? '').toString();
          final employmentType  = (d['employmentType'] as String? ?? '').toString();
          final yearsOfExp      = (d['yearsOfExperience'] ?? '').toString();
          final badgeNumber     = (d['badgeNumber'] ?? '').toString();
          final shiftPattern    = (d['shiftPattern'] as String? ?? '').toString();
          final managerId       = (d['managerId'] as String? ?? '').toString();
          final officeLocation  = (d['officeLocation'] as String? ?? '').toString();
          final workPhone       = (d['workPhone'] ?? '').toString();
          final dateOfBirth     = d['dateOfBirth'] is Timestamp
              ? _fmtDate(d['dateOfBirth'])
              : (d['dateOfBirth'] as String? ?? '').toString();
          final joiningDate = d['joiningDate'] is Timestamp
              ? _fmtDate(d['joiningDate'])
              : (d['joiningDate'] as String? ?? '').toString();
          // -- DOCS & CERTS
          final cvUrl        = (d['cvUrl'] as String? ?? '').toString();
          final ndaUrl       = (d['ndaUrl'] as String? ?? '').toString();
          final empContract  = (d['employmentContractUrl'] as String? ?? '').toString();
          final workPermit   = (d['workPermitUrl'] as String? ?? '').toString();
          final taxForm      = (d['taxFormUrl'] as String? ?? '').toString();
          final certs        = (d['certifications'] as List?)?.join(', ') ?? '';
          final trainingRecs = (d['trainingRecords'] as List?)?.join(', ') ?? '';
          final prevEmps     = (d['previousEmployers'] as List?)?.join(', ') ?? '';
          final probReviews  = (d['probationReviews'] as List?)?.join(', ') ?? '';
          // -- AVATAR
          final profileUrl = (d['profilePhotoUrl'] as String? ?? '').toString();

          return ListView(children: [
            const SizedBox(height: 16),
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                child: profileUrl.isEmpty
                    ? Text(fullName.isEmpty ? '?' : fullName[0],
                    style: const TextStyle(fontSize: 32, color: Colors.white))
                    : null,
              ),
            ),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.camera_alt, color: _darkBlue),
                label:
                const Text('Change Photo', style: TextStyle(color: _darkBlue)),
                onPressed: () => _pickAndUploadPhoto(employeeId),
              ),
            ),

            // PERSONAL INFO
            _sectionHeader('Personal Information'),
            _infoRow('fullName', Icons.person, 'Full Name', fullName,
                onTap: () => _editField('fullName', 'Full Name', fullName)),
            _infoRow('name', Icons.account_circle, 'Name', name,
                onTap: () => _editField('name', 'Name', name)),
            _infoRow('dateOfBirth', Icons.cake, 'Date of Birth', dateOfBirth,
                onTap: () =>
                    _editField('dateOfBirth', 'Date of Birth', dateOfBirth)),
            _infoRow('personalEmail', Icons.email, 'User Name or Email',
                personalEmail,
                ),
            _infoRow('personalPhone', Icons.phone, 'Personal Phone',
                personalPhone,
                onTap: () =>
                    _editField('personalPhone', 'Personal Phone', personalPhone)),
            _infoRow('governmentIdUrl', Icons.badge, 'Gov’t ID URL', governmentId,
                onTap: () => _editField(
                    'governmentIdUrl', 'Gov’t ID URL', governmentId)),

            // OFFICE INFO
            _sectionHeader('Office Information'),
            _infoRow('employeeId', Icons.confirmation_number, 'Employee ID',
                employeeId),
            _infoRow('officeEmail', Icons.email_outlined, 'Office Email',
                officeEmail,
                onTap: () =>
                    _editField('officeEmail', 'Office Email', officeEmail)),
            _infoRow('jobTitle', Icons.work, 'Job Title', jobTitle,
                onTap: () => _editField('jobTitle', 'Job Title', jobTitle)),
            _infoRow('designation', Icons.work_outline, 'Designation',
                designation,
                onTap: () =>
                    _editField('designation', 'Designation', designation)),
            _infoRow('department', Icons.business, 'Department', department,
                onTap: () =>
                    _editField('department', 'Department', department)),
            _infoRow('joiningDate', Icons.calendar_today, 'Date of Hire',
                joiningDate,
                onTap: () =>
                    _editField('joiningDate', 'Date of Hire', joiningDate)),
            _infoRow('shiftPattern', Icons.schedule, 'Shift Pattern',
                shiftPattern,
                onTap: () =>
                    _editField('shiftPattern', 'Shift Pattern', shiftPattern)),
            _infoRow('managerId', Icons.supervisor_account, 'Manager ID',
                managerId,
                onTap: () =>
                    _editField('managerId', 'Manager ID', managerId)),
            _infoRow('officeLocation', Icons.location_on, 'Office Location',
                officeLocation,
                onTap: () =>
                    _editField('officeLocation', 'Office Location', officeLocation)),
            _infoRow('workPhone', Icons.phone_in_talk, 'Work Phone', workPhone,
                onTap: () => _editField('workPhone', 'Work Phone', workPhone)),
            _infoRow('badgeNumber', Icons.credit_card, 'Badge Number',
                badgeNumber,
                onTap: () =>
                    _editField('badgeNumber', 'Badge Number', badgeNumber)),

            // DOCS & CERTS
            _sectionHeader('Documents & Certifications'),
            _infoRow('cvUrl', Icons.insert_drive_file, 'CV URL', cvUrl,
                onTap: () => _pickAndUploadCV(employeeId)),
            _infoRow('ndaUrl', Icons.description, 'NDA URL', ndaUrl,
                onTap: () => _editField('ndaUrl', 'NDA URL', ndaUrl)),
            _infoRow('employmentContractUrl', Icons.article,
                'Contract URL', empContract,
                onTap: () => _editField(
                    'employmentContractUrl', 'Contract URL', empContract)),
            _infoRow('workPermitUrl', Icons.perm_device_information,
                'Work Permit URL', workPermit,
                onTap: () =>
                    _editField('workPermitUrl', 'Work Permit URL', workPermit)),
            _infoRow('taxFormUrl', Icons.receipt, 'Tax Form URL', taxForm,
                onTap: () => _editField('taxFormUrl', 'Tax Form URL', taxForm)),
            _infoRow('certifications', Icons.school, 'Certifications', certs,
                onTap: () =>
                    _editField('certifications', 'Certifications', certs)),
            _infoRow('trainingRecords', Icons.history_edu,
                'Training Records', trainingRecs,
                onTap: () =>
                    _editField('trainingRecords', 'Training Records', trainingRecs)),
            _infoRow('previousEmployers', Icons.business_center,
                'Previous Employers', prevEmps,
                onTap: () => _editField(
                    'previousEmployers', 'Previous Employers', prevEmps)),
            _infoRow('probationReviews', Icons.rate_review,
                'Probation Reviews', probReviews,
                onTap: () =>
                    _editField('probationReviews', 'Probation Reviews', probReviews)),
            _infoRow('yearsOfExperience', Icons.timeline, 'Years of Experience',
                yearsOfExp,
                onTap: () => _editField(
                    'yearsOfExperience', 'Years of Experience', yearsOfExp)),
            const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }
}
