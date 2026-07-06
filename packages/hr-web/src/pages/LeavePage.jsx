// Leave Management — mirrors Flutter leave_management_screen.dart
// Collection: data/{cid}/leaves
// Fields: employeeName, reason, fromDate (yyyy-MM-dd), toDate (yyyy-MM-dd),
//         status (Pending/Approved/Rejected), appliedAt (yyyy-MM-dd)
// Status values match Flutter exactly: 'Pending', 'Approved', 'Rejected'

import { useEffect, useState, useMemo } from 'react';
import { Plus, Search, X, Loader2, Calendar, CheckCircle, XCircle, Users } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, update, remove, orderBy } from '../lib/db';
import { formatDate, statusBadge } from '../lib/utils';
import { Modal } from '../components/ui/Modal';
import { EmployeePicker, EmployeeAvatar } from '../components/ui/EmployeePicker';

export function LeavePage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [leaves,    setLeaves]    = useState([]);
  const [employees, setEmployees] = useState([]);
  const [search,    setSearch]    = useState('');
  const [loading,   setLoading]   = useState(true);
  const [modal,     setModal]     = useState(null);
  const [filter,    setFilter]    = useState('all');

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'leaves'), (docs) => {
      setLeaves(docs);
      setLoading(false);
    }, [orderBy('appliedAt', 'desc')]);
    return unsub;
  }, [cid]);

  // Load employees for picker
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

  const filtered = leaves.filter((l) => {
    const q = search.toLowerCase();
    const matchSearch = !q || (l.employeeName || '').toLowerCase().includes(q);
    // Flutter uses 'Pending'/'Approved'/'Rejected' (capitalised)
    const status = (l.status || 'Pending').toLowerCase();
    const matchFilter = filter === 'all' || status === filter.toLowerCase();
    return matchSearch && matchFilter;
  });

  const pending  = leaves.filter(l => (l.status || 'Pending').toLowerCase() === 'pending').length;
  const approved = leaves.filter(l => (l.status || '').toLowerCase() === 'approved').length;
  const rejected = leaves.filter(l => (l.status || '').toLowerCase() === 'rejected').length;

  async function handleApprove(id) {
    await update(cid, 'leaves', id, { status: 'Approved' });
  }
  async function handleReject(id) {
    await update(cid, 'leaves', id, { status: 'Rejected' });
  }

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h2 className="page-title">Leave Management</h2>
          <p className="page-sub">{leaves.length} total · {employees.length} employees</p>
        </div>
        <button onClick={() => setModal('add')} className="btn-primary">
          <Plus size={16} /> Add Leave
        </button>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <div className="stat-card">
          <div className="stat-icon bg-yellow-50 text-yellow-600"><Calendar size={20} /></div>
          <div><p className="stat-label">Pending</p><p className="stat-value text-xl">{pending}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-green-50 text-green-600"><CheckCircle size={20} /></div>
          <div><p className="stat-label">Approved</p><p className="stat-value text-xl">{approved}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-red-50 text-red-600"><XCircle size={20} /></div>
          <div><p className="stat-label">Rejected</p><p className="stat-value text-xl">{rejected}</p></div>
        </div>
      </div>

      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative flex-1 max-w-sm">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input className="input pl-9" placeholder="Search employee…" value={search} onChange={(e) => setSearch(e.target.value)} />
          {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={14} /></button>}
        </div>
        <div className="flex gap-1">
          {['all', 'pending', 'approved', 'rejected'].map((f) => (
            <button key={f} onClick={() => setFilter(f)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold capitalize transition ${
                filter === f ? 'bg-[#065F46] text-white' : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
              }`}>
              {f}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div>
      ) : (
        <div className="card">
          <div className="table-wrap border-0 rounded-none">
            <table className="data-table">
              <thead>
                <tr><th>Employee</th><th>From</th><th>To</th><th>Reason</th><th>Applied</th><th>Status</th><th>Actions</th></tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr><td colSpan={7} className="text-center py-10 text-gray-400">No leave requests found</td></tr>
                ) : filtered.map((l) => (
                  <tr key={l.id}>
                    <td>
                      <div className="flex items-center gap-2">
                        <EmployeeAvatar emp={{ _displayName: l.employeeName }} size={7} />
                        <span className="font-semibold text-gray-900">{l.employeeName || '—'}</span>
                      </div>
                    </td>
                    <td>{l.fromDate || l.startDate || l.from || '—'}</td>
                    <td>{l.toDate || l.endDate || l.to || '—'}</td>
                    <td className="max-w-[160px] truncate text-gray-500">{l.reason || '—'}</td>
                    <td className="text-gray-400 text-xs">{l.appliedAt || formatDate(l.createdAt)}</td>
                    <td><span className={statusBadge(l.status)}>{l.status || 'Pending'}</span></td>
                    <td>
                      <div className="flex gap-1">
                        {(l.status || 'Pending').toLowerCase() === 'pending' && (
                          <>
                            <button onClick={() => handleApprove(l.id)} className="btn-sm btn bg-green-600 text-white hover:bg-green-700 px-2 py-1" title="Approve"><CheckCircle size={13} /></button>
                            <button onClick={() => handleReject(l.id)}  className="btn-sm btn bg-red-600 text-white hover:bg-red-700 px-2 py-1"   title="Reject"><XCircle size={13} /></button>
                          </>
                        )}
                        <button onClick={() => setModal(l)} className="btn-icon btn-sm" title="Edit"><Plus size={13} className="rotate-45" /></button>
                        <button onClick={() => remove(cid, 'leaves', l.id)} className="btn-icon btn-sm text-red-400 hover:text-red-600"><X size={13} /></button>
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
        <LeaveModal
          leave={modal === 'add' ? null : modal}
          cid={cid}
          employees={employees}
          onClose={() => setModal(null)}
        />
      )}
    </div>
  );
}

function LeaveModal({ leave, cid, employees, onClose }) {
  const isEdit = !!leave;
  const today  = new Date().toISOString().split('T')[0];

  const [selectedEmp, setSelectedEmp] = useState(
    isEdit ? { _displayName: leave.employeeName, name: leave.employeeName } : null
  );
  const [form, setForm] = useState({
    employeeName: leave?.employeeName || '',
    employeeId:   leave?.employeeId   || '',
    department:   leave?.department   || '',
    reason:       leave?.reason       || '',
    fromDate:     leave?.fromDate     || leave?.startDate || leave?.from || today,
    toDate:       leave?.toDate       || leave?.endDate   || leave?.to   || today,
    status:       leave?.status       || 'Pending',
    appliedAt:    leave?.appliedAt    || today,
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
    setSaving(true); setError('');
    try {
      if (isEdit) await update(cid, 'leaves', leave.id, form);
      else        await add(col(cid, 'leaves'), form);
      onClose();
    } catch (e) { setError(e.message); }
    finally { setSaving(false); }
  }

  return (
    <Modal title={isEdit ? 'Edit Leave' : 'Add Leave Request'} onClose={onClose} wide>
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

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label">From Date</label>
            <input className="input" type="date" value={form.fromDate} onChange={e => set('fromDate', e.target.value)} />
          </div>
          <div>
            <label className="label">To Date</label>
            <input className="input" type="date" value={form.toDate} onChange={e => set('toDate', e.target.value)} />
          </div>
        </div>
        <div>
          <label className="label">Reason</label>
          <textarea className="input" rows={2} value={form.reason} onChange={e => set('reason', e.target.value)} placeholder="Reason for leave…" />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label">Applied Date</label>
            <input className="input" type="date" value={form.appliedAt} onChange={e => set('appliedAt', e.target.value)} />
          </div>
          <div>
            <label className="label">Status</label>
            <select className="input" value={form.status} onChange={e => set('status', e.target.value)}>
              <option value="Pending">Pending</option>
              <option value="Approved">Approved</option>
              <option value="Rejected">Rejected</option>
            </select>
          </div>
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
