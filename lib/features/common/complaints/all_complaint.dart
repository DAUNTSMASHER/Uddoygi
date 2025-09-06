import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AllComplaintScreen extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String? role;

  const AllComplaintScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    this.role,
  });

  @override
  State<AllComplaintScreen> createState() => _AllComplaintScreenState();
}

class _AllComplaintScreenState extends State<AllComplaintScreen> {
  // Filters & UI state
  String _statusFilter = 'all';
  String _searchText = '';
  String _actionTypeFilter = 'all'; // used inside details too
  bool _sortDesc = true;

  final _searchController = TextEditingController();

  final List<String> _statusOptions = ['all', 'pending', 'resolved', 'forwarded', 'closed'];
  final List<String> _actionTypes   = ['all', 'note', 'punishment', 'reward', 'warning', 'forwarded', 'closed', 'pending'];

  // Palette (aligned with your other screens)
  static const Color _brandTeal  = Color(0xFF001863);
  static const Color _indigoCard = Color(0xFF0B2D9F);
  static const Color _surface    = Color(0xFFF4FBFB);
  static const Color _boardDark  = Color(0xFF0330AE);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /* ====================== Data / Streams ====================== */

  Stream<QuerySnapshot<Map<String, dynamic>>> _complaintsStream() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('complaints')
        .orderBy('timestamp', descending: true);

    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }

    if (widget.role != "hr" && widget.role != "admin") {
      q = q.where('submittedBy', isEqualTo: widget.userEmail);
    }

    return q.snapshots();
  }

  /* ====================== Helpers ====================== */

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) return DateFormat('MMM d, h:mm a').format(ts.toDate());
    if (ts is DateTime)  return DateFormat('MMM d, h:mm a').format(ts);
    return '—';
  }

  DateTime _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.fromMillisecondsSinceEpoch(0);
    // String/other -> epoch start to keep sort stable
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':  return Colors.green;
      case 'pending':   return Colors.orange;
      case 'forwarded': return Colors.indigo;
      case 'closed':    return Colors.grey;
      default:          return Colors.blueGrey;
    }
  }

  Widget _statusChip(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final q = _searchText.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool contains(Object? v) => v != null && v.toString().toLowerCase().contains(q);

    return contains(data['subject']) ||
        contains(data['message']) ||
        contains(data['submittedByName']) ||
        contains(data['submittedBy']) ||
        contains(data['department']) ||
        contains(data['against']);
  }

  /* ====================== Detail Sheet ====================== */

  void _showComplaintDetail(Map<String, dynamic> data, String docId) {
    final List rawHistory = (data['resolutionHistory'] ?? []) as List;

    // Filter by action type and sort by timestamp/editedAt (desc)
    final filteredHistory = rawHistory.where((entry) {
      final t = (entry['type'] ?? '').toString().toLowerCase();
      return _actionTypeFilter == 'all' || t == _actionTypeFilter;
    }).toList()
      ..sort((a, b) {
        final dtB = _toDate(b['editedAt'] ?? b['timestamp']);
        final dtA = _toDate(a['editedAt'] ?? a['timestamp']);
        return dtB.compareTo(dtA); // desc
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          maxChildSize: 0.96,
          minChildSize: 0.5,
          builder: (_, controller) => SingleChildScrollView(
            controller: controller,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          data['subject']?.toString().isNotEmpty == true
                              ? data['subject']
                              : '(No Subject)',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900, color: Colors.indigo),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip((data['status'] ?? 'pending').toString()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if ((data['message'] ?? '').toString().isNotEmpty)
                    Text(data['message'], style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 12),

                  // Meta chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metaChip(Icons.person, data['submittedByName'] ?? widget.userName),
                      _metaChip(Icons.email, data['submittedBy'] ?? ''),
                      _metaChip(Icons.apartment, data['department'] ?? ''),
                      if ((data['against'] ?? '').toString().isNotEmpty)
                        _metaChip(Icons.badge, 'Against: ${data['against']}'),
                      _metaChip(Icons.schedule, _fmtTs(data['timestamp'])),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.filter_alt, size: 18),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _actionTypeFilter,
                        items: _actionTypes
                            .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                            .toList(),
                        onChanged: (val) => setState(() => _actionTypeFilter = val!),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const Divider(height: 24),

                  if (filteredHistory.isEmpty)
                    const Text('No actions recorded.',
                        style: TextStyle(fontStyle: FontStyle.italic)),

                  if (filteredHistory.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, i) {
                        final entry = filteredHistory[i] as Map;
                        final type = (entry['type'] ?? 'note').toString();
                        final note = (entry['note'] ?? '').toString();
                        final by   = (entry['by'] ?? '').toString();
                        final ts   = entry['editedAt'] ?? entry['timestamp'];
                        final dateStr = _fmtTs(ts);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.withOpacity(.12),
                              child: Icon(_actionIcon(type), color: Colors.indigo),
                            ),
                            title: Text(
                              '${type.toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'By: $by\n$note',
                                style: const TextStyle(height: 1.3),
                              ),
                            ),
                            isThreeLine: true,
                            trailing: (widget.role == 'hr' || widget.role == 'admin')
                                ? IconButton(
                              tooltip: 'Edit note',
                              icon: const Icon(Icons.edit, color: Colors.indigo),
                              onPressed: () => _editHistoryEntry(docId, rawHistory, i, entry),
                            )
                                : null,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _actionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'punishment': return Icons.gavel;
      case 'reward':     return Icons.emoji_events;
      case 'warning':    return Icons.warning_amber_rounded;
      case 'forwarded':  return Icons.forward_to_inbox;
      case 'closed':     return Icons.lock;
      case 'pending':    return Icons.timelapse;
      default:           return Icons.sticky_note_2_outlined;
    }
  }

  void _editHistoryEntry(String docId, List history, int index, Map entry) {
    final controller = TextEditingController(text: (entry['note'] ?? '').toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Action Note'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Update note…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () async {
              history[index]['note'] = controller.text.trim();
              history[index]['editedAt'] = Timestamp.now();
              await FirebaseFirestore.instance.collection('complaints').doc(docId).update({
                'resolutionHistory': history,
              });
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Action updated')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /* ====================== UI ====================== */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Complaints', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: _brandTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _sortDesc ? 'Newest first' : 'Oldest first',
            icon: const Icon(Icons.sort),
            onPressed: () => setState(() => _sortDesc = !_sortDesc),
          ),
          PopupMenuButton<String>(
            tooltip: 'Filter status',
            icon: const Icon(Icons.filter_alt),
            onSelected: (v) => setState(() => _statusFilter = v),
            itemBuilder: (context) => _statusOptions
                .map((e) => PopupMenuItem(value: e, child: Text(e.toUpperCase())))
                .toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchText = val),
              decoration: InputDecoration(
                hintText: 'Search subject, message, name, email, dept…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _complaintsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // All docs from stream
          final docs = snapshot.data!.docs;

          // Summary counts (from stream, before search)
          int total = docs.length, p = 0, r = 0, f = 0, c = 0;
          for (final d in docs) {
            final st = (d.data()['status'] ?? 'pending').toString().toLowerCase();
            if (st == 'pending') p++;
            else if (st == 'resolved') r++;
            else if (st == 'forwarded') f++;
            else if (st == 'closed') c++;
          }

          // Search filter (client-side)
          final filtered = docs.where((d) => _matchesSearch(d.data())).toList()
            ..sort((a, b) {
              final dtA = _toDate(a.data()['timestamp']);
              final dtB = _toDate(b.data()['timestamp']);
              return _sortDesc ? dtB.compareTo(dtA) : dtA.compareTo(dtB);
            });

          if (filtered.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _overviewBoard(total: total, pending: p, resolved: r, forwarded: f, closed: c),
                const SizedBox(height: 16),
                _emptyState(),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: filtered.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  children: [
                    _overviewBoard(total: total, pending: p, resolved: r, forwarded: f, closed: c),
                    const SizedBox(height: 16),
                    _quickStatusChips(), // handy chips under board
                    const SizedBox(height: 12),
                  ],
                );
              }

              final doc  = filtered[i - 1];
              final data = doc.data();
              final time = _toDate(data['timestamp']);
              final subject = (data['subject'] ?? '(No Subject)').toString();
              final message = (data['message'] ?? '').toString();
              final status  = (data['status']  ?? 'pending').toString();
              final dept    = (data['department'] ?? '').toString();
              final against = (data['against'] ?? '').toString();
              final byName  = (data['submittedByName'] ?? '').toString();
              final byEmail = (data['submittedBy'] ?? '').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showComplaintDetail(data, doc.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header gradient
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                          gradient: LinearGradient(
                            colors: [_indigoCard, Color(0xFF1D5DF1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                            _statusChip(status),
                          ],
                        ),
                      ),

                      // Body
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.isNotEmpty)
                              Text(
                                message,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, height: 1.35),
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (dept.isNotEmpty) _metaChip(Icons.apartment, dept),
                                if (against.isNotEmpty) _metaChip(Icons.badge, 'Against: $against'),
                                _metaChip(Icons.person, byName.isNotEmpty ? byName : '(unknown)'),
                                if (byEmail.isNotEmpty) _metaChip(Icons.email, byEmail),
                                _metaChip(Icons.schedule, _fmtTs(time)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /* ====================== Pieces ====================== */

  Widget _overviewBoard({
    required int total,
    required int pending,
    required int resolved,
    required int forwarded,
    required int closed,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(color: _boardDark, borderRadius: BorderRadius.circular(20)),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final tileW = (w - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: tileW, child: _squareStat('Total Complaints', '$total', Icons.list_alt)),
            SizedBox(width: tileW, child: _squareStat('Pending', '$pending', Icons.timelapse)),
            SizedBox(width: tileW, child: _squareStat('Resolved', '$resolved', Icons.verified)),
            SizedBox(width: tileW, child: _squareStat('Forwarded', '$forwarded', Icons.forward_to_inbox)),
            SizedBox(width: tileW, child: _squareStat('Closed', '$closed', Icons.lock)),
          ],
        );
      }),
    );
  }

  Widget _squareStat(String label, String value, IconData icon) {
    return Container(
      height: 100,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.black.withOpacity(.85), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: const Center(
        child: Text('No complaints found.', style: TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _quickStatusChips() {
    final items = _statusOptions;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((s) {
        final sel = _statusFilter == s;
        final c = sel ? Colors.white : Colors.white70;
        return InkWell(
          onTap: () => setState(() => _statusFilter = s),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? Colors.black.withOpacity(.15) : Colors.black.withOpacity(.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              s.toUpperCase(),
              style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
