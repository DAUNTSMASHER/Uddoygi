import { useState, useRef, useEffect } from 'react';
import { Menu, Bell, LogOut, ChevronDown, Monitor } from 'lucide-react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { initials } from '../../lib/utils';

export function TopBar({ title, onMenuToggle }) {
  const { session, logout } = useAuth();
  const navigate  = useNavigate();
  const location  = useLocation();
  const [dropOpen, setDropOpen] = useState(false);
  const dropRef = useRef(null);

  useEffect(() => {
    function onOutside(e) {
      if (dropRef.current && !dropRef.current.contains(e.target)) setDropOpen(false);
    }
    document.addEventListener('mousedown', onOutside);
    return () => document.removeEventListener('mousedown', onOutside);
  }, []);

  useEffect(() => { setDropOpen(false); }, [location.pathname]);

  async function handleLogout() {
    setDropOpen(false);
    await logout();
    navigate('/login', { replace: true });
  }

  const userInitials = initials(session?.displayName || 'HR');

  return (
    /* Green gradient header — mirrors Flutter AppBar with _brandGreen */
    <header
      className="h-[60px] shrink-0 z-30 flex items-center px-5 lg:px-8 gap-4"
      style={{
        background: 'linear-gradient(90deg, #065F46 0%, #047857 100%)',
        boxShadow: '0 2px 8px 0 rgba(6,95,70,0.25)',
      }}
    >
      {/* Mobile hamburger */}
      <button
        onClick={onMenuToggle}
        className="p-2 rounded-xl hover:bg-white/15 text-white/80 hover:text-white transition lg:hidden"
      >
        <Menu size={18} />
      </button>

      {/* Page title */}
      <div className="flex-1 min-w-0">
        <h1 className="text-[15px] font-black text-white truncate leading-none">{title}</h1>
        <p className="text-white/50 text-[10px] font-medium mt-0.5 hidden sm:block">HR Dashboard</p>
      </div>

      {/* Right actions */}
      <div className="flex items-center gap-1.5">

        {/* Company ID badge */}
        {session?.companyId && (
          <span className="hidden md:inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl
            text-[10px] font-bold bg-white/15 text-white border border-white/20">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-300 animate-pulse" />
            {session.companyId}
          </span>
        )}

        {/* Web access hint */}
        <a
          href="https://uddyogi-hr.web.app"
          target="_blank"
          rel="noreferrer"
          className="hidden lg:flex items-center gap-1.5 p-2 rounded-xl hover:bg-white/15 text-white/60 hover:text-white transition"
          title="uddyogi-hr.web.app"
        >
          <Monitor size={16} />
        </a>

        {/* Notifications */}
        <button className="relative p-2 rounded-xl hover:bg-white/15 text-white/70 hover:text-white transition">
          <Bell size={17} />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-red-400 rounded-full ring-2 ring-[#065F46]" />
        </button>

        {/* User avatar + dropdown */}
        <div className="relative" ref={dropRef}>
          <button
            onClick={() => setDropOpen(o => !o)}
            className="flex items-center gap-2 pl-1.5 pr-2 py-1.5 rounded-xl hover:bg-white/15 transition group"
          >
            {/* Avatar */}
            <div className="w-7 h-7 rounded-full bg-white/20 flex items-center justify-center text-white text-[11px] font-bold overflow-hidden ring-2 ring-white/30 shrink-0">
              {session?.photoUrl
                ? <img src={session.photoUrl} alt="" className="w-full h-full object-cover" />
                : <span>{userInitials}</span>}
            </div>
            <div className="hidden sm:block text-left">
              <p className="text-[12px] font-semibold text-white leading-tight max-w-[100px] truncate">
                {session?.displayName?.split(' ')[0] || 'HR'}
              </p>
              <p className="text-[9px] text-white/50 leading-tight capitalize">{session?.role || 'hr'}</p>
            </div>
            <ChevronDown size={12} className={`text-white/50 transition-transform ${dropOpen ? 'rotate-180' : ''}`} />
          </button>

          {/* Dropdown */}
          {dropOpen && (
            <div className="absolute right-0 top-full mt-2 w-56 bg-white rounded-2xl shadow-xl border border-gray-100 py-1.5 z-50 fade-in">
              {/* User info */}
              <div className="px-4 py-3 border-b border-gray-50">
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-[#065F46] flex items-center justify-center text-white text-xs font-bold overflow-hidden shrink-0">
                    {session?.photoUrl
                      ? <img src={session.photoUrl} alt="" className="w-full h-full object-cover" />
                      : <span>{userInitials}</span>}
                  </div>
                  <div className="min-w-0">
                    <p className="text-sm font-bold text-gray-900 truncate">{session?.displayName || 'HR User'}</p>
                    <p className="text-[11px] text-gray-400 truncate">{session?.email}</p>
                  </div>
                </div>
              </div>

              {/* Company info */}
              <div className="px-4 py-2.5 border-b border-gray-50">
                <p className="text-[10px] text-gray-400 font-semibold uppercase tracking-wide">Company ID</p>
                <p className="text-sm font-black text-[#065F46] font-mono mt-0.5">{session?.companyId || '—'}</p>
              </div>

              {/* Logout */}
              <div className="px-2 pt-1.5 pb-1">
                <button
                  onClick={handleLogout}
                  className="w-full flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-sm text-red-600 hover:bg-red-50 transition font-semibold"
                >
                  <LogOut size={15} />
                  Sign Out
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
