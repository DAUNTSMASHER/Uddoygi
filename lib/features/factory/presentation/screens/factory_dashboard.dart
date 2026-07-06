// lib/features/factory/presentation/screens/factory_dashboard.dart
import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/factory/presentation/widgets/factory_drawer.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:uddoygi/features/common/stock/stockscreen.dart';
import 'package:uddoygi/features/factory/presentation/factory/work_order.dart';
import 'package:uddoygi/features/factory/presentation/factory/purchase_order.dart';
import 'package:uddoygi/features/factory/presentation/factory/QC_report.dart';
import 'package:uddoygi/features/factory/presentation/factory/daily_production.dart';
import 'package:uddoygi/features/factory/presentation/screens/progress_update_screen.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/widgets/u_ai_assistant.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ── Palette (Premium Navy) ───────────────────────────────────────────────────
const _primary    = Color(0xFF0F172A);
const _accent     = Color(0xFF3B82F6); // Blue
const _bg         = Color(0xFFF8FAFC);
const _card       = Color(0xFFFFFFFF);
const _fg         = Color(0xFF1E293B);
const _muted      = Color(0xFF64748B);

class FactoryDashboard extends StatefulWidget {
  const FactoryDashboard({Key? key}) : super(key: key);
  @override
  State<FactoryDashboard> createState() => _FactoryDashboardState();
}

class _FactoryDashboardState extends State<FactoryDashboard> {
  String _cid = '';
  String? name;
  String? photoUrl;
  bool _showMetrics = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (!mounted) return;
    setState(() => _cid = id ?? '');
    await _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    setState(() {
      name = (session?['name'] as String?) ?? current?.displayName ?? 'Factory';
      photoUrl = current?.photoURL;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Text('Factory Dashboard', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.logout_rounded, size: 20), onPressed: () {}),
        ],
      ),
      drawer: const FactoryDrawer(),
      body: CustomScrollView(
        slivers: [
          // ── Hero Section ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  _ModeToggle(
                    value: _showMetrics,
                    onChanged: (v) => setState(() => _showMetrics = v),
                    leftLabel: 'Metrics',
                    rightLabel: 'Workplace',
                  ),
                  const SizedBox(height: 24),
                  if (_showMetrics) _FactoryMetricsGrid(cid: _cid).animate().fadeIn(),
                ],
              ),
            ),
          ),

          // ── Workplace / Actions ─────────────────────────────────────────
          if (!_showMetrics)
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildListDelegate([
                  _ActionCard(title: 'Work Orders', icon: Icons.assignment_rounded, color: Colors.blue),
                  _ActionCard(title: 'Production', icon: Icons.factory_rounded, color: Colors.teal),
                  _ActionCard(title: 'Inventory', icon: Icons.inventory_2_rounded, color: Colors.orange),
                  _ActionCard(title: 'QC Reports', icon: Icons.fact_check_rounded, color: Colors.purple),
                ]),
              ),
            ),

          // ── Secondary Actions ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Activity', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: _fg)),
                  const SizedBox(height: 16),
                  ...List.generate(3, (i) => _RecentActivityItem()),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: _accent,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String leftLabel, rightLabel;
  const _ModeToggle({required this.value, required this.onChanged, required this.leftLabel, required this.rightLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(label: leftLabel, active: value, onTap: () => onChanged(true)),
          _ToggleBtn(label: rightLabel, active: !value, onTap: () => onChanged(false)),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: GoogleFonts.outfit(color: active ? _primary : Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

class _FactoryMetricsGrid extends StatelessWidget {
  final String cid;
  const _FactoryMetricsGrid({required this.cid});

  @override
  Widget build(BuildContext context) {
    if (cid.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        const _MetricCard(label: 'EFFICIENCY', value: '94%', icon: Icons.bolt_rounded, color: Colors.amber),
        
        // Dynamic OUTPUT
        StreamBuilder<QuerySnapshot>(
          stream: DB.colSync(cid, C.workOrders)
              .where('status', isEqualTo: 'Completed')
              .snapshots(),
          builder: (_, snap) {
            final count = snap.data?.docs.length ?? 0;
            return _MetricCard(
              label: 'OUTPUT', 
              value: count > 1000 ? '${(count/1000).toStringAsFixed(1)}k' : '$count', 
              icon: Icons.inventory_2_rounded, 
              color: Colors.blue
            );
          }
        ),

        // Dynamic WORKERS
        StreamBuilder<QuerySnapshot>(
          stream: DB.colSync(cid, C.users).snapshots(),
          builder: (_, snap) {
            final count = snap.data?.docs.length ?? 0;
            return _MetricCard(
              label: 'STAFF', 
              value: '$count', 
              icon: Icons.people_rounded, 
              color: Colors.teal
            );
          }
        ),

        const _MetricCard(label: 'UPTIME', value: '99.9%', icon: Icons.timer_rounded, color: Colors.purple),
      ],
    );
  }
}


class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white60)),
            ],
          ),
          const Spacer(),
          Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _ActionCard({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return UCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: _fg)),
        ],
      ),
    );
  }
}

class _RecentActivityItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: _bg, child: Icon(Icons.history_rounded, size: 20, color: _muted)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Batch #402 Completed', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: _fg)),
                  Text('2 hours ago • Machine A', style: GoogleFonts.outfit(fontSize: 11, color: _muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Stream<int>? badgeStream;
  _NavItem(this.label, this.icon, {required this.onTap, this.badgeStream});
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  const _BadgeIcon({required this.icon, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color),
        if (count > 0)
          Positioned(
            right: -6, top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final bool small;
  const _Badge({required this.count, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }
}
