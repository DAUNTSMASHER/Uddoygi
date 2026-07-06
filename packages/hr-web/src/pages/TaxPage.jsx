// Bangladesh HR Tax Management — Web ERP
// Tabs: TDS/Employee · Challan · Annual Filing · TIN Registry · Slab Calculator
import { useEffect, useState, useCallback } from 'react';
import {
  Loader2, Plus, Trash2, Edit2, CheckCircle, Clock, AlertTriangle,
  Calculator, FileText, Receipt, Fingerprint, ChevronRight,
  Copy, Check, Info, Building2, Calendar, User, Hash,
} from 'lucide-react';
import { serverTimestamp } from 'firebase/firestore';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, update, remove, orderBy } from '../lib/db';
import { formatDate } from '../lib/utils';

// ── BD FY 2024-25 slab calculator ────────────────────────────────────────────
const THRESHOLDS = {
  Male:              350000,
  Female:            400000,
  'Senior (65+)':    400000,
  Disabled:          475000,
  'Freedom Fighter': 500000,
};
const SLABS      = [100000, 400000, 500000, 500000];
const SLAB_RATES = [0.05,   0.10,   0.15,   0.20];

function computeTax(grossIncome, category = 'Male') {
  const threshold = THRESHOLDS[category] ?? 350000;
  if (grossIncome <= threshold) return { tax: 0, taxable: 0, lines: [], threshold };
  let taxable = grossIncome - threshold;
  let tax = 0;
  const lines = [];
  for (let i = 0; i < SLABS.length; i++) {
    if (taxable <= 0) break;
    const chunk = Math.min(taxable, SLABS[i]);
    const t = chunk * SLAB_RATES[i];
    lines.push({ label: `Slab ${i+1}: ৳${(SLABS[i]/100000).toFixed(1)}L @ ${SLAB_RATES[i]*100}%`, income: chunk, tax: t });
    tax += t;
    taxable -= chunk;
  }
  if (taxable > 0) {
    const t = taxable * 0.25;
    lines.push({ label: 'Remaining @ 25%', income: taxable, tax: t });
    tax += t;
  }
  return { tax, taxable: grossIncome - threshold, lines, threshold };
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function tk(n) {
  if (n == null || isNaN(n)) return '—';
  if (Math.abs(n) >= 10_000_000) return `৳${(n/10_000_000).toFixed(1)}Cr`;
  if (Math.abs(n) >= 100_000)    return `৳${(n/100_000).toFixed(1)}L`;
  if (Math.abs(n) >= 1_000)      return `৳${(n/1_000).toFixed(1)}K`;
  return `৳${Math.round(n).toLocaleString('en-IN')}`;
}

function tkFull(n) {
  if (n == null || isNaN(n)) return '—';
  return `৳${Math.round(n).toLocaleString('en-IN')}`;
}

const STATUS_CLS = {
  pending:    'bg-amber-50 text-amber-700 border-amber-200',
  paid:       'bg-emerald-50 text-emerald-700 border-emerald-200',
  deducted:   'bg-emerald-50 text-emerald-700 border-emerald-200',
  submitted:  'bg-blue-50 text-blue-700 border-blue-200',
  overdue:    'bg-red-50 text-red-700 border-red-200',
  registered: 'bg-teal-50 text-teal-700 border-teal-200',
};

function Badge({ status }) {
  const s = (status || 'pending').toLowerCase();
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold border ${STATUS_CLS[s] || STATUS_CLS.pending}`}>
      {status || 'pending'}
    </span>
  );
}

function StatCard({ label, value, sub, icon: Icon, cls }) {
  return (
    <div className={`rounded-2xl p-4 flex items-center gap-3 ${cls}`}>
      <div className="w-10 h-10 rounded-xl bg-white/30 flex items-center justify-center shrink-0">
        <Icon size={18} className="text-white" />
      </div>
      <div>
        <p className="text-white/70 text-[10px] font-semibold uppercase tracking-wide">{label}</p>
        <p className="text-white text-xl font-black leading-none">{value}</p>
        {sub && <p className="text-white/60 text-[11px] mt-0.5">{sub}</p>}
      </div>
    </div>
  );
}

function SectionHead({ title, link }) {
  return (
    <div className="flex items-center gap-2 mb-4">
      <span className="w-1 h-4 rounded-full bg-[#0B3552] inline-block" />
      <h3 className="text-[13px] font-bold text-[#0B3552]">{title}</h3>
      {link && <a href={link} target="_blank" rel="noreferrer" className="ml-auto text-[11px] text-[#0B3552] hover:underline flex items-center gap-1">NBR <ChevronRight size={10} /></a>}
    </div>
  );
}

// ── Main page ─────────────────────────────────────────────────────────────────
const TABS = [
  { id: 'tds',      label: 'TDS / Employee', icon: Receipt },
  { id: 'challan',  label: 'Challan',        icon: FileText },
  { id: 'filing',   label: 'Annual Filing',  icon: CheckCircle },
  { id: 'tin',      label: 'TIN Registry',   icon: Fingerprint },
  { id: 'calc',     label: 'Slab Calculator',icon: Calculator },
];

export function TaxPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';
  const [tab, setTab] = useState('tds');

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h2 className="text-xl font-black text-gray-900">Tax Management</h2>
          <p className="text-xs text-gray-500 mt-0.5">Bangladesh NBR — FY 2024-25 compliance</p>
        </div>
        <a href="https://nbr.gov.bd" target="_blank" rel="noreferrer"
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[#0B3552]/10 text-[#0B3552] text-xs font-semibold hover:bg-[#0B3552]/20 transition">
          <Building2 size={13} /> NBR Portal
        </a>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-2xl overflow-x-auto">
        {TABS.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-[12px] font-semibold whitespace-nowrap transition-all
              ${tab === t.id ? 'bg-white text-[#0B3552] shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}>
            <t.icon size={13} />
            {t.label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      {tab === 'tds'     && <TdsTab     cid={cid} />}
      {tab === 'challan' && <ChallanTab cid={cid} />}
      {tab === 'filing'  && <FilingTab  cid={cid} />}
      {tab === 'tin'     && <TinTab     cid={cid} />}
      {tab === 'calc'    && <CalcTab />}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TDS Tab
// ─────────────────────────────────────────────────────────────────────────────
function TdsTab({ cid }) {
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal]     = useState(null);
  const [search, setSearch]   = useState('');

  useEffect(() => {
    if (!cid) return;
    return subscribe(col(cid, 'taxes'), docs => {
      setRecords(docs.filter(d => d.category === 'tds'));
      setLoading(false);
    }, [orderBy('createdAt', 'desc')]);
  }, [cid]);

  const filtered = records.filter(r =>
    !search || (r.employeeName || '').toLowerCase().includes(search.toLowerCase()) ||
    (r.month || '').toLowerCase().includes(search.toLowerCase())
  );

  const totalTds = records.reduce((s, r) => s + (r.tdsAmount || 0), 0);
  const deducted = records.filter(r => r.status === 'deducted').length;
  const pending  = records.filter(r => r.status !== 'deducted').length;

  return (
    <div className="space-y-4">
      {/* Stats */}
      <div className="grid grid-cols-3 gap-3">
        <StatCard label="Total TDS"  value={tk(totalTds)} icon={Receipt}      cls="bg-gradient-to-br from-[#0B3552] to-[#1B5E8B]" />
        <StatCard label="Deducted"   value={deducted}     icon={CheckCircle}  cls="bg-gradient-to-br from-emerald-700 to-emerald-500" />
        <StatCard label="Pending"    value={pending}      icon={Clock}        cls="bg-gradient-to-br from-amber-600 to-amber-400" />
      </div>

      {/* Toolbar */}
      <div className="flex items-center gap-3 flex-wrap">
        <input value={search} onChange={e => setSearch(e.target.value)}
          placeholder="Search employee or month…"
          className="input flex-1 min-w-[180px] h-9 text-sm" />
        <button onClick={() => setModal('add')} className="btn-primary flex items-center gap-2 h-9">
          <Plus size={14} /> Add TDS Record
        </button>
      </div>

      {/* Table */}
      {loading ? <Loader /> : (
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="data-table">
              <thead><tr>
                <th>Employee</th><th>Month</th><th>Dept</th><th>TIN</th>
                <th className="text-right">Gross</th><th className="text-right">TDS</th>
                <th className="text-right">Net</th><th>Status</th><th></th>
              </tr></thead>
              <tbody>
                {filtered.length === 0
                  ? <tr><td colSpan={9} className="text-center py-10 text-gray-400">No TDS records</td></tr>
                  : filtered.map(r => (
                    <tr key={r.id}>
                      <td className="font-semibold text-gray-900">{r.employeeName || '—'}</td>
                      <td className="text-gray-500 text-xs">{r.month || '—'}</td>
                      <td className="text-gray-500 text-xs capitalize">{r.department || '—'}</td>
                      <td className="font-mono text-xs text-gray-500">{r.tin || '—'}</td>
                      <td className="text-right font-semibold text-gray-800">{tkFull(r.grossSalary)}</td>
                      <td className="text-right font-bold text-red-600">{tkFull(r.tdsAmount)}</td>
                      <td className="text-right font-bold text-emerald-700">{tkFull((r.grossSalary||0)-(r.tdsAmount||0))}</td>
                      <td><Badge status={r.status} /></td>
                      <td>
                        <div className="flex gap-1">
                          {r.status !== 'deducted' && (
                            <button onClick={() => update(cid, 'taxes', r.id, { status: 'deducted' })}
                              className="btn-icon btn-sm text-emerald-600 hover:text-emerald-700" title="Mark Deducted">
                              <CheckCircle size={13} />
                            </button>
                          )}
                          <button onClick={() => setModal(r)} className="btn-icon btn-sm"><Edit2 size={13} /></button>
                          <button onClick={() => remove(cid, 'taxes', r.id)} className="btn-icon btn-sm text-red-400 hover:text-red-600"><Trash2 size={13} /></button>
                        </div>
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
      {modal && <TdsModal record={modal === 'add' ? null : modal} cid={cid} onClose={() => setModal(null)} />}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Challan Tab
// ─────────────────────────────────────────────────────────────────────────────
function ChallanTab({ cid }) {
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal]     = useState(null);

  useEffect(() => {
    if (!cid) return;
    return subscribe(col(cid, 'taxes'), docs => {
      setRecords(docs.filter(d => d.category === 'challan'));
      setLoading(false);
    }, [orderBy('createdAt', 'desc')]);
  }, [cid]);

  const totalAmount = records.reduce((s, r) => s + (r.amount || 0), 0);
  const paid = records.filter(r => r.status === 'paid').length;

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-3 gap-3">
        <StatCard label="Total Deposited" value={tk(totalAmount)} icon={FileText}    cls="bg-gradient-to-br from-[#0B3552] to-[#1B5E8B]" />
        <StatCard label="Paid"            value={paid}            icon={CheckCircle} cls="bg-gradient-to-br from-emerald-700 to-emerald-500" />
        <StatCard label="Pending"         value={records.length - paid} icon={Clock} cls="bg-gradient-to-br from-amber-600 to-amber-400" />
      </div>

      <div className="bg-amber-50 border border-amber-200 rounded-xl px-4 py-3 flex items-start gap-3">
        <Info size={14} className="text-amber-600 mt-0.5 shrink-0" />
        <p className="text-xs text-amber-800 font-medium">
          Use NBR Treasury Challan (Form IT-10BB) for income tax deposits. Deposit at designated banks (Sonali, DBBL, BRAC, etc.) and record the challan number here.
        </p>
      </div>

      <div className="flex justify-end">
        <button onClick={() => setModal('add')} className="btn-primary flex items-center gap-2">
          <Plus size={14} /> Add Challan
        </button>
      </div>

      {loading ? <Loader /> : (
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="data-table">
              <thead><tr>
                <th>Challan No.</th><th>Tax Type</th><th>Tax Year</th>
                <th>Bank</th><th>Deposit Date</th>
                <th className="text-right">Amount</th><th>Status</th><th></th>
              </tr></thead>
              <tbody>
                {records.length === 0
                  ? <tr><td colSpan={8} className="text-center py-10 text-gray-400">No challans recorded</td></tr>
                  : records.map(r => (
                    <tr key={r.id}>
                      <td className="font-mono font-semibold text-[#0B3552]">{r.challanNo || '—'}</td>
                      <td>{r.taxType || '—'}</td>
                      <td>{r.taxYear || '—'}</td>
                      <td className="text-gray-500 text-xs">{r.bankName || '—'}</td>
                      <td className="text-gray-500 text-xs">{r.depositDate || '—'}</td>
                      <td className="text-right font-bold text-gray-900">{tkFull(r.amount)}</td>
                      <td><Badge status={r.status} /></td>
                      <td>
                        <div className="flex gap-1">
                          {r.status !== 'paid' && (
                            <button onClick={() => update(cid, 'taxes', r.id, { status: 'paid' })}
                              className="btn-icon btn-sm text-emerald-600" title="Mark Paid">
                              <CheckCircle size={13} />
                            </button>
                          )}
                          <button onClick={() => remove(cid, 'taxes', r.id)} className="btn-icon btn-sm text-red-400 hover:text-red-600"><Trash2 size={13} /></button>
                        </div>
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
      {modal && <ChallanModal record={modal === 'add' ? null : modal} cid={cid} onClose={() => setModal(null)} />}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Annual Filing Tab
// ─────────────────────────────────────────────────────────────────────────────
function FilingTab({ cid }) {
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal]     = useState(null);

  useEffect(() => {
    if (!cid) return;
    return subscribe(col(cid, 'taxes'), docs => {
      setRecords(docs.filter(d => d.category === 'filing'));
      setLoading(false);
    }, [orderBy('createdAt', 'desc')]);
  }, [cid]);

  const totalTax  = records.reduce((s, r) => s + (r.taxPayable || 0), 0);
  const submitted = records.filter(r => r.status === 'submitted').length;

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-3 gap-3">
        <StatCard label="Total Tax Payable" value={tk(totalTax)} icon={FileText}    cls="bg-gradient-to-br from-[#0B3552] to-[#1B5E8B]" />
        <StatCard label="Submitted"         value={submitted}   icon={CheckCircle} cls="bg-gradient-to-br from-emerald-700 to-emerald-500" />
        <StatCard label="Pending"           value={records.length - submitted} icon={Clock} cls="bg-gradient-to-br from-amber-600 to-amber-400" />
      </div>

      <div className="bg-blue-50 border border-blue-200 rounded-xl px-4 py-3 flex items-start gap-3">
        <Info size={14} className="text-blue-600 mt-0.5 shrink-0" />
        <div className="text-xs text-blue-800 font-medium space-y-0.5">
          <p><strong>NBR Deadline:</strong> 30 November each year for individual returns.</p>
          <p><strong>Forms:</strong> IT-11GA (salaried), IT-11UMA (business), IT-11CHA (company), IT-11GHA (others).</p>
          <p><strong>e-Filing:</strong> <a href="https://etaxnbr.gov.bd" target="_blank" rel="noreferrer" className="underline">etaxnbr.gov.bd</a></p>
        </div>
      </div>

      <div className="flex justify-end">
        <button onClick={() => setModal('add')} className="btn-primary flex items-center gap-2">
          <Plus size={14} /> Add Filing Record
        </button>
      </div>

      {loading ? <Loader /> : (
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="data-table">
              <thead><tr>
                <th>Employee / Entity</th><th>TIN</th><th>Tax Year</th><th>Form</th>
                <th className="text-right">Total Income</th><th className="text-right">Tax Payable</th>
                <th>Filed On</th><th>Ack No.</th><th>Status</th><th></th>
              </tr></thead>
              <tbody>
                {records.length === 0
                  ? <tr><td colSpan={10} className="text-center py-10 text-gray-400">No filing records</td></tr>
                  : records.map(r => (
                    <tr key={r.id}>
                      <td className="font-semibold text-gray-900">{r.employeeName || r.entityName || '—'}</td>
                      <td className="font-mono text-xs text-gray-500">{r.tin || '—'}</td>
                      <td>{r.taxYear || '—'}</td>
                      <td className="text-xs text-[#0B3552] font-semibold">{r.returnForm || '—'}</td>
                      <td className="text-right font-semibold text-gray-800">{tkFull(r.totalIncome)}</td>
                      <td className="text-right font-bold text-red-600">{tkFull(r.taxPayable)}</td>
                      <td className="text-gray-500 text-xs">{r.filingDate || '—'}</td>
                      <td className="font-mono text-xs text-gray-500">{r.acknowledgementNo || '—'}</td>
                      <td><Badge status={r.status} /></td>
                      <td>
                        <div className="flex gap-1">
                          {r.status !== 'submitted' && (
                            <button onClick={() => update(cid, 'taxes', r.id, { status: 'submitted' })}
                              className="btn-icon btn-sm text-emerald-600" title="Mark Submitted">
                              <CheckCircle size={13} />
                            </button>
                          )}
                          <button onClick={() => remove(cid, 'taxes', r.id)} className="btn-icon btn-sm text-red-400 hover:text-red-600"><Trash2 size={13} /></button>
                        </div>
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
      {modal && <FilingModal record={modal === 'add' ? null : modal} cid={cid} onClose={() => setModal(null)} />}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TIN Registry Tab
// ─────────────────────────────────────────────────────────────────────────────
function TinTab({ cid }) {
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal]     = useState(null);
  const [search, setSearch]   = useState('');
  const [copied, setCopied]   = useState(null);

  useEffect(() => {
    if (!cid) return;
    return subscribe(col(cid, 'taxes'), docs => {
      setRecords(docs.filter(d => d.category === 'tin'));
      setLoading(false);
    }, [orderBy('createdAt', 'desc')]);
  }, [cid]);

  const filtered = records.filter(r =>
    !search || (r.employeeName || '').toLowerCase().includes(search.toLowerCase()) ||
    (r.tin || '').includes(search)
  );

  function copyTin(tin, id) {
    navigator.clipboard.writeText(tin).then(() => {
      setCopied(id);
      setTimeout(() => setCopied(null), 2000);
    });
  }

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-3">
        <StatCard label="Total TINs"    value={records.length} icon={Fingerprint} cls="bg-gradient-to-br from-[#0B3552] to-[#1B5E8B]" />
        <StatCard label="Registered"    value={records.filter(r => r.tin).length} icon={CheckCircle} cls="bg-gradient-to-br from-teal-700 to-teal-500" />
      </div>

      <div className="flex items-center gap-3 flex-wrap">
        <input value={search} onChange={e => setSearch(e.target.value)}
          placeholder="Search name or TIN…"
          className="input flex-1 min-w-[180px] h-9 text-sm" />
        <button onClick={() => setModal('add')} className="btn-primary flex items-center gap-2 h-9">
          <Plus size={14} /> Register TIN
        </button>
      </div>

      {loading ? <Loader /> : (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {filtered.length === 0
            ? <div className="col-span-3 text-center py-10 text-gray-400 text-sm">No TIN records</div>
            : filtered.map(r => (
              <div key={r.id} className={`bg-white rounded-2xl border p-4 hover:shadow-md transition
                ${r.tin ? 'border-teal-200' : 'border-amber-200'}`}>
                <div className="flex items-start justify-between gap-2 mb-3">
                  <div className="flex items-center gap-2.5">
                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0
                      ${r.tin ? 'bg-teal-50' : 'bg-amber-50'}`}>
                      <Fingerprint size={18} className={r.tin ? 'text-teal-600' : 'text-amber-600'} />
                    </div>
                    <div>
                      <p className="font-bold text-[#0B3552] text-[13px] leading-tight">{r.employeeName || '—'}</p>
                      <p className="text-[11px] text-gray-400">{r.designation || r.department || '—'}</p>
                    </div>
                  </div>
                  <button onClick={() => remove(cid, 'taxes', r.id)} className="btn-icon btn-sm text-red-300 hover:text-red-500">
                    <Trash2 size={12} />
                  </button>
                </div>
                {r.tin ? (
                  <div className="flex items-center gap-2 bg-gray-50 rounded-xl px-3 py-2">
                    <span className="font-mono font-bold text-[#0B3552] text-sm tracking-widest flex-1">{r.tin}</span>
                    <button onClick={() => copyTin(r.tin, r.id)}
                      className="text-gray-400 hover:text-[#0B3552] transition">
                      {copied === r.id ? <Check size={13} className="text-emerald-600" /> : <Copy size={13} />}
                    </button>
                  </div>
                ) : (
                  <div className="flex items-center gap-2 bg-amber-50 rounded-xl px-3 py-2">
                    <AlertTriangle size={12} className="text-amber-500" />
                    <span className="text-xs text-amber-700 font-semibold">TIN not registered</span>
                  </div>
                )}
                {r.email && <p className="text-[11px] text-gray-400 mt-2">{r.email}</p>}
              </div>
            ))}
        </div>
      )}
      {modal && <TinModal record={modal === 'add' ? null : modal} cid={cid} onClose={() => setModal(null)} />}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Slab Calculator Tab
// ─────────────────────────────────────────────────────────────────────────────
function CalcTab() {
  const [category, setCategory] = useState('Male');
  const [income, setIncome] = useState({
    basic: '', hra: '', medical: '', conveyance: '', bonus: '', other: '',
  });
  const [result, setResult] = useState(null);
  const [copied, setCopied] = useState(false);

  const set = (k, v) => setIncome(f => ({ ...f, [k]: v }));
  const n = (k) => parseFloat(income[k]) || 0;

  const totalGross = n('basic') + n('hra') + n('medical') + n('conveyance') + n('bonus') + n('other');
  const hraExempt  = Math.min(n('hra') * 0.5, 300000);
  const medExempt  = Math.min(n('medical'), 120000);
  const convExempt = Math.min(n('conveyance'), 30000);
  const netTaxable = Math.max(0, totalGross - hraExempt - medExempt - convExempt);

  function calculate() {
    setResult(computeTax(netTaxable, category));
  }

  function copyResult() {
    if (!result) return;
    const text = `BD Tax FY 2024-25\nCategory: ${category}\nGross: ${tkFull(totalGross)}\nNet Taxable: ${tkFull(netTaxable)}\nAnnual Tax: ${tkFull(result.tax)}\nMonthly TDS: ${tkFull(result.tax/12)}`;
    navigator.clipboard.writeText(text).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }

  const CATEGORIES = ['Male', 'Female', 'Senior (65+)', 'Disabled', 'Freedom Fighter'];
  const INCOME_FIELDS = [
    { key: 'basic',      label: 'Basic Salary',         hint: null },
    { key: 'hra',        label: 'House Rent Allowance',  hint: 'Exempt: 50% up to ৳3L' },
    { key: 'medical',    label: 'Medical Allowance',     hint: 'Exempt: up to ৳1.2L' },
    { key: 'conveyance', label: 'Conveyance Allowance',  hint: 'Exempt: up to ৳30K' },
    { key: 'bonus',      label: 'Festival Bonus',        hint: null },
    { key: 'other',      label: 'Other Income',          hint: null },
  ];

  return (
    <div className="grid lg:grid-cols-2 gap-5">
      {/* Left: Inputs */}
      <div className="space-y-4">
        {/* Category */}
        <div className="bg-white rounded-2xl border border-gray-100 p-5">
          <SectionHead title="Taxpayer Category" />
          <div className="flex flex-wrap gap-2">
            {CATEGORIES.map(c => (
              <button key={c} onClick={() => setCategory(c)}
                className={`px-3 py-2 rounded-xl text-xs font-semibold border transition
                  ${category === c ? 'bg-[#0B3552] text-white border-[#0B3552]' : 'bg-gray-50 text-gray-600 border-gray-200 hover:border-[#0B3552]/30'}`}>
                <span className="block">{c}</span>
                <span className={`block text-[9px] mt-0.5 ${category === c ? 'text-white/60' : 'text-gray-400'}`}>
                  Free: ৳{((THRESHOLDS[c]||350000)/100000).toFixed(1)}L
                </span>
              </button>
            ))}
          </div>
        </div>

        {/* Income inputs */}
        <div className="bg-white rounded-2xl border border-gray-100 p-5">
          <SectionHead title="Annual Income Breakdown" />
          <div className="space-y-3">
            {INCOME_FIELDS.map(f => (
              <div key={f.key} className="flex items-center gap-3">
                <div className="flex-1">
                  <p className="text-[11px] font-semibold text-gray-700">{f.label}</p>
                  {f.hint && <p className="text-[10px] text-emerald-600">{f.hint}</p>}
                </div>
                <div className="relative w-36">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-sm">৳</span>
                  <input
                    type="number"
                    value={income[f.key]}
                    onChange={e => set(f.key, e.target.value)}
                    placeholder="0"
                    className="input pl-7 text-right font-bold text-[#0B3552] text-sm h-9"
                  />
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Summary */}
        {totalGross > 0 && (
          <div className="bg-white rounded-2xl border border-gray-100 p-5">
            <SectionHead title="Income Summary" />
            <div className="space-y-2 text-sm">
              {[
                { label: 'Total Gross',           val: tkFull(totalGross),  color: 'text-gray-800' },
                { label: '− HRA Exemption',       val: `− ${tkFull(hraExempt)}`,  color: 'text-emerald-600' },
                { label: '− Medical Exemption',   val: `− ${tkFull(medExempt)}`,  color: 'text-emerald-600' },
                { label: '− Conveyance Exemption',val: `− ${tkFull(convExempt)}`, color: 'text-emerald-600' },
              ].map(r => (
                <div key={r.label} className="flex justify-between">
                  <span className="text-gray-500">{r.label}</span>
                  <span className={`font-semibold ${r.color}`}>{r.val}</span>
                </div>
              ))}
              <div className="border-t pt-2 flex justify-between font-bold text-[#0B3552]">
                <span>Net Taxable Income</span>
                <span>{tkFull(netTaxable)}</span>
              </div>
            </div>
          </div>
        )}

        <button onClick={calculate} disabled={totalGross === 0}
          className="btn-primary w-full py-3 text-sm font-bold flex items-center justify-center gap-2 disabled:opacity-40">
          <Calculator size={16} /> Calculate Tax
        </button>
      </div>

      {/* Right: Result + Rate table */}
      <div className="space-y-4">
        {result ? (
          <>
            {/* Result hero */}
            <div className="bg-gradient-to-br from-[#0B3552] to-[#1B5E8B] rounded-2xl p-5 text-white">
              <p className="text-white/60 text-xs font-semibold uppercase tracking-wide mb-1">Total Annual Tax Payable</p>
              <p className="text-4xl font-black">{tkFull(result.tax)}</p>
              <p className="text-white/60 text-sm mt-1">Monthly TDS: {tkFull(result.tax / 12)}</p>
              <div className="grid grid-cols-3 gap-2 mt-4">
                {[
                  { label: 'Taxable',    val: tk(result.taxable) },
                  { label: 'Eff. Rate',  val: netTaxable > 0 ? `${(result.tax/netTaxable*100).toFixed(1)}%` : '0%' },
                  { label: 'Monthly',    val: tk(result.tax/12) },
                ].map(p => (
                  <div key={p.label} className="bg-white/15 rounded-xl p-2.5 text-center">
                    <p className="text-white font-black text-sm">{p.val}</p>
                    <p className="text-white/50 text-[10px]">{p.label}</p>
                  </div>
                ))}
              </div>
            </div>

            {/* Slab breakdown */}
            <div className="bg-white rounded-2xl border border-gray-100 p-5">
              <SectionHead title="Slab-wise Breakdown" />
              <div className="space-y-2 text-sm">
                <div className="flex justify-between text-[11px] text-gray-400 font-semibold uppercase tracking-wide pb-1 border-b">
                  <span>Slab</span><span>Income</span><span>Tax</span>
                </div>
                {/* Free threshold */}
                <div className="flex justify-between text-emerald-700 font-semibold">
                  <span className="text-xs">Free Threshold (0%)</span>
                  <span className="text-xs">{tkFull(result.threshold)}</span>
                  <span className="text-xs">৳0</span>
                </div>
                {result.lines.map((l, i) => (
                  <div key={i} className="flex justify-between text-gray-700">
                    <span className="text-xs flex-1">{l.label}</span>
                    <span className="text-xs w-24 text-right">{tkFull(l.income)}</span>
                    <span className="text-xs w-24 text-right font-bold text-[#0B3552]">{tkFull(l.tax)}</span>
                  </div>
                ))}
                <div className="border-t pt-2 flex justify-between font-black text-[#0B3552]">
                  <span>Total Tax</span>
                  <span>{tkFull(result.tax)}</span>
                </div>
              </div>
            </div>

            <button onClick={copyResult}
              className="btn-secondary w-full flex items-center justify-center gap-2 text-sm">
              {copied ? <><Check size={14} className="text-emerald-600" /> Copied!</> : <><Copy size={14} /> Copy Result</>}
            </button>
          </>
        ) : (
          <div className="bg-white rounded-2xl border border-gray-100 p-8 flex flex-col items-center justify-center text-center min-h-[200px]">
            <Calculator size={32} className="text-gray-200 mb-3" />
            <p className="text-sm font-semibold text-gray-400">Enter income details and click Calculate</p>
          </div>
        )}

        {/* Rate reference */}
        <div className="bg-white rounded-2xl border border-gray-100 p-5">
          <SectionHead title="FY 2024-25 Tax Rate Reference" link="https://nbr.gov.bd" />
          <div className="space-y-1.5 text-xs">
            {[
              { label: 'Up to ৳3.5L (Male)',         rate: '0%',   green: true },
              { label: 'Up to ৳4L (Female/Senior)',   rate: '0%',   green: true },
              { label: 'Up to ৳4.75L (Disabled)',     rate: '0%',   green: true },
              { label: 'Up to ৳5L (Freedom Fighter)', rate: '0%',   green: true },
              { label: 'Next ৳1L',                    rate: '5%',   green: false },
              { label: 'Next ৳4L',                    rate: '10%',  green: false },
              { label: 'Next ৳5L',                    rate: '15%',  green: false },
              { label: 'Next ৳5L',                    rate: '20%',  green: false },
              { label: 'Remaining',                   rate: '25%',  green: false },
            ].map(r => (
              <div key={r.label} className="flex justify-between items-center">
                <span className="text-gray-500">{r.label}</span>
                <span className={`px-2 py-0.5 rounded-md font-bold text-[11px]
                  ${r.green ? 'bg-emerald-50 text-emerald-700' : 'bg-blue-50 text-blue-700'}`}>
                  {r.rate}
                </span>
              </div>
            ))}
          </div>
          <div className="mt-3 pt-3 border-t">
            <p className="text-[11px] font-bold text-gray-600 mb-2">Company Rates</p>
            {[
              ['Listed Company',         '22.5%'],
              ['One Person Company',     '25.0%'],
              ['Non-listed Company',     '27.5%'],
              ['Bank / NBFI / Insurance','37.5%'],
              ['Tobacco Company',        '45.0%'],
            ].map(([l, r]) => (
              <div key={l} className="flex justify-between items-center mb-1">
                <span className="text-[11px] text-gray-500">{l}</span>
                <span className="px-2 py-0.5 rounded-md font-bold text-[11px] bg-purple-50 text-purple-700">{r}</span>
              </div>
            ))}
          </div>
          <div className="mt-3 bg-amber-50 border border-amber-200 rounded-xl p-3">
            <p className="text-[10px] text-amber-800">
              ⚠ For guidance only. Consult a certified tax consultant or NBR for official filings.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Modals
// ─────────────────────────────────────────────────────────────────────────────
function ModalShell({ title, onClose, children, onSave, saving }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between px-5 py-4 border-b">
          <h3 className="font-bold text-[#0B3552] text-[15px]">{title}</h3>
          <button onClick={onClose} className="btn-icon"><span className="text-lg leading-none">×</span></button>
        </div>
        <div className="overflow-y-auto flex-1 px-5 py-4 space-y-3">{children}</div>
        <div className="flex justify-end gap-3 px-5 py-4 border-t">
          <button onClick={onClose} className="btn-secondary">Cancel</button>
          <button onClick={onSave} disabled={saving} className="btn-primary flex items-center gap-2">
            {saving && <Loader2 size={13} className="animate-spin" />}
            {saving ? 'Saving…' : 'Save Record'}
          </button>
        </div>
      </div>
    </div>
  );
}

function Field({ label, children }) {
  return (
    <div>
      <label className="label">{label}</label>
      {children}
    </div>
  );
}

function TdsModal({ record, cid, onClose }) {
  const [f, setF] = useState({
    employeeName: record?.employeeName || '',
    designation:  record?.designation  || '',
    department:   record?.department   || '',
    tin:          record?.tin          || '',
    gender:       record?.gender       || 'Male',
    month:        record?.month        || new Date().toLocaleString('en-BD', { month: 'long', year: 'numeric' }),
    grossSalary:  record?.grossSalary  || '',
    tdsAmount:    record?.tdsAmount    || '',
    status:       record?.status       || 'pending',
  });
  const [saving, setSaving] = useState(false);
  const s = (k, v) => setF(p => ({ ...p, [k]: v }));

  function autoCalc() {
    const gross = parseFloat(f.grossSalary) || 0;
    if (!gross) return;
    const { tax } = computeTax(gross * 12, f.gender);
    s('tdsAmount', (tax / 12).toFixed(2));
  }

  async function save() {
    setSaving(true);
    try {
      const data = { ...f, category: 'tds', grossSalary: parseFloat(f.grossSalary)||0, tdsAmount: parseFloat(f.tdsAmount)||0, createdAt: serverTimestamp() };
      if (record) await update(cid, 'taxes', record.id, data);
      else await add(col(cid, 'taxes'), data);
      onClose();
    } catch (e) { alert(e.message); } finally { setSaving(false); }
  }

  return (
    <ModalShell title={record ? 'Edit TDS Record' : 'Add TDS Record'} onClose={onClose} onSave={save} saving={saving}>
      <Field label="Employee Name"><input className="input" value={f.employeeName} onChange={e => s('employeeName', e.target.value)} /></Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Designation"><input className="input" value={f.designation} onChange={e => s('designation', e.target.value)} /></Field>
        <Field label="Department"><input className="input" value={f.department} onChange={e => s('department', e.target.value)} /></Field>
      </div>
        <div className="grid grid-cols-2 gap-3">
        <Field label="TIN (12-digit)"><input className="input font-mono" maxLength={12} value={f.tin} onChange={e => s('tin', e.target.value)} /></Field>
        <Field label="Gender / Category">
          <select className="input" value={f.gender} onChange={e => s('gender', e.target.value)}>
            {['Male','Female','Senior (65+)','Disabled','Freedom Fighter'].map(g => <option key={g}>{g}</option>)}
            </select>
        </Field>
      </div>
      <Field label="Month"><input className="input" value={f.month} onChange={e => s('month', e.target.value)} placeholder="e.g. January 2025" /></Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Gross Salary (৳)"><input className="input" type="number" value={f.grossSalary} onChange={e => s('grossSalary', e.target.value)} /></Field>
        <Field label="TDS Amount (৳)">
          <div className="flex gap-2">
            <input className="input flex-1" type="number" value={f.tdsAmount} onChange={e => s('tdsAmount', e.target.value)} />
            <button onClick={autoCalc} className="btn-secondary px-2.5 text-xs" title="Auto-calculate">Auto</button>
          </div>
        </Field>
      </div>
      <Field label="Status">
        <select className="input" value={f.status} onChange={e => s('status', e.target.value)}>
          <option value="pending">Pending</option>
          <option value="deducted">Deducted</option>
          <option value="overdue">Overdue</option>
        </select>
      </Field>
      <div className="bg-blue-50 border border-blue-200 rounded-xl p-3 text-[11px] text-blue-800">
        TDS auto-calculated using FY 2024-25 BD slabs. Male free threshold: ৳3.5L · Female: ৳4L · Disabled: ৳4.75L
      </div>
    </ModalShell>
  );
}

function ChallanModal({ record, cid, onClose }) {
  const [f, setF] = useState({
    challanNo:   record?.challanNo   || '',
    taxType:     record?.taxType     || 'Income Tax (IT)',
    taxYear:     record?.taxYear     || '2024-25',
    amount:      record?.amount      || '',
    bankName:    record?.bankName    || '',
    depositDate: record?.depositDate || new Date().toISOString().split('T')[0],
    notes:       record?.notes       || '',
    status:      record?.status      || 'pending',
  });
  const [saving, setSaving] = useState(false);
  const s = (k, v) => setF(p => ({ ...p, [k]: v }));

  async function save() {
    setSaving(true);
    try {
      const data = { ...f, category: 'challan', amount: parseFloat(f.amount)||0, createdAt: serverTimestamp() };
      if (record) await update(cid, 'taxes', record.id, data);
      else await add(col(cid, 'taxes'), data);
      onClose();
    } catch (e) { alert(e.message); } finally { setSaving(false); }
  }

  return (
    <ModalShell title={record ? 'Edit Challan' : 'Add Tax Challan'} onClose={onClose} onSave={save} saving={saving}>
      <Field label="Challan Number"><input className="input font-mono" value={f.challanNo} onChange={e => s('challanNo', e.target.value)} placeholder="NBR challan no." /></Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Tax Type">
          <select className="input" value={f.taxType} onChange={e => s('taxType', e.target.value)}>
            {['Income Tax (IT)','VAT','Advance Tax','Withholding Tax','Corporate Tax'].map(t => <option key={t}>{t}</option>)}
          </select>
        </Field>
        <Field label="Tax Year">
          <select className="input" value={f.taxYear} onChange={e => s('taxYear', e.target.value)}>
            {['2022-23','2023-24','2024-25','2025-26'].map(y => <option key={y}>{y}</option>)}
          </select>
        </Field>
      </div>
      <Field label="Amount (৳)"><input className="input" type="number" value={f.amount} onChange={e => s('amount', e.target.value)} /></Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Bank Name"><input className="input" value={f.bankName} onChange={e => s('bankName', e.target.value)} placeholder="e.g. Sonali Bank" /></Field>
        <Field label="Deposit Date"><input className="input" type="date" value={f.depositDate} onChange={e => s('depositDate', e.target.value)} /></Field>
        </div>
      <Field label="Notes"><textarea className="input" rows={2} value={f.notes} onChange={e => s('notes', e.target.value)} /></Field>
      <Field label="Status">
        <select className="input" value={f.status} onChange={e => s('status', e.target.value)}>
          <option value="pending">Pending</option><option value="paid">Paid</option>
        </select>
      </Field>
    </ModalShell>
  );
}

function FilingModal({ record, cid, onClose }) {
  const [f, setF] = useState({
    employeeName:      record?.employeeName      || '',
    tin:               record?.tin               || '',
    taxYear:           record?.taxYear           || '2024-25',
    returnForm:        record?.returnForm        || 'IT-11GA',
    gender:            record?.gender            || 'Male',
    totalIncome:       record?.totalIncome       || '',
    taxableIncome:     record?.taxableIncome     || '',
    taxPayable:        record?.taxPayable        || '',
    filingDate:        record?.filingDate        || new Date().toISOString().split('T')[0],
    acknowledgementNo: record?.acknowledgementNo || '',
    status:            record?.status            || 'pending',
  });
  const [saving, setSaving] = useState(false);
  const s = (k, v) => setF(p => ({ ...p, [k]: v }));

  function autoCalc() {
    const income = parseFloat(f.totalIncome) || 0;
    const { tax } = computeTax(income, f.gender);
    s('taxPayable', tax.toFixed(2));
  }

  async function save() {
    setSaving(true);
    try {
      const data = { ...f, category: 'filing', totalIncome: parseFloat(f.totalIncome)||0, taxableIncome: parseFloat(f.taxableIncome)||0, taxPayable: parseFloat(f.taxPayable)||0, createdAt: serverTimestamp() };
      if (record) await update(cid, 'taxes', record.id, data);
      else await add(col(cid, 'taxes'), data);
      onClose();
    } catch (e) { alert(e.message); } finally { setSaving(false); }
  }

  return (
    <ModalShell title={record ? 'Edit Filing' : 'Add Tax Return Filing'} onClose={onClose} onSave={save} saving={saving}>
      <Field label="Employee / Entity Name"><input className="input" value={f.employeeName} onChange={e => s('employeeName', e.target.value)} /></Field>
      <Field label="TIN (12-digit)"><input className="input font-mono" maxLength={12} value={f.tin} onChange={e => s('tin', e.target.value)} /></Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Tax Year">
          <select className="input" value={f.taxYear} onChange={e => s('taxYear', e.target.value)}>
            {['2022-23','2023-24','2024-25','2025-26'].map(y => <option key={y}>{y}</option>)}
          </select>
        </Field>
        <Field label="Return Form">
          <select className="input" value={f.returnForm} onChange={e => s('returnForm', e.target.value)}>
            {['IT-11GA','IT-11UMA','IT-11CHA','IT-11GHA'].map(f => <option key={f}>{f}</option>)}
          </select>
        </Field>
      </div>
      <Field label="Gender / Category">
        <select className="input" value={f.gender} onChange={e => s('gender', e.target.value)}>
          {['Male','Female','Senior (65+)','Disabled','Freedom Fighter'].map(g => <option key={g}>{g}</option>)}
        </select>
      </Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Total Income (৳)"><input className="input" type="number" value={f.totalIncome} onChange={e => s('totalIncome', e.target.value)} /></Field>
        <Field label="Taxable Income (৳)"><input className="input" type="number" value={f.taxableIncome} onChange={e => s('taxableIncome', e.target.value)} /></Field>
      </div>
      <Field label="Tax Payable (৳)">
        <div className="flex gap-2">
          <input className="input flex-1" type="number" value={f.taxPayable} onChange={e => s('taxPayable', e.target.value)} />
          <button onClick={autoCalc} className="btn-secondary px-2.5 text-xs">Auto</button>
        </div>
      </Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Filing Date"><input className="input" type="date" value={f.filingDate} onChange={e => s('filingDate', e.target.value)} /></Field>
        <Field label="Acknowledgement No."><input className="input font-mono" value={f.acknowledgementNo} onChange={e => s('acknowledgementNo', e.target.value)} /></Field>
      </div>
      <Field label="Status">
        <select className="input" value={f.status} onChange={e => s('status', e.target.value)}>
          <option value="pending">Pending</option><option value="submitted">Submitted</option><option value="overdue">Overdue</option>
        </select>
      </Field>
    </ModalShell>
  );
}

function TinModal({ record, cid, onClose }) {
  const [f, setF] = useState({
    employeeName: record?.employeeName || '',
    designation:  record?.designation  || '',
    department:   record?.department   || '',
    tin:          record?.tin          || '',
    email:        record?.email        || '',
  });
  const [saving, setSaving] = useState(false);
  const s = (k, v) => setF(p => ({ ...p, [k]: v }));

  async function save() {
    if (!f.employeeName || !f.tin) return;
    setSaving(true);
    try {
      const data = { ...f, category: 'tin', status: 'registered', createdAt: serverTimestamp() };
      if (record) await update(cid, 'taxes', record.id, data);
      else await add(col(cid, 'taxes'), data);
      onClose();
    } catch (e) { alert(e.message); } finally { setSaving(false); }
  }

  return (
    <ModalShell title="Register TIN" onClose={onClose} onSave={save} saving={saving}>
      <Field label="Employee Name"><input className="input" value={f.employeeName} onChange={e => s('employeeName', e.target.value)} /></Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Designation"><input className="input" value={f.designation} onChange={e => s('designation', e.target.value)} /></Field>
        <Field label="Department"><input className="input" value={f.department} onChange={e => s('department', e.target.value)} /></Field>
      </div>
      <Field label="TIN (12-digit)">
        <input className="input font-mono tracking-widest text-lg" maxLength={12} value={f.tin} onChange={e => s('tin', e.target.value)} placeholder="000000000000" />
      </Field>
      <Field label="Email"><input className="input" type="email" value={f.email} onChange={e => s('email', e.target.value)} /></Field>
    </ModalShell>
  );
}

function Loader() {
  return (
    <div className="flex justify-center py-16">
      <Loader2 size={22} className="animate-spin text-[#0B3552]" />
    </div>
  );
}
