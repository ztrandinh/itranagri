"use client";
import { useEffect, useMemo, useState } from "react";
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, Tooltip, Legend, CartesianGrid, ResponsiveContainer } from "recharts";
import { fmt } from "@/lib/client";
type Row = { t: string; dim: string | null; v: number };
const COLORS = ["#166534", "#0369a1", "#b45309", "#7e22ce", "#be123c", "#0f766e", "#4d7c0f", "#a16207", "#1d4ed8", "#9f1239", "#334155", "#ca8a04"];
export const labelT = (t: string, bucket: string) => { const d = new Date(t); return bucket === "day" || bucket === "week" ? d.toLocaleDateString("vi-VN", { day: "2-digit", month: "2-digit" }) : bucket === "month" ? `T${d.getMonth() + 1}/${d.getFullYear()}` : bucket === "quarter" ? `Q${Math.floor(d.getMonth() / 3) + 1}/${d.getFullYear()}` : String(d.getFullYear()); };
export type AnyChartProps = { table: string; col: string; agg?: "sum" | "avg" | "count" | "min" | "max"; bucket?: string; dim?: string | null; filters?: Record<string, string>; from?: string; to?: string; chart?: "bar" | "line" | "cum"; compare?: boolean; height?: number; title?: string; unit?: string; onDrill?: (t: string, dimval: string | null, rows: Record<string, unknown>[]) => void; showControls?: boolean };

/** Biểu đồ MỌI TRƯỜNG — gắn được ở bất kỳ màn nào: <AnyChart table="inventory_moves" col="qty" dim="sku" filters={{direction:"1"}} /> */
export default function AnyChart(p: AnyChartProps) {
  const [bucket, setBucket] = useState(p.bucket ?? "day"); const [chart, setChart] = useState<"bar" | "line" | "cum">(p.chart ?? "bar");
  const [from, setFrom] = useState(p.from ?? new Date(Date.now() - 30 * 86400e3).toISOString().slice(0, 10)); const [to, setTo] = useState(p.to ?? new Date().toISOString().slice(0, 10));
  const [rows, setRows] = useState<Row[]>([]); const [prev, setPrev] = useState<Row[]>([]); const [err, setErr] = useState<string | null>(null); const [drill, setDrill] = useState<{ t: string; rows: Record<string, unknown>[] } | null>(null);
  useEffect(() => { setBucket(p.bucket ?? "day"); }, [p.bucket]);
  const qs = useMemo(() => { const u = new URLSearchParams({ table: p.table, col: p.col, agg: p.agg ?? "sum", bucket, from, to }); if (p.dim) u.set("dim", p.dim); if (p.compare) u.set("compare", "1"); for (const [k, v] of Object.entries(p.filters ?? {})) if (v) u.set(`f.${k}`, v); return u.toString(); }, [p.table, p.col, p.agg, p.dim, p.compare, p.filters, bucket, from, to]);
  useEffect(() => { setDrill(null); fetch(`/api/series/any?${qs}`).then((r) => r.json()).then((j) => { if (j.rows) { setRows(j.rows.map((r: Row) => ({ ...r, v: Number(r.v) }))); setPrev((j.prev ?? []).map((r: Row) => ({ ...r, v: Number(r.v) }))); setErr(null); } else setErr(j.error + (j.detail ? `: ${j.detail}` : "")); }).catch((e) => setErr(String(e))); }, [qs]);
  const { data, keys } = useMemo(() => {
    const ks = [...new Set(rows.map((r) => r.dim ?? "Tổng"))].slice(0, 12); const byT = new Map<string, Record<string, number | string>>();
    for (const r of rows) { const o = byT.get(r.t) ?? { t: labelT(r.t, bucket), _t: r.t }; if (ks.includes(r.dim ?? "Tổng")) o[r.dim ?? "Tổng"] = r.v; byT.set(r.t, o); }
    const arr = [...byT.values()].sort((a, b) => String(a._t).localeCompare(String(b._t)));
    if (p.compare && prev.length) { const ps = [...new Set(prev.map((r) => r.t))].sort(); arr.forEach((o, i) => { const pt = ps[i]; if (pt) o["Kỳ trước"] = prev.filter((r) => r.t === pt).reduce((a, r) => a + r.v, 0); }); }
    if (chart === "cum") { const acc: Record<string, number> = {}; for (const o of arr) for (const k of [...ks, "Kỳ trước"]) if (typeof o[k] === "number") { acc[k] = (acc[k] ?? 0) + (o[k] as number); o[k] = acc[k]; } }
    return { data: arr, keys: p.compare && prev.length ? [...ks, "Kỳ trước"] : ks };
  }, [rows, prev, bucket, chart, p.compare]);
  const total = rows.reduce((a, r) => a + r.v, 0); const prevTotal = prev.reduce((a, r) => a + r.v, 0);
  async function onPoint(o: Record<string, unknown> | undefined, key?: string) {
    if (!o) return; const t = String(o._t); const dimval = p.dim && key && key !== "Tổng" && key !== "Kỳ trước" ? key : null;
    const r = await fetch(`/api/series/any?${qs}&records=1&t=${encodeURIComponent(t)}${dimval ? `&dimval=${encodeURIComponent(dimval)}` : ""}`).then((x) => x.json());
    if (p.onDrill) p.onDrill(t, dimval, r.rows ?? []); else setDrill({ t: labelT(t, bucket) + (dimval ? ` · ${dimval}` : ""), rows: r.rows ?? [] });
  }
  const Ch = chart === "line" || chart === "cum" ? LineChart : BarChart; const isAvg = p.agg === "avg" || p.agg === "min" || p.agg === "max";
  return (
    <div>
      {(p.showControls ?? true) && <div className="flex flex-wrap gap-2 items-center text-sm mb-1">
        {p.title && <b className="mr-2">{p.title}</b>}
        <select className="input !w-auto !py-1 !text-sm" value={bucket} onChange={(e) => setBucket(e.target.value)}><option value="day">Ngày</option><option value="week">Tuần</option><option value="month">Tháng</option><option value="quarter">Quý</option><option value="year">Năm</option></select>
        <input type="date" className="input !w-auto !py-1 !text-sm" value={from} onChange={(e) => setFrom(e.target.value)} /><span>→</span><input type="date" className="input !w-auto !py-1 !text-sm" value={to} onChange={(e) => setTo(e.target.value)} />
        <div className="flex rounded-lg overflow-hidden border">{(["bar", "line", "cum"] as const).map((c) => <button key={c} className={`px-2 py-1 ${chart === c ? "bg-green-700 text-white" : "bg-white"}`} onClick={() => setChart(c)}>{c === "bar" ? "Cột" : c === "line" ? "Đường" : "Lũy kế"}</button>)}</div>
        <span className="ml-auto font-bold">{isAvg ? "TB" : "Tổng"}: {fmt.n(isAvg && rows.length ? total / rows.length : total, 1)} {p.unit ?? ""}{p.compare && prev.length ? <span className={`ml-1 text-xs ${total >= prevTotal ? "text-green-700" : "text-red-700"}`}>({prevTotal ? `${total >= prevTotal ? "+" : ""}${(((total - prevTotal) / prevTotal) * 100).toFixed(0)}%` : "n/a"} vs kỳ trước)</span> : null}</span>
      </div>}
      {err && <div className="text-red-700 text-sm">{err}</div>}
      <div style={{ height: p.height ?? 260 }}>{data.length ? <ResponsiveContainer><Ch data={data} onClick={(e: unknown) => { const ev = e as { activePayload?: { payload: Record<string, unknown> }[] }; if (ev?.activePayload?.[0]) onPoint(ev.activePayload[0].payload); }}><CartesianGrid strokeDasharray="3 3" stroke="#e7e5e4" /><XAxis dataKey="t" fontSize={11} /><YAxis fontSize={11} tickFormatter={(v: number) => fmt.n(v)} width={56} /><Tooltip formatter={(v: unknown) => fmt.n(Number(v), 1)} /><Legend />
        {keys.map((k, i) => chart === "bar" ? <Bar key={k} dataKey={k} fill={k === "Kỳ trước" ? "#a8a29e" : COLORS[i % COLORS.length]} stackId={p.dim ? "s" : undefined} onClick={(d: unknown) => onPoint((d as { payload?: Record<string, unknown> })?.payload, k)} cursor="pointer" /> : <Line key={k} type="monotone" dataKey={k} stroke={k === "Kỳ trước" ? "#a8a29e" : COLORS[i % COLORS.length]} strokeWidth={2} dot={{ r: 3 }} strokeDasharray={k === "Kỳ trước" ? "5 5" : undefined} activeDot={{ r: 6, onClick: (_e: unknown, d: unknown) => onPoint((d as { payload?: Record<string, unknown> })?.payload, k) }} />)}
      </Ch></ResponsiveContainer> : <div className="h-full flex items-center justify-center text-stone-400 text-sm">Không có dữ liệu trong khoảng đã chọn</div>}</div>
      {drill && <div className="card mt-2 p-0 overflow-auto"><div className="px-3 py-1.5 bg-stone-100 rounded-t-2xl flex justify-between text-sm"><b>Bản ghi gốc · {drill.t} ({drill.rows.length})</b><button onClick={() => setDrill(null)}>✕</button></div><RecordsTable rows={drill.rows} /></div>}
    </div>);
}
export function RecordsTable({ rows }: { rows: Record<string, unknown>[] }) {
  if (!rows.length) return <div className="p-3 text-stone-500 text-sm">Không có bản ghi.</div>;
  const cols = Object.keys(rows[0]).filter((k) => !["farm_id", "org_id", "supersedes_id", "client_ref", "photo_hash", "search"].includes(k)).slice(0, 14);
  return <table className="tbl text-xs"><thead><tr>{cols.map((c) => <th key={c} className="pl-2">{c}</th>)}</tr></thead><tbody>{rows.slice(0, 200).map((r, i) => <tr key={i}>{cols.map((c) => <td key={c} className="pl-2 max-w-[220px] truncate">{typeof r[c] === "object" && r[c] !== null ? JSON.stringify(r[c]).slice(0, 80) : /^\d{4}-\d\d-\d\dT/.test(String(r[c] ?? "")) ? fmt.dt(String(r[c])) : String(r[c] ?? "")}</td>)}</tr>)}</tbody></table>;
}

/** Trình khám phá MỌI TRƯỜNG: chọn bảng → cột số → cách gộp → nhóm theo → lọc → biểu đồ */
export function AnyExplorer({ initial }: { initial?: Partial<AnyChartProps> }) {
  const [tables, setTables] = useState<{ table: string; label: string }[]>([]); const [table, setTable] = useState(initial?.table ?? "inventory_moves");
  const [meta, setMeta] = useState<{ cols: { name: string; type: string; kind: string }[]; jsonKeys: Record<string, string[]> } | null>(null);
  const [col, setCol] = useState(initial?.col ?? "qty"); const [agg, setAgg] = useState<AnyChartProps["agg"]>(initial?.agg ?? "sum"); const [dim, setDim] = useState(initial?.dim ?? ""); const [filters, setFilters] = useState<Record<string, string>>(initial?.filters ?? {}); const [fcol, setFcol] = useState(""); const [fvals, setFvals] = useState<{ v: string; n: number }[]>([]); const [compare, setCompare] = useState(false);
  useEffect(() => { fetch("/api/series/any?tables=1").then((r) => r.json()).then((j) => setTables(j.tables ?? [])); }, []);
  useEffect(() => { fetch(`/api/series/any?cols=${table}`).then((r) => r.json()).then((j) => { setMeta(j); const nums = (j.cols ?? []).filter((c: { kind: string }) => c.kind === "num"); if (!nums.find((c: { name: string }) => c.name === col)) { setCol(nums[0]?.name ?? "id"); if (!nums.length) setAgg("count"); } }); // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [table]);
  useEffect(() => { if (!fcol) { setFvals([]); return; } fetch(`/api/series/any?distinct=${table}&col=${encodeURIComponent(fcol)}`).then((r) => r.json()).then((j) => setFvals(j.values ?? [])); }, [fcol, table]);
  const nums = meta?.cols.filter((c) => c.kind === "num") ?? []; const dims = [...(meta?.cols.filter((c) => c.kind === "dim").map((c) => c.name) ?? []), ...Object.entries(meta?.jsonKeys ?? {}).flatMap(([jc, ks]) => ks.map((k) => `${jc}.${k}`))];
  const jsonNums = Object.entries(meta?.jsonKeys ?? {}).flatMap(([jc, ks]) => ks.map((k) => `${jc}.${k}`));
  return (
    <div className="space-y-2">
      <div className="card grid sm:grid-cols-2 lg:grid-cols-5 gap-2 items-end">
        <div className="lg:col-span-2"><label className="text-xs text-stone-500">Bảng dữ liệu ({tables.length})</label><select className="input" value={table} onChange={(e) => { setTable(e.target.value); setDim(""); setFilters({}); setFcol(""); }}>{tables.map((t) => <option key={t.table} value={t.table}>{t.label}</option>)}</select></div>
        <div><label className="text-xs text-stone-500">Trường số</label><select className="input" value={col} onChange={(e) => setCol(e.target.value)}>{nums.map((c) => <option key={c.name} value={c.name}>{c.name} ({c.type})</option>)}{jsonNums.length ? <optgroup label="Trường trong JSON">{jsonNums.map((k) => <option key={k} value={k}>{k}</option>)}</optgroup> : null}<option value="id">— đếm bản ghi —</option></select></div>
        <div><label className="text-xs text-stone-500">Cách gộp</label><select className="input" value={agg} onChange={(e) => setAgg(e.target.value as AnyChartProps["agg"])}><option value="sum">Tổng</option><option value="avg">Trung bình</option><option value="count">Đếm</option><option value="min">Nhỏ nhất</option><option value="max">Lớn nhất</option></select></div>
        <div><label className="text-xs text-stone-500">Nhóm theo (chồng cột / nhiều đường)</label><select className="input" value={dim} onChange={(e) => setDim(e.target.value)}><option value="">Tổng</option>{dims.map((d) => <option key={d} value={d}>{d}</option>)}</select></div>
        <div className="lg:col-span-3 flex flex-wrap gap-1 items-end"><div><label className="text-xs text-stone-500">Lọc theo cột</label><select className="input !w-44" value={fcol} onChange={(e) => setFcol(e.target.value)}><option value="">— chọn cột —</option>{dims.map((d) => <option key={d} value={d}>{d}</option>)}</select></div>
          {fcol && <div><label className="text-xs text-stone-500">Giá trị</label><select className="input !w-56" value={filters[fcol] ?? ""} onChange={(e) => setFilters({ ...filters, [fcol]: e.target.value })}><option value="">— tất cả —</option>{fvals.map((v) => <option key={v.v} value={v.v}>{v.v} ({v.n})</option>)}</select></div>}
          {Object.entries(filters).filter(([, v]) => v).map(([k, v]) => <span key={k} className="b-yel">{k} = {v} <button onClick={() => setFilters({ ...filters, [k]: "" })}>✕</button></span>)}</div>
        <label className="text-sm flex items-center gap-1"><input type="checkbox" checked={compare} onChange={(e) => setCompare(e.target.checked)} /> So kỳ trước</label>
        <div className="text-xs text-stone-500 lg:col-span-5">Nguyên tắc: <b>bất kỳ trường số nào được nhập vào hệ thống đều có biểu đồ</b> — không cần lập trình thêm; thêm bảng/cột mới → danh sách này tự cập nhật. Bấm cột/điểm để xem bản ghi gốc & người ghi.</div>
      </div>
      <div className="card"><AnyChart table={table} col={agg === "count" ? "id" : col} agg={agg} dim={dim || null} filters={filters} compare={compare} height={320} /></div>
    </div>);
}
