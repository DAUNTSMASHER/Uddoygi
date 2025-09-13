// lib/features/customers/presentation/customer_list_view.dart
//
// UI + per-customer order snapshot (compact) — SYNCED with
// CustomerDetailsPage(customerId: ...) API
// ------------------------------------------------------------
// • Polished cards (Google Fonts)
// • Country flag avatar (circle_flags) when `countryCode` exists
// • Email/phone chips
// • Per-customer “Order update” row (count, last date, total)
// • Receipt icon ➜ CustomerOrderSummary(email) (snackbar if no email)
// • Tap or Edit ➜ CustomerDetailsPage(customerId, customerEmailHint)
// • Delete with confirmation
// ------------------------------------------------------------
//
// pubspec.yaml deps:
//   google_fonts: ^6.2.1
//   circle_flags: ^3.0.1

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:circle_flags/circle_flags.dart';

import 'customer_order_summary.dart';
import 'customer_details.dart';

class CustomerListView extends StatelessWidget {
  final String userId;
  final String email; // agent email

  const CustomerListView({
    super.key,
    required this.userId,
    required this.email,
  });

  String _extractAgentName(String email) {
    final namePart = email.split('@')[0];
    return namePart
        .split('.')
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final agentName = _extractAgentName(email);

    return Scaffold(

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .where('agentName', isEqualTo: agentName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching customers.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No customers found.'));
          }

          final customers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];

              final data = customer.data() as Map<String, dynamic>;
              final name = (data['name'] ?? 'No Name').toString();
              final customerEmail = data.containsKey('email') ? (data['email'] ?? '').toString().trim() : '';
              final phone = data.containsKey('phone') ? (data['phone'] ?? 'No Phone').toString() : 'No Phone';
              final address = data.containsKey('address') ? (data['address'] ?? 'No Address').toString() : 'No Address';
              final agent = data.containsKey('agentName') ? (data['agentName'] ?? 'Unknown Agent').toString() : 'Unknown Agent';
              final country = (data['country'] ?? '').toString();
              final countryCode = (data['countryCode'] ?? '').toString().toUpperCase();

              void _openDetails() {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailsPage(
                      customerId: customer.id,
                      customerEmailHint: customerEmail.isEmpty ? null : customerEmail,
                    ),
                  ),
                );
              }

              return Card(
                elevation: 1.5,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openDetails, // quick open full profile
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row: avatar/flag + name + quick actions
                        Row(
                          children: [
                            // Flag avatar (falls back to initials)
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFEAF2FF),
                              ),
                              alignment: Alignment.center,
                              child: (countryCode.length == 2)
                                  ? ClipOval(child: CircleFlag(countryCode, size: 44))
                                  : Text(
                                _initials(name),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.blueGrey.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // Country (small)
                                  Row(
                                    children: [
                                      Icon(Icons.public, size: 14, color: Colors.blueGrey.shade400),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          country.isEmpty ? '—' : country,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.blueGrey.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Actions:
                            // 1) Receipt ➜ per-customer summary (requires email)
                            IconButton(
                              icon: const Icon(Icons.receipt_long),
                              tooltip: 'Order Summary (this customer)',
                              onPressed: () {
                                if (customerEmail.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('No email set for this customer. Add an email to view order summary.'),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomerOrderSummary(email: customerEmail),
                                  ),
                                );
                              },
                            ),
                            // 2) Edit ➜ open profile (by id, with email hint)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit Customer',
                              onPressed: _openDetails,
                            ),
                            // 3) Delete ➜ confirm then remove doc
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete Customer',
                              onPressed: () async {
                                final ok = await _confirmDelete(context, name);
                                if (ok != true) return;
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('customers')
                                      .doc(customer.id)
                                      .delete();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Deleted "$name"')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Delete failed: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Per-customer ORDER UPDATE (compact live snapshot)
                        if (customerEmail.isNotEmpty)
                          _PerCustomerOrdersRow(
                            agentEmail: email,
                            customerEmail: customerEmail,
                          ),

                        const SizedBox(height: 10),

                        // Info chips row
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (customerEmail.isNotEmpty)
                              _chip(
                                icon: Icons.alternate_email,
                                label: customerEmail,
                                tooltip: 'Email',
                              ),
                            _chip(
                              icon: Icons.phone_outlined,
                              label: phone,
                              tooltip: 'Phone',
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        // Address line
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.place_outlined, size: 16, color: Colors.blueGrey.shade400),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                address,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.blueGrey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        // Footer meta
                        Row(
                          children: [
                            Icon(Icons.badge_outlined, size: 14, color: Colors.blueGrey.shade400),
                            const SizedBox(width: 6),
                            Text(
                              'Agent: $agent',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.blueGrey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Confirm dialog
  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Small UI helper for info chips
  Widget _chip({required IconData icon, required String label, String? tooltip}) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.blue.shade800),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label.isEmpty ? '—' : label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.blue.shade900,
            ),
          ),
        ),
      ],
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: tooltip == null ? child : Tooltip(message: tooltip, child: child),
    );
  }
}

/// Compact, live per-customer order summary row
/// - Orders count
/// - Last order date
/// - Total amount (sum of grandTotal or total)
class _PerCustomerOrdersRow extends StatelessWidget {
  final String agentEmail;     // current agent
  final String customerEmail;  // this card's customer

  const _PerCustomerOrdersRow({
    required this.agentEmail,
    required this.customerEmail,
  });

  num _extractTotal(Map<String, dynamic> inv) {
    final gt = inv['grandTotal'];
    if (gt is num) return gt;
    final t = inv['total'];
    if (t is num) return t;
    // fallback: items * unitPrice when present
    final items = inv['items'];
    if (items is List) {
      num sum = 0;
      for (final it in items) {
        if (it is Map) {
          final q = (it['qty'] is num) ? it['qty'] as num : num.tryParse('${it['qty']}') ?? 0;
          final up = (it['unitPrice'] is num) ? it['unitPrice'] as num : num.tryParse('${it['unitPrice']}') ?? 0;
          sum += q * up;
        }
      }
      return sum;
    }
    return 0;
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }

  @override
  Widget build(BuildContext context) {
    // Per-customer invoices for THIS agent
    final q = FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: agentEmail)
        .where('customerEmail', isEqualTo: customerEmail);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(minHeight: 3),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _pillRow(
            children: const [
              _StatPill(icon: Icons.shopping_bag_outlined, label: 'Orders', value: '0'),
              _StatPill(icon: Icons.event_outlined, label: 'Last', value: '—'),
              _StatPill(icon: Icons.attach_money, label: 'Total', value: '0'),
            ],
          );
        }

        final docs = snap.data!.docs;
        int count = docs.length;
        num total = 0;
        DateTime? last;

        for (final d in docs) {
          final m = d.data();
          total += _extractTotal(m);
          final created = (m['createdAt'] is Timestamp)
              ? (m['createdAt'] as Timestamp).toDate()
              : (m['timestamp'] is Timestamp)
              ? (m['timestamp'] as Timestamp).toDate()
              : null;
          if (created != null && (last == null || created.isAfter(last!))) {
            last = created;
          }
        }

        return _pillRow(
          children: [
            _StatPill(icon: Icons.shopping_bag_outlined, label: 'Orders', value: '$count'),
            _StatPill(icon: Icons.event_outlined, label: 'Last', value: last == null ? '—' : _fmtDate(last!)),
            _StatPill(icon: Icons.attach_money, label: 'Total', value: total.toStringAsFixed(0)),
          ],
        );
      },
    );
  }

  Widget _pillRow({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(children: children),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label: $value',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.blueGrey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
