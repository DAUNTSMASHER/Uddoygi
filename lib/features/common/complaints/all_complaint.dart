import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AllComplaintScreen extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String? role;

  const AllComplaintScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    this.role,
  });

  @override
  State<AllComplaintScreen> createState() => _AllComplaintScreenState();
}

class _AllComplaintScreenState extends State<AllComplaintScreen> {
  String _statusFilter = 'all';
  String _searchText = '';
  String _actionTypeFilter = 'all';

  final _searchController = TextEditingController();
  final List<String> _statusOptions = ['all', 'pending', 'resolved', 'forwarded', 'closed'];
  final List<String> _actionTypes = ['all', 'note', 'punishment', 'reward', 'warning', 'forwarded', 'closed', 'pending'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _complaintsStream() {
    var q = FirebaseFirestore.instance
        .collection('complaints')
        .orderBy('timestamp', descending: true);

    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }

    if (widget.role != "hr" && widget.role != "admin") {
      q = q.where('submittedBy', isEqualTo: widget.userEmail);
    }

    return q.snapshots();
  }

  void _showComplaintDetail(Map<String, dynamic> data, String docId) {
    final List history = (data['resolutionHistory'] ?? []) as List;
    final filteredHistory = history
        .where((entry) =>
    _actionTypeFilter == 'all' ||
        (entry['type'] ?? '').toString().toLowerCase() == _actionTypeFilter)
        .toList()
      ..sort((a, b) {
        final t1 = (a['editedAt'] ?? a['timestamp']) ?? '';
        final t2 = (b['editedAt'] ?? b['timestamp']) ?? '';
        return t2.toString().compareTo(t1.toString());
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) => SingleChildScrollView(
            controller: controller,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['subject'] ?? '(No Subject)',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const SizedBox(height: 6),
                  Text(data['message'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.filter_alt, size: 18),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _actionTypeFilter,
                        items: _actionTypes
                            .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                            .toList(),
                        onChanged: (val) => setState(() => _actionTypeFilter = val!),
                      ),
                      const Spacer(),
                      _statusChip(data['status'] ?? 'pending'),
                    ],
                  ),
                  const Divider(height: 24),
                  if (filteredHistory.isEmpty)
                    const Text('No actions recorded.'),
                  if (filteredHistory.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, i) {
                        final entry = filteredHistory[i];
                        final type = (entry['type'] ?? 'note').toString();
                        final note = (entry['note'] ?? '').toString();
                        final by = entry['by'] ?? '';
                        final ts = entry['editedAt'] ?? entry['timestamp'] ?? '';
                        final dateStr = ts is Timestamp
                            ? DateFormat('MMM d, h:mm a').format(ts.toDate())
                            : ts.toString();

                        return Card(
                          color: Colors.grey[100],
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.history, color: Colors.indigo),
                            title: Text('${type.toUpperCase()}: $note',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            subtitle: Text('By: $by\n$dateStr'),
                            isThreeLine: true,
                            trailing: (widget.role == 'hr' || widget.role == 'admin')
                                ? IconButton(
                              icon: const Icon(Icons.edit, color: Colors.indigo),
                              onPressed: () {
                                _editHistoryEntry(docId, history, i, entry);
                              },
                            )
                                : null,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _editHistoryEntry(String docId, List history, int index, Map entry) {
    final controller = TextEditingController(text: entry['note'] ?? '');
    final type = entry['type'] ?? 'note';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Action'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () async {
              history[index]['note'] = controller.text;
              history[index]['editedAt'] = Timestamp.now();
              await FirebaseFirestore.instance.collection('complaints').doc(docId).update({
                'resolutionHistory': history,
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action updated')));
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'resolved':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'forwarded':
        color = Colors.indigo;
        break;
      case 'closed':
        color = Colors.grey;
        break;
      default:
        color = Colors.blueGrey;
    }

    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Complaints'),
        backgroundColor: Colors.indigo,
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _statusFilter,
              items: _statusOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                  .toList(),
              onChanged: (val) => setState(() => _statusFilter = val!),
              icon: const Icon(Icons.filter_alt, color: Colors.white),
              dropdownColor: Colors.white,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchText = val),
              decoration: InputDecoration(
                hintText: 'Search complaints...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _complaintsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          final filtered = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final subject = (data['subject'] ?? '').toString().toLowerCase();
            final message = (data['message'] ?? '').toString().toLowerCase();
            final name = (data['submittedByName'] ?? '').toString().toLowerCase();
            return _searchText.isEmpty ||
                subject.contains(_searchText.toLowerCase()) ||
                message.contains(_searchText.toLowerCase()) ||
                name.contains(_searchText.toLowerCase());
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No complaints found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final data = filtered[i].data() as Map<String, dynamic>;
              final docId = filtered[i].id;
              final time = data['timestamp'] is Timestamp
                  ? (data['timestamp'] as Timestamp).toDate()
                  : DateTime.now();

              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: ListTile(
                  title: Text(data['subject'] ?? '(No Subject)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['message'] ?? '', style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(DateFormat('MMM d, h:mm a').format(time),
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  trailing: _statusChip(data['status'] ?? 'pending'),
                  onTap: () => _showComplaintDetail(data, docId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}