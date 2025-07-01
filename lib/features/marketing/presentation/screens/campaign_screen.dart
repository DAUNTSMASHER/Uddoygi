import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _proposalController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  bool isHead = false;
  bool isAdmin = false;
  String role = '';

  @override
  void initState() {
    super.initState();
    checkUserRole();
  }

  Future<void> checkUserRole() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists) {
      setState(() {
        role = doc['role'] ?? '';
        isHead = role == 'marketing_head';
        isAdmin = role == 'admin' || role == 'ceo';
      });
    }
  }

  Future<void> submitProposal() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('campaigns').add({
        'proposal': _proposalController.text.trim(),
        'status': 'pending',
        'submittedBy': user!.uid,
        'timestamp': Timestamp.now(),
      });
      _proposalController.clear();
    }
  }

  Future<void> updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance.collection('campaigns').doc(docId).update({'status': status});
  }

  Future<void> generatePdf(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Campaign Reports')),
          ...docs.map((c) => pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text('Proposal: ${c['proposal']}\nStatus: ${c['status']}\nDate: ${DateFormat.yMMMd().add_jm().format((c['timestamp'] as Timestamp).toDate())}'),
          ))
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final uid = user!.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                final snap = await FirebaseFirestore.instance.collection('campaigns').get();
                await generatePdf(snap.docs);
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (isHead) ...[
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _proposalController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Campaign Proposal',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitProposal,
                        child: const Text('Submit to CEO'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isAdmin ? 'All Campaigns' : 'Your Submitted Campaigns',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('campaigns')
                    .where('submittedBy', isEqualTo: isAdmin ? null : uid)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('No campaigns found.'));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final c = docs[index];
                      final time = (c['timestamp'] as Timestamp).toDate();
                      final formatted = DateFormat.yMMMd().add_jm().format(time);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        child: ListTile(
                          title: Text(c['proposal']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Status: ${c['status']}'),
                              Text('Submitted on: $formatted'),
                            ],
                          ),
                          trailing: isAdmin
                              ? PopupMenuButton<String>(
                            onSelected: (status) => updateStatus(c.id, status),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'approved', child: Text('Approve')),
                              PopupMenuItem(value: 'rejected', child: Text('Reject')),
                            ],
                          )
                              : Chip(
                            label: Text(
                              c['status'],
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: c['status'] == 'approved'
                                ? Colors.green
                                : c['status'] == 'pending'
                                ? Colors.orange
                                : Colors.grey,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
