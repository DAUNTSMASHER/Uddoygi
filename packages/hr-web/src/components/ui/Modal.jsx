import { useEffect } from 'react';
import { X } from 'lucide-react';

/**
 * Shared modal component.
 * Props:
 *   title   — header text
 *   onClose — called when X or backdrop is clicked
 *   wide    — use max-w-2xl instead of max-w-md
 *   xl      — use max-w-4xl
 *   children
 */
export function Modal({ title, onClose, children, wide, xl }) {
  // Lock body scroll while open
  useEffect(() => {
    document.body.style.overflow = 'hidden';
    return () => { document.body.style.overflow = ''; };
  }, []);

  const maxW = xl ? 'max-w-4xl' : wide ? 'max-w-2xl' : 'max-w-md';

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: 'rgba(0,0,0,0.45)', backdropFilter: 'blur(4px)' }}
      onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div
        className={`bg-white rounded-2xl shadow-2xl w-full ${maxW} max-h-[92vh] flex flex-col fade-in`}
        style={{ border: '1px solid rgba(6,95,70,0.10)' }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b shrink-0"
          style={{ borderColor: 'rgba(6,95,70,0.08)' }}>
          <h3 className="font-black text-gray-900 text-base">{title}</h3>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition"
          >
            <X size={16} />
          </button>
        </div>

        {/* Body */}
        <div className="p-6 overflow-y-auto flex-1">
          {children}
        </div>
      </div>
    </div>
  );
}
