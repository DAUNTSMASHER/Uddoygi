// ProcurementPage.jsx — Procurement Management
// Mirrors Flutter procurement_screen.dart (ProcurementScreen)
// Collections: procurements, expenses, cash_flow, company_profile, notifications

import { useEffect, useState, useMemo } from 'react';
import {
  ShoppingCart, Clock, CheckCircle2, Package, Loader2,
  Plus, X, ChevronDown, ChevronUp, MoreVertical, Edit2, Trash2,
  Check, AlertTriangle, DollarSign, Building2,
} from 'lucide-react';
import {
  collection, onSnapshot, addDoc, updateDoc, deleteDoc,
  doc, serverTimestamp, writeBatch, increment,
} from 'firebase/firestore';
import { db } from '../lib/db';
import { useAuth } from '../context/AuthContext';

const BRAND = '#065F46';
const DEPTS = ['marketing', 'factory', 'rnd', 'hr', 'admin'];

const STATUS_CONFIG = {
  Pending:   { bg: '#FEF9C3', text: '#854D0E', border: '#FDE047', icon: Clock },
  Approved:  { bg: '#DBEAFE', text: '#1E40AF', border: '#93C5FD', icon: CheckCircle2 },
  Received:  { bg: '#DCFCE7', text: '#166534', border: '#86EFAC', icon: Package },
  Cancelled: { bg: '#F3F4F6', text: '#6B7280', border: '#D1D5DB', icon: X },
};

const TABS = ['Pending', 'Approved', 'Received', 'All'];

function fmt(v) {
  return new Intl.NumberFormat('en-BD', { minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(v || 0);
}
function fmtDate(ts) {
  if (!ts) return '—';
  const d = ts?.toDate ? ts.toDate() : new Date((ts.seconds || 0) * 1000);
  return d.toLocaleDateString('en-BD', { day: '2-digit', month: 'short', year: 'numeric' });
}

export function ProcurementPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [items,   setItems]   = useState([]);
  const [loading, setLoading] = useState(true);
  const [tab,     setTab]     = useState('Pending');
  const [showAdd, setShowAdd] = useState(false);
  const [editDoc, setEditDoc] = useState(null);

  useEffect(() => {
    if (!cid) return;
    const unsub = onSnapshot(collection(db, 'data', cid, 'procurements'), snap => {
      const docs = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      docs.sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
      setItems(docs);
      setLoading(false);
    });
    return unsub;
  }, [cid]);

  const filtered = useMemo(() => {
    if (tab === 'All') return items;
    return items.filter(i => i.status === tab);
  }, [items, tab]);

  const stats = useMemo(() => ({
    pending:  items.filter(i => i.status === 'Pending').length,
    approved: items.filter(i => i.status === 'Approved').length,
    received: items.filter(i => i.status === 'Received').length,
    spent:    items.filter(i => i.status === 'Received').reduce((s, i) => s + (i.amount || 0), 0),
  }), [items]);

  async function handleSave(data) {
    if (!cid) return;
    if (editDoc) {
      await updateDoc(doc(db, 'data', cid, 'procurements', editDoc.id), {
        ...data, updatedAt: serverTimestamp(),
      });
    } else {
      await addDoc(collection(db, 'data', cid, 'procurements'), {
        ...data,
        status: 'Pending',
        requestedByEmail: session?.email || '',
        requestedByName:  session?.displayName || session?.email || 'HR',
        requestedAt: serverTimestamp(),
        createdAt:   serverTimestamp(),
      });
    }
    setShowAdd(false);
    setEditDoc(null);
  }

  async function handleDelete(id) {
    if (!cid || !window.confirm('Delete this procurement request?')) return;
    await deleteDoc(doc(db, 'data', cid, 'procurements', id));
  }

  async function handleApprove(item) {
    if (!cid) return;
    await updateDoc(doc(db, 'data', cid, 'procurements', item.id), {
      status:          'Approved',
      approvedBy:      session?.email || '',
      approvedByName:  session?.displayName || 'HR',
      approvedAt:      serverTimestamp(),
      updatedAt:       serverTimestamp(),
    });
    // Notification
    try {
      await addDoc(collection(db, 'data', cid, 'notifications'), {
        title:   'Procurement Approved',
        body:    `Your request for "${item.item}" has been approved.`,
        toEmail: item.requestedByEmail || '',
        type:    'procurement',
        read:    false,
        createdAt: serverTimestamp(),
      });
    } catch (_) {}
  }

  async function handleReceive(item) {
    if (!cid || !window.confirm(`Mark "${item.item}" as received? This will record an expense and deduct from balance.`)) return;
    const batch = writeBatch(db);

    // Update procurement
    batch.update(doc(db, 'data', cid, 'procurements', item.id), {
      status:          'Received',
      receivedBy:      session?.email || '',
      receivedByName:  session?.displayName || 'HR',
      receivedAt:      serverTimestamp(),
      updatedAt:       serverTimestamp(),
    });

    // Add expense
    const expRef = doc(collection(db, 'data', cid, 'expenses'));
    batch.set(expRef, {
      vendor:        item.vendor || '',
      category:      'Procurement',
      item:          item.item || '',
      quantity:      item.quantity || 1,
      amount:        item.amount || 0,
      department:    item.requestedByDept || '',
      status:        'paid',
      notes:         item.notes || '',
      procurementId: item.id,
      addedBy:       session?.email || '',
      addedByName:   session?.displayName || 'HR',
      createdAt:     serverTimestamp(),
    });

    // Add cash_flow
    const cfRef = doc(collection(db, 'data', cid, 'cash_flow'));
    batch.set(cfRef, {
      type:          'cash_out',
      amount:        item.amount || 0,
      currency:      'BDT',
      method:        'cash',
      description:   `Procurement: ${item.item}`,
      department:    item.requestedByDept || '',
      procurementId: item.id,
      approvedBy:    session?.email || '',
      approvedByName: session?.displayName || 'HR',
      date:          serverTimestamp(),
      createdAt:     serverTimestamp(),
    });

    // Update company profile
    batch.update(doc(db, 'data', cid, 'company_profile', 'main'), {
      cashOut:            increment(item.amount || 0),
      lastCashOutAt:      serverTimestamp(),
      lastCashOutAmount:  item.amount || 0,
      lastCashOutItem:    item.item || '',
    });

    await batch.commit();

    // Notification
    try {
      await addDoc(collection(db, 'data', cid, 'notifications'), {
        title:   'Procurement Received',
        body:    `"${item.item}" has been received and expense recorded.`,
        toEmail: item.requestedByEmail || '',
        type:    'procurement',
        read:    false,
        createdAt: serverTimestamp(),
      });
    } catch (_) {}
  }

  async function handleCancel(item) {
    if (!cid || !window.confirm('Cancel this procurement request?')) return;
    await updateDoc(doc(db, 'data', cid, 'procurements', item.id), {
      status:       'Cancelled',
      cancelledBy:  session?.email || '',
      cancelledAt:  serverTimestamp(),
      updatedAt:    serverTimestamp(),
    });
  }

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
          <h2 className="page-title">Procurement</h2>
          <p className="page-sub">Manage purchase requests and vendor orders</p>
        </div>
        <button onClick={() => { setEditDoc(null); setShowAdd(true); }} className="btn-primary">
          <Plus size={15} /> New Request
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { label: 'Pending',  value: stats.pending,  icon: Clock,        bg: '#FEF9C3', color: '#CA8A04' },
          { label: 'Approved', value: stats.approved, icon: CheckCircle2, bg: '#DBEAFE', color: '#2563EB' },
          { label: 'Received', value: stats.received, icon: Package,      bg: '#DCFCE7', color: '#16A34A' },
          { label: 'Total Spent', value: `৳${fmt(stats.spent)}`, icon: DollarSign, bg: '#F3E8FF', color: '#7C3AED' },
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

      {/* Tabs */}
      <div className="flex gap-1 p-1 bg-gray-100 rounded-xl w-fit">
        {TABS.map(t => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`px-4 py-2 rounded-lg text-sm font-bold transition ${
              tab === t ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      {/* List */}
      {filtered.length === 0 ? (
        <div className="card p-12 text-center">
          <ShoppingCart size={36} className="mx-auto mb-3 text-gray-200" />
          <p className="text-gray-400 font-semibold">No {tab === 'All' ? '' : tab.toLowerCase()} procurement requests</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map(item => (
            <ProcurementCard
              key={item.id}
              item={item}
              onEdit={() => { setEditDoc(item); setShowAdd(true); }}
              onDelete={() => handleDelete(item.id)}
              onApprove={() => handleApprove(item)}
              onReceive={() => handleReceive(item)}
              onCancel={() => handleCancel(item)}
            />
          ))}
        </div>
      )}

      {/* Add/Edit modal */}
      {showAdd && (
        <ProcurementModal
          initial={editDoc}
          onSave={handleSave}
          onClose={() => { setShowAdd(false); setEditDoc(null); }}
        />
      )}
    </div>
  );
}

function ProcurementCard({ item, onEdit, onDelete, onApprove, onReceive, onCancel }) {
  const [expanded, setExpanded] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const sc = STATUS_CONFIG[item.status] || STATUS_CONFIG['Pending'];
  const StatusIcon = sc.icon;

  return (
    <div className="card overflow-hidden">
      <div className="flex items-center gap-3 p-4 cursor-pointer" onClick={() => setExpanded(p => !p)}>
        <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
          style={{ background: sc.bg }}>
          <StatusIcon size={20} style={{ color: sc.text }} />
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <p className="font-bold text-gray-900 text-sm">{item.item || '—'}</p>
            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold border"
              style={{ background: sc.bg, color: sc.text, borderColor: sc.border }}>
              {item.status}
            </span>
          </div>
          <p className="text-xs text-gray-400 mt-0.5 truncate">
            {item.vendor || 'No vendor'} · Qty: {item.quantity || 1} · {fmtDate(item.createdAt)}
          </p>
        </div>
        <div className="text-right shrink-0">
          <p className="font-black text-sm" style={{ color: BRAND }}>৳{fmt(item.amount)}</p>
          <p className="text-[10px] text-gray-400">{item.requestedByDept || '—'}</p>
        </div>
        {/* Menu */}
        <div className="relative shrink-0" onClick={e => e.stopPropagation()}>
          <button
            onClick={() => setMenuOpen(p => !p)}
            className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-400"
          >
            <MoreVertical size={16} />
          </button>
          {menuOpen && (
            <div className="absolute right-0 top-8 bg-white rounded-xl shadow-xl border border-gray-100 z-10 w-36 py-1">
              <button onClick={() => { setMenuOpen(false); onEdit(); }}
                className="flex items-center gap-2 w-full px-3 py-2 text-sm text-gray-700 hover:bg-gray-50">
                <Edit2 size={13} /> Edit
              </button>
              <button onClick={() => { setMenuOpen(false); onDelete(); }}
                className="flex items-center gap-2 w-full px-3 py-2 text-sm text-red-600 hover:bg-red-50">
                <Trash2 size={13} /> Delete
              </button>
            </div>
          )}
        </div>
        <div className="shrink-0 text-gray-400">
          {expanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
        </div>
      </div>

      {expanded && (
        <div className="border-t border-gray-100 p-4 bg-gray-50 space-y-3">
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 text-sm">
            {[
              { label: 'Requested By', value: item.requestedByName || item.requestedByEmail || '—' },
              { label: 'Department',   value: item.requestedByDept || '—' },
              { label: 'Requested At', value: fmtDate(item.requestedAt) },
              ...(item.approvedBy ? [{ label: 'Approved By', value: item.approvedByName || item.approvedBy }] : []),
              ...(item.receivedBy ? [{ label: 'Received By', value: item.receivedByName || item.receivedBy }] : []),
            ].map(f => (
              <div key={f.label} className="bg-white rounded-lg p-2.5 border border-gray-100">
                <p className="text-[10px] text-gray-400 font-semibold">{f.label}</p>
                <p className="font-bold text-gray-800 text-xs mt-0.5">{f.value}</p>
              </div>
            ))}
          </div>

          {item.notes && (
            <div className="bg-white rounded-lg p-3 border border-gray-100">
              <p className="text-[10px] text-gray-400 font-semibold mb-1">Notes</p>
              <p className="text-sm text-gray-700">{item.notes}</p>
            </div>
          )}

          {item.status === 'Received' && (
            <div className="flex items-center gap-2 p-3 rounded-xl bg-green-50 border border-green-200">
              <Check size={14} className="text-green-600 shrink-0" />
              <p className="text-xs text-green-700 font-semibold">Expense & cash-out auto-recorded</p>
            </div>
          )}

          {/* Action buttons */}
          <div className="flex gap-2 flex-wrap pt-1">
            {item.status === 'Pending' && (
              <>
                <button onClick={onApprove}
                  className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold text-white transition"
                  style={{ background: BRAND }}>
                  <Check size={14} /> Approve
                </button>
                <button onClick={onCancel}
                  className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold text-white bg-gray-500 hover:bg-gray-600 transition">
                  <X size={14} /> Cancel
                </button>
              </>
            )}
            {item.status === 'Approved' && (
              <>
                <button onClick={onReceive}
                  className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold text-white transition"
                  style={{ background: '#2563EB' }}>
                  <Package size={14} /> Mark Received
                </button>
                <button onClick={onCancel}
                  className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold text-white bg-gray-500 hover:bg-gray-600 transition">
                  <X size={14} /> Cancel
                </button>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function ProcurementModal({ initial, onSave, onClose }) {
  const [form, setForm] = useState({
    item:             initial?.item || '',
    quantity:         initial?.quantity || 1,
    vendor:           initial?.vendor || '',
    amount:           initial?.amount || '',
    notes:            initial?.notes || '',
    requestedByDept:  initial?.requestedByDept || 'hr',
  });
  const [saving, setSaving] = useState(false);

  function set(k, v) { setForm(p => ({ ...p, [k]: v })); }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.item.trim()) return;
    setSaving(true);
    try {
      await onSave({ ...form, amount: parseFloat(form.amount) || 0, quantity: parseInt(form.quantity) || 1 });
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h3 className="font-black text-gray-900">{initial ? 'Edit Request' : 'New Procurement Request'}</h3>
          <button onClick={onClose} className="btn-icon"><X size={16} /></button>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="label">Item / Description *</label>
            <input className="input" value={form.item} onChange={e => set('item', e.target.value)} required />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Quantity</label>
              <input type="number" min="1" className="input" value={form.quantity} onChange={e => set('quantity', e.target.value)} />
            </div>
            <div>
              <label className="label">Amount (৳)</label>
              <input type="number" min="0" className="input" value={form.amount} onChange={e => set('amount', e.target.value)} />
            </div>
          </div>
          <div>
            <label className="label">Vendor</label>
            <input className="input" value={form.vendor} onChange={e => set('vendor', e.target.value)} />
          </div>
          <div>
            <label className="label">Department</label>
            <select className="input" value={form.requestedByDept} onChange={e => set('requestedByDept', e.target.value)}>
              {DEPTS.map(d => <option key={d} value={d}>{d.charAt(0).toUpperCase() + d.slice(1)}</option>)}
            </select>
          </div>
          <div>
            <label className="label">Notes</label>
            <textarea rows={2} className="input resize-none" value={form.notes} onChange={e => set('notes', e.target.value)} />
          </div>
          <div className="flex gap-3 pt-2">
            <button type="submit" disabled={saving || !form.item.trim()} className="btn-primary flex-1 disabled:opacity-50">
              {saving ? <Loader2 size={14} className="animate-spin" /> : null}
              {saving ? 'Saving…' : initial ? 'Update' : 'Submit Request'}
            </button>
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}
