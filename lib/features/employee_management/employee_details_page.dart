import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../storage/drive.dart';

const Color _darkBlue = Color(0xFF2A0A4B);

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

  // Built only after _cid is loaded — never use an empty-CID reference.
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

  Future<void> _pickAndUploadCV(String employeeId) async {
    if (_docRef == null) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result?.files.single.path == null) return;
    if (!mounted) return;

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
      await _docRef!.update({'cvUrl': url});
    }
  }

  Future<void> _editField(String key, String label, String currentValue) async {
    if (_docRef == null) return;
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
        await _docRef!.update({key: Timestamp.fromDate(picked)});
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
      await _docRef!.update({key: updated});
    }
  }

  Future<void> _editPaymentMethod() async {
    if (_docRef == null) return;
    const methods = ['bKash', 'Nagad', 'Rocket', 'Upay', 'Bank Transfer', 'Other'];
    final snap = await _docRef!.get();
    if (!mounted) return;
    final current = (snap.data()?['paymentMethod'] as String?) ?? '';
    String? selected = current.isEmpty ? null : current;

    final nav = Navigator.of(context);
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Select Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: methods.map((m) => ListTile(
              dense: true,
              title: Text(m),
              leading: Icon(
                selected == m
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected == m ? const Color(0xFF2A0A4B) : Colors.black38,
                size: 20,
              ),
              onTap: () => setSt(() => selected = m),
            )).toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => nav.pop(),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => nav.pop(selected),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (picked != null && picked != current) {
      await _docRef!.update({'paymentMethod': picked});
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
      appBar: AppBar(
        title: const Text(
          'Employee Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
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
          // -- PERSONAL
          final fullName      = (d['fullName'] as String? ?? '').toString();
          final name          = (d['name'] as String? ?? fullName).toString();
          final personalEmail = (d['personalEmail'] as String? ?? '').toString();
          final personalPhone = (d['personalPhone'] ?? '').toString();
          final governmentId  = (d['governmentIdUrl'] as String? ?? '').toString();
          // -- PAYMENT INFO
          final paymentMethod  = (d['paymentMethod']  as String? ?? '').toString();
          final paymentAccount = (d['paymentAccount'] as String? ?? '').toString();
          final paymentName    = (d['paymentName']    as String? ?? '').toString();
          final bankName       = (d['bankName']       as String? ?? '').toString();
          final branchName     = (d['branchName']     as String? ?? '').toString();
          final routingNumber  = (d['routingNumber']  as String? ?? '').toString();
          final paymentVerified = (d['paymentVerified'] as bool?) ?? false;
          // -- OFFICE
          final employeeId      = (d['employeeId'] as String? ?? widget.employeeId).toString();
          final officeEmail     = (d['officeEmail'] as String? ?? widget.userEmail).toString();
          final department      = (d['department'] as String? ?? '').toString().toUpperCase();
          final jobTitle        = (d['jobTitle'] as String? ?? '').toString();
          final designation     = (d['designation'] as String? ?? '').toString();
          // employmentType read but not displayed in current layout
          // final employmentType = (d['employmentType'] as String? ?? '').toString();
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
                    style: const TextStyle(fontSize: 32, color: Color(0xFF2A0A4B), fontWeight: FontWeight.w900))
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

            // PAYMENT INFO
            _sectionHeader('Payment Information'),
            // Verified badge
            if (paymentVerified)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF065F46).withValues(alpha: 0.08),
                  border: Border.all(color: const Color(0xFF065F46).withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF065F46), size: 18),
                  SizedBox(width: 8),
                  Text('Payment details verified by HR',
                      style: TextStyle(
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ]),
              )
            else
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.08),
                  border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Payment details not yet verified. Employee should update their info.',
                        style: TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
                ]),
              ),
            _infoRow('paymentMethod', Icons.payment_rounded, 'Payment Method',
                paymentMethod.isEmpty ? 'Not set' : paymentMethod,
                onTap: () => _editPaymentMethod()),
            _infoRow('paymentAccount', Icons.account_balance_wallet_rounded,
                'Account / Mobile Number',
                paymentAccount.isEmpty ? 'Not set' : paymentAccount,
                onTap: () => _editField('paymentAccount', 'Account / Mobile Number', paymentAccount)),
            _infoRow('paymentName', Icons.person_outline_rounded,
                'Account Holder Name',
                paymentName.isEmpty ? 'Not set' : paymentName,
                onTap: () => _editField('paymentName', 'Account Holder Name', paymentName)),
            _infoRow('bankName', Icons.account_balance_rounded,
                'Bank Name (if bank transfer)',
                bankName.isEmpty ? 'Not set' : bankName,
                onTap: () => _editField('bankName', 'Bank Name', bankName)),
            _infoRow('branchName', Icons.location_city_rounded,
                'Branch Name',
                branchName.isEmpty ? 'Not set' : branchName,
                onTap: () => _editField('branchName', 'Branch Name', branchName)),
            _infoRow('routingNumber', Icons.numbers_rounded,
                'Routing / Account Number',
                routingNumber.isEmpty ? 'Not set' : routingNumber,
                onTap: () => _editField('routingNumber', 'Routing Number', routingNumber)),
            // HR verify toggle
            ListTile(
              leading: Icon(
                paymentVerified ? Icons.verified_rounded : Icons.pending_actions_rounded,
                color: paymentVerified ? const Color(0xFF065F46) : const Color(0xFFD97706),
              ),
              title: const Text('HR Verification'),
              subtitle: Text(paymentVerified ? 'Verified' : 'Pending verification'),
              trailing: Switch.adaptive(
                value: paymentVerified,
                activeThumbColor: const Color(0xFF065F46),
                activeTrackColor: const Color(0xFF065F46).withValues(alpha: 0.4),
                onChanged: (v) async {
                  if (_docRef == null) return;
                  await _docRef!.update({'paymentVerified': v});
                },
              ),
            ),
            const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }
}

