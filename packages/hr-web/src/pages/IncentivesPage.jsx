// IncentivesPage.jsx — Incentive Dashboard
// Mirrors Flutter incentives_screen.dart + hr_incentive_calculator_screen.dart
//   + incentive_history_screen.dart + admin_overview_dashboard_screen.dart
//
// Three tabs:
//   1. Overview    — month/year filter, agent summary table (total sale, products, incentive)
//   2. Calculator  — select sales report → edit qty/price/cost → compute & submit incentives
//   3. History     — list of processed incentive records with breakdown dialog
//
// Firestore collection: marketingIncentives
//   Doc ID pattern: {email}_{month}_{year}_sales
//   Fields: rows[], totalIncentive, timestamp
//   Row fields: productName, quantity, sellingPrice, purchaseCost, fixedCost, netProfit, incentive

import { useEffect, useState, useMemo } from 'react';
import {
  Calculator, History, BarChart2, ChevronDown, ChevronUp,
  Loader2, Search, X, Check, Upload, Eye, DollarSign,
  TrendingUp, Users, Package,
} from 'lucide-react';
import { doc, updateDoc } from 'firebase/firestore';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, orderBy, db } from '../lib/db';
import { formatDate } from '../lib/utils';

const BRAND   = '#065F46';
const DARK    = '#2A0A4B';
const MONTHS  = ['January','February','March','April','May','June','July','August','September','October','November','December'];

function n(v) {
  if (v == null) return 0;
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return parseFloat(v.replace(/,/g, '')) || 0;
  return 0;
}
function fmt(v) {
  return new Intl.NumberFormat('en-BD', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(v || 0);
}

// Parse doc ID: {email}_{month}_{year}_sales  →  { email, month, year }
function parseDocId(id) {
  const withoutSuffix = id.replace(/_sales$/, '');
  const parts = withoutSuffix.split('_');
  if (parts.length < 3) return { email: id, month: '', year: '' };
  const year  = parts[parts.length - 1];
  const month = parts[parts.length - 2];
  const email = parts.slice(0, parts.length - 2).join('_');
  return { email, month, year };
}

const TABS = [
  { id: 'overview',   label: 'Overview',   icon: BarChart2 },
  { id: 'calculator', label: 'Calculator', icon: Calculator },
  { id: 'history',    label: 'History',    icon: History },
];

export function IncentivesPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';
  const [tab, setTab] = useState('overview');
  const [docs, setDocs] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'marketingIncentives'), d => {
      setDocs(d);
      setLoading(false);
    });
    return unsub;
  }, [cid]);

  // Only docs with _sales in ID
  const salesDocs = useMemo(() => docs.filter(d => (d.id || '').includes('_sales')), [docs]);

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="page-header">
        <div>
          <h2 className="page-title">Incentive Dashboard</h2>
          <p className="page-sub">Calculate, track and review marketing incentives</p>
        </div>
      </div>

      {/* Tab bar */}
      <div className="flex gap-1 p-1 bg-gray-100 rounded-xl w-fit">
        {TABS.map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-bold transition ${
              tab === t.id
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            <t.icon size={15} />
            {t.label}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex justify-center py-20">
          <Loader2 size={24} className="animate-spin" style={{ color: BRAND }} />
        </div>
      ) : (
        <>
          {tab === 'overview'   && <OverviewTab   salesDocs={salesDocs} />}
          {tab === 'calculator' && <CalculatorTab salesDocs={salesDocs} cid={cid} />}
          {tab === 'history'    && <HistoryTab    salesDocs={salesDocs} />}
        </>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: Overview — agent summary table with month/year filter
// ─────────────────────────────────────────────────────────────────────────────
function OverviewTab({ salesDocs }) {
  const now = new Date();
  const [selMonth, setSelMonth] = useState(now.getMonth() + 1); // 1-based
  const [selYear,  setSelYear]  = useState(now.getFullYear());

  const filtered = useMemo(() => {
    return salesDocs.filter(d => {
      const { month, year } = parseDocId(d.id);
      const mNum = parseInt(month) || (MONTHS.indexOf(month) + 1);
      const yNum = parseInt(year);
      return mNum === selMonth && yNum === selYear;
    });
  }, [salesDocs, selMonth, selYear]);

  const totals = useMemo(() => {
    let totalSale = 0, totalQty = 0, totalIncentive = 0;
    filtered.forEach(d => {
      const rows = d.rows || [];
      rows.forEach(r => {
        totalSale += n(r.quantity) * n(r.sellingPrice);
        totalQty  += n(r.quantity);
      });
      totalIncentive += n(d.totalIncentive);
    });
    return { totalSale, totalQty, totalIncentive };
  }, [filtered]);

  const years = useMemo(() => {
    const y = new Set(salesDocs.map(d => parseInt(parseDocId(d.id).year)).filter(Boolean));
    const cur = new Date().getFullYear();
    for (let i = cur - 2; i <= cur + 1; i++) y.add(i);
    return [...y].sort();
  }, [salesDocs]);

  return (
    <div className="space-y-4">
      {/* KPI strip */}
      <div className="grid grid-cols-3 gap-4">
        <div className="stat-card">
          <div className="stat-icon bg-green-50 text-green-600"><TrendingUp size={20} /></div>
          <div><p className="stat-label">Total Sale</p><p className="stat-value">৳{fmt(totals.totalSale)}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-blue-50 text-blue-600"><Package size={20} /></div>
          <div><p className="stat-label">Total Products</p><p className="stat-value">{totals.totalQty}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-purple-50 text-purple-600"><DollarSign size={20} /></div>
          <div><p className="stat-label">Total Incentive</p><p className="stat-value">৳{fmt(totals.totalIncentive)}</p></div>
        </div>
      </div>

      {/* Filters */}
      <div className="flex gap-3 items-center flex-wrap">
        <select className="input w-36" value={selMonth} onChange={e => setSelMonth(+e.target.value)}>
          {MONTHS.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
        </select>
        <select className="input w-24" value={selYear} onChange={e => setSelYear(+e.target.value)}>
          {years.map(y => <option key={y}>{y}</option>)}
        </select>
      </div>

      {/* Table */}
      <div className="card">
        <div className="table-wrap border-0 rounded-none">
          <table className="data-table">
            <thead>
              <tr>
                <th>S/N</th>
                <th>Agent Email</th>
                <th>Total Sale</th>
                <th>Total Products</th>
                <th>Total Incentive</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr><td colSpan={6} className="text-center py-10 text-gray-400">No data for {MONTHS[selMonth - 1]} {selYear}</td></tr>
              ) : filtered.map((d, i) => {
                const { email } = parseDocId(d.id);
                const rows = d.rows || [];
                let sale = 0, qty = 0;
                rows.forEach(r => { sale += n(r.quantity) * n(r.sellingPrice); qty += n(r.quantity); });
                return (
                  <tr key={d.id}>
                    <td className="text-gray-400">{i + 1}</td>
                    <td className="font-medium text-gray-900">{email}</td>
                    <td className="font-bold text-green-700">৳{fmt(sale)}</td>
                    <td>{qty}</td>
                    <td className="font-bold" style={{ color: BRAND }}>৳{fmt(n(d.totalIncentive))}</td>
                    <td>
                      <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-bold ${
                        d.totalIncentive != null
                          ? 'bg-green-50 text-green-700'
                          : 'bg-yellow-50 text-yellow-700'
                      }`}>
                        {d.totalIncentive != null ? <><Check size={10} /> Calculated</> : 'Pending'}
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        {filtered.length > 0 && (
          <div className="px-4 py-3 border-t border-gray-100 flex justify-between bg-gray-50 rounded-b-xl text-sm font-black">
            <span className="text-gray-500">Total ({filtered.length} agents)</span>
            <span className="flex gap-6">
              <span style={{ color: BRAND }}>Sale: ৳{fmt(totals.totalSale)}</span>
              <span style={{ color: '#7C3AED' }}>Incentive: ৳{fmt(totals.totalIncentive)}</span>
            </span>
          </div>
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: Calculator — select report, edit rows, compute & submit
// ─────────────────────────────────────────────────────────────────────────────
function CalculatorTab({ salesDocs, cid }) {
  const [selectedId,    setSelectedId]    = useState('');
  const [rows,          setRows]          = useState([]);
  const [rate,          setRate]          = useState(0.15);
  const [saving,        setSaving]        = useState(false);
  const [saved,         setSaved]         = useState(false);

  const selectedDoc = useMemo(() => salesDocs.find(d => d.id === selectedId), [salesDocs, selectedId]);

  function loadReport(id) {
    setSelectedId(id);
    setSaved(false);
    const d = salesDocs.find(x => x.id === id);
    if (!d) { setRows([]); return; }
    setRows((d.rows || []).map(r => ({
      product:     r.productName || '',
      quantity:    n(r.quantity),
      unitPrice:   n(r.sellingPrice),
      productCost: n(r.purchaseCost),
      fixedCost:   n(r.fixedCost),
    })));
  }

  function updateRow(i, field, val) {
    setRows(prev => prev.map((r, idx) => idx === i ? { ...r, [field]: parseFloat(val) || 0 } : r));
    setSaved(false);
  }

  // Compute derived values for each row
  const computed = useMemo(() => rows.map(r => {
    const totalPrice = r.quantity * r.unitPrice;
    const prodCost   = r.quantity * r.productCost;
    const profit     = totalPrice - prodCost;
    const netProfit  = profit * ((100 - r.fixedCost) / 100);
    const incentive  = netProfit * rate;
    return { totalPrice, prodCost, profit, netProfit, incentive };
  }), [rows, rate]);

  const totals = useMemo(() => ({
    sales:     computed.reduce((s, r) => s + r.totalPrice, 0),
    incentive: computed.reduce((s, r) => s + r.incentive, 0),
  }), [computed]);

  async function handleSubmit() {
    if (!selectedId) return;
    setSaving(true);
    try {
      const updatedRows = rows.map((r, i) => ({
        productName:  r.product,
        quantity:     r.quantity,
        sellingPrice: r.unitPrice,
        purchaseCost: r.productCost,
        fixedCost:    r.fixedCost,
        netProfit:    computed[i].netProfit,
        incentive:    computed[i].incentive,
      }));
      await updateDoc(doc(db, 'data', cid, 'marketingIncentives', selectedId), {
        rows:           updatedRows,
        totalIncentive: totals.incentive,
      });
      setSaved(true);
    } catch (e) {
      alert('Submit failed: ' + e.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="space-y-4">
      {/* Controls */}
      <div className="card p-4 flex flex-wrap gap-4 items-end">
        <div className="flex-1 min-w-[200px]">
          <label className="label">Select Sales Report</label>
          <select className="input" value={selectedId} onChange={e => loadReport(e.target.value)}>
            <option value="">— Choose a report —</option>
            {salesDocs.map(d => {
              const { email, month, year } = parseDocId(d.id);
              const label = d.totalIncentive != null
                ? `${email} · ${month} ${year} (৳${fmt(n(d.totalIncentive))})`
                : `${email} · ${month} ${year} (Pending)`;
              return <option key={d.id} value={d.id}>{label}</option>;
            })}
          </select>
        </div>
        <div className="w-40">
          <label className="label">Incentive Rate (e.g. 0.15)</label>
          <input
            type="number"
            step="0.01"
            min="0"
            max="1"
            className="input"
            value={rate}
            onChange={e => setRate(parseFloat(e.target.value) || 0.15)}
          />
        </div>
      </div>

      {/* Data table */}
      {rows.length === 0 ? (
        <div className="card p-12 text-center">
          <Calculator size={36} className="mx-auto mb-3 text-gray-200" />
          <p className="text-gray-400 font-semibold">Select a sales report to start calculating</p>
        </div>
      ) : (
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="data-table min-w-[900px]">
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Qty</th>
                  <th>Unit Price</th>
                  <th>Total Price</th>
                  <th>Unit Cost</th>
                  <th>Prod. Cost</th>
                  <th>Profit</th>
                  <th>Fixed Cost %</th>
                  <th>Net Profit</th>
                  <th>Incentive</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r, i) => {
                  const c = computed[i];
                  return (
                    <tr key={i}>
                      <td className="font-medium text-gray-900">{r.product}</td>
                      <td>
                        <input type="number" className="input w-20 py-1 text-sm" value={r.quantity}
                          onChange={e => updateRow(i, 'quantity', e.target.value)} />
                      </td>
                      <td>
                        <input type="number" className="input w-24 py-1 text-sm" value={r.unitPrice}
                          onChange={e => updateRow(i, 'unitPrice', e.target.value)} />
                      </td>
                      <td className="font-semibold text-gray-700">৳{fmt(c.totalPrice)}</td>
                      <td>
                        <input type="number" className="input w-24 py-1 text-sm" value={r.productCost}
                          onChange={e => updateRow(i, 'productCost', e.target.value)} />
                      </td>
                      <td className="text-gray-600">৳{fmt(c.prodCost)}</td>
                      <td className="font-semibold" style={{ color: c.profit >= 0 ? '#16A34A' : '#DC2626' }}>
                        ৳{fmt(c.profit)}
                      </td>
                      <td>
                        <input type="number" className="input w-20 py-1 text-sm" value={r.fixedCost}
                          onChange={e => updateRow(i, 'fixedCost', e.target.value)} />
                      </td>
                      <td className="font-semibold text-blue-700">৳{fmt(c.netProfit)}</td>
                      <td className="font-black" style={{ color: BRAND }}>৳{fmt(c.incentive)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Footer */}
          <div className="px-4 py-3 border-t border-gray-100 flex items-center justify-between bg-gray-50">
            <div className="flex gap-6 text-sm font-bold">
              <span className="text-gray-600">Total Sales: <span className="text-gray-900">৳{fmt(totals.sales)}</span></span>
              <span style={{ color: BRAND }}>Total Incentive: ৳{fmt(totals.incentive)}</span>
            </div>
            <button
              onClick={handleSubmit}
              disabled={saving || !selectedId}
              className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-black text-white transition disabled:opacity-50"
              style={{ background: saved ? '#16A34A' : BRAND }}
            >
              {saving ? <Loader2 size={14} className="animate-spin" /> : saved ? <Check size={14} /> : <Upload size={14} />}
              {saving ? 'Submitting…' : saved ? 'Submitted!' : 'Submit & Save'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3: History — list of processed records with breakdown dialog
// ─────────────────────────────────────────────────────────────────────────────
function HistoryTab({ salesDocs }) {
  const [search,    setSearch]    = useState('');
  const [breakdown, setBreakdown] = useState(null); // doc data for dialog

  const processed = useMemo(() =>
    salesDocs.filter(d => d.totalIncentive != null)
  , [salesDocs]);

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    if (!q) return processed;
    return processed.filter(d => {
      const { email, month, year } = parseDocId(d.id);
      return email.toLowerCase().includes(q) || month.toLowerCase().includes(q) || year.includes(q);
    });
  }, [processed, search]);

  return (
    <div className="space-y-4">
      {/* Search */}
      <div className="relative max-w-sm">
        <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input className="input pl-9" placeholder="Search agent, month…" value={search} onChange={e => setSearch(e.target.value)} />
        {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={13} /></button>}
      </div>

      {/* List */}
      {filtered.length === 0 ? (
        <div className="card p-12 text-center">
          <History size={36} className="mx-auto mb-3 text-gray-200" />
          <p className="text-gray-400 font-semibold">No incentive records found</p>
        </div>
      ) : (
        <div className="space-y-2">
          {filtered.map(d => {
            const { email, month, year } = parseDocId(d.id);
            const ts = d.timestamp || d.createdAt;
            return (
              <div key={d.id} className="card p-4 flex items-center gap-4">
                <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
                  style={{ background: BRAND + '15' }}>
                  <DollarSign size={18} style={{ color: BRAND }} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-bold text-gray-900 text-sm truncate">{email}</p>
                  <p className="text-xs text-gray-400 mt-0.5">
                    {month} {year} · {ts ? formatDate(ts) : '—'}
                  </p>
                </div>
                <div className="text-right shrink-0">
                  <p className="font-black text-sm" style={{ color: BRAND }}>৳{fmt(n(d.totalIncentive))}</p>
                  <p className="text-[10px] text-gray-400">Total Incentive</p>
                </div>
                <button
                  onClick={() => setBreakdown(d)}
                  className="btn-icon btn-sm"
                  title="View breakdown"
                >
                  <Eye size={14} />
                </button>
              </div>
            );
          })}
        </div>
      )}

      {/* Breakdown dialog */}
      {breakdown && (
        <BreakdownDialog data={breakdown} onClose={() => setBreakdown(null)} />
      )}
    </div>
  );
}

function BreakdownDialog({ data, onClose }) {
  const { email, month, year } = parseDocId(data.id);
  const rows = data.rows || [];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <div>
            <h3 className="font-black text-gray-900">Incentive Breakdown</h3>
            <p className="text-xs text-gray-400 mt-0.5">{email} · {month} {year}</p>
          </div>
          <button onClick={onClose} className="btn-icon"><X size={16} /></button>
        </div>
        <div className="overflow-auto flex-1 p-4">
          <table className="data-table min-w-[700px]">
            <thead>
              <tr>
                <th>Product</th>
                <th>Qty</th>
                <th>Unit Price</th>
                <th>Unit Cost</th>
                <th>Profit</th>
                <th>Net Profit</th>
                <th>Incentive</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r, i) => {
                const profit = (n(r.sellingPrice) - n(r.purchaseCost)) * n(r.quantity);
                return (
                  <tr key={i}>
                    <td className="font-medium text-gray-900">{r.productName || '—'}</td>
                    <td>{n(r.quantity)}</td>
                    <td>৳{fmt(n(r.sellingPrice))}</td>
                    <td>৳{fmt(n(r.purchaseCost))}</td>
                    <td className="font-semibold" style={{ color: profit >= 0 ? '#16A34A' : '#DC2626' }}>৳{fmt(profit)}</td>
                    <td className="text-blue-700 font-semibold">৳{fmt(n(r.netProfit))}</td>
                    <td className="font-black" style={{ color: BRAND }}>৳{fmt(n(r.incentive))}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <div className="px-6 py-4 border-t border-gray-100 flex justify-between items-center bg-gray-50 rounded-b-2xl">
          <span className="text-sm font-black" style={{ color: BRAND }}>
            Total Incentive: ৳{fmt(n(data.totalIncentive))}
          </span>
          <button onClick={onClose} className="btn-secondary">Close</button>
        </div>
      </div>
    </div>
  );
}
