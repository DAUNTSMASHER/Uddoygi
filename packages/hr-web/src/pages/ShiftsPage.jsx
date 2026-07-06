// Shift Tracker — mirrors Flutter shift_tracker_screen.dart
// Collection: data/{cid}/shifts
// Fields: employeeName, shift (Morning/Evening/Night), date (yyyy-MM-dd)
// Flutter only stores: employeeName, shift, date — no startTime/endTime

import { useEffect, useState } from 'react';
import { Plus, Loader2, Edit2, X, Users, BarChart3, Search, Calendar } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, update, remove, orderBy } from '../lib/db';
import { formatDate, statusBadge } from '../lib/utils';
import { Modal } from '../components/ui/Modal';
import { EmployeePicker, EmployeeAvatar } from '../components/ui/EmployeePicker';

const SHIFTS = ['Morning', 'Evening', 'Night'];

const SHIFT_COLORS = {
  Morning: 'bg-amber-50 text-amber-700 border border-amber-200',
  Evening: 'bg-indigo-50 text-indigo-700 border border-indigo-200',
  Night:   'bg-slate-100 text-slate-700 border border-slate-300',
};

export function ShiftsPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [shifts,    setShifts]    = useState([]);
  const [employees, setEmployees] = useState([]);
  const [loading,   setLoading]   = useState(true);
  const [modal,     setModal]     = useState(null);
  const [search,    setSearch]    = useState('');
  const [dateFilter, setDateFilter] = useState('');

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'shifts'), (docs) => {
      setShifts(docs);
      setLoading(false);
    }, [orderBy('date', 'desc')]);
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

  const filtered = shifts.filter(s => {
    const q = search.toLowerCase();
    const matchSearch = !q || (s.employeeName || '').toLowerCase().includes(q);
    const matchDate = !dateFilter || (s.date || '').startsWith(dateFilter);
    return matchSearch && matchDate;
  });

  // Shift distribution counts
  const counts = SHIFTS.reduce((acc, sh) => {
    acc[sh] = shifts.filter(s => (s.shift || '').toLowerCase() === sh.toLowerCase()).length;
    return acc;
  }, {});

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h2 className="page-title">Shift Tracker</h2>
          <p className="page-sub">{shifts.length} shift records · {employees.length} employees</p>
        </div>
        <button onClick={() => setModal('add')} className="btn-primary"><Plus size={16} /> Add Shift</button>
      </div>

      {/* Shift distribution cards */}
      <div className="grid grid-cols-3 gap-4">
        {SHIFTS.map(sh => (
          <div key={sh} className="stat-card">
            <div className={`stat-icon ${SHIFT_COLORS[sh].split(' ').slice(0,2).join(' ')}`}><BarChart3 size={18} /></div>
            <div><p className="stat-label">{sh}</p><p className="stat-value text-xl">{counts[sh] || 0}</p></div>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[200px] max-w-sm">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input className="input pl-9" placeholder="Search employee…" value={search} onChange={e => setSearch(e.target.value)} />
          {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={14} /></button>}
        </div>
        <div className="flex items-center gap-2">
          <Calendar size={15} className="text-gray-400" />
          <input className="input w-36" type="month" value={dateFilter}
            onChange={e => setDateFilter(e.target.value)}
            title="Filter by month" />
          {dateFilter && <button onClick={() => setDateFilter('')} className="text-gray-400 hover:text-gray-600"><X size={14} /></button>}
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div>
      ) : (
        <div className="card">
          <div className="table-wrap border-0 rounded-none">
            <table className="data-table">
              <thead>
                <tr><th>Employee</th><th>Shift</th><th>Date</th><th></th></tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr><td colSpan={4} className="text-center py-10 text-gray-400">No shift records</td></tr>
                ) : filtered.map(s => (
                  <tr key={s.id}>
                    <td>
                      <div className="flex items-center gap-2">
                        <EmployeeAvatar emp={{ _displayName: s.employeeName }} size={7} />
                        <span className="font-semibold text-gray-900">{s.employeeName || '—'}</span>
                      </div>
                    </td>
                    <td>
                      <span className={`badge text-xs font-semibold px-2.5 py-1 rounded-full ${SHIFT_COLORS[s.shift] || 'bg-gray-100 text-gray-600'}`}>
                        {s.shift || '—'}
                      </span>
                    </td>
                    <td className="text-gray-500">{s.date || '—'}</td>
                    <td>
                      <div className="flex gap-1">
                        <button onClick={() => setModal(s)} className="btn-icon btn-sm"><Edit2 size={13} /></button>
                        <button onClick={() => remove(cid, 'shifts', s.id)} className="btn-icon btn-sm text-red-400 hover:text-red-600"><X size={13} /></button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {modal && (
        <ShiftModal
          shift={modal === 'add' ? null : modal}
          cid={cid}
          employees={employees}
          onClose={() => setModal(null)}
        />
      )}
    </div>
  );
}

function ShiftModal({ shift, cid, employees, onClose }) {
  const isEdit = !!shift;
  const today  = new Date().toISOString().split('T')[0];

  const [selectedEmp, setSelectedEmp] = useState(
    isEdit ? { _displayName: shift.employeeName, name: shift.employeeName } : null
  );
  const [form, setForm] = useState({
    employeeName: shift?.employeeName || '',
    employeeId:   shift?.employeeId   || '',
    department:   shift?.department   || '',
    shift:        shift?.shift        || 'Morning',
    date:         shift?.date         || today,
  });
  const [saving, setSaving] = useState(false);
  const [error,  setError]  = useState('');

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  function handleEmpSelect(emp) {
    setSelectedEmp(emp);
    if (emp) {
      setForm(f => ({
        ...f,
        employeeName: emp._displayName || emp.fullName || emp.name || '',
        employeeId:   emp.id || '',
        department:   emp.department || '',
      }));
    } else {
      setForm(f => ({ ...f, employeeName: '', employeeId: '', department: '' }));
    }
  }

  async function handleSave() {
    if (!form.employeeName.trim()) { setError('Please select an employee.'); return; }
    if (!form.date) { setError('Date is required.'); return; }
    setSaving(true); setError('');
    try {
      if (isEdit) await update(cid, 'shifts', shift.id, form);
      else        await add(col(cid, 'shifts'), form);
      onClose();
    } catch (e) { setError(e.message); }
    finally { setSaving(false); }
  }

  return (
    <Modal title={isEdit ? 'Edit Shift' : 'Add Shift'} onClose={onClose}>
      <div className="space-y-4">
        {!isEdit && (
          <div className="rounded-xl border border-[#065F46]/20 bg-[#F0FDF4] p-4">
            <p className="text-xs font-black uppercase tracking-wider text-[#065F46]/70 mb-3 flex items-center gap-1.5">
              <Users size={13} /> Select Employee
            </p>
            <EmployeePicker employees={employees} value={selectedEmp} onChange={handleEmpSelect} required />
          </div>
        )}
        {isEdit && (
          <div className="flex items-center gap-3 p-3 rounded-xl bg-gray-50 border border-gray-200">
            <EmployeeAvatar emp={{ _displayName: form.employeeName }} size={9} />
            <p className="font-bold text-gray-900 text-sm">{form.employeeName || '—'}</p>
          </div>
        )}

        <div>
          <label className="label">Shift</label>
          <div className="flex gap-2">
            {SHIFTS.map(sh => (
              <button key={sh} type="button"
                onClick={() => set('shift', sh)}
                className={`flex-1 py-2 rounded-xl text-sm font-semibold border transition ${
                  form.shift === sh
                    ? 'bg-[#065F46] text-white border-[#065F46]'
                    : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
                }`}>
                {sh}
              </button>
            ))}
          </div>
        </div>

        <div>
          <label className="label">Date</label>
          <input className="input" type="date" value={form.date} onChange={e => set('date', e.target.value)} />
        </div>

        {error && <p className="text-red-600 text-sm">{error}</p>}
        <div className="flex justify-end gap-3">
          <button onClick={onClose} className="btn-secondary">Cancel</button>
          <button onClick={handleSave} disabled={saving} className="btn-primary">
            {saving ? <Loader2 size={14} className="animate-spin" /> : null}
            {saving ? 'Saving…' : 'Save'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
