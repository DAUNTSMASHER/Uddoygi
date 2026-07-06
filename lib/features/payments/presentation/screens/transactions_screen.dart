// lib/features/payments/presentation/screens/transactions_screen.dart
//
// Full transaction history with filter by status and date range.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/piprapay_repository.dart';
import '../../domain/models/pipra_txn_model.dart';

const Color _brand    = Color(0xFF059669); // green
const Color _brandMid = Color(0xFF10B981);
const Color _surface  = Color(0xFFF0FDF4);
const Color _red      = Color(0xFFDC2626);
const Color _amber    = Color(0xFFD97706);
const Color _indigo   = Color(0xFF4F46E5);

final _money  = NumberFormat('#,##0.00', 'en');
final _dateFmt = DateFormat('d MMM yyyy, hh:mm a');

class TransactionsScreen extends StatefulWidget {
  final String cid;
  const TransactionsScreen({super.key, required this.cid});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final PipraPayRepository _repo;
  TxnStatus? _filterStatus;
  String     _search = '';

  @override
  void initState() {
    super.initState();
    _repo = PipraPayRepository(cid: widget.cid);
  }

  Color _statusColor(TxnStatus s) => switch (s) {
        TxnStatus.paid       => _brand,
        TxnStatus.failed     => _red,
        TxnStatus.cancelled  => Colors.grey,
        TxnStatus.processing => _amber,
        TxnStatus.refunded   => _indigo,
        _                    => _amber,
      };

  IconData _statusIcon(TxnStatus s) => switch (s) {
        TxnStatus.paid       => Icons.check_circle_rounded,
        TxnStatus.failed     => Icons.cancel_rounded,
        TxnStatus.cancelled  => Icons.block_rounded,
        TxnStatus.processing => Icons.hourglass_top_rounded,
        TxnStatus.refunded   => Icons.replay_rounded,
        _                    => Icons.pending_rounded,
      };

  @override
  Widget build(BuildContext context) => Scaffold(
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
          title: const Text('Transactions',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            // ── Filter bar ────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(children: [
                // Search
                TextField(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name, pp_id…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: Colors.black38),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                // Status chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _StatusChip(
                      label: 'All',
                      selected: _filterStatus == null,
                      color: _brand,
                      onTap: () => setState(() => _filterStatus = null),
                    ),
                    ...TxnStatus.values.map((s) => _StatusChip(
                          label: s.label,
                          selected: _filterStatus == s,
                          color: _statusColor(s),
                          onTap: () => setState(() => _filterStatus = s),
                        )),
                  ]),
                ),
              ]),
            ),

            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<PipraTxnModel>>(
                stream: _repo.watchTransactions(limit: 200),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: _brand));
                  }
                  var txns = snap.data!;

                  if (_filterStatus != null) {
                    txns = txns
                        .where((t) => t.status == _filterStatus)
                        .toList();
                  }
                  if (_search.isNotEmpty) {
                    txns = txns
                        .where((t) =>
                            t.beneficiaryName
                                .toLowerCase()
                                .contains(_search) ||
                            t.ppId.toLowerCase().contains(_search) ||
                            t.invoiceId.toLowerCase().contains(_search))
                        .toList();
                  }

                  if (txns.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 64, color: Colors.black12),
                          const SizedBox(height: 12),
                          Text(
                            _search.isNotEmpty || _filterStatus != null
                                ? 'No matching transactions'
                                : 'No transactions yet',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black38),
                          ),
                        ],
                      ),
                    );
                  }

                  // Summary row
                  final totalPaid = txns
                      .where((t) => t.status == TxnStatus.paid)
                      .fold(0.0, (p, t) => p + t.amount);

                  return Column(
                    children: [
                      // Summary bar
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(children: [
                          Text('${txns.length} transactions',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black45)),
                          const Spacer(),
                          Text('৳ ${_money.format(totalPaid)} paid',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _brand)),
                        ]),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              16, 12, 16, 32),
                          itemCount: txns.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _TxnCard(
                            txn:         txns[i],
                            statusColor: _statusColor(txns[i].status),
                            statusIcon:  _statusIcon(txns[i].status),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}

// ── Transaction Card ──────────────────────────────────────────────────────────
class _TxnCard extends StatelessWidget {
  final PipraTxnModel txn;
  final Color         statusColor;
  final IconData      statusIcon;
  const _TxnCard({
    required this.txn,
    required this.statusColor,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
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
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(
                      txn.initiatedAt == null
                          ? '—'
                          : _dateFmt.format(txn.initiatedAt!),
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
                          fontSize: 15,
                          color: statusColor)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
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

            if (txn.ppId.isNotEmpty || txn.paymentMethod.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(spacing: 16, runSpacing: 6, children: [
                if (txn.ppId.isNotEmpty)
                  _Detail(label: 'PP ID', value: txn.ppId),
                if (txn.invoiceId.isNotEmpty)
                  _Detail(label: 'Invoice', value: txn.invoiceId),
                if (txn.paymentMethod.isNotEmpty)
                  _Detail(label: 'Method', value: txn.paymentMethod),
                if (txn.currency.isNotEmpty)
                  _Detail(label: 'Currency', value: txn.currency),
                if (txn.fee > 0)
                  _Detail(label: 'Fee', value: '৳ ${_money.format(txn.fee)}'),
                if (txn.isSandbox)
                  const _Detail(label: 'Mode', value: 'Sandbox'),
              ]),
            ],

            if (txn.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(txn.notes,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black38)),
            ],
          ],
        ),
      );
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;
  const _Detail({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.black38)),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
        ],
      );
}

class _StatusChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final Color        color;
  final VoidCallback onTap;
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : Colors.transparent),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : Colors.black38)),
        ),
      );
}
