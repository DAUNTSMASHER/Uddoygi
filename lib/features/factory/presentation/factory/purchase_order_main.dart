import 'package:flutter/material.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/core/responsive.dart';
import 'package:uddoygi/features/factory/presentation/factory/po_overview_screen.dart';
import 'package:uddoygi/features/factory/presentation/factory/po_list_screen.dart';
import 'package:uddoygi/features/factory/presentation/factory/po_status_tracker.dart';

class PurchaseOrderMainScreen extends StatefulWidget {
  const PurchaseOrderMainScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseOrderMainScreen> createState() => _PurchaseOrderMainScreenState();
}

class _PurchaseOrderMainScreenState extends State<PurchaseOrderMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    POOverviewScreen(),
    POListScreen(),
    POStatusTrackerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      body: _pages[_currentIndex],
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4)),
            ],
          ),
          child: SizedBox(
            height: 40,
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              backgroundColor: Colors.white,
              elevation: 0,
              iconSize: 16,
              selectedLabelStyle: AppFonts.banglaBody(fontWeight: FontWeight.w800, fontSize: 9),
              unselectedLabelStyle: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 9),
              selectedItemColor: const Color(0xFFBA002E),
              unselectedItemColor: const Color(0xFF5A413D),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'List'),
                BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Status'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
