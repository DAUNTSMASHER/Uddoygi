export function Card({ children, className = '', padding = true }) {
  return (
    <div className={`bg-white rounded-xl border border-gray-100 shadow-sm ${padding ? 'p-5' : ''} ${className}`}>
      {children}
    </div>
  );
}

export function CardHeader({ title, subtitle, action, icon: Icon }) {
  return (
    <div className="flex items-start justify-between mb-4">
      <div className="flex items-center gap-3">
        {Icon && (
          <div className="w-9 h-9 rounded-lg bg-[#065F46]/5 flex items-center justify-center">
            <Icon size={18} className="text-[#065F46]" />
          </div>
        )}
        <div>
          <h3 className="text-sm font-semibold text-gray-900">{title}</h3>
          {subtitle && <p className="text-xs text-gray-500 mt-0.5">{subtitle}</p>}
        </div>
      </div>
      {action && <div>{action}</div>}
    </div>
  );
}
