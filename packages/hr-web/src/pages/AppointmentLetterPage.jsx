// Appointment Letter Generator — mirrors Flutter hr_appointment_letter_screen.dart
// Collection: data/{cid}/hr_documents
// Generates PDF using jsPDF + jspdf-autotable

import { useEffect, useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  ArrowLeft, Loader2, UserCheck, Building2, Calendar, Briefcase,
  DollarSign, FileText, Shield, Download, Save, Eye, EyeOff, RefreshCw,
} from 'lucide-react';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, add } from '../lib/db';
import { formatDate, formatCurrency } from '../lib/utils';
import { EmployeePicker, EmployeeAvatar } from '../components/ui/EmployeePicker';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '../firebase';

// ─── helpers ────────────────────────────────────────────────────────────────
function todayISO() { return new Date().toISOString().split('T')[0]; }
function plusDays(iso, n) {
  const d = new Date(iso + 'T00:00:00');
  d.setDate(d.getDate() + n);
  return d.toISOString().split('T')[0];
}
function genLetterNo() {
  const y = new Date().getFullYear();
  const n = String(Math.floor(Math.random() * 900) + 100);
  return `HR/APP/${y}-${n}`;
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

const APPT_TYPES = ['Permanent', 'Probation', 'Contract', 'Internship'];
const PROBATION_OPTIONS = ['None', '3 Months', '6 Months', '1 Year'];

// ─── PDF generation ─────────────────────────────────────────────────────────
function generateAppointmentPDF(data) {
  const {
    companyName, companyAddress, companyWebsite,
    candidateName, candidateAddress, designation, department,
    appointmentType, issueDate, joiningDate, letterNo, refNo,
    grossSalary, salaryInWords, probationPeriod, noticePeriod, specialTerms,
    workLocation, workingHours,
    authorizedBy, authorDesig,
    inclSalaryBreakdown, inclSeal, inclEmployeeAccept,
    lang,
  } = data;

  const isBn = lang === 'Bangla';
  const pdf  = new jsPDF({ unit: 'pt', format: 'a4' });
  const W    = pdf.internal.pageSize.getWidth();
  const M    = 50;
  let   y    = M;

  // Header
  pdf.setFont('times', 'bold');
  pdf.setFontSize(16);
  pdf.setTextColor(6, 95, 70);
  pdf.text((companyName || 'Company Name').toUpperCase(), W / 2, y, { align: 'center' });
  y += 18;
  pdf.setFont('times', 'normal');
  pdf.setFontSize(10);
  pdf.setTextColor(80, 80, 80);
  pdf.text(companyAddress || '', W / 2, y, { align: 'center' });
  if (companyWebsite) { y += 12; pdf.text(companyWebsite, W / 2, y, { align: 'center' }); }
  y += 14;
  pdf.setDrawColor(6, 95, 70);
  pdf.setLineWidth(1.5);
  pdf.line(M, y, W - M, y);
  y += 16;

  // Ref + Date row
  pdf.setFont('times', 'normal');
  pdf.setFontSize(10);
  pdf.setTextColor(0, 0, 0);
  pdf.text(`Ref: ${letterNo}${refNo ? ' / ' + refNo : ''}`, M, y);
  pdf.text(`Date: ${issueDate}`, W - M, y, { align: 'right' });
  y += 24;

  // Title
  const title = isBn ? 'নিয়োগপত্র' : 'APPOINTMENT LETTER';
  pdf.setFont('times', 'bold');
  pdf.setFontSize(14);
  pdf.text(title, W / 2, y, { align: 'center' });
  const tw = pdf.getTextWidth(title);
  pdf.setLineWidth(0.8);
  pdf.line((W - tw) / 2, y + 2, (W + tw) / 2, y + 2);
  y += 24;

  // Candidate address block
  pdf.setFont('times', 'normal');
  pdf.setFontSize(11);
  pdf.text(isBn ? 'বরাবর,' : 'To,', M, y);
  y += 14;
  pdf.setFont('times', 'bold');
  pdf.text(candidateName || '', M, y);
  y += 12;
  pdf.setFont('times', 'normal');
  pdf.setFontSize(10);
  pdf.setTextColor(80, 80, 80);
  if (candidateAddress) {
    const addrLines = pdf.splitTextToSize(candidateAddress, W - M * 2 - 100);
    pdf.text(addrLines, M, y);
    y += addrLines.length * 12;
  }
  y += 10;

  // Subject
  pdf.setFont('times', 'bold');
  pdf.setFontSize(11);
  pdf.setTextColor(0, 0, 0);
  const subject = isBn
    ? `বিষয়: ${designation || 'পদে'} (${appointmentType}) নিয়োগ প্রসঙ্গে`
    : `Subject: Appointment as ${designation || 'Position'} (${appointmentType})`;
  pdf.text(subject, M, y);
  y += 20;

  // Body
  pdf.setFont('times', 'normal');
  pdf.setFontSize(11);
  const body = isBn
    ? `প্রিয় ${candidateName},\n\nআমরা আপনাকে ${joiningDate} তারিখ থেকে ${department || ''} বিভাগে ${designation || ''} পদে ${appointmentType} ভিত্তিতে নিয়োগ করতে পেরে আনন্দিত।`
    : `Dear ${candidateName},\n\nWe are pleased to appoint you as ${designation || 'Position'} in the ${department || ''} department on a ${appointmentType} basis, effective ${joiningDate}.`;
  const bodyLines = pdf.splitTextToSize(body, W - M * 2);
  pdf.text(bodyLines, M, y);
  y += bodyLines.length * 14 + 10;

  // Salary section
  const gross = Number(grossSalary) || 0;
  if (gross > 0) {
    pdf.setFont('times', 'bold');
    pdf.setFontSize(11);
    pdf.text(isBn ? 'ক্ষতিপূরণ ও সুবিধাদি' : 'Compensation & Benefits', M, y);
    y += 14;

    if (inclSalaryBreakdown) {
      const basic = Math.round(gross * 0.60);
      const hra   = Math.round(gross * 0.30);
      const med   = Math.round(gross * 0.05);
      const conv  = gross - basic - hra - med;
      autoTable(pdf, {
        startY: y,
        head: [[isBn ? 'উপাদান' : 'Component', isBn ? 'পরিমাণ (BDT)' : 'Amount (BDT)']],
        body: [
          [isBn ? 'মূল বেতন (৬০%)' : 'Basic Salary (60%)',      basic.toLocaleString('en-BD')],
          [isBn ? 'বাড়ি ভাড়া (৩০%)' : 'House Rent (30%)',       hra.toLocaleString('en-BD')],
          [isBn ? 'চিকিৎসা (৫%)' : 'Medical (5%)',              med.toLocaleString('en-BD')],
          [isBn ? 'যাতায়াত (৫%)' : 'Conveyance (5%)',          conv.toLocaleString('en-BD')],
        ],
        foot: [[isBn ? 'মোট মাসিক বেতন' : 'Total Gross Salary', gross.toLocaleString('en-BD')]],
        theme: 'grid',
        headStyles: { fillColor: [6, 95, 70], textColor: 255, fontStyle: 'bold', fontSize: 10 },
        footStyles: { fillColor: [240, 253, 244], textColor: [6, 95, 70], fontStyle: 'bold', fontSize: 10 },
        bodyStyles: { fontSize: 10 },
        margin: { left: M, right: M },
      });
      y = pdf.lastAutoTable.finalY + 10;
    } else {
      pdf.setFont('times', 'normal');
      pdf.setFontSize(11);
      pdf.text(`Monthly Gross Salary: BDT ${gross.toLocaleString('en-BD')}`, M, y);
      y += 16;
    }
    if (salaryInWords) {
      pdf.setFont('times', 'italic');
      pdf.setFontSize(10);
      pdf.setTextColor(80, 80, 80);
      pdf.text(`(${isBn ? 'কথায়' : 'In words'}: ${salaryInWords})`, M, y);
      y += 16;
      pdf.setTextColor(0, 0, 0);
    }
  }

  // Terms & Conditions
  y += 4;
  pdf.setFont('times', 'bold');
  pdf.setFontSize(11);
  pdf.text(isBn ? 'শর্তাবলী' : 'Terms & Conditions', M, y);
  y += 14;
  pdf.setFont('times', 'normal');
  pdf.setFontSize(10);
  const terms = [
    `${isBn ? 'নোটিশ পিরিয়ড' : 'Notice Period'}: ${noticePeriod || '30 Days'}`,
    `${isBn ? 'পরীক্ষামূলক সময়' : 'Probation Period'}: ${probationPeriod || 'None'}`,
    `${isBn ? 'কর্মঘণ্টা' : 'Working Hours'}: ${workingHours || 'Regular (9:00 AM – 6:00 PM)'}`,
    `${isBn ? 'কর্মস্থল' : 'Work Location'}: ${workLocation || 'Head Office'}`,
  ];
  terms.forEach(t => {
    pdf.text(`• ${t}`, M + 6, y);
    y += 13;
  });
  if (specialTerms) {
    const stLines = pdf.splitTextToSize(`• ${specialTerms}`, W - M * 2 - 6);
    pdf.text(stLines, M + 6, y);
    y += stLines.length * 13;
  }
  y += 10;

  // Closing
  pdf.setFont('times', 'normal');
  pdf.setFontSize(11);
  const closing = isBn
    ? 'আমরা আশা করি আপনি আমাদের দলে মূল্যবান অবদান রাখবেন।'
    : 'We look forward to your valuable contribution to our team.';
  pdf.text(closing, M, y);
  y += 30;

  // Signatory
  const [sigName, sigDesig] = (authorizedBy || '').split(' - ');
  pdf.setFont('times', 'bold');
  pdf.setFontSize(11);
  pdf.text(sigName || authorizedBy || '', M, y);
  y += 14;
  pdf.setFont('times', 'normal');
  pdf.setFontSize(10);
  pdf.setTextColor(80, 80, 80);
  pdf.text(sigDesig || authorDesig || '', M, y);
  y += 12;
  pdf.text(companyName || '', M, y);

  // Seal
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

  // Employee acceptance block
  if (inclEmployeeAccept) {
    y += 40;
    pdf.setDrawColor(200, 200, 200);
    pdf.setLineWidth(0.5);
    pdf.line(M, y, W - M, y);
    y += 14;
    pdf.setFont('times', 'bold');
    pdf.setFontSize(11);
    pdf.setTextColor(0, 0, 0);
    pdf.text(isBn ? 'কর্মীর স্বীকৃতি' : 'Employee Acceptance', M, y);
    y += 14;
    pdf.setFont('times', 'normal');
    pdf.setFontSize(10);
    const accept = isBn
      ? `আমি, ${candidateName}, উপরোক্ত নিয়োগের শর্তাবলী পড়েছি এবং সম্মত হচ্ছি।`
      : `I, ${candidateName}, have read and agree to the terms and conditions of this appointment.`;
    pdf.text(pdf.splitTextToSize(accept, W - M * 2), M, y);
    y += 30;
    pdf.line(M, y, M + 160, y);
    pdf.line(W - M - 160, y, W - M, y);
    y += 12;
    pdf.setFontSize(9);
    pdf.setTextColor(80, 80, 80);
    pdf.text(isBn ? 'কর্মীর স্বাক্ষর ও তারিখ' : 'Employee Signature & Date', M, y);
    pdf.text(isBn ? 'সাক্ষীর স্বাক্ষর ও তারিখ' : 'Witness Signature & Date', W - M - 160, y);
  }

  const fname = `Appointment_Letter_${(candidateName || 'Candidate').replace(/\s+/g, '_')}_${todayISO().replace(/-/g, '')}.pdf`;
  pdf.save(fname);
}

// ─── Main component ──────────────────────────────────────────────────────────
export function AppointmentLetterPage() {
  const { session } = useAuth();
  const cid      = session?.companyId || '';
  const navigate = useNavigate();

  const [employees,   setEmployees]   = useState([]);
  const [companyInfo, setCompanyInfo] = useState({});
  const [selectedEmp, setSelectedEmp] = useState(null);
  const [loadingEmps, setLoadingEmps] = useState(true);
  const [saving,      setSaving]      = useState(false);
  const [saved,       setSaved]       = useState(false);
  const [showPreview, setShowPreview] = useState(true);
  const [lang,        setLang]        = useState('English');

  const today = todayISO();

  const [form, setForm] = useState({
    letterNo:         genLetterNo(),
    refNo:            '',
    appointmentType:  'Permanent',
    issueDate:        today,
    joiningDate:      plusDays(today, 7),
    grossSalary:      '',
    salaryInWords:    '',
    probationPeriod:  'None',
    noticePeriod:     '30 Days',
    specialTerms:     '',
    workLocation:     'Head Office',
    workingHours:     'Regular (9:00 AM – 6:00 PM)',
    authorizedBy:     '',
    authorDesig:      '',
    inclSalaryBreakdown: true,
    inclSeal:            true,
    inclEmployeeAccept:  true,
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
          const name  = d.fullName || d.name || '';
          const desig = d.designation || d.jobTitle || 'HR Director';
          setForm(f => ({ ...f, authorizedBy: `${name} - ${desig}`, authorDesig: desig }));
        }
      });
    }
  }, [cid, session?.uid]);

  // Auto-update salary in words
  useEffect(() => {
    const g = Number(form.grossSalary) || 0;
    if (g > 0) set('salaryInWords', numToWords(g) + ' Taka Only');
    else set('salaryInWords', '');
  }, [form.grossSalary]);

  // Salary breakdown
  const gross = Number(form.grossSalary) || 0;
  const breakdown = useMemo(() => ({
    basic: Math.round(gross * 0.60),
    hra:   Math.round(gross * 0.30),
    med:   Math.round(gross * 0.05),
    conv:  gross - Math.round(gross * 0.60) - Math.round(gross * 0.30) - Math.round(gross * 0.05),
  }), [gross]);

  async function handleSave() {
    if (!selectedEmp) { alert('Please select a candidate.'); return; }
    setSaving(true);
    try {
      await add(col(cid, 'hr_documents'), {
        type:                'Appointment Letter',
        letterNo:            form.letterNo,
        refNo:               form.refNo,
        appointmentType:     form.appointmentType,
        language:            lang,
        candidateName:       selectedEmp._displayName || selectedEmp.fullName || '',
        candidateId:         selectedEmp.employeeId || selectedEmp.id || '',
        candidateEmail:      selectedEmp.email || selectedEmp.officeEmail || '',
        candidatePhone:      selectedEmp.phone || '',
        designation:         selectedEmp.designation || selectedEmp.jobTitle || '',
        department:          selectedEmp.department || '',
        issueDate:           form.issueDate,
        joiningDate:         form.joiningDate,
        grossSalary:         gross,
        salaryInWords:       form.salaryInWords,
        probationPeriod:     form.probationPeriod,
        noticePeriod:        form.noticePeriod,
        specialTerms:        form.specialTerms,
        workLocation:        form.workLocation,
        workingHours:        form.workingHours,
        authorizedBy:        form.authorizedBy,
        inclSalaryBreakdown: form.inclSalaryBreakdown,
        inclSeal:            form.inclSeal,
        inclEmployeeAccept:  form.inclEmployeeAccept,
        status:              'Draft',
        employeeUid:         selectedEmp.id || '',
        employeeName:        selectedEmp._displayName || selectedEmp.fullName || '',
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (e) { alert(e.message); }
    finally { setSaving(false); }
  }

  function handleGeneratePDF() {
    if (!selectedEmp) { alert('Please select a candidate first.'); return; }
    generateAppointmentPDF({
      companyName:    companyInfo.companyName || companyInfo.legalName || 'Company',
      companyAddress: companyInfo.registeredAddress || '',
      companyWebsite: companyInfo.website || '',
      candidateName:  selectedEmp._displayName || selectedEmp.fullName || '',
      candidateAddress: selectedEmp.address || '',
      designation:    selectedEmp.designation || selectedEmp.jobTitle || '',
      department:     selectedEmp.department || '',
      appointmentType: form.appointmentType,
      issueDate:      form.issueDate,
      joiningDate:    form.joiningDate,
      letterNo:       form.letterNo,
      refNo:          form.refNo,
      grossSalary:    gross,
      salaryInWords:  form.salaryInWords,
      probationPeriod: form.probationPeriod,
      noticePeriod:   form.noticePeriod,
      specialTerms:   form.specialTerms,
      workLocation:   form.workLocation,
      workingHours:   form.workingHours,
      authorizedBy:   form.authorizedBy,
      authorDesig:    form.authorDesig,
      inclSalaryBreakdown: form.inclSalaryBreakdown,
      inclSeal:       form.inclSeal,
      inclEmployeeAccept: form.inclEmployeeAccept,
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
            <h2 className="page-title">New Appointment Letter</h2>
            <p className="page-sub">Appointment Letter · {lang} Format</p>
          </div>
        </div>
        <div className="flex bg-gray-100 rounded-xl p-1 gap-1">
          {['English', 'Bangla'].map(l => (
            <button key={l} onClick={() => setLang(l)}
              className={`px-4 py-1.5 rounded-lg text-sm font-semibold transition ${
                lang === l ? 'bg-white shadow text-[#065F46]' : 'text-gray-500 hover:text-gray-700'
              }`}>
              {l === 'English' ? 'English' : 'বাংলা (Bangla)'}
            </button>
          ))}
        </div>
      </div>

      <div className="grid lg:grid-cols-[1fr_420px] gap-5">
        {/* Left — Form */}
        <div className="space-y-4">

          {/* Setup & Format */}
          <div className="card p-5 space-y-4">
            <SectionHeader icon={<FileText size={14} className="text-indigo-600" />} bg="bg-indigo-50" title="Setup & Format" />
            <div>
              <label className="label">Appointment Type</label>
              <div className="flex flex-wrap gap-2">
                {APPT_TYPES.map(t => (
                  <button key={t} type="button" onClick={() => set('appointmentType', t)}
                    className={`px-4 py-1.5 rounded-full text-sm font-semibold border transition ${
                      form.appointmentType === t
                        ? 'bg-[#065F46] text-white border-[#065F46]'
                        : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
                    }`}>
                    {t}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Select Candidate */}
          <div className="card p-5 space-y-4">
            <SectionHeader icon={<UserCheck size={14} className="text-[#065F46]" />} bg="bg-[#065F46]/10" title="Select Candidate" />
            {loadingEmps ? (
              <div className="flex items-center gap-2 text-gray-400 py-4">
                <Loader2 size={16} className="animate-spin" /> Loading employees…
              </div>
            ) : (
              <EmployeePicker employees={employees} value={selectedEmp} onChange={setSelectedEmp} required />
            )}
            {selectedEmp && (
              <div className="grid grid-cols-2 gap-2 mt-1">
                {[
                  { label: 'Email',       value: selectedEmp.email || selectedEmp.officeEmail || '—' },
                  { label: 'Phone',       value: selectedEmp.phone || '—' },
                  { label: 'Designation', value: selectedEmp.designation || selectedEmp.jobTitle || '—' },
                  { label: 'Department',  value: selectedEmp.department || '—' },
                ].map(f => (
                  <div key={f.label} className="bg-gray-50 rounded-xl p-2.5">
                    <p className="text-xs text-gray-400">{f.label}</p>
                    <p className="text-xs font-semibold text-gray-800 truncate">{f.value}</p>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Issuing Company */}
          <div className="card p-5 space-y-3">
            <div className="flex items-center justify-between">
              <SectionHeader icon={<Building2 size={14} className="text-amber-600" />} bg="bg-amber-50" title="Issuing Company" />
              <span className="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full font-semibold">Auto-filled</span>
            </div>
            <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl border border-gray-200">
              <div className="w-10 h-10 rounded-xl bg-[#065F46] text-white flex items-center justify-center font-bold text-sm">
                {(companyInfo.companyName || companyInfo.legalName || 'C').charAt(0).toUpperCase()}
              </div>
              <div>
                <p className="font-bold text-gray-900 text-sm">{companyInfo.companyName || companyInfo.legalName || '—'}</p>
                <p className="text-xs text-gray-400">{companyInfo.registeredAddress || '—'}</p>
                {companyInfo.website && <p className="text-xs text-blue-500">{companyInfo.website}</p>}
              </div>
            </div>
          </div>

          {/* Dates & References */}
          <div className="card p-5 space-y-4">
            <SectionHeader icon={<Calendar size={14} className="text-blue-600" />} bg="bg-blue-50" title="Dates & References" />
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="label">Issue Date</label>
                <input className="input" type="date" value={form.issueDate} onChange={e => set('issueDate', e.target.value)} />
              </div>
              <div>
                <label className="label">Joining Date</label>
                <input className="input" type="date" value={form.joiningDate} onChange={e => set('joiningDate', e.target.value)} />
              </div>
              <div>
                <label className="label">Letter No.</label>
                <div className="flex gap-1.5">
                  <input className="input flex-1" value={form.letterNo} onChange={e => set('letterNo', e.target.value)} />
                  <button onClick={() => set('letterNo', genLetterNo())} className="btn-icon" title="Regenerate"><RefreshCw size={13} /></button>
                </div>
              </div>
              <div>
                <label className="label">Ref No. (optional)</label>
                <input className="input" value={form.refNo} onChange={e => set('refNo', e.target.value)} placeholder="Optional" />
              </div>
            </div>
          </div>

          {/* Job & Placement */}
          <div className="card p-5 space-y-4">
            <SectionHeader icon={<Briefcase size={14} className="text-purple-600" />} bg="bg-purple-50" title="Job & Placement" />
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="label">Designation</label>
                <div className="input bg-gray-50 text-gray-600 text-sm">{selectedEmp?.designation || selectedEmp?.jobTitle || '—'}</div>
              </div>
              <div>
                <label className="label">Department</label>
                <div className="input bg-gray-50 text-gray-600 text-sm">{selectedEmp?.department || '—'}</div>
              </div>
              <div>
                <label className="label">Work Location</label>
                <input className="input" value={form.workLocation} onChange={e => set('workLocation', e.target.value)} />
              </div>
              <div>
                <label className="label">Working Hours / Shift</label>
                <input className="input" value={form.workingHours} onChange={e => set('workingHours', e.target.value)} />
              </div>
            </div>
          </div>

          {/* Compensation & Benefits */}
          <div className="card p-5 space-y-4">
            <SectionHeader icon={<DollarSign size={14} className="text-green-600" />} bg="bg-green-50" title="Compensation & Benefits" />
            <div>
              <label className="label">Monthly Gross Salary (BDT)</label>
              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-xs font-semibold">BDT</span>
                <input className="input pl-10 text-[#065F46] font-bold" type="number"
                  value={form.grossSalary} onChange={e => set('grossSalary', e.target.value)} placeholder="0" />
              </div>
            </div>
            {gross > 0 && (
              <div className="rounded-xl bg-green-50 border border-green-200 p-3 space-y-1.5">
                <p className="text-xs font-bold text-green-700 mb-2">Salary Breakdown</p>
                {[
                  { label: 'Basic Salary (60%)', value: breakdown.basic },
                  { label: 'House Rent (30%)',   value: breakdown.hra },
                  { label: 'Medical (5%)',        value: breakdown.med },
                  { label: 'Conveyance (5%)',     value: breakdown.conv },
                ].map(r => (
                  <div key={r.label} className="flex justify-between text-xs">
                    <span className="text-gray-600">{r.label}</span>
                    <span className="font-semibold text-gray-800">{formatCurrency(r.value)}</span>
                  </div>
                ))}
                <div className="border-t border-green-300 pt-1.5 flex justify-between text-sm font-bold text-[#065F46]">
                  <span>Total Gross</span>
                  <span>{formatCurrency(gross)}</span>
                </div>
              </div>
            )}
            <div>
              <label className="label">Salary In Words</label>
              <input className="input" value={form.salaryInWords} onChange={e => set('salaryInWords', e.target.value)} placeholder="Auto-calculated…" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="label">Probation Period</label>
                <select className="input" value={form.probationPeriod} onChange={e => set('probationPeriod', e.target.value)}>
                  {PROBATION_OPTIONS.map(o => <option key={o}>{o}</option>)}
                </select>
              </div>
              <div>
                <label className="label">Pay Frequency</label>
                <div className="input bg-gray-50 text-gray-500 text-sm">Monthly</div>
              </div>
            </div>
          </div>

          {/* Terms & Conditions */}
          <div className="card p-5 space-y-4">
            <SectionHeader icon={<FileText size={14} className="text-gray-600" />} bg="bg-gray-100" title="Terms & Conditions" />
            <div>
              <label className="label">Notice Period</label>
              <input className="input" value={form.noticePeriod} onChange={e => set('noticePeriod', e.target.value)} />
            </div>
            <div>
              <label className="label">Special Conditions (optional)</label>
              <textarea className="input" rows={3} value={form.specialTerms} onChange={e => set('specialTerms', e.target.value)} placeholder="Any special terms or conditions…" />
            </div>
          </div>

          {/* Approval & Signatures */}
          <div className="card p-5 space-y-4">
            <SectionHeader icon={<Shield size={14} className="text-blue-600" />} bg="bg-blue-50" title="Approval & Signatures" />
            <div>
              <label className="label">Authorized Signatory</label>
              <input className="input" value={form.authorizedBy} onChange={e => set('authorizedBy', e.target.value)} placeholder="Name - Designation" />
            </div>
            <div className="space-y-3">
              <Toggle checked={form.inclSalaryBreakdown} onChange={v => set('inclSalaryBreakdown', v)} label="Include Salary Breakdown" />
              <Toggle checked={form.inclSeal}            onChange={v => set('inclSeal', v)}            label="Official Company Seal" />
              <Toggle checked={form.inclEmployeeAccept}  onChange={v => set('inclEmployeeAccept', v)}  label="Employee Acceptance Block" />
            </div>
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
              <AppointmentPreview
                companyName={companyInfo.companyName || companyInfo.legalName || 'Company Name'}
                companyAddress={companyInfo.registeredAddress || ''}
                companyWebsite={companyInfo.website || ''}
                emp={selectedEmp}
                form={form}
                gross={gross}
                breakdown={breakdown}
                lang={lang}
              />
            </div>
          )}
        </div>
      </div>

      {/* Bottom action bar */}
      <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 px-6 py-3 flex justify-end gap-3 z-30">
        <button onClick={() => navigate('/hr/authorization')} className="btn-secondary">
          <ArrowLeft size={15} /> Back
        </button>
        <button onClick={handleSave} disabled={saving || !selectedEmp} className="btn-secondary">
          {saving ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
          {saved ? 'Saved ✓' : saving ? 'Saving…' : 'Save Draft'}
        </button>
        <button onClick={handleGeneratePDF} disabled={!selectedEmp} className="btn-primary">
          <Download size={14} /> Generate PDF
        </button>
      </div>
    </div>
  );
}

// ─── Section header helper ───────────────────────────────────────────────────
function SectionHeader({ icon, bg, title }) {
  return (
    <div className="flex items-center gap-2">
      <div className={`w-7 h-7 rounded-lg ${bg} flex items-center justify-center`}>{icon}</div>
      <h3 className="font-bold text-gray-900">{title}</h3>
    </div>
  );
}

// ─── Live A4 Preview ─────────────────────────────────────────────────────────
function AppointmentPreview({ companyName, companyAddress, companyWebsite, emp, form, gross, breakdown, lang }) {
  const isBn = lang === 'Bangla';
  return (
    <div className="bg-white p-6 text-[10px] leading-relaxed min-h-[600px]" style={{ fontFamily: 'Georgia, serif' }}>
      {/* Header */}
      <div className="text-center mb-3">
        <p className="text-sm font-bold text-[#065F46] uppercase tracking-wide">{companyName}</p>
        <p className="text-gray-500 text-[9px]">{companyAddress}</p>
        {companyWebsite && <p className="text-blue-500 text-[9px]">{companyWebsite}</p>}
        <div className="border-t-2 border-[#065F46] mt-2" />
      </div>
      <div className="flex justify-between text-[9px] text-gray-500 mb-3">
        <span>Ref: {form.letterNo}</span>
        <span>Date: {form.issueDate}</span>
      </div>
      <p className="text-center font-bold underline text-xs mb-3">
        {isBn ? 'নিয়োগপত্র' : 'APPOINTMENT LETTER'}
      </p>
      <p className="text-[9px] text-gray-500 mb-1">{isBn ? 'বরাবর,' : 'To,'}</p>
      <p className="font-bold text-[10px]">{emp?._displayName || emp?.fullName || '[Candidate Name]'}</p>
      <p className="text-[9px] text-gray-400 mb-3">{emp?.department || '[Department]'}</p>

      <p className="font-bold text-[9px] mb-1">
        {isBn
          ? `বিষয়: ${emp?.designation || 'পদে'} (${form.appointmentType}) নিয়োগ`
          : `Subject: Appointment as ${emp?.designation || 'Position'} (${form.appointmentType})`}
      </p>
      <p className="text-gray-700 text-[9px] mb-3">
        {isBn
          ? `প্রিয় ${emp?._displayName || '[নাম]'}, আমরা আপনাকে ${form.joiningDate} থেকে ${form.appointmentType} ভিত্তিতে নিয়োগ করতে পেরে আনন্দিত।`
          : `Dear ${emp?._displayName || '[Name]'}, We are pleased to appoint you as ${emp?.designation || 'Position'} on a ${form.appointmentType} basis, effective ${form.joiningDate}.`}
      </p>

      {gross > 0 && form.inclSalaryBreakdown && (
        <div className="mb-3">
          <p className="font-bold text-[9px] mb-1">{isBn ? 'বেতন বিবরণ' : 'Compensation'}</p>
          <table className="w-full border-collapse text-[8px]">
            <thead>
              <tr className="bg-[#065F46] text-white">
                <th className="border border-[#065F46] px-1.5 py-0.5 text-left">{isBn ? 'উপাদান' : 'Component'}</th>
                <th className="border border-[#065F46] px-1.5 py-0.5 text-right">{isBn ? 'পরিমাণ' : 'Amount'}</th>
              </tr>
            </thead>
            <tbody>
              {[
                [isBn ? 'মূল বেতন (৬০%)' : 'Basic (60%)',  breakdown.basic],
                [isBn ? 'বাড়ি ভাড়া (৩০%)' : 'HRA (30%)',  breakdown.hra],
                [isBn ? 'চিকিৎসা (৫%)' : 'Medical (5%)',   breakdown.med],
                [isBn ? 'যাতায়াত (৫%)' : 'Conveyance (5%)',breakdown.conv],
              ].map(([l, v]) => (
                <tr key={l}><td className="border border-gray-200 px-1.5 py-0.5">{l}</td><td className="border border-gray-200 px-1.5 py-0.5 text-right">{v.toLocaleString()}</td></tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="bg-green-50 font-bold text-[#065F46]">
                <td className="border border-gray-200 px-1.5 py-0.5">{isBn ? 'মোট' : 'Total'}</td>
                <td className="border border-gray-200 px-1.5 py-0.5 text-right">{gross.toLocaleString()}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      <div className="mt-4 flex justify-between items-end">
        <div>
          <p className="font-bold text-[10px]">{(form.authorizedBy || '').split(' - ')[0] || '—'}</p>
          <p className="text-gray-400 text-[8px]">{form.authorDesig}</p>
          <p className="text-gray-400 text-[8px]">{companyName}</p>
        </div>
        {form.inclSeal && (
          <div className="w-12 h-12 rounded-full border-2 border-[#065F46] flex items-center justify-center text-[6px] text-[#065F46] font-bold text-center leading-tight">
            OFFICIAL<br />SEAL
          </div>
        )}
      </div>

      {form.inclEmployeeAccept && (
        <div className="mt-4 border-t border-gray-200 pt-3">
          <p className="font-bold text-[9px] mb-1">{isBn ? 'কর্মীর স্বীকৃতি' : 'Employee Acceptance'}</p>
          <div className="flex justify-between mt-3">
            <div className="border-t border-gray-400 w-28 text-[7px] text-gray-400 pt-0.5">{isBn ? 'কর্মীর স্বাক্ষর' : 'Employee Signature'}</div>
            <div className="border-t border-gray-400 w-28 text-[7px] text-gray-400 pt-0.5">{isBn ? 'সাক্ষীর স্বাক্ষর' : 'Witness Signature'}</div>
          </div>
        </div>
      )}
    </div>
  );
}
