import { useEffect, useState, useMemo } from 'react';
import { Search, Plus, X, Loader2, User, Phone, Edit2, Users, UserCheck, UserX, TrendingUp } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, update, remove, orderBy } from '../lib/db';
import { formatDate, initials, statusBadge } from '../lib/utils';
import { Modal } from '../components/ui/Modal';

// Department colour palette — mirrors Flutter admin screen
const DEPT_COLORS = [
  '#065F46', '#2563EB', '#EA580C', '#7C3AED',
  '#0369A1', '#16A34A', '#DC2626', '#D97706',
  '#0891B2', '#9333EA',
];

export function EmployeesPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [employees, setEmployees] = useState([]);
  const [search,    setSearch]    = useState('');
  const [deptFilter, setDeptFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [loading,   setLoading]   = useState(true);
  const [modal,     setModal]     = useState(null);

  useEffect(() => {
    if (!cid) return;
    // No orderBy — many employees only have 'fullName', not 'name',
    // so orderBy('name') silently excludes them. Sort client-side instead.
    // Flutter AllEmployeesPage shows ALL users including admin — no dept filter.
    const unsub = subscribe(col(cid, 'users'), (docs) => {
      const mapped = docs
        .map(d => ({ ...d, _displayName: d.fullName || d.name || d.email || '—' }))
        .sort((a, b) => a._displayName.localeCompare(b._displayName));
      setEmployees(mapped);
      setLoading(false);
    });
    return unsub;
  }, [cid]);

  // ── Derived stats ──────────────────────────────────────────────────────────
  const activeCount     = employees.filter(e => (e.status || 'active') === 'active').length;
  const inactiveCount   = employees.filter(e => e.status === 'inactive').length;
  const terminatedCount = employees.filter(e => e.status === 'terminated').length;

  // This-month new hires
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const newThisMonth = employees.filter(e => {
    const ts = e.createdAt;
    if (!ts) return false;
    const dt = ts?.toDate ? ts.toDate() : new Date(ts.seconds * 1000);
    return dt >= monthStart;
  }).length;

  // Department breakdown
  const deptBreakdown = useMemo(() => {
    const map = {};
    employees.forEach(e => {
      const d = (e.department || 'Other').trim();
      map[d] = (map[d] || 0) + 1;
    });
    return Object.entries(map)
      .sort((a, b) => b[1] - a[1])
      .map(([dept, count], i) => ({
        dept,
        count,
        pct: employees.length > 0 ? Math.round(count / employees.length * 100) : 0,
        color: DEPT_COLORS[i % DEPT_COLORS.length],
      }));
  }, [employees]);

  // Unique departments for filter
  const departments = deptBreakdown.map(d => d.dept);

  const filtered = employees.filter((e) => {
    const q = search.toLowerCase();
    const matchSearch = !q ||
      (e._displayName || '').toLowerCase().includes(q) ||
      (e.email || '').toLowerCase().includes(q) ||
      (e.department || '').toLowerCase().includes(q) ||
      (e.designation || e.jobTitle || '').toLowerCase().includes(q) ||
      (e.employeeId || '').toLowerCase().includes(q);
    const matchDept   = !deptFilter   || (e.department || '').trim() === deptFilter;
    const matchStatus = !statusFilter || (e.status || 'active') === statusFilter;
    return matchSearch && matchDept && matchStatus;
  });

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h2 className="page-title">Employee Directory</h2>
          <p className="page-sub">{employees.length} total · {activeCount} active · {newThisMonth > 0 ? `+${newThisMonth} this month` : ''}</p>
        </div>
        <button onClick={() => setModal('add')} className="btn-primary">
          <Plus size={16} /> Add Employee
        </button>
      </div>

      {/* ── KPI strip ─────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="stat-card">
          <div className="stat-icon bg-[#065F46]/10 text-[#065F46]"><Users size={20} /></div>
          <div>
            <p className="stat-label">Total Employees</p>
            <p className="stat-value">{employees.length}</p>
            {newThisMonth > 0 && <p className="text-xs text-[#065F46] font-semibold mt-0.5">+{newThisMonth} this month</p>}
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-green-50 text-green-600"><UserCheck size={20} /></div>
          <div><p className="stat-label">Active</p><p className="stat-value">{activeCount}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-yellow-50 text-yellow-600"><User size={20} /></div>
          <div><p className="stat-label">Inactive</p><p className="stat-value">{inactiveCount}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-red-50 text-red-500"><UserX size={20} /></div>
          <div><p className="stat-label">Terminated</p><p className="stat-value">{terminatedCount}</p></div>
        </div>
      </div>

      {/* ── Department breakdown (mirrors Flutter admin screen) ────────────── */}
      {deptBreakdown.length > 0 && (
        <div className="card p-4">
          <div className="flex items-center gap-2 mb-3">
            <TrendingUp size={15} className="text-[#065F46]" />
            <p className="font-black text-sm text-gray-700">Department Breakdown</p>
          </div>

          {/* Stacked bar */}
          <div className="flex h-3 rounded-full overflow-hidden mb-3 gap-px">
            {deptBreakdown.map(d => (
              <div
                key={d.dept}
                style={{ width: `${d.pct}%`, background: d.color, minWidth: d.pct > 0 ? 4 : 0 }}
                title={`${d.dept}: ${d.count} (${d.pct}%)`}
              />
            ))}
          </div>

          {/* Legend chips */}
          <div className="flex flex-wrap gap-2">
            {deptBreakdown.map(d => (
              <button
                key={d.dept}
                onClick={() => setDeptFilter(deptFilter === d.dept ? '' : d.dept)}
                className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold transition border ${
                  deptFilter === d.dept
                    ? 'text-white border-transparent shadow-sm'
                    : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50'
                }`}
                style={deptFilter === d.dept ? { background: d.color, borderColor: d.color } : {}}
              >
                <span
                  className="w-2 h-2 rounded-full shrink-0"
                  style={{ background: deptFilter === d.dept ? 'rgba(255,255,255,0.7)' : d.color }}
                />
                <span className="capitalize">{d.dept}</span>
                <span className={`font-black ${deptFilter === d.dept ? 'text-white/80' : 'text-gray-400'}`}>
                  {d.count}
                </span>
              </button>
            ))}
            {deptFilter && (
              <button
                onClick={() => setDeptFilter('')}
                className="flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-gray-100 text-gray-500 hover:bg-gray-200 transition"
              >
                <X size={10} /> Clear
              </button>
            )}
          </div>
        </div>
      )}

      {/* ── Filters row ───────────────────────────────────────────────────── */}
      <div className="flex flex-wrap items-center gap-3">
        {/* Search */}
        <div className="relative flex-1 min-w-[200px] max-w-sm">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            className="input pl-9"
            placeholder="Search by name, email, department…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
              <X size={14} />
            </button>
          )}
        </div>

        {/* Status filter */}
        <div className="flex gap-1.5">
          {['', 'active', 'inactive', 'terminated'].map(s => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                statusFilter === s
                  ? 'bg-[#065F46] text-white'
                  : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
              }`}
            >
              {s === '' ? 'All' : s.charAt(0).toUpperCase() + s.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div>
      ) : filtered.length === 0 ? (
        <div className="empty-state card-p">
          <div className="empty-state-icon"><User size={24} /></div>
          <p className="font-semibold text-gray-700">No employees found</p>
          <p className="text-sm text-gray-400 mt-1">{search ? 'Try a different search term' : 'Add your first employee to get started'}</p>
        </div>
      ) : (
        <div className="card">
          <div className="table-wrap border-0 rounded-none">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Employee</th>
                  <th>Dept / Designation</th>
                  <th>Contact</th>
                  <th>Joined</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((emp) => {
                  const deptInfo = deptBreakdown.find(d => d.dept === (emp.department || '').trim());
                  return (
                    <tr key={emp.id}>
                      <td>
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-full bg-brand-100 text-[#065F46] flex items-center justify-center text-xs font-bold shrink-0 overflow-hidden ring-2 ring-[#065F46]/10">
                            {emp.profileImage || emp.photoUrl || emp.profilePhotoUrl ? (
                              <img src={emp.profileImage || emp.photoUrl || emp.profilePhotoUrl} alt="" className="w-full h-full object-cover" />
                            ) : (
                              initials(emp._displayName || '?')
                            )}
                          </div>
                          <div>
                            <p className="font-semibold text-gray-900 text-sm">{emp._displayName}</p>
                            <p className="text-xs text-gray-400">{emp.email || emp.officeEmail}</p>
                            {emp.employeeId && <p className="text-[10px] text-gray-300 font-mono">{emp.employeeId}</p>}
                          </div>
                        </div>
                      </td>
                      <td>
                        <div className="flex flex-col gap-0.5">
                          {emp.department && (
                            <span
                              className="inline-flex items-center gap-1 text-xs font-semibold px-2 py-0.5 rounded-full w-fit capitalize"
                              style={{
                                background: (deptInfo?.color || '#065F46') + '18',
                                color: deptInfo?.color || '#065F46',
                              }}
                            >
                              {emp.department}
                            </span>
                          )}
                          <span className="text-xs text-gray-500">{emp.designation || emp.jobTitle || emp.role || '—'}</span>
                        </div>
                      </td>
                      <td>
                        {emp.phone && (
                          <span className="text-xs text-gray-500 flex items-center gap-1">
                            <Phone size={11} />{emp.phone}
                          </span>
                        )}
                      </td>
                      <td className="text-gray-500 text-sm">{formatDate(emp.joiningDate || emp.createdAt)}</td>
                      <td><span className={statusBadge(emp.status || 'active')}>{emp.status || 'active'}</span></td>
                      <td>
                        <button onClick={() => setModal(emp)} className="btn-icon btn-sm" title="Edit">
                          <Edit2 size={13} />
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {modal && (
        <EmployeeModal
          employee={modal === 'add' ? null : modal}
          cid={cid}
          onClose={() => setModal(null)}
        />
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPLOYEE MODAL
// ─────────────────────────────────────────────────────────────────────────────
function EmployeeModal({ employee, cid, onClose }) {
  const isEdit = !!employee;
  // Support both 'fullName' (Flutter admin) and 'name' (web-added) fields
  const displayName = employee?.fullName || employee?.name || '';
  const [form, setForm] = useState({
    fullName:    displayName,
    name:        displayName,
    email:       employee?.email       || employee?.officeEmail || '',
    phone:       employee?.phone       || employee?.workPhone   || '',
    department:  employee?.department  || '',
    designation: employee?.designation || employee?.jobTitle    || '',
    salary:      employee?.salary      || employee?.baseSalary  || '',
    status:      employee?.status      || 'active',
  });
  const [saving, setSaving] = useState(false);
  const [error,  setError]  = useState('');

  const set = (k, v) => setForm((f) => {
    const next = { ...f, [k]: v };
    // Keep fullName and name in sync
    if (k === 'fullName') next.name = v;
    if (k === 'name') next.fullName = v;
    return next;
  });

  async function handleSave() {
    if (!form.fullName || !form.email) { setError('Name and email are required.'); return; }
    setSaving(true);
    setError('');
    try {
      if (isEdit) {
        await update(cid, 'users', employee.id, form);
      } else {
        await add(col(cid, 'users'), { ...form, role: 'employee' });
      }
      onClose();
    } catch (e) {
      setError(e.message || 'Failed to save. Please try again.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal title={isEdit ? 'Edit Employee' : 'Add Employee'} onClose={onClose}>
      <div className="grid grid-cols-2 gap-4">
        <div className="col-span-2">
          <label className="label">Full Name *</label>
          <input className="input" value={form.fullName} onChange={(e) => set('fullName', e.target.value)} placeholder="John Doe" />
        </div>
        <div className="col-span-2">
          <label className="label">Email *</label>
          <input className="input" type="email" value={form.email} onChange={(e) => set('email', e.target.value)} placeholder="john@company.com" />
          {isEdit && employee?.authEmail && (
            <p className="text-[10px] text-gray-400 mt-1">Auth email: {employee.authEmail}</p>
          )}
        </div>
        <div>
          <label className="label">Phone</label>
          <input className="input" value={form.phone} onChange={(e) => set('phone', e.target.value)} placeholder="+880..." />
        </div>
        <div>
          <label className="label">Department</label>
          <input className="input" value={form.department} onChange={(e) => set('department', e.target.value)} placeholder="HR, Factory, Marketing…" />
        </div>
        <div>
          <label className="label">Designation</label>
          <input className="input" value={form.designation} onChange={(e) => set('designation', e.target.value)} placeholder="Manager, Executive…" />
        </div>
        <div>
          <label className="label">Salary (BDT)</label>
          <input className="input" type="number" value={form.salary} onChange={(e) => set('salary', e.target.value)} placeholder="0" />
        </div>
        <div className="col-span-2">
          <label className="label">Status</label>
          <select className="input" value={form.status} onChange={(e) => set('status', e.target.value)}>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
            <option value="terminated">Terminated</option>
          </select>
        </div>
      </div>
      {error && <p className="text-red-600 text-sm mt-3">{error}</p>}
      <div className="flex justify-end gap-3 mt-5">
        <button onClick={onClose} className="btn-secondary">Cancel</button>
        <button onClick={handleSave} disabled={saving} className="btn-primary">
          {saving ? <Loader2 size={14} className="animate-spin" /> : null}
          {saving ? 'Saving…' : isEdit ? 'Save Changes' : 'Add Employee'}
        </button>
      </div>
    </Modal>
  );
}
