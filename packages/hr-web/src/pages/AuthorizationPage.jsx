// Authorization Hub — mirrors Flutter hr_authorization_screen.dart
// Shows doc-type cards + recent documents, navigates to sub-pages

import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, X, Loader2, ShieldCheck, FileText, Award, UserCheck, Clock } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { col, subscribe, orderBy, limit } from '../lib/db';
import { formatDate } from '../lib/utils';
import { EmployeeAvatar } from '../components/ui/EmployeePicker';

const DOC_TYPE_META = {
  'Salary Certificate': {
    icon: <Award size={22} />,
    badge: 'Most Used',
    badgeColor: 'bg-green-100 text-green-700',
    chips: ['Salary breakdown table', 'English & Bangla format', 'Digital signature & seal', 'PDF download'],
    route: 'salary-certificate',
    color: 'from-[#065F46] to-[#059669]',
  },
  'Appointment Letter': {
    icon: <UserCheck size={22} />,
    badge: 'New Hire',
    badgeColor: 'bg-blue-100 text-blue-700',
    chips: ['Compensation breakdown', 'Appointment type', 'Terms & conditions', 'Employee acceptance block'],
    route: 'appointment-letter',
    color: 'from-[#1D4ED8] to-[#3B82F6]',
  },
};

const TYPE_ICON = {
  'Salary Certificate': <Award size={16} className="text-green-600" />,
  'Appointment Letter': <UserCheck size={16} className="text-blue-600" />,
};

export function AuthorizationPage() {
  const { session } = useAuth();
  const cid = session?.companyId || '';
  const navigate = useNavigate();

  const [docs,    setDocs]    = useState([]);
  const [search,  setSearch]  = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!cid) return;
    const unsub = subscribe(col(cid, 'hr_documents'), (d) => {
      setDocs(d);
      setLoading(false);
    }, [orderBy('createdAt', 'desc'), limit(100)]);
    return unsub;
  }, [cid]);

  const recentDocs = docs.slice(0, 5);

  const filtered = docs.filter(d => {
    const q = search.toLowerCase();
    return !q
      || (d.employeeName || '').toLowerCase().includes(q)
      || (d.type || '').toLowerCase().includes(q)
      || (d.department || '').toLowerCase().includes(q);
  });

  const certCount   = docs.filter(d => d.type === 'Salary Certificate').length;
  const letterCount = docs.filter(d => d.type === 'Appointment Letter').length;

  return (
    <div className="space-y-6">
      {/* Hero banner — mirrors Flutter gradient card */}
      <div className="rounded-2xl p-6 text-white relative overflow-hidden"
        style={{ background: 'linear-gradient(135deg, #065F46, #059669)' }}>
        <div className="absolute right-4 top-4 opacity-10">
          <ShieldCheck size={80} />
        </div>
        <div className="relative">
          <p className="text-white/70 text-sm font-medium uppercase tracking-wider mb-1">HR Module</p>
          <h1 className="text-2xl font-black">Document Authorization</h1>
          <p className="text-white/80 text-sm mt-1">Generate official HR documents with digital signatures and PDF export</p>
          <div className="flex gap-4 mt-4">
            <div className="bg-white/10 rounded-xl px-4 py-2 text-center">
              <p className="text-xl font-bold">{certCount}</p>
              <p className="text-white/70 text-xs">Certificates</p>
            </div>
            <div className="bg-white/10 rounded-xl px-4 py-2 text-center">
              <p className="text-xl font-bold">{letterCount}</p>
              <p className="text-white/70 text-xs">Letters</p>
            </div>
            <div className="bg-white/10 rounded-xl px-4 py-2 text-center">
              <p className="text-xl font-bold">{docs.length}</p>
              <p className="text-white/70 text-xs">Total Docs</p>
            </div>
          </div>
        </div>
      </div>

      {/* Select Document Type — mirrors Flutter _DocTypeCard */}
      <div>
        <p className="text-xs font-black uppercase tracking-wider text-gray-500 mb-3">Select Document Type</p>
        <div className="grid sm:grid-cols-2 gap-4">
          {Object.entries(DOC_TYPE_META).map(([type, meta]) => (
            <button key={type} onClick={() => navigate(`/hr/authorization/${meta.route}`)}
              className="card p-5 text-left hover:shadow-card-md transition-all group hover:-translate-y-0.5 w-full">
              <div className="flex items-start justify-between mb-3">
                <div className={`w-12 h-12 rounded-2xl bg-gradient-to-br ${meta.color} text-white flex items-center justify-center shadow-md`}>
                  {meta.icon}
                </div>
                <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${meta.badgeColor}`}>
                  {meta.badge}
                </span>
              </div>
              <h3 className="font-bold text-gray-900 text-base mb-1">{type}</h3>
              <p className="text-sm text-gray-500 mb-3">
                {type === 'Salary Certificate'
                  ? 'Official salary confirmation for banks, embassies & institutions'
                  : 'Formal employment offer with compensation & terms'}
              </p>
              <div className="flex flex-wrap gap-1.5">
                {meta.chips.map(chip => (
                  <span key={chip} className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full border border-gray-200">
                    {chip}
                  </span>
                ))}
              </div>
              <div className="mt-4 flex items-center gap-1.5 text-[#065F46] font-semibold text-sm group-hover:gap-2.5 transition-all">
                <span>Generate Document</span>
                <span>→</span>
              </div>
            </button>
          ))}
        </div>
      </div>

      {/* Recent Documents — mirrors Flutter _RecentDocs */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <p className="text-xs font-black uppercase tracking-wider text-gray-500">Recent Documents</p>
          <div className="relative">
            <Search size={13} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400" />
            <input className="input pl-8 py-1.5 text-xs w-52" placeholder="Search employee, type…"
              value={search} onChange={e => setSearch(e.target.value)} />
            {search && <button onClick={() => setSearch('')} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400"><X size={12} /></button>}
          </div>
        </div>

        {loading ? (
          <div className="flex justify-center py-10"><Loader2 size={22} className="animate-spin text-[#065F46]" /></div>
        ) : (
          <div className="card">
            <div className="table-wrap border-0 rounded-none">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Employee</th>
                    <th>Department</th>
                    <th>Document Type</th>
                    <th>Issued By</th>
                    <th>Date</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="text-center py-12">
                        <div className="flex flex-col items-center gap-2 text-gray-400">
                          <FileText size={28} className="opacity-30" />
                          <p className="text-sm">No documents yet — generate one above</p>
                        </div>
                      </td>
                    </tr>
                  ) : filtered.map(d => (
                    <tr key={d.id}>
                      <td>
                        <div className="flex items-center gap-2.5">
                          <EmployeeAvatar emp={d} size={8} />
                          <div>
                            <p className="font-semibold text-gray-900 text-sm">{d.employeeName || d.candidateName || '—'}</p>
                            {d.designation && <p className="text-xs text-gray-400">{d.designation}</p>}
                          </div>
                        </div>
                      </td>
                      <td className="capitalize text-gray-500">{d.department || '—'}</td>
                      <td>
                        <div className="flex items-center gap-1.5">
                          {TYPE_ICON[d.type] || <FileText size={14} className="text-gray-400" />}
                          <span className="text-sm text-gray-700">{d.type || '—'}</span>
                        </div>
                      </td>
                      <td className="text-gray-500 text-sm">{d.authorizedBy || d.issuedBy || d.createdBy || '—'}</td>
                      <td className="text-gray-400 text-xs">{formatDate(d.createdAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
