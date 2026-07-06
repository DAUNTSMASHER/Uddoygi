import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Users, DollarSign, Calendar, Clock, TrendingUp, TrendingDown,
  FileText, Bell, CreditCard, ArrowRight, Loader2,
  BookOpen, ShieldCheck, Briefcase, PiggyBank, CheckCircle,
  XCircle, AlertCircle, Building2, Wallet, Receipt, BarChart3,
  ChevronRight, Activity, MessageSquare, Banknote, ArrowUpRight,
  ArrowDownRight, Layers, Target, Zap, UserCheck, AlertTriangle,
  Calculator,
} from 'lucide-react';
import {
  AreaChart, Area, ResponsiveContainer, Tooltip, XAxis, YAxis,
  BarChart, Bar, CartesianGrid, PieChart, Pie, Cell, Legend,
} from 'recharts';
import { collection, doc, onSnapshot, orderBy, limit } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { col, subscribe } from '../lib/db';
import { formatCurrency, formatDate, timeAgo } from '../lib/utils';

// ── Helpers ───────────────────────────────────────────────────────────────────

function greeting() {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

function todayKey() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
}

function compactCurrency(n) {
  if (n == null || isNaN(n)) return '—';
  if (Math.abs(n) >= 10_000_000) return `৳${(n/10_000_000).toFixed(1)}Cr`;
  if (Math.abs(n) >= 100_000)    return `৳${(n/100_000).toFixed(1)}L`;
  if (Math.abs(n) >= 1_000)      return `৳${(n/1_000).toFixed(1)}K`;
  return `৳${Math.round(n).toLocaleString()}`;
}

const STATUS_CLS = {
  green:  'bg-emerald-50 text-emerald-700 border border-emerald-200',
  yellow: 'bg-amber-50 text-amber-700 border border-amber-200',
  red:    'bg-red-50 text-red-700 border border-red-200',
  blue:   'bg-blue-50 text-blue-700 border border-blue-200',
  gray:   'bg-gray-100 text-gray-600 border border-gray-200',
};

function statusVariant(s) {
  const v = (s || '').toLowerCase();
  if (['active','approved','paid','present','verified','received'].includes(v)) return 'green';
  if (['pending','processing','disbursed'].includes(v)) return 'yellow';
  if (['rejected','unpaid','absent','terminated','cancelled'].includes(v)) return 'red';
  if (['closed','repaid'].includes(v)) return 'blue';
  return 'gray';
}

function Badge({ status }) {
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold ${STATUS_CLS[statusVariant(status)]}`}>
      {status || '—'}
    </span>
  );
}

function Sk({ className = '' }) {
  return <div className={`shimmer rounded-xl ${className}`} />;
}

// ── Finance Hero Card ─────────────────────────────────────────────────────────
function FinanceHeroCard({ label, value, sub, delta, deltaUp, icon: Icon, gradient, link }) {
  const inner = (
    <div className={`relative rounded-2xl p-5 overflow-hidden h-full flex flex-col justify-between ${gradient}`}>
      {/* Decorative circle */}
      <div className="absolute -right-6 -top-6 w-28 h-28 rounded-full bg-white/10" />
      <div className="absolute -right-2 -bottom-8 w-20 h-20 rounded-full bg-white/5" />

      <div className="flex items-start justify-between gap-2 relative z-10">
        <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center shrink-0">
          <Icon size={18} className="text-white" />
        </div>
        {delta !== undefined && (
          <div className={`flex items-center gap-1 text-[11px] font-bold px-2 py-0.5 rounded-full
            ${deltaUp ? 'bg-white/20 text-white' : 'bg-white/20 text-white'}`}>
            {deltaUp ? <ArrowUpRight size={10} /> : <ArrowDownRight size={10} />}
            {delta}
          </div>
        )}
      </div>

      <div className="relative z-10 mt-3">
        <p className="text-white/70 text-[11px] font-semibold uppercase tracking-wider mb-1">{label}</p>
        <p className="text-white text-2xl font-black leading-none">{value ?? '—'}</p>
        {sub && <p className="text-white/60 text-xs mt-1.5 leading-tight">{sub}</p>}
      </div>
    </div>
  );
  return link ? <Link to={link} className="block h-full">{inner}</Link> : inner;
}

// ── KPI Tile (white card) ─────────────────────────────────────────────────────
function KpiTile({ label, value, sub, icon: Icon, iconCls, link }) {
  const inner = (
    <div className="bg-white rounded-2xl border border-gray-100 p-4 flex items-center gap-3.5
                    hover:shadow-md hover:border-gray-200 transition-all duration-200 h-full">
      <div className={`w-11 h-11 rounded-xl flex items-center justify-center shrink-0 ${iconCls}`}>
        <Icon size={19} />
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide leading-none mb-1">{label}</p>
        <p className="text-xl font-black text-gray-900 leading-none">{value ?? '—'}</p>
        {sub && <p className="text-[11px] text-gray-400 mt-1 leading-tight">{sub}</p>}
      </div>
      {link && <ChevronRight size={14} className="text-gray-300 shrink-0" />}
    </div>
  );
  return link ? <Link to={link} className="block h-full">{inner}</Link> : inner;
}

// ── Section header ────────────────────────────────────────────────────────────
function SectionHead({ title, link, linkLabel = 'View all' }) {
  return (
    <div className="flex items-center justify-between mb-3">
      <h3 className="text-[13px] font-bold text-gray-800 flex items-center gap-2">
        <span className="w-1 h-4 rounded-full bg-[#065F46] inline-block" />
        {title}
      </h3>
      {link && (
        <Link to={link} className="flex items-center gap-1 text-[11px] font-semibold text-[#065F46] hover:underline">
          {linkLabel} <ArrowRight size={11} />
        </Link>
      )}
    </div>
  );
}

// ── Alert pill ────────────────────────────────────────────────────────────────
function AlertPill({ count, label, to, color }) {
  if (!count) return null;
  return (
    <Link to={to}
      className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition hover:opacity-90 ${color}`}>
      <AlertTriangle size={11} />
      {count} {label}{count !== 1 ? 's' : ''}
    </Link>
  );
}

// ── Attendance ring ───────────────────────────────────────────────────────────
function AttRing({ present, absent, late }) {
  const total = present + absent + late || 1;
  const data = [
    { name: 'Present', value: present, color: '#10b981' },
    { name: 'Absent',  value: absent,  color: '#ef4444' },
    { name: 'Late',    value: late,    color: '#f59e0b' },
  ].filter(d => d.value > 0);
  if (data.length === 0) data.push({ name: 'No data', value: 1, color: '#e5e7eb' });

  return (
    <div className="flex items-center gap-4">
      <div className="w-20 h-20 shrink-0">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie data={data} cx="50%" cy="50%" innerRadius={22} outerRadius={36}
              dataKey="value" strokeWidth={0}>
              {data.map((d, i) => <Cell key={i} fill={d.color} />)}
            </Pie>
          </PieChart>
        </ResponsiveContainer>
      </div>
      <div className="space-y-1.5 flex-1">
        {[
          { label: 'Present', val: present, color: 'bg-emerald-500' },
          { label: 'Absent',  val: absent,  color: 'bg-red-500' },
          { label: 'Late',    val: late,    color: 'bg-amber-500' },
        ].map(r => (
          <div key={r.label} className="flex items-center gap-2">
            <span className={`w-2 h-2 rounded-full shrink-0 ${r.color}`} />
            <span className="text-[11px] text-gray-500 flex-1">{r.label}</span>
            <span className="text-[11px] font-bold text-gray-800">{r.val}</span>
            <span className="text-[10px] text-gray-400">
              {Math.round((r.val / total) * 100)}%
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Main Dashboard ────────────────────────────────────────────────────────────
export function DashboardPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [stats, setStats] = useState({
    employees: 0, activeEmployees: 0,
    payrollPaid: 0, payrollPending: 0,
    leavePending: 0, leaveApproved: 0,
    budgetTotal: 0, budgetMin: 0,
    credits: 0, expenses: 0,
    cashIn: 0, cashOut: 0,
    outstandingLoans: 0,
    pendingSlips: 0, pendingLoans: 0,
    presentToday: 0, absentToday: 0, lateToday: 0,
    complaints: 0,
  });
  const [recentPayroll,  setRecentPayroll]  = useState([]);
  const [recentLeaves,   setRecentLeaves]   = useState([]);
  const [recentLoans,    setRecentLoans]    = useState([]);
  const [recentExpenses, setRecentExpenses] = useState([]);
  const [notices,        setNotices]        = useState([]);
  const [payrollChart,   setPayrollChart]   = useState([]);
  const [expenseChart,   setExpenseChart]   = useState([]);
  const [loading,        setLoading]        = useState(true);

  useEffect(() => {
    if (!cid) return;
    const unsubs = [];

    // Employees
    unsubs.push(subscribe(col(cid, 'users'), (docs) => {
      setStats(s => ({
        ...s,
        employees: docs.length,
        activeEmployees: docs.filter(d => (d.status || 'active').toLowerCase() === 'active').length,
      }));
      setLoading(false);
    }));

    // Payroll
    unsubs.push(subscribe(col(cid, 'payrolls'), (docs) => {
      const paid    = docs.filter(d => (d.status||'').toLowerCase() === 'paid');
      const pending = docs.filter(d => (d.status||'').toLowerCase() !== 'paid');
      setStats(s => ({
        ...s,
        payrollPaid:    paid.reduce((a, d)    => a + (d.netSalary||d.amount||0), 0),
        payrollPending: pending.reduce((a, d) => a + (d.netSalary||d.amount||0), 0),
      }));
      setRecentPayroll(docs.slice(0, 7));

      const byPeriod = {};
      docs.forEach(d => {
        const k = d.period || formatDate(d.generatedAt||d.createdAt, 'MMM yy');
        if (k && k !== '—') byPeriod[k] = (byPeriod[k]||0) + (d.netSalary||d.amount||0);
      });
      setPayrollChart(Object.entries(byPeriod).slice(-6).map(([name, v]) => ({ name, v })));
    }, [orderBy('createdAt','desc'), limit(60)]));

    // Leaves
    unsubs.push(subscribe(col(cid, 'leaves'), (docs) => {
      setStats(s => ({
        ...s,
        leavePending:  docs.filter(d => (d.status||'').toLowerCase() === 'pending').length,
        leaveApproved: docs.filter(d => (d.status||'').toLowerCase() === 'approved').length,
      }));
      setRecentLeaves(docs.slice(0, 5));
    }, [orderBy('createdAt','desc'), limit(20)]));

    // Budgets
    unsubs.push(subscribe(col(cid, 'budgets'), (docs) => {
      setStats(s => ({
        ...s,
        budgetTotal: docs.reduce((a, d) => a + (d.totalNeed||d.amount||d.totalBudget||0), 0),
        budgetMin:   docs.reduce((a, d) => a + (d.totalMin||d.spent||d.usedAmount||0), 0),
      }));
    }));

    // Expenses — recent entries from expenses collection for the "Recent Expenses" widget only
    unsubs.push(subscribe(col(cid, 'expenses'), (docs) => {
      setRecentExpenses(docs.slice(0, 5));
    }, [orderBy('createdAt','desc'), limit(40)]));

    // Notices
    unsubs.push(subscribe(col(cid, 'notices'), (docs) => {
      setNotices(docs.slice(0, 4));
    }, [orderBy('createdAt','desc'), limit(4)]));

    // Payment slips
    unsubs.push(subscribe(col(cid, 'payment_slips'), (docs) => {
      setStats(s => ({
        ...s,
        pendingSlips: docs.filter(d => (d.status||'').toLowerCase() === 'pending').length,
      }));
    }));

    // Loans
    unsubs.push(subscribe(col(cid, 'loans'), (docs) => {
      // Outstanding = disbursed loans not yet fully repaid
      const outstanding = docs
        .filter(d => {
          const s = (d.status || '').toLowerCase();
          return s === 'disbursed' || s === 'approved';
        })
        .reduce((sum, d) => {
          const principal = d.disbursedAmount || d.amount || 0;
          const repaid    = d.repaidAmount || d.totalRepaid || 0;
          return sum + Math.max(0, principal - repaid);
        }, 0);
      setStats(s => ({
        ...s,
        pendingLoans:    docs.filter(d => (d.status||'').toLowerCase() === 'pending').length,
        outstandingLoans: outstanding,
      }));
      setRecentLoans(docs.slice(0, 4));
    }, [orderBy('createdAt','desc'), limit(10)]));

    // Credits + Cash-out — derived live from cash_flow (single source of truth)
    // Reversal entries are audit-only and NOT counted.
    unsubs.push(subscribe(col(cid, 'cash_flow'), (docs) => {
      let totalIn = 0, totalOut = 0;
      const byMonth = {};
      docs.forEach(d => {
        const amt = d.amount || 0;
        if (d.type === 'cash_in')  totalIn  += amt;
        if (d.type === 'cash_out') {
          totalOut += amt;
          // Build expense chart from cash_out entries
          const ts = d.createdAt;
          if (ts) {
            const dt = ts?.toDate ? ts.toDate() : new Date((ts.seconds || 0) * 1000);
            const k  = dt.toLocaleDateString('en-US', { month: 'short', year: '2-digit' });
            byMonth[k] = (byMonth[k] || 0) + amt;
          }
        }
      });
      setExpenseChart(Object.entries(byMonth).slice(-6).map(([name, v]) => ({ name, v })));
      setStats(s => ({ ...s, credits: totalIn, cashIn: totalIn, cashOut: totalOut }));
    }));

    // Company profile — still subscribed for other fields (lastCashOutItem, etc.)
    const cpRef = doc(db, 'data', cid, 'company_profile', 'main');
    unsubs.push(onSnapshot(cpRef, snap => {
      if (snap.exists()) {
        // cashIn/cashOut intentionally NOT read from here — use live cash_flow sums above
        const d = snap.data();
        setStats(s => ({ ...s, _profileData: d }));
      }
    }));

    // Complaints
    unsubs.push(subscribe(col(cid, 'complaints'), (docs) => {
      setStats(s => ({
        ...s,
        complaints: docs.filter(d => (d.status||'').toLowerCase() === 'pending').length,
      }));
    }));

    // Attendance today
    const todayRecordsRef = collection(db, 'data', cid, 'attendance', todayKey(), 'records');
    unsubs.push(onSnapshot(todayRecordsRef, snap => {
      const recs = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setStats(s => ({
        ...s,
        presentToday: recs.filter(r => (r.status||'').toLowerCase() === 'present').length,
        absentToday:  recs.filter(r => (r.status||'').toLowerCase() === 'absent').length,
        lateToday:    recs.filter(r => (r.status||'').toLowerCase() === 'late').length,
      }));
    }));

    return () => unsubs.forEach(u => u?.());
  }, [cid]);

  // balance = credit − expenses − outstanding_loans
  const cashBalance = stats.cashIn - stats.cashOut - stats.outstandingLoans;
  const budgetPct   = stats.budgetTotal > 0
    ? Math.min(100, Math.round((stats.budgetMin / stats.budgetTotal) * 100)) : 0;
  const today = new Date().toLocaleDateString('en-BD', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  });

  if (loading) {
    return (
      <div className="space-y-5 pb-8 fade-in">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {[...Array(4)].map((_,i) => <Sk key={i} className="h-32" />)}
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
          {[...Array(6)].map((_,i) => <Sk key={i} className="h-20" />)}
        </div>
        <div className="grid lg:grid-cols-3 gap-5">
          <Sk className="lg:col-span-2 h-64" />
          <Sk className="h-64" />
        </div>
        <div className="flex items-center justify-center py-6 gap-2">
          <Loader2 size={16} className="animate-spin text-[#065F46]" />
          <span className="text-sm text-gray-400">Loading dashboard…</span>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-5 pb-10 fade-in">

      {/* ── Page header ────────────────────────────────────────────────────── */}
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mb-0.5">{today}</p>
          <h1 className="text-xl font-black text-gray-900 leading-tight">
            {greeting()}, <span className="text-[#065F46]">{session?.displayName?.split(' ')[0] || 'HR'}</span>
          </h1>
          <p className="text-xs text-gray-500 mt-0.5">Real-time company financial overview</p>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <AlertPill count={stats.pendingSlips}  label="slip"      to="/hr/slip-approvals" color="bg-amber-50 text-amber-700 border-amber-200" />
          <AlertPill count={stats.pendingLoans}  label="loan"      to="/hr/loans"          color="bg-blue-50 text-blue-700 border-blue-200" />
          <AlertPill count={stats.complaints}    label="complaint" to="/hr/complaints"     color="bg-red-50 text-red-700 border-red-200" />
          <AlertPill count={stats.leavePending}  label="leave req" to="/hr/leave"          color="bg-purple-50 text-purple-700 border-purple-200" />
        </div>
      </div>

      {/* ── Finance hero strip (4 gradient cards) ──────────────────────────── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <FinanceHeroCard
          label="Net Balance"
          value={compactCurrency(cashBalance)}
          sub={`Credit ${compactCurrency(stats.cashIn)} · Exp ${compactCurrency(stats.cashOut)} · Loans ${compactCurrency(stats.outstandingLoans)}`}
          icon={Wallet}
          gradient={cashBalance >= 0
            ? 'bg-gradient-to-br from-[#065F46] to-[#2563EB]'
            : 'bg-gradient-to-br from-red-700 to-red-500'}
          link="/hr/credits"
        />
        <FinanceHeroCard
          label="Payroll Disbursed"
          value={compactCurrency(stats.payrollPaid)}
          sub={`${compactCurrency(stats.payrollPending)} pending`}
          icon={DollarSign}
          gradient="bg-gradient-to-br from-emerald-700 to-emerald-500"
          link="/hr/payroll"
        />
        <FinanceHeroCard
          label="Budget Allocated"
          value={compactCurrency(stats.budgetTotal)}
          sub={`${budgetPct}% minimum need met`}
          icon={Target}
          gradient="bg-gradient-to-br from-violet-700 to-violet-500"
          link="/hr/budget"
        />
        <FinanceHeroCard
          label="Total Expenses"
          value={compactCurrency(stats.cashOut)}
          sub={`Credits: ${compactCurrency(stats.cashIn)}`}
          icon={TrendingDown}
          gradient="bg-gradient-to-br from-rose-700 to-rose-500"
          link="/hr/expenses"
        />
      </div>

      {/* ── KPI tiles (6-up) ───────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
        <KpiTile label="Employees"    value={stats.employees}    sub={`${stats.activeEmployees} active`}    icon={Users}       iconCls="bg-blue-50 text-blue-600"    link="/hr/employees" />
        <KpiTile label="Present"      value={stats.presentToday} sub="today"                                icon={CheckCircle} iconCls="bg-emerald-50 text-emerald-600" link="/hr/attendance" />
        <KpiTile label="Absent"       value={stats.absentToday}  sub="today"                                icon={XCircle}     iconCls="bg-red-50 text-red-500"      link="/hr/attendance" />
        <KpiTile label="Late"         value={stats.lateToday}    sub="today"                                icon={Clock}       iconCls="bg-amber-50 text-amber-600"  link="/hr/attendance" />
        <KpiTile label="Leave Reqs"   value={stats.leavePending} sub={`${stats.leaveApproved} approved`}    icon={Calendar}    iconCls="bg-purple-50 text-purple-600" link="/hr/leave" />
        <KpiTile label="Pending Slips" value={stats.pendingSlips} sub="awaiting approval"                   icon={Receipt}     iconCls="bg-orange-50 text-orange-600" link="/hr/slip-approvals" />
      </div>

      {/* ── Budget utilisation bar ─────────────────────────────────────────── */}
      {stats.budgetTotal > 0 && (
        <div className="bg-white rounded-2xl border border-gray-100 px-5 py-4">
          <div className="flex items-center justify-between mb-2 gap-4">
            <div className="flex items-center gap-2 min-w-0">
              <Target size={14} className="text-violet-600 shrink-0" />
              <p className="text-[13px] font-bold text-gray-800">Budget Utilisation</p>
              <span className="text-[11px] text-gray-400 hidden sm:inline">
                — {compactCurrency(stats.budgetMin)} minimum of {compactCurrency(stats.budgetTotal)} allocated
              </span>
            </div>
            <div className="flex items-center gap-3 shrink-0">
              <span className={`text-sm font-black ${budgetPct > 90 ? 'text-red-600' : budgetPct > 70 ? 'text-amber-600' : 'text-emerald-600'}`}>
                {budgetPct}%
              </span>
              <Link to="/hr/budget" className="text-[11px] font-semibold text-[#065F46] hover:underline flex items-center gap-0.5">
                Details <ChevronRight size={10} />
              </Link>
            </div>
          </div>
          <div className="w-full bg-gray-100 rounded-full h-2.5">
            <div
              className={`h-2.5 rounded-full transition-all duration-700
                ${budgetPct > 90 ? 'bg-red-500' : budgetPct > 70 ? 'bg-amber-500' : 'bg-violet-600'}`}
              style={{ width: `${budgetPct}%` }}
            />
          </div>
          <div className="flex justify-between mt-1 text-[10px] text-gray-300">
            <span>0%</span><span>25%</span><span>50%</span><span>75%</span><span>100%</span>
          </div>
        </div>
      )}

      {/* ── Main 3-column grid ─────────────────────────────────────────────── */}
      <div className="grid lg:grid-cols-3 gap-5 items-start">

        {/* ── Left col (2/3) ───────────────────────────────────────────────── */}
        <div className="lg:col-span-2 space-y-5">

          {/* Payroll + Expense dual chart */}
          <div className="bg-white rounded-2xl border border-gray-100 p-5">
            <div className="flex items-center justify-between mb-4 gap-4">
              <h3 className="text-[13px] font-bold text-gray-800 flex items-center gap-2">
                <span className="w-1 h-4 rounded-full bg-[#065F46] inline-block" />
                Financial Trends
              </h3>
              <div className="flex items-center gap-3 text-[11px] text-gray-400">
                <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-sm bg-[#065F46] inline-block" />Payroll</span>
                <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-sm bg-rose-400 inline-block" />Expenses</span>
              </div>
            </div>
            {payrollChart.length > 1 ? (
              <div className="h-52">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart
                    data={payrollChart.map((p, i) => ({
                      name: p.name,
                      payroll: p.v,
                      expense: expenseChart[i]?.v || 0,
                    }))}
                    margin={{ top: 4, right: 4, left: 0, bottom: 0 }}
                  >
                    <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" vertical={false} />
                    <XAxis dataKey="name" tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                    <YAxis
                      tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false}
                      tickFormatter={v => `৳${(v/1000).toFixed(0)}K`} width={44}
                    />
                    <Tooltip
                      formatter={(v, name) => [compactCurrency(v), name === 'payroll' ? 'Net Payroll' : 'Expenses']}
                      contentStyle={{ borderRadius: 10, border: '1px solid #e5e7eb', fontSize: 11 }}
                    />
                    <Bar dataKey="payroll" fill="#065F46" radius={[4,4,0,0]} maxBarSize={32} />
                    <Bar dataKey="expense" fill="#fb7185" radius={[4,4,0,0]} maxBarSize={32} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <div className="h-52 flex items-center justify-center text-gray-300 text-sm">
                Not enough data yet
              </div>
            )}
          </div>

          {/* Cash flow + Payroll side by side */}
          <div className="grid sm:grid-cols-2 gap-4">
            {/* Cash flow */}
            <div className="bg-white rounded-2xl border border-gray-100 p-5">
              <SectionHead title="Cash Flow" link="/hr/balance" />
              <div className="space-y-2.5 mt-1">
                {[
                  { label: 'Credit (Cash In)',      val: stats.cashIn,           color: 'bg-emerald-500', textColor: 'text-emerald-700', bg: 'bg-emerald-50' },
                  { label: 'Expenses (Cash Out)',   val: stats.cashOut,          color: 'bg-red-500',     textColor: 'text-red-700',     bg: 'bg-red-50' },
                  { label: 'Outstanding Loans',     val: stats.outstandingLoans, color: 'bg-amber-500',   textColor: 'text-amber-700',   bg: 'bg-amber-50' },
                  { label: 'Net Balance',           val: cashBalance,
                    color: cashBalance >= 0 ? 'bg-[#065F46]' : 'bg-red-500',
                    textColor: cashBalance >= 0 ? 'text-[#065F46]' : 'text-red-700',
                    bg: cashBalance >= 0 ? 'bg-[#065F46]/5' : 'bg-red-50' },
                ].map(r => (
                  <div key={r.label} className={`flex items-center justify-between px-3.5 py-2.5 rounded-xl ${r.bg}`}>
                    <div className="flex items-center gap-2.5">
                      <span className={`w-2 h-2 rounded-full ${r.color}`} />
                      <span className="text-xs font-semibold text-gray-600">{r.label}</span>
                    </div>
                    <span className={`text-sm font-black ${r.textColor}`}>{compactCurrency(r.val)}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Attendance today */}
            <div className="bg-white rounded-2xl border border-gray-100 p-5">
              <SectionHead title="Today's Attendance" link="/hr/attendance" />
              <AttRing
                present={stats.presentToday}
                absent={stats.absentToday}
                late={stats.lateToday}
              />
            </div>
          </div>

          {/* Recent payroll table */}
          <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
            <div className="px-5 pt-4 pb-3 border-b border-gray-50">
              <SectionHead title="Recent Payroll" link="/hr/payroll" />
            </div>
            {recentPayroll.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-10 text-center">
                <div className="w-10 h-10 rounded-xl bg-gray-100 flex items-center justify-center mb-2">
                  <DollarSign size={18} className="text-gray-300" />
                </div>
                <p className="text-xs text-gray-400">No payroll records yet</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-gray-50/80">
                      {['Employee','Period','Dept','Net Salary','Status'].map(h => (
                        <th key={h} className="px-4 py-2.5 text-left text-[10px] font-bold text-gray-400 uppercase tracking-widest whitespace-nowrap">
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {recentPayroll.map(p => (
                      <tr key={p.id} className="hover:bg-gray-50/50 transition-colors">
                        <td className="px-4 py-2.5 font-semibold text-gray-900 whitespace-nowrap text-[13px]">
                          {p.employeeName || p.name || '—'}
                        </td>
                        <td className="px-4 py-2.5 text-gray-500 text-xs whitespace-nowrap">
                          {p.period || formatDate(p.generatedAt||p.createdAt, 'MMM yyyy')}
                        </td>
                        <td className="px-4 py-2.5 text-gray-500 text-xs whitespace-nowrap capitalize">
                          {p.department || '—'}
                        </td>
                        <td className="px-4 py-2.5 text-right font-bold text-gray-900 whitespace-nowrap text-[13px]">
                          {compactCurrency(p.netSalary || p.amount)}
                        </td>
                        <td className="px-4 py-2.5 whitespace-nowrap">
                          <Badge status={p.status || 'pending'} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          {/* Recent expenses */}
          {recentExpenses.length > 0 && (
            <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
              <div className="px-5 pt-4 pb-3 border-b border-gray-50">
                <SectionHead title="Recent Expenses" link="/hr/expenses" />
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-gray-50/80">
                      {['Title','Category','Due Date','Amount','Status'].map(h => (
                        <th key={h} className="px-4 py-2.5 text-left text-[10px] font-bold text-gray-400 uppercase tracking-widest whitespace-nowrap">
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {recentExpenses.map(e => (
                      <tr key={e.id} className="hover:bg-gray-50/50 transition-colors">
                        <td className="px-4 py-2.5 font-semibold text-gray-900 whitespace-nowrap text-[13px]">
                          {e.title || e.description || '—'}
                        </td>
                        <td className="px-4 py-2.5 text-gray-500 text-xs whitespace-nowrap capitalize">
                          {e.category || '—'}
                        </td>
                        <td className="px-4 py-2.5 text-gray-500 text-xs whitespace-nowrap">
                          {formatDate(e.dueDate)}
                        </td>
                        <td className="px-4 py-2.5 text-right font-bold text-rose-600 whitespace-nowrap text-[13px]">
                          {compactCurrency(e.amount)}
                        </td>
                        <td className="px-4 py-2.5 whitespace-nowrap">
                          <Badge status={e.status || 'pending'} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>

        {/* ── Right col (1/3) ──────────────────────────────────────────────── */}
        <div className="space-y-4">

          {/* Pending approvals block */}
          {(stats.pendingSlips > 0 || stats.pendingLoans > 0) && (
            <div className="bg-white rounded-2xl border border-gray-100 p-4 space-y-2.5">
              <p className="text-[12px] font-bold text-gray-700 flex items-center gap-2">
                <Zap size={13} className="text-amber-500" /> Needs Attention
              </p>
              {stats.pendingSlips > 0 && (
                <Link to="/hr/slip-approvals"
                  className="flex items-center gap-3 p-3 rounded-xl bg-amber-50 border border-amber-100 hover:bg-amber-100 transition group">
                  <div className="w-9 h-9 rounded-xl bg-amber-100 text-amber-700 flex items-center justify-center shrink-0">
                    <Receipt size={15} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-bold text-amber-800 leading-tight">
                      {stats.pendingSlips} Payment Slip{stats.pendingSlips !== 1 ? 's' : ''}
                    </p>
                    <p className="text-[10px] text-amber-600 mt-0.5">Awaiting approval</p>
                  </div>
                  <ChevronRight size={13} className="text-amber-400 group-hover:translate-x-0.5 transition-transform" />
                </Link>
              )}
              {stats.pendingLoans > 0 && (
                <Link to="/hr/loans"
                  className="flex items-center gap-3 p-3 rounded-xl bg-blue-50 border border-blue-100 hover:bg-blue-100 transition group">
                  <div className="w-9 h-9 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center shrink-0">
                    <PiggyBank size={15} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-bold text-blue-800 leading-tight">
                      {stats.pendingLoans} Loan Request{stats.pendingLoans !== 1 ? 's' : ''}
                    </p>
                    <p className="text-[10px] text-blue-600 mt-0.5">Review pending</p>
                  </div>
                  <ChevronRight size={13} className="text-blue-400 group-hover:translate-x-0.5 transition-transform" />
                </Link>
              )}
            </div>
          )}

          {/* Leave requests */}
          {recentLeaves.length > 0 && (
            <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
              <div className="px-4 pt-4 pb-2.5 border-b border-gray-50">
                <SectionHead title="Leave Requests" link="/hr/leave" />
              </div>
              <div className="divide-y divide-gray-50">
                {recentLeaves.map(l => (
                  <div key={l.id} className="px-4 py-2.5 flex items-center gap-3 hover:bg-gray-50/50 transition-colors">
                    <div className="w-8 h-8 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center shrink-0">
                      <Calendar size={13} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-[12px] font-semibold text-gray-800 truncate leading-tight">
                        {l.employeeName || l.name || '—'}
                      </p>
                      <p className="text-[10px] text-gray-400 mt-0.5">
                        {l.leaveType || l.type || '—'} · {formatDate(l.startDate||l.from, 'dd MMM')}
                      </p>
                    </div>
                    <Badge status={l.status || 'pending'} />
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Loan requests */}
          {recentLoans.length > 0 && (
            <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
              <div className="px-4 pt-4 pb-2.5 border-b border-gray-50">
                <SectionHead title="Loan Requests" link="/hr/loans" />
              </div>
              <div className="divide-y divide-gray-50">
                {recentLoans.map(l => (
                  <div key={l.id} className="px-4 py-2.5 flex items-center gap-3 hover:bg-gray-50/50 transition-colors">
                    <div className="w-8 h-8 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center shrink-0">
                      <PiggyBank size={13} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-[12px] font-semibold text-gray-800 truncate leading-tight">
                        {l.employeeName || l.name || l.userEmail || '—'}
                      </p>
                      <p className="text-[10px] text-gray-400 mt-0.5">{compactCurrency(l.amount)}</p>
                    </div>
                    <Badge status={l.status || 'pending'} />
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Notices */}
          <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
            <div className="px-4 pt-4 pb-2.5 border-b border-gray-50">
              <SectionHead title="Latest Notices" link="/hr/notices" />
            </div>
            {notices.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-8 text-center">
                <Bell size={18} className="text-gray-200 mb-2" />
                <p className="text-[11px] text-gray-400">No notices yet</p>
              </div>
            ) : (
              <div className="divide-y divide-gray-50">
                {notices.map(n => (
                  <div key={n.id} className="px-4 py-2.5 hover:bg-gray-50/50 transition-colors">
                    <div className="flex items-start gap-2.5">
                      <span className={`w-2 h-2 rounded-full mt-1.5 shrink-0 ${
                        (n.priority||'').toLowerCase() === 'urgent' ? 'bg-red-500' :
                        (n.priority||'').toLowerCase() === 'high'   ? 'bg-amber-500' : 'bg-[#065F46]'
                      }`} />
                      <div className="min-w-0 flex-1">
                        <p className="text-[12px] font-semibold text-gray-800 line-clamp-1 leading-tight">
                          {n.title || 'Notice'}
                        </p>
                        <p className="text-[10px] text-gray-400 mt-0.5">{timeAgo(n.createdAt)}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Finance quick links */}
          <div className="bg-white rounded-2xl border border-gray-100 p-4">
            <p className="text-[12px] font-bold text-gray-700 mb-3 flex items-center gap-2">
              <Layers size={13} className="text-[#065F46]" /> Finance Quick Links
            </p>
            <div className="grid grid-cols-2 gap-2">
              {[
                { label: 'Payroll',    icon: DollarSign,  to: '/hr/payroll',        bg: 'bg-[#065F46]/10 text-[#065F46]' },
                { label: 'Budget',     icon: Target,      to: '/hr/budget',         bg: 'bg-violet-100 text-violet-700' },
                { label: 'Expenses',   icon: TrendingDown,to: '/hr/expenses',       bg: 'bg-rose-100 text-rose-700' },
                { label: 'Credits',    icon: CreditCard,  to: '/hr/credits',        bg: 'bg-teal-100 text-teal-700' },
                { label: 'Loans',      icon: PiggyBank,   to: '/hr/loans',          bg: 'bg-amber-100 text-amber-700' },
                { label: 'Accounts',   icon: Building2,   to: '/hr/accounts',       bg: 'bg-cyan-100 text-cyan-700' },
                { label: 'Tax',        icon: Calculator,  to: '/hr/tax',            bg: 'bg-gray-100 text-gray-700' },
                { label: 'Slips',      icon: Receipt,     to: '/hr/slip-approvals', bg: 'bg-orange-100 text-orange-700' },
              ].map(a => (
                <Link key={a.label} to={a.to}
                  className="flex items-center gap-2 px-2.5 py-2 rounded-xl hover:bg-gray-50 border border-gray-100 hover:border-gray-200 transition group">
                  <div className={`w-7 h-7 rounded-lg flex items-center justify-center shrink-0 ${a.bg}`}>
                    <a.icon size={13} />
                  </div>
                  <span className="text-[11px] font-semibold text-gray-700 group-hover:text-[#065F46] truncate">
                    {a.label}
                  </span>
                </Link>
              ))}
            </div>
          </div>

          {/* People quick links */}
          <div className="bg-white rounded-2xl border border-gray-100 p-4">
            <p className="text-[12px] font-bold text-gray-700 mb-3 flex items-center gap-2">
              <UserCheck size={13} className="text-blue-600" /> People & Comms
            </p>
            <div className="grid grid-cols-2 gap-2">
              {[
                { label: 'Employees',   icon: Users,         to: '/hr/employees',   bg: 'bg-blue-100 text-blue-700' },
                { label: 'Attendance',  icon: Clock,         to: '/hr/attendance',  bg: 'bg-orange-100 text-orange-700' },
                { label: 'Leave',       icon: Calendar,      to: '/hr/leave',       bg: 'bg-purple-100 text-purple-700' },
                { label: 'Shifts',      icon: BarChart3,     to: '/hr/shifts',      bg: 'bg-indigo-100 text-indigo-700' },
                { label: 'Notices',     icon: Bell,          to: '/hr/notices',     bg: 'bg-rose-100 text-rose-700' },
                { label: 'Messages',    icon: MessageSquare, to: '/hr/messages',    bg: 'bg-sky-100 text-sky-700' },
                { label: 'Complaints',  icon: AlertCircle,   to: '/hr/complaints',  bg: 'bg-red-100 text-red-700' },
                { label: 'Recruitment', icon: Briefcase,     to: '/hr/recruitment', bg: 'bg-emerald-100 text-emerald-700' },
              ].map(a => (
                <Link key={a.label} to={a.to}
                  className="flex items-center gap-2 px-2.5 py-2 rounded-xl hover:bg-gray-50 border border-gray-100 hover:border-gray-200 transition group">
                  <div className={`w-7 h-7 rounded-lg flex items-center justify-center shrink-0 ${a.bg}`}>
                    <a.icon size={13} />
                  </div>
                  <span className="text-[11px] font-semibold text-gray-700 group-hover:text-[#065F46] truncate">
                    {a.label}
                  </span>
                </Link>
              ))}
            </div>
          </div>

        </div>
      </div>
    </div>
  );
}
