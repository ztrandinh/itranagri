"use client";
/** Sheet — tấm trượt từ đáy (mobile) / hộp thoại giữa màn (desktop).
 *  Trợ năng như Modal: role=dialog, aria-modal, Esc đóng, bẫy focus, trả focus.
 *  Dùng cho form nhập nhanh trên điện thoại (ngón cái với tới, không che toàn màn). */
import { useEffect, useRef } from "react";

export function Sheet({ open, onClose, title, children, widthClassName }: {
  open: boolean; onClose: () => void; title?: string; children: React.ReactNode; widthClassName?: string;
}) {
  const panelRef = useRef<HTMLDivElement>(null);
  const prevFocus = useRef<HTMLElement | null>(null);
  useEffect(() => {
    if (!open) return;
    prevFocus.current = document.activeElement as HTMLElement | null;
    const el = panelRef.current;
    (el?.querySelector<HTMLElement>('button,[href],input,select,textarea,[tabindex]:not([tabindex="-1"])') ?? el)?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") { e.stopPropagation(); onClose(); }
      if (e.key === "Tab" && el) {
        const f = Array.from(el.querySelectorAll<HTMLElement>('button,[href],input,select,textarea,[tabindex]:not([tabindex="-1"])')).filter((n) => !n.hasAttribute("disabled"));
        if (!f.length) return;
        const first = f[0], last = f[f.length - 1];
        if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
        else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
      }
    };
    document.addEventListener("keydown", onKey, true);
    const prevOverflow = document.body.style.overflow; document.body.style.overflow = "hidden";
    return () => { document.removeEventListener("keydown", onKey, true); document.body.style.overflow = prevOverflow; prevFocus.current?.focus?.(); };
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div className="fixed inset-0 flex items-end sm:items-center justify-center" style={{ zIndex: "var(--z-sheet)" }} onClick={onClose}>
      <div className="absolute inset-0 ui-fade" style={{ background: "rgba(8,14,11,.45)" }} aria-hidden="true" />
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        onClick={(e) => e.stopPropagation()}
        className={`relative w-full ${widthClassName ?? "sm:max-w-md"} outline-none ui-sheet-in`}
        style={{
          background: "var(--surface)", color: "var(--ink)", border: "1px solid var(--line)",
          borderRadius: "var(--r-xl) var(--r-xl) 0 0", boxShadow: "var(--sh-3)",
          padding: "var(--s4)", paddingBottom: "calc(var(--s4) + env(safe-area-inset-bottom))",
          maxHeight: "88vh", overflowY: "auto",
        }}
      >
        <div aria-hidden="true" className="mx-auto mb-3 sm:hidden" style={{ width: 40, height: 4, borderRadius: 999, background: "var(--line)" }} />
        {title && <h2 className="text-lg font-bold mb-3">{title}</h2>}
        {children}
      </div>
    </div>
  );
}
