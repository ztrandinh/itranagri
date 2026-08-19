"use client";
import { useState } from "react";
import dynamic from "next/dynamic";
import { CFG } from "@/components/panels/Obj360";
import { SkeletonText } from "@/components/ui/Skeleton";
/** LAZY: ChartIcon nằm ở MỌI DÒNG bảng — nếu nạp AnyChart (kéo theo recharts ~400KB)
 *  tĩnh thì mọi trang đều phải tải thư viện biểu đồ dù người dùng không mở lần nào.
 *  Chỉ tải khi thật sự bấm 📈. */
const AnyChart = dynamic(() => import("@/components/AnyChartInner"), {
  ssr: false,
  loading: () => <div className="p-3"><SkeletonText lines={4} /></div>,
});
/** 📈 ở cuối MỖI DÒNG đối tượng: bấm → biểu đồ biến động của chính đối tượng đó (so kỳ trước) — dùng cấu hình 360 (CFG) nên mọi loại đối tượng đều có */
export default function ChartIcon({ type, id, label }: { type: string; id: string; label?: string }) {
  const [open, setOpen] = useState(false); const cfg = CFG[type]; if (!cfg || !cfg.charts.length) return null;
  return (<>
    <button className="rounded-full px-1.5 text-base hover:bg-emerald-100" title={`Biểu đồ ${label ?? id} (so kỳ trước)`} onClick={(e) => { e.stopPropagation(); setOpen(true); }}>📈</button>
    {open && <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/40" onClick={() => setOpen(false)}><div className="bg-white rounded-t-2xl sm:rounded-2xl w-full sm:w-[900px] max-h-[90vh] overflow-auto p-4 space-y-3" onClick={(e) => e.stopPropagation()}>
      <div className="flex items-center"><b>{cfg.label} · {label ?? id}</b><a className="ml-3 underline text-sm" href={`/xem/${type}/${encodeURIComponent(id)}`}>trang 360</a><button className="ml-auto text-xl" onClick={() => setOpen(false)}>✕</button></div>
      <div className="grid md:grid-cols-2 gap-3">{cfg.charts.map((ch) => <div key={ch.title} className="border rounded-xl p-2"><AnyChart title={ch.title} table={ch.table} col={ch.col} agg={ch.agg ?? "sum"} dim={ch.dim ?? null} filters={{ [ch.filter]: id, ...(ch.extra ?? {}) }} bucket="week" from={new Date(Date.now() - 90 * 86400e3).toISOString().slice(0, 10)} height={190} compare /></div>)}</div>
      <div className="text-xs text-slate-500">Đường xám nét đứt = kỳ trước; % thay đổi ở góc phải mỗi biểu đồ; bấm cột để xem bản ghi gốc.</div>
    </div></div>}
  </>);
}
