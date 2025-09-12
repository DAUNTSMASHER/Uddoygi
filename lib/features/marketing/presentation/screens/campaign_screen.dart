import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Brand palette
const Color _brandBlue = Color(0xFF0D47A1);
const Color _accent    = Color(0xFF1D5DF1);
final  Color _surface  = Colors.grey[100]!; // light surface

class AdsManagerMobile extends StatefulWidget {
  const AdsManagerMobile({super.key});

  @override
  State<AdsManagerMobile> createState() => _AdsManagerMobileState();
}

class _AdsManagerMobileState extends State<AdsManagerMobile> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      _DashboardScreen(),
      _PerformanceScreen(),
      _CampaignScreen(),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _brandBlue,
          secondary: _accent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _brandBlue, // BLUE background
          foregroundColor: Colors.white, // WHITE text/icons
          elevation: 0.6,
          centerTitle: true,
        ),
        scaffoldBackgroundColor: Colors.white, // rest is white
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _index == 0 ? 'Dashboard'
                : _index == 1 ? 'Performance'
                : 'Campaigns',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: pages[_index],

        // Blue NavigationBar with white labels/icons
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: _brandBlue,
            indicatorColor: Colors.white24,
            labelTextStyle: MaterialStateProperty.resolveWith<TextStyle?>(
                  (states) {
                final selected = states.contains(MaterialState.selected);
                return TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                );
              },
            ),
            iconTheme: MaterialStateProperty.resolveWith<IconThemeData?>(
                  (states) {
                final selected = states.contains(MaterialState.selected);
                return IconThemeData(color: selected ? Colors.white : Colors.white70);
              },
            ),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.show_chart_outlined),
                selectedIcon: Icon(Icons.show_chart),
                label: 'Performance',
              ),
              NavigationDestination(
                icon: Icon(Icons.campaign_outlined),
                selectedIcon: Icon(Icons.campaign),
                label: 'Campaign',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================== DASHBOARD =============================== */

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen();

  Stream<_DashSummary> _summaryStream() {
    return FirebaseFirestore.instance
        .collection('campaigns')
        .snapshots()
        .map((s) {
      int total = s.docs.length;
      int running = 0;

      // Achievement: % of eligible campaigns whose KPI target met.
      // Rule: if KPI with key 'revenue' exists -> compare totals.revenue >= target
      // else if 'orders' KPI -> totals.orders >= target
      // else if 'sessions' KPI -> totals.sessions >= target
      // If no numeric target found, campaign is not counted in denominator.
      int eligible = 0;
      int achieved = 0;

      String bestName = '-';
      num bestScore = -1;

      for (final doc in s.docs) {
        final data = doc.data();

        final status = (data['status'] ?? 'draft').toString().toLowerCase();
        if (status == 'ongoing') running++;

        final totals = Map<String, dynamic>.from(data['totals'] ?? {});
        final kpisRaw = (data['kpis'] as List? ?? []);
        final List<Map<String, dynamic>> kpis = kpisRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        // Choose the "best" campaign by highest totals.revenue,
        // fallback to orders, then sessions if revenue missing.
        num score = 0;
        if (totals['revenue'] is num) score = totals['revenue'] as num;
        else if (totals['orders'] is num) score = (totals['orders'] as num) * 1.0;
        else if (totals['sessions'] is num) score = (totals['sessions'] as num) / 10.0;

        if (score > bestScore) {
          bestScore = score;
          bestName = (data['title'] ?? data['name'] ?? '-').toString();
        }

        // Achievement
        num? target;
        String? key;
        // prefer revenue KPI
        for (final k in kpis) {
          final kKey = (k['key'] ?? '').toString().toLowerCase();
          if (k['target'] is num) {
            if (kKey == 'revenue') { key = 'revenue'; target = k['target'] as num; break; }
          }
        }
        // fallback orders
        if (target == null) {
          for (final k in kpis) {
            final kKey = (k['key'] ?? '').toString().toLowerCase();
            if (k['target'] is num && kKey == 'orders') { key = 'orders'; target = k['target'] as num; break; }
          }
        }
        // fallback sessions
        if (target == null) {
          for (final k in kpis) {
            final kKey = (k['key'] ?? '').toString().toLowerCase();
            if (k['target'] is num && kKey == 'sessions') { key = 'sessions'; target = k['target'] as num; break; }
          }
        }

        if (target != null && key != null) {
          final actual = (totals[key] is num) ? totals[key] as num : 0;
          eligible++;
          if (actual >= target!) achieved++;
        }
      }

      final double achieveRate =
      eligible == 0 ? 0.0 : (achieved / eligible) * 100.0;

      return _DashSummary(
        totalCampaigns: total,
        runningCampaigns: running,
        achievementRate: achieveRate,
        bestCampaignName: bestName,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_DashSummary>(
      stream: _summaryStream(),
      builder: (ctx, snap) {
        final data = snap.data ??
            const _DashSummary(
              totalCampaigns: 0,
              runningCampaigns: 0,
              achievementRate: 0.0,
              bestCampaignName: '-',
            );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            _SectionCard(
              title: 'Overview',
              titleColor: _brandBlue,
              child: Column(
                children: [
                  _MetricRow(
                    label: 'Total Campaigns',
                    value: NumberFormat.compact().format(data.totalCampaigns),
                  ),
                  const Divider(height: 18),
                  _MetricRow(
                    label: 'Running Campaigns',
                    value: NumberFormat.compact().format(data.runningCampaigns),
                  ),
                  const Divider(height: 18),
                  _MetricRow(
                    label: 'Achievement Rate',
                    value: '${data.achievementRate.toStringAsFixed(1)}%',
                  ),
                  const Divider(height: 18),
                  _MetricRow(
                    label: 'All-time Best Campaign',
                    value: data.bestCampaignName,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashSummary {
  final int totalCampaigns;
  final int runningCampaigns;
  final double achievementRate; // 0..100
  final String bestCampaignName;
  const _DashSummary({
    required this.totalCampaigns,
    required this.runningCampaigns,
    required this.achievementRate,
    required this.bestCampaignName,
  });
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _brandBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _brandBlue,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Color? titleColor;
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: titleColor ?? Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (subtitle != null)
            Text(subtitle!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

/* ============================== PERFORMANCE ============================== */

class _PerformanceScreen extends StatelessWidget {
  const _PerformanceScreen();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('campaigns')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _brandBlue));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _EmptyState(message: 'No data yet. Create a campaign to see performance.');
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final c = docs[i].data();

            final totals = Map<String, dynamic>.from(c['totals'] ?? {});
            final kpisRaw = (c['kpis'] as List? ?? []);
            final kpis = kpisRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black12.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (c['title'] ?? c['name'] ?? '-').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: _brandBlue),
                        ),
                      ),
                      _StatusChip(status: (c['status'] ?? 'draft').toString()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(c['department'] ?? '-').toString()} • ${_dateRangeText(c['startDate'], c['endDate'])}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniStat(label: 'Spend', value: _money(totals['spend'] ?? 0)),
                      _MiniStat(label: 'Sessions', value: _compact(totals['sessions'] ?? 0)),
                      _MiniStat(label: 'Orders', value: _compact(totals['orders'] ?? 0)),
                      _MiniStat(label: 'Revenue', value: _money(totals['revenue'] ?? 0)),
                    ],
                  ),
                  if (kpis.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('KPIs', style: TextStyle(fontWeight: FontWeight.w600, color: _brandBlue)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kpis.map((k) {
                        final label = (k['label'] ?? k['key']).toString();
                        final target = k['target'];
                        final unit = (k['unit'] ?? '').toString();
                        return _KpiPill(label: '$label: $target$unit');
                      }).toList(),
                    ),
                  ],
                ]),
              ),
            );
          },
        );
      },
    );
  }

  static String _dateRangeText(dynamic start, dynamic end) {
    String fmt(dynamic ts) {
      if (ts == null) return '-';
      final d = (ts is Timestamp) ? ts.toDate() : DateTime.tryParse('$ts');
      if (d == null) return '-';
      return DateFormat('MMM d').format(d);
    }
    return '${fmt(start)} → ${fmt(end)}';
  }

  static String _money(dynamic v) {
    if (v is num) return '\$${NumberFormat.compact().format(v)}';
    return '-';
  }

  static String _compact(dynamic v) {
    if (v is num) return NumberFormat.compact().format(v);
    return '-';
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: _brandBlue)),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
      ]),
    );
  }
}

class _KpiPill extends StatelessWidget {
  final String label;
  const _KpiPill({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: _brandBlue.withOpacity(.2)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: _brandBlue)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg = Colors.grey.shade200;
    Color fg = Colors.grey.shade800;
    if (s == 'ongoing') { bg = Colors.green.shade50; fg = Colors.green.shade800; }
    else if (s == 'paused') { bg = Colors.orange.shade50; fg = Colors.orange.shade800; }
    else if (s == 'expired') { bg = Colors.red.shade50; fg = Colors.red.shade800; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, color: Colors.grey[500], size: 56),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
        ]),
      ),
    );
  }
}

/* ============================== CAMPAIGNS ================================ */

class _CampaignScreen extends StatefulWidget {
  const _CampaignScreen();

  @override
  State<_CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<_CampaignScreen> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('campaigns')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _brandBlue));
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const _EmptyState(message: 'No campaigns. Tap + to create a new campaign.');
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final ref = docs[i].reference;
                final c = docs[i].data();
                return _CampaignTile(docRef: ref, data: c);
              },
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          child: FloatingActionButton.extended(
            backgroundColor: _brandBlue,
            foregroundColor: Colors.white,
            onPressed: () => _openNewCampaign(context),
            icon: const Icon(Icons.add),
            label: const Text('New'),
          ),
        ),
      ],
    );
  }

  Future<void> _openNewCampaign(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _NewCampaignPage()));
  }
}

class _CampaignTile extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> docRef;
  final Map<String, dynamic> data;
  const _CampaignTile({required this.docRef, required this.data});

  @override
  Widget build(BuildContext context) {
    final dept = (data['department'] ?? '-').toString();
    final title = (data['title'] ?? data['name'] ?? '-').toString();
    final status = (data['status'] ?? 'draft').toString();
    final createdAt = (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : null;
    final totals = Map<String, dynamic>.from(data['totals'] ?? {});

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _CampaignDetailPage(docRef: docRef, data: data)),
      ),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [
          BoxShadow(color: Colors.black12.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 4)),
        ]),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _brandBlue))),
            _StatusChip(status: status),
          ]),
          const SizedBox(height: 6),
          Text('$dept • ${createdAt != null ? DateFormat('MMM d').format(createdAt) : '-'}',
              style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 8, children: [
            _MiniStat(label: 'Spend', value: _currency(totals['spend'] ?? 0)),
            _MiniStat(label: 'Sessions', value: NumberFormat.compact().format((totals['sessions'] ?? 0) as num)),
            _MiniStat(label: 'Orders', value: NumberFormat.compact().format((totals['orders'] ?? 0) as num)),
            _MiniStat(label: 'Revenue', value: _currency(totals['revenue'] ?? 0)),
          ]),
        ]),
      ),
    );
  }

  static String _currency(dynamic v) {
    if (v is num) return '\$${NumberFormat.compact().format(v)}';
    return '-';
  }
}

/* =========================== NEW CAMPAIGN FORM =========================== */

class _NewCampaignPage extends StatefulWidget {
  const _NewCampaignPage();

  @override
  State<_NewCampaignPage> createState() => _NewCampaignPageState();
}

class _NewCampaignPageState extends State<_NewCampaignPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl  = TextEditingController();
  final _titleCtl = TextEditingController();
  final _descCtl  = TextEditingController();

  String   _department = 'Marketing';
  DateTime _start = DateTime.now();
  DateTime _end   = DateTime.now().add(const Duration(days: 14));
  double   _budget = 0;
  String   _status = 'ongoing';

  final Set<String> _platforms = {'Instagram', 'Facebook'};
  final List<_KpiModel> _kpis = [];

  @override
  void initState() {
    super.initState();
    _applyKpiPreset('Marketing');
  }

  void _applyKpiPreset(String dept) {
    _kpis.clear();
    final preset = _departmentKpiPresets[dept] ?? _departmentKpiPresets['Marketing']!;
    _kpis.addAll(preset.map((e) => _KpiModel(key: e.key, label: e.label, unit: e.unit, target: e.defaultTarget)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Campaign')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            _FieldCard(child: Column(children: [
              _TextField(label: 'Campaign Name *', controller: _nameCtl, validator: _req),
              const SizedBox(height: 10),
              _TextField(label: 'Ad Title', controller: _titleCtl),
              const SizedBox(height: 10),
              _TextField(label: 'Description', controller: _descCtl, maxLines: 4),
            ])),
            const SizedBox(height: 12),
            _FieldCard(child: Column(children: [
              _DropdownField(
                label: 'Department *',
                value: _department,
                items: const ['Marketing','HR','Factory','Accounts','R&D','Logistics','International'],
                onChanged: (v) { if (v != null) { _department = v; _applyKpiPreset(v); } },
              ),
              const SizedBox(height: 10),
              _DateRangeField(
                start: _start, end: _end,
                onChanged: (s, e) { _start = s; _end = e; setState(() {}); },
              ),
              const SizedBox(height: 10),
              _NumberField(label: 'Budget (USD)', value: _budget, onChanged: (v) { _budget = v; }),
              const SizedBox(height: 10),
              _DropdownField(
                label: 'Status',
                value: _status,
                items: const ['ongoing','paused','expired','draft'],
                onChanged: (v) { if (v != null) setState(() => _status = v); },
              ),
            ])),
            const SizedBox(height: 12),
            _FieldCard(
              title: 'Platforms',
              child: _PlatformPicker(
                selected: _platforms,
                onChanged: (s) { setState(() { _platforms
                  ..clear()
                  ..addAll(s); }); },
              ),
            ),
            const SizedBox(height: 12),
            _FieldCard(
              title: 'KPIs (targets)',
              subtitle: 'These drive what shows on Performance.',
              child: Column(children: [
                ..._kpis.asMap().entries.map((e) => _KpiEditor(
                  model: e.value,
                  onChanged: (m) { setState(() => _kpis[e.key] = m); },
                  onDelete: () { setState(() => _kpis.removeAt(e.key)); },
                )),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _kpis.add(_KpiModel())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add custom KPI'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Create Campaign'),
            ),
          ],
        ),
      ),
    );
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final doc = FirebaseFirestore.instance.collection('campaigns').doc();
    final now = DateTime.now();

    await doc.set({
      'name'       : _nameCtl.text.trim(),
      'title'      : _titleCtl.text.trim(),
      'description': _descCtl.text.trim(),
      'department' : _department,
      'status'     : _status, // ongoing | paused | expired | draft
      'platforms'  : _platforms.toList(),
      'startDate'  : Timestamp.fromDate(_start),
      'endDate'    : Timestamp.fromDate(_end),
      'budget'     : _budget,
      'kpis'       : _kpis.where((k) => k.key.trim().isNotEmpty).map((k) => k.toMap()).toList(),
      'totals'     : {'spend': 0, 'sessions': 0, 'orders': 0, 'revenue': 0},
      'today'      : {'spend': 0, 'sessions': 0, 'orders': 0, 'revenue': 0},
      'createdAt'  : Timestamp.fromDate(now),
      'createdBy'  : {'name': 'Admin', 'email': ''},
    });

    if (mounted) Navigator.of(context).pop();
  }
}

/* ============================ FORM HELPERS =============================== */

class _FieldCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  const _FieldCard({this.title, this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: Colors.black12.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 4)),
      ]),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Text(title!, style: const TextStyle(fontWeight: FontWeight.w800, color: _brandBlue)),
          if (subtitle != null) Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(subtitle!, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          ),
          const Divider(height: 18),
        ],
        child,
      ]),
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final int maxLines;
  const _TextField({required this.label, required this.controller, this.validator, this.maxLines = 1});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _brandBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true, fillColor: _surface,
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  final String label;
  final double value;
  final void Function(double) onChanged;
  const _NumberField({required this.label, required this.value, required this.onChanged});
  @override
  State<_NumberField> createState() => _NumberFieldState();
}
class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _ctl;
  @override
  void initState() { super.initState(); _ctl = TextEditingController(text: widget.value == 0 ? '' : widget.value.toString()); }
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(color: _brandBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true, fillColor: _surface,
      ),
      onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final void Function(String?) onChanged;
  const _DropdownField({required this.label, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _brandBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true, fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DateRangeField extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final void Function(DateTime, DateTime) onChanged;
  const _DateRangeField({required this.start, required this.end, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final text = '${DateFormat('MMM d, yyyy').format(start)}  →  ${DateFormat('MMM d, yyyy').format(end)}';
    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDateRange: DateTimeRange(start: start, end: end),
          helpText: 'Select Duration',
        );
        if (picked != null) onChanged(picked.start, picked.end);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Duration',
          labelStyle: const TextStyle(color: _brandBlue),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true, fillColor: _surface,
        ),
        child: Text(text, style: const TextStyle(color: _brandBlue)),
      ),
    );
  }
}

class _PlatformPicker extends StatefulWidget {
  final Set<String> selected;
  final void Function(Set<String>) onChanged;
  const _PlatformPicker({required this.selected, required this.onChanged});

  @override
  State<_PlatformPicker> createState() => _PlatformPickerState();
}

class _PlatformPickerState extends State<_PlatformPicker> {
  static const _all = ['Instagram','Facebook','TikTok','YouTube','Google'];
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _all.map((p) {
        final on = widget.selected.contains(p);
        return FilterChip(
          selected: on,
          label: Text(p, style: const TextStyle(color: _brandBlue)),
          onSelected: (v) {
            final next = {...widget.selected};
            if (v) { next.add(p); } else { next.remove(p); }
            widget.onChanged(next);
          },
          selectedColor: _brandBlue.withOpacity(.12),
          checkmarkColor: _brandBlue,
          side: BorderSide(color: _brandBlue.withOpacity(.2)),
        );
      }).toList(),
    );
  }
}

class _KpiEditor extends StatefulWidget {
  final _KpiModel model;
  final void Function(_KpiModel) onChanged;
  final VoidCallback onDelete;
  const _KpiEditor({required this.model, required this.onChanged, required this.onDelete});

  @override
  State<_KpiEditor> createState() => _KpiEditorState();
}
class _KpiEditorState extends State<_KpiEditor> {
  late final TextEditingController _keyCtl;
  late final TextEditingController _labelCtl;
  late final TextEditingController _targetCtl;
  late final TextEditingController _unitCtl;

  @override
  void initState() {
    super.initState();
    _keyCtl    = TextEditingController(text: widget.model.key);
    _labelCtl  = TextEditingController(text: widget.model.label);
    _targetCtl = TextEditingController(text: widget.model.target == null ? '' : widget.model.target.toString());
    _unitCtl   = TextEditingController(text: widget.model.unit);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: [
          Expanded(child: TextFormField(
            controller: _keyCtl,
            decoration: const InputDecoration(labelText: 'Key (e.g., revenue, sessions)', labelStyle: TextStyle(color: _brandBlue)),
            onChanged: (_) => _emit(),
          )),
          const SizedBox(width: 8),
          IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline, color: _brandBlue)),
        ]),
        Row(children: [
          Expanded(child: TextFormField(
            controller: _labelCtl,
            decoration: const InputDecoration(labelText: 'Label', labelStyle: TextStyle(color: _brandBlue)),
            onChanged: (_) => _emit(),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(
            controller: _unitCtl,
            decoration: const InputDecoration(labelText: 'Unit (%, \$, pcs, etc.)', labelStyle: TextStyle(color: _brandBlue)),
            onChanged: (_) => _emit(),
          )),
        ]),
        const SizedBox(height: 8),
        TextFormField(
          controller: _targetCtl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Target (number)', labelStyle: TextStyle(color: _brandBlue)),
          onChanged: (_) => _emit(),
        ),
      ]),
    );
  }

  void _emit() {
    widget.onChanged(_KpiModel(
      key: _keyCtl.text.trim(),
      label: _labelCtl.text.trim(),
      unit: _unitCtl.text.trim(),
      target: double.tryParse(_targetCtl.text.trim()),
    ));
  }
}

class _KpiModel {
  final String key;
  final String label;
  final String unit;
  final double? target;
  _KpiModel({this.key = '', this.label = '', this.unit = '', this.target});

  Map<String, dynamic> toMap() => {
    'key': key,
    'label': label.isEmpty ? key : label,
    'unit': unit,
    'target': target,
    'default': false,
  };
}

/* ============================ CAMPAIGN DETAIL ============================ */

class _CampaignDetailPage extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> docRef;
  final Map<String, dynamic> data;
  const _CampaignDetailPage({required this.docRef, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text((data['title'] ?? data['name'] ?? 'Campaign').toString())),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _brandBlue));
          final c = snap.data!.data() ?? {};
          final metricsToday = Map<String, dynamic>.from(c['today'] ?? {});
          final totals = Map<String, dynamic>.from(c['totals'] ?? {});
          final kpisRaw = (c['kpis'] as List? ?? []);
          final kpis = kpisRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SectionCard(
                title: 'Today',
                titleColor: _brandBlue,
                child: Wrap(spacing: 10, runSpacing: 8, children: [
                  _MiniStat(label: 'Spend', value: _money(metricsToday['spend'] ?? 0)),
                  _MiniStat(label: 'Sessions', value: NumberFormat.compact().format((metricsToday['sessions'] ?? 0) as num)),
                  _MiniStat(label: 'Orders', value: NumberFormat.compact().format((metricsToday['orders'] ?? 0) as num)),
                  _MiniStat(label: 'Revenue', value: _money(metricsToday['revenue'] ?? 0)),
                ]),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Totals',
                titleColor: _brandBlue,
                child: Wrap(spacing: 10, runSpacing: 8, children: [
                  _MiniStat(label: 'Spend', value: _money(totals['spend'] ?? 0)),
                  _MiniStat(label: 'Sessions', value: NumberFormat.compact().format((totals['sessions'] ?? 0) as num)),
                  _MiniStat(label: 'Orders', value: NumberFormat.compact().format((totals['orders'] ?? 0) as num)),
                  _MiniStat(label: 'Revenue', value: _money(totals['revenue'] ?? 0)),
                ]),
              ),
              if (kpis.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'KPIs',
                  titleColor: _brandBlue,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: kpis.map((k) {
                      final label = (k['label'] ?? k['key']).toString();
                      final unit  = (k['unit'] ?? '').toString();
                      final target= (k['target'] ?? 0).toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Expanded(child: Text(label, style: const TextStyle(color: _brandBlue))),
                            Text('$target$unit', style: const TextStyle(fontWeight: FontWeight.w800, color: _brandBlue)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
                onPressed: () => _quickUpdateSpend(context),
                icon: const Icon(Icons.add_chart),
                label: const Text('Quick add today metrics'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _quickUpdateSpend(BuildContext context) async {
    final sCtl = TextEditingController();
    final vCtl = TextEditingController();
    final oCtl = TextEditingController();
    final rCtl = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Add Today Metrics', style: TextStyle(fontWeight: FontWeight.w800, color: _brandBlue)),
            const SizedBox(height: 12),
            TextField(controller: sCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Spend (USD)')),
            TextField(controller: vCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sessions')),
            TextField(controller: oCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Orders')),
            TextField(controller: rCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Revenue (USD)')),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );

    if (ok == true) {
      final spend   = double.tryParse(sCtl.text) ?? 0;
      final sess    = int.tryParse(vCtl.text) ?? 0;
      final orders  = int.tryParse(oCtl.text) ?? 0;
      final revenue = double.tryParse(rCtl.text) ?? 0;

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final data = snap.data() ?? {};
        final today  = Map<String, dynamic>.from(data['today']  ?? {});
        final totals = Map<String, dynamic>.from(data['totals'] ?? {});

        final newToday = {
          'spend'   : (today['spend'] ?? 0) + spend,
          'sessions': (today['sessions'] ?? 0) + sess,
          'orders'  : (today['orders'] ?? 0) + orders,
          'revenue' : (today['revenue'] ?? 0) + revenue,
        };
        final newTotals = {
          'spend'   : (totals['spend'] ?? 0) + spend,
          'sessions': (totals['sessions'] ?? 0) + sess,
          'orders'  : (totals['orders'] ?? 0) + orders,
          'revenue' : (totals['revenue'] ?? 0) + revenue,
        };

        tx.update(docRef, {'today': newToday, 'totals': newTotals});

        // daily metrics subcollection
        final dayId = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final mRef = docRef.collection('metrics').doc(dayId);
        final mSnap= await tx.get(mRef);
        final base = mSnap.data() ?? {'date': dayId, 'spend': 0.0, 'sessions': 0, 'orders': 0, 'revenue': 0.0};
        tx.set(mRef, {
          'date'    : dayId,
          'spend'   : (base['spend'] ?? 0) + spend,
          'sessions': (base['sessions'] ?? 0) + sess,
          'orders'  : (base['orders'] ?? 0) + orders,
          'revenue' : (base['revenue'] ?? 0) + revenue,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    }
  }

  static String _money(dynamic v) {
    if (v is num) return '\$${NumberFormat.compact().format(v)}';
    return '-';
  }
}

/* ============================== KPI PRESETS ============================== */

class _PresetKpi {
  final String key;
  final String label;
  final String unit;
  final double defaultTarget;
  const _PresetKpi(this.key, this.label, this.unit, this.defaultTarget);
}

final Map<String, List<_PresetKpi>> _departmentKpiPresets = {
  'Marketing': [
    _PresetKpi('impressions', 'Impressions', ' pcs', 200000),
    _PresetKpi('clicks', 'Clicks', ' pcs', 15000),
    _PresetKpi('sessions', 'Sessions', ' pcs', 8000),
    _PresetKpi('orders', 'Orders', ' pcs', 140),
    _PresetKpi('revenue', 'Revenue', ' \$', 25000),
    _PresetKpi('cpc', 'Avg CPC', ' \$', 0.25),
  ],
  'HR': [
    _PresetKpi('applicants', 'Applicants', ' pcs', 50),
    _PresetKpi('interviews', 'Interviews', ' pcs', 20),
    _PresetKpi('hires', 'Hires', ' pcs', 5),
  ],
  'Factory': [
    _PresetKpi('workOrders', 'Work Orders', ' pcs', 120),
    _PresetKpi('onTimeRate', 'On-time %', ' %', 95),
    _PresetKpi('defects', 'Defects', ' pcs', 10),
  ],
  'Accounts': [
    _PresetKpi('collections', 'Collections', ' \$', 15000),
    _PresetKpi('due', 'Outstanding Due', ' \$', 5000),
  ],
  'R&D': [
    _PresetKpi('samples', 'New Samples', ' pcs', 8),
    _PresetKpi('cycleDays', 'Avg Cycle Days', ' d', 12),
  ],
  'Logistics': [
    _PresetKpi('shipments', 'Shipments', ' pcs', 60),
    _PresetKpi('onTimeRate', 'On-time %', ' %', 97),
  ],
  'International': [
    _PresetKpi('rfq', 'RFQs', ' pcs', 70),
    _PresetKpi('leads', 'Qualified Leads', ' pcs', 50),
    _PresetKpi('orders', 'Orders', ' pcs', 25),
  ],
};
