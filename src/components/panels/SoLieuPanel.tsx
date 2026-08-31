"use client";
import { useEffect, useMemo, useState } from "react";
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, Tooltip, Legend, CartesianGrid, ResponsiveContainer, ReferenceLine } from "recharts";
import type { Sess } from "@/components/Shell";
import { fmt } from "@/lib/client";
import { AnyExplorer } from "@/components/AnyChart";
type M = { code: string; name: string; unit: string; group: string; dims?: string[]; norm?: string };
type Row = { t: string; dim: string | null; v: number };
const COLORS = ["#166534", "#0369a1", "#b45309", "#7e22ce", "#be123c", "#0f766e", "#4d7c0f", "#a16207", "#1d4ed8", "#9f1239"];
const label = (t: string, bucket: string) => { const d = new Date(t); return bucket === "day" || bucket === "week" ? d.toLocaleDateString("vi-VN", { day: "2-digit", month: "2-digit" }) : bucket === "month" ? `T${d.getMonth() + 1}/${d.getFullYear()}` : bucket === "quarter" ? `Q${Math.floor(d.getMonth() / 3) + 1}/${d.getFullYear()}` : String(d.getFullYear()); };

export default function SoLieuPanel({ sess, initialMetric, initialTab }: { sess: Sess; initialMetric?: string; initialTab?: string }) {
  const [top, setTop] = useState<"kpi" | "any">(initialTab === "any" ? "any" : "kpi");
  return (<div className="space-y-3">
    <div className="flex gap-2">{[["kpi", "Chỉ số nghiệp vụ (catalog)"], ["any", "📈 Mọi trường dữ liệu (tự động)"]].map(([k, l]) => <button key={k} className={`px-4 py-2 rounded-xl font-semibold ${top === k ? "bg-green-700 text-white" : "bg-white border"}`} onClick={() => setTop(k as typeof top)}>{l}</button>)}</div>
    {top === "any" ? <AnyExplorer /> : <MetricExplorer sess={sess} initialMetric={initialMetric} />}
  </div>);
}
function MetricExplorer({ sess, initialMetric }: { sess: Sess; initialMetric?: string }) {
  const [metrics, setMetrics] = useState<M[]>([]); const [metric, setMetric] = useState(initialMetric ?? "feed_kg"); const [bucket, setBucket] = useState("day"); const [dim, setDim] = useState(""); const [chart, setChart] = useState<"bar" | "line" | "cum">("bar"); const [compare, setCompare] = useState(false);
  const [from, setFrom] = useState(new Date(Date.now() - 30 * 86400e3).toISOString().slice(0, 10)); const [to, setTo] = useState(new Date().toISOString().slice(0, 10));
  const [rows, setRows] = useState<Row[]>([]); const [prev, setPrev] = useState<Row[]>([]); const [err, setErr] = useState<string | null>(null); const [loading, setLoading] = useState(true); const [drill, setDrill] = useState<{ t: string; dimval: string | null; rows: Record<string, unknown>[] } | null>(null); const [norm, setNorm] = useState<number | null>(null);
  useEffect(() => { fetch("/api/series?list=1").then((r) => r.json()).then((j) => setMetrics(j.metrics ?? [])); }, []);
  useEffect(() => { setDrill(null); setLoading(true); fetch(`/api/series?metric=${metric}&bucket=${bucket}&from=${from}&to=${to}${dim ? `&dim=${dim}` : ""}${compare ? "&compare=1" : ""}`).then((r) => r.json()).then((j) => { if (j.rows) { setRows(j.rows.map((r: Row) => ({ ...r, v: Number(r.v) }))); setPrev((j.prev ?? []).map((r: Row) => ({ ...r, v: Number(r.v) }))); setErr(null); } else setErr(j.error); }).catch(() => setErr("offline")).finally(() => setLoading(false)); }, [metric, bucket, from, to, dim, compare]);
  const m = metrics.find((x) => x.code === metric);
  useEffect(() => { if (!m?.norm) { setNorm(null); return; } fetch("/api/data/norms").then((r) => r.json()).then((j) => { const n = (j.rows ?? []).find((x: { kind: string }) => x.kind === m.norm); const herd = n ? fetch("/api/data/herd_value").then((r) => r.json()) : null; if (n && herd) herd.then((h) => { const head = Number(h.rows?.[0]?.head_count ?? 0); const perDay = Number(n.value) * head; setNorm(bucket === "day" ? perDay : bucket === "week" ? perDay * 7 : bucket === "month" ? perDay * 30 : bucket === "quarter" ? perDay * 91 : perDay * 365); }); }); }, [m, bucket]);
  const { data, keys } = useMemo(() => {
    const ks = [...new Set(rows.map((r) => r.dim ?? "Tổng"))].slice(0, 10); const byT = new Map<string, Record<string, number | string>>();
    for (const r of rows) { const o = byT.get(r.t) ?? { t: label(r.t, bucket), _t: r.t }; o[r.dim ?? "Tổng"] = r.v; byT.set(r.t, o); }
    const arr = [...byT.values()].sort((a, b) => String(a._t).localeCompare(String(b._t)));
    if (compare && prev.length) { const ps = [...new Set(prev.map((r) => r.t))].sort(); arr.forEach((o, i) => { const pt = ps[i]; if (pt) o["Kỳ trước"] = prev.filter((r) => r.t === pt).reduce((a, r) => a + r.v, 0); }); }
    if (chart === "cum") { const acc: Record<string, number> = {}; for (const o of arr) for (const k of [...ks, "Kỳ trước"]) if (typeof o[k] === "number") { acc[k] = (acc[k] ?? 0) + (o[k] as number); o[k] = acc[k]; } }
    return { data: arr, keys: compare && prev.length ? [...ks, "Kỳ trước"] : ks };
  }, [rows, prev, bucket, compare, chart]);
  const total = rows.reduce((a, r) => a + r.v, 0), prevTotal = prev.reduce((a, r) => a + r.v, 0);
  const groups = [...new Set(metrics.map((x) => x.group))];
  async function onPoint(o: Record<string, unknown> | undefined, key?: string) {
    if (!o) return; const t = String(o._t); const dimval = dim && key && key !== "Tổng" && key !== "Kỳ trước" ? key : null;
    const r = await fetch(`/api/series?records=1&metric=${metric}&bucket=${bucket}&t=${encodeURIComponent(t)}${dim ? `&dim=${dim}` : ""}${dimval ? `&dimval=${encodeURIComponent(dimval)}` : ""}`).then((x) => x.json());
    setDrill({ t: label(t, bucket), dimval, rows: r.rows ?? [] });
  }
  const Ch = chart === "line" || chart === "cum" ? LineChart : BarChart;
  return (
    <div className="space-y-3">
      <div className="card grid sm:grid-cols-2 lg:grid-cols-6 gap-2 items-end">
        <div className="lg:col-span-2"><label className="text-xs text-stone-500">Chỉ số ({metrics.length})</label><select className="input" value={metric} onChange={(e) => { setMetric(e.target.value); setDim(""); }}>{groups.map((g) => <optgroup key={g} label={g}>{metrics.filter((x) => x.group === g).map((x) => <option key={x.code} value={x.code}>{x.name}</option>)}</optgroup>)}</select></div>
        <div><label className="text-xs text-stone-500">Kỳ</label><select className="input" value={bucket} onChange={(e) => setBucket(e.target.value)}><option value="day">Ngày</option><option value="week">Tuần</option><option value="month">Tháng</option><option value="quarter">Quý</option><option value="year">Năm</option></select></div>
        <div><label className="text-xs text-stone-500">Cắt theo</label><select className="input" value={dim} onChange={(e) => setDim(e.target.value)}><option value="">Tổng</option>{(m?.dims ?? []).map((d) => <option key={d} value={d}>{d}</option>)}</select></div>
        <div><label className="text-xs text-stone-500">Từ</label><input type="date" className="input" value={from} onChange={(e) => setFrom(e.target.value)} /></div>
        <div><label className="text-xs text-stone-500">Đến</label><input type="date" className="input" value={to} onChange={(e) => setTo(e.target.value)} /></div>
      </div>
      <div className="flex gap-2 items-center flex-wrap text-sm"><span>Nhanh:</span>{[["7 ngày", 7, "day"], ["30 ngày", 30, "day"], ["Quý này", 92, "week"], ["1 năm", 365, "month"], ["3 năm", 1095, "quarter"]].map(([l, d, b]) => <button key={String(l)} className="btn-secondary !py-1 !px-3 !text-sm" onClick={() => { setFrom(new Date(Date.now() - Number(d) * 86400e3).toISOString().slice(0, 10)); setTo(new Date().toISOString().slice(0, 10)); setBucket(String(b)); }}>{l}</button>)}
        <span className="ml-auto flex gap-1 items-center">{[["bar", "Cột"], ["line", "Đường"], ["cum", "Lũy kế"]].map(([k, l]) => <button key={k} className={`btn-secondary !py-1 !px-3 !text-sm ${chart === k ? "!bg-green-700 !text-white" : ""}`} onClick={() => setChart(k as typeof chart)}>{l}</button>)}<label className="ml-2 flex items-center gap-1"><input type="checkbox" checked={compare} onChange={(e) => setCompare(e.target.checked)} /> So kỳ trước</label></span></div>
      <div className="card"><div className="flex flex-wrap justify-between items-baseline gap-2"><h3 className="font-bold">{m?.name} <span className="text-sm font-normal text-stone-500">({m?.unit}) · {sess.farmId}</span></h3><div className="text-sm">Tổng kỳ: <b>{fmt.n(total, 1)}</b> {m?.unit}{compare && prevTotal > 0 && <span className={total >= prevTotal ? "text-green-700" : "text-red-700"}> · {total >= prevTotal ? "▲" : "▼"} {fmt.n(((total - prevTotal) / prevTotal) * 100, 1)}% so kỳ trước ({fmt.n(prevTotal, 1)})</span>}{norm != null && <span className="text-stone-500"> · định mức ≈ {fmt.n(norm)}/kỳ</span>}</div></div>
        {loading && <div className="ui-skel py-10"><span className="sr-only">Đang tải…</span></div>}
        {!loading && err && <div role="alert" className="text-red-700">{err}</div>}
        {!loading && !rows.length && !err && <div className="text-stone-500 py-10 text-center">Chưa có dữ liệu trong khoảng này.</div>}
        {!loading && rows.length > 0 && <div className="h-80 mt-2"><ResponsiveContainer width="100%" height="100%"><Ch data={data} onClick={(e: unknown) => { const ap = (e as { activePayload?: { payload: Record<string, unknown> }[] } | null)?.activePayload; if (ap?.[0]) void onPoint(ap[0].payload); }}><CartesianGrid strokeDasharray="3 3" /><XAxis dataKey="t" /><YAxis /><Tooltip formatter={(v) => fmt.n(v, 1)} /><Legend />{norm != null && chart !== "cum" && <ReferenceLine y={norm} stroke="#9ca3af" strokeDasharray="4 4" label={{ value: "định mức", position: "insideTopRight", fontSize: 11 }} />}{keys.map((k, i) => chart === "bar" ? <Bar key={k} dataKey={k} stackId={k === "Kỳ trước" ? "b" : "a"} fill={k === "Kỳ trước" ? "#cbd5e1" : COLORS[i % COLORS.length]} cursor="pointer" onClick={(d: { payload?: Record<string, unknown> }) => onPoint(d?.payload, k)} /> : <Line key={k} type="monotone" dataKey={k} stroke={k === "Kỳ trước" ? "#94a3b8" : COLORS[i % COLORS.length]} strokeDasharray={k === "Kỳ trước" ? "5 5" : undefined} dot={{ r: 3 }} strokeWidth={2} />)}</Ch></ResponsiveContainer></div>}
        <div className="text-xs text-stone-500 mt-1">Bấm vào cột/điểm → danh sách bản ghi gốc (ai ghi, lúc nào). Đường xám đứt = định mức (NORM). "So kỳ trước" vẽ kỳ liền trước cùng độ dài.</div></div>
      {drill && <div className="card p-0 overflow-auto"><div className="flex justify-between px-3 py-2 bg-stone-100 rounded-t-2xl"><b>Bản ghi gốc · {drill.t}{drill.dimval ? ` · ${drill.dimval}` : ""} ({drill.rows.length})</b><button className="underline text-sm" onClick={() => setDrill(null)}>đóng</button></div>
        <table className="tbl"><thead><tr>{Object.keys(drill.rows[0] ?? {}).slice(0, 12).map((k) => <th key={k} className="pl-2">{k}</th>)}</tr></thead><tbody>{drill.rows.slice(0, 200).map((r, i) => <tr key={i}>{Object.keys(drill.rows[0] ?? {}).slice(0, 12).map((k) => <td key={k} className="pl-2 text-sm">{k === "ts" ? fmt.dt(r[k]) : typeof r[k] === "object" ? JSON.stringify(r[k]).slice(0, 60) : String(r[k] ?? "")}</td>)}</tr>)}</tbody></table>{drill.rows?.length === 0 && <div className="p-3 text-stone-500">Không có bản ghi.</div>}</div>}
      {rows.length > 0 && <div className="card p-0 overflow-auto"><div className="flex justify-between px-3 py-2 bg-stone-100 rounded-t-2xl"><b>Bảng số liệu</b><button className="underline text-sm" onClick={() => { const csv = "﻿ky,chieu,gia_tri\n" + rows.map((r) => `${r.t},${r.dim ?? ""},${r.v}`).join("\n"); const a = document.createElement("a"); a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" })); a.download = `${metric}-${bucket}-${from}_${to}.csv`; a.click(); }}>⬇ CSV</button></div><table className="tbl"><thead><tr><th className="pl-3">Kỳ</th>{keys.map((k) => <th key={k} className="text-right">{k}</th>)}</tr></thead><tbody>{data.map((d, i) => <tr key={i} className="cursor-pointer hover:bg-green-50" onClick={() => onPoint(d)}><td className="pl-3">{String(d.t)}</td>{keys.map((k) => <td key={k} className="text-right">{d[k] != null ? fmt.n(d[k], 1) : ""}</td>)}</tr>)}</tbody></table></div>}
    </div>);
}
