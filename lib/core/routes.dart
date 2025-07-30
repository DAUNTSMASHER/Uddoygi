// lib/core/routes.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/main.dart';
import 'package:uddoygi/profile.dart';

// 🔵 Admin Screens
import 'package:uddoygi/features/admin/presentation/screens/admin_dashboard.dart';
import 'package:uddoygi/features/admin/presentation/screens/reports_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/reports_graph_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/welfare_scheme_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/complaints_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/salary_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/notices_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_all_notices_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_messages_screen.dart';
import 'package:uddoygi/features/admin/presentation/widgets/admin_allbuyer.dart';
import 'package:uddoygi/features/admin/presentation/screens/employee_management_screen.dart';

// 🆕 Admin - Incentive Reports
import 'package:uddoygi/features/admin/presentation/screens/incentives.dart';

// 👥 Employee Management Screens
import 'package:uddoygi/features/employee_management/add_employee_page.dart';
import 'package:uddoygi/features/employee_management/all_employees_page.dart';
import 'package:uddoygi/features/employee_management/submit_recommendation_page.dart';
import 'package:uddoygi/features/employee_management/transitions_page.dart';

// 🟢 HR Screens
import 'package:uddoygi/features/hr/presentation/screens/hr_dashboard.dart';
import 'package:uddoygi/features/hr/presentation/screens/employee_directory_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/shift_tracker_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/recruitment_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/attendance_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/leave_management_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/payroll_processing_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/payslip_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/salary_management.dart';
import 'package:uddoygi/features/hr/presentation/screens/benefits_compensation_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/loan_approval_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/incentives_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/general_ledger_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/accounts_payable_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/accounts_receivable_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/balance_update_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/tax_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/procurement_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/budget_forecast_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/notices_screen.dart';

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

// 🟣 Marketing Work Order Screens
import 'package:uddoygi/features/marketing/presentation/work_order/add_new_wo.dart';
import 'package:uddoygi/features/marketing/presentation/work_order/add_new_po.dart';
import 'package:uddoygi/features/marketing/presentation/work_order/incoming_products.dart';
import 'package:uddoygi/features/marketing/presentation/work_order/qc_report.dart';

// 🟣 Factory Screens
import 'package:uddoygi/features/factory/presentation/screens/factory_dashboard.dart';
import 'package:uddoygi/features/factory/presentation/screens/factory_notice.dart';

// 🔁 Common Screens
import 'package:uddoygi/features/common/presentation/screens/messages_screen.dart';
import 'package:uddoygi/features/common/presentation/screens/welfare_screen.dart';
import 'package:uddoygi/features/common/presentation/screens/complaints_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/login': (context) => const LoginScreenWrapper(),
  '/profile': (context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return ProfilePage(userId: uid);
  },

  // 🔵 Admin
  '/admin/dashboard': (context) => const AdminDashboard(),
  '/admin/employees': (context) => const EmployeeManagementScreen(),
  '/admin/employees/add': (context) => const AddEmployeePage(),
  '/admin/employees/all': (context) => const AllEmployeesPage(),
  '/admin/employees/recommendation': (context) => const SubmitRecommendationPage(),
  '/admin/employees/promotions': (context) => const TransitionsPage(),
  '/admin/reports': (context) => const ReportsScreen(),
  '/admin/reports/graphs': (context) => const AdminReportsWithGraphsScreen(),
  '/admin/reports/incentives': (context) => const IncentiveScreen(),
  '/admin/welfare': (context) => const WelfareSchemeScreen(),
  '/admin/complaints': (context) => const ComplaintsScreen(),
  '/admin/salary': (context) => const SalaryScreen(),
  '/admin/notices': (context) => const AdminNoticeScreen(),
  '/admin/notices/all': (context) => const AdminAllNoticesScreen(),
  '/admin/messages': (context) => const AdminMessagesScreen(),
  '/admin/all-buyers': (context) => const AdminAllBuyersPage(),

  // 🟢 HR
  '/hr/dashboard': (context) => const HRDashboard(),
  '/hr/employee_directory': (context) => const EmployeeDirectoryScreen(),
  '/hr/shift_tracker': (context) => const ShiftTrackerScreen(),
  '/hr/recruitment': (context) => const RecruitmentScreen(),
  '/hr/attendance': (context) => const AttendanceScreen(),
  '/hr/leave_management': (context) => const LeaveManagementScreen(),
  '/hr/payroll_processing': (context) => const PayrollProcessingScreen(),
  '/hr/payslip': (context) => const PayslipScreen(),
  '/hr/salary_management': (context) => const SalaryManagementScreen(),
  '/hr/benefits_compensation': (context) => const BenefitsCompensationScreen(),
  '/hr/loan_approval': (context) => const LoanApprovalScreen(),
  '/hr/incentives': (context) => const IncentivehrScreen(),
  '/hr/general_ledger': (context) => const GeneralLedgerScreen(),
  '/hr/accounts_payable': (context) => const AccountsPayableScreen(),
  '/hr/accounts_receivable': (context) => const AccountsReceivableScreen(),
  '/hr/balance_update': (context) => const BalanceUpdateScreen(),
  '/hr/tax': (context) => const TaxScreen(),
  '/hr/procurement': (context) => const ProcurementScreen(),
  '/hr/budget_forecast': (context) => const BudgetForecastScreen(),
  '/hr/notices': (context) => const HRNoticeScreen(),

  // 🟠 Marketing
  '/marketing/dashboard': (context) => const MarketingDashboard(),
  '/marketing/clients': (context) => const CustomersScreen(),
  '/marketing/sales': (context) => const SalesScreen(),
  '/marketing/task_assignment': (context) => const TaskAssignmentScreen(),

  '/marketing/orders': (context) => const OrdersScreen(),

  '/marketing/sales/new': (context) => const NewInvoicesScreen(),
  '/marketing/sales/all': (context) => const AllInvoicesScreen(),
  '/marketing/sales/report': (context) => const SalesReportScreen(),
  '/marketing/notices': (context) => const MarketingNoticeScreen(),

  // 🟣 Marketing Work Orders
  '/marketing/workorders/new': (context) => const AddNewWorkOrderScreen(),
  '/marketing/purchase_orders/new': (context) => const AddNewPurchaseOrderScreen(),
  '/marketing/incoming_products': (context) => const IncomingProductsScreen(),
  '/marketing/qc_report': (context) => const QCReportScreen(),

  // 🟣 Factory
  '/factory/dashboard': (context) => const FactoryDashboard(),
  '/factory/notices': (context) => const FactoryNoticeScreen(),

  // 🔁 Common
  '/common/messages': (context) => const MessagesScreen(),
  '/common/welfare': (context) => const WelfareScreen(),
  '/common/complaints': (context) => const ComplaintScreen(),
};