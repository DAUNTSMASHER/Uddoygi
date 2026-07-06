import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:circle_flags/circle_flags.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

import 'package:uddoygi/features/marketing/presentation/widgets/add_customer_form.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/customer_details.dart';
import 'package:uddoygi/features/marketing/presentation/screens/new_invoices_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color _bg = Color(0xFFF7F9FC);
const Color _primary = Color(0xFF2563EB);
const Color _primaryDk = Color(0xFF1E3A8A);
const Color _fg = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _border = Color(0xFFE2E8F0);

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _cid = '';
  String? userId;
  String? email;
  bool isLoading = true;
  String searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await LocalStorageService.getSavedCompanyId();
    final session = await LocalStorageService.getSession();
    if (!mounted) return;
    setState(() {
      _cid = id ?? '';
      userId = session?['uid'] ?? FirebaseAuth.instance.currentUser?.uid;
      email = session?['email'] ?? FirebaseAuth.instance.currentUser?.email;
      isLoading = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (userId == null || email == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(title: const Text('Customers'), backgroundColor: _primaryDk),
        body: const Center(child: Text('Session not found. Please log in again.')),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryDk,
        foregroundColor: Colors.white,
        title: Text('Customers', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primaryDk],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add Customer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: Text('Add Customer', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      backgroundColor: _primaryDk,
                      foregroundColor: Colors.white,
                    ),
                    backgroundColor: _bg,
                    body: AddCustomerForm(userId: userId!, email: email!),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _cid.isEmpty 
                  ? const Stream.empty() 
                  : DB.colSync(_cid, C.customers).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _primary));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading customers: ${snapshot.error}'));
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  final emailField = (data['email'] ?? '').toString().toLowerCase();
                  final q = searchQuery.toLowerCase();
                  return name.contains(q) || phone.contains(q) || emailField.contains(q);
                }).toList();
                
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return CustomerCard(
                      doc: filtered[index], 
                      cid: _cid, 
                      agentEmail: email!,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: TextField(
        onChanged: (val) => setState(() => searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search by name, phone or email...',
          hintStyle: GoogleFonts.inter(color: _muted),
          prefixIcon: const Icon(Icons.search, color: _muted),
          filled: true,
          fillColor: _bg,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: _muted.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty ? 'No customers yet.' : 'No matches found.',
            style: GoogleFonts.inter(fontSize: 16, color: _muted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class CustomerCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String cid;
  final String agentEmail;

  const CustomerCard({super.key, required this.doc, required this.cid, required this.agentEmail});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? 'Unknown').toString();
    final customerEmail = (data['email'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();
    final country = (data['country'] ?? 'Not specified').toString();
    final countryCode = (data['countryCode'] ?? '').toString().toUpperCase();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerDetailsPage(
                customerId: doc.id,
                customerEmailHint: customerEmail.isEmpty ? null : customerEmail,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEFF6FF)),
                    alignment: Alignment.center,
                    child: (countryCode.length == 2)
                        ? ClipOval(child: CircleFlag(countryCode, size: 48))
                        : Text(_initials(name), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: _primary)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _fg)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.public, size: 14, color: _muted),
                            const SizedBox(width: 4),
                            Expanded(child: Text(country, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: _muted))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (customerEmail.isNotEmpty)
                    _CustomerStatsBadge(cid: cid, agentEmail: agentEmail, customerEmail: customerEmail),
                ],
              ),
              const SizedBox(height: 16),
              
              // Body Info
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: _primary),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Text(phone.isEmpty ? 'No phone' : phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14, color: _fg, fontWeight: FontWeight.w500)),
                  ),
                  if (customerEmail.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.email_outlined, size: 16, color: _primary),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Text(customerEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14, color: _fg, fontWeight: FontWeight.w500)),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 12),
              
              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: _muted, padding: const EdgeInsets.symmetric(horizontal: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                        label: Text('View Details', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailsPage(
                                customerId: doc.id,
                                customerEmailHint: customerEmail.isEmpty ? null : customerEmail,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: Text('Quick Invoice', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NewInvoicesScreen(
                            initialCustomerId: doc.id,
                            initialCustomerName: name,
                            initialCustomerEmail: customerEmail,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerStatsBadge extends StatelessWidget {
  final String cid;
  final String agentEmail;
  final String customerEmail;

  const _CustomerStatsBadge({required this.cid, required this.agentEmail, required this.customerEmail});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(cid, C.invoices)
          .where('agentEmail', isEqualTo: agentEmail)
          .where('customerEmail', isEqualTo: customerEmail)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        final count = docs.length;
        
        String type = 'Lead';
        Color color = Colors.orange.shade700;
        Color bgColor = Colors.orange.shade50;
        
        if (count == 1) {
          type = 'Confirmed';
          color = Colors.blue.shade700;
          bgColor = Colors.blue.shade50;
        } else if (count > 1) {
          type = 'Repeat Buyer';
          color = Colors.green.shade700;
          bgColor = Colors.green.shade50;
        }

        DateTime? last;
        for (final d in docs) {
          final m = d.data() as Map<String, dynamic>;
          final created = (m['createdAt'] is Timestamp)
              ? (m['createdAt'] as Timestamp).toDate()
              : (m['timestamp'] is Timestamp)
              ? (m['timestamp'] as Timestamp).toDate()
              : null;
          if (created != null && (last == null || created.isAfter(last))) {
            last = created;
          }
        }
        
        String lastDateStr = '';
        if (last != null) {
          lastDateStr = '\nLast: ${last.year}-${last.month.toString().padLeft(2, '0')}-${last.day.toString().padLeft(2, '0')}';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                type,
                style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$count Invoice${count > 1 ? 's' : ''}$lastDateStr',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(fontSize: 10, color: _muted, fontWeight: FontWeight.w500, height: 1.2),
              ),
            ],
          ],
        );
      },
    );
  }
}
