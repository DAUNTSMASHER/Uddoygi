import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class AdminAllNoticesScreen extends StatefulWidget {
  const AdminAllNoticesScreen({super.key});

  @override
  State<AdminAllNoticesScreen> createState() => _AdminNoticeScreenState();
}

class _AdminNoticeScreenState extends State<AdminAllNoticesScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<PlatformFile> _pickedFiles = [];
  bool _loading = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) setState(() => _pickedFiles = result.files);
  }

  Future<void> _publishNotice() async {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty) return;
    setState(() => _loading = true);
    try {
      // Upload attachments
      List<String> fileUrls = [];
      if (_pickedFiles.isNotEmpty) {
        for (var file in _pickedFiles) {
          final path = file.path!;
          final name = file.name;
          final ref = FirebaseStorage.instance.ref('notice_attachments/$name-${DateTime.now().millisecondsSinceEpoch}');
          await ref.putFile(File(path));
          final url = await ref.getDownloadURL();
          fileUrls.add(url);
        }
      }
      await FirebaseFirestore.instance.collection('notices').add({
        'title': title,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'publishedBy': 'admin', // Change as needed
        'attachments': fileUrls,
      });
      _titleController.clear();
      _descriptionController.clear();
      setState(() => _pickedFiles = []);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notice published!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to publish: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addComment(String noticeId, String comment) async {
    if (comment.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('notices')
        .doc(noticeId)
        .collection('comments')
        .add({
      'text': comment,
      'timestamp': FieldValue.serverTimestamp(),
      'commentedBy': 'user', // Change as needed
    });
  }

  Color get primary => Colors.indigo;
  Color get accent => Colors.blueAccent;
  Color get containerBg => Colors.grey[100]!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: containerBg,
      appBar: AppBar(
        title: const Text('Notices', style: TextStyle(color: Colors.white)),
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Card(
            color: Colors.white,
            elevation: 4,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: primary),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: primary),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    style: TextStyle(color: Colors.grey[800]),
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: primary),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _pickFiles,
                        icon: Icon(Icons.attach_file, color: Colors.white),
                        label: const Text('Attach Files'),
                        style: ElevatedButton.styleFrom(backgroundColor: accent),
                      ),
                      const SizedBox(width: 10),
                      if (_pickedFiles.isNotEmpty)
                        Expanded(
                          child: Text(
                            "${_pickedFiles.length} file(s) attached",
                            style: TextStyle(color: accent, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _loading
                          ? const SizedBox(
                          height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.publish, color: Colors.white),
                      label: _loading ? const Text("Publishing...") : const Text('Publish Notice'),
                      onPressed: _loading ? null : _publishNotice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- Notices List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notices')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No notices yet.'));
                }
                final notices = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: notices.length,
                  itemBuilder: (context, i) {
                    final notice = notices[i];
                    final title = notice['title'] ?? '';
                    final desc = notice['description'] ?? '';
                    final timestamp = notice['timestamp'] as Timestamp?;
                    final publishedBy = notice['publishedBy'] ?? 'Admin';
                    final attachments = (notice['attachments'] ?? []) as List?;
                    final date = timestamp?.toDate();
                    final noticeId = notice.id;
                    final commentController = TextEditingController();

                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primary)),
                            const SizedBox(height: 6),
                            Text(desc, style: TextStyle(color: Colors.grey[800])),
                            const SizedBox(height: 6),
                            if (attachments != null && attachments.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: attachments.map<Widget>((url) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: GestureDetector(
                                      onTap: () {
                                        // Use url_launcher to open links if needed
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.attach_file, size: 18, color: accent),
                                          Flexible(
                                            child: Text(
                                              url,
                                              style: TextStyle(
                                                  color: accent,
                                                  decoration: TextDecoration.underline,
                                                  fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  publishedBy,
                                  style: TextStyle(color: accent, fontSize: 12),
                                ),
                                const Spacer(),
                                if (date != null)
                                  Text(
                                    DateFormat('d-M-yyyy h:mm a').format(date),
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                              ],
                            ),
                            const Divider(height: 24, color: Colors.grey),
                            // Comments Section
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('notices')
                                  .doc(noticeId)
                                  .collection('comments')
                                  .orderBy('timestamp', descending: false)
                                  .snapshots(),
                              builder: (context, commentSnap) {
                                if (commentSnap.connectionState == ConnectionState.waiting) {
                                  return const SizedBox(height: 20, child: Center(child: CircularProgressIndicator()));
                                }
                                final comments = commentSnap.data?.docs ?? [];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (comments.isNotEmpty)
                                      ...comments.map((c) {
                                        final data = c.data() as Map<String, dynamic>;
                                        final commentText = data['text'] ?? '';
                                        final commenter = data['commentedBy'] ?? '';
                                        final commentTime = data['timestamp'] is Timestamp
                                            ? (data['timestamp'] as Timestamp).toDate()
                                            : DateTime.now();
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.comment, size: 14, color: accent),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  commentText,
                                                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                commenter,
                                                style: TextStyle(color: accent.withOpacity(0.7), fontSize: 10),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat('d-M h:mm a').format(commentTime),
                                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    // Add Comment Inline
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: commentController,
                                              style: TextStyle(color: Colors.grey[800]),
                                              decoration: InputDecoration(
                                                hintText: "Add a comment...",
                                                hintStyle: TextStyle(color: accent.withOpacity(0.5)),
                                                contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide.none,
                                                ),
                                                filled: true,
                                                fillColor: Colors.grey[100],
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.send, color: primary),
                                            onPressed: () {
                                              _addComment(noticeId, commentController.text);
                                              commentController.clear();
                                            },
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
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
