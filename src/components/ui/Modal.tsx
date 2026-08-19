"use client";
/** Modal có trợ năng: role=dialog + aria-modal, đóng bằng Esc, click nền, bẫy focus tối giản
 *  (focus phần tử đầu khi mở, trả focus về nơi cũ khi đóng). Thay các modal tự chế (fixed inset-0)
 *  rải rác không có Esc/focus-trap. */
import { useEffect, useRef } from "react";

export function Modal({ open, onClose, title, children, labelledBy }: {
  open: boolean;
  onClose: () => void;
  title?: string;
  labelledBy?: string;
  children: React.ReactNode;
}) {
  const panelRef = useRef<HTMLDivElement>(null);
  const prevFocus = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!open) return;
    prevFocus.current = document.activeElement as HTMLElement | null;
    const el = panelRef.current;
    // focus phần tử focus-được đầu tiên, hoặc chính panel
    const first = el?.querySelector<HTMLElement>('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
    (first ?? el)?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") { e.stopPropagation(); onClose(); }
      if (e.key === "Tab" && el) {
        const f = Array.from(el.querySelectorAll<HTMLElement>('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')).filter((n) => !n.hasAttribute("disabled"));
        if (!f.length) return;
        const first0 = f[0], last = f[f.length - 1];
        if (e.shiftKey && document.activeElement === first0) { e.preventDefault(); last.focus(); }
        else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first0.focus(); }
      }
    };
    document.addEventListener("keydown", onKey, true);
    return () => {
      document.removeEventListener("keydown", onKey, true);
      prevFocus.current?.focus?.();
    };
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="ui-fade absolute inset-0" style={{ background: "rgba(8,14,11,.45)" }} aria-hidden="true" />
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-label={labelledBy ? undefined : title}
        aria-labelledby={labelledBy}
        tabIndex={-1}
        className="ui-pop-in relative rounded-2xl shadow-xl w-full max-w-md p-5 outline-none" style={{ background: "var(--surface)", color: "var(--ink)", border: "1px solid var(--line)", boxShadow: "var(--sh-3)" }}
        onClick={(e) => e.stopPropagation()}
      >
        {title && <h2 className="text-lg font-bold text-slate-800 mb-3">{title}</h2>}
        {children}
      </div>
    </div>
  );
}
