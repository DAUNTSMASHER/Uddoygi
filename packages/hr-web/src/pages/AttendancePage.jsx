// Attendance — mirrors Flutter attendance_screen.dart
// Subcollection path: data/{cid}/attendance/{yyyy-MM-dd}/records/{employeeId}
// Fields: employeeId, name (fullName), department, status, remarks, markedBy, timestamp
// Status values: 'present' / 'absent' / 'late' / 'leave'
// Auto-creates records from users collection (mirrors Flutter _createIfEmpty)
//
// Employee source: ALL users (same as EmployeesPage) — no department/role filter.
// Only terminated employees are excluded (status === 'terminated').

import { useEffect, useState, useCallback } from 'react';
import {
  Plus, Search, X, Loader2, Clock, ChevronLeft, ChevronRight,
  RefreshCw, UserCheck, CheckCircle2, XCircle, Timer, Umbrella,
} from 'lucide-react';
import { collection, onSnapshot, doc, setDoc, writeBatch, serverTimestamp, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { col, subscribe } from '../lib/db';
import { formatDate } from '../lib/utils';
import { EmployeePicker, EmployeeAvatar } from '../components/ui/EmployeePicker';

function todayStr() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
}

function addDays(dateStr, n) {
  const d = new Date(dateStr + 'T00:00:00');
  d.setDate(d.getDate() + n);
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
}


const STATUS_CONFIG = {
  present: { label: 'Present', color: '#16A34A', bg: '#DCFCE7', icon: CheckCircle2 },
  absent:  { label: 'Absent',  color: '#DC2626', bg: '#FEE2E2', icon: XCircle      },
  late:    { label: 'Late',    color: '#F97316', bg: '#FFEDD5', icon: Timer         },
  leave:   { label: 'Leave',   color: '#2563EB', bg: '#DBEAFE', icon: Umbrella      },
};

export function AttendancePage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [date,       setDate]      = useState(todayStr());
  const [records,    setRecords]   = useState([]);
  const [employees,  setEmployees] = useState([]);
  const [search,     setSearch]    = useState('');
  const [deptFilter, setDeptFilter] = useState('all');
  const [loading,    setLoading]   = useState(true);
  const [modal,      setModal]     = useState(null); // null | 'add' | record-object
  const [editRow,    setEditRow]   = useState(null); // record to quick-edit via row click
  const [creating,   setCreating]  = useState(false);

  // Subscribe to attendance/{date}/records
  useEffect(() => {
    if (!cid) return;
    setLoading(true);
    const ref = collection(db, 'data', cid, 'attendance', date, 'records');
    const unsub = onSnapshot(ref, (snap) => {
      setRecords(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
    return unsub;
  }, [cid, date]);

  // Load ALL employees — same source as EmployeesPage, no role/dept filter.
  // Only skip terminated employees (they no longer work here).
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

  // Mirrors Flutter _createIfEmpty — batch-creates absent records for all non-admin employees
  const createRecords = useCallback(async () => {
    if (!cid || employees.length === 0) return;
    setCreating(true);
    try {
      const batch = writeBatch(db);
      for (const emp of employees) {
        const empId = emp.employeeId || emp.id;
        const ref = doc(db, 'data', cid, 'attendance', date, 'records', empId);
        batch.set(ref, {
          employeeId: empId,
          email:      emp.email || emp.officeEmail || '',
          name:       emp.fullName || emp.name || '',
          department: emp.department || '',
          status:     'absent',
          remarks:    '',
          timestamp:  serverTimestamp(),
          markedBy:   session?.email || 'system',
        }, { merge: true });
      }
      await batch.commit();
    } catch (e) { alert(e.message); }
    finally { setCreating(false); }
  }, [cid, date, employees, session]);

  // Departments for filter chips (from loaded employees)
  const departments = ['all', ...Array.from(new Set(employees.map(e => e.department).filter(Boolean)))];

  const filtered = records.filter(r => {
    const q = search.toLowerCase();
    const matchSearch = !q
      || (r.name || r.employeeName || '').toLowerCase().includes(q)
      || (r.employeeId || '').toLowerCase().includes(q)
      || (r.department || '').toLowerCase().includes(q);
    const matchDept = deptFilter === 'all' || (r.department || '').toLowerCase() === deptFilter.toLowerCase();
    return matchSearch && matchDept;
  });

  const present = filtered.filter(r => r.status === 'present').length;
  const absent  = filtered.filter(r => r.status === 'absent').length;
  const late    = filtered.filter(r => r.status === 'late').length;
  const onLeave = filtered.filter(r => r.status === 'leave').length;
  const total   = filtered.length;
  const pct     = total > 0 ? Math.round((present / total) * 100) : 0;

  const isToday = date === todayStr();

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h2 className="page-title">Attendance</h2>
          <p className="page-sub">{filtered.length} records for {formatDate(date)}</p>
        </div>
        <div className="flex gap-2">
          <button onClick={createRecords} disabled={creating || employees.length === 0}
            className="btn-secondary" title="Auto-create absent records for all employees">
            {creating ? <Loader2 size={15} className="animate-spin" /> : <RefreshCw size={15} />}
            {creating ? 'Creating…' : `Auto-Fill (${employees.length})`}
          </button>
          <button onClick={() => setModal('add')} className="btn-primary">
            <Plus size={16} /> Mark Attendance
          </button>
        </div>
      </div>

      {/* Date navigator */}
      <div className="flex items-center gap-3 bg-white rounded-2xl border border-gray-100 p-3 w-fit">
        <button onClick={() => setDate(d => addDays(d, -1))} className="btn-icon">
          <ChevronLeft size={16} />
        </button>
        <input
          type="date"
          value={date}
          max={todayStr()}
          onChange={e => setDate(e.target.value)}
          className="input w-40 text-center text-sm font-semibold"
        />
        <button onClick={() => setDate(d => addDays(d, 1))} disabled={isToday} className="btn-icon disabled:opacity-40">
          <ChevronRight size={16} />
        </button>
        {!isToday && (
          <button onClick={() => setDate(todayStr())} className="btn-secondary btn-sm">Today</button>
        )}
      </div>

      {/* Hero attendance card */}
      {total > 0 && (
        <div className="rounded-2xl p-5 text-white" style={{ background: 'linear-gradient(135deg, #065F46, #059669)' }}>
          <div className="flex items-center justify-between mb-3">
            <div>
              <p className="text-white/70 text-sm">Attendance Rate</p>
              <p className="text-3xl font-black">{pct}%</p>
            </div>
            <div className="text-right">
              <p className="text-white/70 text-sm">Total Employees</p>
              <p className="text-2xl font-bold">{total}</p>
            </div>
          </div>
          <div className="w-full bg-white/20 rounded-full h-2 mb-3">
            <div className="bg-white rounded-full h-2 transition-all" style={{ width: `${pct}%` }} />
          </div>
          <div className="grid grid-cols-4 gap-3 text-center">
            {[
              { label: 'Present', value: present, color: 'text-emerald-200' },
              { label: 'Absent',  value: absent,  color: 'text-red-200' },
              { label: 'Late',    value: late,    color: 'text-amber-200' },
              { label: 'Leave',   value: onLeave, color: 'text-blue-200' },
            ].map(s => (
              <div key={s.label}>
                <p className={`text-xl font-bold ${s.color}`}>{s.value}</p>
                <p className="text-white/60 text-xs">{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Stat cards (when no records yet) */}
      {total === 0 && !loading && (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {[
            { label: 'Present', value: present, bg: 'bg-emerald-50', text: 'text-emerald-600' },
            { label: 'Absent',  value: absent,  bg: 'bg-red-50',     text: 'text-red-600' },
            { label: 'Late',    value: late,    bg: 'bg-amber-50',   text: 'text-amber-600' },
            { label: 'On Leave',value: onLeave, bg: 'bg-blue-50',    text: 'text-blue-600' },
          ].map(s => (
            <div key={s.label} className="stat-card">
              <div className={`stat-icon ${s.bg} ${s.text}`}><Clock size={18} /></div>
              <div><p className="stat-label">{s.label}</p><p className="stat-value">{s.value}</p></div>
            </div>
          ))}
        </div>
      )}

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[200px] max-w-sm">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input className="input pl-9" placeholder="Search by name, ID, department…"
            value={search} onChange={e => setSearch(e.target.value)} />
          {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={14} /></button>}
        </div>
        <div className="flex flex-wrap gap-1">
          {departments.map(d => (
            <button key={d} onClick={() => setDeptFilter(d)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold capitalize transition ${
                deptFilter === d ? 'bg-[#065F46] text-white' : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
              }`}>
              {d}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      {loading ? (
        <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div>
      ) : (
        <div className="card">
          <div className="table-wrap border-0 rounded-none">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Employee</th>
                  <th>ID</th>
                  <th>Department</th>
                  <th>Status</th>
                  <th>Remarks</th>
                  <th>Marked By</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-12 text-center">
                      <div className="flex flex-col items-center gap-3 text-gray-400">
                        <UserCheck size={32} className="opacity-30" />
                        <p className="text-sm">No attendance records for this date</p>
                        {employees.length > 0 && (
                          <button onClick={createRecords} disabled={creating} className="btn-secondary btn-sm">
                            {creating ? <Loader2 size={13} className="animate-spin" /> : <RefreshCw size={13} />}
                            Auto-fill from {employees.length} employees
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ) : filtered.map(r => (
                  <AttendanceRow
                    key={r.id}
                    record={r}
                    onClick={() => setEditRow(r)}
                  />
                ))}
              </tbody>
            </table>
          </div>
          {filtered.length > 0 && (
            <p className="text-xs text-gray-400 px-4 pb-3 pt-1">
              Click any row to update attendance
            </p>
          )}
        </div>
      )}

      {/* Add attendance modal */}
      {modal === 'add' && (
        <AddAttendanceModal
          date={date}
          cid={cid}
          employees={employees}
          markedBy={session?.displayName || session?.email || ''}
          onClose={() => setModal(null)}
        />
      )}

      {/* Row-click quick-edit dialog */}
      {editRow && (
        <EditAttendanceDialog
          record={editRow}
          date={date}
          cid={cid}
          isToday={isToday}
          markedBy={session?.displayName || session?.email || ''}
          onClose={() => setEditRow(null)}
        />
      )}
    </div>
  );
}

// ── Attendance row — entire row is clickable ──────────────────────────────────
function AttendanceRow({ record: r, onClick }) {
  const cfg = STATUS_CONFIG[r.status] || STATUS_CONFIG.absent;
  const Icon = cfg.icon;

  return (
    <tr
      onClick={onClick}
      className="cursor-pointer hover:bg-gray-50 transition-colors"
      title="Click to update attendance"
    >
      <td>
        <div className="flex items-center gap-2">
          <EmployeeAvatar emp={{ _displayName: r.name || r.employeeName }} size={7} />
          <span className="font-semibold text-gray-900">{r.name || r.employeeName || '—'}</span>
        </div>
      </td>
      <td className="text-gray-500">{r.employeeId || '—'}</td>
      <td className="capitalize text-gray-500">{r.department || '—'}</td>
      <td>
        <span
          className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold"
          style={{ background: cfg.bg, color: cfg.color }}
        >
          <Icon size={11} />
          {cfg.label}
        </span>
      </td>
      <td className="text-gray-500 max-w-[160px] truncate">{r.remarks || '—'}</td>
      <td className="text-gray-400 text-xs">{r.markedBy || '—'}</td>
    </tr>
  );
}

// ── Quick-edit dialog (mirrors Flutter _EditStatusSheet bottom sheet) ─────────
function EditAttendanceDialog({ record, date, cid, isToday, markedBy, onClose }) {
  const [status,  setStatus]  = useState(record.status || 'absent');
  const [remarks, setRemarks] = useState(record.remarks || '');
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState('');

  async function handleSave() {
    setSaving(true); setError('');
    try {
      const empId = record.id || record.employeeId;
      const ref = doc(db, 'data', cid, 'attendance', date, 'records', empId);
      await updateDoc(ref, {
        status,
        remarks: status === 'absent' ? remarks : '',
        markedBy,
        timestamp: serverTimestamp(),
      });
      onClose();
    } catch (e) { setError(e.message); }
    finally { setSaving(false); }
  }

  const cfg = STATUS_CONFIG[status] || STATUS_CONFIG.absent;

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden">

        {/* Colored header strip */}
        <div className="px-5 pt-5 pb-4" style={{ background: cfg.bg }}>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center" style={{ background: cfg.color + '22' }}>
              {(() => { const Icon = cfg.icon; return <Icon size={20} style={{ color: cfg.color }} />; })()}
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-black text-gray-900 text-sm">
                {record.name || record.employeeName || record.employeeId}
              </p>
              <p className="text-xs text-gray-500">
                {record.department ? record.department.toUpperCase() : ''}{record.employeeId ? ` · ${record.employeeId}` : ''}
              </p>
            </div>
            <button onClick={onClose} className="w-7 h-7 rounded-lg flex items-center justify-center text-gray-400 hover:bg-black/10 transition">
              <X size={14} />
            </button>
          </div>
        </div>

        <div className="p-5 space-y-4">
          <div>
            <p className="text-xs font-black uppercase tracking-wider text-gray-400 mb-2">Update Status</p>
            {/* 4 status chips with icons — mirrors Flutter _EditStatusSheet */}
            <div className="grid grid-cols-4 gap-2">
              {Object.entries(STATUS_CONFIG).map(([key, c]) => {
                const Icon = c.icon;
                const selected = status === key;
                return (
                  <button
                    key={key}
                    type="button"
                    onClick={() => setStatus(key)}
                    className="flex flex-col items-center gap-1.5 py-3 rounded-xl border-2 transition-all"
                    style={selected
                      ? { borderColor: c.color, background: c.color, color: '#fff' }
                      : { borderColor: c.color + '33', background: c.bg, color: c.color }
                    }
                  >
                    <Icon size={18} />
                    <span className="text-[9px] font-black uppercase tracking-wide">{c.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Remarks — only shown for absent, mirrors Flutter */}
          {status === 'absent' && (
            <div>
              <label className="text-xs font-black uppercase tracking-wider text-gray-400 mb-1.5 block">
                Reason (optional)
              </label>
              <textarea
                className="input resize-none"
                rows={2}
                value={remarks}
                onChange={e => setRemarks(e.target.value)}
                placeholder="Reason for absence…"
              />
            </div>
          )}

          {!isToday && (
            <p className="text-xs text-amber-600 font-semibold flex items-center gap-1.5">
              <Clock size={12} /> Editing a past date
            </p>
          )}

          {error && <p className="text-red-600 text-sm">{error}</p>}

          <button
            onClick={handleSave}
            disabled={saving}
            className="w-full py-3 rounded-xl text-sm font-black text-white flex items-center justify-center gap-2 transition disabled:opacity-50"
            style={{ background: cfg.color }}
          >
            {saving ? <Loader2 size={14} className="animate-spin" /> : null}
            {saving ? 'Saving…' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Add new attendance modal ──────────────────────────────────────────────────
function AddAttendanceModal({ date, cid, employees, markedBy, onClose }) {
  const [selectedEmp, setSelectedEmp] = useState(null);
  const [form, setForm] = useState({
    employeeId: '',
    name:       '',
    department: '',
    status:     'present',
    remarks:    '',
  });
  const [saving, setSaving] = useState(false);
  const [error,  setError]  = useState('');

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  function handleEmpSelect(emp) {
    setSelectedEmp(emp);
    if (emp) {
      setForm(f => ({
        ...f,
        employeeId: emp.employeeId || emp.id || '',
        name:       emp.fullName || emp.name || emp._displayName || '',
        department: emp.department || '',
      }));
    } else {
      setForm(f => ({ ...f, employeeId: '', name: '', department: '' }));
    }
  }

  async function handleSave() {
    if (!form.name.trim()) { setError('Select an employee first.'); return; }
    setSaving(true); setError('');
    try {
      const docId = form.employeeId || form.name.replace(/\s+/g, '_').toLowerCase();
      const ref = doc(db, 'data', cid, 'attendance', date, 'records', docId);
      await setDoc(ref, {
        ...form,
        remarks: form.status === 'absent' ? form.remarks : '',
        date,
        markedBy,
        timestamp:  serverTimestamp(),
        createdAt:  serverTimestamp(),
      }, { merge: true });
      onClose();
    } catch (e) { setError(e.message); }
    finally { setSaving(false); }
  }

  const cfg = STATUS_CONFIG[form.status] || STATUS_CONFIG.present;

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden">

        <div className="flex items-center justify-between px-5 pt-5 pb-4 border-b border-gray-100">
          <p className="font-black text-gray-900">Mark Attendance</p>
          <button onClick={onClose} className="w-7 h-7 rounded-lg flex items-center justify-center text-gray-400 hover:bg-gray-100 transition">
            <X size={14} />
          </button>
        </div>

        <div className="p-5 space-y-4">
          {/* Employee picker */}
          {employees.length > 0 && (
            <div>
              <p className="text-xs font-black uppercase tracking-wider text-gray-400 mb-2">Select Employee</p>
              <EmployeePicker employees={employees} value={selectedEmp} onChange={handleEmpSelect} />
            </div>
          )}

          {/* Manual fallback */}
          {employees.length === 0 && (
            <div>
              <label className="label">Employee Name</label>
              <input className="input" value={form.name} onChange={e => set('name', e.target.value)} placeholder="Full name" />
            </div>
          )}

          {/* Status chips */}
          <div>
            <p className="text-xs font-black uppercase tracking-wider text-gray-400 mb-2">Status</p>
            <div className="grid grid-cols-4 gap-2">
              {Object.entries(STATUS_CONFIG).map(([key, c]) => {
                const Icon = c.icon;
                const selected = form.status === key;
                return (
                  <button
                    key={key}
                    type="button"
                    onClick={() => set('status', key)}
                    className="flex flex-col items-center gap-1.5 py-3 rounded-xl border-2 transition-all"
                    style={selected
                      ? { borderColor: c.color, background: c.color, color: '#fff' }
                      : { borderColor: c.color + '33', background: c.bg, color: c.color }
                    }
                  >
                    <Icon size={18} />
                    <span className="text-[9px] font-black uppercase tracking-wide">{c.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Remarks only for absent */}
          {form.status === 'absent' && (
            <div>
              <label className="text-xs font-black uppercase tracking-wider text-gray-400 mb-1.5 block">Reason (optional)</label>
              <textarea className="input resize-none" rows={2} value={form.remarks}
                onChange={e => set('remarks', e.target.value)} placeholder="Reason for absence…" />
            </div>
          )}

          {error && <p className="text-red-600 text-sm">{error}</p>}

          <div className="flex gap-3">
            <button onClick={onClose} className="flex-1 py-2.5 rounded-xl border border-gray-200 text-sm font-semibold text-gray-600 hover:bg-gray-50 transition">
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={saving}
              className="flex-1 py-2.5 rounded-xl text-sm font-black text-white flex items-center justify-center gap-2 transition disabled:opacity-50"
              style={{ background: cfg.color }}
            >
              {saving ? <Loader2 size={14} className="animate-spin" /> : null}
              {saving ? 'Saving…' : 'Save'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
