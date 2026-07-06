import { useEffect, useState } from 'react';
import { Loader2, BookOpen, Plus, Edit2, X } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, update, remove, orderBy } from '../lib/db';
import { formatCurrency, formatDate } from '../lib/utils';
import { Modal } from '../components/ui/Modal';

export function BudgetPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';
  const [budgets, setBudgets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal]     = useState(null);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'budgets'), (docs) => { setBudgets(docs); setLoading(false); }, [orderBy('createdAt', 'desc')]);
    return unsub;
  }, [cid]);

  const totalBudget = budgets.reduce((s, b) => s + (b.amount || b.totalBudget || 0), 0);
  const totalSpent  = budgets.reduce((s, b) => s + (b.spent || b.usedAmount || 0), 0);
  const remaining   = totalBudget - totalSpent;

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div><h2 className="page-title">Budget</h2><p className="page-sub">Financial planning & allocation</p></div>
        <button onClick={() => setModal('add')} className="btn-primary"><Plus size={16} /> Add Budget</button>
      </div>
      <div className="grid grid-cols-3 gap-4">
        <div className="stat-card"><div className="stat-icon bg-purple-50 text-purple-600"><BookOpen size={20} /></div><div><p className="stat-label">Total Budget</p><p className="stat-value text-xl">{formatCurrency(totalBudget)}</p></div></div>
        <div className="stat-card"><div className="stat-icon bg-red-50 text-red-600"><BookOpen size={20} /></div><div><p className="stat-label">Spent</p><p className="stat-value text-xl">{formatCurrency(totalSpent)}</p></div></div>
        <div className="stat-card"><div className="stat-icon bg-green-50 text-green-600"><BookOpen size={20} /></div><div><p className="stat-label">Remaining</p><p className="stat-value text-xl">{formatCurrency(remaining)}</p></div></div>
      </div>
      {loading ? <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div> : (
        <div className="space-y-3">
          {budgets.length === 0 ? (
            <div className="empty-state card-p"><div className="empty-state-icon"><BookOpen size={24} /></div><p className="font-semibold text-gray-700">No budget entries</p></div>
          ) : budgets.map(b => {
            const total = b.amount || b.totalBudget || 0;
            const spent = b.spent || b.usedAmount || 0;
            const pct   = total > 0 ? Math.min(100, Math.round((spent / total) * 100)) : 0;
            return (
              <div key={b.id} className="card p-5">
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="font-bold text-gray-900">{b.title || b.category || b.name || 'Budget'}</h3>
                      <span className="badge badge-gray">{b.period || b.year || '—'}</span>
                    </div>
                    <div className="flex items-center gap-4 text-sm text-gray-500 mb-3">
                      <span>Budget: <strong className="text-gray-900">{formatCurrency(total)}</strong></span>
                      <span>Spent: <strong className="text-red-600">{formatCurrency(spent)}</strong></span>
                      <span>Remaining: <strong className="text-green-600">{formatCurrency(total - spent)}</strong></span>
                    </div>
                    <div className="w-full bg-gray-100 rounded-full h-2">
                      <div className={`h-2 rounded-full transition-all ${pct > 90 ? 'bg-red-500' : pct > 70 ? 'bg-yellow-500' : 'bg-[#065F46]/50'}`} style={{ width: `${pct}%` }} />
                    </div>
                    <p className="text-xs text-gray-400 mt-1">{pct}% used</p>
                  </div>
                  <div className="flex gap-1 shrink-0">
                    <button onClick={() => setModal(b)} className="btn-icon btn-sm"><Edit2 size={13} /></button>
                    <button onClick={() => remove(cid, 'budgets', b.id)} className="btn-icon btn-sm text-red-400 hover:text-red-600"><X size={13} /></button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
      {modal && <BudgetModal budget={modal === 'add' ? null : modal} cid={cid} onClose={() => setModal(null)} />}
    </div>
  );
}

function BudgetModal({ budget, cid, onClose }) {
  const isEdit = !!budget;
  const [form, setForm] = useState({ title: budget?.title || budget?.category || '', amount: budget?.amount || budget?.totalBudget || '', spent: budget?.spent || budget?.usedAmount || '', period: budget?.period || new Date().getFullYear().toString(), notes: budget?.notes || '' });
  const [saving, setSaving] = useState(false);
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));
  async function handleSave() {
    setSaving(true);
    try {
      const data = { ...form, amount: parseFloat(form.amount) || 0, spent: parseFloat(form.spent) || 0 };
      if (isEdit) await update(cid, 'budgets', budget.id, data);
      else await add(col(cid, 'budgets'), data);
      onClose();
    } catch (e) { alert(e.message); } finally { setSaving(false); }
  }
  return (
    <Modal title={isEdit ? 'Edit Budget' : 'Add Budget'} onClose={onClose}>
      <div className="space-y-3">
        <div><label className="label">Title / Category *</label><input className="input" value={form.title} onChange={(e) => set('title', e.target.value)} /></div>
        <div><label className="label">Total Budget (BDT) *</label><input className="input" type="number" value={form.amount} onChange={(e) => set('amount', e.target.value)} /></div>
        <div><label className="label">Amount Spent (BDT)</label><input className="input" type="number" value={form.spent} onChange={(e) => set('spent', e.target.value)} /></div>
        <div><label className="label">Period (e.g. 2025)</label><input className="input" value={form.period} onChange={(e) => set('period', e.target.value)} /></div>
        <div><label className="label">Notes</label><textarea className="input" rows={2} value={form.notes} onChange={(e) => set('notes', e.target.value)} /></div>
      </div>
      <div className="flex justify-end gap-3 mt-5">
        <button onClick={onClose} className="btn-secondary">Cancel</button>
        <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? <Loader2 size={14} className="animate-spin" /> : null}{saving ? 'Saving…' : 'Save'}</button>
      </div>
    </Modal>
  );
}
