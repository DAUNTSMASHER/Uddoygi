// lib/features/admin/presentation/screens/admin_research.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// ─────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────
class _C {
  static const p1 = Color(0xFF1A0533);
  static const p2 = Color(0xFF4C1D95);
  static const p3 = Color(0xFF7C3AED);
  static const bg = Color(0xFFF5F3FF);
  static const card = Colors.white;
  static const text = Color(0xFF0F172A);
  static const text2 = Color(0xFF64748B);
  static const border = Color(0xFFEDE9FE);
  static const green = Color(0xFF059669);
  static const amber = Color(0xFFD97706);
  static const red = Color(0xFFDC2626);
  static const cyan = Color(0xFF0891B2);
  static const teal = Color(0xFF0D9488);
}

// ─────────────────────────────────────────────
// COLLECTIONS
// ─────────────────────────────────────────────
const _projectsCol = 'rnd_projects';
const _updatesCol = 'rnd_updates';
const _scoresCol = 'rnd_scores';

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────
String _fmtDate(dynamic v, {bool withTime = false}) {
  if (v == null) return '';
  DateTime? dt;
  if (v is Timestamp) dt = v.toDate();
  if (v is String) dt = DateTime.tryParse(v);
  if (dt == null) return '';
  return withTime
      ? DateFormat('dd MMM yyyy  HH:mm').format(dt)
      : DateFormat('dd MMM yyyy').format(dt);
}

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  final a = p.isNotEmpty && p.first.isNotEmpty ? p.first[0] : 'U';
  final b = p.length > 1 && p[1].isNotEmpty ? p[1][0] : '';
  return (a + b).toUpperCase();
}

Color _priorityColor(String p) {
  switch (p) {
    case 'Critical': return _C.red;
    case 'High': return _C.amber;
    case 'Medium': return _C.cyan;
    default: return _C.text2;
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'Completed': return _C.green;
    case 'In Progress': return _C.p3;
    case 'On Hold': return _C.amber;
    case 'Cancelled': return _C.red;
    default: return _C.text2;
  }
}

IconData _statusIcon(String s) {
  switch (s) {
    case 'Completed': return Icons.check_circle_rounded;
    case 'In Progress': return Icons.play_circle_rounded;
    case 'On Hold': return Icons.pause_circle_rounded;
    case 'Cancelled': return Icons.cancel_rounded;
    default: return Icons.radio_button_unchecked_rounded;
  }
}

// ─────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────
class AdminResearchScreen extends StatefulWidget {
  const AdminResearchScreen({super.key});

  @override
  State<AdminResearchScreen> createState() => _AdminResearchScreenState();
}

enum _Tab { overview, projects, updates, leaderboard }

class _AdminResearchScreenState extends State<AdminResearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _adminName = 'Admin';
  String _adminEmail = '';

  // projects filter
  String _projectFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _loadSession();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final s = await LocalStorageService.getSession();
    if (!mounted) return;
    setState(() {
      _adminEmail = (s?['email'] as String?) ?? '';
      _adminName = (s?['name'] as String?) ?? _adminEmail;
    });
  }

  // ── Assign a new project ──
  void _showProjectDialog({DocumentSnapshot? existing}) {
    final titleC = TextEditingController(text: existing?.get('title') ?? '');
    final descC = TextEditingController(text: existing?.get('description') ?? '');
    final objectivesC = TextEditingController(text: existing?.get('objectives') ?? '');
    final assigneeC = TextEditingController(text: existing?.get('assigneeName') ?? '');
    final assigneeEmailC = TextEditingController(text: existing?.get('assigneeEmail') ?? '');
    final deadlineC = TextEditingController(text: existing?.get('deadline') ?? '');
    String priority = existing?.get('priority') ?? 'Medium';
    String status = existing?.get('status') ?? 'Not Started';
    int progress = existing?.get('progress') ?? 0;

    final priorities = ['Low', 'Medium', 'High', 'Critical'];
    final statuses = ['Not Started', 'In Progress', 'On Hold', 'Completed', 'Cancelled'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          backgroundColor: _C.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    Container(
                      height: 36, width: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(colors: [_C.p2, _C.p3]),
                      ),
                      child: const Icon(Icons.science_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        existing == null ? 'Assign New Project' : 'Edit Project',
                        style: AppFonts.banglaHeading(fontWeight: FontWeight.w900, fontSize: 16, color: _C.text),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _C.text2),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _Field(controller: titleC, label: 'Project Title', hint: 'e.g. AI-Powered Demand Forecasting'),
                const SizedBox(height: 10),
                _Field(controller: descC, label: 'Description', hint: 'What is this project about?', maxLines: 3),
                const SizedBox(height: 10),
                _Field(controller: objectivesC, label: 'Objectives / Deliverables', hint: 'Key goals and expected outputs', maxLines: 2),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: _Field(controller: assigneeC, label: 'Assignee Name', hint: 'Full name')),
                    const SizedBox(width: 10),
                    Expanded(child: _Field(controller: assigneeEmailC, label: 'Assignee Email', hint: 'email@company.com')),
                  ],
                ),
                const SizedBox(height: 10),
                _Field(controller: deadlineC, label: 'Deadline', hint: 'YYYY-MM-DD', keyboardType: TextInputType.datetime),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _DropdownField<String>(
                        label: 'Priority',
                        value: priority,
                        items: priorities,
                        onChanged: (v) => setSt(() => priority = v ?? priority),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DropdownField<String>(
                        label: 'Status',
                        value: status,
                        items: statuses,
                        onChanged: (v) => setSt(() => status = v ?? status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Progress slider
                Text('Progress: $progress%',
                    style: AppFonts.banglaBody(fontWeight: FontWeight.w800, color: _C.text2, fontSize: 13)),
                Slider(
                  value: progress.toDouble(),
                  min: 0, max: 100, divisions: 20,
                  activeColor: _C.p3,
                  inactiveColor: _C.border,
                  label: '$progress%',
                  onChanged: (v) => setSt(() => progress = v.round()),
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: AppFonts.banglaBody(fontWeight: FontWeight.w700, color: _C.text2)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _C.p2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: Icon(existing == null ? Icons.add_rounded : Icons.save_rounded, size: 16),
                      label: Text(
                        existing == null ? 'Assign Project' : 'Save Changes',
                        style: AppFonts.banglaBody(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () async {
                        final title = titleC.text.trim();
                        if (title.isEmpty) return;
                        final data = {
                          'title': title,
                          'description': descC.text.trim(),
                          'objectives': objectivesC.text.trim(),
                          'assigneeName': assigneeC.text.trim(),
                          'assigneeEmail': assigneeEmailC.text.trim().toLowerCase(),
                          'deadline': deadlineC.text.trim(),
                          'priority': priority,
                          'status': status,
                          'progress': progress,
                          'assignedBy': _adminName,
                          'assignedByEmail': _adminEmail,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                        if (existing == null) {
                          data['createdAt'] = FieldValue.serverTimestamp();
                          await DB.firestore.collection(_projectsCol).add(data);
                        } else {
                          await existing.reference.update(data);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
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

  // ── Delete project ──
  Future<void> _deleteProject(DocumentSnapshot doc) async {
    final ok = await _confirmDialog(context, 'Delete Project?',
        'This will permanently remove the project and cannot be undone.');
    if (ok == true) await doc.reference.delete();
  }

  // ── Assign / update score ──
  void _showScoreDialog({DocumentSnapshot? existing, String? memberEmail, String? memberName}) {
    final scoreC = TextEditingController(
        text: existing != null ? (existing.get('score') ?? '').toString() : '');
    final noteC = TextEditingController(text: existing?.get('note') ?? '');
    final nameC = TextEditingController(text: memberName ?? existing?.get('memberName') ?? '');
    final emailC = TextEditingController(text: memberEmail ?? existing?.get('memberEmail') ?? '');
    String category = existing?.get('category') ?? 'Monthly';
    final categories = ['Monthly', 'Project', 'Innovation', 'Collaboration', 'Presentation'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: _C.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Text(
            existing == null ? 'Assign Score' : 'Update Score',
            style: AppFonts.banglaBody(fontWeight: FontWeight.w900, color: _C.text),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                if (existing == null) ...[
                  _Field(controller: nameC, label: 'Member Name', hint: 'Full name'),
                  const SizedBox(height: 10),
                  _Field(controller: emailC, label: 'Member Email', hint: 'email@company.com'),
                  const SizedBox(height: 10),
                ],
                _DropdownField<String>(
                  label: 'Score Category',
                  value: category,
                  items: categories,
                  onChanged: (v) => setSt(() => category = v ?? category),
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: scoreC,
                  label: 'Score (0–100)',
                  hint: '85',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _Field(controller: noteC, label: 'Feedback / Note', hint: 'Optional feedback', maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: AppFonts.banglaBody(fontWeight: FontWeight.w700, color: _C.text2)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _C.p2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final score = int.tryParse(scoreC.text.trim()) ?? 0;
                final clampedScore = score.clamp(0, 100);
                final data = {
                  'memberName': nameC.text.trim(),
                  'memberEmail': emailC.text.trim().toLowerCase(),
                  'category': category,
                  'score': clampedScore,
                  'note': noteC.text.trim(),
                  'assignedBy': _adminName,
                  'timestamp': FieldValue.serverTimestamp(),
                };
                if (existing == null) {
                  await DB.firestore.collection(_scoresCol).add(data);
                } else {
                  await existing.reference.update(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(
                existing == null ? 'Assign Score' : 'Update',
                style: AppFonts.banglaBody(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        elevation: 0,
        title: Text('R&D Research Wing',
            style: AppFonts.banglaBody(fontWeight: FontWeight.w900, color: Colors.white)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_C.p1, _C.p2, _C.p3],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Assign project',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () { HapticFeedback.lightImpact(); _showProjectDialog(); },
          ),
          IconButton(
            tooltip: 'Assign score',
            icon: const Icon(Icons.star_outline_rounded),
            onPressed: () { HapticFeedback.lightImpact(); _showScoreDialog(); },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: AppFonts.banglaBody(fontWeight: FontWeight.w900, fontSize: 13),
          unselectedLabelStyle: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 13),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Projects'),
            Tab(text: 'Daily Updates'),
            Tab(text: 'Leaderboard'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OverviewTab(),
          _ProjectsTab(
            filter: _projectFilter,
            onFilterChanged: (v) => setState(() => _projectFilter = v),
            onEdit: (doc) => _showProjectDialog(existing: doc),
            onDelete: _deleteProject,
            onScore: (doc) => _showScoreDialog(
              memberEmail: doc.get('assigneeEmail'),
              memberName: doc.get('assigneeName'),
            ),
          ),
          _UpdatesTab(adminName: _adminName, adminEmail: _adminEmail),
          _LeaderboardTab(onEditScore: (doc) => _showScoreDialog(existing: doc)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 1 — OVERVIEW
// ─────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.firestore.collection(_projectsCol).snapshots(),
      builder: (ctx, projSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: DB.firestore
              .collection(_updatesCol)
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots(),
          builder: (ctx, updSnap) {
            final projects = projSnap.data?.docs ?? [];
            final updates = updSnap.data?.docs ?? [];

            int total = projects.length;
            int inProgress = projects.where((d) => (d.data() as Map)['status'] == 'In Progress').length;
            int completed = projects.where((d) => (d.data() as Map)['status'] == 'Completed').length;
            int onHold = projects.where((d) => (d.data() as Map)['status'] == 'On Hold').length;

            // avg progress
            double avgProgress = 0;
            if (projects.isNotEmpty) {
              avgProgress = projects
                  .map((d) => ((d.data() as Map)['progress'] as num?)?.toDouble() ?? 0)
                  .reduce((a, b) => a + b) / projects.length;
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KPI row
                        Row(
                          children: [
                            Expanded(child: _KpiTile(label: 'Total Projects', value: total.toString(), icon: Icons.science_rounded, color: _C.p3)),
                            const SizedBox(width: 10),
                            Expanded(child: _KpiTile(label: 'In Progress', value: inProgress.toString(), icon: Icons.play_circle_rounded, color: _C.cyan)),
                          ],
                        ).animate().fadeIn(duration: 200.ms).slideY(begin: .05),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _KpiTile(label: 'Completed', value: completed.toString(), icon: Icons.check_circle_rounded, color: _C.green)),
                            const SizedBox(width: 10),
                            Expanded(child: _KpiTile(label: 'On Hold', value: onHold.toString(), icon: Icons.pause_circle_rounded, color: _C.amber)),
                          ],
                        ).animate().fadeIn(duration: 220.ms).slideY(begin: .05),

                        const SizedBox(height: 14),

                        // Avg progress bar
                        _AvgProgressCard(avgProgress: avgProgress)
                            .animate().fadeIn(duration: 240.ms),

                        const SizedBox(height: 14),

                        // Project status breakdown
                        if (projects.isNotEmpty) ...[
                          _StatusBreakdown(projects: projects)
                              .animate().fadeIn(duration: 260.ms),
                          const SizedBox(height: 14),
                        ],

                        // Recent updates
                        _SectionLabel(label: 'Recent Daily Updates'),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                if (updates.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _EmptyCard(message: 'No updates posted yet.'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: _UpdateCard(doc: updates[i], showActions: false)
                            .animate().fadeIn(duration: 200.ms).slideY(begin: .04),
                      ),
                      childCount: updates.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: color.withOpacity(.08), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            height: 38, width: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withOpacity(.12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppFonts.banglaData(fontWeight: FontWeight.w900, fontSize: 22, color: _C.text)),
                Text(label, style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 11, color: _C.text2),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvgProgressCard extends StatelessWidget {
  final double avgProgress;
  const _AvgProgressCard({required this.avgProgress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [_C.p1, _C.p2, _C.p3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: _C.p2.withOpacity(.25), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text('Overall R&D Progress',
                  style: AppFonts.banglaBody(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14)),
              const Spacer(),
              Text('${avgProgress.toStringAsFixed(1)}%',
                  style: AppFonts.banglaData(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 22)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: avgProgress / 100,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text('Average across all projects',
              style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white60)),
        ],
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  final List<QueryDocumentSnapshot> projects;
  const _StatusBreakdown({required this.projects});

  @override
  Widget build(BuildContext context) {
    final statuses = ['Not Started', 'In Progress', 'On Hold', 'Completed', 'Cancelled'];
    final counts = {for (final s in statuses) s: 0};
    for (final d in projects) {
      final s = (d.data() as Map)['status'] as String? ?? 'Not Started';
      counts[s] = (counts[s] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Project Status Breakdown',
              style: AppFonts.banglaBody(fontWeight: FontWeight.w900, color: _C.text, fontSize: 13)),
          const SizedBox(height: 12),
          ...statuses.where((s) => (counts[s] ?? 0) > 0).map((s) {
            final count = counts[s]!;
            final pct = projects.isEmpty ? 0.0 : count / projects.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_statusIcon(s), size: 14, color: _statusColor(s)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(s,
                            style: AppFonts.banglaBody(fontWeight: FontWeight.w800, fontSize: 12, color: _C.text)),
                      ),
                      Text('$count',
                          style: AppFonts.banglaBody(fontWeight: FontWeight.w900, fontSize: 12, color: _statusColor(s))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: _C.border,
                      valueColor: AlwaysStoppedAnimation<Color>(_statusColor(s)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 2 — PROJECTS
// ─────────────────────────────────────────────
class _ProjectsTab extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final void Function(DocumentSnapshot) onEdit;
  final void Function(DocumentSnapshot) onDelete;
  final void Function(DocumentSnapshot) onScore;

  const _ProjectsTab({
    required this.filter,
    required this.onFilterChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onScore,
  });

  static const _filters = ['All', 'Not Started', 'In Progress', 'On Hold', 'Completed', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          color: _C.card,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f, style: AppFonts.banglaBody(fontWeight: FontWeight.w800, fontSize: 12)),
                  selected: filter == f,
                  onSelected: (_) => onFilterChanged(f),
                  selectedColor: _C.p2,
                  checkmarkColor: Colors.white,
                  labelStyle: AppFonts.banglaBody(
                    fontWeight: FontWeight.w800, fontSize: 12,
                    color: filter == f ? Colors.white : _C.text2,
                  ),
                  backgroundColor: _C.bg,
                  side: BorderSide(color: filter == f ? _C.p2 : _C.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
              )).toList(),
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: DB.firestore
                .collection(_projectsCol)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const _Shimmer();
              var docs = snap.data?.docs ?? [];
              if (filter != 'All') {
                docs = docs.where((d) => (d.data() as Map)['status'] == filter).toList();
              }
              if (docs.isEmpty) {
                return _Empty(
                  icon: Icons.science_rounded,
                  message: filter == 'All'
                      ? 'No projects assigned yet.\nTap + to assign a project.'
                      : 'No "$filter" projects.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                itemCount: docs.length,
                itemBuilder: (_, i) => _ProjectCard(
                  doc: docs[i],
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onScore: onScore,
                ).animate().fadeIn(duration: 200.ms).slideY(begin: .04),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final void Function(DocumentSnapshot) onEdit;
  final void Function(DocumentSnapshot) onDelete;
  final void Function(DocumentSnapshot) onScore;

  const _ProjectCard({required this.doc, required this.onEdit, required this.onDelete, required this.onScore});

  @override
  Widget build(BuildContext context) {
    final m = doc.data() as Map<String, dynamic>;
    final title = m['title'] ?? 'Untitled';
    final desc = m['description'] ?? '';
    final objectives = m['objectives'] ?? '';
    final assigneeName = m['assigneeName'] ?? '';
    final deadline = m['deadline'] ?? '';
    final priority = m['priority'] ?? 'Medium';
    final status = m['status'] ?? 'Not Started';
    final progress = (m['progress'] as num?)?.toInt() ?? 0;
    final assignedBy = m['assignedBy'] ?? '';
    final createdAt = _fmtDate(m['createdAt']);

    final statusC = _statusColor(status);
    final priorityC = _priorityColor(priority);

    // Check if deadline is overdue
    bool overdue = false;
    if (deadline.isNotEmpty && status != 'Completed' && status != 'Cancelled') {
      final dl = DateTime.tryParse(deadline);
      if (dl != null && dl.isBefore(DateTime.now())) overdue = true;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: overdue ? _C.red.withOpacity(.4) : _C.border, width: overdue ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              color: _C.p1.withOpacity(.04),
              border: Border(bottom: BorderSide(color: _C.border)),
            ),
            child: Row(
              children: [
                // Priority badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityC.withOpacity(.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: priorityC.withOpacity(.3)),
                  ),
                  child: Text(priority,
                      style: AppFonts.banglaBody(fontSize: 10, fontWeight: FontWeight.w900, color: priorityC)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: AppFonts.banglaBody(fontWeight: FontWeight.w900, fontSize: 14, color: _C.text),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusC.withOpacity(.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 11, color: statusC),
                      const SizedBox(width: 4),
                      Text(status,
                          style: AppFonts.banglaBody(fontSize: 10, fontWeight: FontWeight.w900, color: statusC)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: _C.text2, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (v) {
                    if (v == 'edit') onEdit(doc);
                    if (v == 'score') onScore(doc);
                    if (v == 'delete') onDelete(doc);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: _PopItem(icon: Icons.edit_rounded, label: 'Edit Project')),
                    PopupMenuItem(value: 'score', child: _PopItem(icon: Icons.star_rounded, label: 'Assign Score', color: _C.amber)),
                    PopupMenuItem(value: 'delete', child: _PopItem(icon: Icons.delete_rounded, label: 'Delete', color: _C.red)),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc.isNotEmpty)
                  Text(desc,
                      style: AppFonts.banglaBody(fontSize: 13, fontWeight: FontWeight.w600, color: _C.text),
                      maxLines: 2, overflow: TextOverflow.ellipsis),

                if (objectives.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.flag_rounded, size: 13, color: _C.text2),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('Objectives: $objectives',
                            style: AppFonts.banglaBody(fontSize: 12, fontWeight: FontWeight.w700, color: _C.text2),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Progress',
                                  style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w800, color: _C.text2)),
                              Text('$progress%',
                                  style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w900, color: _C.p3)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              minHeight: 8,
                              backgroundColor: _C.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progress >= 100 ? _C.green : _C.p3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Meta row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (assigneeName.isNotEmpty)
                      _InfoChip(label: assigneeName, icon: Icons.person_rounded, color: _C.p2),
                    if (deadline.isNotEmpty)
                      _InfoChip(
                        label: 'Due: $deadline',
                        icon: Icons.calendar_today_rounded,
                        color: overdue ? _C.red : _C.text2,
                      ),
                    if (assignedBy.isNotEmpty)
                      _InfoChip(label: 'By $assignedBy', icon: Icons.admin_panel_settings_rounded, color: _C.teal),
                    _InfoChip(label: createdAt, icon: Icons.access_time_rounded, color: _C.text2),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 3 — DAILY UPDATES
// ─────────────────────────────────────────────
class _UpdatesTab extends StatefulWidget {
  final String adminName;
  final String adminEmail;
  const _UpdatesTab({required this.adminName, required this.adminEmail});

  @override
  State<_UpdatesTab> createState() => _UpdatesTabState();
}

class _UpdatesTabState extends State<_UpdatesTab> {
  String _filterProject = 'All';
  List<String> _projectTitles = ['All'];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final snap = await DB.firestore.collection(_projectsCol).get();
    final titles = snap.docs.map((d) => (d.data()['title'] as String?) ?? '').where((t) => t.isNotEmpty).toList();
    if (mounted) setState(() => _projectTitles = ['All', ...titles]);
  }

  Future<void> _deleteUpdate(DocumentSnapshot doc) async {
    final ok = await _confirmDialog(context, 'Delete Update?', 'This update will be permanently removed.');
    if (ok == true) await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Project filter + post button
        Container(
          color: _C.card,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _projectTitles.map((t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(t, style: AppFonts.banglaBody(fontWeight: FontWeight.w800, fontSize: 11)),
                        selected: _filterProject == t,
                        onSelected: (_) => setState(() => _filterProject = t),
                        selectedColor: _C.p2,
                        checkmarkColor: Colors.white,
                        labelStyle: AppFonts.banglaBody(
                          fontWeight: FontWeight.w800, fontSize: 11,
                          color: _filterProject == t ? Colors.white : _C.text2,
                        ),
                        backgroundColor: _C.bg,
                        side: BorderSide(color: _filterProject == t ? _C.p2 : _C.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: DB.firestore
                .collection(_updatesCol)
                .orderBy('timestamp', descending: true)
                .limit(100)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const _Shimmer();
              var docs = snap.data?.docs ?? [];
              if (_filterProject != 'All') {
                docs = docs.where((d) => (d.data() as Map)['projectTitle'] == _filterProject).toList();
              }
              if (docs.isEmpty) {
                return _Empty(
                  icon: Icons.update_rounded,
                  message: _filterProject == 'All'
                      ? 'No updates posted yet.'
                      : 'No updates for "$_filterProject".',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                itemCount: docs.length,
                itemBuilder: (_, i) => _UpdateCard(
                  doc: docs[i],
                  showActions: true,
                  onDelete: () => _deleteUpdate(docs[i]),
                ).animate().fadeIn(duration: 200.ms).slideY(begin: .04),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final bool showActions;
  final VoidCallback? onDelete;

  const _UpdateCard({required this.doc, required this.showActions, this.onDelete});

  Color _typeColor(String t) {
    switch (t) {
      case 'Blocker': return _C.red;
      case 'Milestone': return _C.green;
      case 'Review': return _C.cyan;
      case 'Note': return _C.amber;
      default: return _C.p3;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'Blocker': return Icons.block_rounded;
      case 'Milestone': return Icons.flag_rounded;
      case 'Review': return Icons.rate_review_rounded;
      case 'Note': return Icons.sticky_note_2_rounded;
      default: return Icons.update_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = doc.data() as Map<String, dynamic>;
    final content = m['content'] ?? '';
    final projectTitle = m['projectTitle'] ?? 'General';
    final updateType = m['updateType'] ?? 'Progress';
    final postedBy = m['postedBy'] ?? '';
    final memberName = m['memberName'] ?? '';
    final timestamp = _fmtDate(m['timestamp'], withTime: true);
    final typeC = _typeColor(updateType);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: typeC, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeC.withOpacity(.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(updateType), size: 11, color: typeC),
                      const SizedBox(width: 4),
                      Text(updateType,
                          style: AppFonts.banglaBody(fontSize: 10, fontWeight: FontWeight.w900, color: typeC)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(projectTitle,
                      style: AppFonts.banglaBody(fontWeight: FontWeight.w900, fontSize: 12, color: _C.p2),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (showActions && onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _C.text2),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(content,
                style: AppFonts.banglaBody(fontSize: 13, fontWeight: FontWeight.w600, color: _C.text)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (memberName.isNotEmpty) ...[
                  _InfoChip(label: memberName, icon: Icons.person_rounded, color: _C.p3),
                  const SizedBox(width: 6),
                ],
                _InfoChip(label: postedBy, icon: Icons.edit_rounded, color: _C.teal),
                const Spacer(),
                Text(timestamp,
                    style: AppFonts.banglaBody(fontSize: 10, fontWeight: FontWeight.w700, color: _C.text2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 4 — LEADERBOARD
// ─────────────────────────────────────────────
class _LeaderboardTab extends StatelessWidget {
  final void Function(DocumentSnapshot) onEditScore;
  const _LeaderboardTab({required this.onEditScore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.firestore
          .collection(_scoresCol)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Shimmer();
        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _Empty(
            icon: Icons.leaderboard_rounded,
            message: 'No scores assigned yet.\nTap ★ to assign a score.',
          );
        }

        // Aggregate scores per member
        final memberScores = <String, _MemberScore>{};
        for (final d in docs) {
          final m = d.data() as Map<String, dynamic>;
          final email = (m['memberEmail'] as String?) ?? '';
          final name = (m['memberName'] as String?) ?? email;
          final score = (m['score'] as num?)?.toInt() ?? 0;
          if (email.isEmpty) continue;
          if (!memberScores.containsKey(email)) {
            memberScores[email] = _MemberScore(name: name, email: email);
          }
          memberScores[email]!.scores.add(score);
        }

        // Sort by average score desc
        final sorted = memberScores.values.toList()
          ..sort((a, b) => b.average.compareTo(a.average));

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top 3 podium
            if (sorted.length >= 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: _Podium(members: sorted.take(3).toList()),
                ).animate().fadeIn(duration: 300.ms),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
                child: _SectionLabel(label: 'All Members'),
              ),
            ),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: _MemberScoreCard(
                    rank: i + 1,
                    member: sorted[i],
                    recentDocs: docs.where((d) {
                      final m = d.data() as Map<String, dynamic>;
                      return (m['memberEmail'] as String?) == sorted[i].email;
                    }).take(3).toList(),
                    onEditScore: onEditScore,
                  ).animate().fadeIn(duration: 200.ms).slideX(begin: .04),
                ),
                childCount: sorted.length,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

class _MemberScore {
  final String name;
  final String email;
  final List<int> scores = [];
  _MemberScore({required this.name, required this.email});
  double get average => scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length;
  int get highest => scores.isEmpty ? 0 : scores.reduce(math.max);
  int get count => scores.length;
}

class _Podium extends StatelessWidget {
  final List<_MemberScore> members;
  const _Podium({required this.members});

  @override
  Widget build(BuildContext context) {
    final podiumColors = [_C.amber, Colors.grey.shade400, const Color(0xFFCD7F32)];
    final podiumIcons = [Icons.emoji_events_rounded, Icons.military_tech_rounded, Icons.workspace_premium_rounded];
    final heights = [90.0, 70.0, 60.0];
    final order = members.length >= 3 ? [1, 0, 2] : (members.length == 2 ? [1, 0] : [0]);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [_C.p1, _C.p2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: _C.p2.withOpacity(.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text('Top Performers',
              style: AppFonts.banglaBody(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: order.where((i) => i < members.length).map((i) {
              final m = members[i];
              final c = podiumColors[i];
              return Expanded(
                child: Column(
                  children: [
                    Icon(podiumIcons[i], color: c, size: i == 0 ? 28 : 22),
                    const SizedBox(height: 4),
                    Container(
                      height: 36, width: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c, width: 2),
                        color: Colors.white.withOpacity(.1),
                      ),
                      alignment: Alignment.center,
                      child: Text(_initials(m.name),
                          style: AppFonts.banglaBody(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                    const SizedBox(height: 4),
                    Text(m.name.split(' ').first,
                        style: AppFonts.banglaBody(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${m.average.toStringAsFixed(1)}',
                        style: AppFonts.banglaBody(color: c, fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 4),
                    Container(
                      height: heights[i],
                      decoration: BoxDecoration(
                        color: c.withOpacity(.25),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        border: Border.all(color: c.withOpacity(.4)),
                      ),
                      alignment: Alignment.center,
                      child: Text('#${i + 1}',
                          style: AppFonts.banglaBody(color: c, fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MemberScoreCard extends StatelessWidget {
  final int rank;
  final _MemberScore member;
  final List<QueryDocumentSnapshot> recentDocs;
  final void Function(DocumentSnapshot) onEditScore;

  const _MemberScoreCard({
    required this.rank,
    required this.member,
    required this.recentDocs,
    required this.onEditScore,
  });

  Color get _rankColor {
    if (rank == 1) return _C.amber;
    if (rank == 2) return Colors.grey.shade400;
    if (rank == 3) return const Color(0xFFCD7F32);
    return _C.text2;
  }

  @override
  Widget build(BuildContext context) {
    final avg = member.average;
    final scoreColor = avg >= 80 ? _C.green : (avg >= 60 ? _C.amber : _C.red);

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rank <= 3 ? _rankColor.withOpacity(.3) : _C.border,
            width: rank <= 3 ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Rank badge
                Container(
                  height: 32, width: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _rankColor.withOpacity(.15),
                    border: Border.all(color: _rankColor.withOpacity(.4)),
                  ),
                  alignment: Alignment.center,
                  child: Text('#$rank',
                      style: AppFonts.banglaBody(fontWeight: FontWeight.w900, fontSize: 11, color: _rankColor)),
                ),
                const SizedBox(width: 10),
                _Avatar(name: member.name),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name,
                          style: AppFonts.banglaBody(fontWeight: FontWeight.w900, color: _C.text),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(member.email,
                          style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w700, color: _C.text2),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Average score circle
                Container(
                  height: 52, width: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scoreColor.withOpacity(.1),
                    border: Border.all(color: scoreColor.withOpacity(.35), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(avg.toStringAsFixed(1),
                          style: AppFonts.banglaBody(fontWeight: FontWeight.w900, fontSize: 14, color: scoreColor)),
                      Text('avg', style: AppFonts.banglaBody(fontSize: 8, fontWeight: FontWeight.w800, color: _C.text2)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Score bar
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: avg / 100,
                minHeight: 6,
                backgroundColor: _C.border,
                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              ),
            ),

            const SizedBox(height: 10),

            // Stats row
            Row(
              children: [
                _InfoChip(label: '${member.count} scores', icon: Icons.star_rounded, color: _C.amber),
                const SizedBox(width: 8),
                _InfoChip(label: 'Best: ${member.highest}', icon: Icons.trending_up_rounded, color: _C.green),
              ],
            ),

            // Recent score entries
            if (recentDocs.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: _C.border),
              const SizedBox(height: 8),
              ...recentDocs.map((d) {
                final m = d.data() as Map<String, dynamic>;
                final score = (m['score'] as num?)?.toInt() ?? 0;
                final category = m['category'] ?? '';
                final note = m['note'] ?? '';
                final date = _fmtDate(m['timestamp']);
                final sc = score >= 80 ? _C.green : (score >= 60 ? _C.amber : _C.red);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: sc.withOpacity(.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: sc.withOpacity(.3)),
                        ),
                        child: Text('$score',
                            style: AppFonts.banglaBody(fontWeight: FontWeight.w900, fontSize: 12, color: sc)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$category${note.isNotEmpty ? '  ·  $note' : ''}',
                          style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w700, color: _C.text2),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(date,
                          style: AppFonts.banglaBody(fontSize: 10, fontWeight: FontWeight.w700, color: _C.text2)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => onEditScore(d),
                        child: const Icon(Icons.edit_rounded, size: 14, color: _C.text2),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36, width: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [_C.p2, _C.p3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(_initials(name),
          style: AppFonts.banglaBody(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _InfoChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: AppFonts.banglaBody(fontWeight: FontWeight.w900, fontSize: 13, color: _C.text2, letterSpacing: .4));
  }
}

class _PopItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _PopItem({required this.icon, required this.label, this.color = _C.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: AppFonts.banglaBody(fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: AppFonts.banglaBody(fontWeight: FontWeight.w700, color: _C.text),
      decoration: _dropDeco(label).copyWith(hintText: hint,
          hintStyle: AppFonts.banglaBody(color: _C.text2.withOpacity(.6), fontWeight: FontWeight.w600)),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: _dropDeco(label),
      items: items.map((i) => DropdownMenuItem<T>(
        value: i,
        child: Text(i.toString(), style: AppFonts.banglaBody(fontWeight: FontWeight.w700)),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

InputDecoration _dropDeco(String label) => InputDecoration(
  labelText: label,
  labelStyle: AppFonts.banglaBody(color: _C.text2, fontWeight: FontWeight.w700),
  filled: true,
  fillColor: _C.bg,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.p3, width: 1.5)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
);

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Text(message, style: AppFonts.banglaBody(fontWeight: FontWeight.w700, color: _C.text2)),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  const _Empty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: _C.border),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: AppFonts.banglaBody(fontWeight: FontWeight.w700, color: _C.text2)),
        ],
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext context) {
    Widget box({double h = 120}) => Container(
          height: h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.border),
          ),
        );
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: [
            box(h: 60), const SizedBox(height: 10),
            box(h: 60), const SizedBox(height: 12),
            box(h: 160), const SizedBox(height: 12),
            box(h: 140),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONFIRM DIALOG HELPER
// ─────────────────────────────────────────────
Future<bool?> _confirmDialog(BuildContext context, String title, String message) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: AppFonts.banglaBody(fontWeight: FontWeight.w900)),
      content: Text(message, style: AppFonts.banglaBody(color: _C.text2, fontWeight: FontWeight.w700)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: AppFonts.banglaBody(fontWeight: FontWeight.w700, color: _C.text2)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _C.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Confirm', style: AppFonts.banglaBody(fontWeight: FontWeight.w900)),
        ),
      ],
    ),
  );
}
