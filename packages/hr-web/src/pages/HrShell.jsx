import { useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { Sidebar } from '../components/layout/Sidebar';
import { TopBar }  from '../components/layout/TopBar';

const TITLES = {
  '/hr':                'Dashboard',
  '/hr/employees':      'Employee Directory',
  '/hr/recruitment':    'Recruitment',
  '/hr/attendance':     'Attendance',
  '/hr/leave':          'Leave Management',
  '/hr/shifts':         'Shift Tracker',
  '/hr/payroll':        'Payroll',
  '/hr/payslips':       'Pay Slips',
  '/hr/salary':         'Salary Management',
  '/hr/loans':          'Loan Approval',
  '/hr/credits':        'Credits & Ledger',
  '/hr/budget':         'Budget',
  '/hr/accounts':       'Accounts',
  '/hr/expenses':       'Expenses',
  '/hr/tax':            'Tax',
  '/hr/notices':        'Notices',
  '/hr/slip-approvals': 'Payment Slip Approvals',
  '/hr/authorization':  'Authorization Documents',
  '/hr/messages':       'Messages',
  '/hr/complaints':     'Complaints',
  '/hr/roi':            'Performance & ROI',
  '/hr/incentives':     'Incentive Dashboard',
  '/hr/welfare':        'Welfare Requests',
  '/hr/procurement':    'Procurement',
  '/hr/benefits':       'Benefits & Compensation',
  '/hr/budget-forecast': 'Budget Forecast',
};

export function HrShell() {
  const [collapsed,   setCollapsed]   = useState(false);
  const [mobileOpen,  setMobileOpen]  = useState(false);
  const location = useLocation();
  const title = TITLES[location.pathname] || 'HR Portal';

  return (
    <div className="flex h-screen overflow-hidden" style={{ background: '#F1F8F4' }}>

      {/* ── Mobile overlay ─────────────────────────────────────────────────── */}
      {mobileOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 lg:hidden backdrop-blur-sm"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* ── Sidebar ────────────────────────────────────────────────────────── */}
      <div
        className={`
          fixed lg:static inset-y-0 left-0 z-50 lg:z-auto shrink-0
          transition-transform duration-300 ease-in-out
          ${mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
        `}
      >
        <Sidebar
          collapsed={collapsed}
          onToggle={() => setCollapsed(c => !c)}
          onMobileClose={() => setMobileOpen(false)}
        />
      </div>

      {/* ── Main area ──────────────────────────────────────────────────────── */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">

        {/* Top bar */}
        <TopBar
          title={title}
          onMenuToggle={() => setMobileOpen(o => !o)}
        />

        {/* Scrollable content */}
        <main className="flex-1 overflow-y-auto">
          <div className="content-area px-5 py-6 lg:px-8 lg:py-7 fade-in">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
