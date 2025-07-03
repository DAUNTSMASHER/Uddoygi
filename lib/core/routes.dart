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
import 'package:uddoygi/features/admin/presentation/widgets/admin_allbuyer.dart';

// 🟢 HR Screens
import 'package:uddoygi/features/hr/presentation/screens/hr_dashboard.dart';
import 'package:uddoygi/features/hr/presentation/screens/notices_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/recruitment_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/salary_management.dart';
import 'package:uddoygi/features/hr/presentation/screens/incentives_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/loan_approval_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/balance_update_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/procurement_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/tax_screen.dart';

// HR Complaints
import 'package:uddoygi/features/common/presentation/screens/complaints_screen.dart';

// 🟠 Marketing Screens
import 'package:uddoygi/features/marketing/presentation/screens/marketing_dashboard.dart';
import 'package:uddoygi/features/marketing/presentation/screens/customers_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/sales_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/task_assignment_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/campaign_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/orders_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/loan_request_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/new_invoices_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/all_invoices_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/sales_report_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/marketing_notice.dart';

// 🟣 Factory Screens
import 'package:uddoygi/features/factory/presentation/screens/factory_dashboard.dart';
import 'package:uddoygi/features/factory/presentation/screens/factory_notice.dart';

// COMMON
import 'package:uddoygi/features/common/presentation/screens/messages_screen.dart';
import 'package:uddoygi/features/common/presentation/screens/welfare_screen.dart';

// === FULL ROUTE MAP ===

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
  '/admin/all-buyers': (context) => const AdminAllBuyersPage(),

  // 🟢 HR Routes
  '/hr/dashboard': (context) => const HRDashboard(),
  '/hr/notices': (context) => const HRNoticeScreen(),
  '/hr/recruitment': (context) => const RecruitmentScreen(),
  '/hr/salary_management': (context) => const SalaryManagementScreen(),
  '/hr/incentives': (context) => const IncentivesScreen(),
  '/hr/loan_approval': (context) => const LoanApprovalScreen(),
  '/hr/balance_update': (context) => const BalanceUpdateScreen(),
  '/hr/procurement': (context) => const ProcurementScreen(),
  '/hr/tax': (context) => const TaxScreen(),
  '/hr/complaints': (context) => const ComplaintScreen(),    // 👈 NEW LINE for HR Complaints

  // 🟠 Marketing Routes
  '/marketing/dashboard': (context) => const MarketingDashboard(),
  '/marketing/clients': (context) => const CustomersScreen(),
  '/marketing/sales': (context) => const SalesScreen(),
  '/marketing/task_assignment': (context) => const TaskAssignmentScreen(),
  '/marketing/campaign': (context) => const CampaignScreen(),
  '/marketing/orders': (context) => const OrdersScreen(),
  '/marketing/loan_request': (context) => const LoanRequestScreen(),
  '/marketing/sales/new': (context) => const NewInvoicesScreen(),
  '/marketing/sales/all': (context) => const AllInvoicesScreen(),
  '/marketing/sales/report': (context) => const SalesReportScreen(),
  '/marketing/notices': (context) => const MarketingNoticeScreen(),

  // 🟣 Factory Routes
  '/factory/dashboard': (context) => const FactoryDashboard(),
  '/factory/notices': (context) => const FactoryNoticeScreen(),

  // COMMON Routes
  '/common/messages': (context) => const MessagesScreen(),
  '/common/welfare': (context) => const WelfareScreen(),
  '/common/complaints': (context) => const ComplaintScreen(), // For general user access
};
