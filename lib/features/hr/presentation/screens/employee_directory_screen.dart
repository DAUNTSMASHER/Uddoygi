import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EmployeeDirectoryScreen extends StatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  State<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();

  String _searchText = '';
  String _selectedDept = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> departments = ['All', 'HR', 'Factory', 'Marketing', 'Admin'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('Employee Directory', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportEmployeePdf,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchText = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),

            // Department Chips
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: departments.length,
                itemBuilder: (context, index) {
                  final dept = departments[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(dept),
                      selected: _selectedDept == dept,
                      selectedColor: Colors.indigo,
                      backgroundColor: Colors.grey[200],
                      labelStyle: TextStyle(
                        color: _selectedDept == dept ? Colors.white : Colors.black,
                      ),
                      onSelected: (_) => setState(() => _selectedDept = dept),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Designation Filter
            TextField(
              controller: _designationController,
              decoration: const InputDecoration(
                labelText: 'Filter by Designation',
                prefixIcon: Icon(Icons.work),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Joining Date Filter
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(_startDate == null
                        ? 'Start Date'
                        : DateFormat('yyyy-MM-dd').format(_startDate!)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(_endDate == null
                        ? 'End Date'
                        : DateFormat('yyyy-MM-dd').format(_endDate!)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _startDate = null;
                    _endDate = null;
                  }),
                )
              ],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('employees').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final filtered = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toLowerCase();
                    final email = (data['email'] ?? '').toLowerCase();
                    final dept = (data['department'] ?? '');
                    final desg = (data['designation'] ?? '').toLowerCase();
                    final joining = data['joiningDate'] ?? '';

                    final matchesSearch = name.contains(_searchText) || email.contains(_searchText);
                    final matchesDept = _selectedDept == 'All' || dept == _selectedDept;
                    final matchesDesg = desg.contains(_designationController.text.trim().toLowerCase());

                    final joinDate = joining.isNotEmpty ? DateTime.tryParse(joining) : null;
                    final matchesDate = (_startDate == null && _endDate == null) ||
                        (joinDate != null &&
                            (_startDate == null || joinDate.isAfter(_startDate!.subtract(const Duration(days: 1)))) &&
                            (_endDate == null || joinDate.isBefore(_endDate!.add(const Duration(days: 1)))));

                    return matchesSearch && matchesDept && matchesDesg && matchesDate;
                  }).toList();

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () => _showEmployeeDetail(data),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.indigo,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(data['name'] ?? ''),
                          subtitle: Text('${data['designation'] ?? ''} • ${data['department'] ?? ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () => _showAddEditForm(existing: data, id: doc.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Add Employee'),
        onPressed: () => _showAddEditForm(),
      ),
    );
  }

  void _showEmployeeDetail(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['name'] ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('Email', data['email']),
            _infoRow('Phone', data['phone']),
            _infoRow('Department', data['department']),
            _infoRow('Designation', data['designation']),
            _infoRow('Joining Date', data['joiningDate']),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? '')),
        ],
      ),
    );
  }

  void _showAddEditForm({Map<String, dynamic>? existing, String? id}) {
    final nameController = TextEditingController(text: existing?['name']);
    final emailController = TextEditingController(text: existing?['email']);
    final phoneController = TextEditingController(text: existing?['phone']);
    final deptController = TextEditingController(text: existing?['department']);
    final desgController = TextEditingController(text: existing?['designation']);
    final joiningController = TextEditingController(text: existing?['joiningDate']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(existing == null ? 'Add Employee' : 'Edit Employee',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: deptController, decoration: const InputDecoration(labelText: 'Department')),
            TextField(controller: desgController, decoration: const InputDecoration(labelText: 'Designation')),
            TextField(controller: joiningController, decoration: const InputDecoration(labelText: 'Joining Date (yyyy-MM-dd)')),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              onPressed: () async {
                final data = {
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'department': deptController.text.trim(),
                  'designation': desgController.text.trim(),
                  'joiningDate': joiningController.text.trim(),
                };

                if (id != null) {
                  await FirebaseFirestore.instance.collection('employees').doc(id).update(data);
                } else {
                  await FirebaseFirestore.instance.collection('employees').add(data);
                }

                Navigator.pop(context);
              },
            )
          ],
        ),
      ),
    );
  }

  Future<void> _exportEmployeePdf() async {
    final query = await FirebaseFirestore.instance.collection('employees').get();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Employee Directory',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Name', 'Email', 'Phone', 'Dept', 'Designation', 'Joining'],
            data: query.docs.map((doc) {
              final d = doc.data();
              return [
                d['name'] ?? '',
                d['email'] ?? '',
                d['phone'] ?? '',
                d['department'] ?? '',
                d['designation'] ?? '',
                d['joiningDate'] ?? '',
              ];
            }).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey),
            cellPadding: const pw.EdgeInsets.all(5),
          )
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
