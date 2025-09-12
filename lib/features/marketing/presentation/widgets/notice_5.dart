// lib/widgets/notice_5.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommentsPanel extends StatefulWidget {
  /// The parent notice document id (collection: 'notices/{noticeId}/comments')
  final String noticeId;

  /// Current user metadata (used when posting). If null, we try FirebaseAuth.
  final String? meAvatarUrl;
  final String? meName;
  final String? meEmail;

  /// If you want to override Firestore posting, provide this.
  /// If null, this widget will write to:
  ///   notices/{noticeId}/comments
  final Future<void> Function(String text)? onPostComment;

  /// Page size for initial load + each "See more"
  final int pageSize;

  /// Optional: override the comments stream (must return newest-first).
  /// If provided, we ignore Firestore streaming below.
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? commentsStreamOverride;

  /// Optional: collection names if different in your app
  final String noticesCollection;
  final String commentsSubcollection;

  const CommentsPanel({
    super.key,
    required this.noticeId,
    this.meAvatarUrl,
    this.meName,
    this.meEmail,
    this.onPostComment,
    this.pageSize = 10,
    this.commentsStreamOverride,
    this.noticesCollection = 'notices',
    this.commentsSubcollection = 'comments',
  });

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  static const _brandBlue = Color(0xFF1D5DF1);

  final _controller = TextEditingController();
  bool _posting = false;

  /// Live (first page) subscription
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _liveSub;

  /// We keep a combined list (live first page + loaded older pages)
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _comments = [];

  /// For pagination (older pages are fetched with .get + startAfterDocument)
  DocumentSnapshot<Map<String, dynamic>>? _lastOlderDoc;
  bool _loadingMore = false;
  bool _hasMore = true;

  String get _resolvedEmail =>
      widget.meEmail ?? FirebaseAuth.instance.currentUser?.email ?? '';

  String get _resolvedName =>
      widget.meName ??
          (FirebaseAuth.instance.currentUser?.displayName ??
              FirebaseAuth.instance.currentUser?.email ??
              'User');

  String? get _resolvedAvatar => widget.meAvatarUrl;

  @override
  void initState() {
    super.initState();
    if (widget.commentsStreamOverride == null) {
      _bindLiveFirstPage();
    } else {
      _bindOverrideStream();
    }
  }

  void _bindOverrideStream() {
    // If a custom stream is provided, just listen and replace the list.
    widget.commentsStreamOverride!.listen((docs) {
      setState(() {
        _comments
          ..clear()
          ..addAll(docs);
        // When overriding, we don't know if there is more; expose "See more" via parent if needed.
        _hasMore = false;
      });
    });
  }

  void _bindLiveFirstPage() {
    final base = FirebaseFirestore.instance
        .collection(widget.noticesCollection)
        .doc(widget.noticeId)
        .collection(widget.commentsSubcollection);

    _liveSub = base
        .orderBy('timestamp', descending: true)
        .limit(widget.pageSize)
        .snapshots()
        .listen((snap) {
      // Replace the newest segment with live data while preserving older loaded pages.
      // Strategy: keep only items that are not older than the last live doc (by id set).
      final liveDocs = snap.docs;
      final liveIds = liveDocs.map((d) => d.id).toSet();

      // Remove any previous live items (those whose id is in liveIds)
      _comments.removeWhere((d) => liveIds.contains(d.id));

      // Insert latest live at the TOP (they are already newest-first)
      _comments.insertAll(0, liveDocs);

      // Update the "oldest among live" marker for future pagination startAfter
      if (liveDocs.isNotEmpty) {
        _lastOlderDoc = liveDocs.last;
      }

      // If live page is shorter than pageSize, there might be no more (but we’ll verify on first "See more" click).
      _hasMore = true;

      if (mounted) setState(() {});
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || widget.commentsStreamOverride != null) return;
    setState(() => _loadingMore = true);

    try {
      final base = FirebaseFirestore.instance
          .collection(widget.noticesCollection)
          .doc(widget.noticeId)
          .collection(widget.commentsSubcollection);

      Query<Map<String, dynamic>> q = base.orderBy('timestamp', descending: true).limit(widget.pageSize);

      if (_lastOlderDoc != null) {
        q = q.startAfterDocument(_lastOlderDoc!);
      }

      final older = await q.get();
      final docs = older.docs;

      if (docs.isEmpty) {
        _hasMore = false;
      } else {
        _comments.addAll(docs);
        _lastOlderDoc = docs.last;
        // If we got less than the page size, assume no more
        if (docs.length < widget.pageSize) _hasMore = false;
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _liveSub?.cancel();
    super.dispose();
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    final m = _mon[d.month];
    return '$m ${d.day}, ${d.year}';
  }

  static const _mon = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  Future<void> _postComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _posting = true);
    try {
      if (widget.onPostComment != null) {
        await widget.onPostComment!(text);
      } else {
        await FirebaseFirestore.instance
            .collection(widget.noticesCollection)
            .doc(widget.noticeId)
            .collection(widget.commentsSubcollection)
            .add({
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'authorEmail': _resolvedEmail,
          'authorName': _resolvedName,
          'avatarUrl': _resolvedAvatar ?? '',
          'likes': 0,
          // If you maintain reply count, keep it updated in write paths:
          'repliesCount': 0,
        });
      }
      _controller.clear();
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Composer (mobile-safe)
            LayoutBuilder(builder: (ctx, c) {
              final tight = c.maxWidth < 380;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundImage:
                    (_resolvedAvatar != null && _resolvedAvatar!.isNotEmpty)
                        ? NetworkImage(_resolvedAvatar!)
                        : null,
                    radius: 18,
                    child: (_resolvedAvatar == null || _resolvedAvatar!.isEmpty)
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD5DBE7)),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.symmetric(horizontal: tight ? 12 : 18),
                      ),
                      onPressed: _posting ? null : _postComment,
                      child: Text(_posting ? 'Posting…' : 'Post'),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Comments list (combined: live newest + older pages)
            ..._comments.map((doc) {
              final m = doc.data();
              final name = (m['authorName'] ?? m['authorEmail'] ?? 'User').toString();
              final avatar = (m['avatarUrl'] ?? '').toString();
              final text = (m['text'] ?? '').toString();
              final ts = m['timestamp'];
              final when = ts is Timestamp ? ts.toDate() : DateTime.now();
              final likes = (m['likes'] is num) ? (m['likes'] as num).toInt() : 0;
              final replies = (m['repliesCount'] is num) ? (m['repliesCount'] as num).toInt() : 0;

              return _CommentCard(
                author: name,
                avatarUrl: avatar,
                text: text,
                dateLabel: _dateLabel(when),
                likes: likes,
                replies: replies,
              );
            }),

            // See more
            if (_hasMore && widget.commentsStreamOverride == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: Text(_loadingMore ? 'Loading…' : 'See more comments'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────── Single comment row ───────────────────────── */

class _CommentCard extends StatelessWidget {
  final String author;
  final String avatarUrl;
  final String text;
  final String dateLabel;
  final int likes;
  final int replies;

  const _CommentCard({
    required this.author,
    required this.avatarUrl,
    required this.text,
    required this.dateLabel,
    required this.likes,
    required this.replies,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            radius: 16,
            child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE6EAF2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: Color(0xFF98A2B3),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: const TextStyle(height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.favorite_border, size: 16, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text('$likes', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      const SizedBox(width: 14),
                      const Icon(Icons.mode_comment_outlined, size: 16, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text('$replies', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
