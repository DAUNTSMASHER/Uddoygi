import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'add_payroll_screen.dart';
import 'review_payroll_screen.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────
final _money      = UddoygiDesign.moneyFormat;
const _brandGreen = Color(0xFF065F46);

// ─────────────────────────────────────────────────────────────────────────────
class PayrollOverviewScreen extends StatefulWidget {
  const PayrollOverviewScreen({super.key});
  @override
  State<PayrollOverviewScreen> createState() => _PayrollOverviewScreenState();
}

class _PayrollOverviewScreenState extends State<PayrollOverviewScreen> {
  String _cid = '';
  String _search = '';
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final period = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Payroll Hub', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: _brandGreen), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPayrollScreen()))),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPayrollScreen())),
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Entry', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(UddoygiDesign.space20),
              children: [
                if (uid != null) _MySalaryHero(cid: _cid, uid: uid, period: period).animate().fadeIn().slideX(begin: -0.1, end: 0),
                const SizedBox(height: 20),
                _CompanyRunSection(cid: _cid, period: period).animate().fadeIn().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Employee Registry', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    Text(period, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                _SearchBox(controller: _searchCtl, onChanged: (v) => setState(() => _search = v)),
                const SizedBox(height: 16),
                _EmployeeList(cid: _cid, period: period, search: _search),
              ],
            ),
    );
  }
}

class _MySalaryHero extends StatelessWidget {
  final String cid, uid, period;
  const _MySalaryHero({required this.cid, required this.uid, required this.period});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(cid, C.payrolls).where('employeeUid', isEqualTo: uid).where('period', isEqualTo: period).limit(1).snapshots(),
      builder: (ctx, snap) {
        final d = snap.data?.docs.firstOrNull?.data();
        final net = (d?['netSalary'] ?? 0).toDouble();
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_brandGreen, Color(0xFF052E16)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: _brandGreen.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MY NET SALARY', style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(DateFormat('MMM').format(DateTime.now()).toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                ],
              ),
              const SizedBox(height: 12),
              Text('৳ ${_money.format(net)}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              Row(
                children: [
                  _HeroMeta(label: 'Status', value: d?['status']?.toString().toUpperCase() ?? 'PENDING'),
                  const Spacer(),
                  TextButton(onPressed: () {}, style: TextButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _brandGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16)), child: Text('VIEW SLIP', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final String label, value;
  const _HeroMeta({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700)),
      Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
    ],
  );
}

class _CompanyRunSection extends StatelessWidget {
  final String cid, period;
  const _CompanyRunSection({required this.cid, required this.period});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(cid, C.payrolls).where('period', isEqualTo: period).snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        double total = 0;
        int paid = 0;
        for (var d in docs) {
          total += (d.data()['netSalary'] ?? 0).toDouble();
          if (d.data()['status'] == 'disbursed') paid++;
        }
        return UCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.business_center_rounded, color: _brandGreen, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Corporate Payroll Run', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                        Text('${docs.length} Employees • $paid Disbursed', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL DISBURSEMENT', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[400])),
                      Text('৳ ${_money.format(total)}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                    ],
                  ),
                  IconButton.filled(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewPayrollScreen())), icon: const Icon(Icons.chevron_right_rounded), style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9), foregroundColor: _brandGreen)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBox({required this.controller, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: 'Search by employee name or role...',
      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.withOpacity(0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.withOpacity(0.1))),
    ),
  );
}

class _EmployeeList extends StatelessWidget {
  final String cid, period, search;
  const _EmployeeList({required this.cid, required this.period, required this.search});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(cid, C.payrolls).where('period', isEqualTo: period).snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        final filtered = docs.where((d) => d.data()['employeeName'].toString().toLowerCase().contains(search.toLowerCase())).toList();
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) => _EmployeeRow(data: filtered[i].data(), docId: filtered[i].id).animate().fadeIn(delay: (i * 50).ms),
        );
      },
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  const _EmployeeRow({required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.05))),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: _brandGreen.withOpacity(0.1), child: Text(data['employeeName']?[0] ?? '?', style: GoogleFonts.outfit(color: _brandGreen, fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['employeeName'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800)),
                Text(data['department'] ?? 'General', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('৳ ${_money.format(data['netSalary'] ?? 0)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: _brandGreen)),
              Text(status.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: status == 'disbursed' ? Colors.green : Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
