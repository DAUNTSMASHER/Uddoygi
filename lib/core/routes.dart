// lib/core/routes.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/main.dart';
import 'package:uddoygi/profile.dart';

// 🟢 Auth / Onboarding
import 'package:uddoygi/features/auth/presentation/screens/company_registration_screen.dart';
import 'package:uddoygi/features/auth/presentation/screens/forgot_company_id_screen.dart';

// 🔵 Admin Screens
import 'package:uddoygi/features/admin/presentation/screens/admin_dashboard.dart';
import 'package:uddoygi/features/admin/presentation/screens/reports_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/welfare_scheme_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/complaints_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/notices_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_all_notices_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_messages_screen.dart';
import 'package:uddoygi/features/admin/presentation/widgets/admin_allbuyer.dart';
import 'package:uddoygi/features/admin/presentation/screens/employee_management_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_research.dart';
import 'package:uddoygi/features/admin/presentation/screens/company_profile_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_settings_screen.dart';
import 'package:uddoygi/features/admin/presentation/screens/smtp_settings_screen.dart';

// 🔬 R&D Department
import 'package:uddoygi/features/rnd/presentation/screens/rnd_dashboard.dart';
import 'package:uddoygi/features/rnd/presentation/screens/rnd_projects_screen.dart';
import 'package:uddoygi/features/rnd/presentation/screens/rnd_daily_update_screen.dart';
import 'package:uddoygi/features/rnd/presentation/screens/rnd_milestones_screen.dart';
import 'package:uddoygi/features/rnd/presentation/screens/rnd_project_request_screen.dart';
import 'package:uddoygi/features/rnd/presentation/screens/rnd_approval_screen.dart';
import 'package:uddoygi/features/rnd/presentation/screens/rnd_request_tracker_screen.dart';
import 'package:uddoygi/features/rnd/presentation/screens/rnd_notices_screen.dart';

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
import 'package:uddoygi/features/hr/presentation/screens/payroll_overview_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/review_payroll_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/employee_payslip_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/hr_authorization_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/hr_salary_certificate_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/hr_appointment_letter_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/hr_payment_slip_approval_screen.dart';
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
import 'package:uddoygi/features/hr/presentation/screens/welfare_screen.dart';
import 'package:uddoygi/features/hr/presentation/screens/ROI.dart';
import 'package:uddoygi/features/hr/presentation/screens/budget.dart';

// 🟠 Marketing Screens
import 'package:uddoygi/features/marketing/presentation/screens/marketing_dashboard.dart';
import 'package:uddoygi/features/marketing/presentation/screens/customers_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/sales_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/task_assignment_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/orders_screen.dart';
import 'package:uddoygi/features/factory/presentation/screens/loan_request_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/new_invoices_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/all_invoices_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/sales_report_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/marketing_notice.dart';

// 🟣 Marketing Work Order Screens
import 'package:uddoygi/features/marketing/presentation/work_order/add_new_wo.dart';
import 'package:uddoygi/features/marketing/presentation/work_order/add_new_po.dart';
import 'package:uddoygi/features/marketing/presentation/work_order/incoming_products.dart';
import 'package:uddoygi/features/marketing/presentation/work_order/QC_report.dart';

// 🟣 Factory Screens
import 'package:uddoygi/features/factory/presentation/screens/factory_dashboard.dart';
import 'package:uddoygi/features/factory/presentation/screens/factory_notice.dart';
import 'package:uddoygi/features/factory/presentation/screens/factory_attendance_screen.dart';


// 🔁 Common Screens
import 'package:uddoygi/features/common/presentation/screens/messages_screen.dart';
import 'package:uddoygi/features/common/presentation/screens/welfare_screen.dart';
import 'package:uddoygi/features/common/presentation/screens/complaints_screen.dart';
import 'package:uddoygi/features/common/salary_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/login':              (context) => const LoginScreenWrapper(),
  '/register-company':   (context) => const CompanyRegistrationScreen(),
  '/forgot-company-id':  (context) => const ForgotCompanyIdScreen(),
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
  '/admin/research': (context) => const AdminResearchScreen(),
  '/admin/reports/incentives': (context) => const IncentiveScreen(),
  '/admin/welfare': (context) => const WelfareSchemeScreen(),
  '/admin/complaints': (context) => const ComplaintsScreen(),
  '/admin/notices': (context) => const AdminNoticeScreen(),
  '/admin/notices/all': (context) => const AdminAllNoticesScreen(),
  '/admin/messages': (context) => const AdminMessagesScreen(),
  '/admin/company':   (context) => const CompanyProfileScreen(),
  '/admin/settings':  (context) => const AdminSettingsScreen(),
  '/admin/smtp':      (context) => const SmtpSettingsScreen(),
  '/admin/rnd/approval': (context) => const RndApprovalScreen(),

  // 🔬 R&D Department
  '/rnd/dashboard':  (context) => const RndDashboard(),
  '/rnd/projects':   (context) => const RndProjectsScreen(),
  '/rnd/updates':    (context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return RndDailyUpdateScreen(
      projectId:    args?['projectId']    as String?,
      projectTitle: args?['projectTitle'] as String?,
    );
  },
  '/rnd/milestones': (context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return RndMilestonesScreen(
      projectId:    args?['projectId']    as String?,
      projectTitle: args?['projectTitle'] as String?,
    );
  },
  '/rnd/request':    (context) => const RndProjectRequestScreen(),
  '/rnd/inbox':      (context) => const RndApprovalScreen(),
  '/rnd/tracker':    (context) => const RndRequestTrackerScreen(),
  '/rnd/notices':    (context) => const RndNoticesScreen(),
  '/rnd/reports':    (context) => const RndProjectsScreen(),
  '/rnd/attendance': (context) => const FactoryAttendanceScreen(),
  '/rnd/loan':       (context) => const RndProjectsScreen(),
  '/admin/all-buyers': (context) => const AdminAllBuyersPage(),

  // 🟢 HR
  '/hr/dashboard': (context) => const HRDashboard(),
  '/hr/employee_directory': (context) => const EmployeeDirectoryScreen(),
  '/hr/shift_tracker': (context) => const ShiftTrackerScreen(),
  '/hr/recruitment': (context) => const RecruitmentScreen(),
  '/hr/attendance': (context) => const AttendanceScreen(),
  '/hr/leave_management': (context) => const LeaveManagementScreen(),
  '/hr/payroll':              (context) => const PayrollOverviewScreen(),
  '/hr/payroll/review':       (context) => const ReviewPayrollScreen(),
  '/hr/payroll_processing': (context) => const PayrollProcessingScreen(),
  '/hr/payslip':              (context) => const PayslipScreen(),
  '/employee/payslip':        (context) => const EmployeePayslipScreen(),
  '/hr/authorization':          (context) => const HrAuthorizationScreen(),
  '/hr/salary_certificate':     (context) => const HrSalaryCertificateScreen(),
  '/hr/appointment_letter':     (context) => const HrAppointmentLetterScreen(),
  '/hr/payment_slip_approvals': (context) => const HrPaymentSlipApprovalScreen(),
  '/hr/salary_management': (context) => const SalaryManagementScreen(),
  '/hr/benefits_compensation': (context) => const BenefitsCompensationScreen(),
  '/hr/loan_approval': (context) => const LoanApprovalScreen(),
  '/hr/incentives': (context) => const IncentivehrScreen(),
  '/hr/credits': (context) => const GeneralLedgerScreen(),
  '/hr/accounts_payable': (context) => const AccountsPayableScreen(),
  '/hr/expenses': (context) => const ExpensesScreen(),
  '/hr/balance_update': (context) => const BalanceUpdateScreen(),
  '/hr/tax': (context) => const TaxScreen(),
  '/hr/procurement': (context) => const ProcurementScreen(),
  '/hr/budget_forecast': (context) => const BudgetForecastScreen(),
  '/hr/notices': (context) => const HRNoticeScreen(),
  '/hr/welfare': (context) => const HRWelfareScreen(),
  '/hr/roi':     (context) => const ROIPage(),
  '/hr/budget':  (context) => const BudgetPage(),

  // 🟠 Marketing
  '/marketing/dashboard': (context) => const MarketingDashboard(),
  '/marketing/notices': (context) => const MarketingNoticeScreen(),
  '/marketing/clients': (context) => const CustomersScreen(),
  '/marketing/sales': (context) => const SalesScreen(),
  '/marketing/task_assignment': (context) => const TaskAssignmentScreen(),
  '/marketing/orders': (context) => const OrdersScreen(),
  '/marketing/loan_request': (context) => LoanRequestScreen(),
  '/marketing/sales/new': (context) => const NewInvoicesScreen(),
  '/marketing/sales/all': (context) => const AllInvoicesScreen(),
  '/marketing/sales/report': (context) => const SalesReportScreen(),

  // 🟣 Marketing Work Orders
  '/marketing/workorders/new': (context) => const AddNewWorkOrderScreen(),
  '/marketing/purchase_orders/new': (context) => const AddNewPurchaseOrderScreen(),
  '/marketing/incoming_products': (context) => const IncomingProductsScreen(),
  '/marketing/qc_report': (context) => MarketingQCReportScreen(),

  // 🟣 Factory
  '/factory/dashboard': (context) => const FactoryDashboard(),
  '/factory/notices': (context) => const FactoryNoticeScreen(),
  '/factory/attendance':    (context) => const FactoryAttendanceScreen(),
  '/marketing/attendance':  (context) => const FactoryAttendanceScreen(),
  '/admin/attendance':      (context) => const FactoryAttendanceScreen(),

  // 🔁 Common
  '/common/messages': (context) => const MessagesScreen(),
  '/common/welfare': (context) => const WelfareScreen(),
  '/common/complaints': (context) => const ComplaintScreen(),
  '/common/salary': (context) => const SalaryScreen(),
};