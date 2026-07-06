export function Badge({ children, variant = 'gray', className = '' }) {
  const variants = {
    green:  'bg-green-100 text-green-800 border border-green-200',
    yellow: 'bg-yellow-100 text-yellow-800 border border-yellow-200',
    red:    'bg-red-100 text-red-800 border border-red-200',
    blue:   'bg-blue-100 text-blue-800 border border-blue-200',
    purple: 'bg-purple-100 text-purple-800 border border-purple-200',
    gray:   'bg-gray-100 text-gray-700 border border-gray-200',
    brand:  'bg-brand-100 text-[#162F57] border border-[#065F46]/20',
  };
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold ${variants[variant] || variants.gray} ${className}`}>
      {children}
    </span>
  );
}
