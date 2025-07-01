import 'package:flutter/material.dart';
import 'package:uddoygi/main.dart'; // ✅ Login wrapper

// 🔵 Admin Screens
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

// 🟢 HR Screens
import 'package:uddoygi/features/hr/presentation/screens/hr_dashboard.dart';

// 🟠 Marketing Screens
import 'package:uddoygi/features/marketing/presentation/screens/marketing_dashboard.dart';
import 'package:uddoygi/features/marketing/presentation/screens/customers_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/sales_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/task_assignment_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/campaign_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/orders_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/loan_request_screen.dart';

// 🟣 Factory Screens
import 'package:uddoygi/features/factory/presentation/screens/factory_dashboard.dart';

final Map<String, WidgetBuilder> appRoutes = {
  // 🔐 Authentication
  '/login': (context) => const LoginScreenWrapper(),

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
  '/marketing/clients': (context) => const CustomersScreen(),
  '/marketing/sales': (context) => const SalesScreen(),
  '/marketing/task_assignment': (context) => const TaskAssignmentScreen(),
  '/marketing/campaign': (context) => const CampaignScreen(),
  '/marketing/orders': (context) => const OrdersScreen(),
  '/marketing/loan_request': (context) => const LoanRequestScreen(),

  // 🟣 Factory Routes
  '/factory/dashboard': (context) => const FactoryDashboard(),
};
