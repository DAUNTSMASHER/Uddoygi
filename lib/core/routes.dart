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

// 💳 PipraPay / Payments
import 'package:uddoygi/features/payments/presentation/screens/piprapay_dashboard.dart';
import 'package:uddoygi/features/payments/presentation/screens/hr_payment_dispatch_screen.dart';
import 'package:uddoygi/features/payments/presentation/screens/employee_payment_info_screen.dart';
import 'package:uddoygi/features/payments/presentation/screens/employee_payment_methods_screen.dart';
import 'package:uddoygi/features/payments/presentation/screens/hr_bank_accounts_screen.dart';
import 'package:uddoygi/features/payments/presentation/screens/piprapay_settings_screen.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// 🖥️ HR Web Shell
import 'package:uddoygi/features/hr/presentation/widgets/hr_web_shell.dart';

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
import 'package:uddoygi/features/marketing/presentation/screens/renumeration_dashboard.dart';

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

  // 🟢 HR — all screens are wrapped in _HrRoute for desktop sidebar support
  '/hr/dashboard':              (ctx) => const HRDashboard(),
  '/hr/employee_directory':     (ctx) => _HrRoute(title: 'Employee Directory',    child: const EmployeeDirectoryScreen()),
  '/hr/shift_tracker':          (ctx) => _HrRoute(title: 'Shift Tracker',          child: const ShiftTrackerScreen()),
  '/hr/recruitment':            (ctx) => _HrRoute(title: 'Recruitment',            child: const RecruitmentScreen()),
  '/hr/attendance':             (ctx) => _HrRoute(title: 'Attendance',             child: const AttendanceScreen()),
  '/hr/leave_management':       (ctx) => _HrRoute(title: 'Leave Management',       child: const LeaveManagementScreen()),
  '/hr/payroll':                (ctx) => _HrRoute(title: 'Payroll Overview',        child: const PayrollOverviewScreen()),
  '/hr/payroll/review':         (ctx) => _HrRoute(title: 'Review Payroll',          child: const ReviewPayrollScreen()),
  '/hr/payroll_processing':     (ctx) => _HrRoute(title: 'Payroll Processing',      child: const PayrollProcessingScreen()),
  '/hr/payslip':                (ctx) => _HrRoute(title: 'Payslips',               child: const PayslipScreen()),
  '/employee/payslip':          (ctx) => const EmployeePayslipScreen(),
  '/hr/authorization':          (ctx) => _HrRoute(title: 'Authorization',          child: const HrAuthorizationScreen()),
  '/hr/salary_certificate':     (ctx) => _HrRoute(title: 'Salary Certificate',     child: const HrSalaryCertificateScreen()),
  '/hr/appointment_letter':     (ctx) => _HrRoute(title: 'Appointment Letter',     child: const HrAppointmentLetterScreen()),
  '/hr/payment_slip_approvals': (ctx) => _HrRoute(title: 'Slip Approvals',         child: const HrPaymentSlipApprovalScreen()),
  '/hr/salary_management':      (ctx) => _HrRoute(title: 'Salary Management',      child: const SalaryManagementScreen()),
  '/hr/benefits_compensation':  (ctx) => _HrRoute(title: 'Benefits & Compensation',child: const BenefitsCompensationScreen()),
  '/hr/loan_approval':          (ctx) => _HrRoute(title: 'Loan Approval',          child: const LoanApprovalScreen()),
  '/hr/incentives':             (ctx) => _HrRoute(title: 'Incentives',             child: const IncentivehrScreen()),
  '/hr/credits':                (ctx) => _HrRoute(title: 'Credits',                child: const GeneralLedgerScreen()),
  '/hr/accounts_payable':       (ctx) => _HrRoute(title: 'Accounts Payable',       child: const AccountsPayableScreen()),
  '/hr/expenses':               (ctx) => _HrRoute(title: 'Expenses',               child: const ExpensesScreen()),
  '/hr/balance_update':         (ctx) => _HrRoute(title: 'Balance Update',         child: const BalanceUpdateScreen()),
  '/hr/tax':                    (ctx) => _HrRoute(title: 'Tax',                    child: const TaxScreen()),
  '/hr/procurement':            (ctx) => _HrRoute(title: 'Procurement',            child: const ProcurementScreen()),
  '/hr/budget_forecast':        (ctx) => _HrRoute(title: 'Budget Forecast',        child: const BudgetForecastScreen()),
  '/hr/notices':                (ctx) => _HrRoute(title: 'Notices',                child: const HRNoticeScreen()),
  '/hr/welfare':                (ctx) => _HrRoute(title: 'Welfare',                child: const HRWelfareScreen()),
  '/hr/roi':                    (ctx) => _HrRoute(title: 'ROI',                    child: const ROIPage()),
  '/hr/budget':                 (ctx) => _HrRoute(title: 'Budget',                 child: const BudgetPage()),

  // 💳 Payments / PipraPay
  '/payments/piprapay':               (ctx) => _HrRoute(title: 'PipraPay',          child: const PipraPayDashboard()),
  '/payments/dispatch':               (ctx) => _HrRoute(title: 'Pay Dispatch',       child: const HrPaymentDispatchScreen()),
  '/payments/my-payment-info':        (ctx) => const EmployeePaymentInfoScreen(),
  '/common/salary/payment-methods':   (ctx) => const EmployeePaymentMethodsScreen(),
  '/payments/bank-accounts': (ctx) {
    final cid = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
    return _HrRoute(
      title: 'Accounts',
      child: _CidLoader(
        builder: (c) => HrBankAccountsScreen(cid: c),
        fallbackCid: cid,
      ),
    );
  },
  '/payments/piprapay/settings': (ctx) {
    final cid = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
    return _HrRoute(
      title: 'PipraPay Settings',
      child: _CidLoader(
        builder: (c) => PipraPaySettingsScreen(cid: c),
        fallbackCid: cid,
      ),
    );
  },

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
  '/marketing/renumeration': (context) => const RenumerationDashboard(),

  // 🟣 Factory
  '/factory/dashboard': (context) => const FactoryDashboard(),
  '/factory/notices': (context) => const FactoryNoticeScreen(),
  '/factory/attendance':    (context) => const FactoryAttendanceScreen(),
  '/factory/salary_overtime': (context) => const SalaryScreen(),
  '/marketing/attendance':  (context) => const FactoryAttendanceScreen(),
  '/admin/attendance':      (context) => const FactoryAttendanceScreen(),
  '/admin/salary':          (context) => const SalaryScreen(),

  // 🔁 Common
  '/common/messages': (context) => const MessagesScreen(),
  '/common/welfare': (context) => const WelfareScreen(),
  '/common/complaints': (context) => const ComplaintScreen(),
  '/common/salary': (context) => const SalaryScreen(),
};

// ── Helper: auto-loads companyId from local storage ──────────────────────────
class _CidLoader extends StatefulWidget {
  final Widget Function(String cid) builder;
  final String fallbackCid;
  const _CidLoader({required this.builder, this.fallbackCid = ''});
  @override
  State<_CidLoader> createState() => _CidLoaderState();
}

class _CidLoaderState extends State<_CidLoader> {
  String _cid = '';
  bool   _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.fallbackCid.isNotEmpty) {
      _cid    = widget.fallbackCid;
      _loaded = true;
    } else {
      LocalStorageService.getSavedCompanyId().then((id) {
        if (mounted) setState(() { _cid = id ?? ''; _loaded = true; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.builder(_cid);
  }
}

// ── Helper: wraps HR screens with desktop sidebar on wide screens ─────────────
// On desktop (≥ 900 px): renders child inside HrWebShell (sidebar + top bar).
// On mobile: passes child through unchanged.
class _HrRoute extends StatelessWidget {
  final String title;
  final Widget child;
  const _HrRoute({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    if (!isDesktop) return child;
    return HrWebShell(title: title, child: child);
  }
}