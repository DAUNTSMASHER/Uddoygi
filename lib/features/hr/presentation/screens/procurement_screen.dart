import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProcurementScreen extends StatefulWidget {
  const ProcurementScreen({super.key});

  @override
  State<ProcurementScreen> createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends State<ProcurementScreen> {
  String _statusFilter = 'All';
  DateTime? _selectedMonth;
  int total = 0, approved = 0, pending = 0, received = 0;
  List<Map<String, dynamic>> _filteredData = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final snapshot = await FirebaseFirestore.instance.collection('procurements').get();
    int t = 0, a = 0, p = 0, r = 0;
    List<Map<String, dynamic>> filtered = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final date = DateTime.tryParse(data['requestedAt'] ?? '') ?? DateTime(2000);
      if (_selectedMonth != null &&
          (date.month != _selectedMonth!.month || date.year != _selectedMonth!.year)) {
        continue;
      }

      filtered.add(data);
      t++;
      if (data['status'] == 'Approved') a++;
      if (data['status'] == 'Pending') p++;
      if (data['status'] == 'Received') r++;
    }

    setState(() {
      total = t;
      approved = a;
      pending = p;
      received = r;
      _filteredData = filtered;
    });
  }

  String _generateAISummary(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return "No data available for this month.";

    Map<String, int> itemFreq = {};
    Map<String, int> vendorFreq = {};

    for (var d in data) {
      itemFreq[d['item']] = (itemFreq[d['item']] ?? 0) + 1;
      vendorFreq[d['vendor']] = (vendorFreq[d['vendor']] ?? 0) + 1;
    }

    String topItem = itemFreq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    String topVendor = vendorFreq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return "🧠 This month, the most requested item was **$topItem**, and the vendor most frequently used was **$topVendor**.";
  }

  Future<void> _showProcurementForm({DocumentSnapshot? doc}) async {
    final isEdit = doc != null;
    final TextEditingController itemController =
    TextEditingController(text: doc?['item'] ?? '');
    final TextEditingController qtyController =
    TextEditingController(text: doc?['quantity']?.toString() ?? '');
    final TextEditingController vendorController =
    TextEditingController(text: doc?['vendor'] ?? '');
    String status = doc?['status'] ?? 'Pending';

    await showModalBottomSheet(
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
              Text(isEdit ? 'Edit Procurement' : 'New Procurement'),
              TextField(
                controller: itemController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: vendorController,
                decoration: const InputDecoration(labelText: 'Vendor Name'),
              ),
              DropdownButton<String>(
                value: status,
                items: ['Pending', 'Approved', 'Received', 'Cancelled']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => status = val!),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final data = {
                    'item': itemController.text.trim(),
                    'quantity': int.tryParse(qtyController.text.trim()) ?? 0,
                    'vendor': vendorController.text.trim(),
                    'status': status,
                    'requestedAt':
                    DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  };

                  if (isEdit) {
                    await FirebaseFirestore.instance
                        .collection('procurements')
                        .doc(doc.id)
                        .update(data);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('procurements')
                        .add(data);
                  }

                  Navigator.pop(context);
                  _fetchStats();
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

  void _deleteProcurement(String id) async {
    await FirebaseFirestore.instance.collection('procurements').doc(id).delete();
    _fetchStats();
  }

  bool _matchFilters(Map<String, dynamic> data) {
    final date = DateTime.tryParse(data['requestedAt'] ?? '') ?? DateTime(2000);
    if (_statusFilter != 'All' && data['status'] != _statusFilter) return false;
    if (_selectedMonth != null &&
        (date.month != _selectedMonth!.month || date.year != _selectedMonth!.year)) {
      return false;
    }
    return true;
  }

  Widget _buildStatsCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(title, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          DropdownButton<String>(
            value: _statusFilter,
            items: ['All', 'Pending', 'Approved', 'Received', 'Cancelled']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() {
              _statusFilter = val!;
              _fetchStats();
            }),
          ),
          const Spacer(),
          TextButton(
            child: Text(_selectedMonth == null
                ? 'Filter by Month'
                : DateFormat('MMM yyyy').format(_selectedMonth!)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2022),
                lastDate: DateTime(2030),
                helpText: 'Pick a date to filter by month',
              );
              if (picked != null) {
                setState(() => _selectedMonth = picked);
                _fetchStats();
              }
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiSummary = _generateAISummary(_filteredData);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Procurement Requests'),
        backgroundColor: Colors.indigo,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProcurementForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Request'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatsCard('Total', total, Colors.blue),
              _buildStatsCard('Approved', approved, Colors.green),
            ],
          ),
          Row(
            children: [
              _buildStatsCard('Pending', pending, Colors.orange),
              _buildStatsCard('Received', received, Colors.teal),
            ],
          ),
          _buildFilterControls(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(aiSummary,
                style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('procurements')
                  .orderBy('requestedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs
                    .where((doc) => _matchFilters(doc.data() as Map<String, dynamic>))
                    .toList();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('${data['item']} • ${data['status']}'),
                        subtitle: Text(
                          'Qty: ${data['quantity']} | Vendor: ${data['vendor']}\nRequested: ${data['requestedAt']}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showProcurementForm(doc: doc);
                            } else if (value == 'delete') {
                              _deleteProcurement(doc.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
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
