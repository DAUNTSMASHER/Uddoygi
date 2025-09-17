import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _green = Color(0xFF065F46);     // deep green (brand)
const _mint  = Color(0xFF10B981);     // accent green
const _bg    = Color(0xFFF1F8F4);     // soft surface
const _cardB = Color(0x1A065F46);     // light border
const _shadowLite  = Color(0x14000000);

class SalaryScreen extends StatelessWidget {
  const SalaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final email = user?.email;

    // Build the base query: prefer uid, else email
    Query<Map<String, dynamic>> _query() {
      final base = FirebaseFirestore.instance.collection('payrolls');
      if (uid != null) {
        return base.where('employeeUid', isEqualTo: uid).orderBy('generatedAt', descending: true);
      } else if (email != null) {
        return base.where('officeEmail', isEqualTo: email).orderBy('generatedAt', descending: true);
      }
      // fallback (likely no auth) -> empty query via impossible condition
      return base.where('employeeId', isEqualTo: '__none__');
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('My Salary', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query().snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Failed to load payslips.', style: TextStyle(color: _green)));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _green));
          }

          final docs = snap.data!.docs;

          // ---- summary calculations ----
          final uniquePeriods = <String>{};
          num totalNet = 0, sumDisbursed = 0, sumPending = 0;
          int cntDisbursed = 0, cntPending = 0, cntRequested = 0;

          for (final d in docs) {
            final m = d.data();
            uniquePeriods.add((m['period'] ?? '').toString());
            final net = _num(m['netSalary']);
            totalNet += net;

            final st = (m['status'] ?? 'pending').toString();
            if (st == 'disbursed') {
              cntDisbursed++;
              sumDisbursed += net;
            } else if (st == 'requested') {
              cntRequested++;
              sumPending += net;
            } else {
              cntPending++;
              sumPending += net;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _SummaryHeader(
                totalMonths: uniquePeriods.where((e) => e.isNotEmpty).length,
                totalSalary: totalNet,
                totalDisbursed: sumDisbursed,
                totalPending: sumPending,
                counts: (pending: cntPending, requested: cntRequested, disbursed: cntDisbursed),
              ),
              const SizedBox(height: 16),
              if (docs.isEmpty)
                _EmptyState()
              else
                ...docs.map((d) => _PayslipCard(doc: d)).toList(),
            ],
          );
        },
      ),
    );
  }
}

/* =================== Summary header =================== */

class _SummaryHeader extends StatelessWidget {
  final int totalMonths;
  final num totalSalary;
  final num totalDisbursed;
  final num totalPending;
  final ({int pending, int requested, int disbursed}) counts;

  const _SummaryHeader({
    required this.totalMonths,
    required this.totalSalary,
    required this.totalDisbursed,
    required this.totalPending,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_green, _mint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (ctx, c) {
            const spacing = 10.0;
            final w = c.maxWidth;
            final cardW = (w - (spacing * 2)) / 3; // 3 columns
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _StatCard(width: cardW, label: 'Total months', value: '$totalMonths'),
                _StatCard(width: cardW, label: 'Total net salary', value: _money(totalSalary)),
                _StatCard(width: cardW, label: 'Disbursed', value: _money(totalDisbursed)),
                _StatCard(width: cardW, label: 'Pending', value: _money(totalPending)),
                _StatCard(width: cardW, label: 'Requested (count)', value: '${counts.requested}'),
                _StatCard(width: cardW, label: 'Disbursed (count)', value: '${counts.disbursed}'),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  const _StatCard({required this.width, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 96,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardB),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _green, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _green, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

/* =================== Payslip card =================== */

class _PayslipCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _PayslipCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final period = (m['period'] ?? '').toString();
    final gross = _num(m['grossSalary']);
    final bonus = _num(m['bonus']);
    final loan  = _num(m['loanDeduction'] ?? m['loanDeductionTotal']); // support both field names
    final net   = _num(m['netSalary']);
    final st    = (m['status'] ?? 'pending').toString();
    final ts    = m['generatedAt'];
    DateTime? gen;
    if (ts is Timestamp) gen = ts.toDate();
    final when = gen != null ? DateFormat('yMMMd').format(gen) : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardB),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                period,
                style: const TextStyle(fontWeight: FontWeight.w800, color: _green),
              ),
            ),
            _StatusChip(status: st),
          ],
        ),
        subtitle: Text('Net: ${_money(net)}  •  Generated: $when'),
        children: [
          const Divider(height: 16),
          _RowLine(label: 'Gross salary', value: _money(gross)),
          _RowLine(label: 'Bonus', value: _money(bonus)),
          _RowLine(label: 'Loan deduction', value: _money(loan)),
          const SizedBox(height: 4),
          _RowLine(label: 'Net to receive', value: _money(net), bold: true),
          const SizedBox(height: 12),
          if (st == 'requested') _ActionRowRequested(docId: doc.id, data: m),
          if (st == 'disbursed') _DisbursedAtLine(ts: m['disbursedAt']),
        ],
      ),
    );
  }
}

class _ActionRowRequested extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _ActionRowRequested({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            onPressed: () async {
              await _accept(docId, data);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Disbursement accepted')),
                );
              }
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _green),
              foregroundColor: _green,
            ),
            onPressed: () async {
              final note = await _askNote(context);
              if (note == null) return;
              await _reject(docId, data, note);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Rejection sent to HR')),
                );
              }
            },
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
          ),
        ),
      ],
    );
  }

  static Future<void> _accept(String id, Map<String, dynamic> m) async {
    final db = FirebaseFirestore.instance;

    // mark payroll disbursed
    await db.collection('payrolls').doc(id).update({
      'status': 'disbursed',
      'disbursedAt': FieldValue.serverTimestamp(),
    });

    // flip the related request notification to acknowledged (if present)
    final reqId = (m['requestId'] ?? '').toString();
    if (reqId.isNotEmpty) {
      await db.collection('notifications').doc(reqId).set(
        {
          'status': 'acknowledged',
          'respondedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    // Optionally, create a confirmation notification
    final user = FirebaseAuth.instance.currentUser;
    await db.collection('notifications').add({
      'type': 'payslip_disbursed',
      'toUid': user?.uid,
      'toEmail': user?.email,
      'title': 'Salary disbursed',
      'body': 'Your salary for ${m['period']} has been marked disbursed.',
      'payrollId': id,
      'period': m['period'],
      'amount': m['netSalary'],
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _reject(String id, Map<String, dynamic> m, String note) async {
    final db = FirebaseFirestore.instance;

    // move back to pending & note it
    await db.collection('payrolls').doc(id).set({
      'status': 'pending',
      'requestId': null,
      'rejectionNote': note,
      'rejectedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Notify HR (you can filter these by type + no toUid to route to HR inbox)
    final user = FirebaseAuth.instance.currentUser;
    await db.collection('notifications').add({
      'type': 'payslip_rejected',
      'fromUid': user?.uid,
      'fromEmail': user?.email,
      'title': 'Payslip rejected',
      'body': 'The employee rejected the disbursement for ${m['period']}. Note: $note',
      'payrollId': id,
      'period': m['period'],
      'amount': m['netSalary'],
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<String?> _askNote(BuildContext context) async {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reason (optional)'),
        content: TextField(
          controller: ctl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write a short note to HR…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}

class _DisbursedAtLine extends StatelessWidget {
  final dynamic ts;
  const _DisbursedAtLine({required this.ts});

  @override
  Widget build(BuildContext context) {
    DateTime? d;
    if (ts is Timestamp) d = ts.toDate();
    final when = d != null ? DateFormat('yMMMd • h:mm a').format(d) : '—';
    return Align(
      alignment: Alignment.centerLeft,
      child: Text('Disbursed at: $when',
          style: const TextStyle(color: Colors.black54, fontSize: 12)),
    );
  }
}

/* =================== tiny UI helpers =================== */

class _RowLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _RowLine({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: _green,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get _bgColor {
    switch (status) {
      case 'disbursed':
        return Colors.green.withOpacity(.12);
      case 'requested':
        return Colors.amber.withOpacity(.18);
      default:
        return Colors.black12;
    }
  }

  Color get _fgColor {
    switch (status) {
      case 'disbursed':
        return Colors.green.shade800;
      case 'requested':
        return Colors.amber.shade900;
      default:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _fgColor.withOpacity(.3)),
      ),
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.w900, color: _fgColor, fontSize: 12)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Text('No payslips yet.',
            style: TextStyle(color: _green, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/* =================== utils =================== */

String _money(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final r = s.length - i;
    b.write(s[i]);
    if (r > 1 && r % 3 == 1) b.write(',');
  }
  return '৳$b';
}

num _num(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
  return 0;
}
