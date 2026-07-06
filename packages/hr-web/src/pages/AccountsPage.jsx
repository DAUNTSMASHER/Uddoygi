import { useEffect, useState } from 'react';
import { Loader2, Building2, Plus, Edit2, X } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, update, remove, orderBy } from '../lib/db';
import { formatCurrency, formatDate } from '../lib/utils';
import { Modal } from '../components/ui/Modal';

export function AccountsPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';
  const [accounts, setAccounts] = useState([]);
  const [loading, setLoading]   = useState(true);
  const [modal, setModal]       = useState(null);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'moneySources'), (docs) => { setAccounts(docs); setLoading(false); }, [orderBy('createdAt', 'desc')]);
    return unsub;
  }, [cid]);

  const totalBalance = accounts.reduce((s, a) => s + (a.balance || a.currentBalance || 0), 0);

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div><h2 className="page-title">Company Accounts</h2><p className="page-sub">Manage bank accounts, bKash, Nagad</p></div>
        <button onClick={() => setModal('add')} className="btn-primary"><Plus size={16} /> Add Account</button>
      </div>
      <div className="stat-card max-w-xs">
        <div className="stat-icon bg-green-50 text-green-600"><Building2 size={20} /></div>
        <div><p className="stat-label">Total Balance</p><p className="stat-value text-xl">{formatCurrency(totalBalance)}</p></div>
      </div>
      {loading ? <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div> : (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {accounts.length === 0 ? (
            <div className="col-span-3 empty-state card-p"><div className="empty-state-icon"><Building2 size={24} /></div><p className="font-semibold text-gray-700">No accounts added</p></div>
          ) : accounts.map(a => (
            <div key={a.id} className="card p-5 hover:shadow-card-md transition-shadow">
              <div className="flex items-start justify-between gap-2 mb-3">
                <div className={`w-10 h-10 rounded-xl flex items-center justify-center text-white text-xs font-bold shrink-0 ${
                  (a.type || '').toLowerCase() === 'bkash' ? 'bg-pink-600' :
                  (a.type || '').toLowerCase() === 'nagad' ? 'bg-orange-500' :
                  'bg-blue-600'
                }`}>
                  {(a.type || 'BK').slice(0, 2).toUpperCase()}
                </div>
                <div className="flex gap-1">
                  <button onClick={() => setModal(a)} className="btn-icon btn-sm"><Edit2 size={13} /></button>
                  <button onClick={() => remove(cid, 'moneySources', a.id)} className="btn-icon btn-sm text-red-400 hover:text-red-600"><X size={13} /></button>
                </div>
              </div>
              <h3 className="font-bold text-gray-900">{a.name || a.accountName || '—'}</h3>
              <p className="text-sm text-gray-500 mt-0.5">{a.type || '—'} · {a.accountNumber || a.number || '—'}</p>
              {a.bankName && <p className="text-xs text-gray-400 mt-0.5">{a.bankName}</p>}
              <p className="text-xl font-black text-gray-900 mt-3">{formatCurrency(a.balance || a.currentBalance || 0)}</p>
              <p className="text-xs text-gray-400 mt-0.5">Updated {formatDate(a.updatedAt || a.createdAt)}</p>
            </div>
          ))}
        </div>
      )}
      {modal && <AccountModal account={modal === 'add' ? null : modal} cid={cid} onClose={() => setModal(null)} />}
    </div>
  );
}

function AccountModal({ account, cid, onClose }) {
  const isEdit = !!account;
  const [form, setForm] = useState({ name: account?.name || account?.accountName || '', type: account?.type || 'Bank', accountNumber: account?.accountNumber || account?.number || '', bankName: account?.bankName || '', balance: account?.balance || account?.currentBalance || '', notes: account?.notes || '' });
  const [saving, setSaving] = useState(false);
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));
  async function handleSave() {
    setSaving(true);
    try {
      const data = { ...form, balance: parseFloat(form.balance) || 0 };
      if (isEdit) await update(cid, 'moneySources', account.id, data);
      else await add(col(cid, 'moneySources'), data);
      onClose();
    } catch (e) { alert(e.message); } finally { setSaving(false); }
  }
  return (
    <Modal title={isEdit ? 'Edit Account' : 'Add Account'} onClose={onClose}>
      <div className="space-y-3">
        <div><label className="label">Account Name *</label><input className="input" value={form.name} onChange={(e) => set('name', e.target.value)} placeholder="e.g. Main bKash, Payroll Bank" /></div>
        <div><label className="label">Type</label>
          <select className="input" value={form.type} onChange={(e) => set('type', e.target.value)}>
            {['Bank', 'bKash', 'Nagad', 'Rocket', 'Cash', 'Other'].map(t => <option key={t}>{t}</option>)}
          </select>
        </div>
        <div><label className="label">Account Number</label><input className="input" value={form.accountNumber} onChange={(e) => set('accountNumber', e.target.value)} /></div>
        {form.type === 'Bank' && <div><label className="label">Bank Name</label><input className="input" value={form.bankName} onChange={(e) => set('bankName', e.target.value)} /></div>}
        <div><label className="label">Current Balance (BDT)</label><input className="input" type="number" value={form.balance} onChange={(e) => set('balance', e.target.value)} /></div>
        <div><label className="label">Notes</label><textarea className="input" rows={2} value={form.notes} onChange={(e) => set('notes', e.target.value)} /></div>
      </div>
      <div className="flex justify-end gap-3 mt-5">
        <button onClick={onClose} className="btn-secondary">Cancel</button>
        <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? <Loader2 size={14} className="animate-spin" /> : null}{saving ? 'Saving…' : 'Save'}</button>
      </div>
    </Modal>
  );
}
