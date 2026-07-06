// LoansPage — mirrors Flutter loan_approval_screen.dart exactly
//
// Firestore:
//   data/{cid}/loans/{id}
//     userEmail, userId, employeeName, department, type, amount,
//     durationMonths, purpose, status (pending|approved|rejected|disbursed|closed),
//     requestedAt, disbursedAmount, disbursedAt, disbursedBy,
//     decisionAt, decidedBy, notes
//
//   data/{cid}/loans/{id}/repayments/{rid}
//     amount, note, addedAt, addedBy, userId, userEmail, userLevel
//
// Two tabs: Pending (individual loan cards) | All (grouped by agent)
// Portfolio hero card: Total Issued / Repaid / Outstanding + progress bar
// Per-loan: repayment progress live from subcollection
// Actions: Approve, Reject, Disburse, Repay (FIFO across loans per agent)
// PDF export per agent (loans + repayments table)

import { useEffect, useState, useMemo, useCallback } from 'react';
import {
  Loader2, Search, X, Plus, Users, PiggyBank,
  CheckCircle2, XCircle, Banknote, Wallet,
  ChevronDown, ChevronUp, FileText, Download,
  Clock, ThumbsUp, AlertCircle, ReceiptText,
  RefreshCw, TrendingDown,
} from 'lucide-react';
import {
  collection, doc, onSnapshot, writeBatch,
  serverTimestamp, getDocs, orderBy as fbOrderBy, query,
} from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, update, orderBy } from '../lib/db';
import { formatCurrency, formatDate } from '../lib/utils';
import { Modal } from '../components/ui/Modal';
import { EmployeePicker, EmployeeAvatar } from '../components/ui/EmployeePicker';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

// ── Palette ───────────────────────────────────────────────────────────────────
const BRAND   = '#065F46';
const MID     = '#059669';
const DANGER  = '#DC2626';
const WARN    = '#F97316';
const INFO    = '#2563EB';
const MUTED   = '#64748B';

const STATUS_CFG = {
  pending:   { color: WARN,   bg: '#FFF7ED', label: 'Pending',   icon: <Clock size={11} /> },
  approved:  { color: INFO,   bg: '#EFF6FF', label: 'Approved',  icon: <ThumbsUp size={11} /> },
  rejected:  { color: DANGER, bg: '#FEF2F2', label: 'Rejected',  icon: <XCircle size={11} /> },
  disbursed: { color: MID,    bg: '#ECFDF5', label: 'Disbursed', icon: <Banknote size={11} /> },
  closed:    { color: MUTED,  bg: '#F8FAFC', label: 'Closed',    icon: <CheckCircle2 size={11} /> },
};

function statusCfg(s) {
  return STATUS_CFG[(s || 'pending').toLowerCase()] || STATUS_CFG.pending;
}

function initials(email) {
  const core = (email || 'U').split('@')[0];
  const parts = core.split(/[\W_]+/).filter(Boolean);
  if (!parts.length) return core[0].toUpperCase();
  return (parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
}

function n(v) { return typeof v === 'number' ? v : parseFloat(v) || 0; }
function pct(repaid, total) { return total > 0 ? Math.min(1, repaid / total) : 0; }

// ── Repayments subcollection helper ──────────────────────────────────────────
async function fetchRepaid(cid, loanId) {
  const snap = await getDocs(
    query(collection(db, 'data', cid, 'loans', loanId, 'repayments'))
  );
  return snap.docs.reduce((s, d) => s + n(d.data().amount), 0);
}

async function fetchAgentOutstanding(cid, userId) {
  const loansSnap = await getDocs(
    query(col(cid, 'loans'))
  );
  const active = loansSnap.docs.filter(d => {
    const s = (d.data().status || '').toLowerCase();
    return (s === 'approved' || s === 'disbursed') &&
      (d.data().userId === userId || d.data().userEmail === userId);
  });

  let repayable = 0, repaid = 0;
  for (const ld of active) {
    const principal = n(ld.data().amount);
    repayable += principal;
    const rSnap = await getDocs(
      query(collection(db, 'data', cid, 'loans', ld.id, 'repayments'))
    );
    repaid += rSnap.docs.reduce((s, d) => s + n(d.data().amount), 0);
  }
  return { repayable, repaid, outstanding: Math.max(0, repayable - repaid) };
}

// ── Progress bar ─────────────────────────────────────────────────────────────
function ProgressBar({ value, color = MID }) {
  return (
    <div className="h-1.5 rounded-full bg-gray-100 overflow-hidden">
      <div
        className="h-full rounded-full transition-all duration-500"
        style={{ width: `${Math.round(value * 100)}%`, background: color }}
      />
    </div>
  );
}

// ── Status badge ─────────────────────────────────────────────────────────────
function StatusBadge({ status }) {
  const cfg = statusCfg(status);
  return (
    <span
      className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-black border"
      style={{ color: cfg.color, background: cfg.bg, borderColor: cfg.color + '33' }}
    >
      {cfg.icon} {cfg.label}
    </span>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE ROOT
// ─────────────────────────────────────────────────────────────────────────────
export function LoansPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [loans,     setLoans]     = useState([]);
  const [employees, setEmployees] = useState([]);
  const [loading,   setLoading]   = useState(true);
  const [tab,       setTab]       = useState(0); // 0=Pending 1=All
  const [search,    setSearch]    = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [modal,     setModal]     = useState(null); // null | 'add' | loan-obj
  const [disburseModal, setDisburseModal] = useState(null); // loan-obj
  const [repayModal,    setRepayModal]    = useState(null); // { userId, userEmail, loans[] }

  // Portfolio totals (live from subcollections)
  const [totalRepaidAll, setTotalRepaidAll] = useState(0);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'loans'), (docs) => {
      setLoans(docs);
      setLoading(false);
    }, [orderBy('requestedAt', 'desc')]);
    return unsub;
  }, [cid]);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'users'), (docs) => {
      setEmployees(
        docs
          .filter(e => (e.status || 'active') !== 'terminated')
          .map(e => ({ ...e, _displayName: e.fullName || e.name || e.email || '' }))
          .sort((a, b) => a._displayName.localeCompare(b._displayName))
      );
    });
    return unsub;
  }, [cid]);

  // Compute total repaid across all approved/disbursed/closed loans
  useEffect(() => {
    if (!cid || loans.length === 0) return;
    const active = loans.filter(l => ['approved','disbursed','closed'].includes((l.status||'').toLowerCase()));
    let cancelled = false;
    Promise.all(active.map(l => fetchRepaid(cid, l.id)))
      .then(vals => { if (!cancelled) setTotalRepaidAll(vals.reduce((s, v) => s + v, 0)); })
      .catch(() => {});
    return () => { cancelled = true; };
  }, [cid, loans]);

  // Portfolio stats
  const totalIssued = useMemo(() =>
    loans.filter(l => ['approved','disbursed','closed'].includes((l.status||'').toLowerCase()))
         .reduce((s, l) => s + n(l.disbursedAmount || l.amount), 0),
  [loans]);
  const outstanding = Math.max(0, totalIssued - totalRepaidAll);
  const repaidPct   = pct(totalRepaidAll, totalIssued);
  const pendingCount   = loans.filter(l => (l.status||'pending').toLowerCase() === 'pending').length;
  const approvedCount  = loans.filter(l => (l.status||'').toLowerCase() === 'approved').length;
  const disbursedTotal = loans.filter(l => (l.status||'').toLowerCase() === 'disbursed')
                              .reduce((s, l) => s + n(l.disbursedAmount || l.amount), 0);

  // Filtered lists
  const pendingLoans = useMemo(() => {
    const q = search.toLowerCase();
    return loans.filter(l => {
      if ((l.status||'pending').toLowerCase() !== 'pending') return false;
      return !q || (l.employeeName||l.userEmail||'').toLowerCase().includes(q) ||
                   (l.type||'').toLowerCase().includes(q);
    });
  }, [loans, search]);

  const allLoans = useMemo(() => {
    const q = search.toLowerCase();
    return loans.filter(l => {
      const s = (l.status||'').toLowerCase();
      const matchStatus = statusFilter === 'all' || s === statusFilter;
      const matchSearch = !q || (l.employeeName||l.userEmail||'').toLowerCase().includes(q);
      return matchStatus && matchSearch;
    });
  }, [loans, search, statusFilter]);

  // Group all loans by agent (for "All" tab)
  const agentGroups = useMemo(() => {
    const map = {};
    allLoans.forEach(l => {
      const key = l.userId || l.userEmail || l.employeeName || 'unknown';
      if (!map[key]) map[key] = {
        userId: l.userId || '',
        userEmail: l.userEmail || '',
        employeeName: l.employeeName || l.userEmail || '',
        loans: [],
        totalPrincipal: 0,
        repayable: 0,
      };
      map[key].loans.push(l);
      map[key].totalPrincipal += n(l.amount);
      if (['approved','disbursed'].includes((l.status||'').toLowerCase()))
        map[key].repayable += n(l.amount);
    });
    return Object.values(map).sort((a, b) => b.totalPrincipal - a.totalPrincipal);
  }, [allLoans]);

  // Actions
  async function handleApprove(id, note) {
    await update(cid, 'loans', id, {
      status: 'approved',
      notes: note || null,
      decisionAt: serverTimestamp(),
      decidedBy: session?.email || 'hr',
    });
  }
  async function handleReject(id, note) {
    await update(cid, 'loans', id, {
      status: 'rejected',
      notes: note || null,
      decisionAt: serverTimestamp(),
      decidedBy: session?.email || 'hr',
    });
  }
  async function handleDisburse(loan, amount, note) {
    await update(cid, 'loans', loan.id, {
      status: 'disbursed',
      disbursedAmount: amount,
      disbursedAt: serverTimestamp(),
      disbursedBy: session?.email || 'hr',
      notes: note || null,
      decisionAt: serverTimestamp(),
      decidedBy: session?.email || 'hr',
    });
    setDisburseModal(null);
  }

  // FIFO repayment across all active loans for an agent
  async function handleRepay(userId, userEmail, amount, note) {
    if (amount <= 0) return;
    // Fetch all active loans for this agent ordered by requestedAt
    const loansSnap = await getDocs(
      query(col(cid, 'loans'), fbOrderBy('requestedAt', 'asc'))
    );
    const active = loansSnap.docs.filter(d => {
      const m = d.data();
      const s = (m.status||'').toLowerCase();
      return (s === 'approved' || s === 'disbursed') &&
        (m.userId === userId || m.userEmail === userEmail);
    });

    const buckets = [];
    let totalOutstanding = 0;
    for (const ld of active) {
      const principal = n(ld.data().amount);
      const rSnap = await getDocs(
        query(collection(db, 'data', cid, 'loans', ld.id, 'repayments'))
      );
      const alreadyRepaid = rSnap.docs.reduce((s, d) => s + n(d.data().amount), 0);
      const out = Math.max(0, principal - alreadyRepaid);
      if (out > 0) { buckets.push({ ref: ld.ref, id: ld.id, outstanding: out }); totalOutstanding += out; }
    }

    if (totalOutstanding <= 0) { alert('No outstanding balance for this employee.'); return; }
    if (amount > totalOutstanding) { alert(`Amount exceeds outstanding of ${formatCurrency(totalOutstanding)}.`); return; }

    const batch = writeBatch(db);
    let remaining = amount;
    for (const b of buckets) {
      if (remaining <= 0) break;
      const apply = Math.min(remaining, b.outstanding);
      const repRef = doc(collection(db, 'data', cid, 'loans', b.id, 'repayments'));
      batch.set(repRef, {
        amount: apply,
        note: note || 'Agent-level repayment',
        addedAt: serverTimestamp(),
        addedBy: session?.email || 'hr',
        userLevel: true,
        userId, userEmail,
      });
      remaining -= apply;
    }
    await batch.commit();

    // Auto-close fully repaid loans
    for (const b of buckets) {
      const lSnap = await getDocs(
        query(collection(db, 'data', cid, 'loans', b.id, 'repayments'))
      );
      const totalRepaid = lSnap.docs.reduce((s, d) => s + n(d.data().amount), 0);
      const loanDoc = await getDocs(query(col(cid, 'loans')));
      const lData = loanDoc.docs.find(d => d.id === b.id)?.data();
      if (lData && totalRepaid >= n(lData.amount)) {
        await update(cid, 'loans', b.id, { status: 'closed' });
      }
    }
    setRepayModal(null);
  }

  // PDF export for an agent
  async function exportAgentPdf(agent) {
    const loansSnap = await getDocs(
      query(col(cid, 'loans'), fbOrderBy('requestedAt', 'asc'))
    );
    const agentLoans = loansSnap.docs.filter(d =>
      d.data().userId === agent.userId || d.data().userEmail === agent.userEmail
    );

    const loanRows = [];
    const repayRows = [];
    for (const ld of agentLoans) {
      const m = ld.data();
      const amt = n(m.amount);
      const rSnap = await getDocs(
        query(collection(db, 'data', cid, 'loans', ld.id, 'repayments'), fbOrderBy('addedAt', 'asc'))
      );
      let repaid = 0;
      rSnap.docs.forEach(r => {
        const rm = r.data();
        const ra = n(rm.amount);
        repaid += ra;
        const addedAt = rm.addedAt?.toDate ? rm.addedAt.toDate() : null;
        repayRows.push([
          addedAt ? addedAt.toLocaleDateString('en-BD') : '—',
          formatCurrency(ra),
          m.type || 'Loan',
          rm.note || '',
        ]);
      });
      const reqAt = m.requestedAt?.toDate ? m.requestedAt.toDate() : null;
      loanRows.push([
        m.type || 'Loan',
        formatCurrency(amt),
        reqAt ? reqAt.toLocaleDateString('en-BD') : '—',
        m.status || '—',
        formatCurrency(repaid),
        formatCurrency(Math.max(0, amt - repaid)),
      ]);
    }

    const pdf = new jsPDF();
    pdf.setFontSize(16); pdf.setFont('helvetica', 'bold');
    pdf.text('Agent Loan Report', 14, 18);
    pdf.setFontSize(10); pdf.setFont('helvetica', 'normal');
    pdf.text(agent.userEmail || agent.userId || agent.employeeName, 14, 26);

    pdf.setFontSize(12); pdf.setFont('helvetica', 'bold');
    pdf.text('Loans', 14, 36);
    autoTable(pdf, {
      startY: 40,
      head: [['Type','Amount','Requested','Status','Repaid','Outstanding']],
      body: loanRows,
      styles: { fontSize: 8 },
      headStyles: { fillColor: [6, 95, 70] },
    });

    const y2 = pdf.lastAutoTable.finalY + 10;
    pdf.setFontSize(12); pdf.setFont('helvetica', 'bold');
    pdf.text('Repayments (by date)', 14, y2);
    autoTable(pdf, {
      startY: y2 + 4,
      head: [['Date','Amount','Loan','Note']],
      body: repayRows.length ? repayRows : [['No repayments yet','','','']],
      styles: { fontSize: 8 },
      headStyles: { fillColor: [6, 95, 70] },
    });

    pdf.save(`Loan_Report_${agent.userEmail || agent.userId}_${Date.now()}.pdf`);
  }

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="page-header">
        <div>
          <h2 className="page-title">Loan Approval</h2>
          <p className="page-sub">{loans.length} loan requests · {employees.length} employees</p>
        </div>
        <button onClick={() => setModal('add')} className="btn-primary">
          <Plus size={16} /> Add Loan
        </button>
      </div>

      {/* Portfolio hero card — mirrors Flutter _CompanyBalanceCard */}
      <div className="rounded-2xl p-5 text-white shadow-lg"
        style={{ background: `linear-gradient(135deg, ${BRAND} 0%, ${MID} 100%)` }}>
        <div className="flex items-center gap-2 text-white/70 text-xs font-semibold mb-4">
          <PiggyBank size={14} /> Company Loan Portfolio
        </div>
        <div className="grid grid-cols-3 gap-2 mb-4">
          {[
            { label: 'Total Issued',  value: formatCurrency(totalIssued),    icon: <ReceiptText size={15} />, highlight: false },
            { label: 'Repaid',        value: formatCurrency(totalRepaidAll), icon: <CheckCircle2 size={15} />, highlight: false },
            { label: 'Outstanding',   value: formatCurrency(outstanding),    icon: <TrendingDown size={15} />, highlight: outstanding > 0 },
          ].map(s => (
            <div key={s.label} className="text-center">
              <div className="flex justify-center mb-1" style={{ color: s.highlight ? '#FCD34D' : 'rgba(255,255,255,0.7)' }}>
                {s.icon}
              </div>
              <p className="font-black text-sm" style={{ color: s.highlight ? '#FCD34D' : '#fff' }}>{s.value}</p>
              <p className="text-white/60 text-[10px] mt-0.5">{s.label}</p>
            </div>
          ))}
        </div>
        <div className="flex items-center gap-3">
          <div className="flex-1 h-2 rounded-full bg-white/20 overflow-hidden">
            <div className="h-full rounded-full bg-white transition-all duration-700"
              style={{ width: `${Math.round(repaidPct * 100)}%` }} />
          </div>
          <span className="text-white/70 text-xs font-semibold shrink-0">
            {Math.round(repaidPct * 100)}% repaid
          </span>
        </div>
      </div>

      {/* KPI row — mirrors Flutter _KpiCard row */}
      <div className="grid grid-cols-3 gap-3">
        {[
          { icon: <Clock size={18} />,       label: 'Pending',   value: pendingCount,              color: WARN,  bg: '#FFF7ED' },
          { icon: <ThumbsUp size={18} />,    label: 'Approved',  value: approvedCount,             color: INFO,  bg: '#EFF6FF' },
          { icon: <Banknote size={18} />,    label: 'Disbursed', value: formatCurrency(disbursedTotal), color: MID, bg: '#ECFDF5' },
        ].map(k => (
          <div key={k.label} className="card flex items-center gap-3 p-3">
            <div className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
              style={{ background: k.bg, color: k.color }}>
              {k.icon}
            </div>
            <div>
              <p className="font-black text-gray-900 text-sm leading-tight">{k.value}</p>
              <p className="text-[10px] text-gray-400">{k.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Search + status filter */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[200px] max-w-sm">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input className="input pl-9" placeholder="Search by name or email…"
            value={search} onChange={e => setSearch(e.target.value)} />
          {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={14} /></button>}
        </div>
        {tab === 1 && (
          <select className="input w-auto text-sm" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
            <option value="all">All Status</option>
            {['pending','approved','rejected','disbursed','closed'].map(s => (
              <option key={s} value={s} className="capitalize">{s.charAt(0).toUpperCase() + s.slice(1)}</option>
            ))}
          </select>
        )}
      </div>

      {/* Tabs */}
      <div className="flex border-b border-gray-200">
        {['Pending', 'All Loans'].map((t, i) => (
          <button key={t} onClick={() => setTab(i)}
            className={`px-5 py-2.5 text-sm font-bold border-b-2 transition-colors ${
              tab === i ? 'border-[#065F46] text-[#065F46]' : 'border-transparent text-gray-400 hover:text-gray-600'
            }`}>
            {t}
            {i === 0 && pendingCount > 0 && (
              <span className="ml-1.5 px-1.5 py-0.5 rounded-full text-[10px] font-black bg-amber-100 text-amber-700">
                {pendingCount}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Tab content */}
      {loading ? (
        <div className="flex justify-center py-16">
          <Loader2 size={24} className="animate-spin" style={{ color: BRAND }} />
        </div>
      ) : tab === 0 ? (
        /* ── Pending tab ── */
        pendingLoans.length === 0 ? (
          <EmptyState icon={<PiggyBank size={32} />} title="No pending loans" sub="All loan requests have been reviewed." />
        ) : (
          <div className="space-y-3">
            {pendingLoans.map(l => (
              <LoanCard
                key={l.id}
                loan={l}
                cid={cid}
                onApprove={() => promptNote('Approval note (optional)', n => handleApprove(l.id, n))}
                onReject={() => promptNote('Rejection reason (optional)', n => handleReject(l.id, n))}
                onDisburse={() => setDisburseModal(l)}
                onRepay={() => setRepayModal({ userId: l.userId, userEmail: l.userEmail, employeeName: l.employeeName })}
                onEdit={() => setModal(l)}
              />
            ))}
          </div>
        )
      ) : (
        /* ── All tab — grouped by agent ── */
        agentGroups.length === 0 ? (
          <EmptyState icon={<Search size={32} />} title="No results" sub="Try adjusting your search or filter." />
        ) : (
          <div className="space-y-3">
            {agentGroups.map(ag => (
              <AgentCard
                key={ag.userId || ag.userEmail}
                agent={ag}
                cid={cid}
                onRepay={() => setRepayModal({ userId: ag.userId, userEmail: ag.userEmail, employeeName: ag.employeeName })}
                onExport={() => exportAgentPdf(ag)}
              />
            ))}
          </div>
        )
      )}

      {/* Add / Edit modal */}
      {modal && (
        <LoanFormModal
          loan={modal === 'add' ? null : modal}
          cid={cid}
          employees={employees}
          issuedBy={session?.email || 'hr'}
          onClose={() => setModal(null)}
        />
      )}

      {/* Disburse modal */}
      {disburseModal && (
        <DisburseModal
          loan={disburseModal}
          onConfirm={(amt, note) => handleDisburse(disburseModal, amt, note)}
          onClose={() => setDisburseModal(null)}
        />
      )}

      {/* Repay modal */}
      {repayModal && (
        <RepayModal
          agent={repayModal}
          onConfirm={(amt, note) => handleRepay(repayModal.userId, repayModal.userEmail, amt, note)}
          onClose={() => setRepayModal(null)}
        />
      )}
    </div>
  );
}

// ── Prompt helper (replaces Flutter _askNote dialog) ─────────────────────────
function promptNote(title, cb) {
  const note = window.prompt(title) || '';
  cb(note.trim() || null);
}

// ─────────────────────────────────────────────────────────────────────────────
// LOAN CARD (Pending tab) — mirrors Flutter _LoanCard
// ─────────────────────────────────────────────────────────────────────────────
function LoanCard({ loan: l, cid, onApprove, onReject, onDisburse, onRepay, onEdit }) {
  const [repaid,   setRepaid]   = useState(0);
  const [loading,  setLoading]  = useState(true);
  const [expanded, setExpanded] = useState(false);

  const amount = n(l.amount);
  const cfg    = statusCfg(l.status);

  useEffect(() => {
    if (!cid || !l.id) return;
    // Live subscription to repayments subcollection
    const ref = collection(db, 'data', cid, 'loans', l.id, 'repayments');
    const unsub = onSnapshot(ref, snap => {
      setRepaid(snap.docs.reduce((s, d) => s + n(d.data().amount), 0));
      setLoading(false);
    });
    return unsub;
  }, [cid, l.id]);

  const outstanding = Math.max(0, amount - repaid);
  const progress    = pct(repaid, amount);
  const isCleared   = outstanding === 0 && amount > 0;

  return (
    <div className="card overflow-hidden">
      {/* Header strip */}
      <div className="flex items-center gap-3 p-4"
        style={{ background: cfg.color + '0A', borderBottom: `1px solid ${cfg.color}22` }}>
        <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0 font-black text-sm"
          style={{ background: BRAND + '15', color: BRAND }}>
          {initials(l.userEmail || l.employeeName)}
        </div>
        <div className="flex-1 min-w-0">
          <p className="font-bold text-gray-900 text-sm truncate">{l.employeeName || l.userEmail || '—'}</p>
          <p className="text-xs text-gray-400">
            {l.type || 'Loan'} · {l.durationMonths || '—'}m
            {l.requestedAt ? ` · ${formatDate(l.requestedAt)}` : ''}
          </p>
        </div>
        <StatusBadge status={l.status} />
        <button onClick={() => setExpanded(v => !v)} className="btn-icon btn-sm ml-1">
          {expanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
        </button>
      </div>

      {/* Body */}
      <div className="p-4 space-y-3">
        {/* Amount */}
        <div>
          <p className="text-[10px] text-gray-400 font-semibold uppercase tracking-wider">Loan Amount</p>
          <p className="text-2xl font-black text-gray-900">{formatCurrency(amount)}</p>
        </div>

        {/* Repayment progress */}
        {loading ? (
          <div className="h-8 rounded-xl bg-gray-100 animate-pulse" />
        ) : (
          <div className="space-y-2">
            <div className="grid grid-cols-2 gap-2">
              <StatPill label="Repaid"      value={formatCurrency(repaid)}      color={MID} />
              <StatPill label="Outstanding" value={formatCurrency(outstanding)} color={outstanding > 0 ? WARN : MID} />
            </div>
            {isCleared && (
              <div className="text-center py-1 rounded-lg text-xs font-black"
                style={{ background: '#D1FAE5', color: BRAND }}>
                ✓ Cleared
              </div>
            )}
            <ProgressBar value={progress} color={MID} />
          </div>
        )}

        {/* Purpose */}
        {expanded && l.purpose && (
          <div className="flex items-start gap-2 p-2.5 rounded-xl bg-gray-50 border border-gray-100">
            <FileText size={13} className="text-gray-400 shrink-0 mt-0.5" />
            <p className="text-xs text-gray-500 leading-relaxed">{l.purpose}</p>
          </div>
        )}

        {/* Notes */}
        {expanded && l.notes && (
          <div className="text-xs text-gray-400 italic px-1">{l.notes}</div>
        )}

        {/* Action bar */}
        <div className="flex flex-wrap gap-2 pt-1">
          {(l.status === 'pending' || !l.status) && (
            <button onClick={onApprove}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold text-white transition"
              style={{ background: MID }}>
              <CheckCircle2 size={13} /> Approve
            </button>
          )}
          {['pending','approved'].includes((l.status||'').toLowerCase()) && (
            <button onClick={onReject}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold border transition"
              style={{ color: DANGER, borderColor: DANGER + '50' }}>
              <XCircle size={13} /> Reject
            </button>
          )}
          {['pending','approved'].includes((l.status||'').toLowerCase()) && (
            <button onClick={onDisburse}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold border transition"
              style={{ color: INFO, borderColor: INFO + '50' }}>
              <Banknote size={13} /> Disburse
            </button>
          )}
          {outstanding > 0 && (
            <button onClick={onRepay}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold border transition"
              style={{ color: BRAND, borderColor: BRAND + '50' }}>
              <Wallet size={13} /> Repay
            </button>
          )}
          <button onClick={onEdit}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold border border-gray-200 text-gray-500 hover:bg-gray-50 transition ml-auto">
            Edit
          </button>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AGENT CARD (All tab) — mirrors Flutter _AgentRowCard
// ─────────────────────────────────────────────────────────────────────────────
function AgentCard({ agent, cid, onRepay, onExport }) {
  const [totals,  setTotals]  = useState(null);
  const [expanded, setExpanded] = useState(false);

  useEffect(() => {
    if (!cid) return;
    let cancelled = false;
    fetchAgentOutstanding(cid, agent.userId || agent.userEmail)
      .then(t => { if (!cancelled) setTotals(t); })
      .catch(() => {});
    return () => { cancelled = true; };
  }, [cid, agent.userId, agent.userEmail]);

  if (totals && totals.outstanding === 0 && totals.repayable > 0) return null; // auto-hide cleared

  const repaid      = totals?.repaid      ?? 0;
  const outstanding = totals?.outstanding ?? 0;
  const repayable   = totals?.repayable   ?? agent.repayable ?? 0;
  const progress    = pct(repaid, repayable);

  return (
    <div className="card overflow-hidden">
      {/* Header */}
      <div className="flex items-center gap-3 p-4 border-b border-gray-100">
        <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0 font-black text-sm"
          style={{ background: BRAND + '15', color: BRAND }}>
          {initials(agent.userEmail || agent.employeeName)}
        </div>
        <div className="flex-1 min-w-0">
          <p className="font-bold text-gray-900 text-sm truncate">{agent.employeeName || agent.userEmail || '—'}</p>
          <p className="text-xs text-gray-400">
            {agent.loans.length} loan{agent.loans.length !== 1 ? 's' : ''} · Total: {formatCurrency(repayable)}
          </p>
        </div>
        <button onClick={() => setExpanded(v => !v)} className="btn-icon btn-sm">
          {expanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
        </button>
      </div>

      {/* Stats */}
      <div className="p-4 space-y-3">
        {totals === null ? (
          <div className="h-10 rounded-xl bg-gray-100 animate-pulse" />
        ) : (
          <>
            <div className="grid grid-cols-2 gap-2">
              <StatPill label="Repaid"      value={formatCurrency(repaid)}      color={MID} />
              <StatPill label="Outstanding" value={formatCurrency(outstanding)} color={outstanding > 0 ? WARN : MID} />
            </div>
            <ProgressBar value={progress} color={MID} />
          </>
        )}

        {/* Loan list (expanded) */}
        {expanded && (
          <div className="space-y-2 pt-1">
            {agent.loans.map(l => (
              <div key={l.id} className="flex items-center gap-3 p-2.5 rounded-xl bg-gray-50 border border-gray-100">
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-bold text-gray-800">{l.type || 'Loan'} · {formatCurrency(n(l.amount))}</p>
                  {l.requestedAt && <p className="text-[10px] text-gray-400">{formatDate(l.requestedAt)}</p>}
                </div>
                <StatusBadge status={l.status} />
              </div>
            ))}
          </div>
        )}

        {/* Actions */}
        <div className="flex flex-wrap gap-2 pt-1">
          {outstanding > 0 && (
            <button onClick={onRepay}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold text-white transition"
              style={{ background: BRAND }}>
              <Wallet size={13} /> Repay
            </button>
          )}
          <button onClick={() => setExpanded(v => !v)}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold border border-gray-200 text-gray-500 hover:bg-gray-50 transition">
            <FileText size={13} /> {expanded ? 'Hide Loans' : 'View Loans'}
          </button>
          <button onClick={onExport}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold border border-gray-200 text-gray-500 hover:bg-gray-50 transition">
            <Download size={13} /> Export PDF
          </button>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT PILL
// ─────────────────────────────────────────────────────────────────────────────
function StatPill({ label, value, color }) {
  return (
    <div className="p-2.5 rounded-xl border"
      style={{ background: color + '0D', borderColor: color + '33' }}>
      <p className="text-[10px] font-semibold text-gray-500 mb-0.5">{label}</p>
      <p className="text-sm font-black" style={{ color }}>{value}</p>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DISBURSE MODAL — mirrors Flutter _askDisburse
// ─────────────────────────────────────────────────────────────────────────────
function DisburseModal({ loan, onConfirm, onClose }) {
  const [amount, setAmount] = useState(String(n(loan.amount)));
  const [note,   setNote]   = useState('');
  const [saving, setSaving] = useState(false);

  async function handleSubmit() {
    const amt = parseFloat(amount.replace(/,/g, '')) || 0;
    if (amt <= 0) { alert('Enter a valid amount'); return; }
    setSaving(true);
    try { await onConfirm(amt, note.trim() || null); }
    finally { setSaving(false); }
  }

  return (
    <Modal title="Disburse Loan" onClose={onClose}>
      <div className="space-y-4">
        <div className="flex items-center gap-3 p-3 rounded-xl bg-gray-50 border border-gray-200">
          <Banknote size={18} style={{ color: INFO }} />
          <div>
            <p className="font-bold text-gray-900 text-sm">{loan.employeeName || loan.userEmail}</p>
            <p className="text-xs text-gray-400">{loan.type || 'Loan'} · Requested: {formatCurrency(n(loan.amount))}</p>
          </div>
        </div>
        <div>
          <label className="label">Disbursed Amount (BDT) *</label>
          <input className="input" type="number" value={amount} onChange={e => setAmount(e.target.value)} placeholder="0.00" />
        </div>
        <div>
          <label className="label">Note (optional)</label>
          <textarea className="input" rows={2} value={note} onChange={e => setNote(e.target.value)} placeholder="Disbursement note…" />
        </div>
        <div className="flex gap-3">
          <button onClick={onClose} className="btn-secondary flex-1">Cancel</button>
          <button onClick={handleSubmit} disabled={saving} className="btn-primary flex-1">
            {saving ? <Loader2 size={14} className="animate-spin" /> : <Banknote size={14} />}
            {saving ? 'Disbursing…' : 'Disburse'}
          </button>
        </div>
      </div>
    </Modal>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// REPAY MODAL — mirrors Flutter _askRepayment
// ─────────────────────────────────────────────────────────────────────────────
function RepayModal({ agent, onConfirm, onClose }) {
  const [amount, setAmount] = useState('');
  const [note,   setNote]   = useState('');
  const [saving, setSaving] = useState(false);

  async function handleSubmit() {
    const amt = parseFloat(amount.replace(/,/g, '')) || 0;
    if (amt <= 0) { alert('Enter a valid amount'); return; }
    setSaving(true);
    try { await onConfirm(amt, note.trim() || null); }
    catch (e) { alert(e.message); }
    finally { setSaving(false); }
  }

  return (
    <Modal title="Record Repayment" onClose={onClose}>
      <div className="space-y-4">
        <div className="flex items-center gap-3 p-3 rounded-xl bg-gray-50 border border-gray-200">
          <Wallet size={18} style={{ color: BRAND }} />
          <div>
            <p className="font-bold text-gray-900 text-sm">{agent.employeeName || agent.userEmail}</p>
            <p className="text-xs text-gray-400">FIFO repayment across all active loans</p>
          </div>
        </div>
        <div>
          <label className="label">Repayment Amount (BDT) *</label>
          <input className="input" type="number" value={amount} onChange={e => setAmount(e.target.value)} placeholder="0.00" autoFocus />
        </div>
        <div>
          <label className="label">Note (optional)</label>
          <textarea className="input" rows={2} value={note} onChange={e => setNote(e.target.value)} placeholder="Repayment note…" />
        </div>
        <div className="flex gap-3">
          <button onClick={onClose} className="btn-secondary flex-1">Cancel</button>
          <button onClick={handleSubmit} disabled={saving} className="btn-primary flex-1">
            {saving ? <Loader2 size={14} className="animate-spin" /> : <Wallet size={14} />}
            {saving ? 'Saving…' : 'Save Repayment'}
          </button>
        </div>
      </div>
    </Modal>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LOAN FORM MODAL (Add / Edit)
// ─────────────────────────────────────────────────────────────────────────────
function LoanFormModal({ loan, cid, employees, issuedBy, onClose }) {
  const isEdit = !!loan;
  const today  = new Date().toISOString().split('T')[0];

  const [selectedEmp, setSelectedEmp] = useState(
    isEdit ? { _displayName: loan.employeeName, name: loan.employeeName } : null
  );
  const [form, setForm] = useState({
    employeeName:   loan?.employeeName   || '',
    employeeId:     loan?.employeeId     || '',
    userId:         loan?.userId         || '',
    userEmail:      loan?.userEmail      || '',
    department:     loan?.department     || '',
    type:           loan?.type           || 'Loan',
    amount:         loan?.amount         || '',
    durationMonths: loan?.durationMonths || 12,
    purpose:        loan?.purpose        || '',
    status:         loan?.status         || 'pending',
    notes:          loan?.notes          || '',
  });
  const [saving, setSaving] = useState(false);
  const [error,  setError]  = useState('');

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  function handleEmpSelect(emp) {
    setSelectedEmp(emp);
    if (emp) setForm(f => ({
      ...f,
      employeeName: emp._displayName || emp.fullName || emp.name || '',
      employeeId:   emp.id || '',
      userId:       emp.id || '',
      userEmail:    emp.email || emp.officeEmail || '',
      department:   emp.department || '',
    }));
  }

  async function handleSave() {
    if (!form.employeeName.trim()) { setError('Please select an employee.'); return; }
    if (!parseFloat(form.amount)) { setError('Enter a valid amount.'); return; }
    setSaving(true); setError('');
    try {
      const data = { ...form, amount: parseFloat(form.amount) || 0, durationMonths: parseInt(form.durationMonths) || 12 };
      if (isEdit) {
        await update(cid, 'loans', loan.id, data);
      } else {
        await add(col(cid, 'loans'), { ...data, requestedAt: serverTimestamp() });
      }
      onClose();
    } catch (e) { setError(e.message); }
    finally { setSaving(false); }
  }

  return (
    <Modal title={isEdit ? 'Edit Loan' : 'Add Loan Request'} onClose={onClose} wide>
      <div className="space-y-4">
        {!isEdit ? (
          <div className="rounded-xl border border-[#065F46]/20 bg-[#F0FDF4] p-4">
            <p className="text-xs font-black uppercase tracking-wider text-[#065F46]/70 mb-3 flex items-center gap-1.5">
              <Users size={13} /> Select Employee
            </p>
            <EmployeePicker employees={employees} value={selectedEmp} onChange={handleEmpSelect} required />
          </div>
        ) : (
          <div className="flex items-center gap-3 p-3 rounded-xl bg-gray-50 border border-gray-200">
            <EmployeeAvatar emp={{ _displayName: form.employeeName }} size={9} />
            <div>
              <p className="font-bold text-gray-900 text-sm">{form.employeeName}</p>
              {form.userEmail && <p className="text-xs text-gray-400">{form.userEmail}</p>}
            </div>
          </div>
        )}

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label">Loan Amount (BDT) *</label>
            <input className="input" type="number" value={form.amount}
              onChange={e => set('amount', e.target.value)} placeholder="0.00" />
          </div>
          <div>
            <label className="label">Duration (months)</label>
            <input className="input" type="number" value={form.durationMonths}
              onChange={e => set('durationMonths', e.target.value)} min={1} />
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label">Type</label>
            <select className="input" value={form.type} onChange={e => set('type', e.target.value)}>
              {['Loan','Advance','Emergency','Education','Medical'].map(t => <option key={t}>{t}</option>)}
            </select>
          </div>
          <div>
            <label className="label">Status</label>
            <select className="input" value={form.status} onChange={e => set('status', e.target.value)}>
              {['pending','approved','rejected','disbursed','closed'].map(s => (
                <option key={s} value={s} className="capitalize">{s.charAt(0).toUpperCase() + s.slice(1)}</option>
              ))}
            </select>
          </div>
        </div>

        <div>
          <label className="label">Purpose</label>
          <input className="input" value={form.purpose} onChange={e => set('purpose', e.target.value)}
            placeholder="Medical, Education, Emergency…" />
        </div>
        <div>
          <label className="label">Notes</label>
          <textarea className="input" rows={2} value={form.notes}
            onChange={e => set('notes', e.target.value)} placeholder="Optional notes…" />
        </div>

        {error && (
          <div className="flex items-center gap-2 p-3 rounded-xl bg-red-50 border border-red-200">
            <AlertCircle size={14} className="text-red-500 shrink-0" />
            <p className="text-sm text-red-600">{error}</p>
          </div>
        )}
        <div className="flex gap-3">
          <button onClick={onClose} className="btn-secondary flex-1">Cancel</button>
          <button onClick={handleSave} disabled={saving} className="btn-primary flex-1">
            {saving ? <Loader2 size={14} className="animate-spin" /> : null}
            {saving ? 'Saving…' : isEdit ? 'Save Changes' : 'Add Loan'}
          </button>
        </div>
      </div>
    </Modal>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
function EmptyState({ icon, title, sub }) {
  return (
    <div className="card p-12 text-center">
      <div className="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4"
        style={{ background: '#D1FAE5', color: BRAND }}>
        {icon}
      </div>
      <p className="font-black text-gray-700 text-base">{title}</p>
      <p className="text-sm text-gray-400 mt-1">{sub}</p>
    </div>
  );
}
