import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';

// Pages
import { LoginPage }         from './pages/LoginPage';
import { HrShell }           from './pages/HrShell';
import { DashboardPage }     from './pages/DashboardPage';
import { EmployeesPage }     from './pages/EmployeesPage';
import { RecruitmentPage }   from './pages/RecruitmentPage';
import { AttendancePage }    from './pages/AttendancePage';
import { LeavePage }         from './pages/LeavePage';
import { ShiftsPage }        from './pages/ShiftsPage';
import { PayrollPage }       from './pages/PayrollPage';
import { PayslipsPage }      from './pages/PayslipsPage';
import { SalaryPage }        from './pages/SalaryPage';
import { LoansPage }         from './pages/LoansPage';
import { CreditsPage }       from './pages/CreditsPage';
import { BudgetPage }        from './pages/BudgetPage';
import { AccountsPage }      from './pages/AccountsPage';
import { BalancePage }       from './pages/BalancePage';
import { ExpensesPage }      from './pages/ExpensesPage';
import { TaxPage }           from './pages/TaxPage';
import { NoticesPage }       from './pages/NoticesPage';
import { SlipApprovalsPage }  from './pages/SlipApprovalsPage';
import { AuthorizationPage }     from './pages/AuthorizationPage';
import { SalaryCertificatePage } from './pages/SalaryCertificatePage';
import { AppointmentLetterPage } from './pages/AppointmentLetterPage';
import { MessagesPage }          from './pages/MessagesPage';
import { ComplaintsPage }    from './pages/ComplaintsPage';
import { ROIPage }           from './pages/ROIPage';
import { IncentivesPage }    from './pages/IncentivesPage';
import { WelfarePage }       from './pages/WelfarePage';
import { ProcurementPage }   from './pages/ProcurementPage';
import { BenefitsPage }      from './pages/BenefitsPage';
import { BudgetForecastPage } from './pages/BudgetForecastPage';

function ProtectedRoute({ children }) {
  const { isAuthenticated, loading } = useAuth();
  if (loading) return <FullScreenSpinner />;
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  return children;
}

function PublicRoute({ children }) {
  const { isAuthenticated, loading } = useAuth();
  if (loading) return <FullScreenSpinner />;
  if (isAuthenticated) return <Navigate to="/hr" replace />;
  return children;
}

function FullScreenSpinner() {
  return (
    <div className="min-h-screen flex items-center justify-center" style={{ background: '#F1F8F4' }}>
      <div className="flex flex-col items-center gap-4">
        <div className="w-16 h-16 rounded-2xl bg-white shadow-lg flex items-center justify-center overflow-hidden border border-[#065F46]/10">
          <img src="/logo.png" alt="উদ্যোগী" className="w-full h-full object-contain p-1.5" />
        </div>
        <div className="w-6 h-6 border-[3px] border-[#065F46]/20 border-t-[#065F46] rounded-full animate-spin" />
        <p className="text-sm text-gray-500 font-medium">Loading উদ্যোগী HR…</p>
      </div>
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<PublicRoute><LoginPage /></PublicRoute>} />

          <Route path="/hr" element={<ProtectedRoute><HrShell /></ProtectedRoute>}>
            <Route index          element={<DashboardPage />} />
            <Route path="employees"   element={<EmployeesPage />} />
            <Route path="recruitment" element={<RecruitmentPage />} />
            <Route path="attendance"  element={<AttendancePage />} />
            <Route path="leave"       element={<LeavePage />} />
            <Route path="shifts"      element={<ShiftsPage />} />
            <Route path="payroll"     element={<PayrollPage />} />
            <Route path="payslips"    element={<PayslipsPage />} />
            <Route path="salary"      element={<SalaryPage />} />
            <Route path="loans"       element={<LoansPage />} />
            <Route path="credits"     element={<CreditsPage />} />
            <Route path="budget"      element={<BudgetPage />} />
            <Route path="accounts"    element={<AccountsPage />} />
            <Route path="balance"     element={<BalancePage />} />
            <Route path="expenses"    element={<ExpensesPage />} />
            <Route path="tax"         element={<TaxPage />} />
            <Route path="notices"     element={<NoticesPage />} />
            <Route path="slip-approvals"  element={<SlipApprovalsPage />} />
            <Route path="authorization"          element={<AuthorizationPage />} />
            <Route path="authorization/salary-certificate"   element={<SalaryCertificatePage />} />
            <Route path="authorization/appointment-letter"   element={<AppointmentLetterPage />} />
            <Route path="messages"        element={<MessagesPage />} />
            <Route path="complaints"      element={<ComplaintsPage />} />
            <Route path="roi"              element={<ROIPage />} />
            <Route path="incentives"      element={<IncentivesPage />} />
            <Route path="welfare"         element={<WelfarePage />} />
            <Route path="procurement"     element={<ProcurementPage />} />
            <Route path="benefits"        element={<BenefitsPage />} />
            <Route path="budget-forecast" element={<BudgetForecastPage />} />
          </Route>

          <Route path="*" element={<Navigate to="/hr" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
