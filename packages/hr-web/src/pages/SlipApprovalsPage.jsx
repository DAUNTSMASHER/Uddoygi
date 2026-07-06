import { useEffect, useState, useCallback, useRef } from 'react';
import {
  Loader2, CheckCircle, XCircle, Eye, FileText,
  Clock, AlertCircle, ExternalLink,
  RefreshCw, ZoomIn, ZoomOut, Maximize2, Minimize2,
  Search, X, Info, Download,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import {
  col, docRef, subscribe, update, orderBy,
  serverTimestamp, Timestamp,
} from '../lib/db';
import {
  formatDate, formatDateTime, formatCurrency,
  statusBadge, timeAgo,
} from '../lib/utils';
import { Modal } from '../components/ui/Modal';
import {
  doc, writeBatch, increment, collection,
} from 'firebase/firestore';
import { db } from '../firebase';

// ── helpers ───────────────────────────────────────────────────────────────────
function fmtAmt(amount, currency = 'BDT') {
  if (amount == null || isNaN(amount)) return '—';
  return new Intl.NumberFormat('en-BD', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount) + ' ' + currency;
}

function ConfBadge({ pct }) {
  if (pct == null) return null;
  const p = Math.round(pct * 100);
  const cls = p >= 75 ? 'bg-green-50 text-green-700 border-green-200'
    : p >= 45 ? 'bg-yellow-50 text-yellow-700 border-yellow-200'
    : 'bg-red-50 text-red-700 border-red-200';
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold border ${cls}`}>
      {p}% confidence
    </span>
  );
}

const TAB_LABELS = {
  pending_hr: 'Pending',
  verified:   'Verified',
  rejected:   'Rejected',
};

// ─────────────────────────────────────────────────────────────────────────────
// MAIN PAGE
// ─────────────────────────────────────────────────────────────────────────────
export function SlipApprovalsPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [slips, setSlips]       = useState([]);
  const [loading, setLoading]   = useState(true);
  const [tab, setTab]           = useState('pending_hr');
  const [search, setSearch]     = useState('');
  const [reviewing, setReviewing] = useState(null); // slip object being reviewed

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(
      col(cid, 'payment_slips'),
      (docs) => { setSlips(docs); setLoading(false); },
      [orderBy('createdAt', 'desc')],
    );
    return unsub;
  }, [cid]);

  const pending  = slips.filter(s => s.status === 'pending_hr').length;
  const verified = slips.filter(s => s.status === 'verified').length;
  const rejected = slips.filter(s => s.status === 'rejected').length;

  const tabSlips = slips.filter(s => s.status === tab);
  const filtered = tabSlips.filter(s => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      (s.submittedByName || '').toLowerCase().includes(q) ||
      (s.submittedBy     || '').toLowerCase().includes(q) ||
      (s.invoiceNo       || '').toLowerCase().includes(q) ||
      (s.title           || '').toLowerCase().includes(q) ||
      (s.ref             || '').toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-5">
      {/* ── Header ─────────────────────────────────────────────────────── */}
      <div className="page-header">
        <div>
          <h2 className="page-title">Payment Slip Approvals</h2>
          <p className="page-sub">Review and approve payment slips submitted by the marketing team</p>
        </div>
      </div>

      {/* ── Stat cards ─────────────────────────────────────────────────── */}
      <div className="grid grid-cols-3 gap-4">
        <button
          onClick={() => setTab('pending_hr')}
          className={`stat-card text-left transition-all ${tab === 'pending_hr' ? 'ring-2 ring-yellow-400' : ''}`}
        >
          <div className="stat-icon bg-yellow-50 text-yellow-600"><Clock size={20} /></div>
          <div>
            <p className="stat-label">Pending Review</p>
            <p className="stat-value text-xl">{pending}</p>
          </div>
        </button>
        <button
          onClick={() => setTab('verified')}
          className={`stat-card text-left transition-all ${tab === 'verified' ? 'ring-2 ring-green-400' : ''}`}
        >
          <div className="stat-icon bg-green-50 text-green-600"><CheckCircle size={20} /></div>
          <div>
            <p className="stat-label">Verified</p>
            <p className="stat-value text-xl">{verified}</p>
          </div>
        </button>
        <button
          onClick={() => setTab('rejected')}
          className={`stat-card text-left transition-all ${tab === 'rejected' ? 'ring-2 ring-red-400' : ''}`}
        >
          <div className="stat-icon bg-red-50 text-red-600"><XCircle size={20} /></div>
          <div>
            <p className="stat-label">Rejected</p>
            <p className="stat-value text-xl">{rejected}</p>
          </div>
        </button>
      </div>

      {/* ── Tab bar ────────────────────────────────────────────────────── */}
      <div className="flex items-center gap-2 border-b border-gray-200 pb-0">
        {Object.entries(TAB_LABELS).map(([key, label]) => {
          const count = key === 'pending_hr' ? pending : key === 'verified' ? verified : rejected;
          return (
            <button
              key={key}
              onClick={() => setTab(key)}
              className={`px-4 py-2 text-sm font-semibold border-b-2 transition-colors -mb-px ${
                tab === key
                  ? 'border-[#065F46] text-[#065F46]'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              {label}
              {count > 0 && (
                <span className={`ml-1.5 px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                  tab === key ? 'bg-[#065F46] text-white' : 'bg-gray-100 text-gray-600'
                }`}>
                  {count}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* ── Search ─────────────────────────────────────────────────────── */}
      <div className="relative max-w-sm">
        <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          className="input pl-8 pr-8 text-sm w-full"
          placeholder="Search by name, invoice, reference…"
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
        {search && (
          <button onClick={() => setSearch('')} className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
            <X size={13} />
          </button>
        )}
      </div>

      {/* ── Table ──────────────────────────────────────────────────────── */}
      {loading ? (
        <div className="flex justify-center py-16">
          <Loader2 size={24} className="animate-spin text-[#065F46]" />
        </div>
      ) : (
        <div className="card">
          <div className="table-wrap border-0 rounded-none">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Submitted By</th>
                  <th>Invoice</th>
                  <th>Slip Date</th>
                  <th>Amount</th>
                  <th>Method</th>
                  <th>Confidence</th>
                  <th>Submitted</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={9} className="text-center py-12 text-gray-400">
                      <FileText size={32} className="mx-auto mb-2 opacity-30" />
                      No {TAB_LABELS[tab].toLowerCase()} slips
                    </td>
                  </tr>
                ) : filtered.map((s) => (
                  <SlipRow
                    key={s.id}
                    slip={s}
                    cid={cid}
                    session={session}
                    onReview={() => setReviewing(s)}
                  />
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── Review modal ───────────────────────────────────────────────── */}
      {reviewing && (
        <ReviewModal
          slip={reviewing}
          cid={cid}
          session={session}
          onClose={() => setReviewing(null)}
        />
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE ROW
// ─────────────────────────────────────────────────────────────────────────────
function SlipRow({ slip: s, cid, session, onReview }) {
  const isPending  = s.status === 'pending_hr';
  const isVerified = s.status === 'verified';

  const displayAmount = s.isForeignCurrency
    ? `${fmtAmt(s.amount, s.currency)} → ${fmtAmt(s.amountBDT ?? s.convertedAmountBDT, 'BDT')}`
    : fmtAmt(s.amountBDT ?? s.amount, 'BDT');

  return (
    <tr>
      <td>
        <div className="font-semibold text-gray-900 text-sm">{s.submittedByName || s.submittedBy || '—'}</div>
        {s.title && <div className="text-xs text-gray-400 truncate max-w-[160px]">{s.title}</div>}
      </td>
      <td className="font-mono text-xs text-gray-700">#{s.invoiceNo || '—'}</td>
      <td className="text-sm">{formatDate(s.slipDate)}</td>
      <td>
        <div className="font-bold text-sm text-gray-900">
          {s.isForeignCurrency ? (
            <span className="flex flex-col gap-0.5">
              <span className="text-blue-700">{fmtAmt(s.amount, s.currency)}</span>
              <span className="text-xs text-gray-500">≈ {fmtAmt(s.amountBDT ?? s.convertedAmountBDT, 'BDT')}</span>
            </span>
          ) : (
            fmtAmt(s.amountBDT ?? s.amount, 'BDT')
          )}
        </div>
      </td>
      <td className="text-sm text-gray-600">{s.method || '—'}</td>
      <td><ConfBadge pct={s.extractionConfidence} /></td>
      <td className="text-xs text-gray-500">{timeAgo(s.createdAt)}</td>
      <td>
        <SlipStatusBadge status={s.status} />
      </td>
      <td>
        <div className="flex gap-1 items-center">
          <button
            onClick={onReview}
            className="btn-icon btn-sm"
            title="Review slip"
          >
            <Eye size={13} />
          </button>
          {isPending && (
            <span className="text-[10px] font-semibold text-yellow-600 bg-yellow-50 border border-yellow-200 px-1.5 py-0.5 rounded">
              Needs review
            </span>
          )}
          {isVerified && s.confirmedAmount != null && (
            <span className="text-[10px] font-semibold text-green-700 bg-green-50 border border-green-200 px-1.5 py-0.5 rounded">
              ৳{new Intl.NumberFormat('en-BD').format(s.confirmedAmount)}
            </span>
          )}
        </div>
      </td>
    </tr>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BADGE (maps payment_slip statuses)
// ─────────────────────────────────────────────────────────────────────────────
function SlipStatusBadge({ status }) {
  const map = {
    pending_hr: { cls: 'badge badge-yellow', label: 'Pending HR' },
    verified:   { cls: 'badge badge-green',  label: 'Verified'   },
    rejected:   { cls: 'badge badge-red',    label: 'Rejected'   },
  };
  const { cls, label } = map[status] || { cls: 'badge badge-gray', label: status || '—' };
  return <span className={cls}>{label}</span>;
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEW MODAL
// Full review sheet: document viewer, conversion info, editable amount,
// approve (with confirmed amount → cashIn) and reject (with reason).
// Mirrors the Flutter _ReviewSheet logic exactly.
// ─────────────────────────────────────────────────────────────────────────────
function ReviewModal({ slip: s, cid, session, onClose }) {
  const isPending = s.status === 'pending_hr';

  // BDT amount to confirm — pre-filled with amountBDT (conversion-aware)
  const defaultBDT = s.amountBDT ?? s.convertedAmountBDT ?? s.amount ?? 0;
  const [confirmedAmount, setConfirmedAmount] = useState(
    defaultBDT > 0 ? defaultBDT.toFixed(2) : '',
  );
  const [hrNote, setHrNote]         = useState('');
  const [rejectReason, setRejectReason] = useState('');
  const [showReject, setShowReject] = useState(false);
  const [saving, setSaving]         = useState(false);
  const [error, setError]           = useState('');

  const confirmedNum = parseFloat((confirmedAmount || '').replace(/,/g, '')) || 0;
  const originalBDT  = defaultBDT;
  const amountEdited = Math.abs(confirmedNum - originalBDT) > 0.001;

  // ── Approve ───────────────────────────────────────────────────────────────
  const handleApprove = useCallback(async () => {
    if (confirmedNum <= 0) {
      setError('Please enter a valid BDT amount before approving.');
      return;
    }
    setError('');
    setSaving(true);
    try {
      const batch = writeBatch(db);
      const now   = serverTimestamp();
      const fileExpiresAt = Timestamp.fromDate(
        new Date(Date.now() + 24 * 60 * 60 * 1000),
      );

      // 1. Mark slip verified
      batch.update(docRef(cid, 'payment_slips', s.id), {
        status:              'verified',
        confirmedAmount:     confirmedNum,
        submittedAmount:     s.amount,
        submittedAmountBDT:  originalBDT,
        amountEdited,
        hrNote:              hrNote.trim(),
        verifiedBy:          session?.email || '',
        verifiedByName:      session?.displayName || session?.name || session?.email || '',
        verifiedAt:          now,
        fileExpiresAt,
        updatedAt:           now,
      });

      // 2. Update invoice → Payment Taken
      if (s.invoiceId) {
        batch.update(
          doc(db, 'data', cid, 'invoices', s.invoiceId),
          {
            status:          'Payment Taken',
            statusStep:      2,
            slipStatus:      'verified',
            slipVerifiedAt:  now,
            payment: {
              taken:               true,
              amount:              confirmedNum,
              submittedAmount:     s.amount,
              submittedAmountBDT:  originalBDT,
              currency:            s.currency || 'BDT',
              method:              s.method || '',
              ref:                 s.ref || '',
              verifiedByHr:        true,
              amountEdited,
              isForeignCurrency:   s.isForeignCurrency || false,
            },
            updatedAt: now,
          },
        );
      }

      // 3. Increment cashIn on company profile (always BDT)
      batch.update(
        doc(db, 'data', cid, 'company_profile', 'main'),
        {
          cashIn:              increment(confirmedNum),
          lastCashInAt:        now,
          lastCashInAmount:    confirmedNum,
          lastCashInCurrency:  'BDT',
          lastCashInInvoice:   s.invoiceNo || '',
        },
      );

      // 4. Cash-flow entry (always BDT)
      const cfRef = doc(collection(db, 'data', cid, 'cash_flow'));
      batch.set(cfRef, {
        type:                'cash_in',
        amount:              confirmedNum,
        submittedAmount:     s.amount,
        submittedAmountBDT:  originalBDT,
        amountEdited,
        currency:            'BDT',
        originalCurrency:    s.currency || 'BDT',
        isForeignCurrency:   s.isForeignCurrency || false,
        method:              s.method || '',
        invoiceId:           s.invoiceId || '',
        invoiceNo:           s.invoiceNo || '',
        slipId:              s.id,
        description:         `Payment received for Invoice #${s.invoiceNo || '—'}`
                             + (s.isForeignCurrency ? ` (${s.currency} ${fmtAmt(s.amount, s.currency)} → BDT)` : '')
                             + (amountEdited ? ' (amount corrected by HR)' : ''),
        approvedBy:          session?.email || '',
        approvedByName:      session?.displayName || session?.name || session?.email || '',
        hrNote:              hrNote.trim(),
        createdAt:           now,
      });

      // 5. Ledger credit entry
      const ledgerRef = doc(collection(db, 'data', cid, 'ledger'));
      batch.set(ledgerRef, {
        credit:      confirmedNum,
        account:     'Payment Received',
        description: `Invoice #${s.invoiceNo || '—'} — slip verified`
                     + (s.isForeignCurrency ? ` (${s.currency} ${fmtAmt(s.amount, s.currency)})` : '')
                     + (amountEdited ? ' (HR adjusted)' : ''),
        currency:    'BDT',
        invoiceId:   s.invoiceId || '',
        invoiceNo:   s.invoiceNo || '',
        slipId:      s.id,
        verifiedBy:  session?.email || '',
        createdAt:   now,
      });

      // 6. Notification to marketing agent
      const notifRef = doc(collection(db, 'data', cid, 'notifications'));
      batch.set(notifRef, {
        type:        'slip_verified',
        title:       'Payment Slip Verified ✓',
        body:        `Your payment slip for Invoice #${s.invoiceNo || '—'} has been verified. `
                     + `Confirmed amount: BDT ${new Intl.NumberFormat('en-BD', { minimumFractionDigits: 2 }).format(confirmedNum)}`
                     + (s.isForeignCurrency ? ` (from ${s.currency} ${fmtAmt(s.amount, s.currency)})` : '') + '.'
                     + (amountEdited ? ` (HR adjusted from BDT ${new Intl.NumberFormat('en-BD', { minimumFractionDigits: 2 }).format(originalBDT)})` : ''),
        invoiceId:   s.invoiceId || '',
        invoiceNo:   s.invoiceNo || '',
        targetEmail: s.submittedBy || '',
        read:        false,
        createdAt:   now,
      });

      await batch.commit();
      onClose();
    } catch (e) {
      setError('Approval failed: ' + e.message);
    } finally {
      setSaving(false);
    }
  }, [confirmedNum, originalBDT, amountEdited, hrNote, s, cid, session, onClose]);

  // ── Reject ────────────────────────────────────────────────────────────────
  const handleReject = useCallback(async () => {
    const reason = rejectReason.trim() || 'No reason provided';
    setSaving(true);
    setError('');
    try {
      const batch = writeBatch(db);
      const now   = serverTimestamp();

      batch.update(docRef(cid, 'payment_slips', s.id), {
        status:          'rejected',
        hrNote:          reason,
        rejectedBy:      session?.email || '',
        rejectedByName:  session?.displayName || session?.name || session?.email || '',
        rejectedAt:      now,
        updatedAt:       now,
      });

      if (s.invoiceId) {
        batch.update(
          doc(db, 'data', cid, 'invoices', s.invoiceId),
          { slipStatus: 'rejected', updatedAt: now },
        );
      }

      const notifRef = doc(collection(db, 'data', cid, 'notifications'));
      batch.set(notifRef, {
        type:        'slip_rejected',
        title:       'Payment Slip Rejected',
        body:        `Your payment slip for Invoice #${s.invoiceNo || '—'} was rejected. Reason: ${reason}. Please re-submit a valid slip.`,
        invoiceId:   s.invoiceId || '',
        invoiceNo:   s.invoiceNo || '',
        targetEmail: s.submittedBy || '',
        read:        false,
        createdAt:   now,
      });

      await batch.commit();
      onClose();
    } catch (e) {
      setError('Rejection failed: ' + e.message);
    } finally {
      setSaving(false);
    }
  }, [rejectReason, s, cid, session, onClose]);

  const slipDate = formatDate(s.slipDate);
  const convRate = s.conversionRate;

  return (
    <Modal title="Review Payment Slip" onClose={onClose} xl>
      <div className="space-y-5">

        {/* ── Slip meta header ─────────────────────────────────────────── */}
        <div className="flex items-start gap-4 p-4 rounded-xl bg-gray-50 border border-gray-100">
          <div className="w-10 h-10 rounded-xl bg-[#065F46]/10 flex items-center justify-center shrink-0">
            <FileText size={18} className="text-[#065F46]" />
          </div>
          <div className="flex-1 min-w-0">
            <div className="font-bold text-gray-900 text-sm truncate">{s.title || 'Payment Slip'}</div>
            <div className="text-xs text-gray-500 mt-0.5">
              Invoice <span className="font-semibold text-gray-700">#{s.invoiceNo || '—'}</span>
              {' · '}Submitted by <span className="font-semibold text-gray-700">{s.submittedByName || s.submittedBy || '—'}</span>
              {' · '}{timeAgo(s.createdAt)}
            </div>
          </div>
          <SlipStatusBadge status={s.status} />
        </div>

        {/* ── Document viewer ───────────────────────────────────────────── */}
        <DocViewer
          url={s.fileUrl}
          isPdf={s.isPdf}
          fileName={s.fileName}
        />

        {/* ── Slip details grid ─────────────────────────────────────────── */}
        <div>
          <p className="label mb-2">Slip Details</p>
          <div className="rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
            {[
              ['Submitted By',   s.submittedByName || s.submittedBy],
              ['Invoice Total',  s.invoiceTotal != null ? fmtAmt(s.invoiceTotal, 'BDT') : null],
              ['Submitted Amount', s.isForeignCurrency
                ? `${fmtAmt(s.amount, s.currency)} (foreign currency)`
                : fmtAmt(s.amount, 'BDT')],
              s.isForeignCurrency && ['BDT Equivalent', fmtAmt(s.amountBDT ?? s.convertedAmountBDT, 'BDT')],
              s.isForeignCurrency && convRate && ['Exchange Rate', `1 ${s.currency} = ${Number(convRate).toFixed(4)} BDT${s.conversionIsLive ? ' (live)' : ' (estimated)'}`],
              ['Payment Method',  s.method],
              ['Slip Date',       slipDate],
              s.ref && ['Reference / TxID', s.ref],
              s.extractedProvider && ['Detected Provider', s.extractedProvider],
              s.extractedReferenceCompany && ['Paid To', s.extractedReferenceCompany],
              s.note && ['Note', s.note],
              s.extractionConfidence != null && ['AI Confidence', `${Math.round(s.extractionConfidence * 100)}%`],
            ].filter(Boolean).map(([k, v]) => v ? (
              <div key={k} className="flex items-start justify-between px-4 py-2.5 text-sm bg-white">
                <span className="text-gray-500 font-medium shrink-0 mr-4">{k}</span>
                <span className="font-semibold text-gray-900 text-right">{v}</span>
              </div>
            ) : null)}
          </div>
        </div>

        {/* ── Foreign currency notice ───────────────────────────────────── */}
        {s.isForeignCurrency && (
          <div className="flex gap-3 p-3 rounded-xl bg-blue-50 border border-blue-200 text-sm">
            <Info size={16} className="text-blue-600 shrink-0 mt-0.5" />
            <div className="text-blue-800">
              <span className="font-bold">Foreign currency slip: </span>
              The marketing team submitted{' '}
              <span className="font-bold">{fmtAmt(s.amount, s.currency)}</span>.
              The BDT equivalent (
              <span className="font-bold">{fmtAmt(s.amountBDT ?? s.convertedAmountBDT, 'BDT')}</span>)
              has been pre-filled below. Verify against the document before approving.
            </div>
          </div>
        )}

        {/* ── Confirm amount (editable, only for pending) ───────────────── */}
        {isPending && (
          <div className={`rounded-xl border-2 p-4 transition-colors ${amountEdited ? 'border-orange-300 bg-orange-50' : 'border-green-300 bg-green-50'}`}>
            <div className="flex items-center gap-2 mb-3">
              {amountEdited
                ? <AlertCircle size={14} className="text-orange-600" />
                : <CheckCircle size={14} className="text-green-600" />}
              <span className={`text-xs font-bold ${amountEdited ? 'text-orange-700' : 'text-green-700'}`}>
                {amountEdited
                  ? 'Amount edited by HR'
                  : s.isForeignCurrency
                    ? 'BDT equivalent pre-filled — verify before approving'
                    : 'Confirm the BDT amount to accept'}
              </span>
              {amountEdited && (
                <button
                  onClick={() => setConfirmedAmount(defaultBDT.toFixed(2))}
                  className="ml-auto text-xs font-bold text-blue-600 hover:underline"
                >
                  Reset
                </button>
              )}
            </div>
            <div className="flex items-stretch rounded-lg overflow-hidden border border-gray-200">
              <div className="bg-gray-100 px-3 flex items-center text-sm font-bold text-gray-700 border-r border-gray-200">
                BDT
              </div>
              <input
                type="number"
                step="0.01"
                min="0"
                value={confirmedAmount}
                onChange={e => setConfirmedAmount(e.target.value)}
                className="flex-1 px-3 py-3 text-lg font-black text-gray-900 bg-white outline-none focus:ring-2 focus:ring-[#065F46] focus:ring-inset"
                placeholder="0.00"
              />
            </div>
            <p className="text-xs text-gray-500 mt-1.5">
              Only this BDT amount will be added to cash-in. The invoice total is{' '}
              <span className="font-semibold">{fmtAmt(s.invoiceTotal, 'BDT')}</span>.
            </p>
          </div>
        )}

        {/* ── Verified summary (read-only) ──────────────────────────────── */}
        {s.status === 'verified' && (
          <div className="rounded-xl border border-green-200 bg-green-50 p-4 space-y-2 text-sm">
            <div className="flex items-center gap-2 font-bold text-green-800 mb-1">
              <CheckCircle size={15} /> Verified
            </div>
            {[
              ['Confirmed Amount', fmtAmt(s.confirmedAmount, 'BDT')],
              s.amountEdited && ['Original Submitted', fmtAmt(s.submittedAmountBDT ?? s.amount, 'BDT')],
              ['Verified By', s.verifiedByName || s.verifiedBy],
              ['Verified At', formatDateTime(s.verifiedAt)],
              s.hrNote && ['HR Note', s.hrNote],
            ].filter(Boolean).map(([k, v]) => v ? (
              <div key={k} className="flex justify-between">
                <span className="text-green-700">{k}</span>
                <span className="font-semibold text-green-900">{v}</span>
              </div>
            ) : null)}
          </div>
        )}

        {/* ── Rejected summary (read-only) ──────────────────────────────── */}
        {s.status === 'rejected' && (
          <div className="rounded-xl border border-red-200 bg-red-50 p-4 space-y-2 text-sm">
            <div className="flex items-center gap-2 font-bold text-red-800 mb-1">
              <XCircle size={15} /> Rejected
            </div>
            {[
              ['Rejected By', s.rejectedByName || s.rejectedBy],
              ['Rejected At', formatDateTime(s.rejectedAt)],
              s.hrNote && ['Reason', s.hrNote],
            ].filter(Boolean).map(([k, v]) => v ? (
              <div key={k} className="flex justify-between">
                <span className="text-red-700">{k}</span>
                <span className="font-semibold text-red-900">{v}</span>
              </div>
            ) : null)}
          </div>
        )}

        {/* ── HR note (for pending) ─────────────────────────────────────── */}
        {isPending && !showReject && (
          <div>
            <label className="label mb-1.5">HR Note (optional)</label>
            <textarea
              className="input w-full text-sm resize-none"
              rows={2}
              placeholder="Add a note for the marketing team…"
              value={hrNote}
              onChange={e => setHrNote(e.target.value)}
            />
          </div>
        )}

        {/* ── Reject reason panel ───────────────────────────────────────── */}
        {isPending && showReject && (
          <div className="rounded-xl border border-red-200 bg-red-50 p-4 space-y-3">
            <div className="flex items-center gap-2 text-sm font-bold text-red-700">
              <XCircle size={14} /> Rejection Reason
            </div>
            <textarea
              className="input w-full text-sm resize-none border-red-200 focus:ring-red-400"
              rows={3}
              placeholder="Explain why this slip is being rejected…"
              value={rejectReason}
              onChange={e => setRejectReason(e.target.value)}
              autoFocus
            />
            <div className="flex gap-2">
              <button
                onClick={() => { setShowReject(false); setRejectReason(''); }}
                className="btn-secondary flex-1 justify-center text-sm"
                disabled={saving}
              >
                Cancel
              </button>
              <button
                onClick={handleReject}
                disabled={saving}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2 rounded-xl bg-red-600 text-white text-sm font-bold hover:bg-red-700 transition disabled:opacity-50"
              >
                {saving ? <Loader2 size={14} className="animate-spin" /> : <XCircle size={14} />}
                Confirm Reject
              </button>
            </div>
          </div>
        )}

        {/* ── Error ─────────────────────────────────────────────────────── */}
        {error && (
          <p className="text-red-600 text-sm bg-red-50 border border-red-200 rounded-lg px-3 py-2">
            {error}
          </p>
        )}

        {/* ── Action buttons (pending only) ─────────────────────────────── */}
        {isPending && !showReject && (
          <div className="flex gap-3 pt-1 border-t border-gray-100">
            <button
              onClick={() => setShowReject(true)}
              disabled={saving}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl border-2 border-red-300 text-red-600 text-sm font-bold hover:bg-red-50 transition disabled:opacity-50"
            >
              <XCircle size={15} /> Reject
            </button>
            <button
              onClick={handleApprove}
              disabled={saving || confirmedNum <= 0}
              className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-[#065F46] text-white text-sm font-bold hover:bg-[#054a38] transition disabled:opacity-50"
            >
              {saving
                ? <Loader2 size={15} className="animate-spin" />
                : <CheckCircle size={15} />}
              Approve — BDT {confirmedNum > 0
                ? new Intl.NumberFormat('en-BD', { minimumFractionDigits: 2 }).format(confirmedNum)
                : '0.00'}
            </button>
          </div>
        )}
      </div>
    </Modal>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DOC VIEWER
// Renders the attached payment slip document inline.
//  • Images  → tall preview (max-h-96) + fullscreen lightbox on click
//  • PDFs    → embedded <iframe> with open-in-tab fallback
//  • Loading → skeleton placeholder
//  • Error   → friendly message with retry + open-in-tab link
// ─────────────────────────────────────────────────────────────────────────────
function DocViewer({ url, isPdf, fileName }) {
  const [imgState, setImgState]   = useState('loading'); // loading | loaded | error
  const [lightbox, setLightbox]   = useState(false);
  const [pdfLoaded, setPdfLoaded] = useState(false);
  const [pdfError, setPdfError]   = useState(false);
  const [retryKey, setRetryKey]   = useState(0);

  // Reset state when url changes
  useEffect(() => {
    setImgState('loading');
    setPdfLoaded(false);
    setPdfError(false);
  }, [url, retryKey]);

  if (!url) {
    return (
      <div className="flex flex-col items-center justify-center gap-2 py-8 rounded-xl border border-dashed border-gray-200 bg-gray-50 text-gray-400">
        <FileText size={28} className="opacity-40" />
        <p className="text-sm font-medium">No document attached</p>
      </div>
    );
  }

  // Check if file has expired (url exists but is an empty string or we get 403)
  // We handle this via the onError handler below.

  return (
    <>
      <div>
        <div className="flex items-center justify-between mb-2">
          <p className="label">Attached Document</p>
          <div className="flex items-center gap-1.5">
            {!isPdf && imgState === 'loaded' && (
              <button
                onClick={() => setLightbox(true)}
                className="flex items-center gap-1 text-xs text-[#065F46] font-semibold hover:underline"
                title="View fullscreen"
              >
                <Maximize2 size={12} /> Fullscreen
              </button>
            )}
            <a
              href={url}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1 text-xs text-gray-500 font-semibold hover:text-gray-700"
              title="Open in new tab"
            >
              <ExternalLink size={12} /> Open
            </a>
            <a
              href={url}
              download={fileName || 'payment-slip'}
              className="flex items-center gap-1 text-xs text-gray-500 font-semibold hover:text-gray-700"
              title="Download"
            >
              <Download size={12} /> Download
            </a>
          </div>
        </div>

        {isPdf ? (
          /* ── PDF: embedded iframe ──────────────────────────────────── */
          <div className="rounded-xl overflow-hidden border border-gray-200 bg-gray-50">
            {/* Toolbar row */}
            <div className="flex items-center gap-2 px-3 py-2 bg-gray-100 border-b border-gray-200">
              <FileText size={14} className="text-red-500 shrink-0" />
              <span className="text-xs font-semibold text-gray-700 truncate flex-1">
                {fileName || 'Payment Slip PDF'}
              </span>
              <a
                href={url}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-1 text-xs text-[#065F46] font-bold hover:underline shrink-0"
              >
                <ExternalLink size={11} /> Open in tab
              </a>
            </div>

            {/* iframe — uses Google Docs viewer as a reliable cross-origin PDF renderer */}
            {!pdfError ? (
              <div className="relative">
                {!pdfLoaded && (
                  <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-gray-50 z-10">
                    <Loader2 size={20} className="animate-spin text-[#065F46]" />
                    <p className="text-xs text-gray-400 font-medium">Loading PDF…</p>
                  </div>
                )}
                <iframe
                  key={retryKey}
                  src={`https://docs.google.com/gview?url=${encodeURIComponent(url)}&embedded=true`}
                  title="Payment slip PDF"
                  className="w-full"
                  style={{ height: '520px', border: 'none' }}
                  onLoad={() => setPdfLoaded(true)}
                  onError={() => { setPdfError(true); setPdfLoaded(true); }}
                />
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center gap-3 py-10 text-gray-400">
                <FileText size={32} className="opacity-30" />
                <p className="text-sm font-medium text-gray-500">Could not embed PDF preview</p>
                <div className="flex gap-2">
                  <button
                    onClick={() => { setPdfError(false); setRetryKey(k => k + 1); }}
                    className="flex items-center gap-1.5 text-xs font-bold text-[#065F46] border border-[#065F46]/30 px-3 py-1.5 rounded-lg hover:bg-[#065F46]/5 transition"
                  >
                    <RefreshCw size={11} /> Retry
                  </button>
                  <a
                    href={url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-1.5 text-xs font-bold text-gray-600 border border-gray-200 px-3 py-1.5 rounded-lg hover:bg-gray-50 transition"
                  >
                    <ExternalLink size={11} /> Open directly
                  </a>
                </div>
              </div>
            )}
          </div>
        ) : (
          /* ── Image ─────────────────────────────────────────────────── */
          <div className="rounded-xl overflow-hidden border border-gray-200 bg-gray-50">
            {/* Loading skeleton */}
            {imgState === 'loading' && (
              <div className="flex flex-col items-center justify-center gap-2 py-16 bg-gray-100 animate-pulse">
                <div className="w-16 h-16 rounded-xl bg-gray-200" />
                <div className="h-3 w-24 rounded bg-gray-200" />
              </div>
            )}

            {/* Error state */}
            {imgState === 'error' && (
              <div className="flex flex-col items-center justify-center gap-3 py-10 text-gray-400">
                <AlertCircle size={28} className="text-red-400" />
                <p className="text-sm font-medium text-gray-500">Could not load image</p>
                <p className="text-xs text-gray-400 text-center max-w-xs">
                  The file may have expired (documents are deleted 24 hours after submission) or the URL is unavailable.
                </p>
                <div className="flex gap-2 mt-1">
                  <button
                    onClick={() => setRetryKey(k => k + 1)}
                    className="flex items-center gap-1.5 text-xs font-bold text-[#065F46] border border-[#065F46]/30 px-3 py-1.5 rounded-lg hover:bg-[#065F46]/5 transition"
                  >
                    <RefreshCw size={11} /> Retry
                  </button>
                  <a
                    href={url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-1.5 text-xs font-bold text-gray-600 border border-gray-200 px-3 py-1.5 rounded-lg hover:bg-gray-50 transition"
                  >
                    <ExternalLink size={11} /> Open directly
                  </a>
                </div>
              </div>
            )}

            {/* The actual image */}
            <img
              key={retryKey}
              src={url}
              alt="Payment slip"
              className={`w-full object-contain cursor-zoom-in transition-opacity duration-200 ${
                imgState === 'loaded' ? 'opacity-100' : 'opacity-0 absolute pointer-events-none'
              }`}
              style={{ maxHeight: imgState === 'loaded' ? '480px' : undefined }}
              onLoad={() => setImgState('loaded')}
              onError={() => setImgState('error')}
              onClick={() => imgState === 'loaded' && setLightbox(true)}
            />

            {/* Click-to-zoom hint */}
            {imgState === 'loaded' && (
              <div className="flex items-center justify-center gap-1.5 py-1.5 bg-gray-100 border-t border-gray-200 text-xs text-gray-400 font-medium">
                <ZoomIn size={11} /> Click image to view fullscreen
              </div>
            )}
          </div>
        )}
      </div>

      {/* ── Fullscreen lightbox ─────────────────────────────────────────── */}
      {lightbox && (
        <div
          className="fixed inset-0 z-[200] flex items-center justify-center"
          style={{ background: 'rgba(0,0,0,0.92)', backdropFilter: 'blur(6px)' }}
          onClick={() => setLightbox(false)}
        >
          {/* Controls */}
          <div className="absolute top-4 right-4 flex items-center gap-2 z-10">
            <a
              href={url}
              target="_blank"
              rel="noopener noreferrer"
              onClick={e => e.stopPropagation()}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/10 text-white text-xs font-semibold hover:bg-white/20 transition"
            >
              <ExternalLink size={12} /> Open full size
            </a>
            <a
              href={url}
              download={fileName || 'payment-slip'}
              onClick={e => e.stopPropagation()}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/10 text-white text-xs font-semibold hover:bg-white/20 transition"
            >
              <Download size={12} /> Download
            </a>
            <button
              onClick={() => setLightbox(false)}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/10 text-white text-xs font-semibold hover:bg-white/20 transition"
            >
              <Minimize2 size={12} /> Close
            </button>
          </div>

          {/* Image — fills viewport, click outside to close */}
          <img
            src={url}
            alt="Payment slip fullscreen"
            className="max-w-[92vw] max-h-[92vh] object-contain rounded-xl shadow-2xl"
            onClick={e => e.stopPropagation()}
          />

          {/* Close hint */}
          <p className="absolute bottom-4 left-1/2 -translate-x-1/2 text-white/40 text-xs font-medium">
            Click outside to close
          </p>
        </div>
      )}
    </>
  );
}
