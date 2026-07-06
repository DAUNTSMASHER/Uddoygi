import { useState } from 'react';
import {
  ArrowRight, Eye, EyeOff, Loader2, AlertCircle,
  Users, DollarSign, Calendar, CheckCircle, Shield, Globe,
} from 'lucide-react';
import { lookupCompany } from '../lib/companyVerification';
import { useAuth } from '../context/AuthContext';

// ── Feature list shown on left panel ─────────────────────────────────────────
const FEATURES = [
  { icon: Users,       label: 'Employee Management',  sub: 'Full directory, roles & profiles' },
  { icon: DollarSign,  label: 'Payroll Processing',   sub: 'Automated salary & slip generation' },
  { icon: Calendar,    label: 'Leave & Attendance',   sub: 'Real-time tracking & approvals' },
  { icon: Shield,      label: 'Secure & Multi-tenant',sub: 'Company-isolated data access' },
];

// ── Error banner ──────────────────────────────────────────────────────────────
function ErrorBanner({ message }) {
  return (
    <div className="flex items-start gap-2.5 p-3.5 bg-red-50 border border-red-100 rounded-xl text-sm text-red-700">
      <AlertCircle size={15} className="shrink-0 mt-0.5" />
      <span className="leading-snug">{message}</span>
    </div>
  );
}

// ── Main login page ───────────────────────────────────────────────────────────
export function LoginPage() {
  const { login } = useAuth();

  const [phase,       setPhase]       = useState('company'); // 'company' | 'credentials'
  const [cid,         setCid]         = useState('');
  const [company,     setCompany]     = useState(null);
  const [fetchingCo,  setFetchingCo]  = useState(false);

  const [email,       setEmail]       = useState('');
  const [password,    setPassword]    = useState('');
  const [showPw,      setShowPw]      = useState(false);
  const [loggingIn,   setLoggingIn]   = useState(false);

  const [error, setError] = useState('');

  // ── Phase 1: verify company ───────────────────────────────────────────────
  async function handleCompanyContinue(e) {
    e.preventDefault();
    setError('');
    if (!/^\d{8}$/.test(cid.trim())) {
      setError('Company ID must be exactly 8 digits.');
      return;
    }
    setFetchingCo(true);
    try {
      const info = await lookupCompany(cid.trim());
      if (!info) {
        setError("We don't recognise that Company ID. Please double-check.");
        return;
      }
      setCompany(info);
      setPhase('credentials');
    } catch (err) {
      setError(err.message || 'Could not verify Company ID. Check your connection.');
    } finally {
      setFetchingCo(false);
    }
  }

  // ── Phase 2: sign in ──────────────────────────────────────────────────────
  async function handleSignIn(e) {
    e.preventDefault();
    setError('');
    if (!email || !password) { setError('Please enter email and password.'); return; }
    setLoggingIn(true);
    try {
      await login(email, password, cid.trim());
    } catch (err) {
      const code = err.code || '';
      if (code.includes('user-not-found') || code.includes('invalid-credential') || code.includes('wrong-password')) {
        setError('Email or password is incorrect. Please try again.');
      } else if (code.includes('too-many-requests')) {
        setError('Too many failed attempts. Please wait a few minutes and try again.');
      } else {
        setError(err.message || 'Sign-in failed. Please try again.');
      }
    } finally {
      setLoggingIn(false);
    }
  }

  return (
    <div className="min-h-screen flex" style={{ background: '#F1F8F4' }}>

      {/* ── Left branding panel ──────────────────────────────────────────── */}
      <div className="hidden lg:flex lg:w-[460px] xl:w-[500px] shrink-0 flex-col relative overflow-hidden sidebar-bg">

        {/* Decorative circles */}
        <div className="absolute -top-24 -right-24 w-72 h-72 rounded-full bg-white/[0.04]" />
        <div className="absolute top-1/3 -left-16 w-48 h-48 rounded-full bg-white/[0.04]" />
        <div className="absolute -bottom-16 right-8 w-56 h-56 rounded-full bg-white/[0.04]" />

        {/* Content */}
        <div className="relative flex flex-col h-full p-10">

          {/* Logo */}
          <div className="flex items-center gap-3 mb-auto">
            <div className="w-12 h-12 rounded-2xl bg-white flex items-center justify-center overflow-hidden shadow-lg">
              <img src="/logo.png" alt="উদ্যোগী" className="w-full h-full object-contain p-1" />
            </div>
            <div>
              <p className="text-white font-black text-xl leading-none tracking-tight">উদ্যোগী</p>
              <p className="text-white/50 text-xs mt-1">সংগঠিত কোম্পানি, সফল ব্যবসা</p>
            </div>
          </div>

          {/* Headline */}
          <div className="my-12">
            <h1 className="text-4xl xl:text-5xl font-black text-white leading-[1.1] tracking-tight text-balance">
              Manage your<br />
              <span className="text-emerald-200">entire workforce</span><br />
              from anywhere.
            </h1>
            <p className="text-white/60 text-base mt-5 leading-relaxed max-w-sm">
              Payroll, attendance, leaves, recruitment and more — all in one powerful HR dashboard.
            </p>
          </div>

          {/* Feature list */}
          <div className="space-y-4">
            {FEATURES.map(f => (
              <div key={f.label} className="flex items-center gap-4">
                <div className="w-9 h-9 rounded-xl bg-white/10 flex items-center justify-center shrink-0">
                  <f.icon size={16} className="text-blue-200" />
                </div>
                <div>
                  <p className="text-white text-sm font-semibold leading-tight">{f.label}</p>
                  <p className="text-white/50 text-xs mt-0.5">{f.sub}</p>
                </div>
              </div>
            ))}
          </div>

          {/* Footer */}
          <div className="mt-10 pt-6 border-t border-white/10 flex items-center gap-2 text-white/40 text-xs">
            <Globe size={12} />
            <span>Multi-device access · Real-time sync · Secure</span>
          </div>
        </div>
      </div>

      {/* ── Right form panel ─────────────────────────────────────────────── */}
      <div className="flex-1 flex items-center justify-center p-6 lg:p-12">
        <div className="w-full max-w-[400px]">

          {/* Mobile logo */}
          <div className="lg:hidden flex items-center gap-3 mb-10">
            <div className="w-10 h-10 rounded-xl bg-white border border-gray-100 shadow-sm flex items-center justify-center overflow-hidden">
              <img src="/logo.png" alt="উদ্যোগী" className="w-full h-full object-contain p-0.5" />
            </div>
            <div>
              <p className="font-black text-xl text-gray-900 tracking-tight">উদ্যোগী</p>
              <p className="text-xs text-gray-400">HR Portal</p>
            </div>
          </div>

          {/* ── Phase 1: Company ID ── */}
          {phase === 'company' ? (
            <div className="fade-in">
              <div className="mb-8">
                <h2 className="text-3xl font-black text-gray-900 tracking-tight">Welcome back</h2>
                <p className="text-gray-500 text-sm mt-2">Enter your Company ID to continue</p>
              </div>

              <form onSubmit={handleCompanyContinue} className="space-y-5">
                <div>
                  <label className="label">Company ID</label>
                  <input
                    className="input text-center text-3xl font-black tracking-[0.5em] py-4"
                    placeholder="· · · · · · · ·"
                    value={cid}
                    onChange={e => setCid(e.target.value.replace(/\D/g, '').slice(0, 8))}
                    maxLength={8}
                    inputMode="numeric"
                    autoFocus
                    autoComplete="off"
                  />
                  <p className="text-xs text-gray-400 mt-2 text-center">
                    8-digit ID provided at company registration
                  </p>
                </div>

                {error && <ErrorBanner message={error} />}

                <button
                  type="submit"
                  disabled={fetchingCo || cid.length !== 8}
                  className="btn-primary w-full py-3 text-base rounded-xl"
                >
                  {fetchingCo ? (
                    <Loader2 size={17} className="animate-spin" />
                  ) : (
                    <>Continue <ArrowRight size={17} /></>
                  )}
                </button>
              </form>

              <p className="text-center text-xs text-gray-400 mt-8">
                HR Portal · Supports simultaneous multi-device login
              </p>
            </div>

          ) : (
            /* ── Phase 2: Credentials ── */
            <div className="fade-in">

              {/* Company card */}
              <div className="flex items-center gap-3.5 mb-8 p-4 bg-white rounded-2xl border border-gray-100 shadow-sm">
                <div className="w-11 h-11 rounded-xl overflow-hidden bg-[#065F46]/10 flex items-center justify-center shrink-0">
                  {company?.logoUrl ? (
                    <img src={company.logoUrl} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <img src="/logo.png" alt="উদ্যোগী" className="w-8 h-8 object-contain" />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-bold text-gray-900 text-sm truncate">{company?.name}</p>
                  <p className="text-xs text-[#065F46] font-semibold mt-0.5">ID: {company?.companyId}</p>
                </div>
                <button
                  onClick={() => { setPhase('company'); setCompany(null); setError(''); setEmail(''); setPassword(''); }}
                  className="text-xs text-gray-400 hover:text-gray-600 transition font-medium px-2 py-1 rounded-lg hover:bg-gray-100"
                >
                  Change
                </button>
              </div>

              <div className="mb-7">
                <h2 className="text-3xl font-black text-gray-900 tracking-tight">Sign in</h2>
                <p className="text-gray-500 text-sm mt-2">HR & Admin access only</p>
              </div>

              <form onSubmit={handleSignIn} className="space-y-4">
                <div>
                  <label className="label">Email address</label>
                  <input
                    className="input"
                    type="email"
                    placeholder="you@company.com"
                    value={email}
                    onChange={e => setEmail(e.target.value)}
                    autoFocus
                    autoComplete="email"
                  />
                </div>

                <div>
                  <label className="label">Password</label>
                  <div className="relative">
                    <input
                      className="input pr-11"
                      type={showPw ? 'text' : 'password'}
                      placeholder="••••••••"
                      value={password}
                      onChange={e => setPassword(e.target.value)}
                      autoComplete="current-password"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPw(v => !v)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-gray-400 hover:text-gray-600 transition rounded-lg"
                    >
                      {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                </div>

                {error && <ErrorBanner message={error} />}

                <button
                  type="submit"
                  disabled={loggingIn}
                  className="btn-primary w-full py-3 text-base rounded-xl mt-2"
                >
                  {loggingIn ? (
                    <Loader2 size={17} className="animate-spin" />
                  ) : (
                    'Sign In'
                  )}
                </button>
              </form>

              <div className="mt-6 flex items-center gap-2 text-xs text-gray-400">
                <CheckCircle size={13} className="text-[#065F46] shrink-0" />
                You can be signed in on multiple devices simultaneously
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
