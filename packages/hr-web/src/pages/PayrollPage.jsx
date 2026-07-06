// PayrollPage — full payroll workflow:
//   1. Create payroll for a month → add employees → salary auto-filled from 'salaries' collection
//   2. Save draft OR "Pay Bill" → sends notification to each employee → success dialog
//   3. Success dialog instructs to go to Payslips section
//   4. Payslip documents auto-created in 'payslips' collection per employee
//
// Firestore:
//   payrolls/{id}  — payroll batch (month, status, employees[], totalAmount)
//   payslips/{id}  — one per employee per month (employeeId, month, netSalary, status)
//   notifications/{id} — one per employee when paid

import { useEffect, useState, useMemo } from 'react';
import {
  Plus, Search, X, Loader2, DollarSign, Users, Trash2,
  CheckCircle2, Send, AlertCircle, ChevronDown, Edit2,
  FileText, ArrowRight, Banknote, Bell, TrendingDown, Undo2,
} from 'lucide-react';
import { doc, writeBatch, serverTimestamp, collection, getDocs, query, where } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, update, remove, orderBy, fetchAll, increment } from '../lib/db';
import { formatCurrency, formatDate, statusBadge } from '../lib/utils';
import { Modal } from '../components/ui/Modal';
import { EmployeeAvatar } from '../components/ui/EmployeePicker';

const BRAND = '#065F46';

function currentMonthLabel() {
  return new Date().toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────
export function PayrollPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';

  const [payrolls,  setPayrolls]  = useState([]);
  const [employees, setEmployees] = useState([]);
  const [salaries,  setSalaries]  = useState([]);
  const [search,    setSearch]    = useState('');
  const [loading,   setLoading]   = useState(true);
  const [modal,     setModal]     = useState(null); // null | 'create' | payroll-object
  const [success,   setSuccess]   = useState(null); // { month, count } after pay

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'payrolls'), (docs) => {
      setPayrolls(docs);
      setLoading(false);
    }, [orderBy('createdAt', 'desc')]);
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

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'salaries'), docs => setSalaries(docs));
    return unsub;
  }, [cid]);

  const filtered = payrolls.filter(p => {
    const q = search.toLowerCase();
    return !q ||
      (p.month || '').toLowerCase().includes(q) ||
      (p.status || '').toLowerCase().includes(q) ||
      (p.employees || []).some(e => (e.employeeName || '').toLowerCase().includes(q));
  });

  const totalPaid    = payrolls.filter(p => p.status === 'paid').reduce((s, p) => s + (p.totalAmount || 0), 0);
  const totalPending = payrolls.filter(p => p.status !== 'paid').reduce((s, p) => s + (p.totalAmount || 0), 0);

  async function handleDelete(payroll) {
    const isPaid = payroll.status === 'paid';
    const msg = isPaid
      ? `Delete payroll for ${payroll.month}?\n\nThis will also:\n• Remove all payslips for this payroll\n• Remove all expense entries\n• Reverse the cash-out from the balance`
      : `Delete draft payroll for ${payroll.month}?\n\nThis will also remove any associated payslips.`;
    if (!confirm(msg)) return;

    try {
      const batch = writeBatch(db);

      // 1. Delete the payroll document itself
      batch.delete(doc(db, 'data', cid, 'payrolls', payroll.id));

      // 2. Delete all payslips linked to this payroll
      const payslipsSnap = await getDocs(
        query(collection(db, 'data', cid, 'payslips'), where('payrollId', '==', payroll.id))
      );
      payslipsSnap.docs.forEach(d => batch.delete(d.ref));

      // 3. If paid: also delete expenses + cash_flow entries and reverse cashOut
      if (isPaid) {
        // Delete expense entries
        const expSnap = await getDocs(
          query(collection(db, 'data', cid, 'expenses'), where('_payrollDocId', '==', payroll.id))
        );
        expSnap.docs.forEach(d => batch.delete(d.ref));

        // Delete cash_flow entries
        const cfSnap = await getDocs(
          query(collection(db, 'data', cid, 'cash_flow'), where('_payrollDocId', '==', payroll.id))
        );
        cfSnap.docs.forEach(d => batch.delete(d.ref));

        // Reverse the cashOut increment on company_profile
        const totalAmt = payroll.totalAmount || 0;
        if (totalAmt > 0) {
          const profileRef = doc(db, 'data', cid, 'company_profile', 'main');
          batch.update(profileRef, {
            cashOut:   increment(-totalAmt),
            updatedAt: serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      alert('Delete failed: ' + e.message);
    }
  }

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h2 className="page-title">Payroll</h2>
          <p className="page-sub">{payrolls.length} payrolls · {employees.length} employees</p>
        </div>
        <button onClick={() => setModal('create')} className="btn-primary">
          <Plus size={16} /> Create Payroll
        </button>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
        <div className="stat-card">
          <div className="stat-icon bg-green-50 text-green-600"><DollarSign size={20} /></div>
          <div><p className="stat-label">Total Paid</p><p className="stat-value text-xl">{formatCurrency(totalPaid)}</p></div>
        </div>
        <div className="stat-card">
          <div className="stat-icon bg-yellow-50 text-yellow-600"><DollarSign size={20} /></div>
          <div><p className="stat-label">Pending</p><p className="stat-value text-xl">{formatCurrency(totalPending)}</p></div>
        </div>
        <div className="stat-card col-span-2 lg:col-span-1">
          <div className="stat-icon bg-blue-50 text-blue-600"><Users size={20} /></div>
          <div><p className="stat-label">Total Records</p><p className="stat-value text-xl">{payrolls.length}</p></div>
        </div>
      </div>

      {/* Search */}
      <div className="relative max-w-sm">
        <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input className="input pl-9" placeholder="Search month, employee…" value={search} onChange={e => setSearch(e.target.value)} />
        {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><X size={14} /></button>}
      </div>

      {/* Payroll list */}
      {loading ? (
        <div className="flex justify-center py-16"><Loader2 size={24} className="animate-spin text-[#065F46]" /></div>
      ) : filtered.length === 0 ? (
        <div className="card p-12 text-center">
          <FileText size={40} className="mx-auto mb-3 text-gray-200" />
          <p className="font-semibold text-gray-500">No payroll records yet</p>
          <p className="text-sm text-gray-400 mt-1">Create a payroll to get started</p>
          <button onClick={() => setModal('create')} className="btn-primary mt-4 mx-auto">
            <Plus size={15} /> Create First Payroll
          </button>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map(p => (
            <PayrollCard
              key={p.id}
              payroll={p}
              cid={cid}
              session={session}
              onEdit={() => setModal(p)}
              onDelete={() => handleDelete(p)}
              onPaid={(month, count) => setSuccess({ month, count })}
            />
          ))}
        </div>
      )}

      {/* Create / Edit modal */}
      {modal && (
        <PayrollModal
          payroll={modal === 'create' ? null : modal}
          cid={cid}
          employees={employees}
          salaries={salaries}
          session={session}
          onClose={() => setModal(null)}
          onPaid={(month, count) => { setModal(null); setSuccess({ month, count }); }}
        />
      )}

      {/* Success dialog */}
      {success && (
        <SuccessDialog
          month={success.month}
          count={success.count}
          onClose={() => setSuccess(null)}
        />
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYROLL CARD — expandable row showing employees
// ─────────────────────────────────────────────────────────────────────────────
function PayrollCard({ payroll: p, cid, session, onEdit, onDelete, onPaid }) {
  const [expanded,   setExpanded]   = useState(false);
  const [paying,     setPaying]     = useState(false);
  const [reversing,  setReversing]  = useState(false);

  const emps   = p.employees || [];
  const isPaid = p.status === 'paid';

  async function handlePayBill() {
    if (!confirm(`Pay ${emps.length} employees for ${p.month}?\n\nThis will:\n• Record a cash-out expense for each employee\n• Update the company balance\n• Send notifications and create payslips`)) return;
    setPaying(true);
    try {
      const batch     = writeBatch(db);
      const hrEmail   = session?.email || '';
      const totalAmt  = p.totalAmount || 0;

      // 1. Mark payroll as paid
      const payrollRef = doc(db, 'data', cid, 'payrolls', p.id);
      batch.update(payrollRef, {
        status:    'paid',
        paidAt:    serverTimestamp(),
        paidBy:    hrEmail,
        updatedAt: serverTimestamp(),
      });

      // 2. Per-employee: expense + cash_flow + payslip + notification
      for (const emp of emps) {
        const net  = emp.netSalary || 0;
        const name = emp.employeeName || 'Employee';
        const dept = emp.department   || 'HR';

        // Expense entry (mirrors Flutter's per-employee expense doc)
        const expRef = doc(collection(db, 'data', cid, 'expenses'));
        batch.set(expRef, {
          vendor:        `Payroll – ${p.month}`,
          category:      'Payroll',
          item:          `Salary – ${name} (${p.month})`,
          amount:        net,
          employeeName:  name,
          department:    dept,
          notes:         `Salary disbursement for ${name}`,
          period:        p.month,
          dueDate:       serverTimestamp(),
          status:        'paid',
          costCenter:    dept,
          addedBy:       hrEmail,
          createdAt:     serverTimestamp(),
          _payrollDocId: p.id,
          _reversible:   true,
        });

        // Cash-flow entry (cash_out — updates balance)
        const cfRef = doc(collection(db, 'data', cid, 'cash_flow'));
        batch.set(cfRef, {
          type:          'cash_out',
          amount:        net,
          currency:      'BDT',
          description:   `Salary – ${name} (${p.month})`,
          category:      'Payroll',
          department:    dept,
          employeeName:  name,
          approvedBy:    hrEmail,
          approvedByName: session?.displayName || hrEmail,
          date:          serverTimestamp(),
          createdAt:     serverTimestamp(),
          _payrollDocId: p.id,
          _reversible:   true,
        });

        // Payslip document
        const slipRef = doc(collection(db, 'data', cid, 'payslips'));
        batch.set(slipRef, {
          payrollId:    p.id,
          employeeId:   emp.employeeId || emp.id || '',
          employeeUid:  emp.employeeUid || emp.uid || emp.employeeId || emp.id || '',
          officeEmail:  emp.officeEmail || emp.email || '',
          employeeName: name,
          department:   dept,
          designation:  emp.designation || '',
          month:        p.month,
          period:       p.month,   // mobile reads 'period'
          basicSalary:  emp.basicSalary || 0,
          grossSalary:  (emp.basicSalary || 0) + (emp.allowances || 0),
          allowances:   emp.allowances  || 0,
          deductions:   emp.deductions  || 0,
          netSalary:    net,
          status:       'generated',
          createdAt:    serverTimestamp(),
          paidAt:       serverTimestamp(),
          sentAt:       null,
        });

        // Notification to employee
        const notifRef = doc(collection(db, 'data', cid, 'notifications'));
        batch.set(notifRef, {
          type:          'payslip',
          recipientId:   emp.employeeId || emp.id || '',
          toUserId:      emp.employeeUid || emp.uid || emp.employeeId || emp.id || '',
          to:            emp.officeEmail || emp.email || '',
          recipientName: name,
          title:         `Salary Paid — ${p.month}`,
          body:          `Your salary of ${formatCurrency(net)} for ${p.month} has been processed. Check your payslip.`,
          month:         p.month,
          amount:        net,
          read:          false,
          createdAt:     serverTimestamp(),
        });
      }

      // 3. Increment company cashOut (updates balance = cashIn - cashOut)
      if (totalAmt > 0) {
        const profileRef = doc(db, 'data', cid, 'company_profile', 'main');
        batch.update(profileRef, {
          cashOut:            increment(totalAmt),
          lastCashOutAt:      serverTimestamp(),
          lastCashOutAmount:  totalAmt,
          lastCashOutItem:    `Payroll – ${p.month}`,
          updatedAt:          serverTimestamp(),
        });
      }

      await batch.commit();
      onPaid(p.month, emps.length);
    } catch (e) {
      alert('Payment failed: ' + e.message);
    } finally {
      setPaying(false);
    }
  }

  async function handleReversePayroll() {
    const totalAmt = p.totalAmount || 0;
    if (!confirm(
      `Reverse payroll for ${p.month}?\n\n` +
      `This will:\n` +
      `• Delete all cash-out and expense entries for this payroll\n` +
      `• Restore ${formatCurrency(totalAmt)} to the balance\n` +
      `• Reset payroll status back to "Pending"\n` +
      `• Reset all linked payslips back to "Generated"`
    )) return;

    setReversing(true);
    try {
      const batch = writeBatch(db);

      // 1. Delete all cash_flow entries linked to this payroll
      const cfSnap = await getDocs(
        query(collection(db, 'data', cid, 'cash_flow'), where('_payrollDocId', '==', p.id))
      );
      let totalCashOut = 0;
      cfSnap.docs.forEach(d => {
        if (d.data().type === 'cash_out') totalCashOut += (d.data().amount || 0);
        batch.delete(d.ref);
      });

      // 2. Delete all expense entries linked to this payroll
      const expSnap = await getDocs(
        query(collection(db, 'data', cid, 'expenses'), where('_payrollDocId', '==', p.id))
      );
      expSnap.docs.forEach(d => batch.delete(d.ref));

      // 3. Restore company cashOut
      if (totalCashOut > 0) {
        batch.update(doc(db, 'data', cid, 'company_profile', 'main'), {
          cashOut:   increment(-totalCashOut),
          updatedAt: serverTimestamp(),
        });
      }

      // 4. Add a reversal audit entry in cash_flow
      const revRef = doc(collection(db, 'data', cid, 'cash_flow'));
      batch.set(revRef, {
        type:          'reversal',
        amount:        totalCashOut || totalAmt,
        currency:      'BDT',
        description:   `Payroll Reversal – ${p.month}`,
        category:      'Payroll',
        reversedBy:    session?.email || 'HR',
        reversedAt:    serverTimestamp(),
        createdAt:     serverTimestamp(),
        _payrollDocId: p.id,
      });

      // 5. Reset payroll status → 'pending'
      batch.update(doc(db, 'data', cid, 'payrolls', p.id), {
        status:     'pending',
        paidAt:     null,
        reversedAt: serverTimestamp(),
        reversedBy: session?.email || 'HR',
        updatedAt:  serverTimestamp(),
      });

      // 6. Mark all linked payslips → 'reversed', clear sentAt
      const payslipSnap = await getDocs(
        query(collection(db, 'data', cid, 'payslips'), where('payrollId', '==', p.id))
      );
      payslipSnap.docs.forEach(d => {
        batch.update(d.ref, {
          status:     'reversed',
          sentAt:     null,
          reversedAt: serverTimestamp(),
          updatedAt:  serverTimestamp(),
        });
      });

      await batch.commit();
    } catch (e) {
      alert('Reversal failed: ' + e.message);
    } finally {
      setReversing(false);
    }
  }

  return (
    <div className="card overflow-hidden">
      {/* Header row */}
      <div className="flex items-center gap-4 p-4">
        <div
          className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
          style={{ background: isPaid ? '#DCFCE7' : '#FEF9C3' }}
        >
          {isPaid
            ? <CheckCircle2 size={20} style={{ color: '#16A34A' }} />
            : <Banknote size={20} style={{ color: '#CA8A04' }} />
          }
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <p className="font-black text-gray-900">{p.month}</p>
            <span className={statusBadge(p.status || 'pending')}>{p.status || 'pending'}</span>
          </div>
          <p className="text-xs text-gray-400 mt-0.5">
            {emps.length} employee{emps.length !== 1 ? 's' : ''} · Total: {formatCurrency(p.totalAmount || 0)}
          </p>
        </div>
        <div className="flex items-center gap-1.5 shrink-0">
          {!isPaid && (
            <>
              <button onClick={onEdit} className="btn-icon btn-sm" title="Edit payroll">
                <Edit2 size={13} />
              </button>
              <button
                onClick={handlePayBill}
                disabled={paying || emps.length === 0}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-black text-white transition disabled:opacity-50"
                style={{ background: BRAND }}
              >
                {paying ? <Loader2 size={12} className="animate-spin" /> : <Send size={12} />}
                {paying ? 'Paying…' : 'Pay Bill'}
              </button>
            </>
          )}
          {isPaid && (
            <button
              onClick={handleReversePayroll}
              disabled={reversing}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-black transition disabled:opacity-50"
              style={{ background: '#FEF2F2', color: '#DC2626', border: '1px solid #FECACA' }}
              title="Reverse this payroll payment"
            >
              {reversing ? <Loader2 size={12} className="animate-spin" /> : <Undo2 size={12} />}
              {reversing ? 'Reversing…' : 'Reverse'}
            </button>
          )}
          <button onClick={onDelete} className="btn-icon btn-sm text-red-400 hover:text-red-600 hover:bg-red-50" title="Delete">
            <Trash2 size={13} />
          </button>
          <button
            onClick={() => setExpanded(v => !v)}
            className="btn-icon btn-sm"
            title={expanded ? 'Collapse' : 'Expand'}
          >
            <ChevronDown size={14} className={`transition-transform ${expanded ? 'rotate-180' : ''}`} />
          </button>
        </div>
      </div>

      {/* Expanded employee table */}
      {expanded && emps.length > 0 && (
        <div className="border-t border-gray-100">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50">
                <th className="text-left px-4 py-2 text-xs font-black text-gray-500 uppercase tracking-wider">Employee</th>
                <th className="text-left px-4 py-2 text-xs font-black text-gray-500 uppercase tracking-wider">Dept</th>
                <th className="text-right px-4 py-2 text-xs font-black text-gray-500 uppercase tracking-wider">Basic</th>
                <th className="text-right px-4 py-2 text-xs font-black text-gray-500 uppercase tracking-wider">Allowances</th>
                <th className="text-right px-4 py-2 text-xs font-black text-gray-500 uppercase tracking-wider">Deductions</th>
                <th className="text-right px-4 py-2 text-xs font-black text-gray-500 uppercase tracking-wider">Net Salary</th>
              </tr>
            </thead>
            <tbody>
              {emps.map((emp, i) => (
                <tr key={i} className="border-t border-gray-50">
                  <td className="px-4 py-2.5">
                    <div className="flex items-center gap-2">
                      <EmployeeAvatar emp={{ _displayName: emp.employeeName }} size={7} />
                      <div>
                        <p className="font-semibold text-gray-900 text-xs">{emp.employeeName}</p>
                        {emp.designation && <p className="text-[10px] text-gray-400">{emp.designation}</p>}
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-2.5 text-xs text-gray-500 capitalize">{emp.department || '—'}</td>
                  <td className="px-4 py-2.5 text-xs text-right text-gray-700">{formatCurrency(emp.basicSalary)}</td>
                  <td className="px-4 py-2.5 text-xs text-right text-emerald-600">+{formatCurrency(emp.allowances || 0)}</td>
                  <td className="px-4 py-2.5 text-xs text-right text-red-500">−{formatCurrency(emp.deductions || 0)}</td>
                  <td className="px-4 py-2.5 text-xs text-right font-black" style={{ color: BRAND }}>{formatCurrency(emp.netSalary)}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="bg-gray-50 border-t border-gray-200">
                <td colSpan={5} className="px-4 py-2 text-xs font-black text-gray-700 text-right">Total Payroll</td>
                <td className="px-4 py-2 text-sm font-black text-right" style={{ color: BRAND }}>{formatCurrency(p.totalAmount || 0)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      {expanded && emps.length === 0 && (
        <div className="border-t border-gray-100 px-4 py-6 text-center text-gray-400 text-sm">
          No employees in this payroll
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYROLL MODAL — create/edit payroll with employee list + auto-fill salary
// ─────────────────────────────────────────────────────────────────────────────
function PayrollModal({ payroll, cid, employees, salaries, session, onClose, onPaid }) {
  const isEdit = !!payroll;

  const [month,    setMonth]    = useState(payroll?.month || currentMonthLabel());
  const [rows,     setRows]     = useState(payroll?.employees || []);
  const [empSearch, setEmpSearch] = useState('');
  const [showPicker, setShowPicker] = useState(false);
  const [saving,   setSaving]   = useState(false);
  const [paying,   setPaying]   = useState(false);
  const [error,    setError]    = useState('');

  // Build salary lookup: employeeId → salary record
  const salaryMap = useMemo(() => {
    const map = {};
    salaries.forEach(s => {
      if (s.employeeId) map[s.employeeId] = s;
    });
    return map;
  }, [salaries]);

  // Employees not yet in rows
  const availableEmps = useMemo(() => {
    const addedIds = new Set(rows.map(r => r.employeeId));
    return employees.filter(e => !addedIds.has(e.id) && !addedIds.has(e.employeeId));
  }, [employees, rows]);

  const filteredAvailable = useMemo(() => {
    const q = empSearch.toLowerCase();
    if (!q) return availableEmps;
    return availableEmps.filter(e =>
      (e._displayName || '').toLowerCase().includes(q) ||
      (e.department || '').toLowerCase().includes(q)
    );
  }, [availableEmps, empSearch]);

  function addEmployee(emp) {
    const empId = emp.employeeId || emp.id;
    const sal   = salaryMap[empId] || salaryMap[emp.id] || null;
    const empEmail = emp.email || emp.officeEmail || '';
    const empUid   = emp.uid || emp.id || '';

    if (!sal) {
      // No salary found — add with zeros and flag
      setRows(r => [...r, {
        employeeId:   empId,
        employeeUid:  empUid,
        officeEmail:  empEmail,
        employeeName: emp._displayName || emp.fullName || emp.name || '',
        department:   emp.department || '',
        designation:  emp.designation || '',
        basicSalary:  0,
        allowances:   0,
        deductions:   0,
        netSalary:    0,
        noSalaryFound: true,
      }]);
    } else {
      const basic  = sal.basicSalary || sal.basic || 0;
      const allow  = sal.allowances  || 0;
      const deduct = sal.deductions  || 0;
      setRows(r => [...r, {
        employeeId:   empId,
        employeeUid:  empUid,
        officeEmail:  empEmail,
        employeeName: emp._displayName || emp.fullName || emp.name || '',
        department:   emp.department || '',
        designation:  emp.designation || '',
        basicSalary:  basic,
        allowances:   allow,
        deductions:   deduct,
        netSalary:    basic + allow - deduct,
        noSalaryFound: false,
      }]);
    }
    setShowPicker(false);
    setEmpSearch('');
  }

  function removeRow(idx) {
    setRows(r => r.filter((_, i) => i !== idx));
  }

  function updateRow(idx, key, val) {
    setRows(r => r.map((row, i) => {
      if (i !== idx) return row;
      const next = { ...row, [key]: parseFloat(val) || 0 };
      next.netSalary = (next.basicSalary || 0) + (next.allowances || 0) - (next.deductions || 0);
      return next;
    }));
  }

  const totalAmount = rows.reduce((s, r) => s + (r.netSalary || 0), 0);
  const hasMissingSalary = rows.some(r => r.noSalaryFound);

  async function handleSave(andPay = false) {
    if (!month.trim()) { setError('Month is required.'); return; }
    if (rows.length === 0) { setError('Add at least one employee.'); return; }

    if (andPay) setPaying(true); else setSaving(true);
    setError('');

    try {
      const data = {
        month,
        employees: rows,
        totalAmount,
        status: andPay ? 'paid' : (payroll?.status || 'pending'),
        createdBy: session?.email || '',
        ...(andPay ? { paidAt: serverTimestamp(), paidBy: session?.email || '' } : {}),
      };

      let payrollId = payroll?.id;

      if (isEdit) {
        await update(cid, 'payrolls', payroll.id, data);
      } else {
        const ref = await add(col(cid, 'payrolls'), data);
        payrollId = ref.id;
      }

      if (andPay) {
        // Create expenses + cash_flow + payslips + notifications + update balance
        const batch   = writeBatch(db);
        const hrEmail = session?.email || '';

        for (const emp of rows) {
          const net  = emp.netSalary || 0;
          const name = emp.employeeName || 'Employee';
          const dept = emp.department   || 'HR';

          // Expense entry per employee
          const expRef = doc(collection(db, 'data', cid, 'expenses'));
          batch.set(expRef, {
            vendor:        `Payroll – ${month}`,
            category:      'Payroll',
            item:          `Salary – ${name} (${month})`,
            amount:        net,
            employeeName:  name,
            department:    dept,
            notes:         `Salary disbursement for ${name}`,
            period:        month,
            dueDate:       serverTimestamp(),
            status:        'paid',
            costCenter:    dept,
            addedBy:       hrEmail,
            createdAt:     serverTimestamp(),
            _payrollDocId: payrollId,
            _reversible:   true,
          });

          // Cash-flow entry (cash_out) per employee
          const cfRef = doc(collection(db, 'data', cid, 'cash_flow'));
          batch.set(cfRef, {
            type:          'cash_out',
            amount:        net,
            currency:      'BDT',
            description:   `Salary – ${name} (${month})`,
            category:      'Payroll',
            department:    dept,
            employeeName:  name,
            approvedBy:    hrEmail,
            approvedByName: session?.displayName || hrEmail,
            date:          serverTimestamp(),
            createdAt:     serverTimestamp(),
            _payrollDocId: payrollId,
            _reversible:   true,
          });

          // Payslip document
          const slipRef = doc(collection(db, 'data', cid, 'payslips'));
          batch.set(slipRef, {
            payrollId,
            employeeId:   emp.employeeId || '',
            employeeUid:  emp.employeeUid || emp.uid || emp.employeeId || '',
            officeEmail:  emp.officeEmail || emp.email || '',
            employeeName: name,
            department:   dept,
            designation:  emp.designation || '',
            month,
            period:       month,   // mobile reads 'period'
            basicSalary:  emp.basicSalary || 0,
            grossSalary:  (emp.basicSalary || 0) + (emp.allowances || 0),
            allowances:   emp.allowances  || 0,
            deductions:   emp.deductions  || 0,
            netSalary:    net,
            status:       'generated',
            createdAt:    serverTimestamp(),
            paidAt:       serverTimestamp(),
            sentAt:       null,
          });

          // Notification to employee
          const notifRef = doc(collection(db, 'data', cid, 'notifications'));
          batch.set(notifRef, {
            type:          'payslip',
            recipientId:   emp.employeeId || '',
            toUserId:      emp.employeeUid || emp.uid || emp.employeeId || '',
            to:            emp.officeEmail || emp.email || '',
            recipientName: name,
            title:         `Salary Paid — ${month}`,
            body:          `Your salary of ${formatCurrency(net)} for ${month} has been processed. Check your payslip.`,
            month,
            amount:        net,
            read:          false,
            createdAt:     serverTimestamp(),
          });
        }

        // Increment company cashOut — updates balance = cashIn - cashOut
        if (totalAmount > 0) {
          const profileRef = doc(db, 'data', cid, 'company_profile', 'main');
          batch.update(profileRef, {
            cashOut:           increment(totalAmount),
            lastCashOutAt:     serverTimestamp(),
            lastCashOutAmount: totalAmount,
            lastCashOutItem:   `Payroll – ${month}`,
            updatedAt:         serverTimestamp(),
          });
        }

        await batch.commit();
        onPaid(month, rows.length);
      } else {
        onClose();
      }
    } catch (e) {
      setError(e.message || 'Failed to save.');
    } finally {
      setSaving(false);
      setPaying(false);
    }
  }

  return (
    <Modal title={isEdit ? `Edit Payroll — ${payroll.month}` : 'Create Payroll'} onClose={onClose} wide>
      <div className="space-y-5">

        {/* Month */}
        <div>
          <label className="label">Payroll Month *</label>
          <input
            className="input"
            value={month}
            onChange={e => setMonth(e.target.value)}
            placeholder="e.g. January 2025"
          />
        </div>

        {/* Employee rows */}
        <div>
          <div className="flex items-center justify-between mb-2">
            <p className="text-xs font-black uppercase tracking-wider text-gray-500">
              Employees ({rows.length})
            </p>
            <button
              onClick={() => setShowPicker(v => !v)}
              className="flex items-center gap-1.5 text-xs font-bold px-3 py-1.5 rounded-lg transition"
              style={{ background: BRAND + '15', color: BRAND }}
            >
              <Plus size={12} /> Add Employee
            </button>
          </div>

          {/* Employee picker dropdown */}
          {showPicker && (
            <div className="mb-3 rounded-xl border border-[#065F46]/20 bg-[#F0FDF4] p-3">
              <div className="relative mb-2">
                <Search size={13} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  className="input pl-8 text-sm"
                  placeholder="Search employees…"
                  value={empSearch}
                  onChange={e => setEmpSearch(e.target.value)}
                  autoFocus
                />
              </div>
              <div className="max-h-48 overflow-y-auto space-y-1">
                {filteredAvailable.length === 0 ? (
                  <p className="text-center text-xs text-gray-400 py-4">
                    {availableEmps.length === 0 ? 'All employees added' : 'No employees match'}
                  </p>
                ) : filteredAvailable.map(emp => {
                  const empId = emp.employeeId || emp.id;
                  const sal   = salaryMap[empId] || salaryMap[emp.id];
                  return (
                    <button
                      key={emp.id}
                      type="button"
                      onClick={() => addEmployee(emp)}
                      className="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-white transition text-left"
                    >
                      <EmployeeAvatar emp={emp} size={7} />
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-semibold text-gray-900 truncate">{emp._displayName}</p>
                        <p className="text-xs text-gray-400 truncate">{emp.department}{emp.designation ? ` · ${emp.designation}` : ''}</p>
                      </div>
                      {sal ? (
                        <span className="text-xs font-bold shrink-0" style={{ color: BRAND }}>{formatCurrency(sal.grossSalary || sal.salary)}</span>
                      ) : (
                        <span className="text-[10px] font-bold text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded shrink-0">No salary</span>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* No salary warning */}
          {hasMissingSalary && (
            <div className="flex items-start gap-2 p-3 rounded-xl bg-amber-50 border border-amber-200 mb-3">
              <AlertCircle size={14} className="text-amber-600 shrink-0 mt-0.5" />
              <p className="text-xs text-amber-700">
                <span className="font-bold">Some employees have no salary record.</span> Please add their salary in the Salary section first, or enter values manually below.
              </p>
            </div>
          )}

          {/* Employee rows table */}
          {rows.length === 0 ? (
            <div className="text-center py-8 text-gray-400 border-2 border-dashed border-gray-200 rounded-xl">
              <Users size={28} className="mx-auto mb-2 opacity-30" />
              <p className="text-sm">No employees added yet</p>
              <p className="text-xs mt-1">Click "Add Employee" to add employees to this payroll</p>
            </div>
          ) : (
            <div className="rounded-xl border border-gray-200 overflow-hidden">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-gray-50">
                    <th className="text-left px-3 py-2 text-xs font-black text-gray-500">Employee</th>
                    <th className="text-right px-3 py-2 text-xs font-black text-gray-500">Basic</th>
                    <th className="text-right px-3 py-2 text-xs font-black text-gray-500">Allowances</th>
                    <th className="text-right px-3 py-2 text-xs font-black text-gray-500">Deductions</th>
                    <th className="text-right px-3 py-2 text-xs font-black text-gray-500">Net</th>
                    <th className="px-3 py-2" />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row, idx) => (
                    <tr key={idx} className="border-t border-gray-100">
                      <td className="px-3 py-2">
                        <div className="flex items-center gap-2">
                          <EmployeeAvatar emp={{ _displayName: row.employeeName }} size={6} />
                          <div>
                            <p className="font-semibold text-gray-900 text-xs">{row.employeeName}</p>
                            <p className="text-[10px] text-gray-400">{row.department}</p>
                          </div>
                          {row.noSalaryFound && (
                            <span className="text-[9px] font-bold text-amber-600 bg-amber-50 px-1 py-0.5 rounded">No salary</span>
                          )}
                        </div>
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="number"
                          className="input text-xs text-right w-24"
                          value={row.basicSalary}
                          onChange={e => updateRow(idx, 'basicSalary', e.target.value)}
                        />
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="number"
                          className="input text-xs text-right w-24"
                          value={row.allowances}
                          onChange={e => updateRow(idx, 'allowances', e.target.value)}
                        />
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="number"
                          className="input text-xs text-right w-24"
                          value={row.deductions}
                          onChange={e => updateRow(idx, 'deductions', e.target.value)}
                        />
                      </td>
                      <td className="px-3 py-2 text-right">
                        <span className="text-xs font-black" style={{ color: BRAND }}>{formatCurrency(row.netSalary)}</span>
                      </td>
                      <td className="px-3 py-2">
                        <button onClick={() => removeRow(idx)} className="text-red-400 hover:text-red-600 transition">
                          <X size={13} />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr className="bg-gray-50 border-t border-gray-200">
                    <td colSpan={4} className="px-3 py-2 text-xs font-black text-gray-700 text-right">Total Payroll</td>
                    <td className="px-3 py-2 text-right">
                      <span className="text-sm font-black" style={{ color: BRAND }}>{formatCurrency(totalAmount)}</span>
                    </td>
                    <td />
                  </tr>
                </tfoot>
              </table>
            </div>
          )}
        </div>

        {error && (
          <div className="flex items-center gap-2 p-3 rounded-xl bg-red-50 border border-red-200">
            <AlertCircle size={14} className="text-red-500 shrink-0" />
            <p className="text-sm text-red-600">{error}</p>
          </div>
        )}

        {/* Actions */}
        <div className="flex gap-3 pt-1">
          <button onClick={onClose} className="btn-secondary flex-1">Cancel</button>
          <button
            onClick={() => handleSave(false)}
            disabled={saving || paying}
            className="btn-secondary flex-1 flex items-center justify-center gap-2"
          >
            {saving ? <Loader2 size={14} className="animate-spin" /> : null}
            {saving ? 'Saving…' : 'Save Draft'}
          </button>
          <button
            onClick={() => handleSave(true)}
            disabled={saving || paying || rows.length === 0}
            className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-black text-white transition disabled:opacity-40"
            style={{ background: paying ? BRAND + '80' : BRAND }}
          >
            {paying ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
            {paying ? 'Processing…' : 'Pay Bill'}
          </button>
        </div>
      </div>
    </Modal>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUCCESS DIALOG
// ─────────────────────────────────────────────────────────────────────────────
function SuccessDialog({ month, count, onClose }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" />
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden">

        {/* Green header */}
        <div className="px-6 pt-8 pb-6 text-center" style={{ background: 'linear-gradient(135deg, #065F46 0%, #059669 100%)' }}>
          <div className="w-16 h-16 rounded-full bg-white/20 flex items-center justify-center mx-auto mb-4">
            <CheckCircle2 size={36} className="text-white" />
          </div>
          <h2 className="text-white font-black text-xl">Payment Successful!</h2>
          <p className="text-white/70 text-sm mt-1">
            {count} employee{count !== 1 ? 's' : ''} paid for {month}
          </p>
        </div>

        <div className="p-6 space-y-4">
          {/* Steps */}
          <div className="space-y-3">
            <div className="flex items-start gap-3 p-3 rounded-xl bg-red-50 border border-red-100">
              <TrendingDown size={16} className="text-red-500 shrink-0 mt-0.5" />
              <div>
                <p className="text-sm font-bold text-gray-900">Balance Updated</p>
                <p className="text-xs text-gray-500 mt-0.5">Cash-out recorded in the balance sheet. Expense entries created per employee.</p>
              </div>
            </div>
            <div className="flex items-start gap-3 p-3 rounded-xl bg-green-50 border border-green-100">
              <Bell size={16} className="text-green-600 shrink-0 mt-0.5" />
              <div>
                <p className="text-sm font-bold text-gray-900">Notifications Sent</p>
                <p className="text-xs text-gray-500 mt-0.5">Each employee has been notified about their salary payment.</p>
              </div>
            </div>
            <div className="flex items-start gap-3 p-3 rounded-xl bg-blue-50 border border-blue-100">
              <FileText size={16} className="text-blue-600 shrink-0 mt-0.5" />
              <div>
                <p className="text-sm font-bold text-gray-900">Payslips Generated</p>
                <p className="text-xs text-gray-500 mt-0.5">Payslip documents have been created for each employee.</p>
              </div>
            </div>
          </div>

          {/* Instruction */}
          <div className="flex items-center gap-2 p-3 rounded-xl border-2 border-dashed border-[#065F46]/30">
            <ArrowRight size={16} style={{ color: BRAND }} className="shrink-0" />
            <p className="text-sm text-gray-700">
              Go to <span className="font-black" style={{ color: BRAND }}>Pay Slips</span> section to view and send payslips to employees.
            </p>
          </div>

          <button
            onClick={onClose}
            className="w-full py-3 rounded-xl text-sm font-black text-white"
            style={{ background: BRAND }}
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
}
