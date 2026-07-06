import { useEffect, useState, useMemo } from 'react';
import {
  Loader2, TrendingUp, Search, X, Edit2, Plus, Users,
  Trash2, DollarSign, ChevronDown, ChevronUp,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, update, remove, orderBy } from '../lib/db';
import { formatCurrency, formatDate } from '../lib/utils';
import { Modal } from '../components/ui/Modal';
import { EmployeePicker, EmployeeAvatar } from '../components/ui/EmployeePicker';

// ── Salary breakdown components (like salary certificate) ─────────────────────
const BRAND = '#065F46';

function BreakdownRow({ label, value, isTotal, isDeduction }) {
  return (
    <div className={`flex justify-between items-center py-1.5 ${isTotal ? 'border-t border-gray-200 mt-1 pt-2.5' : ''}`}>
      <span className={`text-xs ${isTotal ? 'font-black text-gray-900' : 'text-gray-500'}`}>{label}</span>
      <span className={`text-xs font-bold ${isTotal ? 'text-[#065F46] text-sm' : isDeduction ? 'text-red-500' : 'text-gray-700'}`}>
        {isDeduction && value > 0 ? '−' : ''}{formatCurrency(value)}
      </span>
    </div>
  );
}

function SalaryBreakdownCard({ salary }) {
  const [open, setOpen] = useState(false);
  const basic    = salary.basicSalary || salary.basic || 0;
  const allow    = salary.allowances || 0;
  const deduct   = salary.deductions || 0;
  const gross    = salary.grossSalary || salary.salary || (basic + allow - deduct);

  // Build breakdown lines (mirrors salary certificate)
  const lines = [
    { label: 'Basic Salary',   value: basic,  deduction: false },
    allow  > 0 && { label: 'Allowances',    value: allow,  deduction: false },
    deduct > 0 && { label: 'Deductions',    value: deduct, deduction: true  },
  ].filter(Boolean);

  return (
    <div>
      <button
        onClick={() => setOpen(v => !v)}
        className="flex items-center gap-1 text-xs font-bold text-[#065F46] hover:underline"
      >
        {formatCurrency(gross)}
        {open ? <ChevronUp size={11} /> : <ChevronDown size={11} />}
      </button>
      {open && (
        <div className="mt-2 p-3 rounded-xl bg-[#F0FDF4] border border-[#065F46]/15 min-w-[180px] shadow-sm">
          {lines.map(l => (
            <BreakdownRow key={l.label} label={l.label} value={l.value} isDeduction={l.deduction} />
          ))}
          <BreakdownRow label="Gross Salary" value={gross} isTotal />
        </div>
      )}
    </div>
  );
}

export function SalaryPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [salaries,   setSalaries]   = useState([]);
  const [employees,  setEmployees]  = useState([]);
  const [loading,    setLoading]    = useState(true);
  const [search,     setSearch]     = useState('');
  const [deptFilter, setDeptFilter] = useState('');
  const [modal,      setModal]      = useState(null); // null | 'add' | salary-object

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'salaries'), (docs) => {
      setSalaries(docs);
      setLoading(false);
    });
    return unsub;
  }, [cid]);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'users'), (docs) => {
      setEmployees(
        docs
          .filter(e => (e.status || 'active') !== 'terminated')
          .map(e => ({ ...e, _displayName: e.fullName || e.name || e.email || '' }))
          .sort((a, b) => a._displayName.localeCompare(b._displayName))
      );
    });
    return unsub;
  }, [cid]);

  // Unique departments
  const departments = useMemo(() =>
    [...new Set(salaries.map(s => (s.department || '').trim()).filter(Boolean))].sort()
  , [salaries]);

  const filtered = salaries.filter(s => {
    const q = search.toLowerCase();
    const matchSearch = !q ||
      (s.employeeName || s.name || '').toLowerCase().includes(q) ||
      (s.department || '').toLowerCase().includes(q) ||
      (s.designation || '').toLowerCase().includes(q);
    const matchDept = !deptFilter || (s.department || '').trim() === deptFilter;
    return matchSearch && matchDept;
  });

  // Overall stats — always from full salaries list (not filtered)
  const totalPayroll  = salaries.reduce((sum, s) => sum + (s.grossSalary || s.salary || 0), 0);
  const avgPerHead    = salaries.length > 0 ? totalPayroll / salaries.length : 0;
  const totalBasic    = salaries.reduce((sum, s) => sum + (s.basicSalary || s.basic || 0), 0);
  const totalAllowAll = salaries.reduce((sum, s) => sum + (s.allowances || 0), 0);
  const totalDeductAll= salaries.reduce((sum, s) => sum + (s.deductions || 0), 0);

  // Filtered payroll (for table footer)
  const filteredPayroll = filtered.reduce((sum, s) => sum + (s.grossSalary || s.salary || 0), 0);

  // Dept breakdown for KPI strip
  const deptStats = useMemo(() => {
    const map = {};
    salaries.forEach(s => {
      const d = (s.department || 'Other').trim();
      if (!map[d]) map[d] = { count: 0, total: 0 };
      map[d].count++;
      map[d].total += s.grossSalary || s.salary || 0;
    });
    return Object.entries(map).sort((a, b) => b[1].total - a[1].total);
  }, [salaries]);

  async function handleDelete(id) {
    if (!confirm('Delete this salary record?')) return;
    await remove(cid, 'salaries', id);
  }

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h2 className="page-title">Salary Management</h2>
          <p className="page-sub">
            {salaries.length} salary record{salaries.length !== 1 ? 's' : ''} · {employees.length} total employees
          </p>
        </div>
        <button onClick={() => setModal('add')} className="btn-primary">
          <Plus size={16} /> Add Salary
        </button>
      </div>

      {/* ── KPI strip ─────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {/* Total Gross Payroll */}
        <div className="stat-card col-span-2 sm:col-span-1" style={{ background: 'linear-gradient(135deg,#065F46,#059669)', color: '#fff' }}>
          <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0" style={{ background: 'rgba(255,255,255,0.15)' }}>
            <DollarSign size={20} className="text-white" />
          </div>
          <div>
            <p className="text-white/70 text-xs font-semibold">Total Gross Payroll</p>
            <p className="text-white font-black text-lg leading-tight">{formatCurrency(totalPayroll)}</p>
            <p className="text-white/60 text-[10px] mt-0.5">Basic {formatCurrency(totalBasic)} + Allow {formatCurrency(totalAllowAll)} − Deduct {formatCurrency(totalDeductAll)}</p>
          </div>
        </div>

        {/* Total Employees on Salary */}
        <div className="stat-card">
          <div className="stat-icon bg-blue-50 text-blue-600"><Users size={20} /></div>
          <div>
            <p className="stat-label">Employees on Salary</p>
            <p className="stat-value">{salaries.length}</p>
            <p className="text-[10px] text-gray-400 mt-0.5">
              {employees.length - salaries.length > 0
                ? `${employees.length - salaries.length} without salary`
                : 'All covered'}
            </p>
          </div>
        </div>

        {/* Average Salary Per Head */}
        <div className="stat-card">
          <div className="stat-icon bg-amber-50 text-amber-600"><TrendingUp size={20} /></div>
          <div>
            <p className="stat-label">Avg. Salary / Head</p>
            <p className="stat-value text-sm">{formatCurrency(avgPerHead)}</p>
            <p className="text-[10px] text-gray-400 mt-0.5">Gross average</p>
          </div>
        </div>

        {/* Dept with highest payroll */}
        {deptStats.length > 0 && (
          <div className="stat-card">
            <div className="stat-icon bg-emerald-50 text-emerald-600"><TrendingUp size={20} /></div>
            <div>
              <p className="stat-label">Top Dept</p>
              <p className="stat-value text-sm capitalize">{deptStats[0][0]}</p>
              <p className="text-[10px] text-gray-400 mt-0.5">
                {deptStats[0][1].count} emp · {formatCurrency(deptStats[0][1].total)}
              </p>
            </div>
          </div>
        )}
      </div>

      {/* ── Dept breakdown bar ─────────────────────────────────────────────── */}
      {deptStats.length > 1 && (
        <div className="card p-4">
          <p className="text-xs font-black uppercase tracking-wider text-gray-500 mb-3">Payroll by Department</p>
          <div className="space-y-2">
            {deptStats.map(([dept, info]) => {
              const pct = totalPayroll > 0 ? (info.total / totalPayroll) * 100 : 0;
              return (
                <div key={dept} className="flex items-center gap-3">
                  <span className="text-xs font-semibold text-gray-600 capitalize w-24 shrink-0 truncate">{dept}</span>
                  <div className="flex-1 h-2 bg-gray-100 rounded-full overflow-hidden">
                    <div className="h-full rounded-full" style={{ width: `${pct}%`, background: 'linear-gradient(90deg,#065F46,#059669)' }} />
                  </div>
                  <span className="text-xs font-bold text-gray-700 w-28 text-right shrink-0">
                    {formatCurrency(info.total)}
                    <span className="text-gray-400 font-normal ml-1">({info.count})</span>
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* ── Dept filter chips ─────────────────────────────────────────────── */}
      {departments.length > 0 && (
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => setDeptFilter('')}
            className={`px-3 py-1 rounded-full text-xs font-bold transition ${
              !deptFilter ? 'bg-[#065F46] text-white' : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
            }`}
          >
            All ({salaries.length})
          </button>
          {departments.map(d => (
            <button
              key={d}
              onClick={() => setDeptFilter(d === deptFilter ? '' : d)}
              className={`px-3 py-1 rounded-full text-xs font-bold transition capitalize ${
                deptFilter === d ? 'bg-[#065F46] text-white' : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
              }`}
            >
              {d} ({salaries.filter(s => (s.department || '').trim() === d).length})
            </button>
          ))}
        </div>
      )}

      {/* ── Search ────────────────────────────────────────────────────────── */}
      <div className="relative max-w-sm">
        <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input className="input pl-9" placeholder="Search employee or department…" value={search} onChange={e => setSearch(e.target.value)} />
        {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={14} /></button>}
      </div>

      {/* ── Table ─────────────────────────────────────────────────────────── */}
      {loading ? (
        <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div>
      ) : (
        <div className="card">
          <div className="table-wrap border-0 rounded-none">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Employee</th>
                  <th>Department</th>
                  <th>Basic</th>
                  <th>Allowances</th>
                  <th>Deductions</th>
                  <th>Gross Salary</th>
                  <th>Effective</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="text-center py-12">
                      <div className="flex flex-col items-center gap-3 text-gray-400">
                        <DollarSign size={32} className="opacity-20" />
                        <p className="text-sm">No salary records{deptFilter ? ` for ${deptFilter}` : ''}</p>
                        <button onClick={() => setModal('add')} className="btn-primary btn-sm">
                          <Plus size={13} /> Add First Salary
                        </button>
                      </div>
                    </td>
                  </tr>
                ) : filtered.map(s => (
                  <tr key={s.id}>
                    <td>
                      <div className="flex items-center gap-2.5">
                        <EmployeeAvatar emp={s} size={8} />
                        <div>
                          <p className="font-semibold text-gray-900 text-sm">{s.employeeName || s.name || '—'}</p>
                          {s.designation && <p className="text-xs text-gray-400">{s.designation}</p>}
                        </div>
                      </div>
                    </td>
                    <td>
                      <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold capitalize"
                        style={{ background: BRAND + '15', color: BRAND }}>
                        {s.department || '—'}
                      </span>
                    </td>
                    <td className="text-gray-700 font-medium">{formatCurrency(s.basicSalary || s.basic)}</td>
                    <td className="text-emerald-600 font-medium">
                      {s.allowances > 0 ? `+${formatCurrency(s.allowances)}` : '—'}
                    </td>
                    <td className="text-red-500 font-medium">
                      {s.deductions > 0 ? `−${formatCurrency(s.deductions)}` : '—'}
                    </td>
                    <td>
                      {/* Expandable breakdown — click to see full breakdown */}
                      <SalaryBreakdownCard salary={s} />
                    </td>
                    <td className="text-gray-500 text-sm">{formatDate(s.effectiveDate || s.updatedAt)}</td>
                    <td>
                      <div className="flex items-center gap-1">
                        <button
                          onClick={() => setModal(s)}
                          className="btn-icon btn-sm"
                          title="Edit salary"
                        >
                          <Edit2 size={13} />
                        </button>
                        <button
                          onClick={() => handleDelete(s.id)}
                          className="btn-icon btn-sm text-red-400 hover:text-red-600 hover:bg-red-50"
                          title="Delete salary record"
                        >
                          <Trash2 size={13} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Table footer totals */}
          {filtered.length > 0 && (
            <div className="px-4 py-3 border-t border-gray-100 flex items-center justify-between bg-gray-50 rounded-b-xl">
              <span className="text-xs font-semibold text-gray-500">
                {filtered.length} record{filtered.length !== 1 ? 's' : ''}{deptFilter ? ` · ${deptFilter}` : ''}
                {filtered.length > 1 && (
                  <span className="ml-2 text-gray-400">
                    · avg {formatCurrency(filteredPayroll / filtered.length)}
                  </span>
                )}
              </span>
              <span className="text-sm font-black text-[#065F46]">
                Total: {formatCurrency(filteredPayroll)}
              </span>
            </div>
          )}
        </div>
      )}

      {modal && (
        <SalaryModal
          salary={modal === 'add' ? null : modal}
          cid={cid}
          employees={employees}
          onClose={() => setModal(null)}
        />
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SALARY MODAL — with full breakdown fields
// ─────────────────────────────────────────────────────────────────────────────
function SalaryModal({ salary, cid, employees, onClose }) {
  const isEdit = !!salary;

  const [selectedEmp, setSelectedEmp] = useState(
    isEdit ? { name: salary.employeeName || salary.name, department: salary.department } : null
  );
  const [form, setForm] = useState({
    employeeName:  salary?.employeeName  || salary?.name  || '',
    employeeId:    salary?.employeeId    || '',
    department:    salary?.department    || '',
    designation:   salary?.designation   || '',
    basicSalary:   String(salary?.basicSalary  || salary?.basic || ''),
    houseRent:     String(salary?.houseRent    || ''),
    medical:       String(salary?.medical      || ''),
    transport:     String(salary?.transport    || ''),
    otherAllow:    String(salary?.otherAllow   || ''),
    taxDeduction:  String(salary?.taxDeduction || ''),
    providentFund: String(salary?.providentFund|| ''),
    otherDeduct:   String(salary?.otherDeduct  || ''),
    effectiveDate: salary?.effectiveDate
      ? (typeof salary.effectiveDate === 'string' ? salary.effectiveDate : new Date(salary.effectiveDate?.seconds * 1000).toISOString().split('T')[0])
      : new Date().toISOString().split('T')[0],
  });
  const [saving, setSaving] = useState(false);
  const [error,  setError]  = useState('');

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  // Computed totals
  const basic    = parseFloat(form.basicSalary)   || 0;
  const houseR   = parseFloat(form.houseRent)     || 0;
  const medical  = parseFloat(form.medical)       || 0;
  const transport= parseFloat(form.transport)     || 0;
  const otherA   = parseFloat(form.otherAllow)    || 0;
  const taxD     = parseFloat(form.taxDeduction)  || 0;
  const pf       = parseFloat(form.providentFund) || 0;
  const otherD   = parseFloat(form.otherDeduct)   || 0;

  const totalAllowances = houseR + medical + transport + otherA;
  const totalDeductions = taxD + pf + otherD;
  const grossSalary     = basic + totalAllowances - totalDeductions;

  function handleEmpSelect(emp) {
    setSelectedEmp(emp);
    if (emp) {
      setForm(f => ({
        ...f,
        employeeName:  emp._displayName || emp.fullName || emp.name || '',
        employeeId:    emp.id || '',
        department:    emp.department || '',
        designation:   emp.designation || emp.role || '',
        basicSalary:   String(emp.salary || emp.basicSalary || ''),
        houseRent:     String(emp.houseRent     || ''),
        medical:       String(emp.medical       || ''),
        transport:     String(emp.transport     || ''),
        otherAllow:    String(emp.otherAllow    || ''),
        taxDeduction:  String(emp.taxDeduction  || ''),
        providentFund: String(emp.providentFund || ''),
        otherDeduct:   String(emp.otherDeduct   || ''),
      }));
    }
  }

  async function handleSave() {
    if (!form.employeeName.trim()) { setError('Please select an employee.'); return; }
    if (basic <= 0) { setError('Basic salary must be greater than zero.'); return; }
    setSaving(true); setError('');
    try {
      const data = {
        employeeName:  form.employeeName,
        employeeId:    form.employeeId,
        department:    form.department,
        designation:   form.designation,
        effectiveDate: form.effectiveDate,
        basicSalary:   basic,
        houseRent:     houseR,
        medical,
        transport,
        otherAllow:    otherA,
        taxDeduction:  taxD,
        providentFund: pf,
        otherDeduct:   otherD,
        allowances:    totalAllowances,
        deductions:    totalDeductions,
        grossSalary,
      };
      if (isEdit) {
        await update(cid, 'salaries', salary.id, { ...data, updatedAt: serverTimestamp() });
      } else {
        await add(col(cid, 'salaries'), { ...data, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
      }
      onClose();
    } catch (e) {
      setError(e.message || 'Failed to save.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal title={isEdit ? 'Edit Salary Record' : 'Add Salary Record'} onClose={onClose} wide>
      <div className="space-y-5">

        {/* Employee picker */}
        {!isEdit ? (
          <div className="rounded-xl border border-[#065F46]/20 bg-[#F0FDF4] p-4">
            <p className="text-xs font-black uppercase tracking-wider text-[#065F46]/70 mb-3 flex items-center gap-1.5">
              <Users size={13} /> Select Employee
            </p>
            <EmployeePicker employees={employees} value={selectedEmp} onChange={handleEmpSelect} required />
          </div>
        ) : (
          <div className="flex items-center gap-3 p-3 rounded-xl bg-gray-50 border border-gray-200">
            <EmployeeAvatar emp={{ name: form.employeeName }} size={9} />
            <div>
              <p className="font-bold text-gray-900 text-sm">{form.employeeName || '—'}</p>
              {form.designation && <p className="text-xs text-gray-400">{form.designation} · {form.department}</p>}
            </div>
          </div>
        )}

        {/* Gross summary — shown right after employee selection */}
        {(isEdit || selectedEmp) && (
          <div className="rounded-xl p-4" style={{ background: 'linear-gradient(135deg, #065F46 0%, #059669 100%)' }}>
            <p className="text-white/70 text-xs font-semibold mb-2">Salary Breakdown Summary</p>
            <div className="space-y-1.5">
              <div className="flex justify-between text-xs text-white/80">
                <span>Basic Salary</span><span>{formatCurrency(basic)}</span>
              </div>
              {totalAllowances > 0 && (
                <div className="flex justify-between text-xs text-emerald-200">
                  <span>+ Total Allowances</span><span>{formatCurrency(totalAllowances)}</span>
                </div>
              )}
              {totalDeductions > 0 && (
                <div className="flex justify-between text-xs text-red-300">
                  <span>− Total Deductions</span><span>{formatCurrency(totalDeductions)}</span>
                </div>
              )}
              <div className="border-t border-white/20 pt-2 flex justify-between">
                <span className="text-white font-black text-sm">Gross Salary</span>
                <span className="text-white font-black text-lg">{formatCurrency(grossSalary)}</span>
              </div>
            </div>
          </div>
        )}

        {/* Basic + Effective Date */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="label">Basic Salary (BDT) *</label>
            <input className="input" type="number" value={form.basicSalary} onChange={e => set('basicSalary', e.target.value)} placeholder="0.00" />
          </div>
          <div>
            <label className="label">Effective Date</label>
            <input className="input" type="date" value={form.effectiveDate} onChange={e => set('effectiveDate', e.target.value)} />
          </div>
        </div>

        {/* Allowances section */}
        <div>
          <p className="text-xs font-black uppercase tracking-wider text-emerald-700 mb-2 flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-500 inline-block" />
            Allowances
          </p>
          <div className="grid grid-cols-2 gap-3 p-3 rounded-xl bg-emerald-50 border border-emerald-100">
            {[
              { key: 'houseRent',  label: 'House Rent' },
              { key: 'medical',    label: 'Medical' },
              { key: 'transport',  label: 'Transport' },
              { key: 'otherAllow', label: 'Other Allowances' },
            ].map(f => (
              <div key={f.key}>
                <label className="label text-emerald-700">{f.label}</label>
                <input className="input" type="number" value={form[f.key]} onChange={e => set(f.key, e.target.value)} placeholder="0.00" />
              </div>
            ))}
            <div className="col-span-2 flex justify-between items-center pt-1 border-t border-emerald-200">
              <span className="text-xs font-bold text-emerald-700">Total Allowances</span>
              <span className="text-sm font-black text-emerald-700">{formatCurrency(totalAllowances)}</span>
            </div>
          </div>
        </div>

        {/* Deductions section */}
        <div>
          <p className="text-xs font-black uppercase tracking-wider text-red-600 mb-2 flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-red-500 inline-block" />
            Deductions
          </p>
          <div className="grid grid-cols-2 gap-3 p-3 rounded-xl bg-red-50 border border-red-100">
            {[
              { key: 'taxDeduction',  label: 'Tax' },
              { key: 'providentFund', label: 'Provident Fund' },
              { key: 'otherDeduct',   label: 'Other Deductions' },
            ].map(f => (
              <div key={f.key}>
                <label className="label text-red-600">{f.label}</label>
                <input className="input" type="number" value={form[f.key]} onChange={e => set(f.key, e.target.value)} placeholder="0.00" />
              </div>
            ))}
            <div className="col-span-2 flex justify-between items-center pt-1 border-t border-red-200">
              <span className="text-xs font-bold text-red-600">Total Deductions</span>
              <span className="text-sm font-black text-red-600">−{formatCurrency(totalDeductions)}</span>
            </div>
          </div>
        </div>

        {error && <p className="text-red-600 text-sm">{error}</p>}

        <div className="flex justify-end gap-3">
          <button onClick={onClose} className="btn-secondary">Cancel</button>
          <button onClick={handleSave} disabled={saving} className="btn-primary">
            {saving ? <Loader2 size={14} className="animate-spin" /> : null}
            {saving ? 'Saving…' : isEdit ? 'Save Changes' : 'Add Salary'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
