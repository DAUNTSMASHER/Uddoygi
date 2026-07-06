// CreditsPage — shows cash_in entries from cash_flow (single source of truth,
// same as BalancePage Credits tab). Adding a credit writes to cash_flow as cash_in.
import { useEffect, useState, useMemo } from 'react';
import {
  Plus, Search, X, Loader2, CreditCard, TrendingUp,
  Calendar, Tag, ArrowDownLeft,
} from 'lucide-react';
import { doc, writeBatch, serverTimestamp, collection } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, orderBy, increment } from '../lib/db';
import { formatCurrency, formatDate } from '../lib/utils';
import { Modal } from '../components/ui/Modal';

const BRAND   = '#065F46';
const CASH_IN = '#16A34A';

const SOURCE_LABELS = {
  slip:       'Slip Approval',
  payslip:    'Payslip',
  manual:     'Manual',
  ledger:     'Ledger',
};

function n(v) {
  if (v == null) return 0;
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return parseFloat(v.replace(/,/g, '')) || 0;
  return 0;
}

export function CreditsPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [cashFlow, setCashFlow] = useState([]);
  const [loading,  setLoading]  = useState(true);
  const [search,   setSearch]   = useState('');
  const [modal,    setModal]    = useState(false);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(
      col(cid, 'cash_flow'),
      (docs) => { setCashFlow(docs); setLoading(false); },
      [orderBy('createdAt', 'desc')],
    );
    return unsub;
  }, [cid]);

  // Only cash_in entries
  const credits = useMemo(() =>
    cashFlow.filter(d => d.type === 'cash_in')
  , [cashFlow]);

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    if (!q) return credits;
    return credits.filter(e =>
      (e.description || e.note || e.narration || '').toLowerCase().includes(q) ||
      (e.source || '').toLowerCase().includes(q) ||
      (e.category || '').toLowerCase().includes(q) ||
      (e.reference || e.transactionId || '').toLowerCase().includes(q)
    );
  }, [credits, search]);

  const totalCredits = useMemo(() => credits.reduce((s, e) => s + n(e.amount), 0), [credits]);

  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const thisMonth  = useMemo(() =>
    credits.filter(e => {
      const ts = e.createdAt;
      if (!ts) return false;
      const dt = ts?.toDate ? ts.toDate() : new Date((ts.seconds || 0) * 1000);
      return dt >= monthStart;
    }).reduce((s, e) => s + n(e.amount), 0)
  , [credits]);

  // Source breakdown
  const slipCredits   = useMemo(() =>
    credits.filter(e => e.source === 'slip' || e.category === 'slip').reduce((s, e) => s + n(e.amount), 0)
  , [credits]);
  const manualCredits = useMemo(() =>
    credits.filter(e => !e.source || e.source === 'manual').reduce((s, e) => s + n(e.amount), 0)
  , [credits]);

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="page-header">
        <div>
          <h2 className="page-title">Credits & Cash In</h2>
          <p className="page-sub">{credits.length} cash-in entries · same data as Balance sheet</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary">
          <Plus size={16} /> Add Credit
        </button>
      </div>

      {/* KPI strip */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="stat-card">
          <div className="stat-icon bg-green-50 text-green-600"><TrendingUp size={20} /></div>
          <div>
            <p className="stat-label">Total Credits</p>
            <p className="stat-value text-xl" style={{ color: CASH_IN }}>{formatCurrency(totalCredits)}</p>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-emerald-50 text-emerald-600"><Calendar size={20} /></div>
          <div>
            <p className="stat-label">This Month</p>
            <p className="stat-value text-xl">{formatCurrency(thisMonth)}</p>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-blue-50 text-blue-600"><CreditCard size={20} /></div>
          <div>
            <p className="stat-label">From Slips</p>
            <p className="stat-value text-xl">{formatCurrency(slipCredits)}</p>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-purple-50 text-purple-600"><Tag size={20} /></div>
          <div>
            <p className="stat-label">Manual</p>
            <p className="stat-value text-xl">{formatCurrency(manualCredits)}</p>
          </div>
        </div>
      </div>

      {/* Search */}
      <div className="flex items-center gap-3">
        <div className="relative flex-1 min-w-[200px] max-w-sm">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            className="input pl-9"
            placeholder="Search description, source…"
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
          {search && (
            <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400">
              <X size={14} />
            </button>
          )}
        </div>
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
                  <th>Source</th>
                  <th>Description</th>
                  <th>Reference</th>
                  <th>Currency</th>
                  <th>Amount</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="text-center py-12 text-gray-400">
                      <ArrowDownLeft size={28} className="mx-auto mb-2 text-gray-200" />
                      No credit entries yet
                    </td>
                  </tr>
                ) : filtered.map(e => (
                  <tr key={e.id}>
                    <td className="text-gray-500 text-xs whitespace-nowrap">{formatDate(e.createdAt || e.date)}</td>
                    <td>
                      <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold ${
                        e.source === 'slip' || e.category === 'slip'
                          ? 'bg-blue-50 text-blue-700'
                          : 'bg-purple-50 text-purple-700'
                      }`}>
                        {SOURCE_LABELS[e.source] || SOURCE_LABELS[e.category] || 'Manual'}
                      </span>
                    </td>
                    <td className="font-medium text-gray-900 max-w-[220px] truncate">
                      {e.description || e.note || e.narration || '—'}
                    </td>
                    <td className="text-gray-400 font-mono text-xs">
                      {e.reference || e.transactionId || e.invoiceNo || '—'}
                    </td>
                    <td className="text-gray-500 text-xs">{e.currency || 'BDT'}</td>
                    <td>
                      <span className="font-bold text-sm" style={{ color: CASH_IN }}>
                        +{formatCurrency(n(e.amount))}
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
              {filtered.length} of {credits.length} entries
            </span>
            <span className="text-sm font-black" style={{ color: CASH_IN }}>
              Total: +{formatCurrency(filtered.reduce((s, e) => s + n(e.amount), 0))}
            </span>
          </div>
        </div>
      )}

      {modal && (
        <AddCreditModal
          cid={cid}
          session={session}
          onClose={() => setModal(false)}
        />
      )}
    </div>
  );
}

// ── Add Credit Modal ──────────────────────────────────────────────────────────
// Writes to cash_flow as cash_in so it shows up in Balance sheet immediately.
function AddCreditModal({ cid, session, onClose }) {
  const [form, setForm] = useState({
    description: '',
    amount:      '',
    reference:   '',
    note:        '',
    currency:    'BDT',
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

      // Write to cash_flow as cash_in (shows in Balance sheet)
      const cfRef = doc(collection(db, 'data', cid, 'cash_flow'));
      batch.set(cfRef, {
        type:        'cash_in',
        amount:      amt,
        currency:    form.currency || 'BDT',
        description: form.description,
        reference:   form.reference,
        note:        form.note,
        source:      'manual',
        approvedBy:  hrEmail,
        createdAt:   serverTimestamp(),
        date:        serverTimestamp(),
      });

      // Increment company_profile cashIn
      const profileRef = doc(db, 'data', cid, 'company_profile', 'main');
      batch.update(profileRef, {
        cashIn:    increment(amt),
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
    <Modal title="Add Manual Credit" onClose={onClose}>
      <div className="space-y-3">
        <div>
          <label className="label">Amount *</label>
          <div className="flex gap-2">
            <input
              className="input flex-1"
              type="number"
              min="0"
              placeholder="0"
              value={form.amount}
              onChange={e => set('amount', e.target.value)}
            />
            <select className="input w-24" value={form.currency} onChange={e => set('currency', e.target.value)}>
              <option>BDT</option>
              <option>USD</option>
              <option>EUR</option>
            </select>
          </div>
        </div>
        <div>
          <label className="label">Description</label>
          <input
            className="input"
            placeholder="e.g. Client payment, Invoice #123…"
            value={form.description}
            onChange={e => set('description', e.target.value)}
          />
        </div>
        <div>
          <label className="label">Reference / Transaction ID</label>
          <input
            className="input"
            placeholder="Optional"
            value={form.reference}
            onChange={e => set('reference', e.target.value)}
          />
        </div>
        <div>
          <label className="label">Notes</label>
          <textarea
            className="input"
            rows={2}
            value={form.note}
            onChange={e => set('note', e.target.value)}
          />
        </div>
      </div>
      <div className="flex justify-end gap-3 mt-5">
        <button onClick={onClose} className="btn-secondary">Cancel</button>
        <button onClick={handleSave} disabled={saving} className="btn-primary">
          {saving ? <Loader2 size={14} className="animate-spin" /> : <Plus size={14} />}
          {saving ? 'Saving…' : 'Add Credit'}
        </button>
      </div>
    </Modal>
  );
}
