"use client";
import { useMemo, useState } from "react";
import Link from "next/link";
import ThreeTap from "@/components/ThreeTap";
import { buildForms, type Ref } from "@/lib/forms";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";
import { KpiTile, HourHistogram } from "./Dashboards";

const LV = (l: string) => (l === "DO" ? "b-red" : l === "VANG" || l === "CAM" ? "b-yel" : l === "OK" ? "b-grn" : "b-gray");

export function DoiSoatPanel({ sess }: { sess: Sess }) {
  const latest = useData("recon_latest"); const [rule, setRule] = useState<string | null>(null); const hist = useData(rule ? "recon_history" : null, { rule: rule ?? undefined });
  const [busy, setBusy] = useState(false); const [date, setDate] = useState(new Date(Date.now() - 86400e3).toISOString().slice(0, 10));
  return (
    <div className="space-y-3">
      <div className="card flex flex-wrap items-center gap-2"><b>Reconciliation engine</b> — RC1–RC10 bộ gốc · RC11 giấy–số · RC12 tem. Chạy đêm 01:00; chạy tay: <input type="date" className="input !w-44" value={date} onChange={(e) => setDate(e.target.value)} />
        {["tech_head","director","owner","it_engineer"].includes(sess.role) && <button className="btn-primary !py-2" disabled={busy} onClick={async () => { setBusy(true); await fetch(`/api/jobs/recon?farm=${sess.farmId}&date=${date}`, { method: "POST" }); setBusy(false); latest.reload(); }}>{busy ? "…" : "▶ Chạy đối soát"}</button>}
        <a className="btn-secondary !py-2 ml-auto" href="/api/exports/recon">⬇ CSV</a></div>
      <div className="card p-0 overflow-auto"><table className="tbl"><thead><tr><th className="pl-3">Mã</th><th>Đối soát</th><th>Kỳ</th><th className="text-right">Vế A</th><th className="text-right">Vế B</th><th className="text-right">Lệch</th><th>Trạng thái</th><th></th></tr></thead><tbody>
        {(latest.rows ?? []).map((r) => <tr key={String(r.id)} className={r.status === "DO" ? "bg-red-50" : r.status === "VANG" ? "bg-amber-50" : ""}><td className="pl-3 font-bold"><button className="underline" onClick={() => setRule(String(r.rule_code))}>{String(r.rule_code)}</button></td><td>{String(r.name)}</td><td>{fmt.d(r.period)}</td><td className="text-right">{fmt.n(r.expected, 1)}</td><td className="text-right">{fmt.n(r.actual, 1)}</td><td className="text-right font-bold">{r.diff_pct != null ? fmt.n(r.diff_pct, 2) : "—"}</td><td><span className={LV(String(r.status))}>{String(r.status)}</span>{(r.detail as Record<string, unknown>)?.err ? <div className="text-xs text-red-700">{String((r.detail as Record<string, unknown>).err).slice(0, 80)}</div> : null}</td><td>{["DO","VANG"].includes(String(r.status)) && !r.acked_by && ["tech_head","director","owner"].includes(sess.role) && <button className="btn-secondary !py-1 !px-2 !text-sm" onClick={async () => { await act("ack_recon", { id: r.id }); latest.reload(); }}>Đã xem</button>}{r.acked_by ? <span className="text-xs">✓ {String(r.acked_by)}</span> : null}</td></tr>)}
        {!latest.rows?.length && <tr><td colSpan={8} className="p-4 text-stone-500">Chưa có kết quả — bấm "Chạy đối soát".</td></tr>}</tbody></table></div>
      {rule && <div className="card"><h3 className="font-bold">Lịch sử {rule}</h3><table className="tbl"><thead><tr><th>Kỳ</th><th className="text-right">A</th><th className="text-right">B</th><th className="text-right">Lệch</th><th>TT</th></tr></thead><tbody>{(hist.rows ?? []).map((r) => <tr key={String(r.id)}><td>{fmt.d(r.period)}</td><td className="text-right">{fmt.n(r.expected, 1)}</td><td className="text-right">{fmt.n(r.actual, 1)}</td><td className="text-right">{fmt.n(r.diff_pct, 2)}</td><td><span className={LV(String(r.status))}>{String(r.status)}</span></td></tr>)}</tbody></table></div>}
    </div>);
}

export function CanhBaoPanel({ sess }: { sess: Sess }) {
  const open = useData("alerts_open"); const all = useData("alerts_all"); const grouped = useData("alerts_grouped"); const [tab, setTab] = useState<"open" | "all" | "group">("group");
  const rows = tab === "open" ? open.rows : all.rows;
  return (
    <div className="space-y-3">
      <div className="flex gap-2 items-center">{[["group", "Theo luật (30 ngày)"], ["open", `Chưa xử lý (${open.rows?.length ?? 0})`], ["all", "Tất cả"]].map(([k, l]) => <button key={k} className={`px-4 py-2 rounded-xl font-semibold ${tab === k ? "bg-green-700 text-white" : "bg-white border"}`} onClick={() => setTab(k as typeof tab)}>{l}</button>)}
        {["tech_head","director","owner","it_engineer"].includes(sess.role) && <button className="btn-secondary !py-2 ml-auto" onClick={async () => { await fetch(`/api/jobs/alerts?farm=${sess.farmId}`, { method: "POST" }); open.reload(); all.reload(); }}>▶ Quét cảnh báo ngay</button>}</div>
      {tab === "group" && <div className="card p-0 overflow-auto"><table className="tbl"><thead><tr><th className="pl-3">Luật</th><th>Mức</th><th className="text-right">Số lần</th><th className="text-right">Chưa xử lý</th><th>Lần cuối</th><th>Nội dung gần nhất</th></tr></thead><tbody>{(grouped.rows ?? []).map((g, i) => <tr key={i} className={Number(g.open) ? (g.level === "DO" ? "bg-red-50" : "bg-amber-50") : ""}><td className="pl-3 font-bold">{String(g.rule_code)}</td><td><span className={LV(String(g.level))}>{String(g.level)}</span></td><td className="text-right">{String(g.n)}</td><td className="text-right font-bold">{String(g.open)}</td><td className="text-sm">{fmt.dt(g.last_ts)}</td><td className="text-sm">{String(g.last_subject ?? "").slice(0, 90)}</td></tr>)}</tbody></table><div className="text-xs text-stone-500 px-3 py-2">Ở quy mô lớn xem theo luật trước; mở tab "Chưa xử lý" để ack từng cái. Cảnh báo lặp mỗi đêm (RC) không tràn màn.</div></div>}
      {tab !== "group" && <div className="space-y-2">{(rows ?? []).map((a) => <div key={String(a.id)} className={`card flex items-start gap-3 ${a.level === "DO" ? "border-red-400" : a.level === "VANG" ? "border-amber-300" : ""}`}><span className={LV(String(a.level))}>{String(a.level)}</span><div className="flex-1"><div className="font-semibold">{String(a.rule_code)} · {String(a.subject)}</div><div className="text-xs text-stone-500">{fmt.dt(a.ts)} {a.acked_by ? `· đã nhận ${String(a.acked_by)} ${fmt.dt(a.acked_at)}` : ""}</div></div>{!a.acked_by && <button className="btn-primary !py-1 !px-3 !text-sm" onClick={async () => { await act("ack_alert", { id: a.id }); open.reload(); all.reload(); }}>Đã nhận</button>}</div>)}{!rows?.length && <div className="card text-stone-500">Không có cảnh báo.</div>}</div>}
    </div>);
}

export function SopPanel({ code }: { code?: string }) {
  const sops = useData("sops"); const one = useData(code ? "sop" : null, { code });
  if (code) { const v = one.rows?.[0]; if (!v) return <div className="card">Đang tải…</div>;
    return (<div className="card space-y-2"><Link href="/sop" className="underline text-sm">← Thư viện</Link><h2 className="text-2xl font-bold">{String(v.code)} · {String(v.title)} <span className="b-gray">v{String(v.version)} {String(v.status)}</span></h2>
      <div className="grid sm:grid-cols-2 gap-2 text-sm"><div><b>Mục đích:</b> {String(v.purpose ?? "")}</div><div><b>Người được làm:</b> {String(v.allowed_roles ?? "")}</div><div><b>Công cụ:</b> {String(v.tools ?? "")}</div><div><b>Tần suất:</b> {String(v.frequency ?? "")}</div></div>
      <ol className="list-decimal pl-6 space-y-1">{((v.steps as { n: number; a: string }[]) ?? []).map((s) => <li key={s.n}>{s.a}</li>)}</ol>
      <div className="grid sm:grid-cols-2 gap-2 text-sm"><div><b>Chuẩn ĐẠT:</b> {String(v.pass_criteria ?? "")}</div><div><b>Lỗi thường gặp:</b> {String(v.common_errors ?? "")}</div><div><b>Bằng chứng:</b> {String(v.evidence ?? "")}</div><div><b>An toàn:</b> {String(v.safety ?? "")}</div><div><b>Điều khoản chuẩn (trường 11):</b> {String(v.std_clause ?? "")}</div><div><b>Ký:</b> {String(v.signed_by ?? "chưa")} · rà hạn {fmt.d(v.review_due)}</div></div>
      {v.video_url ? <a className="underline" href={String(v.video_url)}>▶ Video ≤5'</a> : null}</div>); }
  return (<div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">Thư viện SOP (chuẩn 10+1 trường) — không SOP ký = không giao việc</div><table className="tbl"><thead><tr><th className="pl-3">Mã</th><th>Tên</th><th>Bộ phận</th><th>Chuỗi/L2</th><th>Phiên bản</th><th>Rà hạn</th><th>Trạng thái</th></tr></thead><tbody>{(sops.rows ?? []).map((s) => <tr key={String(s.code)}><td className="pl-3 font-mono"><Link className="underline" href={`/sop/${s.code}`}>{String(s.code)}</Link></td><td>{String(s.title)}</td><td>{String(s.dept)}</td><td className="text-sm">{String(s.l2_group ?? "")}</td><td>{s.version ? `v${s.version}` : "—"}</td><td className={s.review_due && new Date(String(s.review_due)) < new Date(Date.now() + 30 * 86400e3) ? "text-amber-700" : ""}>{fmt.d(s.review_due)}</td><td><span className={s.status === "BAN_HANH" ? "b-grn" : "b-yel"}>{String(s.status)}</span></td></tr>)}</tbody></table></div>);
}

export function BanHangPanel({ sess }: { sess: Sess }) {
  const sales = useData("sales_recent"); const recv = useData("receivables"); const price = useData("price_list");
  const animals = useData("animals"), groups = useData("animal_groups"), warehouses = useData("warehouses"), products = useData("products"), plots = useData("plots"), recipes = useData("recipes"), locations = useData("locations"), sops = useData("sops"), devices = useData("devices"), partners = useData("partners");
  const ref: Ref | null = useMemo(() => animals.rows && groups.rows && warehouses.rows && products.rows && plots.rows && recipes.rows && locations.rows && sops.rows && devices.rows && partners.rows ? { animals: animals.rows, groups: groups.rows, warehouses: warehouses.rows, products: products.rows, plots: plots.rows, recipes: recipes.rows, locations: locations.rows, sops: sops.rows, devices: devices.rows, partners: partners.rows } : null, [animals.rows, groups.rows, warehouses.rows, products.rows, plots.rows, recipes.rows, locations.rows, sops.rows, devices.rows, partners.rows]);
  const forms = ref ? buildForms(ref, sess.farmId) : null;
  const floor = (sku: string) => price.rows?.find((p) => p.kind === "SAN" && p.subject === sku)?.price;
  const byChannel = useMemo(() => { const m: Record<string, number> = {}; for (const s of sales.rows ?? []) m[String(s.channel)] = (m[String(s.channel)] ?? 0) + Number(s.amount); return m; }, [sales.rows]);
  const tot = Object.values(byChannel).reduce((a, b) => a + b, 0);
  return (
    <div className="space-y-3">
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">{[1, 2, 3, 4, 5].map((c) => <KpiTile key={c} l={`Kênh ${c}`} v={tot ? `${Math.round((100 * (byChannel[String(c)] ?? 0)) / tot)}%` : "—"} sub={fmt.vnd(byChannel[String(c)] ?? 0)} warn={tot && (byChannel[String(c)] ?? 0) / tot > 0.4 ? "yel" : null} />)}</div>
      <div className="text-xs text-stone-500">Luật: không kênh nào &gt;40% doanh thu một SKU · ≥70% sản lượng có hợp đồng trước · công nợ ≤15 ngày, &gt;30 ngày ngừng giao · giá sàn (bảng giá SAN) — bán dưới sàn cần GĐ duyệt.</div>
      {forms && ["worker","team_lead","director","accountant"].includes(sess.role) && <ThreeTap spec={{ ...forms.sale, onDone: () => { sales.reload(); recv.reload(); } }} />}
      <div className="grid md:grid-cols-2 gap-3">
        <div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">Bán gần đây</div><table className="tbl"><thead><tr><th className="pl-3">Lúc</th><th>Khách</th><th>SKU</th><th className="text-right">SL</th><th className="text-right">Giá</th><th className="text-right">Tiền</th><th>Kênh</th><th>TT</th></tr></thead><tbody>{(sales.rows ?? []).map((s) => <tr key={String(s.id)} className={floor(String(s.sku)) && Number(s.price) < Number(floor(String(s.sku))) ? "bg-red-50" : ""}><td className="pl-3">{fmt.dt(s.ts)}</td><td>{String(s.partner_name)}</td><td className="text-xs">{String(s.sku)}</td><td className="text-right">{fmt.n(s.qty)}</td><td className="text-right">{fmt.vnd(s.price)}{floor(String(s.sku)) && Number(s.price) < Number(floor(String(s.sku))) ? <span className="b-red ml-1">dưới sàn</span> : null}</td><td className="text-right font-bold">{fmt.vnd(s.amount)}</td><td>{String(s.channel)}</td><td>{s.paid ? <span className="b-grn">{String(s.payment)}</span> : <span className="b-yel">nợ</span>}</td></tr>)}</tbody></table></div>
        <div className="card"><h3 className="font-bold">Công nợ</h3><table className="tbl"><tbody>{(recv.rows ?? []).map((r) => <tr key={String(r.id)}><td>{String(r.name)}</td><td className="text-right">{fmt.vnd(r.unpaid)}</td><td className={Number(r.days) > 30 ? "text-red-700 font-bold" : Number(r.days) > 15 ? "text-amber-700" : ""}>{String(r.days)} ngày {Number(r.days) > 30 && "· NGỪNG GIAO"}</td></tr>)}</tbody></table>
          <h3 className="font-bold mt-3">Bảng giá tham chiếu</h3><table className="tbl"><tbody>{(price.rows ?? []).map((p) => <tr key={String(p.id)}><td>{String(p.kind)}</td><td>{String(p.subject)}</td><td className="text-right">{fmt.vnd(p.price)}</td><td className="text-xs">{String(p.unit ?? "")} · {String(p.source ?? "")}</td></tr>)}</tbody></table></div>
      </div>
    </div>);
}

export function TracePanel({ lot: initial }: { lot?: string }) {
  const [lot, setLot] = useState(initial ?? ""); const [q, setQ] = useState(initial ?? "");
  const tree = useData(q ? "trace_lot" : null, { lot: q }); const cust = useData(q ? "trace_customers" : null, { lot: q }); const l = useData(q ? "lot" : null, { lot: q });
  const [recall, setRecall] = useState<{ start: number; end?: number } | null>(null);
  const back = (tree.rows ?? []).filter((r) => r.dir === "BACK"), fwd = (tree.rows ?? []).filter((r) => r.dir === "FWD");
  return (
    <div className="space-y-3">
      <div className="card flex flex-wrap gap-2 items-center"><input className="input flex-1 !min-w-[260px]" placeholder="Mã lô / mã mẻ (F01-LOT-… hoặc F01-ME-…)" value={lot} onChange={(e) => setLot(e.target.value)} /><button className="btn-primary !py-2" onClick={() => { setQ(lot.trim()); setRecall({ start: Date.now() }); }}>Truy xuất 2 chiều</button>{q && <a className="btn-secondary !py-2" href={`/api/exports/epcis?lot=${encodeURIComponent(q)}`} target="_blank">EPCIS 2.0 JSON-LD</a>}</div>
      {q && (<div className="grid md:grid-cols-3 gap-3">
        <div className="card"><h3 className="font-bold">Lô</h3>{l.rows?.[0] ? <div className="text-sm">{String(l.rows[0].product_name)}<br />lô {String(l.rows[0].lot_no)} · NCC {String(l.rows[0].supplier_id ?? "nội bộ")}<br />hạn {fmt.d(l.rows[0].expiry_date)} · <span className={l.rows[0].status === "KHA_DUNG" ? "b-grn" : "b-red"}>{String(l.rows[0].status)}</span></div> : <div className="text-stone-500 text-sm">Không thấy trong bảng lots (có thể là mã mẻ).</div>}</div>
        <div className="card"><h3 className="font-bold">← 1 bước lùi (nguyên liệu)</h3><ul className="text-sm">{back.map((r, i) => <li key={i}>{"—".repeat(Number(r.depth))} {String(r.input_lot)} <span className="text-stone-500">(mẻ {String(r.batch_code)})</span></li>)}{!back.length && <li className="text-stone-500">Không có mẻ dùng lô này làm đầu ra.</li>}</ul></div>
        <div className="card"><h3 className="font-bold">→ 1 bước tiến (sản phẩm · khách)</h3><ul className="text-sm">{fwd.map((r, i) => <li key={i}>{"—".repeat(Number(r.depth))} {String(r.output_lot)} <span className="text-stone-500">(mẻ {String(r.batch_code)})</span></li>)}</ul><h4 className="font-semibold mt-2">Khách đã nhận lô này</h4><ul className="text-sm">{(cust.rows ?? []).map((c, i) => <li key={i}>{fmt.dt(c.ts)} · <b>{String(c.name)}</b> {String(c.phone ?? "")} · {fmt.n(c.qty)} {String(c.unit ?? "")}</li>)}{!cust.rows?.length && <li className="text-stone-500">Chưa bán lô này.</li>}</ul>
          {recall && cust.rows && <div className="mt-2 text-xs text-stone-500">Mock recall: danh sách khách nhận trong {((Date.now() - recall.start) / 1000).toFixed(1)}s (chuẩn ≤ 4h).</div>}</div>
      </div>)}
    </div>);
}

const Q = ({ q, v, ok }: { q: string; v: React.ReactNode; ok: boolean }) => <div className={`card ${ok ? "" : "border-red-300 bg-red-50"}`}><div className="text-sm">{q}</div><div className="text-2xl font-bold">{v}</div></div>;
export function SucKhoePanel({ sess }: { sess: Sess }) {
  const g = useData("governance"); const r = g.rows?.[0] as Record<string, unknown> | undefined;
  const hist = (r?.hour_hist as { h: number; n: number }[] | null) ?? []; const byStaff = (r?.by_staff as { name: string; n: number }[] | null) ?? [];
  const rows = hist.flatMap((x) => Array.from({ length: Number(x.n) }, () => ({ ts: new Date(2026, 0, 1, Number(x.h)).toISOString() })));
  return (
    <div className="space-y-4">
      <p className="text-sm text-stone-600">7 bộ câu chất vấn (chủ đầu tư/GĐ/kế toán hỏi định kỳ). Số đỏ = phải xử lý.</p>
      <h3 className="font-bold">Bộ 1 · Nền có đúng không</h3>
      <div className="grid sm:grid-cols-3 gap-2"><Q q="Thêm trại F02 có phải sửa code?" v={`Không — ${String(r?.farms_total ?? "…")} trại trong bảng farms`} ok /><Q q="Đổi giờ cữ ăn/ngưỡng phải sửa code?" v={`Không — bảng settings (${String(r?.farm_setting_overrides ?? 0)} ghi đè theo trại)`} ok /><Q q="Có bản ghi nào bị UPDATE/DELETE?" v="Không — trigger chặn ở DB, chỉ supersede/void" ok /></div>
      <div className="grid sm:grid-cols-3 gap-2"><Q q="Rút toàn bộ dữ liệu 1 lệnh?" v={<a className="underline" href="/api/exports/all">/api/exports/all (ZIP)</a>} ok /><Q q="Dựng lại trên Postgres trắng 1 buổi?" v="pnpm db:migrate (7 migration) — diễn tập quý" ok /><Q q="Tính năng mới chỉ ra được ai ghi/bao nhiêu/RC nào?" v="Bắt buộc trong DoD" ok /></div>
      <h3 className="font-bold">Bộ 2 · Số có tin được không (thứ 6)</h3>
      <div className="grid sm:grid-cols-3 gap-2"><Q q="RC lệch treo >48h chưa ai xem" v={String(r?.rc_hanging_48h ?? "…")} ok={Number(r?.rc_hanging_48h ?? 0) === 0} /><Q q="Phiếu giấy >24h chưa số hóa" v={String(r?.paper_late ?? "…")} ok={Number(r?.paper_late ?? 0) === 0} /><Q q="Số bấm 2 lần ra bản ghi gốc + tên người ghi?" v="Đàn → sự kiện → người ghi; Kho → thẻ kho" ok /></div>
      <h3 className="font-bold">Bộ 3 · Công nhân có dùng thật không (tháng)</h3>
      <div className="grid sm:grid-cols-3 gap-2"><Q q="% nhập bù (sự kiện vật nuôi / cho ăn) 30 ngày" v={`${String(r?.backfill_pct_animal ?? 0)}% / ${String(r?.backfill_pct_feed ?? 0)}%`} ok={Number(r?.backfill_pct_animal ?? 0) <= 5 && Number(r?.backfill_pct_feed ?? 0) <= 5} /><Q q="Công nhân 7 ngày không ghi gì (quay lại sổ giấy riêng?)" v={String(r?.workers_silent_7d ?? "…")} ok={Number(r?.workers_silent_7d ?? 0) === 0} /><div className="card"><div className="text-sm">Giờ ghi 7 ngày: rải theo ca hay dồn cục cuối ngày (ghi hồi ký)?</div><HourHistogram rows={rows} /><div className="text-xs text-stone-500">0h → 23h</div></div></div>
      <div className="card"><div className="text-sm font-semibold">Bản ghi 7 ngày theo người</div><div className="flex flex-wrap gap-2 mt-1">{byStaff.map((s) => <span key={s.name} className="b-gray">{s.name}: {s.n}</span>)}</div></div>
      <h3 className="font-bold">Bộ 5 · Tiền có khớp không (kế toán) — 4 số phải bằng 0</h3>
      <div className="grid sm:grid-cols-4 gap-2"><Q q="Chi >20tr thiếu chữ ký thứ 2" v={String(r?.expense_missing_sig ?? "…")} ok={Number(r?.expense_missing_sig ?? 0) === 0} /><Q q="Nhập mua không có PO duyệt (30 ngày)" v={String(r?.receipts_without_po ?? "…")} ok={Number(r?.receipts_without_po ?? 0) === 0} /><Q q="Bán dưới giá sàn (30 ngày)" v={String(r?.sales_below_floor ?? "…")} ok={Number(r?.sales_below_floor ?? 0) === 0} /><Q q="Khách nợ >30 ngày vẫn được giao (7 ngày)" v={String(r?.delivered_to_overdue ?? "…")} ok={Number(r?.delivered_to_overdue ?? 0) === 0} /></div>
      <h3 className="font-bold">Bộ 4 · 6 · 7</h3>
      <div className="grid sm:grid-cols-3 gap-2 text-sm"><div className="card"><b>Mất thứ X thì sao (diễn tập quý)</b><ul className="list-disc pl-5"><li>Mất mạng 3 ngày: app ghi offline (hàng đợi), phiếu giấy BM01–10</li><li>Mất điện thoại: thu hồi phiên (Tài khoản → thu hồi)</li><li>DB sập: restore backup + <code>pnpm db:migrate</code></li><li>Mất dev: repo + 7 migration + CLAUDE.md dựng lại</li></ul></div><div className="card"><b>Phần mềm có đi trước trại không (tháng)</b><ul className="list-disc pl-5"><li>Module &lt;10 bản ghi/ngày đang xây? → xem bảng người ghi ở trên</li><li>Connector chỉ mở khi có doanh thu thật (luật file 05 §6b)</li></ul></div><div className="card"><b>Sẵn sàng audit & nhân rộng</b><ul className="list-disc pl-5"><li><a className="underline" href="/audit">Gói audit 24h</a> — thử thật</li><li><a className="underline" href="/truy-xuat">Mock recall</a> — đo giây</li><li>Thế số F02: thêm dòng farms + Phụ lục</li></ul></div></div>
      <div className="text-xs text-stone-500">Trại {sess.farmId} · dữ liệu tính trực tiếp từ bảng sự kiện.</div>
    </div>);
}
