export function Button({
  children,
  variant = 'primary',
  size = 'md',
  loading = false,
  disabled = false,
  onClick,
  type = 'button',
  className = '',
  icon: Icon,
}) {
  const base = 'inline-flex items-center justify-center gap-2 font-semibold rounded-lg transition-all focus:outline-none focus:ring-2 focus:ring-offset-1';

  const variants = {
    primary:  'bg-[#065F46] hover:bg-[#162F57] text-white focus:ring-[#065F46]',
    secondary:'bg-white hover:bg-gray-50 text-gray-700 border border-gray-200 focus:ring-gray-300',
    danger:   'bg-red-600 hover:bg-red-700 text-white focus:ring-red-400',
    ghost:    'bg-transparent hover:bg-gray-100 text-gray-600 focus:ring-gray-300',
    outline:  'bg-transparent border border-[#065F46] text-[#065F46] hover:bg-[#065F46]/5 focus:ring-brand-400',
  };

  const sizes = {
    sm: 'px-3 py-1.5 text-xs',
    md: 'px-4 py-2 text-sm',
    lg: 'px-5 py-2.5 text-base',
  };

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled || loading}
      className={`${base} ${variants[variant] || variants.primary} ${sizes[size] || sizes.md} ${(disabled || loading) ? 'opacity-60 cursor-not-allowed' : ''} ${className}`}
    >
      {loading ? (
        <svg className="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
        </svg>
      ) : Icon ? (
        <Icon size={size === 'sm' ? 14 : size === 'lg' ? 18 : 16} />
      ) : null}
      {children}
    </button>
  );
}
