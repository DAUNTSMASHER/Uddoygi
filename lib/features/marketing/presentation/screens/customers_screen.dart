import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'package:uddoygi/services/local_storage_service.dart';

// If you already have your own summary widget, keep this import (unused now):
// import 'package:uddoygi/features/marketing/presentation/widgets/customer_order_summary.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String? userId;
  String? email;
  bool isLoading = true;

  // Palette (align with your dashboards)
  static const Color _brandTeal  = Color(0xFF001863);
  static const Color _indigoCard = Color(0xFF0B2D9F);
  static const Color _surface    = Color(0xFFF4FBFB);

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final session = await LocalStorageService.getSession();
      if (!mounted) return;

      setState(() {
        userId = session?['uid'];
        email  = session?['email'];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load session: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          title: const Text('Customer Management', style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: _brandTeal, foregroundColor: Colors.white, elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (userId == null || email == null) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          title: const Text('Customer Management', style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: _brandTeal, foregroundColor: Colors.white, elevation: 0,
        ),
        body: Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No active session found.'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadSession, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('Customer Management', style: TextStyle(fontWeight: FontWeight.w800)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_brandTeal, _indigoCard],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: const TabBar(
            indicatorWeight: 3,
            indicatorColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            tabs: [
              Tab(text: 'All Customers', icon: Icon(Icons.people_alt)),
              Tab(text: 'Add Customer', icon: Icon(Icons.person_add_alt_1)),
              Tab(text: 'Orders Summary', icon: Icon(Icons.receipt_long)),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _CustomerListTab(ownerEmail: email!),                    // ✅ only this agent’s customers
              _AddCustomerFormTab(ownerEmail: email!, ownerUid: userId!),
              _OrderSummaryTab(ownerEmail: email!),                    // ✅ only this agent’s orders
            ],
          ),
        ),
      ),
    );
  }
}

/* ========================= All Customers (with avatars) ========================= */

class _CustomerListTab extends StatefulWidget {
  final String ownerEmail;
  const _CustomerListTab({required this.ownerEmail});

  @override
  State<_CustomerListTab> createState() => _CustomerListTabState();
}

class _CustomerListTabState extends State<_CustomerListTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('customers')
        .where('ownerEmail', isEqualTo: widget.ownerEmail) // ✅ filter by logged-in user
        .orderBy('createdAt', descending: true);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search name, phone, email…',
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
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs.where((d) {
                if (_search.isEmpty) return true;
                final m = d.data();
                bool contains(Object? v) =>
                    v != null && v.toString().toLowerCase().contains(_search);
                return contains(m['name']) ||
                    contains(m['email']) ||
                    contains(m['phone']) ||
                    contains(m['address']);
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text('No customers yet.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final m = d.data();
                  final name = (m['name'] ?? 'Unnamed').toString();
                  final email = (m['email'] ?? '').toString();
                  final phone = (m['phone'] ?? '').toString();
                  final photo = (m['photoUrl'] ?? '').toString();

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 1,
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: _avatar(photo, name),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (email.isNotEmpty) Text(email),
                          if (phone.isNotEmpty) Text(phone),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showCustomerSheet(context, d.id, m),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _avatar(String photoUrl, String name) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(radius: 24, backgroundImage: NetworkImage(photoUrl));
    }
    final init = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.indigo.shade100,
      child: Text(init, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo)),
    );
  }

  void _showCustomerSheet(BuildContext context, String id, Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              if ((m['photoUrl'] ?? '').toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(m['photoUrl'], height: 140, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 12),
              Text(
                (m['name'] ?? 'Unnamed').toString(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.indigo),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [
                  _chip(Icons.email, (m['email'] ?? '').toString()),
                  _chip(Icons.phone, (m['phone'] ?? '').toString()),
                  _chip(Icons.home, (m['address'] ?? '').toString()),
                  _chip(Icons.info_outline, (m['notes'] ?? '').toString()),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('customers').doc(id).delete();
                        if (context.mounted) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Customer deleted')),
                        );
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to per-customer orders for this agent only
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _CustomerOrdersPage(
                              ownerEmail: widget.ownerEmail,
                              customerId: id,
                              customerName: (m['name'] ?? '').toString(),
                              customerEmail: (m['email'] ?? '').toString(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View Orders'),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.black87),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/* ========================= Orders Summary (PER-AGENT) =========================
   Aggregates invoices for only the logged-in user (ownerEmail).
   Assumed collection: 'invoices' with fields:
     - ownerEmail (agent email who owns the order)   ✅ filter here
     - customerId | customerEmail | customerName     🔑 matching keys (best-effort)
     - total (numeric) OR items[] with qty & unitPrice (fallback)
     - createdAt (Timestamp) for last order
===============================================================================*/

class _OrderSummaryTab extends StatelessWidget {
  final String ownerEmail;
  const _OrderSummaryTab({required this.ownerEmail});

  num _extractTotal(Map<String, dynamic> inv) {
    final t = inv['total'];
    if (t is num) return t;
    // Fallback: compute from items[]
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

  String _keyForInvoice(Map<String, dynamic> inv) {
    // Prefer stable customerId if present, else email, else name
    if ((inv['customerId'] ?? '').toString().isNotEmpty) return 'id:${inv['customerId']}';
    if ((inv['customerEmail'] ?? '').toString().isNotEmpty) return 'em:${(inv['customerEmail']).toString().toLowerCase()}';
    if ((inv['customerName'] ?? '').toString().isNotEmpty) return 'nm:${inv['customerName']}';
    return 'unknown';
  }

  String _keyForCustomer(DocumentSnapshot<Map<String, dynamic>> c) {
    final m = c.data()!;
    if ((m['email'] ?? '').toString().isNotEmpty) return 'em:${m['email'].toString().toLowerCase()}';
    return 'id:${c.id}';
  }

  @override
  Widget build(BuildContext context) {
    final customersQ = FirebaseFirestore.instance
        .collection('customers')
        .where('ownerEmail', isEqualTo: ownerEmail);

    final invoicesQ = FirebaseFirestore.instance
        .collection('invoices')
        .where('ownerEmail', isEqualTo: ownerEmail) // ✅ key filter: only this agent’s orders
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: customersQ.snapshots(),
      builder: (context, custSnap) {
        if (!custSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final customers = custSnap.data!.docs;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: invoicesQ.snapshots(),
          builder: (context, invSnap) {
            if (!invSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final invoices = invSnap.data!.docs;

            // Build quick lookup for customers
            final Map<String, DocumentSnapshot<Map<String, dynamic>>> customerByKey = {};
            for (final c in customers) {
              customerByKey[_keyForCustomer(c)] = c;
            }

            // Aggregate by customer key
            final Map<String, _CustAgg> agg = {};
            for (final d in invoices) {
              final m = d.data();
              final key = _keyForInvoice(m);
              final total = _extractTotal(m);
              final createdAt = (m['createdAt'] is Timestamp) ? (m['createdAt'] as Timestamp).toDate() : null;

              final a = agg.putIfAbsent(key, () => _CustAgg());
              a.orderCount += 1;
              a.totalAmount += total;
              if (createdAt != null && (a.lastOrderAt == null || createdAt.isAfter(a.lastOrderAt!))) {
                a.lastOrderAt = createdAt;
              }
            }

            // Build rows joined with customer info where possible
            final rows = <_SummaryRow>[];
            agg.forEach((key, a) {
              String displayName = 'Unknown Customer';
              String? email;
              String? customerId;
              // If a matching customer exists, use its info
              if (customerByKey.containsKey(key)) {
                final c = customerByKey[key]!;
                final m = c.data()!;
                displayName = (m['name'] ?? 'Unnamed').toString();
                email = (m['email'] ?? '').toString();
                customerId = c.id;
              } else {
                // Try to pull name/email from invoices for display
                // find one invoice for this key
                final first = invoices.firstWhere(
                      (x) => _keyForInvoice(x.data()) == key,
                  orElse: () => invoices.first,
                );
                final im = first.data();
                displayName = (im['customerName'] ?? displayName).toString();
                email = (im['customerEmail'] ?? '').toString();
                if (key.startsWith('id:')) customerId = key.substring(3);
              }

              rows.add(_SummaryRow(
                customerKey: key,
                customerId: customerId,
                customerName: displayName,
                customerEmail: email,
                orders: a.orderCount,
                total: a.totalAmount,
                lastOrderAt: a.lastOrderAt,
              ));
            });

            rows.sort((a,b){
              final ad = a.lastOrderAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bd = b.lastOrderAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });

            if (rows.isEmpty) {
              return const Center(child: Text('No orders found for your customers.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: rows.length,
              itemBuilder: (context, i) { // <- use context, not _
                final r = rows[i];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                  child: ListTile(
                    title: Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((r.customerEmail ?? '').isNotEmpty) Text(r.customerEmail!),
                        Text('Orders: ${r.orders} • Total: ${r.total.toStringAsFixed(2)}'),
                        if (r.lastOrderAt != null)
                          Text('Last: ${r.lastOrderAt!.toIso8601String().split("T").first}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _CustomerOrdersPage(
                            ownerEmail: ownerEmail,
                            customerId: r.customerId,
                            customerName: r.customerName,
                            customerEmail: r.customerEmail,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );

          },
        );
      },
    );
  }

  String _fmtCurrency(num v) {
    // Keep simple; integrate intl if you prefer
    return v.toStringAsFixed(2);
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4,'0');
    final m = d.month.toString().padLeft(2,'0');
    final da = d.day.toString().padLeft(2,'0');
    return '$y-$m-$da';
  }
}

class _CustAgg {
  int orderCount = 0;
  num totalAmount = 0;
  DateTime? lastOrderAt;
}

class _SummaryRow {
  final String customerKey;
  final String? customerId;
  final String customerName;
  final String? customerEmail;
  final int orders;
  final num total;
  final DateTime? lastOrderAt;

  _SummaryRow({
    required this.customerKey,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.orders,
    required this.total,
    required this.lastOrderAt,
  });
}

/* ========================= Per-Customer Orders Page (PER-AGENT) ========================= */

class _CustomerOrdersPage extends StatelessWidget {
  final String ownerEmail;
  final String? customerId;
  final String customerName;
  final String? customerEmail;

  const _CustomerOrdersPage({
    required this.ownerEmail,
    required this.customerName,
    this.customerEmail,
    this.customerId,
  });

  bool _matchesCustomer(Map<String, dynamic> m) {
    // We stream all invoices for this agent and then filter locally to
    // avoid multi-OR Firestore queries.
    final idOk = (customerId != null && (m['customerId'] ?? '') == customerId);
    final emOk = (customerEmail != null && customerEmail!.isNotEmpty &&
        (m['customerEmail'] ?? '').toString().toLowerCase() == customerEmail!.toLowerCase());
    final nameOk = (m['customerName'] ?? '') == customerName;
    return idOk || emOk || nameOk;
  }

  num _extractTotal(Map<String, dynamic> inv) {
    final t = inv['total'];
    if (t is num) return t;
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
    final y = d.year.toString().padLeft(4,'0');
    final m = d.month.toString().padLeft(2,'0');
    final da = d.day.toString().padLeft(2,'0');
    return '$y-$m-$da';
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('invoices')
        .where('ownerEmail', isEqualTo: ownerEmail)       // ✅ only this agent
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text('Orders • $customerName'),
        backgroundColor: const Color(0xFF001863),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!.docs;
          final mine = all.where((d) => _matchesCustomer(d.data())).toList();

          if (mine.isEmpty) {
            return const Center(child: Text('No orders for this customer.'));
          }

          num total = 0;
          for (final d in mine) {
            total += _extractTotal(d.data());
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B2D9F), Color(0xFF1D5DF1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Text(
                  'Total Orders: ${mine.length}   •   Total Amount: ${total.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: mine.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final inv = mine[i].data();
                    final amt = _extractTotal(inv).toStringAsFixed(2);
                    final createdAt = (inv['createdAt'] is Timestamp)
                        ? (inv['createdAt'] as Timestamp).toDate()
                        : null;
                    final id = mine[i].id;
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: ListTile(
                        title: Text('Invoice #$id', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (createdAt != null) Text('Date: ${_fmtDate(createdAt)}'),
                            if ((inv['status'] ?? '').toString().isNotEmpty) Text('Status: ${inv['status']}'),
                          ],
                        ),
                        trailing: Text(amt, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ========================= Add Customer (with photo) ========================= */

class _AddCustomerFormTab extends StatefulWidget {
  final String ownerEmail;
  final String ownerUid;
  const _AddCustomerFormTab({required this.ownerEmail, required this.ownerUid});

  @override
  State<_AddCustomerFormTab> createState() => _AddCustomerFormTabState();
}

class _AddCustomerFormTabState extends State<_AddCustomerFormTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  XFile? _picked;
  bool _uploading = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final img = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    if (img != null && mounted) {
      setState(() => _picked = img);
    }
  }

  Future<String?> _uploadToStorage(XFile file) async {
    try {
      setState(() => _uploading = true);
      final path = 'customers/${widget.ownerUid}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = FirebaseStorage.instance.ref(path);

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final metadata = SettableMetadata(contentType: 'image/jpeg');
        await ref.putData(bytes, metadata);
      } else {
        await ref.putFile(File(file.path));
      }

      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    String? photoUrl;
    if (_picked != null) {
      photoUrl = await _uploadToStorage(_picked!);
      if (photoUrl == null) return; // upload error already shown
    }

    try {
      await FirebaseFirestore.instance.collection('customers').add({
        'ownerEmail': widget.ownerEmail,  // ✅ tie customer to logged-in user
        'ownerUid': widget.ownerUid,
        'name': _nameCtl.text.trim(),
        'email': _emailCtl.text.trim(),
        'phone': _phoneCtl.text.trim(),
        'address': _addressCtl.text.trim(),
        'notes': _notesCtl.text.trim(),
        'photoUrl': photoUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer added')),
      );
      setState(() {
        _nameCtl.clear();
        _emailCtl.clear();
        _phoneCtl.clear();
        _addressCtl.clear();
        _notesCtl.clear();
        _picked = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Header gradient card
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF0B2D9F), Color(0xFF1D5DF1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: const Text(
            'Add a new customer profile with photo, contact details, and notes.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.3, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 14),

        // Photo picker
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.indigo.shade100,
                backgroundImage: _picked == null ? null : (kIsWeb
                    ? NetworkImage(_picked!.path) as ImageProvider
                    : FileImage(File(_picked!.path))),
                child: _picked == null
                    ? const Icon(Icons.person, size: 44, color: Colors.indigo)
                    : null,
              ),
              Positioned(
                right: 0, bottom: 0,
                child: InkWell(
                  onTap: _uploading ? null : _pickImage,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(_picked == null ? Icons.add_a_photo : Icons.edit, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Form
        Form(
          key: _formKey,
          child: Column(
            children: [
              _field(
                controller: _nameCtl,
                label: 'Full Name',
                icon: Icons.person,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              _field(
                controller: _emailCtl,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              _field(
                controller: _phoneCtl,
                label: 'Phone',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              _field(
                controller: _addressCtl,
                label: 'Address',
                icon: Icons.home,
                maxLines: 2,
              ),
              _field(
                controller: _notesCtl,
                label: 'Notes',
                icon: Icons.note_alt,
                maxLines: 3,
              ),
              const SizedBox(height: 6),
              if (_uploading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(minHeight: 4),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _submit,
                  icon: _uploading
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save, color: Colors.white),
                  label: Text(_uploading ? 'Uploading…' : 'Save Customer',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001863),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
