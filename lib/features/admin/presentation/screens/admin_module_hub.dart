import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/features/hr/presentation/screens/accounts_receivable_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/accounts_payable_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/general_ledger_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/payroll_overview_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/employee_directory_screen.dart';
import 'package:uddoygi/features/factory/presentation/screens/factory_dashboard.dart';
import 'package:uddoygi/features/marketing/presentation/screens/marketing_dashboard.dart';
import 'package:uddoygi/features/marketing/presentation/screens/all_invoices_screen.dart';
import 'package:uddoygi/features/rnd/presentation/screens/rnd_dashboard.dart';
import 'package:uddoygi/features/admin/presentation/screens/reports_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_orders_management_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_products_inventory_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_qc_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/company_monitoring_screen.dart';

class AdminModuleHub extends StatelessWidget {
  final String title;
  final String? orgId;
  final DateTimeRange range;
  final List<String> labels;

  const AdminModuleHub({
    super.key,
    required this.title,
    required this.orgId,
    required this.range,
    required this.labels,
  });

  static const _p1 = Color(0xFF2E1065);
  static const _p2 = Color(0xFF5B21B6);
  static const _p3 = Color(0xFF7C3AED);
  static const _bg = Color(0xFFF7F7FB);
  static const _border = Color(0xFFE7E9F3);
  static const _text = Color(0xFF0F172A);
  static const _text2 = Color(0xFF64748B);

  String _toBanglaTitle(String t) {
    switch (t.toUpperCase()) {
      case 'FINANCE':
      case 'FINANCE & ACCOUNTS':
        return 'অর্থ ও হিসাব ব্যবস্থাপনা';
      case 'MANUFACTURING':
      case 'FACTORY':
        return 'কারখানা ও উৎপাদন ব্যবস্থাপনা';
      case 'INVENTORY':
      case 'STOCK':
        return 'মজুদ ও ইনভেন্টরি';
      case 'AI INSIGHTS':
      case 'AI ANALYTICS':
        return 'এআই বিশ্লেষণ ও পূর্বাভাস';
      case 'HR & PAYROLL':
      case 'HR EFFICIENCY':
        return 'মানবসম্পদ ও বেতন ব্যবস্থাপনা';
      case 'SALES & MARKETING':
      case 'MARKETING':
        return 'বিক্রয় ও বিপণন';
      case 'QC & QUALITY':
      case 'QC':
        return 'মান নিয়ন্ত্রণ (QC)';
      case 'R&D':
      case 'RESEARCH':
        return 'গবেষণা ও উন্নয়ন (R&D)';
      default:
        return t;
    }
  }

  void _navigateToRealScreen(BuildContext context, String label) {
    HapticFeedback.selectionClick();
    Widget? targetScreen;

    final lower = label.toLowerCase();
    if (lower.contains('receivable') || lower.contains('পাওনা')) {
      targetScreen = const ExpensesScreen();
    } else if (lower.contains('payable') || lower.contains('দেনা')) {
      targetScreen = const AccountsPayableScreen();
    } else if (lower.contains('ledger') || lower.contains('খতিয়ান') || lower.contains('cash flow') || lower.contains('profit')) {
      targetScreen = const GeneralLedgerScreen();
    } else if (lower.contains('payroll') || lower.contains('বেতন') || lower.contains('salary')) {
      targetScreen = const PayrollOverviewScreen();
    } else if (lower.contains('employee') || lower.contains('কর্মী') || lower.contains('staff') || lower.contains('hr')) {
      targetScreen = const EmployeeDirectoryScreen();
    } else if (lower.contains('factory') || lower.contains('production') || lower.contains('উৎপাদন') || lower.contains('manufacturing')) {
      targetScreen = const FactoryDashboard();
    } else if (lower.contains('inventory') || lower.contains('stock') || lower.contains('মজুদ')) {
      targetScreen = const AdminProductsInventoryScreen();
    } else if (lower.contains('order') || lower.contains('অর্ডার')) {
      targetScreen = const AdminOrdersManagementScreen();
    } else if (lower.contains('invoice') || lower.contains('চালান') || lower.contains('billing')) {
      targetScreen = const AllInvoicesScreen();
    } else if (lower.contains('marketing') || lower.contains('sales') || lower.contains('বিক্রয়') || lower.contains('campaign')) {
      targetScreen = const MarketingDashboard();
    } else if (lower.contains('qc') || lower.contains('quality') || lower.contains('মান')) {
      targetScreen = const AdminQCReportScreen();
    } else if (lower.contains('r&d') || lower.contains('research') || lower.contains('গবেষণা')) {
      targetScreen = const RndDashboard();
    } else if (lower.contains('alert') || lower.contains('anomaly') || lower.contains('ai') || lower.contains('prediction') || lower.contains('risk') || lower.contains('monitoring')) {
      targetScreen = CompanyMonitoringScreen(companyId: orgId ?? '');
    } else {
      // Fallback to real interactive Reports Screen with category filter instead of dummy snackbar
      targetScreen = const ReportsScreen();
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen!));
  }

  @override
  Widget build(BuildContext context) {
    final banglaHeader = _toBanglaTitle(title);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        title: Text(banglaHeader, style: AppFonts.banglaHeading(fontSize: 18, color: Colors.white)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_p1, _p2, _p3],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 3 : 2);
          double aspectRatio = constraints.maxWidth < 380 ? 1.15 : (cols == 2 ? 1.35 : 1.45);

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'রিপোর্ট বা মডিউল নির্বাচন করুন',
                  style: AppFonts.banglaHeading(color: _text, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'তারিখ সীমা: ${range.start.toString().split(" ").first} → ${range.end.subtract(const Duration(days: 1)).toString().split(" ").first}',
                  style: AppFonts.banglaData(color: _text2, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: labels.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: aspectRatio,
                    ),
                    itemBuilder: (_, i) {
                      final label = labels[i];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _navigateToRealScreen(context, label),
                          splashColor: _p2.withValues(alpha: 0.1),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white,
                              border: Border.all(color: _border),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 38,
                                  width: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      colors: [_p2, _p3],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Icon(Icons.insert_chart_rounded, color: Colors.white, size: 20),
                                ),
                                const Spacer(),
                                Text(
                                  label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.banglaBody(fontWeight: FontWeight.w700, color: _text, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('খুলতে ট্যাপ করুন', style: AppFonts.banglaBody(fontSize: 10, color: _p2, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: _p2),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
