// Shared employee picker component
// Shows: department dropdown → searchable employee list → selected chip
// Handles both 'fullName' (Flutter admin) and 'name' (web-added) fields.
// Props:
//   employees   — array of employee docs from users collection
//   value       — { employeeId, employeeName, department, designation, salary, ... }
//   onChange    — called with the selected employee object (or null to clear)
//   label       — optional label override (default: "Employee")
//   required    — shows asterisk

import { useState, useMemo } from 'react';
import { Search, X, ChevronDown } from 'lucide-react';
import { formatCurrency } from '../../lib/utils';

// Resolve the best display name from a user doc
// _displayName is pre-computed by the pages that load employees
function empName(emp) {
  return emp?._displayName || emp?.fullName || emp?.name || emp?.email || '—';
}

export function EmployeePicker({ employees = [], value, onChange, label = 'Employee', required = false }) {
  const [selectedDept, setSelectedDept] = useState(value?.department || '');
  const [search, setSearch]             = useState('');
  const [open, setOpen]                 = useState(false);

  // Unique sorted departments
  const departments = useMemo(() => {
    return [...new Set(
      employees.map(e => (e.department || '').trim()).filter(Boolean)
    )].sort();
  }, [employees]);

  // Employees filtered by dept then search
  const filtered = useMemo(() => {
    let list = selectedDept
      ? employees.filter(e => (e.department || '').trim() === selectedDept)
      : employees;
    const q = search.toLowerCase();
    if (q) list = list.filter(e =>
      empName(e).toLowerCase().includes(q) ||
      (e.designation || e.jobTitle || e.role || '').toLowerCase().includes(q) ||
      (e.employeeId || '').toLowerCase().includes(q) ||
      (e.email || e.officeEmail || '').toLowerCase().includes(q)
    );
    return list;
  }, [employees, selectedDept, search]);

  function handleDeptChange(dept) {
    setSelectedDept(dept);
    // Clear current selection if it's not in the new dept
    if (value && dept && (value.department || '').trim() !== dept) {
      onChange(null);
    }
    setSearch('');
    setOpen(true);
  }

  function handleSelect(emp) {
    onChange(emp);
    setOpen(false);
    setSearch('');
  }

  function handleClear() {
    onChange(null);
    setSearch('');
    setOpen(true);
  }

  const deptCount = selectedDept
    ? employees.filter(e => (e.department || '').trim() === selectedDept).length
    : employees.length;

  return (
    <div className="space-y-2">
      {/* Department dropdown */}
      <div>
        <label className="label">Department</label>
        <div className="relative">
          <select
            className="input pr-8 appearance-none"
            value={selectedDept}
            onChange={e => handleDeptChange(e.target.value)}
          >
            <option value="">— All Departments ({employees.length}) —</option>
            {departments.map(d => {
              const cnt = employees.filter(e => (e.department || '').trim() === d).length;
              return <option key={d} value={d}>{d} ({cnt})</option>;
            })}
          </select>
          <ChevronDown size={14} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
        </div>
        {departments.length === 0 && (
          <p className="text-xs text-amber-600 mt-1">No departments found. Add employees first.</p>
        )}
      </div>

      {/* Employee picker */}
      <div>
        <label className="label">
          {label}{required && ' *'}
          {selectedDept && (
            <span className="ml-1.5 text-[10px] font-semibold text-[#065F46] bg-[#065F46]/10 px-1.5 py-0.5 rounded">
              {deptCount} {selectedDept}
            </span>
          )}
        </label>

        {value ? (
          /* Selected chip */
          <div className="flex items-center gap-2.5 p-2.5 rounded-lg border border-[#065F46]/30 bg-[#F0FDF4]">
            <EmployeeAvatar emp={value} size={8} />
            <div className="flex-1 min-w-0">
              <p className="text-sm font-bold text-gray-900 truncate">{empName(value)}</p>
              <p className="text-xs text-gray-400 truncate">
                {value.designation || value.jobTitle || value.role || '—'}
                {value.department && ` · ${value.department}`}
                {value.employeeId && ` · ${value.employeeId}`}
              </p>
            </div>
            {(value.salary || value.basicSalary) > 0 && (
              <span className="text-xs font-bold text-[#065F46] shrink-0">
                {formatCurrency(value.salary || value.basicSalary)}
              </span>
            )}
            <button
              type="button"
              onClick={handleClear}
              className="text-gray-400 hover:text-red-500 transition shrink-0"
              title="Change employee"
            >
              <X size={14} />
            </button>
          </div>
        ) : (
          /* Search + dropdown */
          <div className="relative">
            <div className="relative">
              <Search size={13} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                className="input pl-8"
                placeholder={`Search ${selectedDept || 'all'} employees…`}
                value={search}
                onChange={e => { setSearch(e.target.value); setOpen(true); }}
                onFocus={() => setOpen(true)}
              />
              {search && (
                <button
                  type="button"
                  onClick={() => setSearch('')}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  <X size={12} />
                </button>
              )}
            </div>

            {open && (
              <>
                {/* Backdrop */}
                <div className="fixed inset-0 z-20" onClick={() => setOpen(false)} />
                <div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-xl border border-gray-200 shadow-xl z-30 max-h-56 overflow-y-auto">
                  {filtered.length === 0 ? (
                    <div className="px-4 py-6 text-center text-sm text-gray-400">
                      {employees.length === 0
                        ? 'No employees found. Add employees first.'
                        : 'No employees match your search.'}
                    </div>
                  ) : filtered.map(emp => (
                    <button
                      key={emp.id}
                      type="button"
                      onClick={() => handleSelect(emp)}
                      className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-[#F0FDF4] transition text-left border-b border-gray-50 last:border-0"
                    >
                      <EmployeeAvatar emp={emp} size={8} />
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-semibold text-gray-900 truncate">{empName(emp)}</p>
                        <p className="text-xs text-gray-400 truncate">
                          {emp.designation || emp.jobTitle || emp.role || '—'}
                          {emp.department && ` · ${emp.department}`}
                          {emp.employeeId && ` · ${emp.employeeId}`}
                        </p>
                      </div>
                      {(emp.salary || emp.basicSalary) > 0 && (
                        <span className="text-xs font-bold text-[#065F46] shrink-0">
                          {formatCurrency(emp.salary || emp.basicSalary)}
                        </span>
                      )}
                    </button>
                  ))}
                </div>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

// ── Avatar helper ─────────────────────────────────────────────────────────────
export function EmployeeAvatar({ emp, size = 8 }) {
  const displayName = emp?.fullName || emp?.name || emp?.employeeName || '?';
  const initStr = displayName
    .split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();

  return (
    <div className={`w-${size} h-${size} rounded-full shrink-0 overflow-hidden bg-[#065F46]/10 flex items-center justify-center`}>
      {emp?.profileImage || emp?.photoUrl || emp?.profilePhotoUrl ? (
        <img src={emp.profileImage || emp.photoUrl || emp.profilePhotoUrl} alt="" className="w-full h-full object-cover" />
      ) : (
        <span className="text-[10px] font-black text-[#065F46]">{initStr}</span>
      )}
    </div>
  );
}
