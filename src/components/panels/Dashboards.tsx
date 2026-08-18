"use client";
import { useState } from "react";
import Link from "next/link";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";

export function KpiTile({ l, v, sub, warn }: { l: string; v: React.ReactNode; sub?: React.ReactNode; warn?: "red" | "yel" | null }) {
  return <div className={`kpi ${warn === "red" ? "border-red-300 bg-red-50" : warn === "yel" ? "border-amber-300 bg-amber-50" : ""}`}><div className="l">{l}</div><div className="v">{v}</div>{sub && <div className="text-xs text-stone-600">{sub}</div>}</div>;
}
const lvl = (d: number | null | undefined, y: number, r: number) => (d == null ? null : d < r ? "red" : d < y ? "yel" : null);

/** GĐ · 1 trang thứ 6 + đỏ + tiền + việc */
export function GdPanel({ sess }: { sess: Sess }) {
  const w = useData("weekly_one_page"); const kpiC = useData("kpi_conception"); const kpiW = useData("kpi_weaned"); const feedAcc = useData("kpi_feed_accuracy"); const lay = useData("kpi_lay_rate");
  const alerts = useData("alerts_open"); const recon = useData("recon_latest"); const tasks = useData("tasks_today"); const recv = useData("receivables"); const exp = useData("expense_requests"); const inc = useData("incidents_open");
  const [busy, setBusy] = useState(false);
  const o = w.rows?.[0] as Record<string, Record<string, unknown> | null> | undefined;
  const bal = o?.balance, sil = o?.silage, herd = o?.herd;
  const reds = (alerts.rows ?? []).filter((a) => a.level === "DO"); const overdue = (tasks.rows ?? []).filter((t) => new Date(String(t.due_at)) < new Date());
  const pendingExp = (exp.rows ?? []).filter((e) => ["CHO_DUYET","DUYET_1"].includes(String(e.status)));
  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <span className="text-stone-600">Trại <b>{sess.farmId}</b> · {new Date().toLocaleDateString("vi-VN", { weekday: "long", day: "2-digit", month: "2-digit" })}</span>
        <button className="btn-secondary !py-1 !px-3 !text-sm ml-auto" disabled={busy} onClick={async () => { setBusy(true); await fetch(`/api/jobs/all?farm=${sess.farmId}`, { method: "POST" }); setBusy(false); alerts.reload(); recon.reload(); tasks.reload(); }}>{busy ? "Đang chạy…" : "▶ Chạy đối soát + cảnh báo + việc ngay"}</button>
        <a className="btn-secondary !py-1 !px-3 !text-sm" href={`/api/exports/audit-pack?from=${new Date(Date.now() - 7 * 86400e3).toISOString().slice(0, 10)}&to=${new Date().toISOString().slice(0, 10)}`}>⬇ Hồ sơ audit 7 ngày</a>
      </div>
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
        <KpiTile l="Cảnh báo ĐỎ chưa xử lý" v={reds.length} warn={reds.length ? "red" : null} sub={<Link className="underline" href="/canh-bao">xem</Link>} />
        <KpiTile l="Ngày-tồn ủ chua" v={sil?.days_silage != null ? fmt.n(sil.days_silage) : "—"} warn={lvl(sil?.days_silage as number, 45, 30)} sub="≥60 · vàng 45 · đỏ 30" />
        <KpiTile l="Sổ đàn K8" v={`${fmt.n(herd?.head_count)} con`} sub={fmt.vnd(herd?.value)} />
        <KpiTile l="Doanh thu tuần" v={fmt.vnd(o?.revenue_week)} sub={`Công nợ: ${fmt.vnd(o?.receivable)}`} />
        <KpiTile l="Đậu thai/phối 12th" v={kpiC.rows?.[0]?.conception_pct != null ? `${fmt.n(kpiC.rows[0].conception_pct)}%` : "—"} warn={lvl(kpiC.rows?.[0]?.conception_pct as number, 55, 45)} sub="≥55%" />
        <KpiTile l="Bê cai sữa/nái" v={kpiW.rows?.[0]?.weaned_per_dam != null ? fmt.n(kpiW.rows[0].weaned_per_dam, 2) : "—"} warn={lvl(kpiW.rows?.[0]?.weaned_per_dam as number, 0.8, 0.75)} sub="≥0,85" />
        <KpiTile l="Sai số mẻ TMR (hôm nay)" v={feedAcc.rows?.[0]?.err_pct != null ? `${fmt.n(feedAcc.rows[0].err_pct, 1)}%` : "—"} warn={feedAcc.rows?.[0]?.err_pct != null && Number(feedAcc.rows[0].err_pct) > 2 ? "yel" : null} sub="≤2%" />
        <KpiTile l="Tỷ lệ đẻ gà (hôm qua)" v={lay.rows?.[0]?.lay_pct != null ? `${fmt.n(lay.rows[0].lay_pct, 1)}%` : "—"} warn={lay.rows?.[0]?.lay_pct != null && Number(lay.rows[0].lay_pct) < 78 ? "yel" : null} sub="≥78%" />
        <KpiTile l="Việc quá hạn" v={overdue.length} warn={overdue.length ? "yel" : null} sub={`${tasks.rows?.length ?? 0} việc đến hạn`} />
        <KpiTile l="Đối soát lệch (kỳ gần nhất)" v={(recon.rows ?? []).filter((r) => ["DO","VANG"].includes(String(r.status))).length} warn={(recon.rows ?? []).some((r) => r.status === "DO") ? "red" : (recon.rows ?? []).some((r) => r.status === "VANG") ? "yel" : null} sub={<Link className="underline" href="/doi-soat">RC1–RC12</Link>} />
        <KpiTile l="Chi chờ duyệt" v={pendingExp.length} sub={fmt.vnd(pendingExp.reduce((a, e) => a + Number(e.amount), 0))} />
        <KpiTile l="Sự cố mở" v={inc.rows?.length ?? "—"} warn={(inc.rows ?? []).some((i) => ["CAO","NGHIEM_TRONG"].includes(String(i.severity))) ? "red" : null} />
      </div>
      <div className="card"><h3 className="font-bold">6 dòng cân bằng vật chất tuần này (kg)</h3>
        <div className="grid grid-cols-2 sm:grid-cols-6 gap-2 mt-2 text-center">
          {[["Sinh khối vào (ruộng)", bal?.biomass_in_kg], ["Mua ngoài (K2)", bal?.purchased_in_kg], ["Thức ăn tiêu thụ", bal?.feed_used_kg], ["Sản phẩm ra", bal?.products_out_kg], ["Phân sinh ra (ước)", bal?.manure_est_kg], ["Phân xử lý → hữu cơ ra", `${fmt.n(bal?.manure_treated_kg)} → ${fmt.n(bal?.organic_out_kg)}`]].map(([l, v]) => <div key={String(l)} className="rounded-xl bg-stone-50 p-2"><div className="text-xs text-stone-500">{String(l)}</div><div className="font-bold text-lg">{typeof v === "string" ? v : fmt.n(v)}</div></div>)}
        </div><div className="text-xs text-stone-500 mt-1">Dòng không nơi nhận = rò rỉ tiền (rà thứ 6). Phân sinh ra = đàn × định mức 15 kg/con/ngày (NORM).</div></div>
      <div className="grid md:grid-cols-2 gap-3">
        <div className="card"><h3 className="font-bold">Đỏ trong tuần</h3><ul className="text-sm mt-1 space-y-1">{((o?.red_week as unknown as Record<string, unknown>[] | null) ?? []).map((a, i) => <li key={i} className="border-l-4 border-red-500 pl-2">{fmt.dt(a.ts)} · <b>{String(a.rule_code)}</b> {String(a.subject ?? "")}</li>)}{!(o?.red_week as unknown as unknown[] | null)?.length && <li className="text-stone-500">Không có đỏ 7 ngày qua</li>}</ul></div>
        <div className="card"><h3 className="font-bold">Đề nghị chi chờ duyệt (2 chữ ký &gt;20tr · SMS chủ &gt;50tr)</h3>
          {pendingExp.map((e) => <div key={String(e.id)} className="flex items-center gap-2 border-b py-1 text-sm"><span className="font-mono">{String(e.id)}</span><span className="flex-1">{String(e.purpose)} · {String(e.by_name)}</span><b>{fmt.vnd(e.amount)}</b><span className="b-gray">{String(e.status)}</span>{["team_lead","tech_head","director","owner"].includes(sess.role) && <button className="btn-primary !py-1 !px-2 !text-sm" onClick={async () => { const j = await act("approve_expense", { id: e.id, approve: true }); alert(j.error ? j.error : `→ ${j.status}${j.note ? " · " + j.note : ""}${j.sms_owner ? " · SMS chủ đầu tư" : ""}`); exp.reload(); }}>Ký</button>}</div>)}
          {!pendingExp.length && <div className="text-stone-500 text-sm">Không có</div>}
          <ExpenseForm onDone={() => exp.reload()} /></div>
        <div className="card"><h3 className="font-bold">Công nợ theo khách</h3><table className="tbl"><tbody>{(recv.rows ?? []).map((r) => <tr key={String(r.id)}><td>{String(r.name)}</td><td className="text-right">{fmt.vnd(r.unpaid)}</td><td className={Number(r.days) > 30 ? "text-red-700 font-bold" : Number(r.days) > 15 ? "text-amber-700" : ""}>{String(r.days)} ngày</td></tr>)}</tbody></table></div>
        <div className="card"><h3 className="font-bold">Sự cố tuần</h3><ul className="text-sm">{((o?.incidents_week as unknown as Record<string, unknown>[] | null) ?? []).map((i, k) => <li key={k}>{fmt.dt(i.ts)} · <b>{String(i.code)}</b> {String(i.kind)}/{String(i.severity)}: {String(i.description)}</li>)}</ul></div>
      </div>
    </div>);
}
function ExpenseForm({ onDone }: { onDone: () => void }) {
  const [amt, setAmt] = useState(""); const [p, setP] = useState(""); const [cc, setCc] = useState("");
  return <div className="flex flex-wrap gap-2 mt-2"><input className="input !w-40" type="number" placeholder="Số tiền" value={amt} onChange={(e) => setAmt(e.target.value)} /><input className="input !w-32" placeholder="CC-BO…" value={cc} onChange={(e) => setCc(e.target.value)} /><input className="input flex-1 !min-w-[200px]" placeholder="Mục đích chi" value={p} onChange={(e) => setP(e.target.value)} /><button className="btn-secondary !py-2" onClick={async () => { if (!amt || !p) return; await act("create_expense", { amount: Number(amt), purpose: p, cost_center: cc || null }); setAmt(""); setP(""); onDone(); }}>Đề nghị chi</button></div>;
}

/** KTT · duyệt & đối chiếu chéo */
export function KttPanel({ sess }: { sess: Sess }) {
  const alerts = useData("alerts_open"); const recon = useData("recon_latest"); const adj = useData("adjustments_pending"); const cl = useData("checklist_today"); const feed = useData("feed_today"); const po = useData("purchase_orders"); const recent = useData("events_recent");
  const pendingPO = (po.rows ?? []).filter((p) => p.po_status === "CHO_DUYET");
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
        <KpiTile l="Đỏ đêm qua / chưa xử lý" v={(alerts.rows ?? []).filter((a) => a.level === "DO").length} warn={(alerts.rows ?? []).some((a) => a.level === "DO") ? "red" : null} />
        <KpiTile l="RC lệch kỳ gần nhất" v={(recon.rows ?? []).filter((r) => ["DO","VANG"].includes(String(r.status))).length} />
        <KpiTile l="Điều chỉnh tồn chờ duyệt" v={adj.rows?.length ?? 0} />
        <KpiTile l="Checklist ca hôm nay" v={`${(cl.rows ?? []).filter((c) => c.all_green).length}/${cl.rows?.length ?? 0} xanh`} sub={`${(cl.rows ?? []).filter((c) => !c.approved_by).length} chờ duyệt`} />
      </div>
      <div className="grid md:grid-cols-2 gap-3">
        <div className="card"><h3 className="font-bold">Duyệt checklist ca (không tự duyệt của mình)</h3>{(cl.rows ?? []).map((c) => <div key={String(c.id)} className="flex items-center gap-2 border-b py-1 text-sm"><b>{String(c.sop_code)}</b><span>{String(c.shift)}</span><span className={c.all_green ? "b-grn" : "b-yel"}>{c.all_green ? "xanh hết" : "có bước không đạt"}</span><span className="flex-1 text-stone-500">{String(c.created_by)} {String(c.note ?? "")}</span>{c.approved_by ? <span className="b-gray">đã duyệt</span> : <button className="btn-primary !py-1 !px-2 !text-sm" onClick={async () => { const j = await act("approve_checklist", { id: c.id }); if (j.error) alert(j.error); cl.reload(); }}>Duyệt</button>}</div>)}{!cl.rows?.length && <div className="text-stone-500 text-sm">Chưa có checklist hôm nay</div>}</div>
        <div className="card"><h3 className="font-bold">Đối chiếu chéo: cho ăn hôm nay (cân xe vs kế hoạch)</h3><table className="tbl"><thead><tr><th>Lúc</th><th>Đàn</th><th>Cữ</th><th className="text-right">KH</th><th className="text-right">Thực</th><th>Ảnh</th><th>Người</th></tr></thead><tbody>{(feed.rows ?? []).map((f) => <tr key={String(f.id)}><td>{fmt.dt(f.ts)}</td><td>{String(f.dest_group_id ?? f.dest_location_id ?? "")}</td><td>{String(f.meal ?? "")}</td><td className="text-right">{fmt.n(f.planned_kg)}</td><td className={`text-right font-bold ${f.planned_kg && Math.abs(Number(f.qty_kg) - Number(f.planned_kg)) / Number(f.planned_kg) > 0.02 ? "text-red-700" : ""}`}>{fmt.n(f.qty_kg)}</td><td>{Array.isArray(f.photo_urls) && (f.photo_urls as string[]).length ? "📷" : <span className="text-red-600">thiếu</span>}</td><td className="text-xs">{String(f.by_name)}</td></tr>)}</tbody></table></div>
        <div className="card"><h3 className="font-bold">PO chờ duyệt (nhập kho phải có PO)</h3>{pendingPO.map((p) => <div key={String(p.id)} className="flex items-center gap-2 border-b py-1 text-sm"><span className="font-mono">{String(p.id)}</span><span className="flex-1">{String(p.supplier_name)} · {(p.lines as { sku: string; qty: number }[]).map((l) => `${l.sku}×${l.qty}`).join(", ")}</span><b>{fmt.vnd(p.total)}</b><button className="btn-primary !py-1 !px-2 !text-sm" onClick={async () => { const j = await act("po_status", { id: p.id, status: "DUYET" }); if (j.error) alert(j.error); po.reload(); }}>Duyệt</button></div>)}{!pendingPO.length && <div className="text-stone-500 text-sm">Không có</div>}<PoForm onDone={() => po.reload()} /></div>
        <div className="card"><h3 className="font-bold">Bản ghi gần đây (giờ ghi rải theo ca hay dồn cục?)</h3><HourHistogram rows={recent.rows ?? []} /></div>
      </div>
      <div className="text-sm text-stone-500">Vai {sess.role}: được sửa RECIPE/SOP có phiên bản, duyệt điều chỉnh tồn (trang Kho), kiểm kê đột xuất, không được vừa ghi vừa duyệt cùng bản ghi.</div>
    </div>);
}
function PoForm({ onDone }: { onDone: () => void }) {
  const partners = useData("partners"); const products = useData("products");
  const [sup, setSup] = useState(""); const [sku, setSku] = useState(""); const [qty, setQty] = useState(""); const [price, setPrice] = useState("");
  return <div className="flex flex-wrap gap-2 mt-2"><select className="input !w-48" value={sup} onChange={(e) => setSup(e.target.value)}><option value="">NCC</option>{(partners.rows ?? []).filter((p) => String(p.kind).includes("NCC")).map((p) => <option key={String(p.id)} value={String(p.id)}>{String(p.name)}</option>)}</select><select className="input !w-48" value={sku} onChange={(e) => setSku(e.target.value)}><option value="">Hàng</option>{(products.rows ?? []).map((p) => <option key={String(p.sku)} value={String(p.sku)}>{String(p.name)}</option>)}</select><input className="input !w-24" type="number" placeholder="SL" value={qty} onChange={(e) => setQty(e.target.value)} /><input className="input !w-28" type="number" placeholder="Giá" value={price} onChange={(e) => setPrice(e.target.value)} /><button className="btn-secondary !py-2" onClick={async () => { if (!sup || !sku || !qty) return; await act("create_po", { supplier_id: sup, lines: [{ sku, qty: Number(qty), price: Number(price || 0) }] }); setQty(""); onDone(); }}>Tạo PO</button></div>;
}
export function HourHistogram({ rows }: { rows: Record<string, unknown>[] }) {
  const h = new Array(24).fill(0); for (const r of rows) h[new Date(String(r.ts)).getHours()]++;
  const max = Math.max(1, ...h);
  return <div className="flex items-end gap-0.5 h-24 mt-2">{h.map((v, i) => <div key={i} title={`${i}h: ${v}`} className="flex-1 bg-green-600 rounded-t" style={{ height: `${(v / max) * 100}%` }} />)}</div>;
}

/** HQ · công ty mẹ đa trại */
export function HqPanel() {
  const k = useData("hq_kpis"); const f = useData("farm_summary");
  return (
    <div className="space-y-4">
      <div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">So sánh trại — công ty mẹ ITRAN FARM (bấm vào trại để chuyển ngữ cảnh)</div>
        <table className="tbl"><thead><tr><th className="pl-3">Trại</th><th>Vùng</th><th className="text-right">Đàn</th><th className="text-right">Đậu thai %</th><th className="text-right">Bê/nái</th><th className="text-right">Ngày-tồn ủ</th><th className="text-right">Sai số mẻ %</th><th className="text-right">Đẻ %</th><th className="text-right">Việc quá hạn</th><th className="text-right">Đỏ</th><th className="text-right">Giấy chưa số hóa</th><th className="text-right">DT tháng</th><th className="text-right">Công nợ</th></tr></thead><tbody>
          {(k.rows ?? []).map((r) => { const s = (f.rows ?? []).find((x) => x.id === r.farm_id); return <tr key={String(r.farm_id)}><td className="pl-3 font-bold"><button className="underline" onClick={async () => { await fetch("/api/auth/switch-farm", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ farm_id: r.farm_id }) }); location.href = "/gd"; }}>{String(r.farm_id)}</button><div className="text-xs font-normal text-stone-500">{String(r.name)}</div></td><td>{String(r.region_id ?? "")}</td><td className="text-right">{fmt.n(s?.head_count)}</td><td className="text-right">{r.conception_pct != null ? fmt.n(r.conception_pct) : "—"}</td><td className="text-right">{r.weaned_per_dam != null ? fmt.n(r.weaned_per_dam, 2) : "—"}</td><td className={`text-right ${r.days_silage != null && Number(r.days_silage) < 45 ? "text-amber-700 font-bold" : ""}`}>{r.days_silage != null ? fmt.n(r.days_silage) : "—"}</td><td className="text-right">{r.feed_err_pct != null ? fmt.n(r.feed_err_pct, 1) : "—"}</td><td className="text-right">{r.lay_pct != null ? fmt.n(r.lay_pct, 1) : "—"}</td><td className="text-right">{String(r.overdue_tasks)}</td><td className={`text-right ${Number(r.red_alerts) ? "text-red-700 font-bold" : ""}`}>{String(r.red_alerts)}</td><td className="text-right">{String(r.paper_pending)}</td><td className="text-right">{fmt.vnd(r.revenue_mtd)}</td><td className="text-right">{fmt.vnd(r.receivable)}</td></tr>; })}
        </tbody></table></div>
      <div className="grid md:grid-cols-3 gap-3">
        <div className="card"><h3 className="font-bold">3 quyền không ủy</h3><ul className="text-sm list-disc pl-5"><li>Bổ nhiệm/miễn nhiệm GĐ</li><li>Duyệt vốn lớn ngoài kế hoạch (&gt;100 tr) — nhận SMS mọi giao dịch &gt;50 tr</li><li>Sửa Lớp A</li></ul></div>
        <div className="card"><h3 className="font-bold">Thêm trại mới</h3><p className="text-sm">= thêm 1 dòng <code>farms</code> (mã F0x, vùng, S, K) + nhân sự + phụ lục thế số. Không sửa code. Sandbox F99 để đào tạo.</p><a className="btn-secondary !py-2 !text-sm mt-2 inline-flex" href="/api/exports/all">⬇ Xuất toàn bộ dữ liệu trại hiện tại</a></div>
        <div className="card"><h3 className="font-bold">Chuẩn toàn hệ (ORG)</h3><p className="text-sm">SKU, SOP, KPI, alert, RC, định mức là dữ liệu cấp công ty — trại kế thừa; sửa có phiên bản, đẩy xuống trại ký nhận (SOP_DISTRIBUTION).</p><Link className="underline text-sm" href="/sop">Thư viện SOP →</Link></div>
      </div>
    </div>);
}

/** Audit · chỉ đọc + xuất */
export function AuditPanel({ sess }: { sess: Sess }) {
  const [from, setFrom] = useState(new Date(Date.now() - 30 * 86400e3).toISOString().slice(0, 10)); const [to, setTo] = useState(new Date().toISOString().slice(0, 10));
  const paper = useData("paper_all"); const anchors = useData("audit_anchors");
  const kinds = [["audit-pack", "Hồ sơ audit (ZIP, ≤24h)"], ["all", "Toàn bộ dữ liệu (ZIP CSV + schema + sha256)"], ["tt66", "Hồ sơ chăn nuôi TT 66/2025 (ZIP)"], ["sales-tax", "Bảng kê bán hàng (kế toán/thuế)"], ["purchases", "Bảng kê mua hàng"], ["stock-ledger", "Thẻ kho"], ["stock-balance", "Tồn kho"], ["herd", "Sổ đàn K8"], ["medicine-book", "Sổ thuốc – vaccine – ngưng thuốc"], ["gap-log", "Nhật ký ruộng VietGAP/GlobalG.A.P"], ["recon", "Kết quả đối soát RC"]];
  return (
    <div className="space-y-4">
      <div className="card"><h3 className="font-bold">Trung tâm xuất dữ liệu — cho kiểm toán, cơ quan thuế, cơ quan nông nghiệp, đối tác, chủ đầu tư</h3>
        <div className="flex gap-2 items-center mt-2 flex-wrap"><label>Từ</label><input type="date" className="input !w-44" value={from} onChange={(e) => setFrom(e.target.value)} /><label>đến</label><input type="date" className="input !w-44" value={to} onChange={(e) => setTo(e.target.value)} /><span className="text-sm text-stone-500">trại {sess.farmId}</span></div>
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-2 mt-3">{kinds.map(([k, l]) => <a key={k} className="btn-secondary !py-3 !text-base justify-start" href={`/api/exports/${k}?from=${from}&to=${to}`}>⬇ {l}</a>)}</div>
        <div className="text-xs text-stone-500 mt-2">CSV UTF-8 (BOM, mở Excel được). ZIP kèm MANIFEST sha256 để chứng minh toàn vẹn. EPCIS 2.0 JSON-LD theo lô: <code>/api/exports/epcis?lot=…</code>. Mọi bảng đơn lẻ: <code>/api/exports/table:tên_bảng</code>.</div></div>
      <div className="grid md:grid-cols-2 gap-3">
        <div className="card"><h3 className="font-bold">Neo audit (hash-chain theo ngày)</h3><table className="tbl"><thead><tr><th>Ngày</th><th>Bảng</th><th className="text-right">Số dòng</th><th>Digest</th></tr></thead><tbody>{(anchors.rows ?? []).slice(0, 30).map((a, i) => <tr key={i}><td>{fmt.d(a.day)}</td><td>{String(a.table_name)}</td><td className="text-right">{String(a.row_count)}</td><td className="font-mono text-xs">{String(a.digest).slice(0, 12)}…</td></tr>)}</tbody></table></div>
        <div className="card"><h3 className="font-bold">Đối chiếu giấy–số</h3><div className="text-sm">Phiếu đã chụp: {paper.rows?.length ?? 0} · chưa số hóa: {(paper.rows ?? []).filter((p) => !p.digitized).length}</div><Link className="underline text-sm" href="/giay">Mở màn đối chiếu (ảnh gốc cạnh dữ liệu) →</Link></div>
      </div>
    </div>);
}
