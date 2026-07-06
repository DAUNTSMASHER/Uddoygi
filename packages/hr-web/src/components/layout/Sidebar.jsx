import { NavLink, useNavigate } from 'react-router-dom';
import { useEffect, useState } from 'react';
import {
  LayoutDashboard, Users, Briefcase, BarChart3,
  Clock, Calendar,
  DollarSign, FileText, TrendingUp, Receipt, ShieldCheck,
  PiggyBank, CreditCard, TrendingDown, BookOpen, Building2, Calculator, Wallet,
  Bell, MessageSquare, AlertCircle,
  LogOut, ChevronLeft, ChevronRight,
  Target, Percent, Heart, ShoppingCart, Gift, BarChart2,
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { initials } from '../../lib/utils';
import { col, subscribe, orderBy } from '../../lib/db';

// ── Canonical nav — kept in sync with hr_drawer.dart and DashboardPage.jsx ───
const NAV = [
  {
    section: null,
    items: [
      { to: '/hr', label: 'Dashboard', icon: LayoutDashboard, end: true },
    ],
  },
  {
    section: 'People',
    items: [
      { to: '/hr/employees',   label: 'Employees',   icon: Users },
      { to: '/hr/recruitment', label: 'Recruitment', icon: Briefcase },
      { to: '/hr/shifts',      label: 'Shifts',      icon: BarChart3 },
    ],
  },
  {
    section: 'Time',
    items: [
      { to: '/hr/attendance', label: 'Attendance', icon: Clock },
      { to: '/hr/leave',      label: 'Leave',      icon: Calendar },
    ],
  },
  {
    section: 'Payroll',
    items: [
      { to: '/hr/payroll',        label: 'Payroll',        icon: DollarSign },
      { to: '/hr/payslips',       label: 'Payslips',       icon: FileText },
      { to: '/hr/salary',         label: 'Salary',         icon: TrendingUp },
      { to: '/hr/slip-approvals', label: 'Slip Approvals', icon: Receipt },
      { to: '/hr/authorization',  label: 'Authorization',  icon: ShieldCheck },
    ],
  },
  {
    section: 'Finance',
    items: [
      { to: '/hr/balance',    label: 'Balance',    icon: Wallet },
      { to: '/hr/loans',      label: 'Loans',      icon: PiggyBank },
      { to: '/hr/credits',    label: 'Credits',    icon: CreditCard },
      { to: '/hr/expenses',   label: 'Expenses',   icon: TrendingDown },
      { to: '/hr/budget',     label: 'Budget',     icon: BookOpen },
      { to: '/hr/accounts',   label: 'Accounts',   icon: Building2 },
      { to: '/hr/tax',        label: 'Tax',        icon: Calculator },
      { to: '/hr/roi',             label: 'ROI',            icon: Target },
      { to: '/hr/incentives',      label: 'Incentives',     icon: Percent },
      { to: '/hr/benefits',        label: 'Benefits',       icon: Gift },
      { to: '/hr/budget-forecast', label: 'Budget Forecast', icon: BarChart2 },
      { to: '/hr/procurement',     label: 'Procurement',    icon: ShoppingCart },
    ],
  },
  {
    section: 'HR Ops',
    items: [
      { to: '/hr/welfare',    label: 'Welfare',    icon: Heart },
    ],
  },
  {
    section: 'Comms',
    items: [
      { to: '/hr/notices',    label: 'Notices',    icon: Bell },
      { to: '/hr/messages',   label: 'Messages',   icon: MessageSquare },
      { to: '/hr/complaints', label: 'Complaints', icon: AlertCircle },
    ],
  },
];

// Section accent colours — mirrors Flutter drawer section colours
const SECTION_COLORS = {
  People:  'bg-blue-400',
  Time:    'bg-orange-400',
  Payroll: 'bg-emerald-400',
  Finance: 'bg-violet-400',
  'HR Ops': 'bg-pink-400',
  Comms:   'bg-rose-400',
};

export function Sidebar({ collapsed, onToggle, onMobileClose }) {
  const { session, logout } = useAuth();
  const navigate = useNavigate();
  const cid = session?.companyId || '';

  // Live pending slip count for the badge on "Slip Approvals"
  const [pendingSlips, setPendingSlips] = useState(0);
  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(
      col(cid, 'payment_slips'),
      (docs) => setPendingSlips(docs.filter(d => d.status === 'pending_hr').length),
      [orderBy('createdAt', 'desc')],
    );
    return unsub;
  }, [cid]);

  async function handleLogout() {
    await logout();
    navigate('/login', { replace: true });
  }

  const w = collapsed ? 'w-[64px]' : 'w-[240px]';

  return (
    <aside className={`${w} h-full flex flex-col transition-all duration-300 ease-in-out overflow-hidden sidebar-bg`}>

      {/* ── Logo ─────────────────────────────────────────────────────────── */}
      <div className={`flex items-center h-[60px] shrink-0 border-b border-white/[0.10]
        ${collapsed ? 'justify-center px-0' : 'px-4 gap-3'}`}>
        <div className="shrink-0 w-9 h-9 rounded-xl overflow-hidden bg-white shadow-sm flex items-center justify-center">
          <img src="/logo.png" alt="উদ্যোগী" className="w-full h-full object-contain p-0.5" />
        </div>
        {!collapsed && (
          <div className="flex-1 min-w-0">
            <p className="text-white font-black text-[15px] leading-none tracking-tight">উদ্যোগী</p>
            <p className="text-white/40 text-[10px] leading-none mt-1 font-medium">HR Management</p>
          </div>
        )}
      </div>

      {/* ── User strip ───────────────────────────────────────────────────── */}
      {!collapsed && (
        <div className="flex items-center gap-3 px-4 py-3 border-b border-white/[0.10] shrink-0 bg-white/[0.05]">
          <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center text-white text-xs font-bold shrink-0 overflow-hidden ring-2 ring-white/20">
            {session?.photoUrl
              ? <img src={session.photoUrl} alt="" className="w-full h-full object-cover" />
              : <span>{initials(session?.displayName || 'HR')}</span>}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-white text-[13px] font-semibold truncate leading-tight">
              {session?.displayName || 'HR User'}
            </p>
            <p className="text-white/40 text-[10px] truncate mt-0.5 capitalize">
              {session?.role || 'hr'} · {session?.companyId}
            </p>
          </div>
        </div>
      )}

      {/* ── Nav ──────────────────────────────────────────────────────────── */}
      <nav className="flex-1 overflow-y-auto py-2 px-2 space-y-0.5">
        {NAV.map((group, gi) => (
          <div key={gi} className={gi > 0 ? 'mt-1' : ''}>

            {/* Section label */}
            {group.section && !collapsed && (
              <div className="flex items-center gap-2 px-3 pt-3.5 pb-1">
                <span className={`w-1.5 h-1.5 rounded-full shrink-0 ${SECTION_COLORS[group.section] || 'bg-white/30'}`} />
                <p className="text-[9px] font-black uppercase tracking-[0.15em] text-white/35">
                  {group.section}
                </p>
              </div>
            )}
            {group.section && collapsed && gi > 0 && (
              <div className="my-2 mx-3 border-t border-white/10" />
            )}

            {/* Nav items */}
            {group.items.map(item => {
              const badge = item.to === '/hr/slip-approvals' && pendingSlips > 0
                ? pendingSlips
                : null;
              return (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.end}
                  onClick={onMobileClose}
                  title={collapsed ? `${item.label}${badge ? ` (${badge} pending)` : ''}` : undefined}
                  className={({ isActive }) =>
                    `nav-item ${isActive ? 'nav-item-active' : 'nav-item-inactive'}
                     ${collapsed ? 'justify-center px-0 py-2.5' : ''}`
                  }
                >
                  {({ isActive }) => (
                    <>
                      <div className="relative shrink-0">
                        <item.icon size={15} />
                        {/* Collapsed badge dot */}
                        {badge && collapsed && (
                          <span className="absolute -top-1 -right-1 w-3 h-3 rounded-full bg-yellow-400 border border-white/20 text-[7px] font-black text-gray-900 flex items-center justify-center">
                            {badge > 9 ? '9+' : badge}
                          </span>
                        )}
                      </div>
                      {!collapsed && (
                        <span className="truncate flex-1">{item.label}</span>
                      )}
                      {/* Pending count badge */}
                      {badge && !collapsed && (
                        <span className="ml-auto px-1.5 py-0.5 rounded-full text-[9px] font-black bg-yellow-400 text-gray-900 leading-none">
                          {badge}
                        </span>
                      )}
                      {/* Active indicator dot (only when no badge) */}
                      {isActive && !collapsed && !badge && (
                        <span className="w-1.5 h-1.5 rounded-full bg-white/70 shrink-0" />
                      )}
                    </>
                  )}
                </NavLink>
              );
            })}
          </div>
        ))}
      </nav>

      {/* ── Bottom ───────────────────────────────────────────────────────── */}
      <div className="shrink-0 border-t border-white/[0.10] p-2 space-y-0.5">
        {/* Collapse toggle — desktop only */}
        <button
          onClick={onToggle}
          className={`hidden lg:flex nav-item nav-item-inactive w-full
            ${collapsed ? 'justify-center px-0' : ''}`}
          title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {collapsed
            ? <ChevronRight size={15} />
            : <><ChevronLeft size={15} /><span>Collapse</span></>}
        </button>

        {/* Logout */}
        <button
          onClick={handleLogout}
          className={`nav-item w-full text-red-300/80 hover:text-red-200 hover:bg-red-500/10
            ${collapsed ? 'justify-center px-0' : ''}`}
          title={collapsed ? 'Sign Out' : undefined}
        >
          <LogOut size={15} className="shrink-0" />
          {!collapsed && <span>Sign Out</span>}
        </button>
      </div>
    </aside>
  );
}
