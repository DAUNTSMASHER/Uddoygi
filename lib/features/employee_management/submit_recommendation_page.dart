import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class SubmitRecommendationPage extends StatefulWidget {
  const SubmitRecommendationPage({Key? key}) : super(key: key);

  @override
  _SubmitRecommendationPageState createState() =>
      _SubmitRecommendationPageState();
}

class _SubmitRecommendationPageState extends State<SubmitRecommendationPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _govIdController = TextEditingController();
  final _profilePhotoController = TextEditingController();
  final _cvController = TextEditingController();
  final _ndaController = TextEditingController();
  final _contractController = TextEditingController();
  final _permitController = TextEditingController();
  final _taxController = TextEditingController();

  final _certsController = TextEditingController();
  final _trainingController = TextEditingController();
  final _prevEmpsController = TextEditingController();
  final _probationController = TextEditingController();

  final _recommendationController = TextEditingController();
  final _reasonsController = TextEditingController();

  String _status = 'Approved';
  String? _docId;

  @override
  void dispose() {
    for (final c in [
      _fullNameController,
      _nameController,
      _emailController,
      _phoneController,
      _govIdController,
      _profilePhotoController,
      _cvController,
      _ndaController,
      _contractController,
      _permitController,
      _taxController,
      _certsController,
      _trainingController,
      _prevEmpsController,
      _probationController,
      _recommendationController,
      _reasonsController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendToCEO() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'fullName': _fullNameController.text.trim(),
      'name': _nameController.text.trim(),
      'personalEmail': _emailController.text.trim(),
      'personalPhone': _phoneController.text.trim(),
      'governmentIdUrl': _govIdController.text.trim(),
      'profilePhotoUrl': _profilePhotoController.text.trim(),
      'cvUrl': _cvController.text.trim(),
      'ndaUrl': _ndaController.text.trim(),
      'employmentContractUrl': _contractController.text.trim(),
      'workPermitUrl': _permitController.text.trim(),
      'taxFormUrl': _taxController.text.trim(),
      'certifications': _certsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'trainingRecords': _trainingController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'previousEmployers': _prevEmpsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'probationReviews': _probationController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'recommendation': _recommendationController.text.trim(),
      'createdAt': Timestamp.now(),
      'status': _status,
      'reasons': _status == 'Rejected'
          ? _reasonsController.text.trim()
          : '',
      'sentToCEO': true,
    };

    final doc = await FirebaseFirestore.instance
        .collection('recommendation')
        .add(data);
    setState(() => _docId = doc.id);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recommendation sent to CEO')),
    );
  }

  Future<void> _showStatus() async {
    if (_docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recommendation yet')),
      );
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('recommendation')
        .doc(_docId)
        .get();
    final data = snap.data()!;
    final status = (data['status'] as String?) ?? 'Pending';
    final reasons = (data['reasons'] as String?) ?? '—';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Recommendation Status'),
        content: ListTile(
          leading: Icon(
            status == 'Approved' ? Icons.check_circle : Icons.cancel,
            color: status == 'Approved' ? Colors.green : Colors.red,
            size: 40,
          ),
          title: Text(status,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: reasons.isNotEmpty
              ? Text('Reasons: $reasons')
              : null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _darkBlue)),
          )
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text,
          style: TextStyle(
              color: _darkBlue, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Submit Recommendation'),
        backgroundColor: _darkBlue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionHeader('Basic Information'),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person, color: _darkBlue),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v != null && v.trim().isNotEmpty
                        ? null
                        : 'Required',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email, color: _darkBlue),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v != null && v.contains('@')
                        ? null
                        : 'Valid email required',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone, color: _darkBlue),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  _sectionHeader('Documents & Certifications'),
                  TextFormField(
                    controller: _govIdController,
                    decoration: const InputDecoration(
                      labelText: 'Gov’t ID URL',
                      prefixIcon: Icon(Icons.badge, color: _darkBlue),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cvController,
                    decoration: const InputDecoration(
                      labelText: 'CV URL',
                      prefixIcon:
                      Icon(Icons.insert_drive_file, color: _darkBlue),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ndaController,
                    decoration: const InputDecoration(
                      labelText: 'NDA URL',
                      prefixIcon: Icon(Icons.description, color: _darkBlue),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _certsController,
                    decoration: const InputDecoration(
                      labelText: 'Certifications (comma separated)',
                      prefixIcon: Icon(Icons.school, color: _darkBlue),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  _sectionHeader('Recommendation Status'),
                  Row(
                    children: ['Approved', 'Rejected'].map((s) {
                      return Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s),
                          value: s,
                          groupValue: _status,
                          activeColor: _darkBlue,
                          onChanged: (v) => setState(() => _status = v!),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_status == 'Rejected') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonsController,
                      decoration: const InputDecoration(
                        labelText: 'Rejection Reasons',
                        prefixIcon:
                        Icon(Icons.error_outline, color: _darkBlue),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (v) => _status == 'Rejected' &&
                          (v == null || v.trim().isEmpty)
                          ? 'Please provide reasons'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text('Send to CEO',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _darkBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _sendToCEO,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.visibility, color: _darkBlue),
                    label: const Text('View Status',
                        style: TextStyle(color: _darkBlue)),
                    onPressed: _showStatus,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
