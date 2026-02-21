import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ShiftTrackerScreen extends StatefulWidget {
  const ShiftTrackerScreen({super.key});

  @override
  State<ShiftTrackerScreen> createState() => _ShiftTrackerScreenState();
}

class _ShiftTrackerScreenState extends State<ShiftTrackerScreen> {
  String _cid = '';
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String _filterEmployee = '';

  void _showShiftForm({DocumentSnapshot? doc, DateTime? date}) {
    final isEdit = doc != null;
    final nameController = TextEditingController(text: doc?['employeeName'] ?? '');
    final shiftType = doc?['shift'] ?? 'Morning';
    final shiftDate = doc?['date'] ?? DateFormat('yyyy-MM-dd').format(date ?? DateTime.now());
    String selectedShift = shiftType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Employee Name')),
            DropdownButton<String>(
              value: selectedShift,
              items: ['Morning', 'Evening', 'Night']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => selectedShift = val!),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'employeeName': nameController.text.trim(),
                  'shift': selectedShift,
                  'date': shiftDate,
                };
                if (isEdit) {
                  await DB.colSync(_cid, C.shifts).doc(doc.id).update(data);
                } else {
                  await DB.colSync(_cid, C.shifts).add(data);
                }
                Navigator.pop(context);
              },
              child: Text(isEdit ? 'Update' : 'Submit'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPDF(List<QueryDocumentSnapshot> shifts) async {
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: pw.Font.times(), bold: pw.Font.timesBold(), italic: pw.Font.timesItalic(), boldItalic: pw.Font.timesBoldItalic()));
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          children: [
            pw.Text('Shift Report', style: pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Employee', 'Date', 'Shift'],
              data: shifts.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return [d['employeeName'], d['date'], d['shift']];
              }).toList(),
            )
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
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
      appBar: AppBar(
        title: const Text('Shift Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final snapshot = await DB.colSync(_cid, C.shifts).get();
              _exportPDF(snapshot.docs);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showShiftForm(date: _selectedDay),
        label: const Text('Add Shift'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Filter by Employee',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => _filterEmployee = val.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: DB.colSync(_cid, C.shifts)
                  .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(_selectedDay))
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['employeeName'].toLowerCase().contains(_filterEmployee.toLowerCase());
                }).toList();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final d = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('${d['employeeName']} • ${d['shift']}'),
                        subtitle: Text('Date: ${d['date']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showShiftForm(doc: doc),
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
    );
  }
}
