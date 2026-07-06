// Recruitment — mirrors Flutter recruitment_screen.dart
// Collection: data/{cid}/applicants  (NOT 'recruitment' — matches C.applicants in Flutter)
// Fields: name, role, status (Applied/Interviewed/Selected/Rejected),
//         files (list of URLs), appliedAt (yyyy-MM-dd string)

import { useEffect, useState } from 'react';
import { Plus, Search, X, Loader2, Briefcase, Edit2, User, FileText, CheckCircle2, XCircle, Clock, Star } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, update, remove, orderBy } from '../lib/db';
import { formatDate, statusBadge } from '../lib/utils';
import { Modal } from '../components/ui/Modal';

const ROLES = ['All', 'Marketing', 'Factory', 'Admin', 'HR', 'R&D', 'Accounts', 'Other'];
const STATUSES = ['Applied', 'Interviewed', 'Selected', 'Rejected'];

const STATUS_STYLES = {
  Applied:     'bg-blue-50 text-blue-700 border border-blue-200',
  Interviewed: 'bg-amber-50 text-amber-700 border border-amber-200',
  Selected:    'bg-green-50 text-green-700 border border-green-200',
  Rejected:    'bg-red-50 text-red-700 border border-red-200',
};

const STATUS_ICONS = {
  Applied:     <Clock size={12} />,
  Interviewed: <Star size={12} />,
  Selected:    <CheckCircle2 size={12} />,
  Rejected:    <XCircle size={12} />,
};

export function RecruitmentPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [applicants, setApplicants] = useState([]);
  const [loading,    setLoading]    = useState(true);
  const [modal,      setModal]      = useState(null);
  const [search,     setSearch]     = useState('');
  const [roleFilter, setRoleFilter] = useState('All');
  const [statusFilter, setStatusFilter] = useState('all');

  useEffect(() => {
    if (!cid) return;
    // Flutter uses C.applicants = 'applicants'
    const unsub = subscribe(col(cid, 'applicants'), (docs) => {
      setApplicants(docs);
      setLoading(false);
    }, [orderBy('appliedAt', 'desc')]);
    return unsub;
  }, [cid]);

  const filtered = applicants.filter(a => {
    const q = search.toLowerCase();
    const matchSearch = !q || (a.name || '').toLowerCase().includes(q) || (a.role || '').toLowerCase().includes(q);
    const matchRole   = roleFilter === 'All' || (a.role || '').toLowerCase() === roleFilter.toLowerCase();
    const matchStatus = statusFilter === 'all' || (a.status || '').toLowerCase() === statusFilter.toLowerCase();
    return matchSearch && matchRole && matchStatus;
  });

  // Stats
  const applied     = applicants.filter(a => (a.status || '') === 'Applied').length;
  const interviewed = applicants.filter(a => (a.status || '') === 'Interviewed').length;
  const selected    = applicants.filter(a => (a.status || '') === 'Selected').length;
  const rejected    = applicants.filter(a => (a.status || '') === 'Rejected').length;

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h2 className="page-title">Recruitment</h2>
          <p className="page-sub">{applicants.length} applicants</p>
        </div>
        <button onClick={() => setModal('add')} className="btn-primary"><Plus size={16} /> Add Applicant</button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-3">
        {[
          { label: 'Applied',     value: applied,     bg: 'bg-blue-50',   text: 'text-blue-600',  icon: <Clock size={18} /> },
          { label: 'Interviewed', value: interviewed, bg: 'bg-amber-50',  text: 'text-amber-600', icon: <Star size={18} /> },
          { label: 'Selected',    value: selected,    bg: 'bg-green-50',  text: 'text-green-600', icon: <CheckCircle2 size={18} /> },
          { label: 'Rejected',    value: rejected,    bg: 'bg-red-50',    text: 'text-red-600',   icon: <XCircle size={18} /> },
        ].map(s => (
          <div key={s.label} className="stat-card">
            <div className={`stat-icon ${s.bg} ${s.text}`}>{s.icon}</div>
            <div><p className="stat-label">{s.label}</p><p className="stat-value text-xl">{s.value}</p></div>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[200px] max-w-sm">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input className="input pl-9" placeholder="Search name or role…" value={search} onChange={e => setSearch(e.target.value)} />
          {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={14} /></button>}
        </div>
        <select className="input w-auto" value={roleFilter} onChange={e => setRoleFilter(e.target.value)}>
          {ROLES.map(r => <option key={r}>{r}</option>)}
        </select>
        <div className="flex gap-1 flex-wrap">
          {['all', ...STATUSES.map(s => s.toLowerCase())].map(f => (
            <button key={f} onClick={() => setStatusFilter(f)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold capitalize transition ${
                statusFilter === f ? 'bg-[#065F46] text-white' : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
              }`}>
              {f}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div>
      ) : filtered.length === 0 ? (
        <div className="card p-12 text-center">
          <div className="w-14 h-14 rounded-2xl bg-gray-100 flex items-center justify-center mx-auto mb-4 text-gray-400">
            <Briefcase size={24} />
          </div>
          <p className="font-semibold text-gray-700">No applicants found</p>
          <p className="text-sm text-gray-400 mt-1">Add applicants using the button above</p>
        </div>
      ) : (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map(a => (
            <div key={a.id} className="card p-5 hover:shadow-card-md transition-shadow">
              <div className="flex items-start justify-between gap-2 mb-3">
                <div className="w-10 h-10 rounded-xl bg-indigo-100 text-indigo-600 flex items-center justify-center shrink-0 font-bold text-sm">
                  {(a.name || '?').charAt(0).toUpperCase()}
                </div>
                <span className={`inline-flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-full ${STATUS_STYLES[a.status] || 'bg-gray-100 text-gray-600'}`}>
                  {STATUS_ICONS[a.status]} {a.status || 'Applied'}
                </span>
              </div>
              <h3 className="font-bold text-gray-900">{a.name || '—'}</h3>
              <p className="text-sm text-gray-500 mt-0.5">{a.role || '—'}</p>
              <p className="text-xs text-gray-400 mt-2">Applied: {a.appliedAt || formatDate(a.createdAt)}</p>

              {/* File chips — mirrors Flutter */}
              {Array.isArray(a.files) && a.files.length > 0 && (
                <div className="flex flex-wrap gap-1.5 mt-3">
                  {a.files.map((url, i) => (
                    <a key={i} href={url} target="_blank" rel="noopener noreferrer"
                      className="inline-flex items-center gap-1 text-xs bg-blue-50 text-blue-700 border border-blue-200 px-2 py-0.5 rounded-full hover:bg-blue-100">
                      <FileText size={10} /> File {i + 1}
                    </a>
                  ))}
                </div>
              )}

              <div className="flex gap-2 mt-4">
                <button onClick={() => setModal(a)} className="btn-secondary btn-sm flex-1 justify-center"><Edit2 size={13} /> Edit</button>
                <button onClick={() => remove(cid, 'applicants', a.id)} className="btn-ghost btn-sm text-red-500 hover:text-red-700"><X size={13} /></button>
              </div>
            </div>
          ))}
        </div>
      )}

      {modal && <ApplicantModal applicant={modal === 'add' ? null : modal} cid={cid} onClose={() => setModal(null)} />}
    </div>
  );
}

function ApplicantModal({ applicant, cid, onClose }) {
  const isEdit = !!applicant;
  const today  = new Date().toISOString().split('T')[0];

  const [form, setForm] = useState({
    name:       applicant?.name       || '',
    role:       applicant?.role       || 'Marketing',
    status:     applicant?.status     || 'Applied',
    appliedAt:  applicant?.appliedAt  || today,
    files:      applicant?.files      || [],
  });
  const [saving, setSaving] = useState(false);
  const [error,  setError]  = useState('');
  const [fileUrl, setFileUrl] = useState('');

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  function addFileUrl() {
    const url = fileUrl.trim();
    if (!url) return;
    setForm(f => ({ ...f, files: [...f.files, url] }));
    setFileUrl('');
  }
  function removeFile(i) {
    setForm(f => ({ ...f, files: f.files.filter((_, idx) => idx !== i) }));
  }

  async function handleSave() {
    if (!form.name.trim()) { setError('Name is required.'); return; }
    setSaving(true); setError('');
    try {
      if (isEdit) await update(cid, 'applicants', applicant.id, form);
      else        await add(col(cid, 'applicants'), form);
      onClose();
    } catch (e) { setError(e.message); }
    finally { setSaving(false); }
  }

  return (
    <Modal title={isEdit ? 'Edit Applicant' : 'New Applicant'} onClose={onClose}>
      <div className="space-y-3">
        <div>
          <label className="label">Full Name *</label>
          <input className="input" value={form.name} onChange={e => set('name', e.target.value)} placeholder="Applicant name" />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label">Role / Department</label>
            <select className="input" value={form.role} onChange={e => set('role', e.target.value)}>
              {ROLES.filter(r => r !== 'All').map(r => <option key={r}>{r}</option>)}
            </select>
          </div>
          <div>
            <label className="label">Status</label>
            <select className="input" value={form.status} onChange={e => set('status', e.target.value)}>
              {STATUSES.map(s => <option key={s}>{s}</option>)}
            </select>
          </div>
        </div>
        <div>
          <label className="label">Applied Date</label>
          <input className="input" type="date" value={form.appliedAt} onChange={e => set('appliedAt', e.target.value)} />
        </div>

        {/* File URLs — mirrors Flutter file chips */}
        <div>
          <label className="label">File URLs (CV, portfolio…)</label>
          <div className="flex gap-2">
            <input className="input flex-1" value={fileUrl} onChange={e => setFileUrl(e.target.value)}
              placeholder="https://…" onKeyDown={e => e.key === 'Enter' && addFileUrl()} />
            <button type="button" onClick={addFileUrl} className="btn-secondary btn-sm whitespace-nowrap">Add</button>
          </div>
          {form.files.length > 0 && (
            <div className="flex flex-wrap gap-1.5 mt-2">
              {form.files.map((url, i) => (
                <span key={i} className="inline-flex items-center gap-1 text-xs bg-blue-50 text-blue-700 border border-blue-200 px-2 py-0.5 rounded-full">
                  <FileText size={10} /> File {i + 1}
                  <button type="button" onClick={() => removeFile(i)} className="ml-0.5 hover:text-red-500"><X size={10} /></button>
                </span>
              ))}
            </div>
          )}
        </div>

        {error && <p className="text-red-600 text-sm">{error}</p>}
        <div className="flex justify-end gap-3 mt-2">
          <button onClick={onClose} className="btn-secondary">Cancel</button>
          <button onClick={handleSave} disabled={saving} className="btn-primary">
            {saving ? <Loader2 size={14} className="animate-spin" /> : null}
            {saving ? 'Saving…' : isEdit ? 'Save' : 'Add Applicant'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
