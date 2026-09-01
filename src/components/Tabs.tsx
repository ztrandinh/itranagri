"use client";
/** Thanh tab dùng chung.
 *  - Mobile: select sổ xuống (tự gom nhóm theo nhãn "Nhóm · Tên").
 *  - Desktop: hiện các tab chính; khi quá nhiều (>7) phần ít dùng gom vào "Thêm ▾"
 *    (progressive disclosure — giảm mật độ, tab đang chọn LUÔN hiện ngoài).
 */
import { useEffect, useRef, useState } from "react";

const MAX_VISIBLE = 7;

export default function Tabs({ items, value, onChange, right }: { items: (readonly [string, string])[] | [string, string][]; value: string; onChange: (k: string) => void; right?: React.ReactNode }) {
  const list = items as [string, string][];
  const groups = new Map<string, [string, string][]>();
  for (const [k, l] of list) { const i = l.indexOf(" · "); const g = i > 0 && list.length > 6 ? l.slice(0, i) : ""; if (!groups.has(g)) groups.set(g, []); groups.get(g)!.push([k, l]); }
  const idx = list.findIndex(([k]) => k === value);
  const go = (d: number) => { const n = list[(idx + d + list.length) % list.length]; if (n) onChange(n[0]); };

  // tách tab hiện ngoài / tab gom vào "Thêm" — luôn giữ tab đang chọn ở ngoài
  const overflow = list.length > MAX_VISIBLE;
  let head = overflow ? list.slice(0, MAX_VISIBLE) : list;
  let rest = overflow ? list.slice(MAX_VISIBLE) : [];
  if (overflow && idx >= MAX_VISIBLE) { const cur = list[idx]; head = [...head.slice(0, MAX_VISIBLE - 1), cur]; rest = list.slice(MAX_VISIBLE - 1).filter(([k]) => k !== cur[0]); }

  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const off = (e: MouseEvent) => { if (box.current && !box.current.contains(e.target as Node)) setOpen(false); };
    const esc = (e: KeyboardEvent) => { if (e.key === "Escape") setOpen(false); };
    document.addEventListener("mousedown", off); document.addEventListener("keydown", esc);
    return () => { document.removeEventListener("mousedown", off); document.removeEventListener("keydown", esc); };
  }, [open]);

  const btn = (k: string, l: string) => (
    <button key={k} type="button" aria-current={value === k ? "page" : undefined}
      className={value === k ? "tab-btn-active" : "tab-btn"}
      style={{ transition: "background-color var(--dur-fast) var(--ease), color var(--dur-fast) var(--ease)" }}
      onClick={() => onChange(k)}>{l}</button>
  );

  return (
    <div className="flex items-start gap-2">
      <button type="button" className="tab-btn shrink-0 !px-2" title="Tab trước" onClick={() => go(-1)}>‹</button>
      <select className="input sm:hidden flex-1 font-semibold" value={value} onChange={(e) => onChange(e.target.value)} aria-label="Chọn mục">
        {[...groups.entries()].map(([g, arr]) => g ? <optgroup key={g} label={g}>{arr.map(([k, l]) => <option key={k} value={k}>{l}</option>)}</optgroup> : arr.map(([k, l]) => <option key={k} value={k}>{l}</option>))}
      </select>
      <div className="hidden sm:flex flex-wrap gap-1.5 flex-1 items-start">
        {head.map(([k, l]) => btn(k, l))}
        {rest.length > 0 && (
          <div className="relative" ref={box}>
            <button type="button" aria-expanded={open} aria-haspopup="menu"
              className="tab-btn"
              onClick={() => setOpen(!open)}>Thêm ▾ <span style={{ color: "var(--muted)" }}>({rest.length})</span></button>
            {open && (
              <div role="menu" className="ui-pop-in absolute right-0 mt-1 p-1 max-h-72 overflow-auto"
                style={{ zIndex: "var(--z-sheet)", minWidth: 240, background: "var(--surface)", border: "1px solid var(--line)", borderRadius: "var(--r-md)", boxShadow: "var(--sh-2)" }}>
                {rest.map(([k, l]) => (
                  <button key={k} role="menuitem" type="button" onClick={() => { onChange(k); setOpen(false); }}
                    className="block w-full text-left px-3 py-2 min-h-[40px] rounded-lg text-sm" style={{ color: "var(--ink)" }}
                    onMouseEnter={(e) => (e.currentTarget.style.background = "var(--brand-soft)")} onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}>{l}</button>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
      <button type="button" className="tab-btn shrink-0 !px-2" title="Tab tiếp" onClick={() => go(1)}>›</button>
      {right && <div className="shrink-0">{right}</div>}
    </div>
  );
}
