import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class ComplaintActionsScreen extends StatefulWidget {
  final String complaintId;
  final String userName;
  final String userRole;

  const ComplaintActionsScreen({
    super.key,
    required this.complaintId,
    required this.userName,
    required this.userRole,
  });

  @override
  State<ComplaintActionsScreen> createState() => _ComplaintActionsScreenState();
}

class _ComplaintActionsScreenState extends State<ComplaintActionsScreen> {
  final TextEditingController _actionController = TextEditingController();
  String? _actionType;
  bool _loading = false;

  final uuid = const Uuid();

  final List<Map<String, String>> _actionTypes = [
    {'label': 'Note/Resolution', 'value': 'note'},
    {'label': 'Punishment', 'value': 'punishment'},
    {'label': 'Reward', 'value': 'reward'},
    {'label': 'Warning', 'value': 'warning'},
    {'label': 'Forward to CEO', 'value': 'forwarded'},
    {'label': 'Close Complaint', 'value': 'closed'},
    {'label': 'Reopen', 'value': 'pending'},
  ];

  @override
  void initState() {
    super.initState();
    _actionType = _actionTypes.first['value'];
  }

  Future<void> _addAction() async {
    if (_actionController.text.trim().isEmpty || _actionType == null) return;
    setState(() => _loading = true);

    final ref = FirebaseFirestore.instance.collection('complaints').doc(widget.complaintId);

    try {
      final actionId = uuid.v4();
      final now = DateTime.now();
      final formatted = DateFormat('yyyy-MM-dd HH:mm').format(now);

      await ref.update({
        'resolutionHistory': FieldValue.arrayUnion([
          {
            'id': actionId,
            'type': _actionType,
            'note': _actionController.text.trim(),
            'by': '${widget.userRole} (${widget.userName})',
            'time': formatted,
          }
        ]),
        'status': _actionType,
      });

      _actionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action added.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildActionCard(Map<String, dynamic> action) {
    final colorMap = {
      'note': Colors.blue,
      'punishment': Colors.red,
      'reward': Colors.green,
      'warning': Colors.deepOrange,
      'forwarded': Colors.indigo,
      'closed': Colors.grey,
      'pending': Colors.orange,
    };

    final iconMap = {
      'note': Icons.note,
      'punishment': Icons.gavel,
      'reward': Icons.card_giftcard,
      'warning': Icons.warning,
      'forwarded': Icons.forward,
      'closed': Icons.lock,
      'pending': Icons.hourglass_bottom,
    };

    final type = action['type'] ?? '';
    final color = colorMap[type] ?? Colors.blueGrey;
    final icon = iconMap[type] ?? Icons.note;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(type.toString().toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (action['note'] != null && action['note'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(action['note']),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(action['by'] ?? '', style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  Text(action['time'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Actions'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaints')
                    .doc(widget.complaintId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final history = (data['resolutionHistory'] ?? []) as List;
                  final status = data['status'] ?? 'pending';
                  final subject = data['subject'] ?? '(No Subject)';

                  return Column(
                    children: [
                      Card(
                        color: Colors.indigo.shade50,
                        child: ListTile(
                          title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Status: ${status.toString().toUpperCase()}"),
                          trailing: Chip(
                            label: Text(status.toString().toUpperCase()),
                            backgroundColor: Colors.indigo,
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: history.isEmpty
                            ? const Center(child: Text("No actions taken yet."))
                            : ListView.builder(
                          itemCount: history.length,
                          itemBuilder: (_, i) => _buildActionCard(history[i]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const Divider(),
            DropdownButtonFormField<String>(
              value: _actionType,
              decoration: const InputDecoration(
                labelText: 'Action Type',
                border: OutlineInputBorder(),
              ),
              items: _actionTypes.map((t) {
                return DropdownMenuItem(
                  value: t['value'],
                  child: Text(t['label']!),
                );
              }).toList(),
              onChanged: (v) => setState(() => _actionType = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _actionController,
              decoration: const InputDecoration(
                labelText: 'Details / Note',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                onPressed: _loading ? null : _addAction,
                icon: _loading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.add),
                label: Text(_loading ? 'Adding…' : 'Add Action'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
