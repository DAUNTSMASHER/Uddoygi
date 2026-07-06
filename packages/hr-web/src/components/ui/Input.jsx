export function Input({
  label,
  error,
  icon: Icon,
  className = '',
  inputClassName = '',
  ...props
}) {
  return (
    <div className={`flex flex-col gap-1 ${className}`}>
      {label && (
        <label className="text-xs font-semibold text-gray-600 uppercase tracking-wide">
          {label}
        </label>
      )}
      <div className="relative">
        {Icon && (
          <div className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">
            <Icon size={16} />
          </div>
        )}
        <input
          className={`w-full rounded-lg border ${error ? 'border-red-400' : 'border-gray-200'} bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-[#065F46] focus:border-transparent transition ${Icon ? 'pl-9' : ''} ${inputClassName}`}
          {...props}
        />
      </div>
      {error && <p className="text-xs text-red-500">{error}</p>}
    </div>
  );
}

export function Select({ label, error, className = '', children, ...props }) {
  return (
    <div className={`flex flex-col gap-1 ${className}`}>
      {label && (
        <label className="text-xs font-semibold text-gray-600 uppercase tracking-wide">
          {label}
        </label>
      )}
      <select
        className={`w-full rounded-lg border ${error ? 'border-red-400' : 'border-gray-200'} bg-white px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-[#065F46] focus:border-transparent transition`}
        {...props}
      >
        {children}
      </select>
      {error && <p className="text-xs text-red-500">{error}</p>}
    </div>
  );
}
