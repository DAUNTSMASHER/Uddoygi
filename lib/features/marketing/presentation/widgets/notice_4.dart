// lib/widgets/notice_4.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum CommentPermission { anyone, followers, nobody }

class CommentSettingsSheet extends StatefulWidget {
  final CommentPermission initial;
  final ValueChanged<CommentPermission> onDone;

  /// Optional: persist the choice in Firestore (default: false).
  final bool persistToFirestore;

  /// Collection where the per-user setting is stored (doc id = email).
  /// Default: "user_settings"
  final String settingsCollection;

  /// If null, we’ll use FirebaseAuth.currentUser?.email
  final String? userEmail;

  const CommentSettingsSheet({
    super.key,
    required this.initial,
    required this.onDone,
    this.persistToFirestore = false,
    this.settingsCollection = 'user_settings',
    this.userEmail,
  });

  @override
  State<CommentSettingsSheet> createState() => _CommentSettingsSheetState();
}

class _CommentSettingsSheetState extends State<CommentSettingsSheet> {
  static const _brandBlue = Color(0xFF1D5DF1);

  CommentPermission _perm = CommentPermission.anyone;
  bool _loading = false;
  late final String _resolvedEmail;

  @override
  void initState() {
    super.initState();
    _perm = widget.initial;
    _resolvedEmail =
        widget.userEmail ?? FirebaseAuth.instance.currentUser?.email ?? '';

    if (widget.persistToFirestore && _resolvedEmail.isNotEmpty) {
      _loadFromFirestore();
    }
  }

  Future<void> _loadFromFirestore() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection(widget.settingsCollection)
          .doc(_resolvedEmail)
          .get();
      final data = doc.data() ?? {};
      final saved = (data['commentPermission'] ?? '').toString();
      final parsed = _stringToPerm(saved);
      if (parsed != null && mounted) {
        setState(() => _perm = parsed);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveToFirestore(CommentPermission p) async {
    if (!widget.persistToFirestore || _resolvedEmail.isEmpty) return;
    final map = {
      'commentPermission': _permToString(p),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance
        .collection(widget.settingsCollection)
        .doc(_resolvedEmail)
        .set(map, SetOptions(merge: true));
  }

  String _permToString(CommentPermission p) {
    switch (p) {
      case CommentPermission.anyone:
        return 'anyone';
      case CommentPermission.followers:
        return 'followers';
      case CommentPermission.nobody:
        return 'nobody';
    }
  }

  CommentPermission? _stringToPerm(String s) {
    switch (s) {
      case 'anyone':
        return CommentPermission.anyone;
      case 'followers':
        return CommentPermission.followers;
      case 'nobody':
        return CommentPermission.nobody;
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
                // Header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Comment Settings',
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
                _labelChip('Who can comment on this post?'),
                const SizedBox(height: 8),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _radioTile(
                    value: CommentPermission.anyone,
                    label: 'Anyone',
                    subtitle: 'All users can comment',
                    icon: Icons.public,
                  ),
                  _radioTile(
                    value: CommentPermission.followers,
                    label: 'Your followers only',
                    subtitle: 'Only your followers can comment',
                    icon: Icons.group_outlined,
                  ),
                  _radioTile(
                    value: CommentPermission.nobody,
                    label: 'Nobody',
                    subtitle: 'Comments are disabled',
                    icon: Icons.block_outlined,
                  ),
                ],

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
                        await _saveToFirestore(_perm);
                        widget.onDone(_perm);
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
    required CommentPermission value,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _perm == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _perm = value),
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
            Radio<CommentPermission>(
              value: value,
              groupValue: _perm,
              activeColor: _brandBlue,
              onChanged: (v) => setState(() => _perm = v ?? _perm),
            ),
          ],
        ),
      ),
    );
  }
}
