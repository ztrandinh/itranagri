"use client";
import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";
import { KpiTile } from "./Dashboards";
import { usePrompt } from "@/components/ui/PromptDialog";

/** P&L phân hệ theo tháng + chi phí cố định + import sao kê */
export function PlPanel({ sess }: { sess: Sess }) {
  const pl = useData("pl_cc"); const fixed = useData("cc_fixed_costs"); const bank = useData("bank_lines");
  const [f, setF] = useState<Record<string, string>>({ month: new Date().toISOString().slice(0, 7) + "-01", kind: "LUONG" }); const [msg, setMsg] = useState("");
  const months = [...new Set((pl.rows ?? []).map((r) => String(r.month).slice(0, 10)))].sort().reverse(); const [m, setM] = useState<string | null>(null); const cur = m ?? months[0];
  const rows = (pl.rows ?? []).filter((r) => String(r.month).slice(0, 10) === cur);
  const tot = (k: string) => rows.reduce((a, r) => a + Number(r[k] ?? 0), 0);
  const canW = ["accountant","director","owner"].includes(sess.role);
  return (
    <div className="space-y-4">
      <div className="card"><div className="flex flex-wrap items-center gap-2"><h3 className="font-bold">P&L phân hệ (CC) — doanh thu ngoài + nội bộ 70% − vật tư trực tiếp − nội bộ − chi phí cố định = EBITDA</h3><select className="input !w-40 ml-auto" value={cur ?? ""} onChange={(e) => setM(e.target.value)}>{months.map((x) => <option key={x} value={x}>{x.slice(0, 7)}</option>)}</select></div>
        <div className="overflow-auto mt-2"><table className="tbl"><thead><tr><th>CC</th><th className="text-right">DT ngoài</th><th className="text-right">DT nội bộ</th><th className="text-right">Vật tư</th><th className="text-right">Mua nội bộ</th><th className="text-right">Cố định</th><th className="text-right">EBITDA</th></tr></thead><tbody>
          {rows.map((r) => <tr key={String(r.cc)} className={Number(r.ebitda) < 0 ? "bg-red-50" : ""}><td className="font-semibold">{String(r.cc)}</td><td className="text-right">{fmt.vnd(r.revenue_external)}</td><td className="text-right">{fmt.vnd(r.revenue_internal)}</td><td className="text-right">{fmt.vnd(r.material_cost)}</td><td className="text-right">{fmt.vnd(r.internal_cost)}</td><td className="text-right">{fmt.vnd(r.fixed_cost)}</td><td className={`text-right font-bold ${Number(r.ebitda) < 0 ? "text-red-700" : "text-green-700"}`}>{fmt.vnd(r.ebitda)}</td></tr>)}
          <tr className="font-bold border-t-2"><td>Tổng trại</td><td className="text-right">{fmt.vnd(tot("revenue_external"))}</td><td className="text-right">{fmt.vnd(tot("revenue_internal"))}</td><td className="text-right">{fmt.vnd(tot("material_cost"))}</td><td className="text-right">{fmt.vnd(tot("internal_cost"))}</td><td className="text-right">{fmt.vnd(tot("fixed_cost"))}</td><td className="text-right">{fmt.vnd(tot("ebitda"))}</td></tr></tbody></table></div>
        <div className="text-xs text-stone-500 mt-1">Phân hệ lỗ 3 quý liên tiếp → tái cấu trúc/cắt (trừ hạ tầng trục). Vật tư định giá theo giá vốn lô; nội bộ = 70% giá sàn. Chi phí cố định (lương, khấu hao, điện nước, thuê ngoài) nhập theo tháng bên dưới.</div></div>
      <div className="grid md:grid-cols-2 gap-3">
        <div className="card"><h3 className="font-bold">Chi phí cố định theo CC / tháng</h3>
          {canW && <div className="flex flex-wrap gap-2 mt-2"><input type="date" className="input !w-40" value={f.month} onChange={(e) => setF({ ...f, month: e.target.value })} /><select className="input !w-32" value={f.cc ?? ""} onChange={(e) => setF({ ...f, cc: e.target.value })}><option value="">CC</option>{["CC-BO","CC-GA","CC-RAS","CC-TRUN","CC-D5","CC-TT","CC-CB","CC-KD","CC-DL","CC-HC","CC-CN","CC-VIEN"].map((c) => <option key={c}>{c}</option>)}</select><select className="input !w-36" value={f.kind} onChange={(e) => setF({ ...f, kind: e.target.value })}>{["LUONG","KHAU_HAO","DIEN_NUOC","THUE_NGOAI","KHAC"].map((k) => <option key={k}>{k}</option>)}</select><input className="input !w-36" type="number" placeholder="Số tiền" value={f.amount ?? ""} onChange={(e) => setF({ ...f, amount: e.target.value })} /><button className="btn-secondary !py-2" onClick={async () => { if (!f.cc || !f.amount) return; await act("add_fixed_cost", { month: f.month.slice(0, 7) + "-01", cost_center: f.cc, kind: f.kind, amount: Number(f.amount) }); fixed.reload(); pl.reload(); }}>Lưu</button></div>}
          <table className="tbl mt-2"><tbody>{(fixed.rows ?? []).slice(0, 30).map((r) => <tr key={String(r.id)}><td>{String(r.month).slice(0, 7)}</td><td>{String(r.cost_center)}</td><td>{String(r.kind)}</td><td className="text-right">{fmt.vnd(r.amount)}</td></tr>)}</tbody></table></div>
        <div className="card"><h3 className="font-bold">Import sao kê ngân hàng (RC10 tiền vs hàng)</h3>
          {canW && <form className="flex flex-wrap gap-2 mt-2" onSubmit={async (e) => { e.preventDefault(); const fd = new FormData(e.currentTarget); const r = await fetch("/api/import/bank", { method: "POST", body: fd }); const j = await r.json(); setMsg(j.ok ? `Đã nhập ${j.imported} dòng, bỏ ${j.skipped}` : `Lỗi: ${j.error} ${JSON.stringify(j.head ?? "")}`); bank.reload(); }}><input name="bank" className="input !w-40" placeholder="Ngân hàng" /><input name="file" type="file" accept=".csv,.txt" className="input !w-64" required /><button className="btn-primary !py-2">Nhập CSV</button></form>}
          {msg && <div className="text-sm mt-1">{msg}</div>}
          <div className="text-xs text-stone-500 mt-1">CSV cột: Ngày · Số tiền (ghi có) · Nội dung [· Ghi nợ]. Sau khi nhập, chạy đối soát → RC10 so SALE đã thu (CK/QR/POS) theo ngày.</div>
          <table className="tbl mt-2"><tbody>{(bank.rows ?? []).slice(0, 15).map((r) => <tr key={String(r.id)}><td>{fmt.d(r.txn_date)}</td><td>{String(r.direction)}</td><td className="text-right">{fmt.vnd(r.amount)}</td><td className="text-xs">{String(r.memo ?? "").slice(0, 40)}</td></tr>)}</tbody></table></div>
      </div>
    </div>);
}

/** KPI → lương lớp 2 */
export function KpiLuongPanel({ sess }: { sess: Sess }) {
  const [month, setMonth] = useState(new Date().toISOString().slice(0, 7) + "-01"); const k = useData("staff_kpi", { month }); const hist = useData("staff_kpi_history");
  const canW = ["director","owner","it_engineer"].includes(sess.role);
  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center gap-2"><input type="month" className="input !w-44" value={month.slice(0, 7)} onChange={(e) => setMonth(e.target.value + "-01")} />{canW && <button className="btn-secondary !py-2" onClick={async () => { await act("compute_kpi", { month }); k.reload(); }}>↻ Chấm KPI tháng này (máy chấm từ bản ghi)</button>}<span className="text-sm text-stone-500 ml-auto">Lớp 2 = 10–25% lương cứng theo điểm KPI; lớp 3 khoán quý từ P&L CC; lớp 4 chia năm + ESOP ảo</span></div>
      <div className="card p-0 overflow-auto"><table className="tbl"><thead><tr><th className="pl-3">Nhân sự</th><th className="text-right">Điểm</th><th className="text-right">Thưởng lớp 2</th><th>Chi tiết (giá trị / mục tiêu / điểm)</th></tr></thead><tbody>
        {(k.rows ?? []).map((r) => <tr key={String(r.staff_id)} className={Number(r.score) < 60 ? "bg-red-50" : Number(r.score) >= 95 ? "bg-green-50" : ""}><td className="pl-3 font-semibold">{String(r.full_name)}<div className="text-xs text-stone-500 font-normal">{String(r.position ?? "")}</div></td><td className="text-right text-2xl font-bold">{String(r.score)}</td><td className="text-right font-bold">{String(r.bonus_pct)}%</td><td className="text-xs">{Object.entries((r.detail as Record<string, { v: number; t: number; s: number }>) ?? {}).map(([c, d]) => <span key={c} className="b-gray mr-1">{c.replace("KPI-", "")}: {fmt.n(d.v, 1)}/{d.t} → {d.s}</span>)}</td></tr>)}
        {k.rows?.length === 0 && <tr><td colSpan={4} className="p-3 text-stone-500">Chưa chấm tháng này — bấm "Chấm KPI".</td></tr>}</tbody></table></div>
      <div className="card"><h3 className="font-bold">Điểm KPI trung bình theo tháng</h3><div className="flex gap-2 flex-wrap mt-1">{(hist.rows ?? []).map((h) => <span key={String(h.month)} className="b-gray">{String(h.month).slice(0, 7)}: {String(h.score)}</span>)}</div><div className="text-xs text-stone-500 mt-1">Mọi điểm drill được về bản ghi (số bản ghi/ngày, checklist xanh %, sai số mẻ, việc đúng hạn, % nhập bù). Người lao động xem được điểm của mình.</div></div>
    </div>);
}

/** Sơ đồ khu (lưới) — tô màu theo cần chú ý; bấm → danh sách */
export function SoDoPanel({ sess }: { sess: Sess }) {
  const g = useData("location_grid"); const cols = 6; const canW = ["director","owner","it_engineer","tech_head"].includes(sess.role);
  const [edit, setEdit] = useState(false); const [drag, setDrag] = useState<string | null>(null);
  const cells = useMemo(() => { const m = new Map<string, Record<string, unknown>>(); for (const r of g.rows ?? []) m.set(`${r.grid_x},${r.grid_y}`, r); return m; }, [g.rows]);
  const rowsN = Math.max(3, ...(g.rows ?? []).map((r) => Number(r.grid_y) + 1));
  return (
    <div className="space-y-3">
      <div className="flex items-center gap-2 text-sm"><span>Sơ đồ khu trại {sess.farmId} — màu: <span className="b-grn">bình thường</span> <span className="b-yel">có cần chú ý</span> <span className="b-red">≥3 cần chú ý</span> <span className="b-gray">trống</span></span>{canW && <button className={`btn-secondary !py-1 !px-3 !text-sm ml-auto ${edit ? "!bg-green-700 !text-white" : ""}`} onClick={() => setEdit(!edit)}>{edit ? "✓ Xong sắp xếp" : "Sắp xếp (kéo thả)"}</button>}</div>
      <div className="card overflow-auto"><div className="grid gap-2" style={{ gridTemplateColumns: `repeat(${cols}, minmax(120px, 1fr))` }}>
        {Array.from({ length: rowsN * cols }, (_, i) => { const x = i % cols, y = Math.floor(i / cols); const r = cells.get(`${x},${y}`);
          return <div key={i} draggable={edit && !!r} onDragStart={() => setDrag(String(r?.id))} onDragOver={(e) => edit && e.preventDefault()} onDrop={async () => { if (edit && drag) { await act("set_grid", { id: drag, x, y }); setDrag(null); g.reload(); } }}
            className={`rounded-xl border p-2 min-h-[84px] ${!r ? "border-dashed border-stone-200" : Number(r.attention) >= 3 ? "bg-red-50 border-red-300" : Number(r.attention) > 0 ? "bg-amber-50 border-amber-300" : Number(r.head_individual) + Number(r.head_group) > 0 ? "bg-green-50 border-green-300" : "bg-stone-50"}`}>
            {r && <Link href={`/dan?location=${r.id}`} className="block"><div className="font-semibold text-sm leading-tight">{String(r.name)}</div><div className="text-xs text-stone-500">{String(r.kind)}</div><div className="text-sm mt-1">{Number(r.head_individual) > 0 && <b>{String(r.head_individual)} con</b>}{Number(r.head_group) > 0 && <span> · {fmt.n(r.head_group)} nhóm</span>}</div>{Number(r.attention) > 0 && <div className="text-xs text-amber-800">⚠ {String(r.attention)} cần chú ý</div>}{Number(r.open_tasks) > 0 && <div className="text-xs">{String(r.open_tasks)} việc</div>}</Link>}
          </div>; })}
      </div></div>
      <div className="text-xs text-stone-500">Bản đồ GIS thật (polygon lô, geofence) ở Ray B; sơ đồ này đủ để "nhìn một cái biết chỗ nào có việc".</div>
    </div>);
}

/** Tin nhắn khách nhận nuôi (phía trại) */
export function KhachMessages() {
  const m = useData("customer_messages"); const [reply, setReply] = useState<Record<string, string>>({});
  return (<div className="card"><h3 className="font-bold">Tin nhắn khách chăm sóc hộ (SLA trả lời ≤ 24h)</h3>
    {(m.rows ?? []).filter((x) => x.from_customer).slice(0, 30).map((x) => <div key={String(x.id)} className="border-b py-2 text-sm"><div><b>{String(x.partner_name ?? x.contract_id)}</b> · {fmt.dt(x.ts)} {x.animal_id ? `· ${x.animal_id}` : ""}{x.replied_at ? <span className="b-grn ml-1">đã trả lời</span> : <span className="b-yel ml-1">chờ</span>}</div><div>{String(x.body)}</div>{!x.replied_at && <div className="flex gap-2 mt-1"><input className="input !py-1" placeholder="Trả lời…" value={reply[String(x.id)] ?? ""} onChange={(e) => setReply({ ...reply, [String(x.id)]: e.target.value })} /><button className="btn-primary !py-1 !px-3 !text-sm" onClick={async () => { await act("reply_customer", { reply_to: x.id, contract_id: x.contract_id, animal_id: x.animal_id, body: reply[String(x.id)] }); m.reload(); }}>Gửi</button></div>}</div>)}
    {!(m.rows ?? []).some((x) => x.from_customer) && <div className="text-stone-500 text-sm">Chưa có tin nhắn.</div>}</div>);
}

/** Bộ lọc lưu (localStorage) dùng chung */
export function SavedViews({ scope, current, onPick }: { scope: string; current: Record<string, unknown>; onPick: (v: Record<string, unknown>) => void }) {
  const key = `views:${scope}`; const [views, setViews] = useState<{ name: string; v: Record<string, unknown> }[]>([]); const { prompt, promptElement } = usePrompt();
  useEffect(() => { try { setViews(JSON.parse(localStorage.getItem(key) ?? "[]")); } catch { /* ignore */ } }, [key]);
  const save = async () => { const name = await prompt({ title: "Lưu bộ lọc", label: "Tên bộ lọc:", type: "text" }); if (!name) return; const nv = [...views.filter((x) => x.name !== name), { name, v: current }]; setViews(nv); localStorage.setItem(key, JSON.stringify(nv)); };
  return <div className="flex flex-wrap gap-1 items-center text-sm">{promptElement}<span className="text-stone-500">Bộ lọc lưu:</span>{views.map((x) => <span key={x.name} className="b-gray cursor-pointer" onClick={() => onPick(x.v)}>{x.name} <button className="ml-1 text-red-700" onClick={(e) => { e.stopPropagation(); const nv = views.filter((y) => y.name !== x.name); setViews(nv); localStorage.setItem(key, JSON.stringify(nv)); }}>×</button></span>)}<button className="underline" onClick={save}>+ lưu bộ lọc hiện tại</button></div>;
}
