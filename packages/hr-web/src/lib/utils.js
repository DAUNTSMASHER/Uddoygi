import { format, formatDistanceToNow, isValid, parseISO } from 'date-fns';

export function formatDate(val, fmt = 'dd MMM yyyy') {
  if (!val) return '—';
  let d;
  if (val?.toDate) d = val.toDate();
  else if (val?.seconds) d = new Date(val.seconds * 1000);
  else d = new Date(val);
  return isValid(d) ? format(d, fmt) : '—';
}

export function formatDateTime(val) {
  return formatDate(val, 'dd MMM yyyy, hh:mm a');
}

export function timeAgo(val) {
  if (!val) return '—';
  let d;
  if (val?.toDate) d = val.toDate();
  else if (val?.seconds) d = new Date(val.seconds * 1000);
  else d = new Date(val);
  return isValid(d) ? formatDistanceToNow(d, { addSuffix: true }) : '—';
}

export function formatCurrency(amount, currency = 'BDT') {
  if (amount == null || isNaN(amount)) return '—';
  return new Intl.NumberFormat('en-BD', {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

export function formatNumber(n) {
  if (n == null || isNaN(n)) return '—';
  return new Intl.NumberFormat('en-BD').format(n);
}

export function initials(name) {
  if (!name) return '?';
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0].toUpperCase())
    .join('');
}

export function statusColor(status) {
  const s = (status || '').toLowerCase();
  if (['active', 'approved', 'paid', 'confirmed', 'present', 'verified', 'received', 'closed', 'repaid'].includes(s))
    return 'green';
  if (['pending', 'pending_hr', 'processing', 'review', 'disbursed', 'open'].includes(s)) return 'yellow';
  if (['inactive', 'rejected', 'unpaid', 'absent', 'terminated', 'cancelled'].includes(s))
    return 'red';
  if (['generated', 'submitted'].includes(s)) return 'blue';
  return 'gray';
}

// Returns the CSS class string for a <span> badge element
export function statusBadge(status) {
  const color = statusColor(status);
  const map = {
    green:  'badge badge-green',
    yellow: 'badge badge-yellow',
    red:    'badge badge-red',
    blue:   'badge badge-blue',
    gray:   'badge badge-gray',
  };
  return map[color] || map.gray;
}

export function clsx(...args) {
  return args.filter(Boolean).join(' ');
}
