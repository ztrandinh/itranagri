"use client";
/** COMMAND PALETTE (Ctrl/Cmd + K) — gõ vài chữ là tới thẳng nơi cần, không phải lần mò menu.
 *  Tìm trong: mọi trang theo phòng ban (lib/modules) + hành động nhanh + đối tượng (API /api/search).
 *  Bàn phím: ↑↓ chọn · Enter mở · Esc đóng. Có role=dialog/listbox cho trợ năng. */
import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { MODULES } from "@/lib/modules";
import { noAccent } from "@/lib/client";

type Item = { id: string; title: string; hint?: string; href: string; kind: "trang" | "việc" | "đối tượng" };

const ACTIONS: Item[] = [
  { id: "a-ghi", title: "Ghi 3 chạm (nhập số liệu)", href: "/ca?tab=ghi", kind: "việc" },
  { id: "a-viec", title: "Việc hôm nay của tôi", href: "/ca", kind: "việc" },
  { id: "a-duyet", title: "Phê duyệt đang chờ tôi", href: "/phe-duyet", kind: "việc" },
  { id: "a-giay", title: "Nộp phiếu giấy (chụp ảnh)", href: "/giay", kind: "việc" },
  { id: "a-canhbao", title: "Cảnh báo chưa xử lý", href: "/canh-bao", kind: "việc" },
  { id: "a-ds", title: "Hệ thiết kế (token · primitive)", href: "/design-system", kind: "trang" },
];

export function CommandPalette() {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const [sel, setSel] = useState(0);
  const [remote, setRemote] = useState<Item[]>([]);
  const router = useRouter();
  const inputRef = useRef<HTMLInputElement>(null);

  // phím tắt mở/đóng
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") { e.preventDefault(); setOpen((v) => !v); }
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);
  useEffect(() => { if (open) { setQ(""); setSel(0); setRemote([]); setTimeout(() => inputRef.current?.focus(), 30); } }, [open]);

  // trang từ danh mục module
  const pages: Item[] = useMemo(() => Object.entries(MODULES).map(([href, m]) => ({
    id: `p${href}`, title: m.name, hint: `${m.dept} · ${m.users}`, href, kind: "trang" as const,
  })), []);

  // tìm đối tượng thật (bò, ô, SKU, người…) khi gõ ≥2 ký tự
  useEffect(() => {
    if (!open || q.trim().length < 2) { setRemote([]); return; }
    const t = setTimeout(async () => {
      try {
        const r = await fetch(`/api/search?q=${encodeURIComponent(q.trim())}`);
        const j = await r.json();
        setRemote((j.rows ?? []).slice(0, 8).map((x: Record<string, unknown>, i: number) => ({
          id: `o${i}`, title: String(x.label ?? x.name ?? x.id), hint: String(x.type ?? ""),
          href: `/xem/${String(x.type)}/${encodeURIComponent(String(x.id))}`, kind: "đối tượng" as const,
        })));
      } catch { setRemote([]); }
    }, 220);
    return () => clearTimeout(t);
  }, [q, open]);

  const list = useMemo(() => {
    const s = noAccent(q.trim());
    const local = [...ACTIONS, ...pages].filter((it) => !s || noAccent(`${it.title} ${it.hint ?? ""}`).includes(s));
    return [...local.slice(0, 12), ...remote];
  }, [q, pages, remote]);

  useEffect(() => { if (sel >= list.length) setSel(0); }, [list.length, sel]);
  if (!open) return null;

  const go = (it?: Item) => { const x = it ?? list[sel]; if (!x) return; setOpen(false); router.push(x.href); };

  return (
    <div className="fixed inset-0 flex items-start justify-center p-4 pt-[12vh]" style={{ zIndex: "var(--z-modal)" }} onClick={() => setOpen(false)}>
      <div className="ui-fade absolute inset-0" style={{ background: "rgba(8,14,11,.45)" }} aria-hidden="true" />
      <div role="dialog" aria-modal="true" aria-label="Tìm nhanh" onClick={(e) => e.stopPropagation()}
        className="ui-pop-in relative w-full max-w-xl overflow-hidden"
        style={{ background: "var(--surface)", border: "1px solid var(--line)", borderRadius: "var(--r-xl)", boxShadow: "var(--sh-3)" }}>
        <input
          ref={inputRef}
          className="w-full px-4 py-3.5 text-base outline-none"
          style={{ background: "transparent", color: "var(--ink)", borderBottom: "1px solid var(--line)" }}
          placeholder="Tìm trang, việc, con bò, ô ruộng, mặt hàng, người…" aria-label="Tìm trang, việc, con bò, ô ruộng, mặt hàng, người…"
          value={q}
          onChange={(e) => { setQ(e.target.value); setSel(0); }}
          onKeyDown={(e) => {
            if (e.key === "ArrowDown") { e.preventDefault(); setSel((i) => Math.min(i + 1, list.length - 1)); }
            if (e.key === "ArrowUp") { e.preventDefault(); setSel((i) => Math.max(i - 1, 0)); }
            if (e.key === "Enter") { e.preventDefault(); go(); }
          }}
          aria-controls="cmdk-list" aria-activedescendant={list[sel] ? `cmdk-${list[sel].id}` : undefined}
        />
        <ul id="cmdk-list" role="listbox" aria-label="Kết quả" className="max-h-[52vh] overflow-auto py-1">
          {list.map((it, i) => (
            <li key={it.id} id={`cmdk-${it.id}`} role="option" aria-selected={i === sel}>
              <button type="button" onMouseEnter={() => setSel(i)} onClick={() => go(it)}
                className="w-full text-left px-4 py-2.5 flex items-center gap-3"
                style={{ background: i === sel ? "var(--brand-soft)" : "transparent", color: "var(--ink)" }}>
                <span className="text-xs font-bold px-1.5 py-0.5 rounded" style={{ background: "var(--surface-2)", color: "var(--muted)" }}>{it.kind}</span>
                <span className="flex-1 truncate">{it.title}</span>
                {it.hint && <span className="text-xs truncate" style={{ color: "var(--muted)", maxWidth: 200 }}>{it.hint}</span>}
              </button>
            </li>
          ))}
          {!list.length && <li className="px-4 py-6 text-center text-sm" style={{ color: "var(--muted)" }}>Không thấy gì khớp “{q}”.</li>}
        </ul>
        <div className="px-4 py-2 text-xs flex gap-3" style={{ borderTop: "1px solid var(--line)", color: "var(--muted)" }}>
          <span>↑↓ chọn</span><span>Enter mở</span><span>Esc đóng</span><span className="ml-auto">Ctrl/⌘ + K</span>
        </div>
      </div>
    </div>
  );
}
