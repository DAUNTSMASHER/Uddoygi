// BudgetForecastPage.jsx — Budget Forecast
// Mirrors Flutter budget_forecast_screen.dart (BudgetForecastScreen)
// Collection: budget (under data/{cid}/budget)
// Fields: category, amount (forecast), used, year, date

import { useEffect, useState, useMemo } from 'react';
import {
  Target, TrendingUp, BarChart2, Plus, X, Loader2,
  Edit2, Trash2, Download,
} from 'lucide-react';
import {
  collection, onSnapshot, addDoc, updateDoc, deleteDoc,
  doc, serverTimestamp, query, where,
} from 'firebase/firestore';
import { db } from '../lib/db';
import { useAuth } from '../context/AuthContext';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

const BRAND = '#065F46';

function fmt(v) {
  return new Intl.NumberFormat('en-BD', { minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(v || 0);
}

export function BudgetForecastPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const now = new Date();
  const [selYear, setSelYear] = useState(now.getFullYear());
  const [items,   setItems]   = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAdd, setShowAdd] = useState(false);
  const [editDoc, setEditDoc] = useState(null);

  const years = useMemo(() => {
    const cur = now.getFullYear();
    return Array.from({ length: 6 }, (_, i) => cur - 4 + i);
  }, []);

  useEffect(() => {
    if (!cid) return;
    const q = query(
      collection(db, 'data', cid, 'budget'),
      where('year', '==', selYear),
    );
    const unsub = onSnapshot(q, snap => {
      const docs = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setItems(docs);
      setLoading(false);
    });
    return unsub;
  }, [cid, selYear]);

  const totals = useMemo(() => ({
    forecasted: items.reduce((s, i) => s + (i.amount || 0), 0),
    used:       items.reduce((s, i) => s + (i.used || 0), 0),
  }), [items]);

  async function handleAdd(data) {
    if (!cid) return;
    await addDoc(collection(db, 'data', cid, 'budget'), {
      ...data,
      year:      selYear,
      used:      0,
      date:      new Date(selYear, 0, 1),
      createdAt: serverTimestamp(),
    });
    setShowAdd(false);
  }

  async function handleEdit(item, newAmount) {
    if (!cid) return;
    await updateDoc(doc(db, 'data', cid, 'budget', item.id), {
      amount:    parseFloat(newAmount) || 0,
      updatedAt: serverTimestamp(),
    });
    setEditDoc(null);
  }

  async function handleDelete(id) {
    if (!cid || !window.confirm('Delete this forecast entry?')) return;
    await deleteDoc(doc(db, 'data', cid, 'budget', id));
  }

  function handleExportPDF() {
    const doc = new jsPDF({ unit: 'mm', format: 'a4' });
    doc.setFontSize(16);
    doc.text(`Budget Forecast — ${selYear}`, 14, 16);
    doc.setFontSize(10);
    doc.text(`Generated: ${new Date().toLocaleDateString()}`, 14, 23);
    autoTable(doc, {
      startY: 28,
      head: [['Category', 'Forecast (৳)', 'Used (৳)', 'Remaining (৳)', 'Usage %']],
      body: items.map(i => {
        const remaining = (i.amount || 0) - (i.used || 0);
        const pct = i.amount > 0 ? ((i.used || 0) / i.amount * 100).toFixed(1) : '0.0';
        return [i.category || '—', fmt(i.amount), fmt(i.used), fmt(remaining), `${pct}%`];
      }),
      styles: { fontSize: 9 },
      headStyles: { fillColor: [6, 95, 70] },
      foot: [['Total', fmt(totals.forecasted), fmt(totals.used),
        fmt(totals.forecasted - totals.used),
        totals.forecasted > 0 ? `${(totals.used / totals.forecasted * 100).toFixed(1)}%` : '0.0%']],
      footStyles: { fillColor: [240, 253, 244], textColor: [22, 101, 52], fontStyle: 'bold' },
    });
    doc.save(`Budget_Forecast_${selYear}.pdf`);
  }

  if (loading) {
    return (
      <div className="flex justify-center items-center py-32">
        <Loader2 size={28} className="animate-spin" style={{ color: BRAND }} />
      </div>
    );
  }

  const usagePct = totals.forecasted > 0 ? (totals.used / totals.forecasted) * 100 : 0;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="page-header">
        <div>
          <h2 className="page-title">Budget Forecast</h2>
          <p className="page-sub">Plan and track budget allocations by category</p>
        </div>
        <div className="flex gap-2">
          <button onClick={handleExportPDF} className="btn-secondary">
            <Download size={15} /> PDF
          </button>
          <button onClick={() => setShowAdd(true)} className="btn-primary">
            <Plus size={15} /> Add Forecast
          </button>
        </div>
      </div>

      {/* Year selector */}
      <div className="flex items-center gap-3">
        <label className="text-sm font-bold text-gray-600">Year:</label>
        <select
          className="input w-28"
          value={selYear}
          onChange={e => { setSelYear(+e.target.value); setLoading(true); }}
        >
          {years.map(y => <option key={y}>{y}</option>)}
        </select>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="card p-4 flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0 bg-blue-50">
            <Target size={20} className="text-blue-600" />
          </div>
          <div>
            <p className="text-xs text-gray-400 font-semibold">Total Forecasted</p>
            <p className="text-xl font-black text-gray-900">৳{fmt(totals.forecasted)}</p>
          </div>
        </div>
        <div className="card p-4 flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0 bg-orange-50">
            <TrendingUp size={20} className="text-orange-600" />
          </div>
          <div>
            <p className="text-xs text-gray-400 font-semibold">Total Used</p>
            <p className="text-xl font-black text-gray-900">৳{fmt(totals.used)}</p>
          </div>
        </div>
        <div className="card p-4 flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0 bg-green-50">
            <BarChart2 size={20} className="text-green-600" />
          </div>
          <div>
            <p className="text-xs text-gray-400 font-semibold">Remaining</p>
            <p className="text-xl font-black" style={{ color: BRAND }}>
              ৳{fmt(totals.forecasted - totals.used)}
            </p>
          </div>
        </div>
      </div>

      {/* Overall usage bar */}
      {totals.forecasted > 0 && (
        <div className="card p-4">
          <div className="flex justify-between items-center mb-2">
            <p className="text-sm font-bold text-gray-700">Overall Budget Usage</p>
            <p className="text-sm font-black" style={{ color: usagePct > 80 ? '#EF4444' : BRAND }}>
              {usagePct.toFixed(1)}%
            </p>
          </div>
          <div className="w-full bg-gray-100 rounded-full h-3">
            <div
              className="h-3 rounded-full transition-all duration-500"
              style={{
                width: `${Math.min(100, usagePct)}%`,
                background: usagePct > 80 ? '#EF4444' : usagePct > 60 ? '#F59E0B' : BRAND,
              }}
            />
          </div>
          <div className="flex justify-between mt-1 text-xs text-gray-400">
            <span>৳0</span>
            <span>৳{fmt(totals.forecasted)}</span>
          </div>
        </div>
      )}

      {/* Bar chart */}
      {items.length > 0 && (
        <div className="card p-4">
          <p className="text-sm font-bold text-gray-700 mb-4">Category Breakdown</p>
          <div className="space-y-3">
            {items.map(item => {
              const pct = item.amount > 0 ? Math.min(100, ((item.used || 0) / item.amount) * 100) : 0;
              const remaining = (item.amount || 0) - (item.used || 0);
              return (
                <div key={item.id}>
                  <div className="flex justify-between items-center mb-1">
                    <p className="text-sm font-semibold text-gray-800">{item.category}</p>
                    <div className="flex items-center gap-3 text-xs">
                      <span className="text-blue-600 font-bold">৳{fmt(item.amount)} forecast</span>
                      <span className="text-orange-600 font-bold">৳{fmt(item.used || 0)} used</span>
                    </div>
                  </div>
                  <div className="relative w-full bg-gray-100 rounded-full h-4">
                    <div
                      className="h-4 rounded-full transition-all duration-500"
                      style={{
                        width: `${pct}%`,
                        background: pct > 80 ? '#EF4444' : pct > 60 ? '#F59E0B' : '#3B82F6',
                      }}
                    />
                    <div
                      className="absolute inset-0 rounded-full opacity-20"
                      style={{ background: BRAND }}
                    />
                  </div>
                  <p className="text-xs text-gray-400 mt-0.5">
                    {pct.toFixed(1)}% used · ৳{fmt(remaining)} remaining
                  </p>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Table */}
      {items.length === 0 ? (
        <div className="card p-12 text-center">
          <BarChart2 size={36} className="mx-auto mb-3 text-gray-200" />
          <p className="text-gray-400 font-semibold">No forecast entries for {selYear}</p>
          <p className="text-gray-300 text-sm mt-1">Click "Add Forecast" to get started</p>
        </div>
      ) : (
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Category</th>
                  <th>Forecast (৳)</th>
                  <th>Used (৳)</th>
                  <th>Remaining (৳)</th>
                  <th>Usage</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {items.map(item => {
                  const remaining = (item.amount || 0) - (item.used || 0);
                  const pct = item.amount > 0 ? ((item.used || 0) / item.amount * 100) : 0;
                  return (
                    <tr key={item.id}>
                      <td className="font-semibold text-gray-900">{item.category || '—'}</td>
                      <td className="font-bold text-blue-700">৳{fmt(item.amount)}</td>
                      <td className="font-bold text-orange-600">৳{fmt(item.used || 0)}</td>
                      <td className="font-bold" style={{ color: remaining >= 0 ? BRAND : '#EF4444' }}>
                        ৳{fmt(remaining)}
                      </td>
                      <td>
                        <div className="flex items-center gap-2">
                          <div className="w-16 bg-gray-100 rounded-full h-2">
                            <div
                              className="h-2 rounded-full"
                              style={{
                                width: `${Math.min(100, pct)}%`,
                                background: pct > 80 ? '#EF4444' : pct > 60 ? '#F59E0B' : BRAND,
                              }}
                            />
                          </div>
                          <span className="text-xs font-bold text-gray-600">{pct.toFixed(0)}%</span>
                        </div>
                      </td>
                      <td>
                        <div className="flex gap-1">
                          <button
                            onClick={() => setEditDoc(item)}
                            className="p-1.5 rounded-lg hover:bg-blue-50 text-blue-500 transition"
                            title="Edit forecast amount"
                          >
                            <Edit2 size={14} />
                          </button>
                          <button
                            onClick={() => handleDelete(item.id)}
                            className="p-1.5 rounded-lg hover:bg-red-50 text-red-500 transition"
                            title="Delete"
                          >
                            <Trash2 size={14} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
              <tfoot>
                <tr className="bg-gray-50 font-black">
                  <td className="text-gray-700">Total</td>
                  <td className="text-blue-700">৳{fmt(totals.forecasted)}</td>
                  <td className="text-orange-600">৳{fmt(totals.used)}</td>
                  <td style={{ color: totals.forecasted - totals.used >= 0 ? BRAND : '#EF4444' }}>
                    ৳{fmt(totals.forecasted - totals.used)}
                  </td>
                  <td className="text-gray-600">
                    {totals.forecasted > 0 ? `${(totals.used / totals.forecasted * 100).toFixed(1)}%` : '0%'}
                  </td>
                  <td />
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      )}

      {/* Add modal */}
      {showAdd && (
        <ForecastModal onSave={handleAdd} onClose={() => setShowAdd(false)} year={selYear} />
      )}

      {/* Edit modal */}
      {editDoc && (
        <EditForecastModal item={editDoc} onSave={handleEdit} onClose={() => setEditDoc(null)} />
      )}
    </div>
  );
}

function ForecastModal({ onSave, onClose, year }) {
  const [form, setForm] = useState({ category: '', amount: '' });
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.category.trim() || !form.amount) return;
    setSaving(true);
    try {
      await onSave({ category: form.category, amount: parseFloat(form.amount) || 0 });
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h3 className="font-black text-gray-900">Add Forecast — {year}</h3>
          <button onClick={onClose} className="btn-icon"><X size={16} /></button>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="label">Category *</label>
            <input
              className="input"
              placeholder="e.g. Marketing, Operations…"
              value={form.category}
              onChange={e => setForm(p => ({ ...p, category: e.target.value }))}
              required
            />
          </div>
          <div>
            <label className="label">Forecast Amount (৳) *</label>
            <input
              type="number"
              min="0"
              className="input"
              value={form.amount}
              onChange={e => setForm(p => ({ ...p, amount: e.target.value }))}
              required
            />
          </div>
          <div className="flex gap-3 pt-2">
            <button
              type="submit"
              disabled={saving || !form.category.trim() || !form.amount}
              className="btn-primary flex-1 disabled:opacity-50"
            >
              {saving ? <Loader2 size={14} className="animate-spin" /> : null}
              {saving ? 'Saving…' : 'Add Forecast'}
            </button>
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}

function EditForecastModal({ item, onSave, onClose }) {
  const [amount, setAmount] = useState(String(item.amount || ''));
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setSaving(true);
    try {
      await onSave(item, amount);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <div>
            <h3 className="font-black text-gray-900">Edit Forecast</h3>
            <p className="text-xs text-gray-400 mt-0.5">{item.category}</p>
          </div>
          <button onClick={onClose} className="btn-icon"><X size={16} /></button>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="label">Forecast Amount (৳)</label>
            <input
              type="number"
              min="0"
              className="input"
              value={amount}
              onChange={e => setAmount(e.target.value)}
              required
            />
          </div>
          <div className="flex gap-3 pt-2">
            <button type="submit" disabled={saving} className="btn-primary flex-1 disabled:opacity-50">
              {saving ? <Loader2 size={14} className="animate-spin" /> : null}
              {saving ? 'Saving…' : 'Update'}
            </button>
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}
