"use client";
import { useEffect, useRef, useState } from "react";
type Hit = { type: string; id: string; title: string; sub: string };
const ICON: Record<string, string> = { animal: "🐄", group: "🐔", plot: "🟩", crop: "🌱", species: "🧬", product: "📦", staff: "👤", partner: "🤝", device: "⚙️", facility: "🏠", location: "📍", warehouse: "🏬", season: "📅", lot: "🏷️", process: "🔁", department: "🏢", booking: "🛏️" };
/** Ô tìm mọi đối tượng: gõ tên → chọn → trang 360 (/xem/{type}/{id}) có đủ số liệu */
export function Search({ big }: { big?: boolean }) {
  const [q, setQ] = useState(""); const [hits, setHits] = useState<Hit[]>([]); const [open, setOpen] = useState(false); const t = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => { if (t.current) clearTimeout(t.current); if (q.trim().length < 1) { setHits([]); return; } t.current = setTimeout(() => { fetch(`/api/search?q=${encodeURIComponent(q)}`).then((r) => r.json()).then((j) => { setHits(j.rows ?? []); setOpen(true); }); }, 250); }, [q]);
  return (<div className={`relative ${big ? "" : "hidden md:block"}`}>
    <input className={big ? "input !text-lg" : "rounded-lg border border-slate-300 bg-slate-50 px-3 py-1.5 text-sm w-48 lg:w-72 focus:outline-none focus:ring-2 focus:ring-emerald-500"} placeholder="🔍 Tìm bò, ô, SKU, người…" value={q} onChange={(e) => setQ(e.target.value)} onFocus={() => hits.length && setOpen(true)} onBlur={() => setTimeout(() => setOpen(false), 200)} onKeyDown={(e) => { if (e.key === "Enter" && hits[0]) location.href = `/xem/${hits[0].type}/${encodeURIComponent(hits[0].id)}`; }} />
    {open && hits.length > 0 && <div className="absolute z-50 mt-1 w-[92vw] sm:w-[520px] max-h-[60vh] overflow-auto bg-white text-stone-900 rounded-2xl shadow-xl border">{hits.map((h) => <a key={h.type + h.id} href={`/xem/${h.type}/${encodeURIComponent(h.id)}`} className="flex items-center gap-2 px-3 py-2 border-b hover:bg-green-50 text-sm"><span>{ICON[h.type] ?? "•"}</span><span className="font-semibold">{h.title}</span><span className="text-xs text-stone-500 truncate">{h.sub}</span><span className="ml-auto text-[10px] uppercase text-stone-400">{h.type}</span></a>)}</div>}
  </div>);
}
