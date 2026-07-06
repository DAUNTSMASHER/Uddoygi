import { useEffect, useState } from 'react';
import { Search, X, Loader2, AlertCircle, CheckCircle } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, update, orderBy, limit } from '../lib/db';
import { formatDate, timeAgo } from '../lib/utils';

export function ComplaintsPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [complaints, setComplaints] = useState([]);
  const [search,     setSearch]     = useState('');
  const [filter,     setFilter]     = useState('all');
  const [loading,    setLoading]    = useState(true);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'complaints'), (docs) => {
      setComplaints(docs);
      setLoading(false);
    }, [orderBy('createdAt', 'desc'), limit(100)]);
    return unsub;
  }, [cid]);

  const filtered = complaints.filter(c => {
    const matchFilter = filter === 'all' || (c.status || 'pending').toLowerCase() === filter;
    const q = search.toLowerCase();
    const matchSearch = !q
      || (c.subject || '').toLowerCase().includes(q)
      || (c.submittedBy || c.from || '').toLowerCase().includes(q);
    return matchFilter && matchSearch;
  });

  const pending  = complaints.filter(c => (c.status || 'pending').toLowerCase() === 'pending').length;
  const resolved = complaints.filter(c => (c.status || '').toLowerCase() === 'resolved').length;

  async function handleResolve(id) {
    await update(cid, 'complaints', id, {
      status: 'resolved',
      resolvedBy: session?.displayName || session?.email,
      resolvedAt: new Date().toISOString(),
    });
  }

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h2 className="page-title">Complaints</h2>
          <p className="page-sub">{pending} pending</p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <div className="stat-card">
          <div className="stat-icon bg-amber-50 text-amber-600"><AlertCircle size={18} /></div>
          <div><p className="stat-label">Pending</p><p className="stat-value">{pending}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-emerald-50 text-emerald-600"><CheckCircle size={18} /></div>
          <div><p className="stat-label">Resolved</p><p className="stat-value">{resolved}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-blue-50 text-blue-600"><AlertCircle size={18} /></div>
          <div><p className="stat-label">Total</p><p className="stat-value">{complaints.length}</p></div>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-[200px] max-w-sm">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input className="input pl-9" placeholder="Search complaints…"
            value={search} onChange={e => setSearch(e.target.value)} />
          {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={14} /></button>}
        </div>
        <div className="flex gap-1 bg-white border border-gray-200 rounded-xl p-1">
          {['all', 'pending', 'resolved'].map(f => (
            <button key={f} onClick={() => setFilter(f)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition capitalize ${filter === f ? 'bg-[#065F46] text-white' : 'text-gray-600 hover:bg-gray-100'}`}>
              {f}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <div className="empty-state-icon"><AlertCircle size={24} /></div>
          <p className="text-sm font-semibold text-gray-600">No complaints found</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map(c => {
            const isPending = (c.status || 'pending').toLowerCase() === 'pending';
            return (
              <div key={c.id} className="card p-4">
                <div className="flex items-start justify-between gap-4">
                  <div className="flex items-start gap-3 flex-1 min-w-0">
                    <div className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${isPending ? 'bg-amber-50 text-amber-600' : 'bg-emerald-50 text-emerald-600'}`}>
                      {isPending ? <AlertCircle size={16} /> : <CheckCircle size={16} />}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <p className="text-sm font-bold text-gray-900 truncate">
                          {c.subject || c.title || 'Complaint'}
                        </p>
                        <span className={`badge ${isPending ? 'badge-yellow' : 'badge-green'}`}>
                          {c.status || 'pending'}
                        </span>
                      </div>
                      <p className="text-xs text-gray-500 mt-0.5">
                        From: {c.submittedBy || c.from || c.employeeName || '—'} · {timeAgo(c.createdAt)}
                      </p>
                      {c.description && (
                        <p className="text-xs text-gray-600 mt-2 line-clamp-2">{c.description}</p>
                      )}
                      {!isPending && c.resolvedBy && (
                        <p className="text-xs text-emerald-600 mt-1">Resolved by {c.resolvedBy} · {formatDate(c.resolvedAt)}</p>
                      )}
                    </div>
                  </div>
                  {isPending && (
                    <button onClick={() => handleResolve(c.id)} className="btn-primary btn-sm shrink-0">
                      <CheckCircle size={13} /> Resolve
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
