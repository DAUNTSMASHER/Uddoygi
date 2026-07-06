// ROIPage.jsx — Performance & ROI Analytics
// Mirrors Flutter ROI.dart exactly:
//   Formula: N = incentive × (100/15), EC = salary×months + incentive + otherCosts
//             NR = N − EC,  ROI% = NR/EC × 100
// Data: users collection + marketingIncentives collection + payrolls collection
import { useEffect, useState, useMemo } from 'react';
import {
  TrendingUp, TrendingDown, Users, Star, AlertTriangle,
  Search, Filter, Download, Loader2, ChevronDown, ChevronUp,
  Award, Target, BarChart2, RefreshCw, X,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, orderBy } from '../lib/db';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

const BRAND   = '#065F46';
const BRAND2  = '#2563EB';
const GREEN   = '#22C55E';
const RED     = '#EF4444';
const AMBER   = '#F59E0B';
const DEPTS   = ['All', 'marketing', 'factory', 'hr', 'admin', 'rnd'];
const PRESETS = ['This Month', 'Last 30 Days', 'Custom'];

function n(v) {
  if (v == null) return 0;
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return parseFloat(v.replace(/[^0-9.\-]/g, '')) || 0;
  return 0;
}
function pct(v) { return `${(v * 100).toFixed(1)}%`; }
function fmt(v) {
  return new Intl.NumberFormat('en-BD', { minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(v || 0);
}

function getPresetRange(preset) {
  const now = new Date();
  if (preset === 'This Month') {
    return {
      from: new Date(now.getFullYear(), now.getMonth(), 1),
      to:   new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59),
    };
  }
  if (preset === 'Last 30 Days') {
    const from = new Date(now); from.setDate(from.getDate() - 29);
    return { from, to: new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59) };
  }
  return null;
}

function computeROI(incentive, salaryPerMonth, months, otherCosts) {
  const N  = incentive * (100.0 / 15.0);
  const T  = salaryPerMonth * months;
  const EC = T + incentive + otherCosts;
  const NR = N - EC;
  const roi = EC === 0 ? 0 : NR / EC;
  return { N, T, EC, NR, roi };
}

function roiColor(roi) {
  if (roi > 0.3) return GREEN;
  if (roi >= 0)  return AMBER;
  return RED;
}

export function ROIPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [employees,   setEmployees]   = useState([]);
  const [incentives,  setIncentives]  = useState([]);
  const [payrolls,    setPayrolls]    = useState([]);
  const [loading,     setLoading]     = useState(true);

  const [deptFilter,  setDeptFilter]  = useState('All');
  const [empSearch,   setEmpSearch]   = useState('');
  const [preset,      setPreset]      = useState('This Month');
  const [customFrom,  setCustomFrom]  = useState('');
  const [customTo,    setCustomTo]    = useState('');
  const [analyzedId,  setAnalyzedId]  = useState(null);
  const [expanded,    setExpanded]    = useState({});

  // Date range
  const dateRange = useMemo(() => {
    if (preset !== 'Custom') return getPresetRange(preset);
    if (customFrom && customTo) return { from: new Date(customFrom), to: new Date(customTo + 'T23:59:59') };
    return getPresetRange('This Month');
  }, [preset, customFrom, customTo]);

  const periodLabel = useMemo(() => {
    if (!dateRange) return '';
    if (preset !== 'Custom') return preset;
    return `${dateRange.from.toLocaleDateString('en-BD', { day: '2-digit', month: 'short' })} – ${dateRange.to.toLocaleDateString('en-BD', { day: '2-digit', month: 'short', year: 'numeric' })}`;
  }, [dateRange, preset]);

  useEffect(() => {
    if (!cid) return;
    const unsubs = [];
    unsubs.push(subscribe(col(cid, 'users'), docs => { setEmployees(docs); setLoading(false); }));
    unsubs.push(subscribe(col(cid, 'marketingIncentives'), docs => setIncentives(docs)));
    unsubs.push(subscribe(col(cid, 'payrolls'), docs => setPayrolls(docs), [orderBy('createdAt', 'desc')]));
    return () => unsubs.forEach(u => u?.());
  }, [cid]);

  // Build per-employee ROI data
  const roiData = useMemo(() => {
    if (!dateRange) return [];
    const { from, to } = dateRange;

    return employees.map(emp => {
      const empId    = emp.id;
      const name     = emp.fullName || emp.name || emp.email || 'Unknown';
      const dept     = (emp.department || '').toLowerCase();
      const email    = emp.email || emp.officeEmail || '';

      // Sum incentives in range
      const empIncentives = incentives.filter(inc => {
        const ts = inc.createdAt || inc.timestamp;
        if (!ts) return false;
        const dt = ts?.toDate ? ts.toDate() : new Date((ts.seconds || 0) * 1000);
        return dt >= from && dt <= to && (
          inc.employeeId === empId || inc.employeeUid === empId ||
          (inc.agentEmail || '').toLowerCase() === email.toLowerCase() ||
          (inc.id || '').toLowerCase().startsWith(email.toLowerCase())
        );
      });
      const totalIncentive = empIncentives.reduce((s, i) => s + n(i.totalIncentive || i.incentive), 0);

      // Get salary from payrolls
      const empPayrolls = payrolls.filter(p => {
        const emps = p.employees || [];
        return emps.some(e => e.employeeId === empId || e.employeeUid === empId || e.officeEmail === email);
      });
      const avgSalary = empPayrolls.length > 0
        ? empPayrolls.reduce((s, p) => {
            const row = (p.employees || []).find(e => e.employeeId === empId || e.officeEmail === email);
            return s + n(row?.netSalary || p.netSalary || 0);
          }, 0) / empPayrolls.length
        : n(emp.basicSalary || emp.salary || 0);

      const months = Math.max(1, Math.round((to - from) / (1000 * 60 * 60 * 24 * 30)));
      const roi = computeROI(totalIncentive, avgSalary, months, 0);

      return {
        id: empId, name, dept, email,
        incentive: totalIncentive,
        salary: avgSalary,
        months,
        ...roi,
        photoUrl: emp.photoUrl || emp.profilePhotoUrl || '',
      };
    });
  }, [employees, incentives, payrolls, dateRange]);

  // Filtered list
  const filtered = useMemo(() => {
    return roiData.filter(e => {
      const matchDept = deptFilter === 'All' || e.dept === deptFilter;
      const q = empSearch.toLowerCase();
      const matchSearch = !q || e.name.toLowerCase().includes(q) || e.email.toLowerCase().includes(q);
      return matchDept && matchSearch;
    });
  }, [roiData, deptFilter, empSearch]);

  // Aggregate stats
  const { avgROI, best, worst } = useMemo(() => {
    const withData = filtered.filter(e => e.incentive > 0);
    if (withData.length === 0) return { avgROI: 0, best: null, worst: null };
    const avg = withData.reduce((s, e) => s + e.roi, 0) / withData.length;
    const sorted = [...withData].sort((a, b) => b.roi - a.roi);
    return { avgROI: avg, best: sorted[0], worst: sorted[sorted.length - 1] };
  }, [filtered]);

  // PDF export
  function handleExportPDF() {
    const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
    doc.setFontSize(16);
    doc.text('Performance & ROI Report', 14, 16);
    doc.setFontSize(10);
    doc.text(`Period: ${periodLabel}  |  Generated: ${new Date().toLocaleDateString()}`, 14, 23);

    autoTable(doc, {
      startY: 28,
      head: [['Employee', 'Department', 'Salary/Mo', 'Incentive', 'Net Profit (N)', 'Employee Cost', 'Net Return', 'ROI %']],
      body: filtered.map(e => [
        e.name, e.dept,
        `৳${fmt(e.salary)}`, `৳${fmt(e.incentive)}`,
        `৳${fmt(e.N)}`, `৳${fmt(e.EC)}`, `৳${fmt(e.NR)}`,
        `${(e.roi * 100).toFixed(1)}%`,
      ]),
      styles: { fontSize: 8 },
      headStyles: { fillColor: [6, 95, 70] },
    });

    doc.save(`ROI_Report_${periodLabel.replace(/\s/g, '_')}.pdf`);
  }

  const analyzed = analyzedId ? filtered.find(e => e.id === analyzedId) : null;

  if (loading) {
    return (
      <div className="flex justify-center items-center py-32">
        <Loader2 size={28} className="animate-spin" style={{ color: BRAND }} />
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* ── Header ─────────────────────────────────────────────────────────── */}
      <div className="page-header">
        <div>
          <h2 className="page-title">Performance & ROI</h2>
          <p className="page-sub">{periodLabel} · {filtered.length} employees</p>
        </div>
        <button onClick={handleExportPDF} className="btn-primary">
          <Download size={15} /> Export PDF
        </button>
      </div>

      {/* ── Hero Card ──────────────────────────────────────────────────────── */}
      <div
        className="rounded-2xl p-6 text-white relative overflow-hidden"
        style={{ background: 'linear-gradient(135deg, #18181B 0%, #3F3F46 100%)' }}
      >
        <div className="absolute inset-0 opacity-5"
          style={{ backgroundImage: 'radial-gradient(circle at 80% 20%, #22C55E 0%, transparent 60%)' }} />
        <div className="relative">
          <p className="text-white/60 text-xs font-semibold uppercase tracking-widest mb-1">Company Average ROI</p>
          <p className="text-5xl font-black mb-1" style={{ color: avgROI >= 0 ? GREEN : RED }}>
            {(avgROI * 100).toFixed(1)}%
          </p>
          <p className="text-white/50 text-sm">{periodLabel}</p>
          <div className="mt-4 flex flex-wrap gap-4 text-sm">
            <span className="text-white/60">Formula: <span className="text-white font-mono text-xs">ROI = (N − EC) / EC × 100</span></span>
            <span className="text-white/60">N = Incentive × (100/15) &nbsp;|&nbsp; EC = Salary × Months + Incentive</span>
          </div>
        </div>
      </div>

      {/* ── Stats Grid ─────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="card p-4 flex items-center gap-4">
          <div className="w-11 h-11 rounded-xl flex items-center justify-center shrink-0" style={{ background: '#DCFCE7' }}>
            <Award size={22} style={{ color: GREEN }} />
          </div>
          <div>
            <p className="text-xs text-gray-400 font-semibold">Best Performer</p>
            <p className="font-black text-gray-900 text-sm truncate">{best?.name || '—'}</p>
            {best && <p className="text-xs font-bold" style={{ color: GREEN }}>{(best.roi * 100).toFixed(1)}% ROI</p>}
          </div>
        </div>
        <div className="card p-4 flex items-center gap-4">
          <div className="w-11 h-11 rounded-xl flex items-center justify-center shrink-0" style={{ background: '#FEE2E2' }}>
            <AlertTriangle size={22} style={{ color: RED }} />
          </div>
          <div>
            <p className="text-xs text-gray-400 font-semibold">Needs Focus</p>
            <p className="font-black text-gray-900 text-sm truncate">{worst?.name || '—'}</p>
            {worst && <p className="text-xs font-bold" style={{ color: RED }}>{(worst.roi * 100).toFixed(1)}% ROI</p>}
          </div>
        </div>
        <div className="card p-4 flex items-center gap-4">
          <div className="w-11 h-11 rounded-xl flex items-center justify-center shrink-0" style={{ background: '#DBEAFE' }}>
            <Users size={22} style={{ color: BRAND2 }} />
          </div>
          <div>
            <p className="text-xs text-gray-400 font-semibold">Total Staff</p>
            <p className="font-black text-gray-900 text-2xl">{filtered.length}</p>
          </div>
        </div>
      </div>

      {/* ── Filters ────────────────────────────────────────────────────────── */}
      <div className="card p-4 space-y-3">
        <p className="text-xs font-black text-gray-500 uppercase tracking-widest">Filters</p>
        <div className="flex flex-wrap gap-3 items-end">
          {/* Dept filter */}
          <div>
            <label className="label">Department</label>
            <select className="input w-36" value={deptFilter} onChange={e => setDeptFilter(e.target.value)}>
              {DEPTS.map(d => <option key={d}>{d}</option>)}
            </select>
          </div>
          {/* Employee search */}
          <div className="flex-1 min-w-[180px]">
            <label className="label">Search Employee</label>
            <div className="relative">
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input className="input pl-9" placeholder="Name or email…" value={empSearch} onChange={e => setEmpSearch(e.target.value)} />
              {empSearch && <button onClick={() => setEmpSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={13} /></button>}
            </div>
          </div>
          {/* Period preset */}
          <div>
            <label className="label">Period</label>
            <select className="input w-36" value={preset} onChange={e => setPreset(e.target.value)}>
              {PRESETS.map(p => <option key={p}>{p}</option>)}
            </select>
          </div>
          {preset === 'Custom' && (
            <>
              <div>
                <label className="label">From</label>
                <input type="date" className="input" value={customFrom} onChange={e => setCustomFrom(e.target.value)} />
              </div>
              <div>
                <label className="label">To</label>
                <input type="date" className="input" value={customTo} onChange={e => setCustomTo(e.target.value)} />
              </div>
            </>
          )}
        </div>

        {/* Analyze specific employee */}
        <div className="flex items-end gap-3 pt-1 border-t border-gray-100">
          <div className="flex-1">
            <label className="label">Analyze Employee</label>
            <select
              className="input"
              value={analyzedId || ''}
              onChange={e => setAnalyzedId(e.target.value || null)}
            >
              <option value="">— Select employee —</option>
              {filtered.map(e => (
                <option key={e.id} value={e.id}>{e.name} ({e.dept})</option>
              ))}
            </select>
          </div>
          <button
            onClick={() => setAnalyzedId(null)}
            className="btn-secondary"
            disabled={!analyzedId}
          >
            <X size={14} /> Clear
          </button>
        </div>
      </div>

      {/* ── Analyzed Result Card ───────────────────────────────────────────── */}
      {analyzed && (
        <div className="card p-5 border-2" style={{ borderColor: roiColor(analyzed.roi) + '40' }}>
          <div className="flex items-start gap-4 flex-wrap">
            <div className="w-12 h-12 rounded-xl flex items-center justify-center text-white font-black text-lg shrink-0"
              style={{ background: roiColor(analyzed.roi) }}>
              {analyzed.name.charAt(0).toUpperCase()}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <p className="font-black text-gray-900 text-lg">{analyzed.name}</p>
                <span className="px-2 py-0.5 rounded-full text-xs font-bold capitalize"
                  style={{ background: BRAND + '15', color: BRAND }}>{analyzed.dept}</span>
              </div>
              <p className="text-sm text-gray-400 mt-0.5">{analyzed.email}</p>
            </div>
            <div className="text-right">
              <p className="text-3xl font-black" style={{ color: roiColor(analyzed.roi) }}>
                {(analyzed.roi * 100).toFixed(1)}%
              </p>
              <p className="text-xs text-gray-400">NET ROI</p>
            </div>
          </div>

          {/* Breakdown */}
          <div className="mt-4 p-4 rounded-xl bg-gray-50 space-y-2 text-sm">
            <p className="font-bold text-gray-700 text-xs uppercase tracking-wide mb-2">Calculation Breakdown</p>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
              {[
                { label: 'Incentive (F)', value: `৳${fmt(analyzed.incentive)}`, color: BRAND2 },
                { label: 'Net Profit (N = F×100/15)', value: `৳${fmt(analyzed.N)}`, color: GREEN },
                { label: 'Employee Cost (EC)', value: `৳${fmt(analyzed.EC)}`, color: AMBER },
                { label: 'Net Return (NR = N−EC)', value: `৳${fmt(analyzed.NR)}`, color: analyzed.NR >= 0 ? GREEN : RED },
              ].map(m => (
                <div key={m.label} className="bg-white rounded-lg p-3 border border-gray-100">
                  <p className="text-[10px] text-gray-400 font-semibold mb-1">{m.label}</p>
                  <p className="font-black text-sm" style={{ color: m.color }}>{m.value}</p>
                </div>
              ))}
            </div>
          </div>

          {/* Insight */}
          <div className="mt-3 p-3 rounded-xl text-sm"
            style={{ background: analyzed.NR >= 0 ? '#DCFCE7' : '#FEE2E2' }}>
            <p className="font-semibold" style={{ color: analyzed.NR >= 0 ? GREEN : RED }}>
              {analyzed.NR >= 0
                ? `✅ Positive return of ৳${fmt(analyzed.NR)} — this employee is generating value above their cost.`
                : `⚠️ Negative return of ৳${fmt(Math.abs(analyzed.NR))} — employee cost exceeds generated profit.`}
            </p>
          </div>
        </div>
      )}

      {/* ── Employee ROI Tiles ─────────────────────────────────────────────── */}
      <div className="space-y-2">
        <p className="text-xs font-black text-gray-500 uppercase tracking-widest">All Employees</p>
        {filtered.length === 0 ? (
          <div className="card p-12 text-center">
            <BarChart2 size={36} className="mx-auto mb-3 text-gray-200" />
            <p className="text-gray-400 font-semibold">No employees match the current filters</p>
          </div>
        ) : filtered.map(emp => (
          <EmployeeROITile
            key={emp.id}
            emp={emp}
            expanded={!!expanded[emp.id]}
            onToggle={() => setExpanded(p => ({ ...p, [emp.id]: !p[emp.id] }))}
            onAnalyze={() => setAnalyzedId(emp.id)}
          />
        ))}
      </div>
    </div>
  );
}

function EmployeeROITile({ emp, expanded, onToggle, onAnalyze }) {
  const color = roiColor(emp.roi);
  const roiPct = emp.roi * 100;
  const barWidth = Math.min(100, Math.max(0, roiPct + 50)); // map -50%..+100% → 0..100%

  return (
    <div className="card overflow-hidden">
      <div className="flex items-center gap-3 p-4 cursor-pointer" onClick={onToggle}>
        {/* Avatar */}
        <div className="w-10 h-10 rounded-xl flex items-center justify-center text-white font-black shrink-0"
          style={{ background: color }}>
          {emp.name.charAt(0).toUpperCase()}
        </div>

        {/* Name + dept */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <p className="font-bold text-gray-900 text-sm truncate">{emp.name}</p>
            <span className="px-1.5 py-0.5 rounded-full text-[10px] font-bold capitalize"
              style={{ background: BRAND + '15', color: BRAND }}>{emp.dept || '—'}</span>
          </div>
          {/* Progress bar */}
          <div className="mt-1.5 w-full bg-gray-100 rounded-full h-1.5">
            <div className="h-1.5 rounded-full transition-all duration-500"
              style={{ width: `${barWidth}%`, background: color }} />
          </div>
        </div>

        {/* ROI % */}
        <div className="text-right shrink-0">
          <p className="font-black text-base" style={{ color }}>{roiPct.toFixed(1)}%</p>
          <p className="text-[10px] text-gray-400">ROI</p>
        </div>

        {/* Expand icon */}
        <div className="shrink-0 text-gray-400">
          {expanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
        </div>
      </div>

      {/* Expanded detail */}
      {expanded && (
        <div className="border-t border-gray-100 p-4 bg-gray-50">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-sm mb-3">
            {[
              { label: 'Incentive', value: `৳${fmt(emp.incentive)}`, color: BRAND2 },
              { label: 'Salary/Mo', value: `৳${fmt(emp.salary)}`, color: '#374151' },
              { label: 'Net Return', value: `৳${fmt(emp.NR)}`, color: emp.NR >= 0 ? GREEN : RED },
              { label: 'Emp. Cost', value: `৳${fmt(emp.EC)}`, color: AMBER },
            ].map(m => (
              <div key={m.label} className="bg-white rounded-lg p-2.5 border border-gray-100">
                <p className="text-[10px] text-gray-400 font-semibold">{m.label}</p>
                <p className="font-black text-sm mt-0.5" style={{ color: m.color }}>{m.value}</p>
              </div>
            ))}
          </div>
          <button
            onClick={e => { e.stopPropagation(); onAnalyze(); }}
            className="text-xs font-bold px-3 py-1.5 rounded-lg transition"
            style={{ background: BRAND + '15', color: BRAND }}
          >
            <Target size={12} className="inline mr-1" />
            Analyze in detail
          </button>
        </div>
      )}
    </div>
  );
}
