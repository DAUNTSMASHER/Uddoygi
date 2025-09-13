// lib/features/marketing/presentation/screens/marketing_notice_screen.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:uddoygi/services/local_storage_service.dart';

// widgets generated earlier
import 'package:uddoygi/features/marketing/presentation/widgets/notice_1.dart'; // NoticeComposerBar (displayName + photoUrl)
import 'package:uddoygi/features/marketing/presentation/widgets/notice_2.dart'; // NoticeComposerDialog
import 'package:uddoygi/features/marketing/presentation/widgets/notice_3.dart'; // PostSettingsSheet (+ PostVisibility) -> we’ll call it “Notice settings” in UI
import 'package:uddoygi/features/marketing/presentation/widgets/notice_4.dart'; // CommentSettingsSheet (+ CommentPermission)
import 'package:uddoygi/features/marketing/presentation/widgets/notice_5.dart'; // CommentsPanel (noticeId version)
import 'package:uddoygi/features/marketing/presentation/widgets/notice_6.dart';

const _brandBlue = Color(0xFF0D47A1);

class FactoryNoticeScreen extends StatefulWidget {
  const FactoryNoticeScreen({super.key});

  @override
  State<FactoryNoticeScreen> createState() => _FactoryNoticeScreenState();
}

class _FactoryNoticeScreenState extends State<FactoryNoticeScreen> {
  // session
  String? userEmail;
  String? userName;

  // filters
  static const List<String> _departments = <String>[
    'All',
    'Marketing',
    'Sales',
    'HR',
    'Operations',
  ];
  String _dept = _departments.first;
  String _employee = 'All';

  // compose state
  List<_PickedFile> _pendingFiles = [];
  PostVisibility _visibility = PostVisibility.anyone;
  CommentPermission _commentPermission = CommentPermission.anyone;

  // collections
  static const _noticesColl = 'notices';
  static const _employeesColl = 'employees';
  static const _usersColl = 'users'; // real avatars like AllEmployeesPage

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    setState(() {
      userEmail = (session?['email'] as String?) ?? '';
      userName  = (session?['name'] as String?) ?? (session?['email'] as String? ?? '');
    });
  }

  /* ======================== Firestore helpers ======================== */

  /// Map email -> profile from `users` (real photo + name, same style as AllEmployeesPage)
  Stream<Map<String, _Profile>> _profilesStream() {
    return FirebaseFirestore.instance.collection(_usersColl).snapshots().map((s) {
      final map = <String, _Profile>{};
      for (final d in s.docs) {
        final m = d.data();
        final email = (m['officeEmail'] as String? ?? m['email'] as String? ?? '').toLowerCase();
        if (email.isEmpty) continue;
        map[email] = _Profile(
          email: email,
          name: (m['fullName'] as String?)?.trim() ?? email,
          photoUrl: (m['profilePhotoUrl'] as String?)?.trim() ?? '',
          department: (m['department'] as String?) ?? '',
          role: (m['designation'] as String?) ?? '',
        );
      }
      return map;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _noticesStream() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(_noticesColl);
    if (_dept != 'All') {
      q = q.where('department', isEqualTo: _dept);
    }
    if (_employee != 'All') {
      q = q.where('publishedByEmail', isEqualTo: _employee);
    }
    return q.orderBy('timestamp', descending: true).snapshots();
  }

  /// Employee dropdown source
  Stream<List<_Employee>> _employeesStream() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(_employeesColl);
    if (_dept != 'All') q = q.where('department', isEqualTo: _dept);
    return q.snapshots().map((s) {
      final list = s.docs
          .map((d) => _Employee(
        name: (d.data()['name'] as String?) ??
            (d.data()['email'] as String? ?? 'Unknown'),
        email: (d.data()['email'] as String?) ?? '',
        department: (d.data()['department'] as String?) ?? '',
      ))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  Future<List<_UploadedFile>> _uploadPendingFiles(String noticeId) async {
    final storage = FirebaseStorage.instance;
    final List<_UploadedFile> uploaded = [];
    for (final f in _pendingFiles) {
      final path =
          'notices/$noticeId/files/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
      final ref = storage.ref(path);
      final task =
      await ref.putData(f.bytes, SettableMetadata(contentType: f.mime));
      final url = await task.ref.getDownloadURL();
      uploaded.add(_UploadedFile(name: f.name, url: url));
    }
    return uploaded;
  }

  /* ======================== Composer actions ======================== */

  Future<void> _pickComposerFiles() async {
    final result = await FilePicker.platform
        .pickFiles(withData: true, allowMultiple: true);
    if (result == null) return;
    setState(() {
      _pendingFiles = result.files
          .where((x) => x.bytes != null)
          .map((x) => _PickedFile(
        name: x.name,
        bytes: x.bytes!,
        mime: x.mimeType ?? 'application/octet-stream',
      ))
          .toList();
    });
  }

  Future<void> _openPostSettings() async {
    await showDialog(
      context: context,
      builder: (_) => PostSettingsSheet(
        initial: _visibility,
        onOpenCommentSettings: () async {
          Navigator.pop(context);
          await showDialog(
            context: context,
            builder: (_) => CommentSettingsSheet(
              initial: _commentPermission,
              onDone: (perm) => setState(() => _commentPermission = perm),
            ),
          );
        },
        onDone: (vis) => setState(() => _visibility = vis),
      ),
    );
  }

  Future<void> _startCompose() async {
    final pickedBefore = List<_PickedFile>.from(_pendingFiles);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NoticeComposerDialog(
        userName: userName ?? 'Me',
        // this dialog only needs an avatar image; fallback is fine
        avatarUrl: _avatarFallback(userEmail),
        categories: _departments.where((d) => d != 'All').toList(),
        onAddMedia: _pickComposerFiles,
        onClose: () {
          _pendingFiles = pickedBefore; // restore
          Navigator.pop(context);
        },
        onPost: (text, category) async {
          final deptForPost = category ?? (_dept == 'All' ? 'Marketing' : _dept);
          final now = Timestamp.now();
          final doc =
          FirebaseFirestore.instance.collection(_noticesColl).doc();
          final noticeData = {
            'title': _deriveTitle(text),
            'description': text,
            'department': deptForPost,
            'timestamp': now,
            'publishedByName': userName ?? '',
            'publishedByEmail': userEmail ?? '',
            'visibility': _visibility.name,
            'commentPermission': _commentPermission.name,
            'files': [],
          };
          await doc.set(noticeData);
          if (_pendingFiles.isNotEmpty) {
            final uploaded = await _uploadPendingFiles(doc.id);
            await doc.update({
              'files':
              uploaded.map((u) => {'name': u.name, 'url': u.url}).toList(),
            });
          }
          setState(() => _pendingFiles = []);
          Navigator.pop(context);
        },
      ),
    );
  }

  /* ======================== UI ======================== */

  @override
  Widget build(BuildContext context) {
    final myEmail = (userEmail ?? '').toLowerCase();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brandBlue,     // blue background
        foregroundColor: Colors.white,   // makes title & icons white
        elevation: 0,
        title: const Text(
          'Notices',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Notice settings',
            onPressed: _openPostSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),

      // Bind profiles once, then build the rest using that map (real photos & names)
      body: StreamBuilder<Map<String, _Profile>>(
        stream: _profilesStream(),
        builder: (context, profileSnap) {
          final profiles = profileSnap.data ?? const <String, _Profile>{};
          final me = profiles[myEmail];
          final meAvatar = (me != null && me.photoUrl.isNotEmpty)
              ? me.photoUrl
              : null;
          final meName = me?.name ?? (userName ?? myEmail);

          return Column(
            children: [
              // Composer bar — wording changed to “notice”
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: NoticeComposerBar(
                  displayName: meName,
                  photoUrl: meAvatar,
                  hintText: 'Ask a question or start a notice',
                  categories: _departments.where((d) => d != 'All').toList(),
                  selectedCategory: _dept == 'All' ? null : _dept,
                  onCategoryChanged: (v) => setState(() {
                    _dept = v ?? 'All';
                    _employee = 'All';
                  }),
                  onAddMedia: _pickComposerFiles,
                  onStartCompose: _startCompose,
                ),
              ),

              // Filters row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    _FilterDropdown<String>(
                      label: 'Department',
                      value: _dept,
                      items: _departments,
                      onChanged: (v) => setState(() {
                        _dept = v!;
                        _employee = 'All';
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<List<_Employee>>(
                        stream: _employeesStream(),
                        builder: (_, snap) {
                          final employees =
                              snap.data ?? const <_Employee>[];
                          final items = <String>[
                            'All',
                            ...employees
                                .map((e) => e.email)
                                .where((e) => e.isNotEmpty)
                          ];
                          return _FilterDropdown<String>(
                            label: 'Employee',
                            value: _employee,
                            items: items,
                            displayBuilder: (v) {
                              if (v == 'All') return 'All';
                              final match = employees.firstWhere(
                                    (e) =>
                                e.email.toLowerCase() ==
                                    (v ?? '').toLowerCase(),
                                orElse: () => _Employee(
                                    name: v ?? '', email: v ?? '', department: ''),
                              );
                              return match.name;
                            },
                            onChanged: (v) =>
                                setState(() => _employee = v!),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Notices stream (uses real profiles for photo/name)
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _noticesStream(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text('No notices found.'));
                    }
                    return ListView.separated(
                      padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemBuilder: (_, i) => _NoticeCard(
                        doc: docs[i],
                        profiles: profiles,
                        meEmail: myEmail,
                        meName: meName,
                        meAvatarUrl: meAvatar ?? _avatarFallback(myEmail),
                        onOpenFile: _openFile,
                      ),
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                      itemCount: docs.length,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _deriveTitle(String text) {
    final s = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return 'New notice'; // renamed from New post
    return (s.length <= 60) ? s : '${s.substring(0, 57)}...';
  }

  String _avatarFallback(String? email) {
    final ix = (email ?? 'a').hashCode.abs() % 50 + 1;
    return 'https://i.pravatar.cc/150?img=$ix';
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }
}

extension on PlatformFile {
  get mimeType => null; // not used here; kept for compatibility
}

/* ======================== Widgets: notice card (uses real profiles) ======================== */

class _NoticeCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, _Profile> profiles;
  final String meEmail;
  final String meName;
  final String meAvatarUrl;
  final Future<void> Function(String url) onOpenFile;

  const _NoticeCard({
    required this.doc,
    required this.profiles,
    required this.meEmail,
    required this.meName,
    required this.meAvatarUrl,
    required this.onOpenFile,
  });

  @override
  Widget build(BuildContext context) {
    final d = doc.data() ?? {};
    final title = (d['title'] as String?) ?? '';
    final desc = (d['description'] as String?) ?? '';
    final department = (d['department'] as String?) ?? '';
    final authorEmail = (d['publishedByEmail'] as String? ?? '').toLowerCase();
    final authorProfile = profiles[authorEmail];
    final authorNameFromDoc = (d['publishedByName'] as String?)?.trim();
    final displayAuthor = (authorNameFromDoc?.isNotEmpty ?? false)
        ? authorNameFromDoc!
        : (authorProfile?.name ?? (authorEmail.isNotEmpty ? authorEmail : 'Admin'));
    final authorPhoto = authorProfile?.photoUrl ?? '';

    final time = (d['timestamp'] is Timestamp)
        ? (d['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    final files = (d['files'] as List?)?.cast<Map>() ?? const [];

    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header (avatar like AllEmployeesPage: initials fallback)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _brandBlue,
                  backgroundImage: authorPhoto.isNotEmpty ? NetworkImage(authorPhoto) : null,
                  child: authorPhoto.isEmpty
                      ? Text(
                    _initials(displayAuthor),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                _DeptChip(label: department),
              ],
            ),

            if (desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(desc),
            ],

            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'By $displayAuthor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(time),
                  style: const TextStyle(color: Colors.black45),
                ),
                if ((authorProfile?.role ?? '').isNotEmpty)
                  Text(
                    '• ${authorProfile!.role}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black45),
                  ),
              ],
            ),

            if (files.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 20),
              const Text('Attachments', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ...files.map((m) {
                final name = (m['name']?.toString() ?? 'file');
                final url = (m['url']?.toString() ?? '');
                final isImage = _looksLikeImage(name);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: isImage
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      url,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported, size: 24),
                    ),
                  )
                      : const Icon(Icons.attach_file),
                  title: Text(name, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () => onOpenFile(url),
                  ),
                  onTap: () => onOpenFile(url),
                );
              }),
            ],

            const Divider(height: 20),

            // Compact comments (Facebook-style): minimize footprint on the card
            _CompactComments(
              noticeId: doc.id,
              meAvatarUrl: meAvatarUrl,
              meName: meName,
              meEmail: meEmail,
            ),
          ],
        ),
      ),
    );
  }

  bool _looksLikeImage(String filename) {
    final f = filename.toLowerCase();
    return f.endsWith('.jpg') ||
        f.endsWith('.jpeg') ||
        f.endsWith('.png') ||
        f.endsWith('.gif') ||
        f.endsWith('.webp');
  }
}

class _DeptChip extends StatelessWidget {
  final String label;
  const _DeptChip({required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD5DBE7)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/* ======================== Compact comments widget ======================== */

class _CompactComments extends StatelessWidget {
  final String noticeId;
  final String meAvatarUrl;
  final String meName;
  final String meEmail;

  const _CompactComments({
    required this.noticeId,
    required this.meAvatarUrl,
    required this.meName,
    required this.meEmail,
  });

  @override
  Widget build(BuildContext context) {
    final commentsRef = FirebaseFirestore.instance
        .collection('notices')
        .doc(noticeId)
        .collection('comments');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: commentsRef.snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;

        return Column(
          children: [
            // Write a comment (opens full panel)
            Row(
              children: [
                CircleAvatar(radius: 16, backgroundImage: NetworkImage(meAvatarUrl)),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _openFullComments(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 40,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD5DBE7)),
                      ),
                      child: const Text(
                        'Write a comment…',
                        style: TextStyle(color: Color(0xFF98A2B3), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _openFullComments(context),
                  icon: const Icon(Icons.mode_comment_outlined),
                  label: Text(count == 0 ? 'Comments' : 'Comments ($count)'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _openFullComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: CommentsPanel(
            noticeId: noticeId,
            meAvatarUrl: meAvatarUrl,
            meName: meName,
            meEmail: meEmail,
          ),
        ),
      ),
    );
  }
}

/* ======================== small helpers ======================== */

class _PickedFile {
  final String name;
  final Uint8List bytes;
  final String mime;
  _PickedFile({required this.name, required this.bytes, required this.mime});
}

class _UploadedFile {
  final String name;
  final String url;
  _UploadedFile({required this.name, required this.url});
}

class _Employee {
  final String name;
  final String email;
  final String department;
  _Employee({required this.name, required this.email, required this.department});
}

class _Profile {
  final String email;
  final String name;
  final String photoUrl;
  final String department;
  final String role;
  _Profile({
    required this.email,
    required this.name,
    required this.photoUrl,
    required this.department,
    required this.role,
  });
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T)? displayBuilder;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.displayBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD5DBE7)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isDense: true,
          value: value,
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
              value: e,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  displayBuilder?.call(e) ?? e.toString(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Same helper you used in AllEmployeesPage (initials if no photo)
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
