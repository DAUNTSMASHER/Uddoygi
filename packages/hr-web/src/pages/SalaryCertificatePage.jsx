// Salary Certificate Generator — mirrors Flutter hr_salary_certificate_screen.dart
// Collection: data/{cid}/hr_documents
// Generates PDF using jsPDF + jspdf-autotable

import { useEffect, useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  ArrowLeft, Loader2, Award, Building2, User, DollarSign,
  Shield, Download, Save, Eye, EyeOff, CheckSquare, Square,
  RefreshCw, ChevronDown, ChevronUp,
} from 'lucide-react';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add, fetchAll, serverTimestamp } from '../lib/db';
import { formatDate, formatCurrency } from '../lib/utils';
import { EmployeePicker, EmployeeAvatar } from '../components/ui/EmployeePicker';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '../firebase';

// ─── helpers ────────────────────────────────────────────────────────────────
function todayISO() { return new Date().toISOString().split('T')[0]; }
function genCertNo() {
  const y = new Date().getFullYear();
  const n = String(Math.floor(Math.random() * 900) + 100);
  return `SC-${y}-${n}`;
}
function numToWords(n) {
  const ones = ['','One','Two','Three','Four','Five','Six','Seven','Eight','Nine',
    'Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'];
  const tens = ['','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'];
  if (n === 0) return 'Zero';
  if (n < 20) return ones[n];
  if (n < 100) return tens[Math.floor(n/10)] + (n%10 ? ' '+ones[n%10] : '');
  if (n < 1000) return ones[Math.floor(n/100)]+' Hundred'+(n%100?' '+numToWords(n%100):'');
  if (n < 100000) return numToWords(Math.floor(n/1000))+' Thousand'+(n%1000?' '+numToWords(n%1000):'');
  if (n < 10000000) return numToWords(Math.floor(n/100000))+' Lakh'+(n%100000?' '+numToWords(n%100000):'');
  return numToWords(Math.floor(n/10000000))+' Crore'+(n%10000000?' '+numToWords(n%10000000):'');
}

// ─── PDF generation ─────────────────────────────────────────────────────────
function generateSalaryCertPDF(data) {
  const {
    companyName, companyAddress,
    employeeName, employeeId, designation, department, joiningDate, employmentStatus,
    basicSalary, houseRent, medical, transport, gross, salaryInWords,
    purpose, certNo, issueDate,
    authorizedBy, authorDesig, organization,
    inclBreakdown, inclSignature, inclSeal, inclWatermark,
    lang,
  } = data;

  const isBn = lang === 'Bangla';
  const pdf  = new jsPDF({ unit: 'pt', format: 'a4' });
  const W    = pdf.internal.pageSize.getWidth();
  const M    = 50;
  let   y    = M;

  // Watermark
  if (inclWatermark) {
    pdf.setFontSize(60);
    pdf.setTextColor(220, 220, 220);
    pdf.setFont('times', 'bold');
    pdf.text('SYSTEM GENERATED', W / 2, pdf.internal.pageSize.getHeight() / 2, {
      align: 'center', angle: 45,
    });
    pdf.setTextColor(0, 0, 0);
  }

  // Company header
  pdf.setFont('times', 'bold');
  pdf.setFontSize(16);
  pdf.setTextColor(6, 95, 70);
  pdf.text((companyName || 'Company Name').toUpperCase(), W / 2, y, { align: 'center' });
  y += 18;
  pdf.setFont('times', 'normal');
  pdf.setFontSize(10);
  pdf.setTextColor(80, 80, 80);
  pdf.text(companyAddress || '', W / 2, y, { align: 'center' });
  y += 14;
  pdf.setDrawColor(6, 95, 70);
  pdf.setLineWidth(1.5);
  pdf.line(M, y, W - M, y);
  y += 16;

  // Ref + Date
  pdf.setFont('times', 'normal');
  pdf.setFontSize(10);
  pdf.setTextColor(0, 0, 0);
  pdf.text(`Ref: ${certNo}`, M, y);
  pdf.text(`Date: ${issueDate}`, W - M, y, { align: 'right' });
  y += 22;

  // Title
  const title = isBn ? 'যাকে প্রয়োজন তাকে জানানো যাচ্ছে' : 'TO WHOM IT MAY CONCERN';
  pdf.setFont('times', 'bold');
  pdf.setFontSize(13);
  pdf.text(title, W / 2, y, { align: 'center' });
  // underline
  const tw = pdf.getTextWidth(title);
  pdf.setLineWidth(0.8);
  pdf.line((W - tw) / 2, y + 2, (W + tw) / 2, y + 2);
  y += 24;

  // Body paragraph
  pdf.setFont('times', 'normal');
  pdf.setFontSize(11);
  pdf.setTextColor(30, 30, 30);
  const body = isBn
    ? `এই মর্মে প্রত্যয়ন করা যাচ্ছে যে ${employeeName} (আইডি: ${employeeId || 'N/A'}), পদবী: ${designation || 'N/A'}, বিভাগ: ${department || 'N/A'}, যোগদানের তারিখ: ${joiningDate || 'N/A'} থেকে ${employmentStatus || 'কর্মরত'} হিসেবে কর্মরত আছেন।`
    : `This is to certify that ${employeeName} (ID: ${employeeId || 'N/A'}) is employed with our organization as ${designation || 'N/A'} in the ${department || 'N/A'} department since ${joiningDate || 'N/A'} and is currently ${employmentStatus || 'Active'}.`;
  const bodyLines = pdf.splitTextToSize(body, W - M * 2);
  pdf.text(bodyLines, M, y);
  y += bodyLines.length * 14 + 10;

  // Salary breakdown table
  if (inclBreakdown) {
    const head = isBn
      ? [['বেতনের বিবরণ', 'পরিমাণ (BDT)']]
      : [['Salary Component', 'Amount (BDT)']];
    const body2 = [
      [isBn ? 'মূল বেতন' : 'Basic Salary',           Number(basicSalary).toLocaleString('en-BD')],
      [isBn ? 'বাড়ি ভাড়া ভাতা' : 'House Rent Allowance', Number(houseRent).toLocaleString('en-BD')],
      [isBn ? 'চিকিৎসা ভাতা' : 'Medical Allowance',   Number(medical).toLocaleString('en-BD')],
      [isBn ? 'যাতায়াত ভাতা' : 'Transport Allowance', Number(transport).toLocaleString('en-BD')],
    ];
    const foot = [[isBn ? 'মোট মাসিক বেতন' : 'Gross Monthly Salary', Number(gross).toLocaleString('en-BD')]];
    autoTable(pdf, {
      startY: y,
      head, body: body2, foot,
      theme: 'grid',
      headStyles: { fillColor: [6, 95, 70], textColor: 255, fontStyle: 'bold', fontSize: 10 },
      footStyles: { fillColor: [240, 253, 244], textColor: [6, 95, 70], fontStyle: 'bold', fontSize: 10 },
      bodyStyles: { fontSize: 10 },
      margin: { left: M, right: M },
    });
    y = pdf.lastAutoTable.finalY + 14;
  }

  // Salary in words
  if (salaryInWords) {
    pdf.setFont('times', 'italic');
    pdf.setFontSize(10);
    pdf.setTextColor(80, 80, 80);
    pdf.text(`(${isBn ? 'কথায়' : 'In words'}: ${salaryInWords})`, M, y);
    y += 16;
  }

  // Purpose
  if (purpose) {
    pdf.setFont('times', 'normal');
    pdf.setFontSize(11);
    pdf.setTextColor(30, 30, 30);
    const pLine = isBn
      ? `এই সনদপত্র ${purpose} উদ্দেশ্যে ইস্যু করা হয়েছে।`
      : `This certificate is issued for the purpose of ${purpose}.`;
    pdf.text(pdf.splitTextToSize(pLine, W - M * 2), M, y);
    y += 24;
  }

  // Closing
  pdf.setFont('times', 'normal');
  pdf.setFontSize(11);
  const closing = isBn ? 'আমরা তাঁর সাফল্য ও মঙ্গল কামনা করি।' : 'We wish him/her all the best in their endeavors.';
  pdf.text(closing, M, y);
  y += 30;

  // Signature block
  if (inclSignature) {
    pdf.setFont('times', 'bold');
    pdf.setFontSize(11);
    pdf.text(authorizedBy || '', M, y);
    y += 14;
    pdf.setFont('times', 'normal');
    pdf.setFontSize(10);
    pdf.setTextColor(80, 80, 80);
    pdf.text(authorDesig || '', M, y);
    y += 12;
    pdf.text(organization || '', M, y);
  }

  // Seal circle
  if (inclSeal) {
    const cx = W - M - 35;
    const cy = y - 20;
    pdf.setDrawColor(6, 95, 70);
    pdf.setLineWidth(1.5);
    pdf.circle(cx, cy, 28);
    pdf.setFontSize(7);
    pdf.setTextColor(6, 95, 70);
    pdf.text('OFFICIAL', cx, cy - 6, { align: 'center' });
    pdf.text('SEAL', cx, cy + 4, { align: 'center' });
  }

  const fname = `Salary_Certificate_${(employeeName || 'Employee').replace(/\s+/g, '_')}_${todayISO().replace(/-/g, '')}.pdf`;
  pdf.save(fname);
}

// ─── Main component ──────────────────────────────────────────────────────────
export function SalaryCertificatePage() {
  const { session } = useAuth();
  const cid      = session?.companyId || '';
  const navigate = useNavigate();

  const [employees,    setEmployees]    = useState([]);
  const [companyInfo,  setCompanyInfo]  = useState({});
  const [hrUser,       setHrUser]       = useState({});
  const [selectedEmp,  setSelectedEmp]  = useState(null);
  const [loadingEmps,  setLoadingEmps]  = useState(true);
  const [saving,       setSaving]       = useState(false);
  const [saved,        setSaved]        = useState(false);
  const [showPreview,  setShowPreview]  = useState(true);
  const [lang,         setLang]         = useState('English');

  const [form, setForm] = useState({
    certNo:     genCertNo(),
    issueDate:  todayISO(),
    basicSalary: '',
    houseRent:   '',
    medical:     '',
    transport:   '',
    salaryInWords: '',
    purpose:     '',
    authorizedBy: '',
    authorDesig:  '',
    inclBreakdown: true,
    inclSignature: true,
    inclSeal:      true,
    inclWatermark: false,
  });

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  // Load employees
  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'users'), (docs) => {
      setEmployees(
        docs
          .filter(e => (e.status || 'active') !== 'terminated')
          .map(e => ({ ...e, _displayName: e.fullName || e.name || e.email || '' }))
          .sort((a, b) => a._displayName.localeCompare(b._displayName))
      );
      setLoadingEmps(false);
    });
    return unsub;
  }, [cid]);

  // Load company profile + HR user
  useEffect(() => {
    if (!cid) return;
    getDoc(doc(db, 'data', cid, 'company_profile', 'main')).then(snap => {
      if (snap.exists()) setCompanyInfo(snap.data());
    });
    if (session?.uid) {
      getDoc(doc(db, 'data', cid, 'users', session.uid)).then(snap => {
        if (snap.exists()) {
          const d = snap.data();
          setHrUser(d);
          setForm(f => ({
            ...f,
            authorizedBy: d.fullName || d.name || '',
            authorDesig:  d.designation || d.jobTitle || 'Head of HR',
          }));
        }
      });
    }
  }, [cid, session?.uid]);

  // Auto-fill from selected employee
  function handleEmpSelect(emp) {
    setSelectedEmp(emp);
    if (emp) {
      const sal = emp.salary || emp.baseSalary || emp.basicSalary || 0;
      const basic = Number(sal);
      const houseR = Math.round(basic * 0.5);
      const med    = Math.round(basic * 0.1);
      const trans  = Math.round(basic * 0.1);
      setForm(f => ({
        ...f,
        basicSalary:   basic  || '',
        houseRent:     houseR || '',
        medical:       med    || '',
        transport:     trans  || '',
        salaryInWords: basic > 0 ? numToWords(basic + houseR + med + trans) + ' Taka Only' : '',
      }));
    } else {
      setForm(f => ({ ...f, basicSalary: '', houseRent: '', medical: '', transport: '', salaryInWords: '' }));
    }
  }

  const gross = useMemo(() => {
    return (Number(form.basicSalary) || 0) + (Number(form.houseRent) || 0) +
           (Number(form.medical) || 0) + (Number(form.transport) || 0);
  }, [form.basicSalary, form.houseRent, form.medical, form.transport]);

  // Auto-update words when gross changes
  useEffect(() => {
    if (gross > 0) set('salaryInWords', numToWords(gross) + ' Taka Only');
  }, [gross]);

  async function handleSave() {
    if (!selectedEmp) { alert('Please select an employee.'); return; }
    setSaving(true);
    try {
      await add(col(cid, 'hr_documents'), {
        type:             'Salary Certificate',
        certNo:           form.certNo,
        employeeId:       selectedEmp.employeeId || selectedEmp.id || '',
        employeeName:     selectedEmp._displayName || selectedEmp.fullName || '',
        employeeUid:      selectedEmp.id || '',
        designation:      selectedEmp.designation || selectedEmp.jobTitle || '',
        department:       selectedEmp.department || '',
        joiningDate:      selectedEmp.joiningDate || '',
        employmentStatus: selectedEmp.employmentStatus || selectedEmp.status || 'Active',
        basicSalary:      Number(form.basicSalary) || 0,
        houseRent:        Number(form.houseRent)   || 0,
        medicalAllowance: Number(form.medical)     || 0,
        transport:        Number(form.transport)   || 0,
        grossSalary:      gross,
        salaryInWords:    form.salaryInWords,
        purpose:          form.purpose,
        issueDate:        form.issueDate,
        authorizedBy:     form.authorizedBy,
        authorDesig:      form.authorDesig,
        organization:     companyInfo.companyName || companyInfo.legalName || '',
        language:         lang,
        inclBreakdown:    form.inclBreakdown,
        inclSignature:    form.inclSignature,
        inclSeal:         form.inclSeal,
        inclWatermark:    form.inclWatermark,
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (e) { alert(e.message); }
    finally { setSaving(false); }
  }

  function handleGeneratePDF() {
    if (!selectedEmp) { alert('Please select an employee first.'); return; }
    generateSalaryCertPDF({
      companyName:    companyInfo.companyName || companyInfo.legalName || 'Company',
      companyAddress: companyInfo.registeredAddress || '',
      employeeName:   selectedEmp._displayName || selectedEmp.fullName || '',
      employeeId:     selectedEmp.employeeId || '',
      designation:    selectedEmp.designation || '',
      department:     selectedEmp.department || '',
      joiningDate:    selectedEmp.joiningDate || '',
      employmentStatus: selectedEmp.employmentStatus || selectedEmp.status || 'Active',
      basicSalary:    Number(form.basicSalary) || 0,
      houseRent:      Number(form.houseRent)   || 0,
      medical:        Number(form.medical)     || 0,
      transport:      Number(form.transport)   || 0,
      gross,
      salaryInWords:  form.salaryInWords,
      purpose:        form.purpose,
      certNo:         form.certNo,
      issueDate:      form.issueDate,
      authorizedBy:   form.authorizedBy,
      authorDesig:    form.authorDesig,
      organization:   companyInfo.companyName || companyInfo.legalName || '',
      inclBreakdown:  form.inclBreakdown,
      inclSignature:  form.inclSignature,
      inclSeal:       form.inclSeal,
      inclWatermark:  form.inclWatermark,
      lang,
    });
  }

  const Toggle = ({ checked, onChange, label }) => (
    <label className="flex items-center gap-3 cursor-pointer select-none">
      <button type="button" onClick={() => onChange(!checked)}
        className={`w-10 h-5 rounded-full transition-colors ${checked ? 'bg-[#065F46]' : 'bg-gray-300'} relative`}>
        <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${checked ? 'translate-x-5' : 'translate-x-0.5'}`} />
      </button>
      <span className="text-sm text-gray-700">{label}</span>
    </label>
  );

  return (
    <div className="space-y-5 pb-24">
      {/* Header */}
      <div className="page-header">
        <div className="flex items-center gap-3">
          <button onClick={() => navigate('/hr/authorization')} className="btn-icon">
            <ArrowLeft size={18} />
          </button>
          <div>
            <h2 className="page-title">Generate Certificate</h2>
            <p className="page-sub">Salary Certificate · {lang} Format</p>
          </div>
        </div>
        {/* Language toggle — mirrors Flutter tab bar */}
        <div className="flex bg-gray-100 rounded-xl p-1 gap-1">
          {['English', 'Bangla'].map(l => (
            <button key={l} onClick={() => setLang(l)}
              className={`px-4 py-1.5 rounded-lg text-sm font-semibold transition ${
                lang === l ? 'bg-white shadow text-[#065F46]' : 'text-gray-500 hover:text-gray-700'
              }`}>
              {l === 'English' ? 'English Format' : 'বাংলা ফরমেট'}
            </button>
          ))}
        </div>
      </div>

      <div className="grid lg:grid-cols-[1fr_420px] gap-5">
        {/* Left — Form */}
        <div className="space-y-4">

          {/* Card 1 — Employee Record */}
          <div className="card p-5 space-y-4">
            <div className="flex items-center gap-2 mb-1">
              <div className="w-7 h-7 rounded-lg bg-[#065F46]/10 flex items-center justify-center">
                <User size={14} className="text-[#065F46]" />
              </div>
              <h3 className="font-bold text-gray-900">Employee Record</h3>
            </div>
            {loadingEmps ? (
              <div className="flex items-center gap-2 text-gray-400 py-4">
                <Loader2 size={16} className="animate-spin" /> Loading employees…
              </div>
            ) : (
              <EmployeePicker employees={employees} value={selectedEmp} onChange={handleEmpSelect} required />
            )}
            {selectedEmp && (
              <div className="grid grid-cols-2 gap-3 mt-2">
                {[
                  { label: 'Designation', value: selectedEmp.designation || selectedEmp.jobTitle || '—' },
                  { label: 'Department',  value: selectedEmp.department || '—' },
                  { label: 'Joining Date', value: selectedEmp.joiningDate || '—' },
                  { label: 'Status',       value: selectedEmp.employmentStatus || selectedEmp.status || 'Active' },
                ].map(f => (
                  <div key={f.label} className="bg-gray-50 rounded-xl p-3">
                    <p className="text-xs text-gray-400 mb-0.5">{f.label}</p>
                    <p className="text-sm font-semibold text-gray-800">{f.value}</p>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Card 2 — Salary Information */}
          <div className="card p-5 space-y-4">
            <div className="flex items-center gap-2 mb-1">
              <div className="w-7 h-7 rounded-lg bg-amber-50 flex items-center justify-center">
                <DollarSign size={14} className="text-amber-600" />
              </div>
              <h3 className="font-bold text-gray-900">Salary Information</h3>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="label">Certificate No.</label>
                <div className="flex gap-1.5">
                  <input className="input flex-1" value={form.certNo} onChange={e => set('certNo', e.target.value)} />
                  <button onClick={() => set('certNo', genCertNo())} className="btn-icon" title="Regenerate"><RefreshCw size={13} /></button>
                </div>
              </div>
              <div>
                <label className="label">Issue Date</label>
                <input className="input" type="date" value={form.issueDate} onChange={e => set('issueDate', e.target.value)} />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {[
                { key: 'basicSalary', label: 'Basic Salary' },
                { key: 'houseRent',   label: 'House Rent Allowance' },
                { key: 'medical',     label: 'Medical Allowance' },
                { key: 'transport',   label: 'Transport Allowance' },
              ].map(f => (
                <div key={f.key}>
                  <label className="label">{f.label}</label>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-xs font-semibold">BDT</span>
                    <input className="input pl-10" type="number" value={form[f.key]}
                      onChange={e => set(f.key, e.target.value)} placeholder="0" />
                  </div>
                </div>
              ))}
            </div>
            {/* Gross display */}
            <div className="rounded-xl bg-[#065F46]/5 border border-[#065F46]/20 p-3 flex items-center justify-between">
              <span className="text-sm font-semibold text-[#065F46]">Gross Monthly Salary</span>
              <span className="text-lg font-black text-[#065F46]">{formatCurrency(gross)}</span>
            </div>
            <div>
              <label className="label">Salary In Words</label>
              <input className="input" value={form.salaryInWords} onChange={e => set('salaryInWords', e.target.value)} placeholder="Auto-calculated…" />
            </div>
            <div>
              <label className="label">Purpose Of Certificate</label>
              <input className="input" value={form.purpose} onChange={e => set('purpose', e.target.value)} placeholder="Bank loan, visa application, etc." />
            </div>
          </div>

          {/* Card 3 — Authority / Signatory */}
          <div className="card p-5 space-y-4">
            <div className="flex items-center gap-2 mb-1">
              <div className="w-7 h-7 rounded-lg bg-blue-50 flex items-center justify-center">
                <Shield size={14} className="text-blue-600" />
              </div>
              <h3 className="font-bold text-gray-900">Authority / Signatory</h3>
            </div>
            <div>
              <label className="label">Authorized By</label>
              <input className="input" value={form.authorizedBy} onChange={e => set('authorizedBy', e.target.value)} />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="label">Designation</label>
                <div className="input bg-gray-50 text-gray-500 text-sm">{form.authorDesig || '—'}</div>
              </div>
              <div>
                <label className="label">Organization</label>
                <div className="input bg-gray-50 text-gray-500 text-sm truncate">
                  {companyInfo.companyName || companyInfo.legalName || '—'}
                </div>
              </div>
            </div>
          </div>

          {/* Card 4 — Output Preferences */}
          <div className="card p-5 space-y-3">
            <div className="flex items-center gap-2 mb-1">
              <div className="w-7 h-7 rounded-lg bg-purple-50 flex items-center justify-center">
                <Award size={14} className="text-purple-600" />
              </div>
              <h3 className="font-bold text-gray-900">Output Preferences</h3>
            </div>
            <Toggle checked={form.inclBreakdown} onChange={v => set('inclBreakdown', v)} label="Include Salary Breakdown Table" />
            <Toggle checked={form.inclSignature} onChange={v => set('inclSignature', v)} label="Include Digital Signature" />
            <Toggle checked={form.inclSeal}      onChange={v => set('inclSeal', v)}      label="Include Official Seal" />
            <Toggle checked={form.inclWatermark} onChange={v => set('inclWatermark', v)} label='Add "System Generated" Watermark' />
          </div>
        </div>

        {/* Right — Preview */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <p className="text-xs font-black uppercase tracking-wider text-gray-500">Document Preview</p>
            <button onClick={() => setShowPreview(p => !p)} className="btn-icon">
              {showPreview ? <EyeOff size={15} /> : <Eye size={15} />}
            </button>
          </div>
          {showPreview && (
            <div className="card p-0 overflow-hidden">
              <SalaryCertPreview
                companyName={companyInfo.companyName || companyInfo.legalName || 'Company Name'}
                companyAddress={companyInfo.registeredAddress || ''}
                emp={selectedEmp}
                form={form}
                gross={gross}
                lang={lang}
              />
            </div>
          )}
        </div>
      </div>

      {/* Bottom action bar — fixed */}
      <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 px-6 py-3 flex justify-end gap-3 z-30">
        <button onClick={() => navigate('/hr/authorization')} className="btn-secondary">
          <ArrowLeft size={15} /> Back
        </button>
        <button onClick={handleSave} disabled={saving || !selectedEmp} className="btn-secondary">
          {saving ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
          {saved ? 'Saved ✓' : saving ? 'Saving…' : 'Save Record'}
        </button>
        <button onClick={handleGeneratePDF} disabled={!selectedEmp} className="btn-primary">
          <Download size={14} /> Generate PDF
        </button>
      </div>
    </div>
  );
}

// ─── Live A4 Preview ─────────────────────────────────────────────────────────
function SalaryCertPreview({ companyName, companyAddress, emp, form, gross, lang }) {
  const isBn = lang === 'Bangla';
  return (
    <div className="bg-white p-6 text-[10px] leading-relaxed font-serif min-h-[500px]" style={{ fontFamily: 'Georgia, serif' }}>
      {/* Header */}
      <div className="text-center mb-3">
        <p className="text-sm font-bold text-[#065F46] uppercase tracking-wide">{companyName}</p>
        <p className="text-gray-500 text-[9px]">{companyAddress}</p>
        <div className="border-t-2 border-[#065F46] mt-2" />
      </div>
      {/* Ref + Date */}
      <div className="flex justify-between text-[9px] text-gray-500 mb-3">
        <span>Ref: {form.certNo}</span>
        <span>Date: {form.issueDate}</span>
      </div>
      {/* Title */}
      <p className="text-center font-bold underline text-xs mb-3">
        {isBn ? 'যাকে প্রয়োজন তাকে জানানো যাচ্ছে' : 'TO WHOM IT MAY CONCERN'}
      </p>
      {/* Body */}
      {emp ? (
        <p className="text-gray-700 mb-3">
          {isBn
            ? `এই মর্মে প্রত্যয়ন করা যাচ্ছে যে ${emp._displayName || emp.fullName || '—'} (আইডি: ${emp.employeeId || 'N/A'}), পদবী: ${emp.designation || 'N/A'}, বিভাগ: ${emp.department || 'N/A'} বিভাগে কর্মরত আছেন।`
            : `This is to certify that ${emp._displayName || emp.fullName || '—'} (ID: ${emp.employeeId || 'N/A'}) is employed as ${emp.designation || 'N/A'} in the ${emp.department || 'N/A'} department.`
          }
        </p>
      ) : (
        <div className="h-8 bg-gray-100 rounded mb-3 animate-pulse" />
      )}
      {/* Salary table */}
      {form.inclBreakdown && gross > 0 && (
        <table className="w-full border-collapse text-[9px] mb-3">
          <thead>
            <tr className="bg-[#065F46] text-white">
              <th className="border border-[#065F46] px-2 py-1 text-left">{isBn ? 'বেতনের বিবরণ' : 'Salary Component'}</th>
              <th className="border border-[#065F46] px-2 py-1 text-right">{isBn ? 'পরিমাণ' : 'Amount (BDT)'}</th>
            </tr>
          </thead>
          <tbody>
            {[
              [isBn ? 'মূল বেতন' : 'Basic Salary',           form.basicSalary],
              [isBn ? 'বাড়ি ভাড়া ভাতা' : 'House Rent',      form.houseRent],
              [isBn ? 'চিকিৎসা ভাতা' : 'Medical Allowance',  form.medical],
              [isBn ? 'যাতায়াত ভাতা' : 'Transport Allowance',form.transport],
            ].map(([label, val]) => (
              <tr key={label} className="border-b border-gray-200">
                <td className="border border-gray-200 px-2 py-0.5">{label}</td>
                <td className="border border-gray-200 px-2 py-0.5 text-right">{Number(val || 0).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr className="bg-green-50 font-bold text-[#065F46]">
              <td className="border border-gray-200 px-2 py-1">{isBn ? 'মোট মাসিক বেতন' : 'Gross Monthly Salary'}</td>
              <td className="border border-gray-200 px-2 py-1 text-right">{gross.toLocaleString()}</td>
            </tr>
          </tfoot>
        </table>
      )}
      {/* Words */}
      {form.salaryInWords && (
        <p className="text-gray-500 italic text-[9px] mb-2">({isBn ? 'কথায়' : 'In words'}: {form.salaryInWords})</p>
      )}
      {/* Signature */}
      {form.inclSignature && (
        <div className="mt-6 flex justify-between items-end">
          <div>
            <p className="font-bold text-[10px]">{form.authorizedBy || '—'}</p>
            <p className="text-gray-500 text-[9px]">{form.authorDesig}</p>
            <p className="text-gray-500 text-[9px]">{companyName}</p>
          </div>
          {form.inclSeal && (
            <div className="w-14 h-14 rounded-full border-2 border-[#065F46] flex items-center justify-center text-[7px] text-[#065F46] font-bold text-center leading-tight">
              OFFICIAL<br />SEAL
            </div>
          )}
        </div>
      )}
    </div>
  );
}
