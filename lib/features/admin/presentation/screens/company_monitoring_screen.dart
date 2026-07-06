import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CompanyMonitoringScreen extends StatelessWidget {
  final String companyId;

  const CompanyMonitoringScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      body: CustomScrollView(
        slivers: [
          // ── Premium Header (Inspired by Reference) ──────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF4C1D95),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E0040), Color(0xFF4C1D95)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company Pulse',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Real-time operations monitoring',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Horizontal Metrics (Hero Stats) ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 24),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _HeroStatCard(
                      label: 'Active Orders',
                      valueStream: DB.colSync(companyId, C.workOrders)
                          .where('status', isEqualTo: 'processing')
                          .snapshots()
                          .map((s) => s.docs.length.toString()),
                      color: const Color(0xFF0D47A1),
                      icon: Icons.assignment_rounded,
                    ),
                    _HeroStatCard(
                      label: 'Pending Pay',
                      valueStream: DB.colSync(companyId, C.invoices)
                          .where('status', isEqualTo: 'pending')
                          .snapshots()
                          .map((s) => s.docs.length.toString()),
                      color: const Color(0xFFFF9800),
                      icon: Icons.hourglass_top_rounded,
                    ),
                    _HeroStatCard(
                      label: 'Daily Rev',
                      valueStream: _getRevenueStream(),
                      color: const Color(0xFF4CAF50),
                      icon: Icons.trending_up_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Module Grid ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildListDelegate([
                _MonitoringModule(
                  title: 'Order Status',
                  icon: Icons.track_changes_rounded,
                  color: Colors.blue,
                  onTap: () {},
                ),
                _MonitoringModule(
                  title: 'Transactions',
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.indigo,
                  onTap: () {},
                ),
                _MonitoringModule(
                  title: 'Settlements',
                  icon: Icons.verified_user_rounded,
                  color: Colors.teal,
                  onTap: () {},
                ),
                _MonitoringModule(
                  title: 'Statistics',
                  icon: Icons.pie_chart_rounded,
                  color: Colors.purple,
                  onTap: () {},
                ),
              ]),
            ),
          ),

          // ── Activity Feed Header ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
              child: Row(
                children: [
                  Text(
                    'Recent Activity',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Activity Feed Items ───────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: DB.colSync(companyId, C.notifications)
                .orderBy('timestamp', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No activity found.'))));
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final d = docs[index].data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: UCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.history_rounded, size: 20, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['title'] ?? 'Activity',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  Text(
                                    d['body'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatTime(d['timestamp']),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Stream<String> _getRevenueStream() {
    return DB.colSync(companyId, C.invoices).snapshots().map((s) {
      double total = 0;
      for (final d in s.docs) {
        total += (d.data() as Map<String, dynamic>)['grandTotal'] ?? 0;
      }
      return '৳${(total / 1000).toStringAsFixed(1)}K';
    });
  }

  String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }
}

class _HeroStatCard extends StatelessWidget {
  final String label;
  final Stream<String> valueStream;
  final Color color;
  final IconData icon;

  const _HeroStatCard({
    required this.label,
    required this.valueStream,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const Spacer(),
          StreamBuilder<String>(
            stream: valueStream,
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? '...',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }
}

class _MonitoringModule extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MonitoringModule({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: UCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}
