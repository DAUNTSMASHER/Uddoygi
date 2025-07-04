import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

class RecruitmentScreen extends StatefulWidget {
  const RecruitmentScreen({super.key});

  @override
  State<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends State<RecruitmentScreen> {
  String _selectedRole = 'All';
  DateTime? _selectedDate;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  final int _itemsPerPage = 10;
  int _currentPage = 1;

  Future<void> _exportPDF(List<QueryDocumentSnapshot> applicants) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          children: [
            pw.Text('Applicant Report', style: pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Name', 'Role', 'Status', 'Date'],
              data: applicants.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return [
                  d['name'] ?? '',
                  d['role'] ?? '',
                  d['status'] ?? '',
                  d['appliedAt'] ?? ''
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _showApplicantForm({DocumentSnapshot? doc}) async {
    final isEdit = doc != null;
    final TextEditingController nameController = TextEditingController(text: doc?['name'] ?? '');
    final TextEditingController roleController = TextEditingController(text: doc?['role'] ?? '');
    String status = doc?['status'] ?? 'Applied';
    List<String> uploadedFiles = List<String>.from(doc?['files'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEdit ? 'Edit Applicant' : 'New Applicant'),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Role')),
              DropdownButton<String>(
                value: status,
                items: ['Applied', 'Interviewed', 'Selected', 'Rejected']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => status = val!),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                  if (result != null) {
                    for (var file in result.files) {
                      final ref = FirebaseStorage.instance.ref('applicants/${file.name}');
                      await ref.putData(file.bytes!);
                      final url = await ref.getDownloadURL();
                      uploadedFiles.add(url);
                    }
                  }
                },
                child: const Text('Upload PDFs'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final data = {
                    'name': nameController.text.trim(),
                    'role': roleController.text.trim(),
                    'status': status,
                    'files': uploadedFiles,
                    'appliedAt': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  };

                  if (isEdit) {
                    await FirebaseFirestore.instance.collection('applicants').doc(doc.id).update(data);
                  } else {
                    await FirebaseFirestore.instance.collection('applicants').add(data);
                  }
                  Navigator.pop(context);
                },
                child: Text(isEdit ? 'Update' : 'Submit'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchFilters(Map<String, dynamic> data) {
    if (_selectedRole != 'All' && data['role'] != _selectedRole) return false;
    if (_selectedDate != null) {
      final date = DateTime.tryParse(data['appliedAt'] ?? '') ?? DateTime(2000);
      if (date.month != _selectedDate!.month || date.year != _selectedDate!.year) return false;
    }
    if (_searchText.isNotEmpty && !data['name'].toLowerCase().contains(_searchText.toLowerCase())) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recruitment'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final snapshot = await FirebaseFirestore.instance.collection('applicants').get();
              _exportPDF(snapshot.docs);
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplicantForm(),
        icon: const Icon(Icons.add),
        label: const Text('New Applicant'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => _searchText = val),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _selectedRole,
                  items: ['All', 'Marketing', 'Factory', 'Admin', 'HR']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedRole = val!),
                ),
                const Spacer(),
                TextButton(
                  child: Text(_selectedDate == null
                      ? 'Filter by Date'
                      : DateFormat('MMM yyyy').format(_selectedDate!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('applicants')
                  .orderBy('appliedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final allDocs = snapshot.data!.docs
                    .where((doc) => _matchFilters(doc.data() as Map<String, dynamic>))
                    .toList();
                final totalPages = (allDocs.length / _itemsPerPage).ceil();
                final docs = allDocs.skip((_currentPage - 1) * _itemsPerPage).take(_itemsPerPage).toList();

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final d = doc.data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text('${d['name']} • ${d['role']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Status: ${d['status']} • Applied: ${d['appliedAt']}'),
                                  if (d['files'] != null)
                                    Wrap(
                                      spacing: 6,
                                      children: List.generate((d['files'] as List).length, (i) {
                                        return GestureDetector(
                                          onTap: () async => launchUrl(Uri.parse(d['files'][i])),
                                          child: const Chip(label: Text('View File'), avatar: Icon(Icons.picture_as_pdf)),
                                        );
                                      }),
                                    )
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showApplicantForm(doc: doc),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (totalPages > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(totalPages, (i) => i + 1).map((p) => TextButton(
                          onPressed: () => setState(() => _currentPage = p),
                          child: Text('$p', style: TextStyle(fontWeight: _currentPage == p ? FontWeight.bold : FontWeight.normal)),
                        )).toList(),
                      )
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
