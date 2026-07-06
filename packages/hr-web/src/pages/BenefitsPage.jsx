// BenefitsPage.jsx — Benefits & Compensation
// Mirrors Flutter benefits_compensation_screen.dart (BenefitsCompensationScreen)
// Collection: benefits (under data/{cid}/benefits)
// Fields: employee, type (Bonus|Incentive|Allowance), amount, note, date

import { useEffect, useState, useMemo } from 'react';
import {
  Gift, TrendingUp, DollarSign, Zap, Plus, X, Loader2,
  Search, Download, Calendar,
} from 'lucide-react';
import {
  collection, onSnapshot, addDoc, serverTimestamp,
} from 'firebase/firestore';
import { db } from '../lib/db';
import { useAuth } from '../context/AuthContext';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

const BRAND = '#065F46';
const TYPES = ['All', 'Bonus', 'Incentive', 'Allowance'];

const TYPE_CONFIG = {
  Bonus:     { bg: '#DCFCE7', text: '#166534', border: '#86EFAC', icon: Gift,      color: '#16A34A' },
  Incentive: { bg: '#FEF9C3', text: '#854D0E', border: '#FDE047', icon: TrendingUp, color: '#CA8A04' },
  Allowance: { bg: '#EDE9FE', text: '#5B21B6', border: '#C4B5FD', icon: DollarSign, color: '#7C3AED' },
};

function fmt(v) {
  return new Intl.NumberFormat('en-BD', { minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(v || 0);
}
function fmtDate(ts) {
  if (!ts) return '—';
  const d = ts?.toDate ? ts.toDate() : (ts instanceof Date ? ts : new Date((ts.seconds || 0) * 1000));
  return d.toLocaleDateString('en-BD', { day: '2-digit', month: 'short', year: 'numeric' });
}

export function BenefitsPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [items,    setItems]    = useState([]);
  const [loading,  setLoading]  = useState(true);
  const [typeFilter, setTypeFilter] = useState('All');
  const [search,   setSearch]   = useState('');
  const [dateFilter, setDateFilter] = useState('');
  const [showAdd,  setShowAdd]  = useState(false);

  useEffect(() => {
    if (!cid) return;
    const unsub = onSnapshot(collection(db, 'data', cid, 'benefits'), snap => {
      const docs = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      docs.sort((a, b) => {
        const ta = a.date?.seconds || 0;
        const tb = b.date?.seconds || 0;
        return tb - ta;
      });
      setItems(docs);
      setLoading(false);
    });
    return unsub;
  }, [cid]);

  const filtered = useMemo(() => {
    return items.filter(i => {
      const matchType = typeFilter === 'All' || i.type === typeFilter;
      const q = search.toLowerCase();
      const matchSearch = !q || (i.employee || '').toLowerCase().includes(q);
      let matchDate = true;
      if (dateFilter) {
        const d = i.date?.toDate ? i.date.toDate() : new Date((i.date?.seconds || 0) * 1000);
        const ds = d.toISOString().slice(0, 10);
        matchDate = ds === dateFilter;
      }
      return matchType && matchSearch && matchDate;
    });
  }, [items, typeFilter, search, dateFilter]);

  const totals = useMemo(() => {
    const t = { Bonus: 0, Incentive: 0, Allowance: 0 };
    items.forEach(i => { if (t[i.type] !== undefined) t[i.type] += i.amount || 0; });
    return t;
  }, [items]);

  async function handleAdd(data) {
    if (!cid) return;
    await addDoc(collection(db, 'data', cid, 'benefits'), {
      ...data,
      createdAt: serverTimestamp(),
    });
    setShowAdd(false);
  }

  function handleExportPDF() {
    const doc = new jsPDF({ unit: 'mm', format: 'a4' });
    doc.setFontSize(16);
    doc.text('Benefits & Compensation Report', 14, 16);
    doc.setFontSize(10);
    doc.text(`Generated: ${new Date().toLocaleDateString()}`, 14, 23);
    autoTable(doc, {
      startY: 28,
      head: [['Date', 'Employee', 'Type', 'Amount (৳)', 'Note']],
      body: filtered.map(i => [
        fmtDate(i.date),
        i.employee || '—',
        i.type || '—',
        fmt(i.amount),
        i.note || '—',
      ]),
      styles: { fontSize: 9 },
      headStyles: { fillColor: [6, 95, 70] },
    });
    doc.save('Benefits_Report.pdf');
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
          <h2 className="page-title">Benefits & Compensation</h2>
          <p className="page-sub">Track bonuses, incentives and allowances</p>
        </div>
        <div className="flex gap-2">
          <button onClick={handleExportPDF} className="btn-secondary">
            <Download size={15} /> PDF
          </button>
          <button onClick={() => setShowAdd(true)} className="btn-primary">
            <Plus size={15} /> Add Benefit
          </button>
        </div>
      </div>

      {/* KPI strip */}
      <div className="grid grid-cols-3 gap-4">
        {['Bonus', 'Incentive', 'Allowance'].map(type => {
          const tc = TYPE_CONFIG[type];
          const Icon = tc.icon;
          return (
            <div key={type} className="card p-4 flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
                style={{ background: tc.bg }}>
                <Icon size={20} style={{ color: tc.color }} />
              </div>
              <div>
                <p className="text-xs text-gray-400 font-semibold">{type}</p>
                <p className="text-xl font-black text-gray-900">৳{fmt(totals[type])}</p>
              </div>
            </div>
          );
        })}
      </div>

      {/* Filters */}
      <div className="card p-4 space-y-3">
        {/* Type chips */}
        <div className="flex gap-2 flex-wrap">
          {TYPES.map(t => (
            <button
              key={t}
              onClick={() => setTypeFilter(t)}
              className={`px-3 py-1.5 rounded-full text-xs font-bold border transition ${
                typeFilter === t
                  ? 'text-white border-transparent'
                  : 'bg-white text-gray-600 border-gray-200 hover:border-gray-300'
              }`}
              style={typeFilter === t ? { background: BRAND, borderColor: BRAND } : {}}
            >
              {t}
            </button>
          ))}
        </div>

        {/* Search + date */}
        <div className="flex gap-3 flex-wrap">
          <div className="relative flex-1 min-w-[180px]">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              className="input pl-9"
              placeholder="Search employee…"
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
            {search && (
              <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400">
                <X size={13} />
              </button>
            )}
          </div>
          <div className="relative">
            <Calendar size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="date"
              className="input pl-9 w-44"
              value={dateFilter}
              onChange={e => setDateFilter(e.target.value)}
            />
            {dateFilter && (
              <button onClick={() => setDateFilter('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400">
                <X size={13} />
              </button>
            )}
          </div>
        </div>
      </div>

      {/* List */}
      {filtered.length === 0 ? (
        <div className="card p-12 text-center">
          <Gift size={36} className="mx-auto mb-3 text-gray-200" />
          <p className="text-gray-400 font-semibold">No benefit records found</p>
        </div>
      ) : (
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Employee</th>
                  <th>Type</th>
                  <th>Amount</th>
                  <th>Note</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(item => {
                  const tc = TYPE_CONFIG[item.type] || TYPE_CONFIG['Bonus'];
                  const Icon = tc.icon;
                  return (
                    <tr key={item.id}>
                      <td className="text-gray-500 text-sm">{fmtDate(item.date)}</td>
                      <td>
                        <div className="flex items-center gap-2">
                          <div className="w-7 h-7 rounded-lg flex items-center justify-center text-white text-xs font-black shrink-0"
                            style={{ background: tc.color }}>
                            {(item.employee || '?').charAt(0).toUpperCase()}
                          </div>
                          <span className="font-semibold text-gray-900 text-sm">{item.employee || '—'}</span>
                        </div>
                      </td>
                      <td>
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-bold border"
                          style={{ background: tc.bg, color: tc.text, borderColor: tc.border }}>
                          <Icon size={10} />
                          {item.type}
                        </span>
                      </td>
                      <td className="font-black" style={{ color: BRAND }}>৳{fmt(item.amount)}</td>
                      <td className="text-gray-500 text-sm max-w-xs truncate">{item.note || '—'}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <div className="px-4 py-3 border-t border-gray-100 bg-gray-50 flex justify-between items-center rounded-b-xl">
            <span className="text-xs text-gray-500 font-semibold">{filtered.length} records</span>
            <span className="font-black text-sm" style={{ color: BRAND }}>
              Total: ৳{fmt(filtered.reduce((s, i) => s + (i.amount || 0), 0))}
            </span>
          </div>
        </div>
      )}

      {/* Add modal */}
      {showAdd && (
        <BenefitModal onSave={handleAdd} onClose={() => setShowAdd(false)} />
      )}
    </div>
  );
}

function BenefitModal({ onSave, onClose }) {
  const [form, setForm] = useState({
    employee: '',
    type:     'Bonus',
    amount:   '',
    note:     '',
    date:     new Date().toISOString().slice(0, 10),
  });
  const [saving, setSaving] = useState(false);

  function set(k, v) { setForm(p => ({ ...p, [k]: v })); }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.employee.trim() || !form.amount) return;
    setSaving(true);
    try {
      await onSave({
        employee: form.employee,
        type:     form.type,
        amount:   parseFloat(form.amount) || 0,
        note:     form.note,
        date:     new Date(form.date),
      });
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h3 className="font-black text-gray-900">Add Benefit</h3>
          <button onClick={onClose} className="btn-icon"><X size={16} /></button>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="label">Employee Name / ID *</label>
            <input className="input" value={form.employee} onChange={e => set('employee', e.target.value)} required />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Type</label>
              <select className="input" value={form.type} onChange={e => set('type', e.target.value)}>
                {['Bonus', 'Incentive', 'Allowance'].map(t => <option key={t}>{t}</option>)}
              </select>
            </div>
            <div>
              <label className="label">Amount (৳) *</label>
              <input type="number" min="0" className="input" value={form.amount} onChange={e => set('amount', e.target.value)} required />
            </div>
          </div>
          <div>
            <label className="label">Date</label>
            <input type="date" className="input" value={form.date} onChange={e => set('date', e.target.value)} />
          </div>
          <div>
            <label className="label">Note</label>
            <textarea rows={2} className="input resize-none" value={form.note} onChange={e => set('note', e.target.value)} />
          </div>
          <div className="flex gap-3 pt-2">
            <button type="submit" disabled={saving || !form.employee.trim() || !form.amount} className="btn-primary flex-1 disabled:opacity-50">
              {saving ? <Loader2 size={14} className="animate-spin" /> : null}
              {saving ? 'Saving…' : 'Add Benefit'}
            </button>
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}
