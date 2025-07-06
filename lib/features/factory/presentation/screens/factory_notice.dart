import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class FactoryNoticeScreen extends StatefulWidget {
  const FactoryNoticeScreen({super.key});

  @override
  State<FactoryNoticeScreen> createState() => _FactoryNoticeScreenState();
}

class _FactoryNoticeScreenState extends State<FactoryNoticeScreen> {
  String? userEmail;
  String? userName;
  String? expandedId;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final session = await LocalStorageService.getSession();
    setState(() {
      userEmail = (session != null && session['email'] != null) ? session['email'] : '';
      userName = (session != null && session['name'] != null)
          ? session['name']
          : (session != null && session['email'] != null ? session['email'] : '');
    });
  }

  Future<void> _addComment(String noticeId) async {
    final commentController = TextEditingController();
    FilePickerResult? result;
    String? fileUrl, fileName;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.indigo[700],
        title: const Text('Add Comment', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (ctx, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: commentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.attach_file, color: Colors.white),
                label: Text(fileName ?? 'Attach File', style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () async {
                  result = await FilePicker.platform.pickFiles();
                  if (result != null) {
                    setStateDialog(() {
                      fileName = result!.files.single.name;
                    });
                  }
                },
              ),
              if (fileName != null)
                Text(fileName!, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              String? uploadedUrl;
              if (result != null && result!.files.single.bytes != null) {
                final ref = FirebaseStorage.instance
                    .ref('notices/$noticeId/comments/${DateTime.now().millisecondsSinceEpoch}_${result!.files.single.name}');
                final uploadTask = await ref.putData(result!.files.single.bytes!);
                uploadedUrl = await uploadTask.ref.getDownloadURL();
              }
              await FirebaseFirestore.instance
                  .collection('notices')
                  .doc(noticeId)
                  .collection('comments')
                  .add({
                'text': commentController.text.trim(),
                'timestamp': Timestamp.now(),
                'authorEmail': userEmail,
                'authorName': userName,
                'fileUrl': uploadedUrl ?? "",
                'fileName': fileName ?? "",
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file')),
      );
    }
  }

  Future<void> _deleteComment(String noticeId, String commentId) async {
    await FirebaseFirestore.instance
        .collection('notices')
        .doc(noticeId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  Future<void> _editComment(String noticeId, String commentId, String initialText) async {
    final controller = TextEditingController(text: initialText);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.indigo[700],
        title: const Text('Edit Comment', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Comment', labelStyle: TextStyle(color: Colors.white)),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('notices')
                  .doc(noticeId)
                  .collection('comments')
                  .doc(commentId)
                  .update({'text': controller.text.trim()});
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
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
            padding: EdgeInsets.only(top: 8),
            child: Text("No comments yet.", style: TextStyle(color: Colors.white70)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: docs.map((doc) {
            final comment = doc.data() as Map<String, dynamic>;
            final author = comment['authorName'] ?? comment['authorEmail'] ?? 'User';
            final text = comment['text'] ?? '';
            final fileUrl = comment['fileUrl'] ?? '';
            final fileName = comment['fileName'] ?? '';
            final ts = comment['timestamp'];
            final time = ts is Timestamp ? ts.toDate() : DateTime.now();
            return Container(
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: Colors.indigo[600],
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                leading: const Icon(Icons.comment, color: Colors.white70),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        author,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, h:mm a').format(time),
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                        child: Text(
                          text,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    if (fileUrl.isNotEmpty)
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.attach_file, color: Colors.white70, size: 18),
                            label: Text(
                              fileName,
                              style: const TextStyle(color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () => _openFile(fileUrl),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.only(left: 0),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download, color: Colors.white54, size: 20),
                            tooltip: 'Download',
                            onPressed: () => _openFile(fileUrl),
                          ),
                        ],
                      ),
                  ],
                ),
                trailing: (comment['authorEmail'] == userEmail)
                    ? PopupMenuButton<String>(
                  color: Colors.white,
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editComment(noticeId, doc.id, text);
                    } else if (value == 'delete') {
                      _deleteComment(noticeId, doc.id);
                    }
                  },
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildNoticeCard(DocumentSnapshot notice) {
    final data = notice.data() as Map<String, dynamic>;
    final id = notice.id;
    final isExpanded = expandedId == id;
    final timestamp = data['timestamp'];
    final time = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
    final files = data['files'] as List<dynamic>? ?? [];

    return Card(
      color: Colors.indigo[900],
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => setState(() => expandedId = isExpanded ? null : id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign, color: Colors.blueAccent[100]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                    ),
                  ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white70),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 10),
                Text(data['description'] ?? '', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Text('Published by: ${data['publishedBy'] ?? 'Admin'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Text(DateFormat('MMM d, yyyy – hh:mm a').format(time),
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                if (files.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text("Attachments:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ...files.map((file) => ListTile(
                    leading: const Icon(Icons.attach_file, color: Colors.white70),
                    title: Text(
                      file['name'] ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onTap: () => _openFile(file['url']),
                    trailing: IconButton(
                      icon: const Icon(Icons.download, color: Colors.white54),
                      onPressed: () => _openFile(file['url']),
                    ),
                  )),
                ],
                const Divider(color: Colors.white24, height: 20),
                _buildComments(id),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () => _addComment(id),
                    icon: const Icon(Icons.comment, color: Colors.white),
                    label: const Text('Add Comment', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[800],
      appBar: AppBar(
        backgroundColor: Colors.indigo[900],
        title: const Text('Factory Notices', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: userEmail == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No notices found.', style: TextStyle(color: Colors.white70)),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: docs.map((notice) => _buildNoticeCard(notice)).toList(),
          );
        },
      ),
    );
  }
}
