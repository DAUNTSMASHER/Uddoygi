import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/local_storage_service.dart';

import 'package:uddoygi/features/marketing/presentation/widgets/customer_list_view.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/add_customer_form.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/customer_order_summary.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _bg       = Color(0xFFF7F9FC);
const Color _primary  = Color(0xFF2563EB);
const Color _primaryDk= Color(0xFF1E3A8A);
const Color _card     = Color(0xFFFFFFFF);
const Color _border   = Color(0x14000000);
const Color _fg       = Color(0xFF0F172A);
const Color _muted    = Color(0xFF94A3B8);

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String? userId;
  String? email;
  bool isLoading = true;
  int _tab = 0;

  static const _titles = ['Customers', 'Add Customer', 'Order Summary'];

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
        userId    = session?['uid'];
        email     = session?['email'];
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _appBar('Customer Management'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (userId == null || email == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _appBar('Customer Management'),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_off_rounded, color: _primary, size: 28),
                ),
                const SizedBox(height: 16),
                Text('Session not found',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 16, color: _fg)),
                const SizedBox(height: 6),
                Text('Please log in again to continue.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: _muted, fontSize: 13)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: _loadSession,
                    child: Text('Retry',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = <Widget>[
      CustomerListView(userId: userId!, email: email!),
      AddCustomerForm(userId: userId!, email: email!),
      CustomerOrderSummary(email: email!),
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(_titles[_tab]),
      body: SafeArea(
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }

  AppBar _appBar(String title) {
    return AppBar(
      elevation: 0,
      backgroundColor: _primaryDk,
      foregroundColor: Colors.white,
      title: Text(title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_primary, _primaryDk],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _primaryDk,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.12),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: current,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: _primaryDk,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          showUnselectedLabels: true,
          selectedLabelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded),
              label: 'Customers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_add_alt_1_rounded),
              label: 'Add',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'Summary',
            ),
          ],
        ),
      ),
    );
  }
}
