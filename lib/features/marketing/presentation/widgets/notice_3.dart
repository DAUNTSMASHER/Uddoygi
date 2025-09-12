// lib/widgets/notice_3.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum PostVisibility { anyone, followers, onlyMe }

class PostSettingsSheet extends StatefulWidget {
  /// The currently selected visibility to show on open.
  final PostVisibility initial;

  /// Opens the separate comment-permissions sheet.
  final VoidCallback onOpenCommentSettings;

  /// Returns the chosen visibility when the user taps Done.
  final ValueChanged<PostVisibility> onDone;

  /// If true, we read & write the chosen visibility to Firestore:
  /// {settingsCollection}/{userEmail}.visibility
  final bool persistToFirestore;

  /// The collection to store per-user settings. Default: "user_settings".
  final String settingsCollection;

  /// If null, uses FirebaseAuth.currentUser?.email
  final String? userEmail;

  const PostSettingsSheet({
    super.key,
    required this.initial,
    required this.onOpenCommentSettings,
    required this.onDone,
    this.persistToFirestore = false,
    this.settingsCollection = 'user_settings',
    this.userEmail,
  });

  @override
  State<PostSettingsSheet> createState() => _PostSettingsSheetState();
}

class _PostSettingsSheetState extends State<PostSettingsSheet> {
  static const _brandBlue = Color(0xFF1D5DF1);

  PostVisibility _vis = PostVisibility.anyone;
  bool _loading = false;
  String _error = '';

  late final String _resolvedEmail;

  @override
  void initState() {
    super.initState();
    _vis = widget.initial;
    _resolvedEmail =
        widget.userEmail ?? FirebaseAuth.instance.currentUser?.email ?? '';

    if (widget.persistToFirestore && _resolvedEmail.isNotEmpty) {
      _loadFromFirestore();
    }
  }

  Future<void> _loadFromFirestore() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection(widget.settingsCollection)
          .doc(_resolvedEmail)
          .get();

      final data = doc.data() ?? {};
      final saved = (data['visibility'] ?? '').toString();
      final parsed = _stringToVis(saved);
      if (parsed != null && mounted) {
        setState(() => _vis = parsed);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load your notice settings.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveToFirestore(PostVisibility v) async {
    if (!widget.persistToFirestore || _resolvedEmail.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection(widget.settingsCollection)
          .doc(_resolvedEmail)
          .set(
        {
          'visibility': _visToString(v),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Silent fail on save; UX still proceeds.
    }
  }

  String _visToString(PostVisibility v) {
    switch (v) {
      case PostVisibility.anyone:
        return 'anyone';
      case PostVisibility.followers:
        return 'followers';
      case PostVisibility.onlyMe:
        return 'onlyMe';
    }
  }

  PostVisibility? _stringToVis(String s) {
    switch (s) {
      case 'anyone':
        return PostVisibility.anyone;
      case 'followers':
        return PostVisibility.followers;
      case 'onlyMe':
        return PostVisibility.onlyMe;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title row
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notice Settings', // renamed from "Post Settings"
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                _labelChip('Who can see your notices?'),

                const SizedBox(height: 8),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  _radioTile(
                    value: PostVisibility.anyone,
                    label: 'Anyone',
                    subtitle: 'Visible to all users',
                    icon: Icons.public,
                  ),
                  _radioTile(
                    value: PostVisibility.followers,
                    label: 'Your followers only',
                    subtitle: 'Only your followers can see',
                    icon: Icons.group_outlined,
                  ),
                  _radioTile(
                    value: PostVisibility.onlyMe,
                    label: 'Only me',
                    subtitle: 'Private to you',
                    icon: Icons.lock_outline,
                  ),
                ],

                const SizedBox(height: 8),
                _navTile(
                  'Who can comment?',
                  Icons.question_answer_outlined,
                  widget.onOpenCommentSettings,
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await _saveToFirestore(_vis);
                        widget.onDone(_vis);
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _labelChip(String s) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        s,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _radioTile({
    required PostVisibility value,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _vis == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _vis = value),
      child: Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD5DBE7)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '$label\n',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: subtitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Radio<PostVisibility>(
              value: value,
              groupValue: _vis,
              activeColor: _brandBlue,
              onChanged: (v) => setState(() => _vis = v ?? _vis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTile(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 52,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD5DBE7)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
