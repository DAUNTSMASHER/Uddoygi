import { useEffect, useState } from 'react';
import { Plus, Bell, X, Loader2, Edit2 } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, update, remove, orderBy } from '../lib/db';
import { formatDate, timeAgo } from '../lib/utils';
import { Modal } from '../components/ui/Modal';

export function NoticesPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [notices, setNotices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal]     = useState(null);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'notices'), (docs) => {
      setNotices(docs);
      setLoading(false);
    }, [orderBy('createdAt', 'desc')]);
    return unsub;
  }, [cid]);

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h2 className="page-title">Notices</h2>
          <p className="page-sub">{notices.length} notices</p>
        </div>
        <button onClick={() => setModal('add')} className="btn-primary">
          <Plus size={16} /> Post Notice
        </button>
      </div>

      {loading ? (
        <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div>
      ) : notices.length === 0 ? (
        <div className="empty-state card-p">
          <div className="empty-state-icon"><Bell size={24} /></div>
          <p className="font-semibold text-gray-700">No notices yet</p>
          <p className="text-sm text-gray-400 mt-1">Post a notice to inform your team</p>
          <button onClick={() => setModal('add')} className="btn-primary mt-4"><Plus size={16} /> Post Notice</button>
        </div>
      ) : (
        <div className="space-y-3">
          {notices.map((n) => (
            <div key={n.id} className="card p-5 hover:shadow-card-md transition-shadow">
              <div className="flex items-start justify-between gap-4">
                <div className="flex items-start gap-3 flex-1 min-w-0">
                  <div className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${
                    (n.priority || '').toLowerCase() === 'urgent' ? 'bg-red-100 text-red-600' :
                    (n.priority || '').toLowerCase() === 'high'   ? 'bg-orange-100 text-orange-600' :
                    'bg-blue-100 text-blue-600'
                  }`}>
                    <Bell size={18} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="font-bold text-gray-900">{n.title || 'Notice'}</h3>
                      {n.priority && (
                        <span className={`badge ${
                          (n.priority || '').toLowerCase() === 'urgent' ? 'badge-red' :
                          (n.priority || '').toLowerCase() === 'high'   ? 'badge-yellow' :
                          'badge-blue'
                        }`}>{n.priority}</span>
                      )}
                      {n.department && <span className="badge badge-gray">{n.department}</span>}
                    </div>
                    <p className="text-sm text-gray-600 mt-1 leading-relaxed">{n.content || n.body || n.message || '—'}</p>
                    <p className="text-xs text-gray-400 mt-2">{timeAgo(n.createdAt)} · Posted by {n.postedBy || n.createdBy || 'HR'}</p>
                  </div>
                </div>
                <div className="flex gap-1 shrink-0">
                  <button onClick={() => setModal(n)} className="btn-icon btn-sm"><Edit2 size={13} /></button>
                  <button onClick={() => remove(cid, 'notices', n.id)} className="btn-icon btn-sm text-red-400 hover:text-red-600"><X size={13} /></button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {modal && <NoticeModal notice={modal === 'add' ? null : modal} cid={cid} session={session} onClose={() => setModal(null)} />}
    </div>
  );
}

function NoticeModal({ notice, cid, session, onClose }) {
  const isEdit = !!notice;
  const [form, setForm] = useState({
    title:      notice?.title || '',
    content:    notice?.content || notice?.body || notice?.message || '',
    priority:   notice?.priority || 'Normal',
    department: notice?.department || 'All',
  });
  const [saving, setSaving] = useState(false);
  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  async function handleSave() {
    if (!form.title) { alert('Title is required.'); return; }
    setSaving(true);
    try {
      const data = { ...form, postedBy: session?.displayName || session?.email || 'HR' };
      if (isEdit) await update(cid, 'notices', notice.id, data);
      else        await add(col(cid, 'notices'), data);
      onClose();
    } catch (e) { alert(e.message); }
    finally { setSaving(false); }
  }

  return (
    <Modal title={isEdit ? 'Edit Notice' : 'Post Notice'} onClose={onClose} wide>
      <div className="space-y-3">
        <div><label className="label">Title *</label><input className="input" value={form.title} onChange={(e) => set('title', e.target.value)} placeholder="Notice title…" /></div>
        <div><label className="label">Content</label><textarea className="input" rows={5} value={form.content} onChange={(e) => set('content', e.target.value)} placeholder="Write the notice content here…" /></div>
        <div className="grid grid-cols-2 gap-3">
          <div><label className="label">Priority</label>
            <select className="input" value={form.priority} onChange={(e) => set('priority', e.target.value)}>
              {['Normal', 'High', 'Urgent'].map(p => <option key={p}>{p}</option>)}
            </select>
          </div>
          <div><label className="label">Department</label>
            <select className="input" value={form.department} onChange={(e) => set('department', e.target.value)}>
              {['All', 'HR', 'Factory', 'Marketing', 'Admin', 'R&D'].map(d => <option key={d}>{d}</option>)}
            </select>
          </div>
        </div>
      </div>
      <div className="flex justify-end gap-3 mt-5">
        <button onClick={onClose} className="btn-secondary">Cancel</button>
        <button onClick={handleSave} disabled={saving} className="btn-primary">
          {saving ? <Loader2 size={14} className="animate-spin" /> : null}
          {saving ? 'Posting…' : isEdit ? 'Save Changes' : 'Post Notice'}
        </button>
      </div>
    </Modal>
  );
}
