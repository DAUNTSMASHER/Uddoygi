// ExpensesPage — shows cash_out entries from cash_flow (single source of truth,
// same as BalancePage). Manual "Add Expense" writes to both cash_flow and expenses.
import { useEffect, useState, useMemo } from 'react';
import {
  Plus, Search, X, Loader2, TrendingDown, Tag, Building2,
  Calendar, ChevronDown, Undo2,
} from 'lucide-react';
import { doc, writeBatch, serverTimestamp, collection } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, orderBy, where, increment } from '../lib/db';
import { formatCurrency, formatDate } from '../lib/utils';
import { Modal } from '../components/ui/Modal';

const BRAND    = '#065F46';
const CASH_OUT = '#DC2626';

const CATEGORIES   = ['Rent', 'Utilities', 'Payroll', 'Supplies', 'Maintenance', 'Transport', 'Marketing', 'Other'];
const COST_CENTERS = ['HR', 'Factory', 'Marketing', 'Accounts', 'R&D', 'General'];

function n(v) {
  if (v == null) return 0;
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return parseFloat(v.replace(/,/g, '')) || 0;
  return 0;
}

export function ExpensesPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [cashFlow, setCashFlow] = useState([]);
  const [loading,  setLoading]  = useState(true);
  const [search,   setSearch]   = useState('');
  const [catFilter, setCatFilter] = useState('all');
  const [modal,    setModal]    = useState(null);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(
      col(cid, 'cash_flow'),
      (docs) => { setCashFlow(docs); setLoading(false); },
      [orderBy('createdAt', 'desc')],
    );
    return unsub;
  }, [cid]);

  // Only cash_out entries (reversals are audit-only — excluded)
  const expenses = useMemo(() =>
    cashFlow.filter(d => d.type === 'cash_out')
  , [cashFlow]);

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return expenses.filter(e => {
      const matchSearch = !q ||
        (e.description || e.item || e.vendor || '').toLowerCase().includes(q) ||
        (e.category || '').toLowerCase().includes(q) ||
        (e.employeeName || '').toLowerCase().includes(q);
      const matchCat = catFilter === 'all' || (e.category || '').toLowerCase() === catFilter.toLowerCase();
      return matchSearch && matchCat;
    });
  }, [expenses, search, catFilter]);

  const totalExpense = useMemo(() => expenses.reduce((s, e) => s + n(e.amount), 0), [expenses]);

  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const thisMonth  = useMemo(() =>
    expenses.filter(e => {
      const ts = e.createdAt;
      if (!ts) return false;
      const dt = ts?.toDate ? ts.toDate() : new Date((ts.seconds || 0) * 1000);
      return dt >= monthStart;
    }).reduce((s, e) => s + n(e.amount), 0)
  , [expenses]);

  // Category breakdown
  const byCategory = useMemo(() => {
    const map = {};
    expenses.forEach(e => {
      const k = e.category || 'Other';
      map[k] = (map[k] || 0) + n(e.amount);
    });
    return Object.entries(map).sort((a, b) => b[1] - a[1]);
  }, [expenses]);

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="page-header">
        <div>
          <h2 className="page-title">Expenses</h2>
          <p className="page-sub">{expenses.length} cash-out entries · same data as Balance sheet</p>
        </div>
        <button onClick={() => setModal('add')} className="btn-primary">
          <Plus size={16} /> Add Expense
        </button>
      </div>

      {/* KPI strip */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="stat-card">
          <div className="stat-icon bg-red-50 text-red-600"><TrendingDown size={20} /></div>
          <div>
            <p className="stat-label">Total Expenses</p>
            <p className="stat-value text-xl" style={{ color: CASH_OUT }}>{formatCurrency(totalExpense)}</p>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-orange-50 text-orange-600"><Calendar size={20} /></div>
          <div>
            <p className="stat-label">This Month</p>
            <p className="stat-value text-xl">{formatCurrency(thisMonth)}</p>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-gray-50 text-gray-500"><Tag size={20} /></div>
          <div>
            <p className="stat-label">Categories</p>
            <p className="stat-value text-xl">{byCategory.length}</p>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-blue-50 text-blue-600"><Building2 size={20} /></div>
          <div>
            <p className="stat-label">Records</p>
            <p className="stat-value text-xl">{expenses.length}</p>
          </div>
        </div>
      </div>

      {/* Category breakdown pills */}
      {byCategory.length > 0 && (
        <div className="card p-4">
          <p className="text-xs font-bold text-gray-500 uppercase tracking-wide mb-3">By Category</p>
          <div className="flex flex-wrap gap-2">
            {byCategory.map(([cat, amt]) => (
              <button
                key={cat}
                onClick={() => setCatFilter(catFilter === cat.toLowerCase() ? 'all' : cat.toLowerCase())}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-bold transition border ${
                  catFilter === cat.toLowerCase()
                    ? 'bg-[#065F46] text-white border-[#065F46]'
                    : 'bg-white text-gray-600 border-gray-200 hover:border-[#065F46] hover:text-[#065F46]'
                }`}
              >
                {cat}
                <span className={`${catFilter === cat.toLowerCase() ? 'text-white/70' : 'text-gray-400'}`}>
                  {formatCurrency(amt)}
                </span>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Search + filter */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[200px] max-w-sm">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            className="input pl-9"
            placeholder="Search description, category…"
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
          {search && (
            <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400">
              <X size={14} />
            </button>
          )}
        </div>
        <select className="input w-auto text-sm" value={catFilter} onChange={e => setCatFilter(e.target.value)}>
          <option value="all">All Categories</option>
          {CATEGORIES.map(c => <option key={c} value={c.toLowerCase()}>{c}</option>)}
        </select>
        {(search || catFilter !== 'all') && (
          <button
            onClick={() => { setSearch(''); setCatFilter('all'); }}
            className="text-xs text-gray-400 hover:text-gray-600 flex items-center gap-1"
          >
            <X size={12} /> Clear
          </button>
        )}
      </div>

      {/* Table */}
      {loading ? (
        <div className="flex justify-center py-16">
          <Loader2 size={24} className="animate-spin" style={{ color: BRAND }} />
        </div>
      ) : (
        <div className="card">
          <div className="table-wrap border-0 rounded-none">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Description</th>
                  <th>Category</th>
                  <th>Department</th>
                  <th>Employee</th>
                  <th>Amount</th>
                  <th>Source</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="text-center py-12 text-gray-400">
                      <TrendingDown size={28} className="mx-auto mb-2 text-gray-200" />
                      No expense entries found
                    </td>
                  </tr>
                ) : filtered.map(e => (
                  <tr key={e.id}>
                    <td className="text-gray-500 text-xs whitespace-nowrap">{formatDate(e.createdAt || e.date)}</td>
                    <td className="font-medium text-gray-900 max-w-[200px] truncate">
                      {e.description || e.item || e.vendor || '—'}
                    </td>
                    <td>
                      {e.category ? (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-gray-100 text-gray-600">
                          {e.category}
                        </span>
                      ) : '—'}
                    </td>
                    <td className="text-gray-500 text-sm">{e.department || e.costCenter || '—'}</td>
                    <td className="text-gray-500 text-sm">{e.employeeName || '—'}</td>
                    <td>
                      <span className="font-bold text-sm" style={{ color: CASH_OUT }}>
                        -{formatCurrency(n(e.amount))}
                      </span>
                    </td>
                    <td>
                      <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-bold ${
                        e._payrollDocId
                          ? 'bg-emerald-50 text-emerald-700'
                          : 'bg-gray-100 text-gray-600'
                      }`}>
                        {e._payrollDocId ? 'Payroll' : 'Manual'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {/* Footer total */}
          <div className="px-4 py-3 border-t border-gray-100 flex items-center justify-between bg-gray-50 rounded-b-xl">
            <span className="text-xs font-semibold text-gray-500">
              {filtered.length} of {expenses.length} entries
            </span>
            <span className="text-sm font-black" style={{ color: CASH_OUT }}>
              Total: -{formatCurrency(filtered.reduce((s, e) => s + n(e.amount), 0))}
            </span>
          </div>
        </div>
      )}

      {modal && (
        <AddExpenseModal
          cid={cid}
          session={session}
          onClose={() => setModal(null)}
        />
      )}
    </div>
  );
}

// ── Add Expense Modal ─────────────────────────────────────────────────────────
// Writes to cash_flow (cash_out) so it shows up in Balance sheet immediately.
// Also writes to expenses collection for legacy compatibility.
function AddExpenseModal({ cid, session, onClose }) {
  const [form, setForm] = useState({
    description: '',
    amount:      '',
    category:    'Other',
    costCenter:  'General',
    date:        new Date().toISOString().split('T')[0],
    notes:       '',
  });
  const [saving, setSaving] = useState(false);
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  async function handleSave() {
    if (!form.amount || parseFloat(form.amount) <= 0) {
      alert('Please enter a valid amount.');
      return;
    }
    setSaving(true);
    try {
      const amt     = parseFloat(form.amount) || 0;
      const hrEmail = session?.email || '';
      const batch   = writeBatch(db);

      // 1. Write to cash_flow as cash_out (shows in Balance sheet)
      const cfRef = doc(collection(db, 'data', cid, 'cash_flow'));
      batch.set(cfRef, {
        type:        'cash_out',
        amount:      amt,
        currency:    'BDT',
        description: form.description || form.category,
        category:    form.category,
        costCenter:  form.costCenter,
        notes:       form.notes,
        date:        serverTimestamp(),
        createdAt:   serverTimestamp(),
        approvedBy:  hrEmail,
        source:      'manual',
      });

      // 2. Also write to expenses collection (legacy / expense tracking)
      const expRef = doc(collection(db, 'data', cid, 'expenses'));
      batch.set(expRef, {
        description: form.description || form.category,
        amount:      amt,
        category:    form.category,
        costCenter:  form.costCenter,
        notes:       form.notes,
        date:        serverTimestamp(),
        createdAt:   serverTimestamp(),
        addedBy:     hrEmail,
        status:      'paid',
        source:      'manual',
      });

      // 3. Increment company_profile cashOut
      const profileRef = doc(db, 'data', cid, 'company_profile', 'main');
      batch.update(profileRef, {
        cashOut:   increment(amt),
        updatedAt: serverTimestamp(),
      });

      await batch.commit();
      onClose();
    } catch (e) {
      alert('Failed to save: ' + e.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal title="Add Expense" onClose={onClose}>
      <div className="space-y-3">
        <div>
          <label className="label">Description</label>
          <input
            className="input"
            placeholder="e.g. Office rent, Utility bill…"
            value={form.description}
            onChange={e => set('description', e.target.value)}
          />
        </div>
        <div>
          <label className="label">Amount (BDT) *</label>
          <input
            className="input"
            type="number"
            min="0"
            placeholder="0"
            value={form.amount}
            onChange={e => set('amount', e.target.value)}
          />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label">Category</label>
            <select className="input" value={form.category} onChange={e => set('category', e.target.value)}>
              {CATEGORIES.map(c => <option key={c}>{c}</option>)}
            </select>
          </div>
          <div>
            <label className="label">Cost Center</label>
            <select className="input" value={form.costCenter} onChange={e => set('costCenter', e.target.value)}>
              {COST_CENTERS.map(c => <option key={c}>{c}</option>)}
            </select>
          </div>
        </div>
        <div>
          <label className="label">Notes</label>
          <textarea
            className="input"
            rows={2}
            value={form.notes}
            onChange={e => set('notes', e.target.value)}
          />
        </div>
      </div>
      <div className="flex justify-end gap-3 mt-5">
        <button onClick={onClose} className="btn-secondary">Cancel</button>
        <button onClick={handleSave} disabled={saving} className="btn-primary">
          {saving ? <Loader2 size={14} className="animate-spin" /> : <Plus size={14} />}
          {saving ? 'Saving…' : 'Add Expense'}
        </button>
      </div>
    </Modal>
  );
}
