import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';

import '../../data/piprapay_repository.dart';
import '../../domain/models/payment_settings_model.dart';
import '../../domain/models/pipra_txn_model.dart';
import 'piprapay_settings_screen.dart';
import 'money_sources_screen.dart';
import 'beneficiaries_screen.dart';
import 'transactions_screen.dart';
import 'initiate_payment_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _brand    = Color(0xFF4F46E5); // indigo
const Color _brandMid = Color(0xFF6366F1);
const Color _surface  = Color(0xFFF5F3FF);
const Color _green    = Color(0xFF059669);
const Color _red      = Color(0xFFDC2626);
const Color _amber    = Color(0xFFD97706);

final _money = NumberFormat('#,##0.00', 'en');

// ─────────────────────────────────────────────────────────────────────────────
class PipraPayDashboard extends StatefulWidget {
  const PipraPayDashboard({super.key});
  @override
  State<PipraPayDashboard> createState() => _PipraPayDashboardState();
}

class _PipraPayDashboardState extends State<PipraPayDashboard> {
  String _cid = '';
  bool   _cidLoaded = false;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() { _cid = id ?? ''; _cidLoaded = true; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_cidLoaded) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: CircularProgressIndicator(color: _brand)),
      );
    }

    final repo = PipraPayRepository(cid: _cid);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brand, _brandMid],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Text('PipraPay',
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PipraPaySettingsScreen(cid: _cid)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<PaymentSettingsModel>(
        stream: repo.watchSettings(),
        builder: (ctx, settingsSnap) {
          final settings = settingsSnap.data ?? const PaymentSettingsModel();

          return StreamBuilder<List<PipraTxnModel>>(
            stream: repo.watchTransactions(limit: 100),
            builder: (ctx2, txnSnap) {
              final txns = txnSnap.data ?? [];
              final totalPaid = txns
                  .where((t) => t.status == TxnStatus.paid)
                  .fold(0.0, (p, t) => p + t.amount);
              final pending = txns
                  .where((t) => t.status == TxnStatus.pending ||
                      t.status == TxnStatus.processing)
                  .length;
              final failed = txns
                  .where((t) => t.status == TxnStatus.failed)
                  .length;

              return RefreshIndicator(
                color: _brand,
                onRefresh: () async {},
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // ── Status + Hero ─────────────────────────────────────
                    _HeroCard(settings: settings, cid: _cid),

                    const SizedBox(height: 16),

                    // ── KPI Row ───────────────────────────────────────────
                    Row(children: [
                      Expanded(
                          child: _KpiCard(
                              label: 'Total Paid',
                              value: '৳ ${_money.format(totalPaid)}',
                              icon: Icons.check_circle_rounded,
                              color: _green)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _KpiCard(
                              label: 'Pending',
                              value: '$pending',
                              icon: Icons.hourglass_top_rounded,
                              color: _amber)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _KpiCard(
                              label: 'Failed',
                              value: '$failed',
                              icon: Icons.cancel_rounded,
                              color: _red)),
                    ]),

                    const SizedBox(height: 20),

                    // ── Quick Actions ─────────────────────────────────────
                    const _SectionLabel('Quick Actions'),
                    const SizedBox(height: 10),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: [
                        _ActionTile(
                          icon: Icons.send_rounded,
                          label: 'Send Payment',
                          color: _brand,
                          enabled: settings.enabled,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => InitiatePaymentScreen(
                                    cid: _cid, settings: settings)),
                          ),
                        ),
                        _ActionTile(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Money Sources',
                          color: const Color(0xFF0891B2),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => MoneySourcesScreen(cid: _cid)),
                          ),
                        ),
                        _ActionTile(
                          icon: Icons.people_rounded,
                          label: 'Beneficiaries',
                          color: const Color(0xFF7C3AED),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    BeneficiariesScreen(cid: _cid)),
                          ),
                        ),
                        _ActionTile(
                          icon: Icons.receipt_long_rounded,
                          label: 'Transactions',
                          color: _green,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    TransactionsScreen(cid: _cid)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Recent Transactions ───────────────────────────────
                    Row(children: [
                      const _SectionLabel('Recent Transactions'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TransactionsScreen(cid: _cid)),
                        ),
                        child: const Text('See all',
                            style: TextStyle(color: _brand)),
                      ),
                    ]),
                    const SizedBox(height: 8),

                    if (!txnSnap.hasData)
                      const Center(
                          child: CircularProgressIndicator(color: _brand))
                    else if (txns.isEmpty)
                      _EmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: 'No transactions yet',
                        sub: settings.enabled
                            ? 'Tap "Send Payment" to create your first transaction'
                            : 'Enable PipraPay in Settings first',
                      )
                    else
                      ...txns.take(5).map((t) => _TxnTile(txn: t)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final PaymentSettingsModel settings;
  final String cid;
  const _HeroCard({required this.settings, required this.cid});

  @override
  Widget build(BuildContext context) {
    final connected = settings.connectionStatus == 'connected';
    final statusColor = settings.enabled
        ? (connected ? _green : _amber)
        : Colors.grey;
    final statusLabel = settings.enabled
        ? (connected ? 'Connected' : 'Not Connected')
        : 'Disabled';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brand, _brandMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _brand.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 8),
                if (settings.sandboxMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('SANDBOX',
                        style: TextStyle(
                            color: _amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
              ]),
              const SizedBox(height: 12),
              Text('PipraPay Gateway',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(
                settings.backendBaseUrl.isEmpty
                    ? 'Backend URL not configured'
                    : settings.backendBaseUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PipraPaySettingsScreen(cid: cid)),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.settings_rounded,
                color: Colors.white, size: 28),
          ),
        ),
      ]),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Colors.black38)),
          ],
        ),
      );
}

// ── Action Tile ───────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  final bool     enabled;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: enabled
                    ? color.withValues(alpha: 0.2)
                    : Colors.black12),
            boxShadow: enabled
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ]
                : null,
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: enabled
                    ? color.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: enabled ? color : Colors.black26, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: enabled ? Colors.black87 : Colors.black38)),
            ),
          ]),
        ),
      );
}

// ── Transaction Tile ──────────────────────────────────────────────────────────
class _TxnTile extends StatelessWidget {
  final PipraTxnModel txn;
  const _TxnTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (txn.status) {
      TxnStatus.paid       => _green,
      TxnStatus.failed     => _red,
      TxnStatus.cancelled  => Colors.grey,
      TxnStatus.processing => _amber,
      _                    => _amber,
    };
    final dateFmt = DateFormat('d MMM, hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            txn.status == TxnStatus.paid
                ? Icons.check_circle_rounded
                : txn.status == TxnStatus.failed
                    ? Icons.cancel_rounded
                    : Icons.hourglass_top_rounded,
            color: statusColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(txn.beneficiaryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                txn.initiatedAt == null
                    ? txn.status.label
                    : dateFmt.format(txn.initiatedAt!),
                style: const TextStyle(
                    fontSize: 11, color: Colors.black38),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('৳ ${_money.format(txn.amount)}',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: statusColor)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(txn.status.label,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
          ],
        ),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.black87));
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   message;
  final String   sub;
  const _EmptyState(
      {required this.icon, required this.message, required this.sub});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(children: [
          Icon(icon, size: 48, color: Colors.black12),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.black38)),
          const SizedBox(height: 4),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black26)),
        ]),
      );
}
