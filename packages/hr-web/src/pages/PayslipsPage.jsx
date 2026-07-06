// PayslipsPage — payslip documents generated from payroll
// Each payslip is one document per employee per month.
// "Send" button marks status as 'sent' and updates the notification.
// Departments: HR, Marketing, Factory, Admin, R&D — all receive payslips here.

import { useEffect, useState, useMemo } from 'react';
import {
  Loader2, FileText, Download, Search, X, Send,
  CheckCircle2, Clock, Users, DollarSign, ChevronDown,
  ChevronUp, Bell, Eye, Undo2,
} from 'lucide-react';
import { doc, updateDoc, serverTimestamp, addDoc, collection } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, orderBy } from '../lib/db';
import { formatCurrency, formatDate, statusBadge } from '../lib/utils';
import { EmployeeAvatar } from '../components/ui/EmployeePicker';

const BRAND = '#065F46';

const STATUS_CONFIG = {
  generated: { label: 'Generated', color: '#2563EB', bg: '#DBEAFE' },
  sent:      { label: 'Sent',      color: '#16A34A', bg: '#DCFCE7' },
  viewed:    { label: 'Viewed',    color: '#7C3AED', bg: '#EDE9FE' },
  reversed:  { label: 'Reversed',  color: '#DC2626', bg: '#FEE2E2' },
};

export function PayslipsPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [payslips,   setPayslips]   = useState([]);
  const [loading,    setLoading]    = useState(true);
  const [search,     setSearch]     = useState('');
  const [monthFilter, setMonthFilter] = useState('');
  const [deptFilter,  setDeptFilter]  = useState('');
  const [preview,    setPreview]    = useState(null); // payslip to preview

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'payslips'), (docs) => {
      setPayslips(docs);
      setLoading(false);
    }, [orderBy('createdAt', 'desc')]);
    return unsub;
  }, [cid]);

  // Unique months and departments for filters
  const months = useMemo(() =>
    [...new Set(payslips.map(p => p.month).filter(Boolean))].sort().reverse()
  , [payslips]);

  const departments = useMemo(() =>
    [...new Set(payslips.map(p => (p.department || '').trim()).filter(Boolean))].sort()
  , [payslips]);

  const filtered = payslips.filter(p => {
    const q = search.toLowerCase();
    const matchSearch = !q ||
      (p.employeeName || p.name || '').toLowerCase().includes(q) ||
      (p.month || '').toLowerCase().includes(q) ||
      (p.department || '').toLowerCase().includes(q);
    const matchMonth = !monthFilter || p.month === monthFilter;
    const matchDept  = !deptFilter  || (p.department || '').trim() === deptFilter;
    return matchSearch && matchMonth && matchDept;
  });

  const activePayslips = filtered.filter(p => p.status !== 'reversed');
  const totalNet       = activePayslips.reduce((s, p) => s + (p.netSalary || 0), 0);
  const sentCount      = activePayslips.filter(p => p.status === 'sent' || p.status === 'viewed').length;
  const pendingCount   = activePayslips.filter(p => p.status === 'generated' || !p.status).length;
  const reversedCount  = filtered.filter(p => p.status === 'reversed').length;

  async function handleSend(payslip) {
    try {
      // Mark payslip as sent
      const ref = doc(db, 'data', cid, 'payslips', payslip.id);
      await updateDoc(ref, {
        status: 'sent',
        sentAt: serverTimestamp(),
        sentBy: session?.email || '',
      });

      // Send notification to employee
      await addDoc(collection(db, 'data', cid, 'notifications'), {
        type:         'payslip_sent',
        recipientId:  payslip.employeeId || '',
        recipientName: payslip.employeeName || '',
        title:        `Payslip Ready — ${payslip.month}`,
        body:         `Your payslip for ${payslip.month} (${formatCurrency(payslip.netSalary)}) is now available. Please check your account.`,
        month:        payslip.month,
        amount:       payslip.netSalary || 0,
        read:         false,
        createdAt:    serverTimestamp(),
      });
    } catch (e) {
      alert('Failed to send: ' + e.message);
    }
  }

  async function handleSendAll() {
    const unsent = filtered.filter(p => (p.status === 'generated' || !p.status) && p.status !== 'reversed');
    if (unsent.length === 0) { alert('All payslips already sent.'); return; }
    if (!confirm(`Send ${unsent.length} payslip${unsent.length !== 1 ? 's' : ''}?`)) return;
    for (const p of unsent) await handleSend(p);
  }

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h2 className="page-title">Pay Slips</h2>
          <p className="page-sub">
            {payslips.length} payslips · {sentCount} sent · {pendingCount} pending
            {reversedCount > 0 && ` · ${reversedCount} reversed`}
          </p>
        </div>
        {pendingCount > 0 && (
          <button onClick={handleSendAll} className="btn-primary">
            <Send size={15} /> Send All ({pendingCount})
          </button>
        )}
      </div>

      {/* KPI strip */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="stat-card">
          <div className="stat-icon bg-[#065F46]/10 text-[#065F46]"><DollarSign size={20} /></div>
          <div><p className="stat-label">Total Amount</p><p className="stat-value text-lg">{formatCurrency(totalNet)}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-blue-50 text-blue-600"><FileText size={20} /></div>
          <div><p className="stat-label">Total Payslips</p><p className="stat-value">{filtered.length}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-green-50 text-green-600"><CheckCircle2 size={20} /></div>
          <div><p className="stat-label">Sent</p><p className="stat-value">{sentCount}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-yellow-50 text-yellow-600"><Clock size={20} /></div>
          <div><p className="stat-label">Pending</p><p className="stat-value">{pendingCount}</p></div>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 items-center">
        {/* Search */}
        <div className="relative flex-1 min-w-[200px] max-w-sm">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input className="input pl-9" placeholder="Search employee, month…" value={search} onChange={e => setSearch(e.target.value)} />
          {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={14} /></button>}
        </div>

        {/* Month filter */}
        {months.length > 0 && (
          <select className="input w-auto text-sm" value={monthFilter} onChange={e => setMonthFilter(e.target.value)}>
            <option value="">All Months</option>
            {months.map(m => <option key={m} value={m}>{m}</option>)}
          </select>
        )}

        {/* Dept filter chips */}
        <div className="flex flex-wrap gap-1.5">
          <button
            onClick={() => setDeptFilter('')}
            className={`px-3 py-1 rounded-full text-xs font-bold transition ${!deptFilter ? 'bg-[#065F46] text-white' : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'}`}
          >
            All
          </button>
          {departments.map(d => (
            <button
              key={d}
              onClick={() => setDeptFilter(d === deptFilter ? '' : d)}
              className={`px-3 py-1 rounded-full text-xs font-bold transition capitalize ${deptFilter === d ? 'bg-[#065F46] text-white' : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'}`}
            >
              {d}
            </button>
          ))}
        </div>
      </div>

      {/* Payslips table */}
      {loading ? (
        <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div>
      ) : filtered.length === 0 ? (
        <div className="card p-12 text-center">
          <FileText size={40} className="mx-auto mb-3 text-gray-200" />
          <p className="font-semibold text-gray-500">No payslips found</p>
          <p className="text-sm text-gray-400 mt-1">Payslips are generated when you pay a payroll</p>
        </div>
      ) : (
        <div className="card">
          <div className="table-wrap border-0 rounded-none">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Employee</th>
                  <th>Department</th>
                  <th>Month</th>
                  <th>Basic</th>
                  <th>Allowances</th>
                  <th>Deductions</th>
                  <th>Net Salary</th>
                  <th>Generated</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(p => {
                  const cfg = STATUS_CONFIG[p.status] || STATUS_CONFIG.generated;
                  const isSent     = p.status === 'sent' || p.status === 'viewed';
                  const isReversed = p.status === 'reversed';
                  return (
                    <tr key={p.id}>
                      <td>
                        <div className="flex items-center gap-2.5">
                          <EmployeeAvatar emp={{ _displayName: p.employeeName || p.name }} size={8} />
                          <div>
                            <p className="font-semibold text-gray-900 text-sm">{p.employeeName || p.name || '—'}</p>
                            {p.designation && <p className="text-xs text-gray-400">{p.designation}</p>}
                          </div>
                        </div>
                      </td>
                      <td>
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold capitalize"
                          style={{ background: BRAND + '15', color: BRAND }}>
                          {p.department || '—'}
                        </span>
                      </td>
                      <td className="font-semibold text-gray-700">{p.month || '—'}</td>
                      <td className="text-gray-600">{formatCurrency(p.basicSalary || 0)}</td>
                      <td className="text-emerald-600">
                        {p.allowances > 0 ? `+${formatCurrency(p.allowances)}` : '—'}
                      </td>
                      <td className="text-red-500">
                        {p.deductions > 0 ? `−${formatCurrency(p.deductions)}` : '—'}
                      </td>
                      <td>
                        <span className="font-black text-sm" style={{ color: BRAND }}>{formatCurrency(p.netSalary || 0)}</span>
                      </td>
                      <td className="text-gray-400 text-xs">{formatDate(p.createdAt)}</td>
                      <td>
                        <span
                          className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-bold"
                          style={{ background: cfg.bg, color: cfg.color }}
                        >
                          {isReversed ? <Undo2 size={10} /> : isSent ? <CheckCircle2 size={10} /> : <Clock size={10} />}
                          {cfg.label}
                        </span>
                      </td>
                      <td>
                        <div className="flex items-center gap-1">
                          {/* Preview */}
                          <button
                            onClick={() => setPreview(p)}
                            className="btn-icon btn-sm"
                            title="Preview payslip"
                          >
                            <Eye size={13} />
                          </button>

                          {/* Send / Reversed indicator */}
                          {isReversed ? (
                            <span className="inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full"
                              style={{ background: '#FEE2E2', color: '#DC2626' }}>
                              <Undo2 size={9} /> Reversed
                            </span>
                          ) : !isSent ? (
                            <button
                              onClick={() => handleSend(p)}
                              className="flex items-center gap-1 text-xs font-bold px-2.5 py-1 rounded-lg transition"
                              style={{ background: BRAND + '15', color: BRAND }}
                              title="Send payslip to employee"
                            >
                              <Send size={11} /> Send
                            </button>
                          ) : (
                            <span className="text-[10px] text-gray-400 font-semibold">
                              {p.sentAt ? formatDate(p.sentAt) : 'Sent'}
                            </span>
                          )}

                          {/* Download if PDF exists */}
                          {p.pdfUrl && (
                            <a href={p.pdfUrl} target="_blank" rel="noopener noreferrer" className="btn-icon btn-sm" title="Download PDF">
                              <Download size={13} />
                            </a>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Footer total */}
          <div className="px-4 py-3 border-t border-gray-100 flex items-center justify-between bg-gray-50 rounded-b-xl">
            <span className="text-xs font-semibold text-gray-500">
              {filtered.length} payslip{filtered.length !== 1 ? 's' : ''}
              {monthFilter ? ` · ${monthFilter}` : ''}
              {deptFilter ? ` · ${deptFilter}` : ''}
            </span>
            <span className="text-sm font-black" style={{ color: BRAND }}>
              Total: {formatCurrency(totalNet)}
            </span>
          </div>
        </div>
      )}

      {/* Payslip preview modal */}
      {preview && (
        <PayslipPreview
          payslip={preview}
          onSend={() => { handleSend(preview); setPreview(null); }}
          onClose={() => setPreview(null)}
        />
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYSLIP PREVIEW MODAL — A4-style payslip view
// ─────────────────────────────────────────────────────────────────────────────
function PayslipPreview({ payslip: p, onSend, onClose }) {
  const isSent = p.status === 'sent' || p.status === 'viewed';
  const basic  = p.basicSalary || 0;
  const allow  = p.allowances  || 0;
  const deduct = p.deductions  || 0;
  const net    = p.netSalary   || 0;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">

        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl flex items-center justify-center" style={{ background: BRAND + '15' }}>
              <FileText size={16} style={{ color: BRAND }} />
            </div>
            <div>
              <p className="font-black text-gray-900">Payslip Preview</p>
              <p className="text-xs text-gray-400">{p.month}</p>
            </div>
          </div>
          <button onClick={onClose} className="w-8 h-8 rounded-lg flex items-center justify-center text-gray-400 hover:bg-gray-100">
            <X size={15} />
          </button>
        </div>

        {/* Payslip body */}
        <div className="p-5 space-y-4">

          {/* Company + Employee header */}
          <div className="rounded-xl p-4" style={{ background: 'linear-gradient(135deg, #065F46 0%, #059669 100%)' }}>
            <p className="text-white/70 text-xs font-semibold mb-1">SALARY SLIP</p>
            <p className="text-white font-black text-lg">{p.month}</p>
            <div className="mt-3 flex items-center gap-3">
              <EmployeeAvatar emp={{ _displayName: p.employeeName || p.name }} size={10} />
              <div>
                <p className="text-white font-bold">{p.employeeName || p.name || '—'}</p>
                <p className="text-white/70 text-xs">
                  {p.designation && `${p.designation} · `}{p.department}
                  {p.employeeId && ` · ID: ${p.employeeId}`}
                </p>
              </div>
            </div>
          </div>

          {/* Earnings */}
          <div>
            <p className="text-xs font-black uppercase tracking-wider text-gray-400 mb-2">Earnings</p>
            <div className="rounded-xl border border-gray-100 overflow-hidden">
              <div className="flex justify-between px-4 py-2.5 bg-gray-50">
                <span className="text-xs text-gray-500">Basic Salary</span>
                <span className="text-xs font-bold text-gray-800">{formatCurrency(basic)}</span>
              </div>
              {allow > 0 && (
                <div className="flex justify-between px-4 py-2.5 border-t border-gray-100">
                  <span className="text-xs text-gray-500">Allowances</span>
                  <span className="text-xs font-bold text-emerald-600">+{formatCurrency(allow)}</span>
                </div>
              )}
              <div className="flex justify-between px-4 py-2.5 border-t border-gray-100 bg-emerald-50">
                <span className="text-xs font-bold text-emerald-700">Total Earnings</span>
                <span className="text-xs font-black text-emerald-700">{formatCurrency(basic + allow)}</span>
              </div>
            </div>
          </div>

          {/* Deductions */}
          {deduct > 0 && (
            <div>
              <p className="text-xs font-black uppercase tracking-wider text-gray-400 mb-2">Deductions</p>
              <div className="rounded-xl border border-gray-100 overflow-hidden">
                <div className="flex justify-between px-4 py-2.5 bg-gray-50">
                  <span className="text-xs text-gray-500">Total Deductions</span>
                  <span className="text-xs font-bold text-red-500">−{formatCurrency(deduct)}</span>
                </div>
              </div>
            </div>
          )}

          {/* Net salary */}
          <div className="rounded-xl p-4 flex items-center justify-between" style={{ background: BRAND + '0D', border: `1.5px solid ${BRAND}33` }}>
            <span className="font-black text-gray-900">Net Salary</span>
            <span className="text-2xl font-black" style={{ color: BRAND }}>{formatCurrency(net)}</span>
          </div>

          {/* Status */}
          <div className="flex items-center justify-between text-xs text-gray-400">
            <span>Generated: {formatDate(p.createdAt)}</span>
            {isSent && p.sentAt && <span>Sent: {formatDate(p.sentAt)}</span>}
          </div>

          {/* Actions */}
          <div className="flex gap-3 pt-1">
            <button onClick={onClose} className="flex-1 btn-secondary">Close</button>
            {!isSent && (
              <button
                onClick={onSend}
                className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-black text-white"
                style={{ background: BRAND }}
              >
                <Send size={14} /> Send to Employee
              </button>
            )}
            {isSent && (
              <div className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-bold text-green-700 bg-green-50">
                <CheckCircle2 size={14} /> Already Sent
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
