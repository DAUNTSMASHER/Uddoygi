import 'package:flutter/material.dart';

// ✅ Admin Screens
import 'package:uddoygi/features/admin/presentation/screens/admin_dashboard.dart';
import 'package:uddoygi/features/admin/presentation/screens/employee_management_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/reports_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/reports_graph_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/welfare_scheme_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/complaints_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/salary_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/notices_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_all_notices_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_messages_screen.dart';

// ✅ HR Screens
import 'package:uddoygi/features/hr/presentation/screens/hr_dashboard.dart';

// ✅ Marketing Screens
import 'package:uddoygi/features/marketing/presentation/screens/marketing_dashboard.dart';

// ✅ Factory Screens
import 'package:uddoygi/features/factory/presentation/screens/factory_dashboard.dart';

final Map<String, WidgetBuilder> appRoutes = {
  // 🔵 Admin Routes
  '/admin/dashboard': (context) => const AdminDashboard(),
  '/admin/employees': (context) => const EmployeeManagementScreen(),
  '/admin/reports': (context) => const ReportsScreen(),
  '/admin/reports/graphs': (context) => const AdminReportsWithGraphsScreen(),
  '/admin/welfare': (context) => const WelfareSchemeScreen(),
  '/admin/complaints': (context) => const ComplaintsScreen(),
  '/admin/salary': (context) => const SalaryScreen(),
  '/admin/notices': (context) => const AdminNoticeScreen(),
  '/admin/notices/all': (context) => const AdminAllNoticesScreen(),
  '/admin/messages': (context) => const AdminMessagesScreen(),

  // 🟢 HR Routes
  '/hr/dashboard': (context) => const HRDashboard(),

  // 🟠 Marketing Routes
  '/marketing/dashboard': (context) => const MarketingDashboard(),

  // 🟣 Factory Routes
  '/factory/dashboard': (context) => const FactoryDashboard(),
};
