// lib/widgets/notice_2.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NoticeComposerDialog extends StatefulWidget {
  /// If null, avatar is resolved from FirebaseAuth or users/{email}.photoUrl
  final String? avatarUrl;

  /// If null, uses FirebaseAuth.currentUser?.displayName (fallback to email).
  final String? userName;

  /// Optional: scope for users/{email} lookup when avatarUrl is null.
  final String? userEmail;

  /// If provided, used directly; otherwise streamed from Firestore.
  final List<String>? categories;

  /// Firestore source for categories when [categories] is null.
  final String categoriesCollection; // default: 'notice_categories'
  final String categoryNameField;    // default: 'name'

  final Future<void> Function(String text, String? category) onPost;
  final VoidCallback onClose;
  final VoidCallback onAddMedia;

  const NoticeComposerDialog({
    super.key,
    this.userName,
    this.avatarUrl,
    this.userEmail,
    this.categories,
    this.categoriesCollection = 'notice_categories',
    this.categoryNameField = 'name',
    required this.onPost,
    required this.onClose,
    required this.onAddMedia,
  });

  @override
  State<NoticeComposerDialog> createState() => _NoticeComposerDialogState();
}

class _NoticeComposerDialogState extends State<NoticeComposerDialog> {
  static const _brandBlue = Color(0xFF1D5DF1);

  final _controller = TextEditingController();
  String? _category;
  bool _posting = false;

  String? _resolvedAvatar;
  late final String _resolvedEmail;
  late final String _resolvedUserName;

  @override
  void initState() {
    super.initState();
    final authUser = FirebaseAuth.instance.currentUser;
    _resolvedEmail = widget.userEmail ??
        authUser?.email ??
        '';
    _resolvedUserName = widget.userName ??
        authUser?.displayName ??
        authUser?.email ??
        'You';
    _loadAvatarIfNeeded();
  }

  Future<void> _loadAvatarIfNeeded() async {
    // If provided, take it.
    final passed = widget.avatarUrl?.trim() ?? '';
    if (passed.isNotEmpty) {
      setState(() => _resolvedAvatar = passed);
      return;
    }

    // Try FirebaseAuth first.
    final authUrl = FirebaseAuth.instance.currentUser?.photoURL?.trim() ?? '';
    if (authUrl.isNotEmpty) {
      setState(() => _resolvedAvatar = authUrl);
      return;
    }

    // Fallback: users/{email}.photoUrl
    if (_resolvedEmail.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_resolvedEmail)
        .get();
    final data = snap.data();
    final url = (data?['photoUrl'] ?? data?['avatar'] ?? '').toString().trim();
    if (url.isNotEmpty && mounted) {
      setState(() => _resolvedAvatar = url);
    }
  }

  Stream<List<String>> _categoriesStream() {
    if (widget.categories != null) {
      return Stream.value(widget.categories!);
    }
    return FirebaseFirestore.instance
        .collection(widget.categoriesCollection)
        .orderBy(widget.categoryNameField)
        .snapshots()
        .map((s) => s.docs
        .map((d) => (d.data()[widget.categoryNameField] ?? '').toString())
        .where((e) => e.trim().isNotEmpty)
        .toList());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canPost => _controller.text.trim().isNotEmpty && !_posting;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      // Tighter padding on phones
      final isPhone = constraints.maxWidth < 480;
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isPhone ? 12 : 24,
          vertical: isPhone ? 16 : 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            minHeight: isPhone ? 320 : 360,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    _Avatar(avatarUrl: _resolvedAvatar, email: _resolvedEmail),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _resolvedUserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Text area
                Flexible(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Write your post or question here',
                      filled: true,
                      fillColor: const Color(0xFFF1F3F6),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD5DBE7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD5DBE7)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Footer
                StreamBuilder<List<String>>(
                  stream: _categoriesStream(),
                  builder: (context, snap) {
                    final cats = snap.data ?? const <String>[];
                    // Wrap to avoid overflow; dropdown is width-constrained
                    return Row(
                      children: [
                        _ghostButton(
                          icon: Icons.perm_media_outlined,
                          label: 'Add media',
                          onTap: widget.onAddMedia,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _categoryDropdown(
                            categories: cats,
                            selected: _category,
                            onChanged: (v) => setState(() => _category = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                            ),
                            onPressed: _canPost
                                ? () async {
                              setState(() => _posting = true);
                              try {
                                await widget.onPost(_controller.text.trim(), _category);
                              } finally {
                                if (mounted) setState(() => _posting = false);
                              }
                            }
                                : null,
                            child: Text(_posting ? 'Posting…' : 'Post'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _categoryDropdown({
    required List<String> categories,
    required String? selected,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD5DBE7)),
        ),
        child: DropdownButton<String>(
          isExpanded: true,
          value: (selected != null && categories.contains(selected)) ? selected : null,
          hint: const Text(
            'Add Category',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down),
          items: categories
              .map((c) => DropdownMenuItem(
            value: c,
            child: Text(
              c,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ))
              .toList(),
          onChanged: onChanged,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
          dropdownColor: Colors.white,
        ),
      ),
    );
  }

  static Widget _ghostButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD5DBE7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.perm_media_outlined, size: 18, color: _brandBlue),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────── Helper: Avatar with graceful fallback ───────────────────────── */

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String email;
  const _Avatar({required this.avatarUrl, required this.email});

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromEmail(email);
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFE6EAF2),
        child: Text(
          initials,
          style: const TextStyle(
            color: Color(0xFF1D5DF1),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return CircleAvatar(radius: 18, backgroundImage: NetworkImage(avatarUrl!));
  }

  String _initialsFromEmail(String e) {
    if (e.isEmpty) return 'U';
    final left = e.split('@').first;
    final parts = left.split(RegExp(r'[._\- ]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return left.substring(0, 1).toUpperCase();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
