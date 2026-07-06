// Balance & Cash-Flow Page
// Mirrors the Flutter BalanceUpdateScreen exactly:
//   Tab 1 — Overview   : hero balance card, this-month mini-cards, last payment, recent entries
//   Tab 2 — Credits    : all cash_in entries with total hero
//   Tab 3 — Transactions: full cash_flow feed with All/Cash In/Cash Out/Reversal filter chips
//   Tab 4 — Analytics  : period-scoped ledger credit pie + expense pie + bar chart + profit summary
//
// Data sources:
//   company_profile/main  → cashIn, cashOut (running totals)
//   cash_flow             → individual entries (type: cash_in | cash_out | reversal)
//   ledger                → credit entries for Analytics
//   expenses              → expense entries for Analytics
//
// Edit: any transaction can be edited — amount/description/type changes are
//       atomically reflected in company_profile/main via writeBatch + increment.

import { useEffect, useState, useMemo, useCallback } from 'react';
import {
  Loader2, ArrowDownLeft, ArrowUpRight, Undo2,
  Wallet, TrendingUp, TrendingDown, ReceiptText,
  Calendar, ChevronDown, Download, RefreshCw,
  ArrowUp, ArrowDown, CheckCircle2, Edit2, X, Save,
  AlertCircle, Trash2,
} from 'lucide-react';
import {
  PieChart, Pie, Cell, Tooltip as RechartTooltip,
  BarChart, Bar, XAxis, YAxis, CartesianGrid, ResponsiveContainer,
  Legend,
} from 'recharts';
import { doc, deleteDoc, getDocs, collection, query, where as fbWhere } from 'firebase/firestore';
import { useAuth } from '../context/AuthContext';
import {
  col, docRef, subscribe, orderBy, where,
  Timestamp, writeBatch, increment, db, serverTimestamp,
} from '../lib/db';
import { formatDate, formatDateTime } from '../lib/utils';

// ── Palette (matches Flutter) ─────────────────────────────────────────────────
const BRAND    = '#065F46';
const CASH_IN  = '#16A34A';
const CASH_OUT = '#DC2626';
const NEUTRAL  = '#2563EB';
const WARN     = '#EA580C';
const CHART_PALETTE = [
  '#065F46','#2563EB','#EA580C','#7C3AED','#0369A1',
  '#16A34A','#DC2626','#D97706','#0891B2','#9333EA',
  '#15803D','#1D4ED8',
];

// ── Number helpers ────────────────────────────────────────────────────────────
function n(v) {
  if (v == null) return 0;
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return parseFloat(v.replace(/,/g, '')) || 0;
  return 0;
}
function fmt(v) {
  return new Intl.NumberFormat('en-BD', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(v || 0);
}
function fmtShort(v) {
  const abs = Math.abs(v);
  if (abs >= 1e7) return (v / 1e7).toFixed(1) + 'cr';
  if (abs >= 1e5) return (v / 1e5).toFixed(1) + 'L';
  if (abs >= 1e3) return (v / 1e3).toFixed(0) + 'k';
  return v.toFixed(0);
}

// ── Tab bar ───────────────────────────────────────────────────────────────────
const TABS = ['Overview', 'Credits', 'Transactions', 'Analytics'];

// ─────────────────────────────────────────────────────────────────────────────
// PAGE ROOT
// ─────────────────────────────────────────────────────────────────────────────
export function BalancePage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [tab, setTab]             = useState(0);
  const [profile, setProfile]     = useState({});
  const [cashFlow, setCashFlow]   = useState([]);
  const [loans,    setLoans]      = useState([]);
  const [ledger, setLedger]       = useState([]);
  const [expenses, setExpenses]   = useState([]);
  const [loadingProfile, setLP]   = useState(true);
  const [loadingCF, setLCF]       = useState(true);
  const [loadingAnalytics, setLA] = useState(true);
  const [editTx,    setEditTx]    = useState(null); // transaction being edited
  const [reversing, setReversing] = useState(null); // id of tx being reversed

  // Period for Analytics tab (default: this month)
  const now = new Date();
  const [periodStart, setPeriodStart] = useState(new Date(now.getFullYear(), now.getMonth(), 1));
  const [periodEnd,   setPeriodEnd]   = useState(new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59));

  // ── Subscriptions ──────────────────────────────────────────────────────────
  useEffect(() => {
    if (!cid) return;
    // company_profile/main — subscribe to the single doc
    const unsub = subscribe(
      col(cid, 'company_profile'),
      (docs) => {
        const main = docs.find(d => d.id === 'main') || {};
        setProfile(main);
        setLP(false);
      },
    );
    return unsub;
  }, [cid]);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(
      col(cid, 'cash_flow'),
      (docs) => { setCashFlow(docs); setLCF(false); },
      [orderBy('createdAt', 'desc')],
    );
    return unsub;
  }, [cid]);

  // Loans — for outstanding liability calculation
  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'loans'), (docs) => setLoans(docs));
    return unsub;
  }, [cid]);

  // Analytics: ledger + expenses filtered by period
  useEffect(() => {
    if (!cid) return;
    setLA(true);
    const startTs = Timestamp.fromDate(periodStart);
    const endTs   = Timestamp.fromDate(periodEnd);

    const unsubL = subscribe(
      col(cid, 'ledger'),
      (docs) => setLedger(docs),
      [where('date', '>=', startTs), where('date', '<=', endTs), orderBy('date', 'desc')],
    );
    const unsubE = subscribe(
      col(cid, 'expenses'),
      (docs) => { setExpenses(docs); setLA(false); },
      [where('dueDate', '>=', startTs), where('dueDate', '<=', endTs), orderBy('dueDate', 'desc')],
    );
    return () => { unsubL(); unsubE(); };
  }, [cid, periodStart, periodEnd]);

  // ── Derived values ─────────────────────────────────────────────────────────
  //
  // Balance formula:
  //   balance = credit − expenses − outstanding_loans
  //
  // We derive totalCredit and totalExpense by summing the LIVE cash_flow
  // collection directly. This avoids stale counter issues in company_profile/main
  // (e.g. if a reversal didn't decrement cashOut correctly, the live sum is
  // always accurate because reversals DELETE the original cash_out entry).
  //
  // Reversal entries are audit-trail only — they do NOT count as cash_out.

  const { totalCredit, totalExpense } = useMemo(() => {
    let tIn = 0, tOut = 0;
    cashFlow.forEach(d => {
      const amt = n(d.amount);
      if (d.type === 'cash_in')  tIn  += amt;
      if (d.type === 'cash_out') tOut += amt;
      // 'reversal' is audit-only — not counted
    });
    return { totalCredit: tIn, totalExpense: tOut };
  }, [cashFlow]);

  // Outstanding loans = sum of disbursedAmount for loans in 'disbursed' status
  // (repayments live in subcollections; we use disbursedAmount as the gross liability
  //  and subtract any repaid field stored on the loan doc itself if present)
  const outstandingLoans = useMemo(() => {
    return loans
      .filter(l => {
        const s = (l.status || '').toLowerCase();
        return s === 'disbursed' || s === 'approved';
      })
      .reduce((sum, l) => {
        const principal = n(l.disbursedAmount || l.amount);
        const repaid    = n(l.repaidAmount || l.totalRepaid || 0);
        return sum + Math.max(0, principal - repaid);
      }, 0);
  }, [loans]);

  // cashIn / cashOut kept for backward compat with sub-components
  const cashIn  = totalCredit;
  const cashOut = totalExpense;
  const balance = totalCredit - totalExpense - outstandingLoans;

  // This-month totals from cash_flow entries.
  // Reversal entries are audit-trail only — the original cash_out doc is deleted
  // when a reversal happens, so we do NOT subtract reversal amounts here.
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const { monthIn, monthOut } = useMemo(() => {
    let mIn = 0, mOut = 0;
    cashFlow.forEach(d => {
      const ts = d.createdAt;
      if (!ts) return;
      const dt = ts?.toDate ? ts.toDate() : new Date(ts.seconds * 1000);
      if (dt < monthStart) return;
      const amt = n(d.amount);
      if (d.type === 'cash_in')       mIn  += amt;
      else if (d.type === 'cash_out') mOut += amt;
      // reversal: original cash_out was deleted, so no adjustment needed here
    });
    return { monthIn: mIn, monthOut: mOut };
  }, [cashFlow]);

  // ── PDF export ─────────────────────────────────────────────────────────────
  async function handleExportCsv() {
    const rows = [['Date','Type','Description','Currency','Amount (BDT)']];
    cashFlow.slice(0, 200).forEach(d => {
      const ts  = d.createdAt;
      const dt  = ts?.toDate ? ts.toDate() : ts?.seconds ? new Date(ts.seconds * 1000) : null;
      const date = dt ? dt.toLocaleDateString('en-BD') : '—';
      rows.push([
        date,
        (d.type || '').toUpperCase(),
        (d.description || d.invoiceNo || '').replace(/,/g, ' '),
        d.currency || 'BDT',
        fmt(n(d.amount)),
      ]);
    });
    const csv  = rows.map(r => r.join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href = url; a.download = 'balance-cashflow.csv'; a.click();
    URL.revokeObjectURL(url);
  }

  // ── Reverse a cash_out transaction ─────────────────────────────────────────
  // Full cascade:
  //   1. Delete the original cash_out entry
  //   2. Decrement company_profile.cashOut (restores balance)
  //   3. Create a reversal audit entry in cash_flow
  //   4. If linked to a payroll (_payrollDocId):
  //      a. Delete linked expense entries
  //      b. Reset payroll status → 'pending'  (was 'paid')
  //      c. Reset linked payslips → status 'generated', clear sentAt
  async function reverseTransaction(tx) {
    if (tx.type !== 'cash_out') return;
    const amt          = n(tx.amount);
    const payrollDocId = tx._payrollDocId || null;

    const isPayroll = !!payrollDocId;
    const confirmMsg =
      `Reverse this cash-out of ${tx.currency || 'BDT'} ${fmt(amt)}?\n\n` +
      `This will:\n• Delete the cash-out entry\n• Restore ${fmt(amt)} to the balance\n• Add a reversal audit record` +
      (isPayroll
        ? `\n• Revert the linked payroll back to "Pending"\n• Reset linked payslips to "Generated"\n• Remove linked expense entries`
        : '');

    if (!window.confirm(confirmMsg)) return;

    setReversing(tx.id);
    try {
      const batch = writeBatch(db);

      // 1. Delete the original cash_out document
      batch.delete(doc(db, 'data', cid, 'cash_flow', tx.id));

      // 2. Decrement cashOut in company_profile/main (restores balance)
      batch.update(doc(db, 'data', cid, 'company_profile', 'main'), {
        cashOut:   increment(-amt),
        updatedAt: serverTimestamp(),
      });

      // 3. Create a reversal audit entry
      batch.set(doc(db, 'data', cid, 'cash_flow', `rev_${tx.id}`), {
        type:          'reversal',
        amount:        amt,
        currency:      tx.currency || 'BDT',
        originalId:    tx.id,
        description:   `Reversal of: ${tx.description || tx.invoiceNo || 'cash-out entry'}`,
        invoiceNo:     tx.invoiceNo || '',
        reversedBy:    session?.displayName || session?.email || 'HR',
        reversedAt:    serverTimestamp(),
        createdAt:     serverTimestamp(),
        ...(payrollDocId ? { _payrollDocId: payrollDocId } : {}),
      });

      // 4. Payroll cascade — only if this cash_out was created by "Pay Bill"
      if (payrollDocId) {
        // 4a. Delete ALL cash_flow entries for this payroll (multi-employee payrolls
        //     create one entry per employee; reversing any one reverses the whole payroll)
        const allCfSnap = await getDocs(
          query(collection(db, 'data', cid, 'cash_flow'),
            fbWhere('_payrollDocId', '==', payrollDocId))
        );
        let extraCashOutTotal = 0;
        allCfSnap.docs.forEach(d => {
          if (d.id !== tx.id && d.data().type === 'cash_out') {
            // This sibling cash_out was not the one we already deleted above;
            // accumulate its amount so we can decrement cashOut correctly.
            extraCashOutTotal += n(d.data().amount);
          }
          batch.delete(d.ref);
        });
        // Decrement the remaining employees' cashOut amounts
        if (extraCashOutTotal > 0) {
          batch.update(doc(db, 'data', cid, 'company_profile', 'main'), {
            cashOut:   increment(-extraCashOutTotal),
            updatedAt: serverTimestamp(),
          });
        }

        // 4b. Delete all expense entries linked to this payroll
        const expSnap = await getDocs(
          query(collection(db, 'data', cid, 'expenses'),
            fbWhere('_payrollDocId', '==', payrollDocId))
        );
        expSnap.docs.forEach(d => batch.delete(d.ref));

        // 4c. Reset the payroll document back to 'pending'
        batch.update(doc(db, 'data', cid, 'payrolls', payrollDocId), {
          status:    'pending',
          paidAt:    null,
          reversedAt: serverTimestamp(),
          reversedBy: session?.email || 'HR',
          updatedAt:  serverTimestamp(),
        });

        // 4d. Mark all payslips linked to this payroll → 'reversed'
        const payslipSnap = await getDocs(
          query(collection(db, 'data', cid, 'payslips'),
            fbWhere('payrollId', '==', payrollDocId))
        );
        payslipSnap.docs.forEach(d => {
          batch.update(d.ref, {
            status:     'reversed',
            sentAt:     null,
            reversedAt: serverTimestamp(),
            updatedAt:  serverTimestamp(),
          });
        });
      }

      await batch.commit();
    } catch (e) {
      alert('Reversal failed: ' + e.message);
    } finally {
      setReversing(null);
    }
  }

  // ── Sync / cleanup orphaned cash_out entries ───────────────────────────────
  // Finds cash_out entries in cash_flow whose linked payroll is now 'pending'
  // (meaning the payroll was reversed but the cash_out doc was never deleted),
  // and deletes them so the balance reflects reality.
  const [syncing, setSyncing] = useState(false);

  async function handleSyncBalance() {
    if (!window.confirm(
      'Sync Balance?\n\n' +
      'This will scan all cash_out entries and remove any that are linked to a ' +
      'payroll that is no longer "paid" (i.e. orphaned entries from old reversals).\n\n' +
      'This is safe to run and cannot be undone.'
    )) return;

    setSyncing(true);
    try {
      // 1. Fetch all cash_flow entries of type cash_out
      const cfSnap = await getDocs(
        query(collection(db, 'data', cid, 'cash_flow'), fbWhere('type', '==', 'cash_out'))
      );

      // 2. Collect unique payrollDocIds referenced by these entries
      const payrollIds = [...new Set(
        cfSnap.docs
          .map(d => d.data()._payrollDocId)
          .filter(Boolean)
      )];

      // 3. Fetch each referenced payroll to check its current status
      const { getDoc: fsGetDoc } = await import('firebase/firestore');
      const payrollStatuses = {};
      await Promise.all(payrollIds.map(async (pid) => {
        const snap = await fsGetDoc(doc(db, 'data', cid, 'payrolls', pid));
        if (!snap.exists()) {
          payrollStatuses[pid] = 'deleted';
        } else {
          payrollStatuses[pid] = snap.data().status || 'unknown';
        }
      }));

      // 4. Identify orphaned cash_out docs:
      //    - linked to a payroll that is 'pending' (reversed) or deleted
      const orphans = cfSnap.docs.filter(d => {
        const pid = d.data()._payrollDocId;
        if (!pid) return false; // manual cash_out — keep it
        const st = payrollStatuses[pid];
        return st === 'pending' || st === 'deleted';
      });

      if (orphans.length === 0) {
        alert('Balance is already clean — no orphaned entries found.');
        setSyncing(false);
        return;
      }

      // 5. Delete orphaned entries in a batch
      const batch = writeBatch(db);
      orphans.forEach(d => batch.delete(d.ref));

      // 6. Also sync company_profile/main.cashOut to the real sum
      //    (recompute from remaining cash_out docs after deletion)
      const remainingTotal = cfSnap.docs
        .filter(d => !orphans.find(o => o.id === d.id))
        .reduce((s, d) => s + (d.data().type === 'cash_out' ? (d.data().amount || 0) : 0), 0);

      batch.update(doc(db, 'data', cid, 'company_profile', 'main'), {
        cashOut:   remainingTotal,
        updatedAt: serverTimestamp(),
      });

      await batch.commit();
      alert(`Done! Removed ${orphans.length} orphaned cash-out entr${orphans.length === 1 ? 'y' : 'ies'}. Balance is now correct.`);
    } catch (e) {
      alert('Sync failed: ' + e.message);
    } finally {
      setSyncing(false);
    }
  }

  const loading = loadingProfile || loadingCF;

  return (
    <div className="space-y-0 -mx-6 -mt-6">
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div
        className="px-6 pt-5 pb-0"
        style={{ background: 'linear-gradient(135deg, #065F46 0%, #059669 100%)' }}
      >
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-white font-black text-xl">Balance & Cash Flow</h2>
            <p className="text-white/60 text-xs mt-0.5">Live financial overview</p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={handleSyncBalance}
              disabled={syncing}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/15 text-white text-xs font-bold hover:bg-white/25 transition disabled:opacity-50"
              title="Remove orphaned cash-out entries from old reversals"
            >
              {syncing ? <Loader2 size={13} className="animate-spin" /> : <RefreshCw size={13} />}
              {syncing ? 'Syncing…' : 'Sync Balance'}
            </button>
            <button
              onClick={handleExportCsv}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/15 text-white text-xs font-bold hover:bg-white/25 transition"
            >
              <Download size={13} /> Export CSV
            </button>
          </div>
        </div>

        {/* Tab bar */}
        <div className="flex gap-0">
          {TABS.map((t, i) => (
            <button
              key={t}
              onClick={() => setTab(i)}
              className={`px-4 py-2.5 text-sm font-semibold border-b-2 transition-colors ${
                tab === i
                  ? 'border-white text-white'
                  : 'border-transparent text-white/50 hover:text-white/80'
              }`}
            >
              {t}
            </button>
          ))}
        </div>
      </div>

      {/* ── Tab content ──────────────────────────────────────────────────── */}
      <div className="px-6 py-5">
        {loading ? (
          <div className="flex justify-center py-20">
            <Loader2 size={28} className="animate-spin" style={{ color: BRAND }} />
          </div>
        ) : (
          <>
            {tab === 0 && (
              <OverviewTab
                balance={balance}
                totalCredit={totalCredit} totalExpense={totalExpense}
                outstandingLoans={outstandingLoans}
                monthIn={monthIn} monthOut={monthOut}
                cashFlow={cashFlow}
                onEdit={setEditTx}
                onReverse={reverseTransaction}
                reversing={reversing}
              />
            )}
            {tab === 1 && <CreditsTab cashFlow={cashFlow} onEdit={setEditTx} />}
            {tab === 2 && <TransactionsTab cashFlow={cashFlow} onEdit={setEditTx} onReverse={reverseTransaction} reversing={reversing} />}
            {tab === 3 && (
              <AnalyticsTab
                ledger={ledger} expenses={expenses}
                loading={loadingAnalytics}
                periodStart={periodStart} periodEnd={periodEnd}
                onSetPeriod={(s, e) => { setPeriodStart(s); setPeriodEnd(e); }}
              />
            )}
          </>
        )}
      </div>

      {/* ── Edit transaction modal ────────────────────────────────────────── */}
      {editTx && (
        <EditTransactionModal
          tx={editTx}
          cid={cid}
          editorName={session?.displayName || session?.email || 'HR'}
          onClose={() => setEditTx(null)}
        />
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — OVERVIEW
// ─────────────────────────────────────────────────────────────────────────────
function OverviewTab({ balance, totalCredit, totalExpense, outstandingLoans, monthIn, monthOut, cashFlow, onEdit, onReverse, reversing }) {
  const isPos = balance >= 0;
  const lastSlip = cashFlow.find(d => d.type === 'cash_in');
  const recentIn  = cashFlow.filter(d => d.type === 'cash_in').slice(0, 5);
  const recentOut = cashFlow.filter(d => d.type === 'cash_out' || d.type === 'reversal').slice(0, 5);

  return (
    <div className="space-y-5">
      {/* ── Hero balance card ───────────────────────────────────────────── */}
      <div
        className="rounded-2xl p-6 text-white shadow-xl"
        style={{
          background: isPos
            ? 'linear-gradient(135deg, #065F46 0%, #059669 100%)'
            : 'linear-gradient(135deg, #991B1B 0%, #DC2626 100%)',
        }}
      >
        <div className="flex items-center justify-between mb-1">
          <div className="flex items-center gap-2 text-white/70 text-sm font-semibold">
            <Wallet size={16} /> Net Balance
          </div>
          <span className="text-xs font-bold px-2.5 py-1 rounded-full bg-white/15">
            {isPos ? 'Positive' : 'Negative'}
          </span>
        </div>
        <div className="text-4xl font-black tracking-tight mt-2">
          BDT {fmt(balance)}
        </div>
        <div className="text-white/50 text-xs mt-1">
          Credit − Expenses − Outstanding Loans
        </div>

        {/* Three-way breakdown */}
        <div className="grid grid-cols-3 gap-2 mt-5">
          <HeroSubStat
            label="Total Credit"
            value={`BDT ${fmt(totalCredit)}`}
            icon={<ArrowDownLeft size={14} />}
            color="rgba(134,239,172,1)"
          />
          <HeroSubStat
            label="Total Expenses"
            value={`BDT ${fmt(totalExpense)}`}
            icon={<ArrowUpRight size={14} />}
            color="rgba(252,165,165,1)"
          />
          <HeroSubStat
            label="Outstanding Loans"
            value={`BDT ${fmt(outstandingLoans)}`}
            icon={<Undo2 size={14} />}
            color="rgba(253,230,138,1)"
          />
        </div>
      </div>

      {/* ── This-month mini cards ────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-4">
        <MiniStatCard label="This Month In"  value={`BDT ${fmt(monthIn)}`}  icon={<ArrowDownLeft size={18} />}  color={CASH_IN} />
        <MiniStatCard label="This Month Out" value={`BDT ${fmt(monthOut)}`} icon={<ArrowUpRight size={18} />} color={CASH_OUT} />
      </div>

      {/* ── Last payment received ────────────────────────────────────────── */}
      {lastSlip && (
        <div>
          <SectionLabel>Last Payment Received</SectionLabel>
          <LastSlipCard data={lastSlip} onEdit={onEdit} />
        </div>
      )}

      {/* ── Recent cash-in ───────────────────────────────────────────────── */}
      {recentIn.length > 0 && (
        <div>
          <SectionLabel>Recent Cash In</SectionLabel>
          <div className="space-y-2 mt-2">
            {recentIn.map((d, i) => <CfTile key={d.id || i} data={d} onEdit={onEdit} />)}
          </div>
        </div>
      )}

      {/* ── Recent cash-out ──────────────────────────────────────────────── */}
      {recentOut.length > 0 && (
        <div>
          <SectionLabel>Recent Cash Out</SectionLabel>
          <div className="space-y-2 mt-2">
            {recentOut.map((d, i) => <CfTile key={d.id || i} data={d} onEdit={onEdit} onReverse={onReverse} reversing={reversing} />)}
          </div>
        </div>
      )}

      {cashFlow.length === 0 && (
        <div className="text-center py-16 text-gray-400">
          <ReceiptText size={40} className="mx-auto mb-3 opacity-20" />
          <p className="font-semibold">No transactions yet</p>
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — CREDITS
// ─────────────────────────────────────────────────────────────────────────────
function CreditsTab({ cashFlow, onEdit }) {
  const credits = cashFlow.filter(d => d.type === 'cash_in');
  const total   = credits.reduce((s, d) => s + n(d.amount), 0);

  if (credits.length === 0) {
    return (
      <div className="text-center py-20 text-gray-400">
        <Wallet size={48} className="mx-auto mb-3 opacity-20" style={{ color: BRAND }} />
        <p className="font-bold text-gray-500 text-base">No credits yet</p>
        <p className="text-sm mt-1">Approved payment slips will appear here</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* ── Total credits hero ───────────────────────────────────────────── */}
      <div
        className="rounded-2xl p-5 text-white shadow-lg flex items-center gap-4"
        style={{ background: 'linear-gradient(135deg, #065F46 0%, #059669 100%)' }}
      >
        <div className="w-12 h-12 rounded-xl flex items-center justify-center bg-white/15 shrink-0">
          <TrendingUp size={24} className="text-white" />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-white/70 text-xs font-semibold">Total Credits (BDT)</p>
          <p className="text-3xl font-black tracking-tight mt-0.5">৳ {fmt(total)}</p>
        </div>
        <div className="text-right shrink-0">
          <p className="text-2xl font-black">{credits.length}</p>
          <p className="text-white/60 text-xs">entries</p>
        </div>
      </div>

      {/* ── Credits list ─────────────────────────────────────────────────── */}
      <div className="space-y-3">
        {credits.map((d, i) => <CreditEntryCard key={d.id || i} data={d} onEdit={onEdit} />)}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — TRANSACTIONS
// ─────────────────────────────────────────────────────────────────────────────
function TransactionsTab({ cashFlow, onEdit, onReverse, reversing }) {
  const [filter, setFilter] = useState('all');

  const filters = [
    { key: 'all',      label: 'All' },
    { key: 'cash_in',  label: 'Cash In' },
    { key: 'cash_out', label: 'Cash Out' },
    { key: 'reversal', label: 'Reversal' },
  ];

  const filtered = filter === 'all'
    ? cashFlow
    : cashFlow.filter(d => d.type === filter);

  return (
    <div className="space-y-4">
      {/* ── Filter chips ─────────────────────────────────────────────────── */}
      <div className="flex flex-wrap gap-2">
        {filters.map(f => (
          <button
            key={f.key}
            onClick={() => setFilter(f.key)}
            className={`px-4 py-1.5 rounded-full text-xs font-bold transition-all ${
              filter === f.key
                ? 'text-white shadow-sm'
                : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
            }`}
            style={filter === f.key ? { background: BRAND } : {}}
          >
            {f.label}
            {f.key !== 'all' && (
              <span className={`ml-1.5 ${filter === f.key ? 'text-white/70' : 'text-gray-400'}`}>
                ({cashFlow.filter(d => d.type === f.key).length})
              </span>
            )}
          </button>
        ))}
      </div>

      {/* ── Transaction list ─────────────────────────────────────────────── */}
      {filtered.length === 0 ? (
        <div className="text-center py-16 text-gray-400">
          <ReceiptText size={40} className="mx-auto mb-3 opacity-20" />
          <p className="font-semibold">
            {filter === 'all' ? 'No transactions yet' : `No ${filter.replace('_', ' ')} transactions`}
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          {filtered.map((d, i) => <CfTile key={d.id || i} data={d} expanded onEdit={onEdit} onReverse={onReverse} reversing={reversing} />)}
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — ANALYTICS
// ─────────────────────────────────────────────────────────────────────────────
function AnalyticsTab({ ledger, expenses, loading, periodStart, periodEnd, onSetPeriod }) {
  const [showPicker, setShowPicker] = useState(false);
  const [customStart, setCustomStart] = useState('');
  const [customEnd,   setCustomEnd]   = useState('');

  // Aggregate ledger credits by account
  const { totalCredit, creditByAccount } = useMemo(() => {
    let total = 0;
    const byAcc = {};
    ledger.forEach(d => {
      const c   = n(d.credit);
      total    += c;
      const acc = (d.account || 'Other').trim() || 'Other';
      byAcc[acc] = (byAcc[acc] || 0) + c;
    });
    return { totalCredit: total, creditByAccount: byAcc };
  }, [ledger]);

  // Aggregate expenses by category
  const { totalExpense, expenseByCategory } = useMemo(() => {
    let total = 0;
    const byCat = {};
    expenses.forEach(d => {
      const amt = n(d.amount);
      total    += amt;
      const cat = (d.category || 'Other').trim() || 'Other';
      byCat[cat] = (byCat[cat] || 0) + amt;
    });
    return { totalExpense: total, expenseByCategory: byCat };
  }, [expenses]);

  const profit = totalCredit - totalExpense;

  // Period label
  const periodLabel = `${periodStart.toLocaleDateString('en-BD', { month: 'short', year: 'numeric' })}`;

  function applyPreset(type) {
    const now = new Date();
    if (type === 'this') {
      onSetPeriod(
        new Date(now.getFullYear(), now.getMonth(), 1),
        new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59),
      );
    } else if (type === 'last') {
      onSetPeriod(
        new Date(now.getFullYear(), now.getMonth() - 1, 1),
        new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59),
      );
    }
    setShowPicker(false);
  }

  function applyCustom() {
    if (!customStart || !customEnd) return;
    const s = new Date(customStart);
    const e = new Date(customEnd); e.setHours(23, 59, 59);
    onSetPeriod(s, e);
    setShowPicker(false);
  }

  // Chart data
  const creditPieData = Object.entries(creditByAccount)
    .sort((a, b) => b[1] - a[1])
    .map(([name, value], i) => ({ name, value, fill: CHART_PALETTE[i % CHART_PALETTE.length] }));

  const expensePieData = Object.entries(expenseByCategory)
    .sort((a, b) => b[1] - a[1])
    .map(([name, value], i) => ({ name, value, fill: CHART_PALETTE[i % CHART_PALETTE.length] }));

  const expenseBarData = Object.entries(expenseByCategory)
    .sort((a, b) => b[1] - a[1])
    .map(([name, value], i) => ({ name, value, fill: CHART_PALETTE[i % CHART_PALETTE.length] }));

  return (
    <div className="space-y-5">
      {/* ── Period picker ────────────────────────────────────────────────── */}
      <div className="relative">
        <button
          onClick={() => setShowPicker(v => !v)}
          className="flex items-center gap-2 w-full px-4 py-3 rounded-xl bg-white border border-gray-200 text-sm font-semibold text-gray-700 hover:bg-gray-50 transition"
        >
          <Calendar size={16} style={{ color: BRAND }} />
          <span className="flex-1 text-left">Period: {periodLabel}</span>
          <ChevronDown size={16} style={{ color: BRAND }} />
        </button>

        {showPicker && (
          <div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-xl border border-gray-200 shadow-xl z-20 p-4 space-y-2">
            <button onClick={() => applyPreset('this')} className="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg border border-gray-100 hover:bg-gray-50 text-sm font-semibold text-gray-700 transition">
              <Calendar size={15} style={{ color: BRAND }} /> This Month
            </button>
            <button onClick={() => applyPreset('last')} className="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg border border-gray-100 hover:bg-gray-50 text-sm font-semibold text-gray-700 transition">
              <RefreshCw size={15} style={{ color: BRAND }} /> Last Month
            </button>
            <div className="border-t border-gray-100 pt-2">
              <p className="text-xs text-gray-400 font-semibold mb-2">Custom Range</p>
              <div className="grid grid-cols-2 gap-2 mb-2">
                <input type="date" className="input text-sm" value={customStart} onChange={e => setCustomStart(e.target.value)} />
                <input type="date" className="input text-sm" value={customEnd}   onChange={e => setCustomEnd(e.target.value)} />
              </div>
              <button onClick={applyCustom} className="w-full py-2 rounded-lg text-sm font-bold text-white transition" style={{ background: BRAND }}>
                Apply Range
              </button>
            </div>
          </div>
        )}
      </div>

      {loading ? (
        <div className="flex justify-center py-16">
          <Loader2 size={24} className="animate-spin" style={{ color: BRAND }} />
        </div>
      ) : (
        <>
          {/* ── Summary cards ──────────────────────────────────────────────── */}
          <div className="grid grid-cols-2 gap-4">
            <MiniStatCard label="Ledger Credit"  value={`৳ ${fmt(totalCredit)}`}  icon={<TrendingUp size={18} />}   color={CASH_IN} />
            <MiniStatCard label="Expenses"       value={`৳ ${fmt(totalExpense)}`} icon={<TrendingDown size={18} />} color={CASH_OUT} />
          </div>
          <MiniStatCard
            label="Profit (Credit − Expense)"
            value={`৳ ${fmt(profit)}`}
            icon={profit >= 0 ? <ArrowUp size={18} /> : <ArrowDown size={18} />}
            color={profit >= 0 ? CASH_IN : CASH_OUT}
          />

          {/* ── Credit by Account pie ─────────────────────────────────────── */}
          {creditPieData.length > 0 && (
            <ChartCard title="Credit by Account">
              <PieChartWidget data={creditPieData} total={totalCredit} />
            </ChartCard>
          )}

          {/* ── Expense by Category pie ───────────────────────────────────── */}
          {expensePieData.length > 0 && (
            <>
              <ChartCard title="Expense by Category">
                <PieChartWidget data={expensePieData} total={totalExpense} />
              </ChartCard>
              <ChartCard title="Expense Breakdown (Bar)">
                <BarChartWidget data={expenseBarData} />
              </ChartCard>
            </>
          )}

          {creditPieData.length === 0 && expensePieData.length === 0 && (
            <div className="text-center py-16 text-gray-400">
              <TrendingUp size={40} className="mx-auto mb-3 opacity-20" />
              <p className="font-semibold">No data for this period</p>
            </div>
          )}
        </>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

function HeroSubStat({ label, value, icon, color }) {
  return (
    <div className="flex items-center gap-2 rounded-xl px-3 py-2.5 bg-white/12">
      <span style={{ color }}>{icon}</span>
      <div className="min-w-0">
        <p className="text-white/60 text-[10px] font-semibold">{label}</p>
        <p className="text-white text-xs font-black truncate mt-0.5">{value}</p>
      </div>
    </div>
  );
}

function MiniStatCard({ label, value, icon, color }) {
  return (
    <div
      className="flex items-center gap-3 p-4 rounded-xl bg-white border shadow-sm"
      style={{ borderColor: color + '33' }}
    >
      <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0" style={{ background: color + '1A' }}>
        <span style={{ color }}>{icon}</span>
      </div>
      <div className="min-w-0">
        <p className="text-xs text-gray-500 font-semibold">{label}</p>
        <p className="text-base font-black mt-0.5 truncate" style={{ color }}>{value}</p>
      </div>
    </div>
  );
}

function SectionLabel({ children }) {
  return (
    <p className="text-xs font-black uppercase tracking-wider text-gray-400 mb-2">{children}</p>
  );
}

// ── Cash-flow tile ────────────────────────────────────────────────────────────
function CfTile({ data: d, expanded = false, onEdit, onReverse, reversing }) {
  const type      = d.type || '';
  const amount    = n(d.amount);
  const currency  = d.currency || 'BDT';
  const desc      = d.description || '';
  const invoiceNo = d.invoiceNo || '';
  const edited    = d.amountEdited || false;
  const approvedBy = d.approvedByName || d.approvedBy || '';
  const date      = formatDate(d.createdAt);
  const isBeingReversed = reversing === d.id;

  const config = {
    cash_in:  { color: CASH_IN,  bgColor: '#DCFCE7', icon: <ArrowDownLeft size={18} />,  label: 'Cash In',  prefix: '+' },
    cash_out: { color: CASH_OUT, bgColor: '#FEE2E2', icon: <ArrowUpRight size={18} />,   label: 'Cash Out', prefix: '−' },
    reversal: { color: NEUTRAL,  bgColor: '#DBEAFE', icon: <Undo2 size={18} />,          label: 'Reversal (audit)', prefix: '' },
  }[type] || { color: '#6B7280', bgColor: '#F3F4F6', icon: <ReceiptText size={18} />, label: type, prefix: '' };

  return (
    <div
      className="flex items-start gap-3 p-3 rounded-xl bg-white border group"
      style={{ borderColor: config.color + '26' }}
    >
      <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0 mt-0.5" style={{ background: config.bgColor }}>
        <span style={{ color: config.color }}>{config.icon}</span>
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5 flex-wrap">
          <span className="text-xs font-black" style={{ color: config.color }}>{config.label}</span>
          {d._payrollDocId && type === 'cash_out' && (
            <span className="text-[9px] font-bold px-1.5 py-0.5 rounded" style={{ background: '#065F4615', color: '#065F46' }}>Payroll</span>
          )}
          {edited && (
            <span className="text-[9px] font-bold px-1.5 py-0.5 rounded" style={{ background: WARN + '1A', color: WARN }}>HR edited</span>
          )}
        </div>
        {invoiceNo && <p className="text-xs font-bold text-gray-700 mt-0.5">Invoice #{invoiceNo}</p>}
        {desc && (
          <p className="text-xs text-gray-400 mt-0.5 leading-relaxed" style={{ WebkitLineClamp: expanded ? 3 : 1, display: '-webkit-box', WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
            {desc}
          </p>
        )}
        <p className="text-[10px] text-gray-400 mt-0.5">
          {expanded && approvedBy ? `By ${approvedBy}  ·  ${date}` : date}
        </p>
      </div>
      <div className="flex flex-col items-end gap-1.5 shrink-0">
        <p className="text-sm font-black" style={{ color: config.color }}>
          {config.prefix}{currency} {fmt(amount)}
        </p>
        <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-all">
          {/* Reverse button — only on cash_out entries */}
          {type === 'cash_out' && onReverse && d.id && (
            <button
              onClick={() => onReverse(d)}
              disabled={isBeingReversed}
              className="flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-lg transition-all"
              style={{ background: NEUTRAL + '15', color: NEUTRAL }}
              title={d._payrollDocId ? "Reverse payroll payment (restores balance, reverts payroll to Pending, resets payslips)" : "Reverse this cash-out (deletes entry, restores balance)"}
            >
              {isBeingReversed ? <Loader2 size={9} className="animate-spin" /> : <Undo2 size={9} />}
              Reverse
            </button>
          )}
          {onEdit && d.id && type !== 'reversal' && (
            <button
              onClick={() => onEdit(d)}
              className="flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-lg transition-all"
              style={{ background: BRAND + '15', color: BRAND }}
              title="Edit transaction"
            >
              <Edit2 size={10} /> Edit
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

// ── Credit entry card (rich, with foreign currency display) ───────────────────
function CreditEntryCard({ data: d, onEdit }) {
  const amount    = n(d.amount);
  const currency  = (d.currency || 'BDT').toUpperCase();
  const isForeign = currency !== 'BDT';
  const invoiceNo = d.invoiceNo || '';
  const desc      = d.description || '';
  const approvedBy = d.approvedByName || d.approvedBy || '';
  const edited    = d.amountEdited || false;
  const date      = formatDate(d.createdAt);

  return (
    <div className="flex items-start gap-3 p-4 rounded-xl bg-white border shadow-sm group" style={{ borderColor: CASH_IN + '33' }}>
      <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0" style={{ background: '#DCFCE7' }}>
        <ArrowDownLeft size={20} style={{ color: CASH_IN }} />
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5 flex-wrap">
          <span className="text-xs font-black" style={{ color: CASH_IN }}>Cash In</span>
          {edited && (
            <span className="text-[9px] font-bold px-1.5 py-0.5 rounded" style={{ background: WARN + '1A', color: WARN }}>HR edited</span>
          )}
          {isForeign && (
            <span className="text-[9px] font-bold px-1.5 py-0.5 rounded" style={{ background: NEUTRAL + '1A', color: NEUTRAL }}>{currency}→BDT</span>
          )}
        </div>
        {invoiceNo && <p className="text-xs font-bold text-gray-700 mt-0.5">Invoice #{invoiceNo}</p>}
        {desc && <p className="text-xs text-gray-400 mt-0.5 line-clamp-1">{desc}</p>}
        <p className="text-[10px] text-gray-400 mt-0.5">
          {approvedBy ? `By ${approvedBy}  ·  ${date}` : date}
        </p>
      </div>
      <div className="flex flex-col items-end gap-1.5 shrink-0">
        <p className="text-base font-black" style={{ color: CASH_IN }}>
          ৳ {fmt(amount)}
        </p>
        {isForeign && (
          <p className="text-[10px] text-gray-400">{currency} {fmt(amount)}</p>
        )}
        {onEdit && d.id && (
          <button
            onClick={() => onEdit(d)}
            className="opacity-0 group-hover:opacity-100 flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-lg transition-all"
            style={{ background: BRAND + '15', color: BRAND }}
            title="Edit transaction"
          >
            <Edit2 size={10} /> Edit
          </button>
        )}
      </div>
    </div>
  );
}

// ── Last slip card ────────────────────────────────────────────────────────────
function LastSlipCard({ data: d, onEdit }) {
  const amount    = n(d.amount);
  const currency  = d.currency || 'BDT';
  const invoiceNo = d.invoiceNo || '—';
  const approvedBy = d.approvedByName || d.approvedBy || '—';
  const edited    = d.amountEdited || false;
  const date      = formatDate(d.createdAt);

  return (
    <div className="flex items-center gap-3 p-4 rounded-xl bg-white border shadow-sm group" style={{ borderColor: CASH_IN + '4D' }}>
      <div className="w-11 h-11 rounded-xl flex items-center justify-center shrink-0" style={{ background: CASH_IN + '1A' }}>
        <CheckCircle2 size={22} style={{ color: CASH_IN }} />
      </div>
      <div className="flex-1 min-w-0">
        <p className="font-bold text-gray-900 text-sm">Invoice #{invoiceNo}</p>
        <p className="text-xs text-gray-400 mt-0.5">{date}  ·  Approved by {approvedBy}</p>
        {edited && <p className="text-[10px] font-semibold mt-0.5" style={{ color: WARN }}>Amount adjusted by HR</p>}
      </div>
      <div className="flex flex-col items-end gap-1.5 shrink-0">
        <p className="text-base font-black" style={{ color: CASH_IN }}>{currency} {fmt(amount)}</p>
        <p className="text-[10px] text-gray-400">Cash In</p>
        {onEdit && d.id && (
          <button
            onClick={() => onEdit(d)}
            className="opacity-0 group-hover:opacity-100 flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-lg transition-all"
            style={{ background: BRAND + '15', color: BRAND }}
          >
            <Edit2 size={10} /> Edit
          </button>
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT TRANSACTION MODAL
// Edits cash_flow doc and atomically adjusts company_profile/main cashIn/cashOut
// ─────────────────────────────────────────────────────────────────────────────
function EditTransactionModal({ tx, cid, editorName, onClose }) {
  const oldAmount = n(tx.amount);
  const oldType   = tx.type || 'cash_in';

  const [form, setForm] = useState({
    amount:      String(oldAmount),
    type:        oldType,
    description: tx.description || '',
    invoiceNo:   tx.invoiceNo   || '',
    notes:       tx.hrNote      || '',
  });
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState('');
  const [confirm, setConfirm] = useState(false);

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  const newAmount = parseFloat(form.amount) || 0;
  const typeChanged   = form.type !== oldType;
  const amountChanged = Math.abs(newAmount - oldAmount) > 0.001;
  const hasChanges    = amountChanged || typeChanged ||
    form.description !== (tx.description || '') ||
    form.invoiceNo   !== (tx.invoiceNo   || '') ||
    form.notes       !== (tx.hrNote      || '');

  // Calculate the net delta to company_profile/main.
  // Only called when amount or type actually changed.
  //
  // New reversal model:
  //   cash_in  → cashIn  += amount
  //   cash_out → cashOut += amount
  //   reversal → audit-trail only; the original cash_out was DELETED when
  //              the reversal was created, so cashOut was already decremented.
  //              Editing a reversal entry only adjusts the audit amount — it
  //              does NOT re-touch cashOut.
  function getProfileDelta() {
    const deltas = { cashIn: 0, cashOut: 0 };

    // Step 1 — undo what the old entry contributed
    if (oldType === 'cash_in')  deltas.cashIn  -= oldAmount;
    if (oldType === 'cash_out') deltas.cashOut -= oldAmount;
    // reversal: audit-only, no cashOut adjustment

    // Step 2 — apply what the new entry should contribute
    if (form.type === 'cash_in')  deltas.cashIn  += newAmount;
    if (form.type === 'cash_out') deltas.cashOut += newAmount;
    // reversal: audit-only, no cashOut adjustment

    return deltas;
  }

  async function handleSave() {
    if (newAmount <= 0) { setError('Amount must be greater than zero.'); return; }
    if (!confirm && (amountChanged || typeChanged)) { setConfirm(true); return; }

    setSaving(true); setError('');
    try {
      const batch = writeBatch(db);

      // 1. Update the cash_flow document
      const cfRef = doc(db, 'data', cid, 'cash_flow', tx.id);
      batch.update(cfRef, {
        amount:       newAmount,
        type:         form.type,
        description:  form.description,
        invoiceNo:    form.invoiceNo,
        hrNote:       form.notes,
        // only flag as HR-edited when the financial values actually changed
        ...(amountChanged || typeChanged ? { amountEdited: true } : {}),
        editedBy:     editorName,
        editedAt:     serverTimestamp(),
        updatedAt:    serverTimestamp(),
      });

      // 2. Only touch company_profile/main when amount or type changed.
      //    Description / notes edits must NOT affect the running totals.
      if (amountChanged || typeChanged) {
        const { cashIn: dIn, cashOut: dOut } = getProfileDelta();
        const profileRef = doc(db, 'data', cid, 'company_profile', 'main');
        const profileUpdate = { updatedAt: serverTimestamp() };
        if (Math.abs(dIn)  > 0.001) profileUpdate.cashIn  = increment(dIn);
        if (Math.abs(dOut) > 0.001) profileUpdate.cashOut = increment(dOut);
        if (Object.keys(profileUpdate).length > 1) {
          batch.update(profileRef, profileUpdate);
        }
      }

      await batch.commit();
      onClose();
    } catch (e) {
      setError(e.message || 'Failed to save. Please try again.');
    } finally {
      setSaving(false);
    }
  }

  // Reversal type is not editable — reversals are created via the Reverse button
  // on cash_out entries. Editing a reversal only allows amount/description changes.
  const TYPE_CONFIG = oldType === 'reversal'
    ? { reversal: { label: 'Reversal (audit)', color: NEUTRAL, icon: <Undo2 size={14} /> } }
    : {
        cash_in:  { label: 'Cash In',  color: CASH_IN,  icon: <ArrowDownLeft size={14} /> },
        cash_out: { label: 'Cash Out', color: CASH_OUT, icon: <ArrowUpRight size={14} /> },
      };

  // Only compute profile delta when it will actually be applied
  const { cashIn: dIn, cashOut: dOut } = (amountChanged || typeChanged) ? getProfileDelta() : { cashIn: 0, cashOut: 0 };
  const balanceDelta = dIn - dOut;

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={onClose} />

      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl flex items-center justify-center" style={{ background: BRAND + '15' }}>
              <Edit2 size={16} style={{ color: BRAND }} />
            </div>
            <div>
              <p className="font-black text-gray-900">Edit Transaction</p>
              <p className="text-xs text-gray-400">
                {tx.invoiceNo ? `Invoice #${tx.invoiceNo}  ·  ` : ''}{formatDate(tx.createdAt)}
              </p>
            </div>
          </div>
          <button onClick={onClose} className="w-8 h-8 rounded-lg flex items-center justify-center text-gray-400 hover:bg-gray-100 transition">
            <X size={16} />
          </button>
        </div>

        <div className="p-5 space-y-4">
          {/* Original values banner */}
          <div className="rounded-xl p-3 flex items-center gap-3" style={{ background: BRAND + '0D', border: `1px solid ${BRAND}26` }}>
            <AlertCircle size={14} style={{ color: BRAND }} className="shrink-0" />
            <div className="text-xs text-gray-600">
              <span className="font-bold" style={{ color: BRAND }}>Original: </span>
              {TYPE_CONFIG[oldType]?.label || oldType} · {tx.currency || 'BDT'} {fmt(oldAmount)}
              {tx.amountEdited && <span className="ml-1 font-semibold" style={{ color: WARN }}>(previously edited)</span>}
            </div>
          </div>

          {/* Transaction type */}
          <div>
            <label className="text-xs font-black uppercase tracking-wider text-gray-500 mb-2 block">Transaction Type</label>
            {oldType === 'reversal' ? (
              <div className="flex items-center gap-2 p-3 rounded-xl border-2" style={{ borderColor: NEUTRAL + '40', background: NEUTRAL + '0A' }}>
                <Undo2 size={14} style={{ color: NEUTRAL }} />
                <span className="text-xs font-bold" style={{ color: NEUTRAL }}>Reversal (audit record — type cannot be changed)</span>
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-2">
                {Object.entries(TYPE_CONFIG).map(([key, cfg]) => (
                  <button key={key} type="button" onClick={() => set('type', key)}
                    className="flex flex-col items-center gap-1.5 py-2.5 rounded-xl border-2 text-xs font-bold transition-all"
                    style={form.type === key
                      ? { borderColor: cfg.color, background: cfg.color + '15', color: cfg.color }
                      : { borderColor: '#E5E7EB', color: '#6B7280' }
                    }>
                    {cfg.icon}
                    {cfg.label}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Amount */}
          <div>
            <label className="text-xs font-black uppercase tracking-wider text-gray-500 mb-1.5 block">Amount (BDT)</label>
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-sm font-bold">৳</span>
              <input
                className="w-full pl-8 pr-4 py-3 rounded-xl border border-gray-200 text-lg font-black focus:outline-none focus:ring-2 transition"
                style={{ '--tw-ring-color': BRAND }}
                type="number"
                min="0"
                step="0.01"
                value={form.amount}
                onChange={e => set('amount', e.target.value)}
              />
            </div>
            {amountChanged && (
              <p className="text-xs mt-1 font-semibold" style={{ color: WARN }}>
                Changed from {fmt(oldAmount)} → {fmt(newAmount)}
              </p>
            )}
          </div>

          {/* Description */}
          <div>
            <label className="text-xs font-black uppercase tracking-wider text-gray-500 mb-1.5 block">Description</label>
            <textarea
              className="w-full px-3 py-2.5 rounded-xl border border-gray-200 text-sm focus:outline-none focus:ring-2 resize-none transition"
              rows={2}
              value={form.description}
              onChange={e => set('description', e.target.value)}
              placeholder="Transaction description…"
            />
          </div>

          {/* Invoice No */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-black uppercase tracking-wider text-gray-500 mb-1.5 block">Invoice No.</label>
              <input
                className="w-full px-3 py-2.5 rounded-xl border border-gray-200 text-sm focus:outline-none focus:ring-2 transition"
                value={form.invoiceNo}
                onChange={e => set('invoiceNo', e.target.value)}
                placeholder="Optional"
              />
            </div>
            <div>
              <label className="text-xs font-black uppercase tracking-wider text-gray-500 mb-1.5 block">HR Note</label>
              <input
                className="w-full px-3 py-2.5 rounded-xl border border-gray-200 text-sm focus:outline-none focus:ring-2 transition"
                value={form.notes}
                onChange={e => set('notes', e.target.value)}
                placeholder="Optional note"
              />
            </div>
          </div>

          {/* Impact preview — shows what will change in company_profile/main */}
          {(amountChanged || typeChanged) && (
            <div className="rounded-xl p-4 space-y-2" style={{ background: '#F0FDF4', border: '1px solid #BBF7D0' }}>
              <p className="text-xs font-black uppercase tracking-wider" style={{ color: BRAND }}>Balance Impact</p>
              {Math.abs(dIn) > 0.001 && (
                <div className="flex justify-between text-xs">
                  <span className="text-gray-600">Cash In adjustment</span>
                  <span className="font-bold" style={{ color: dIn >= 0 ? CASH_IN : CASH_OUT }}>
                    {dIn >= 0 ? '+' : ''}{fmt(dIn)}
                  </span>
                </div>
              )}
              {Math.abs(dOut) > 0.001 && (
                <div className="flex justify-between text-xs">
                  <span className="text-gray-600">Cash Out adjustment</span>
                  <span className="font-bold" style={{ color: dOut >= 0 ? CASH_OUT : CASH_IN }}>
                    {dOut >= 0 ? '+' : ''}{fmt(dOut)}
                  </span>
                </div>
              )}
              <div className="border-t pt-2 flex justify-between text-sm font-black">
                <span className="text-gray-700">Net Balance change</span>
                <span style={{ color: balanceDelta >= 0 ? CASH_IN : CASH_OUT }}>
                  {balanceDelta >= 0 ? '+' : ''}{fmt(balanceDelta)}
                </span>
              </div>
            </div>
          )}

          {/* Confirm step for amount/type changes */}
          {confirm && (amountChanged || typeChanged) && (
            <div className="rounded-xl p-3 flex items-start gap-2" style={{ background: WARN + '0F', border: `1px solid ${WARN}33` }}>
              <AlertCircle size={14} style={{ color: WARN }} className="shrink-0 mt-0.5" />
              <p className="text-xs text-gray-700">
                <span className="font-bold" style={{ color: WARN }}>Confirm: </span>
                This will update the live balance. The change will be reflected immediately across all views.
                Click Save again to confirm.
              </p>
            </div>
          )}

          {error && (
            <p className="text-red-600 text-sm flex items-center gap-1.5">
              <AlertCircle size={13} /> {error}
            </p>
          )}

          {/* Actions */}
          <div className="flex gap-3 pt-1">
            <button onClick={onClose} className="flex-1 py-2.5 rounded-xl border border-gray-200 text-sm font-semibold text-gray-600 hover:bg-gray-50 transition">
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={saving || !hasChanges}
              className="flex-1 py-2.5 rounded-xl text-sm font-black text-white flex items-center justify-center gap-2 transition disabled:opacity-40"
              style={{ background: saving ? BRAND + '80' : BRAND }}
            >
              {saving ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
              {saving ? 'Saving…' : confirm ? 'Confirm Save' : 'Save Changes'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ── Chart card wrapper ────────────────────────────────────────────────────────
function ChartCard({ title, children }) {
  return (
    <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm">
      <p className="font-black text-gray-800 text-sm mb-4">{title}</p>
      {children}
    </div>
  );
}

// ── Pie chart ─────────────────────────────────────────────────────────────────
function PieChartWidget({ data, total }) {
  const CustomTooltip = ({ active, payload }) => {
    if (!active || !payload?.length) return null;
    const { name, value } = payload[0].payload;
    const pct = total > 0 ? (value / total * 100).toFixed(1) : 0;
    return (
      <div className="bg-white border border-gray-200 rounded-lg px-3 py-2 shadow-lg text-xs">
        <p className="font-bold text-gray-800">{name}</p>
        <p className="text-gray-500">৳ {fmt(value)}  ({pct}%)</p>
      </div>
    );
  };

  return (
    <div>
      <ResponsiveContainer width="100%" height={220}>
        <PieChart>
          <Pie data={data} cx="50%" cy="50%" outerRadius={90} dataKey="value" label={({ name, percent }) => percent > 0.05 ? `${(percent * 100).toFixed(0)}%` : ''} labelLine={false}>
            {data.map((entry, i) => <Cell key={i} fill={entry.fill} />)}
          </Pie>
          <RechartTooltip content={<CustomTooltip />} />
        </PieChart>
      </ResponsiveContainer>
      {/* Legend */}
      <div className="space-y-1.5 mt-2">
        {data.map((entry, i) => {
          const pct = total > 0 ? (entry.value / total * 100) : 0;
          return (
            <div key={i} className="flex items-center gap-2 text-xs">
              <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ background: entry.fill }} />
              <span className="flex-1 text-gray-600 truncate">{entry.name}</span>
              <span className="font-semibold text-gray-700">{pct.toFixed(pct >= 10 ? 0 : 1)}%</span>
              <span className="text-gray-400">৳ {fmt(entry.value)}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── Bar chart ─────────────────────────────────────────────────────────────────
function BarChartWidget({ data }) {
  const CustomTooltip = ({ active, payload, label }) => {
    if (!active || !payload?.length) return null;
    return (
      <div className="bg-white border border-gray-200 rounded-lg px-3 py-2 shadow-lg text-xs">
        <p className="font-bold text-gray-800">{label}</p>
        <p className="text-gray-500">৳ {fmt(payload[0].value)}</p>
      </div>
    );
  };

  return (
    <ResponsiveContainer width="100%" height={220}>
      <BarChart data={data} margin={{ top: 4, right: 4, left: 0, bottom: 40 }}>
        <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#F1F5F9" />
        <XAxis
          dataKey="name"
          tick={{ fontSize: 10, fontWeight: 600 }}
          angle={-35}
          textAnchor="end"
          interval={0}
        />
        <YAxis
          tick={{ fontSize: 10 }}
          tickFormatter={fmtShort}
          width={44}
        />
        <RechartTooltip content={<CustomTooltip />} />
        <Bar dataKey="value" radius={[6, 6, 0, 0]}>
          {data.map((entry, i) => <Cell key={i} fill={entry.fill} />)}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
