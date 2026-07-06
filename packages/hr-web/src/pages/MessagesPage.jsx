import { useEffect, useState } from 'react';
import { Search, X, Loader2, MessageSquare, Send } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, orderBy, limit } from '../lib/db';
import { formatDate, timeAgo } from '../lib/utils';

export function MessagesPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [messages, setMessages] = useState([]);
  const [search,   setSearch]   = useState('');
  const [loading,  setLoading]  = useState(true);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'messages'), (docs) => {
      setMessages(docs);
      setLoading(false);
    }, [orderBy('createdAt', 'desc'), limit(50)]);
    return unsub;
  }, [cid]);

  const filtered = messages.filter(m => {
    const q = search.toLowerCase();
    return !q
      || (m.from || '').toLowerCase().includes(q)
      || (m.to || '').toLowerCase().includes(q)
      || (m.subject || m.body || '').toLowerCase().includes(q);
  });

  const unread = messages.filter(m => !m.read).length;

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h2 className="page-title">Messages</h2>
          <p className="page-sub">{unread > 0 ? `${unread} unread` : 'All caught up'}</p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <div className="stat-card">
          <div className="stat-icon bg-blue-50 text-blue-600"><MessageSquare size={18} /></div>
          <div><p className="stat-label">Total</p><p className="stat-value">{messages.length}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-amber-50 text-amber-600"><MessageSquare size={18} /></div>
          <div><p className="stat-label">Unread</p><p className="stat-value">{unread}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-emerald-50 text-emerald-600"><MessageSquare size={18} /></div>
          <div><p className="stat-label">Read</p><p className="stat-value">{messages.length - unread}</p></div>
        </div>
      </div>

      <div className="relative max-w-sm">
        <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input className="input pl-9" placeholder="Search messages…"
          value={search} onChange={e => setSearch(e.target.value)} />
        {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={14} /></button>}
      </div>

      {loading ? (
        <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <div className="empty-state-icon"><MessageSquare size={24} /></div>
          <p className="text-sm font-semibold text-gray-600">No messages yet</p>
        </div>
      ) : (
        <div className="card divide-y divide-gray-50">
          {filtered.map(m => (
            <div key={m.id} className={`px-5 py-4 hover:bg-gray-50/50 transition-colors ${!m.read ? 'bg-blue-50/30' : ''}`}>
              <div className="flex items-start gap-3">
                <div className={`w-2 h-2 rounded-full mt-2 shrink-0 ${!m.read ? 'bg-blue-500' : 'bg-transparent'}`} />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2">
                    <p className={`text-sm truncate ${!m.read ? 'font-bold text-gray-900' : 'font-semibold text-gray-700'}`}>
                      {m.subject || m.body?.slice(0, 60) || 'Message'}
                    </p>
                    <p className="text-[11px] text-gray-400 shrink-0">{timeAgo(m.createdAt)}</p>
                  </div>
                  <p className="text-xs text-gray-500 mt-0.5">From: {m.from || '—'} → To: {m.to || '—'}</p>
                  {m.body && <p className="text-xs text-gray-400 mt-1 line-clamp-2">{m.body}</p>}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
