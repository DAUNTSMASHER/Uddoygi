import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class AdminNoticeScreen extends StatefulWidget {
  const AdminNoticeScreen({super.key});

  @override
  State<AdminNoticeScreen> createState() => _AdminNoticeScreenState();
}

class _AdminNoticeScreenState extends State<AdminNoticeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedFile;
  String? _fileUrl;
  bool _loading = false;
  final ImagePicker _picker = ImagePicker();
  int? _expandedIndex;

  Future<void> _pickFile() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('notice_files/$fileName');
    await ref.putFile(_selectedFile!);
    _fileUrl = await ref.getDownloadURL();
  }

  Future<void> _publishNotice() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) return;
    setState(() => _loading = true);

    try {
      if (_selectedFile != null) {
        await _uploadFile();
      }
      await FirebaseFirestore.instance.collection('notices').add({
        'title': title,
        'description': description,
        'fileUrl': _fileUrl ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'publishedBy': 'admin',
      });

      _titleController.clear();
      _descriptionController.clear();
      _selectedFile = null;
      _fileUrl = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notice published successfully!")),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to publish: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _filePreview() {
    if (_selectedFile == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.attachment, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _selectedFile!.path.split('/').last,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              setState(() => _selectedFile = null);
            },
          )
        ],
      ),
    );
  }

  void _editNotice(BuildContext context, DocumentSnapshot notice) {
    final TextEditingController titleController =
    TextEditingController(text: notice['title']);
    final TextEditingController descriptionController =
    TextEditingController(text: notice['description']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.indigo[900],
        title: const Text('Edit Notice', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Colors.white)),
            ),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[700]),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('notices')
                  .doc(notice.id)
                  .update({
                'title': titleController.text,
                'description': descriptionController.text,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteNotice(BuildContext context, String id, String? fileUrl) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.indigo[900],
        title: const Text('Delete Notice', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this notice?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Delete comments
                final comments = await FirebaseFirestore.instance
                    .collection('notices')
                    .doc(id)
                    .collection('comments')
                    .get();
                for (var doc in comments.docs) {
                  await doc.reference.delete();
                }
                // Delete attached file from Storage
                if (fileUrl != null && fileUrl.isNotEmpty) {
                  try {
                    await FirebaseStorage.instance.refFromURL(fileUrl).delete();
                  } catch (_) {}
                }
                await FirebaseFirestore.instance
                    .collection('notices')
                    .doc(id)
                    .delete();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error deleting notice: $e")),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editComment(String noticeId, DocumentSnapshot comment) {
    final TextEditingController commentController =
    TextEditingController(text: comment['text']);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.indigo[900],
        title: const Text('Edit Comment', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: commentController,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              labelText: 'Comment', labelStyle: TextStyle(color: Colors.white)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('notices')
                  .doc(noticeId)
                  .collection('comments')
                  .doc(comment.id)
                  .update({'text': commentController.text});
              Navigator.pop(context);
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteComment(String noticeId, String commentId) async {
    await FirebaseFirestore.instance
        .collection('notices')
        .doc(noticeId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  void _addComment(String noticeId, String commenter) {
    final TextEditingController commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.indigo[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.indigo,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: commentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Write a comment...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                  autofocus: true,
                  onSubmitted: (value) async {
                    if (value.trim().isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('notices')
                          .doc(noticeId)
                          .collection('comments')
                          .add({
                        'text': value.trim(),
                        'timestamp': Timestamp.now(),
                        'commenter': commenter,
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () async {
                  if (commentController.text.trim().isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('notices')
                        .doc(noticeId)
                        .collection('comments')
                        .add({
                      'text': commentController.text.trim(),
                      'timestamp': Timestamp.now(),
                      'commenter': commenter,
                    });
                    Navigator.pop(context);
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComments(String noticeId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notices')
          .doc(noticeId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('No comments yet.', style: TextStyle(color: Colors.white70)),
          );
        }
        return Column(
          children: docs.map((doc) {
            final c = doc.data() as Map<String, dynamic>;
            final time = c['timestamp'] is Timestamp
                ? (c['timestamp'] as Timestamp).toDate()
                : DateTime.tryParse('${c['timestamp']}') ?? DateTime.now();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.person, size: 17, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.indigo[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                c['commenter'] ?? 'User',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              const Spacer(),
                              // Edit & Delete buttons
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white70, size: 16),
                                onPressed: () => _editComment(noticeId, doc),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: "Edit",
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                                onPressed: () => _deleteComment(noticeId, doc.id),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: "Delete",
                              ),
                            ],
                          ),
                          Text(
                            c['text'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              DateFormat('MMM d, h:mm a').format(time),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // You can use actual user's name/email if you have session
    final currentUser = "admin";

    return Scaffold(
      backgroundColor: Colors.indigo[900],
      appBar: AppBar(
        title: const Text('Notices', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Notice Form
            Container(
              decoration: BoxDecoration(
                color: Colors.indigo[700],
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  _filePreview(),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file, color: Colors.white),
                        label: const Text('Attach File'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.publish, color: Colors.white),
                          label: _loading
                              ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ))
                              : const Text('Publish', style: TextStyle(color: Colors.white)),
                          onPressed: _loading ? null : _publishNotice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notices List
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
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No notices found.', style: TextStyle(color: Colors.white)));
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final notice = docs[index];
                      final rawTimestamp = notice['timestamp'];
                      final DateTime time = rawTimestamp is Timestamp
                          ? rawTimestamp.toDate()
                          : DateTime.tryParse(rawTimestamp.toString()) ?? DateTime.now();

                      final isExpanded = _expandedIndex == index;

                      return Card(
                        color: Colors.indigo[800],
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: Text(
                                notice['title'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              subtitle: Text(
                                "Posted: ${DateFormat.yMd().add_jm().format(time)}",
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _expandedIndex = isExpanded ? null : index;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.white70),
                                    onPressed: () => _editNotice(context, notice),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () => _deleteNotice(context, notice.id, notice['fileUrl']),
                                  ),
                                ],
                              ),
                            ),
                            if (isExpanded)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(notice['description'] ?? '', style: const TextStyle(color: Colors.white)),
                                    if ((notice['fileUrl'] ?? '').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: GestureDetector(
                                          onTap: () async {
                                            final url = notice['fileUrl'];
                                            if (await canLaunchUrl(Uri.parse(url))) {
                                              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Could not launch file link.")));
                                            }
                                          },
                                          child: Row(
                                            children: [
                                              Icon(Icons.attach_file, color: Colors.blue[100]),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  "View Attached File",
                                                  style: const TextStyle(
                                                      color: Colors.blueAccent,
                                                      decoration: TextDecoration.underline),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.comment, color: Colors.white),
                                        const SizedBox(width: 8),
                                        const Text('Comments', style: TextStyle(color: Colors.white)),
                                        const Spacer(),
                                        TextButton.icon(
                                          icon: const Icon(Icons.add_comment, color: Colors.white),
                                          label: const Text('Add', style: TextStyle(color: Colors.white)),
                                          onPressed: () => _addComment(notice.id, currentUser),
                                        )
                                      ],
                                    ),
                                    _buildComments(notice.id),
                                  ],
                                ),
                              ),
                          ],
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
    );
  }
}
