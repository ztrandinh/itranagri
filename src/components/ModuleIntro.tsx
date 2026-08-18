"use client";
import { useEffect, useState } from "react";
import { MODULES } from "@/lib/modules";
/** Giới thiệu chuẩn đầu mỗi trang: để làm gì · dành cho ai · quy trình · SOP · bắt đầu từ đâu — thu gọn được, nhớ theo người dùng (localStorage) */
export default function ModuleIntro({ path }: { path: string }) {
  const m = MODULES[path]; const [open, setOpen] = useState(true);
  useEffect(() => { try { setOpen(localStorage.getItem("intro:" + path) !== "0"); } catch { /* ignore */ } }, [path]);
  if (!m) return null;
  const toggle = () => { const v = !open; setOpen(v); try { localStorage.setItem("intro:" + path, v ? "1" : "0"); } catch { /* ignore */ } };
  return <div className="rounded-xl border border-emerald-200 bg-emerald-50/50 px-3 py-2 mb-3 text-sm">
    <div className="flex items-center gap-2 flex-wrap"><span className="font-bold text-emerald-900">ℹ {m.name}</span><span className="text-xs rounded-full bg-white border px-2 py-0.5">Phòng: {m.dept}</span><span className="text-xs text-slate-600">Dùng cho: {m.users}</span><button className="ml-auto text-xs underline text-slate-600" onClick={toggle}>{open ? "thu gọn" : "trang này để làm gì?"}</button></div>
    {open && <div className="mt-2 grid md:grid-cols-3 gap-3"><div><div className="text-xs font-bold text-slate-500 uppercase">Để làm gì</div><div>{m.purpose}</div>{m.kpis && <div className="text-xs text-slate-600 mt-1">KPI: {m.kpis.join(" · ")}</div>}</div><div><div className="text-xs font-bold text-slate-500 uppercase">Quy trình</div><ol className="list-decimal ml-4">{m.steps.map((s, i) => <li key={i}>{s}</li>)}</ol></div><div><div className="text-xs font-bold text-slate-500 uppercase">Bắt đầu từ đâu</div><div>{m.start}</div>{m.sops && <div className="text-xs mt-1">SOP/quy trình: {m.sops.map((c) => <a key={c} className="underline mr-1" href={`/to-chuc?tab=sop&q=${c}`}>{c}</a>)}</div>}</div></div>}
  </div>;
}
