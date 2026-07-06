// WelfarePage.jsx — HR Welfare Request Approval
// Mirrors Flutter welfare_screen.dart (HRWelfareScreen)
// Collection: welfare_requests (top-level)
// HR can: Verify & Forward (→ Pending Admin) or Decline requests

import { useEffect, useState, useMemo } from 'react';
import {
  Heart, CheckCircle2, Clock, XCircle, Users,
  Loader2, ChevronDown, ChevronUp, Send, X,
} from 'lucide-react';
import {
  collection, onSnapshot, updateDoc, doc, serverTimestamp,
} from 'firebase/firestore';
import { db } from '../lib/db';
import { useAuth } from '../context/AuthContext';

const BRAND = '#065F46';
const STATUS_COLORS = {
  'Pending HR':    { bg: '#FEF9C3', text: '#854D0E', border: '#FDE047' },
  'Pending Admin': { bg: '#DBEAFE', text: '#1E40AF', border: '#93C5FD' },
  'Approved':      { bg: '#DCFCE7', text: '#166534', border: '#86EFAC' },
  'Rejected':      { bg: '#FEE2E2', text: '#991B1B', border: '#FCA5A5' },
  'Declined':      { bg: '#F3F4F6', text: '#374151', border: '#D1D5DB' },
};
const FILTER_OPTIONS = ['All', 'Pending HR', 'Pending Admin', 'Approved', 'Rejected', 'Declined'];

function fmt(v) {
  return new Intl.NumberFormat('en-BD', { minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(v || 0);
}
function fmtDate(ts) {
  if (!ts) return '—';
  const d = ts?.toDate ? ts.toDate() : new Date((ts.seconds || 0) * 1000);
  return d.toLocaleDateString('en-BD', { day: '2-digit', month: 'short', year: 'numeric' });
}

export function WelfarePage() {
  const { session } = useAuth();
  const [requests, setRequests] = useState([]);
  const [loading,  setLoading]  = useState(true);
  const [filter,   setFilter]   = useState('All');

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'welfare_requests'), snap => {
      const docs = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      docs.sort((a, b) => {
        const ta = a.submittedAt?.seconds || 0;
        const tb = b.submittedAt?.seconds || 0;
        return tb - ta;
      });
      setRequests(docs);
      setLoading(false);
    });
    return unsub;
  }, []);

  const filtered = useMemo(() => {
    if (filter === 'All') return requests;
    return requests.filter(r => r.status === filter);
  }, [requests, filter]);

  const stats = useMemo(() => ({
    total:       requests.length,
    needsReview: requests.filter(r => r.status === 'Pending HR').length,
    withAdmin:   requests.filter(r => r.status === 'Pending Admin').length,
    approved:    requests.filter(r => r.status === 'Approved').length,
  }), [requests]);

  if (loading) {
    return (
      <div className="flex justify-center items-center py-32">
        <Loader2 size={28} className="animate-spin" style={{ color: BRAND }} />
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="page-header">
        <div>
          <h2 className="page-title">Welfare Requests</h2>
          <p className="page-sub">Review and forward employee welfare requests</p>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { label: 'Total',        value: stats.total,       icon: Users,        bg: '#EFF6FF', color: '#2563EB' },
          { label: 'Needs Review', value: stats.needsReview, icon: Clock,        bg: '#FEF9C3', color: '#CA8A04' },
          { label: 'With Admin',   value: stats.withAdmin,   icon: Send,         bg: '#EDE9FE', color: '#7C3AED' },
          { label: 'Approved',     value: stats.approved,    icon: CheckCircle2, bg: '#DCFCE7', color: '#16A34A' },
        ].map(s => (
          <div key={s.label} className="card p-4 flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
              style={{ background: s.bg }}>
              <s.icon size={20} style={{ color: s.color }} />
            </div>
            <div>
              <p className="text-xs text-gray-400 font-semibold">{s.label}</p>
              <p className="text-xl font-black text-gray-900">{s.value}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Filter chips */}
      <div className="flex gap-2 flex-wrap">
        {FILTER_OPTIONS.map(f => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-3 py-1.5 rounded-full text-xs font-bold border transition ${
              filter === f
                ? 'text-white border-transparent'
                : 'bg-white text-gray-600 border-gray-200 hover:border-gray-300'
            }`}
            style={filter === f ? { background: BRAND, borderColor: BRAND } : {}}
          >
            {f}
          </button>
        ))}
      </div>

      {/* List */}
      {filtered.length === 0 ? (
        <div className="card p-12 text-center">
          <Heart size={36} className="mx-auto mb-3 text-gray-200" />
          <p className="text-gray-400 font-semibold">No welfare requests found</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map(req => (
            <WelfareCard key={req.id} req={req} session={session} />
          ))}
        </div>
      )}
    </div>
  );
}

function WelfareCard({ req, session }) {
  const [expanded, setExpanded] = useState(false);
  const [showAction, setShowAction] = useState(null); // 'forward' | 'decline'
  const [note, setNote] = useState('');
  const [saving, setSaving] = useState(false);

  const sc = STATUS_COLORS[req.status] || STATUS_COLORS['Declined'];
  const initials = (req.employeeName || req.employeeEmail || '?').charAt(0).toUpperCase();

  async function handleAction(action) {
    if (!req.id) return;
    setSaving(true);
    try {
      const newStatus = action === 'forward' ? 'Pending Admin' : 'Declined';
      await updateDoc(doc(db, 'welfare_requests', req.id), {
        status:        newStatus,
        hrNote:        note,
        hrVerifiedBy:  session?.email || 'HR',
        hrVerifiedAt:  serverTimestamp(),
      });
      setShowAction(null);
      setNote('');
    } catch (e) {
      alert('Failed: ' + e.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="card overflow-hidden">
      {/* Card header */}
      <div
        className="flex items-center gap-3 p-4 cursor-pointer"
        onClick={() => setExpanded(p => !p)}
      >
        <div className="w-10 h-10 rounded-xl flex items-center justify-center text-white font-black shrink-0"
          style={{ background: BRAND }}>
          {initials}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <p className="font-bold text-gray-900 text-sm">{req.employeeName || req.employeeEmail || '—'}</p>
            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold border"
              style={{ background: sc.bg, color: sc.text, borderColor: sc.border }}>
              {req.status}
            </span>
          </div>
          <p className="text-xs text-gray-400 mt-0.5 truncate">
            {req.department} · {req.schemeTitle || 'Welfare Request'} · {fmtDate(req.submittedAt)}
          </p>
        </div>
        <div className="text-right shrink-0">
          <p className="font-black text-sm" style={{ color: BRAND }}>৳{fmt(req.requestedAmount)}</p>
          <p className="text-[10px] text-gray-400">Requested</p>
        </div>
        <div className="shrink-0 text-gray-400 ml-1">
          {expanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
        </div>
      </div>

      {/* Expanded details */}
      {expanded && (
        <div className="border-t border-gray-100 p-4 bg-gray-50 space-y-3">
          {/* Employee info */}
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 text-sm">
            {[
              { label: 'Email',      value: req.employeeEmail || '—' },
              { label: 'Department', value: req.department || '—' },
              { label: 'Scheme',     value: req.schemeTitle || '—' },
            ].map(f => (
              <div key={f.label} className="bg-white rounded-lg p-2.5 border border-gray-100">
                <p className="text-[10px] text-gray-400 font-semibold">{f.label}</p>
                <p className="font-bold text-gray-800 text-xs mt-0.5 break-all">{f.value}</p>
              </div>
            ))}
          </div>

          {/* Reason */}
          {req.reason && (
            <div className="bg-white rounded-lg p-3 border border-gray-100">
              <p className="text-[10px] text-gray-400 font-semibold mb-1">Reason</p>
              <p className="text-sm text-gray-700">{req.reason}</p>
            </div>
          )}

          {/* HR Note */}
          {req.hrNote && (
            <div className="bg-blue-50 rounded-lg p-3 border border-blue-100">
              <p className="text-[10px] text-blue-400 font-semibold mb-1">HR Note</p>
              <p className="text-sm text-blue-800">{req.hrNote}</p>
            </div>
          )}

          {/* Admin Note */}
          {req.adminNote && (
            <div className="bg-purple-50 rounded-lg p-3 border border-purple-100">
              <p className="text-[10px] text-purple-400 font-semibold mb-1">Admin Note</p>
              <p className="text-sm text-purple-800">{req.adminNote}</p>
            </div>
          )}

          {/* Action buttons — only for Pending HR */}
          {req.status === 'Pending HR' && !showAction && (
            <div className="flex gap-2 pt-1">
              <button
                onClick={() => setShowAction('forward')}
                className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold text-white transition"
                style={{ background: BRAND }}
              >
                <Send size={14} /> Verify & Forward
              </button>
              <button
                onClick={() => setShowAction('decline')}
                className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold text-white bg-red-500 hover:bg-red-600 transition"
              >
                <XCircle size={14} /> Decline
              </button>
            </div>
          )}

          {/* Inline action form */}
          {showAction && (
            <div className="bg-white rounded-xl border border-gray-200 p-4 space-y-3">
              <p className="font-bold text-sm text-gray-800">
                {showAction === 'forward' ? '✅ Verify & Forward to Admin' : '❌ Decline Request'}
              </p>
              <div>
                <label className="label">
                  HR Note {showAction === 'decline' ? '(required)' : '(optional)'}
                </label>
                <textarea
                  rows={3}
                  className="input resize-none"
                  placeholder={showAction === 'forward' ? 'Add a note for admin…' : 'Reason for declining…'}
                  value={note}
                  onChange={e => setNote(e.target.value)}
                />
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => handleAction(showAction)}
                  disabled={saving || (showAction === 'decline' && !note.trim())}
                  className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold text-white transition disabled:opacity-50"
                  style={{ background: showAction === 'forward' ? BRAND : '#EF4444' }}
                >
                  {saving ? <Loader2 size={14} className="animate-spin" /> : null}
                  {saving ? 'Saving…' : showAction === 'forward' ? 'Confirm Forward' : 'Confirm Decline'}
                </button>
                <button
                  onClick={() => { setShowAction(null); setNote(''); }}
                  className="px-4 py-2 rounded-xl text-sm font-bold bg-gray-100 text-gray-600 hover:bg-gray-200 transition"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
