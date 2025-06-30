import 'package:flutter/material.dart';

// Admin Screens
import 'package:uddoygi/features/admin/presentation/screens/admin_dashboard.dart';
import 'package:uddoygi/features/admin/presentation/screens/employee_management_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/reports_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/reports_graph_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/welfare_scheme_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/complaints_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/salary_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/notices_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_all_notices_screen.dart';

// HR, Marketing, and Factory Dashboards
import 'package:uddoygi/features/hr/presentation/screens/hr_dashboard.dart';
import 'package:uddoygi/features/marketing/presentation/screens/marketing_dashboard.dart';
import 'package:uddoygi/features/factory/presentation/screens/factory_dashboard.dart';

// Add the edit notice screen import when available
// import 'package:uddoygi/features/admin/presentation/screens/edit_notice_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  // ✅ Admin Routes
  '/admin/dashboard': (context) => const AdminDashboard(),
  '/admin/employees': (context) => const EmployeeManagementScreen(),
  '/admin/reports': (context) => const ReportsScreen(),
  '/admin/reports/graphs': (context) => const AdminReportsWithGraphsScreen(),
  '/admin/welfare': (context) => const WelfareSchemeScreen(),
  '/admin/complaints': (context) => const ComplaintsScreen(),
  '/admin/salary': (context) => const SalaryScreen(),
  '/admin/notices': (context) => const AdminNoticeScreen(),
  '/admin/notices/all': (context) => const AdminAllNoticesScreen(),
  // '/admin/notices/edit': (context) => const EditNoticeScreen(),

  // ✅ HR Route
  '/hr/dashboard': (context) => const HRDashboard(),

  // ✅ Marketing Route
  '/marketing/dashboard': (context) => const MarketingDashboard(),

  // ✅ Factory Route
  '/factory/dashboard': (context) => const FactoryDashboard(),
};
