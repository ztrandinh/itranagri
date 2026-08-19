"use client";
import { useState } from "react";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";
import { usePrompt } from "@/components/ui/PromptDialog";
import { BarChart, Bar, XAxis, YAxis, Tooltip, Legend, CartesianGrid, ResponsiveContainer } from "recharts";
type R = Record<string, unknown>;

/** LÃI GỘP THEO ĐƠN (giá vốn từ lô/mẻ) — tab trong Bán hàng */
export function OrderMarginPanel({ sess }: { sess: Sess }) {
  void sess; const m = useData<R>("order_margin"); const rows = m.rows ?? [];
  const tot = rows.reduce((a: { rev: number; cogs: number; gm: number }, r) => ({ rev: a.rev + Number(r.revenue), cogs: a.cogs + Number(r.cogs), gm: a.gm + Number(r.gross_margin) }), { rev: 0, cogs: 0, gm: 0 });
  const chart = rows.slice(0, 20).map((r) => ({ name: String(r.order_key).slice(-6), "Doanh thu": Number(r.revenue), "Giá vốn": Number(r.cogs), "Lãi gộp": Number(r.gross_margin) }));
  return <div className="space-y-3">
    <div className="grid grid-cols-2 md:grid-cols-4 gap-2">{[["Doanh thu (300 đơn)", fmt.vnd(tot.rev)], ["Giá vốn (COGS)", fmt.vnd(tot.cogs)], ["Lãi gộp", fmt.vnd(tot.gm)], ["Tỷ suất lãi gộp", tot.rev ? (100 * tot.gm / tot.rev).toFixed(1) + "%" : "—"]].map(([l, v]) => <div key={String(l)} className="card"><div className="text-xs text-slate-500">{l}</div><div className="text-xl font-black">{String(v)}</div></div>)}</div>
    <div className="card"><div className="text-sm font-bold">20 đơn gần nhất — doanh thu / giá vốn / lãi gộp</div><div style={{ height: 260 }}><ResponsiveContainer><BarChart data={chart}><CartesianGrid strokeDasharray="3 3" /><XAxis dataKey="name" tick={{ fontSize: 9 }} /><YAxis tick={{ fontSize: 9 }} /><Tooltip formatter={(v) => fmt.vnd(v)} /><Legend wrapperStyle={{ fontSize: 11 }} /><Bar dataKey="Doanh thu" fill="#0ea5e9" /><Bar dataKey="Giá vốn" fill="#f59e0b" /><Bar dataKey="Lãi gộp" fill="#059669" /></BarChart></ResponsiveContainer></div></div>
    <div className="card p-0 overflow-auto"><table className="tbl text-sm"><thead><tr><th className="pl-3">Đơn / phiếu</th><th>Ngày</th><th>Kênh</th><th className="text-right">Doanh thu</th><th className="text-right">Giá vốn</th><th className="text-right">Lãi gộp</th><th className="text-right">%</th></tr></thead><tbody>
      {rows.map((r) => <tr key={String(r.order_key)} className={Number(r.margin_pct) < 15 ? "bg-amber-50" : ""}><td className="pl-3 text-xs">{r.order_id ? <a className="underline" href={`/xem/order/${r.order_id}`}>{String(r.order_key).slice(-8)}</a> : String(r.order_key).slice(-8)}</td><td className="text-xs">{fmt.d(r.ts)}</td><td className="text-xs">{String(r.channel_code ?? "")}</td><td className="text-right">{fmt.vnd(r.revenue)}</td><td className="text-right">{fmt.vnd(r.cogs)}</td><td className="text-right font-semibold">{fmt.vnd(r.gross_margin)}</td><td className={`text-right ${Number(r.margin_pct) < 15 ? "text-amber-700 font-bold" : ""}`}>{r.margin_pct == null ? "—" : String(r.margin_pct) + "%"}</td></tr>)}</tbody></table></div>
    <div className="text-xs text-slate-500">Giá vốn lấy từ giá bình quân lô (lots.avg_cost) → giá nhập gần nhất → 0. Đơn tô vàng là lãi gộp &lt; 15% (giá vốn cao hoặc bán dưới giá).</div>
  </div>;
}

/** SAO KÊ NGÂN HÀNG + ĐỐI CHIẾU — tab trong Kế toán */
export function BankReconPanel({ sess }: { sess: Sess }) {
  const b = useData<R>("bank_recon"); const rows = b.rows ?? []; const [msg, setMsg] = useState(""); const [raw, setRaw] = useState("");
  const can = ["owner", "director", "accountant", "it_engineer"].includes(sess.role);
  const matched = rows.filter((r) => r.matched).length; const recon = rows.filter((r) => r.reconciled).length;
  const parseImport = async () => {
    const lines = raw.trim().split("\n").filter(Boolean).map((ln) => { const [txn_date, amount, direction, ref, ...memo] = ln.split(/[,\t;]/).map((x) => x.trim()); return { bank: "NH", account: "STK", txn_date, amount: Number(String(amount).replace(/[^\d.-]/g, "")), direction: direction || (Number(amount) >= 0 ? "IN" : "OUT"), ref, memo: memo.join(" ") }; }).filter((x) => x.txn_date && !isNaN(x.amount));
    if (!lines.length) { setMsg("Không đọc được dòng nào. Định dạng: ngày,số tiền,IN/OUT,mã tham chiếu,diễn giải"); return; }
    const j = await act("import_bank_lines", { lines }); setMsg(j.error ? String(j.error) : `Nhập ${j.imported} dòng · tự khớp ${j.matched}`); setRaw(""); b.reload();
  };
  return <div className="space-y-3">
    <div className="grid grid-cols-2 md:grid-cols-4 gap-2">{[["Dòng sao kê", rows.length], ["Đã khớp", matched], ["Chưa khớp", rows.length - matched], ["Đã đối chiếu", recon]].map(([l, v]) => <div key={String(l)} className="card"><div className="text-xs text-slate-500">{l}</div><div className="text-xl font-black">{String(v)}</div></div>)}</div>
    {can && <div className="card"><div className="font-bold text-sm mb-1">Nhập sao kê (dán từ Excel/CSV: <span className="font-normal text-slate-500">ngày, số tiền (±), IN/OUT, mã tham chiếu, diễn giải</span>)</div>
      <textarea className="input w-full font-mono text-xs" rows={4} placeholder={"2026-08-15,12500000,IN,HD001,Thu tien ban bo\n2026-08-16,-4500000,OUT,PO12,Tra NCC cam"} value={raw} onChange={(e) => setRaw(e.target.value)} />
      <div className="flex gap-2 mt-1 items-center"><button className="btn-primary !py-1.5" onClick={parseImport}>Nhập & tự khớp</button><button className="btn-secondary !py-1.5" onClick={async () => { const j = await act("import_bank_lines", { lines: [] }); setMsg(j.error ? String(j.error) : `Chạy tự khớp lại: ${j.matched}`); b.reload(); }}>Tự khớp lại</button><span className="text-xs text-emerald-800">{msg}</span></div></div>}
    <div className="card p-0 overflow-auto"><table className="tbl text-sm"><thead><tr><th className="pl-3">Ngày</th><th>NH·TK</th><th className="text-right">Số tiền</th><th>Chiều</th><th>Diễn giải</th><th>Khớp với</th><th>Đối chiếu</th></tr></thead><tbody>
      {rows.map((r) => <tr key={String(r.id)} className={r.matched ? "" : "bg-amber-50"}><td className="pl-3 text-xs">{fmt.d(r.txn_date)}</td><td className="text-xs">{String(r.bank)}·{String(r.account)}</td><td className={`text-right ${Number(r.amount) < 0 ? "text-red-700" : "text-emerald-700"}`}>{fmt.vnd(r.amount)}</td><td className="text-xs">{String(r.direction ?? "")}</td><td className="text-xs">{String(r.ref ?? "")} {String(r.memo ?? "")}</td><td className="text-xs">{r.matched ? <span className="b-grn">{String(r.matched_kind)} {String(r.matched_ref ?? "").slice(-6)}</span> : <span className="text-amber-700">chưa</span>}</td><td>{can && <button className={`text-xs underline ${r.reconciled ? "text-slate-400" : "text-emerald-700"}`} onClick={async () => { await act("bank_reconcile", { id: r.id, reconciled: !r.reconciled }); b.reload(); }}>{r.reconciled ? "✓ đã đối chiếu" : "đánh dấu"}</button>}</td></tr>)}</tbody></table></div>
    <div className="text-xs text-slate-500">Tự khớp: tiền VÀO ↔ đơn bán đã thu (số tiền, ±3 ngày); tiền RA ↔ đề nghị chi đã duyệt (số tiền). Dòng chưa khớp tô vàng để kế toán đối chiếu tay.</div>
  </div>;
}

/** KÝ SOP + ĐỌC HIỂU + VIDEO — tab trong Tổ chức */
export function SopSignoffPanel({ sess }: { sess: Sess }) {
  const todo = useData<R>("my_sop_todo"); const so = useData<R>("sop_signoff"); const [msg, setMsg] = useState("");
  const ack = async (code: string) => { const j = await act("ack_sop", { sop_code: code, kind: "DOC_HIEU" }); setMsg(j.error ? String(j.error) : "Đã ký đọc–hiểu SOP " + code); todo.reload(); so.reload(); };
  return <div className="space-y-3">
    <div className="card"><div className="font-bold text-sm mb-1">SOP tôi cần đọc & ký ({(todo.rows ?? []).length})</div>
      {(todo.rows ?? []).length === 0 ? <div className="text-sm text-emerald-700">✓ Đã ký hết SOP phòng mình.</div> : <table className="tbl text-sm"><tbody>{(todo.rows ?? []).map((r) => <tr key={String(r.code)}><td className="pl-3">{String(r.code)}</td><td>{String(r.title)}</td><td>{r.video_url ? <a className="underline text-xs" href={String(r.video_url)} target="_blank" rel="noreferrer">▶ video</a> : ""}</td><td><a className="underline text-xs mr-2" href={`/to-chuc?tab=sop&q=${r.code}`}>đọc</a><button className="btn-primary !py-0.5 !px-2 !text-xs" onClick={() => ack(String(r.code))}>Tôi đã đọc & hiểu</button></td></tr>)}</tbody></table>}
      {msg && <div className="text-xs text-emerald-800 mt-1">{msg}</div>}</div>
    <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-slate-100 rounded-t-xl font-bold">Tỷ lệ ký SOP theo phòng ({(so.rows ?? []).length} SOP ban hành)</div><table className="tbl text-sm"><thead><tr><th className="pl-3">SOP</th><th>Tên</th><th>Phòng</th><th>v</th><th>Video</th><th className="text-right">Đã ký / cần</th></tr></thead><tbody>
      {(so.rows ?? []).map((r) => { const pct = Number(r.need) ? Math.round(100 * Number(r.signed) / Number(r.need)) : 0; return <tr key={String(r.code)} className={pct < 80 ? "bg-amber-50" : ""}><td className="pl-3 text-xs">{String(r.code)}</td><td className="text-xs">{String(r.title)}</td><td className="text-xs">{String(r.dept ?? "")}</td><td className="text-xs">{String(r.version)}</td><td>{r.video_url ? <a className="underline text-xs" href={String(r.video_url)} target="_blank" rel="noreferrer">▶</a> : "—"}</td><td className="text-right text-xs">{String(r.signed)}/{String(r.need)} ({pct}%)</td></tr>; })}</tbody></table></div>
    <div className="text-xs text-slate-500">Người dùng {sess.staffName}: ký đọc–hiểu là bằng chứng đào tạo SOP (bổ sung cho video ≤5' và đào tạo tuần). SOP dưới 80% ký được tô vàng cho HCNS/QA nhắc.</div>
  </div>;
}

/** GIỮ LÔ QC — tab trong D5 & Chế biến */
export function QcHoldPanel({ sess }: { sess: Sess }) {
  const holds = useData<R>("qc_holds"); const lots = useData<R>("lots_sellable"); const [f, setF] = useState<R | null>(null); const [msg, setMsg] = useState("");
  const { prompt, promptElement } = usePrompt();
  const can = ["owner", "director", "tech_head", "team_lead", "auditor", "it_engineer"].includes(sess.role); const canRel = ["owner", "director", "tech_head", "auditor"].includes(sess.role);
  return <div className="space-y-3">
    {promptElement}
    <div className="card flex items-center gap-2 flex-wrap text-sm"><b>Giữ lô QC không đạt</b><span className="text-xs text-slate-500">Lô bị giữ chuyển trạng thái GIỮ_QC → hệ thống CHẶN xuất bán cho tới khi giải tỏa (người giữ ≠ người giải tỏa).</span>
      {can && <button className="btn-primary !py-1 !text-xs ml-auto" onClick={() => setF({ ref: "", reason: "", severity: "TRUNG" })}>＋ Giữ lô</button>}</div>
    {f && <div className="card grid sm:grid-cols-4 gap-2"><select className="input" value={String(f.ref)} onChange={(e) => setF({ ...f, ref: e.target.value })}><option value="">— chọn lô —</option>{(lots.rows ?? []).filter((l) => l.status !== "GIU_QC").map((l) => <option key={String(l.id)} value={String(l.id)}>{String(l.id)} · {String(l.sku)}</option>)}</select><input className="input sm:col-span-2" placeholder="Lý do (kết quả kiểm không đạt)" value={String(f.reason)} onChange={(e) => setF({ ...f, reason: e.target.value })} /><select className="input" value={String(f.severity)} onChange={(e) => setF({ ...f, severity: e.target.value })}>{["NHE", "TRUNG", "NANG"].map((x) => <option key={x}>{x}</option>)}</select><div className="sm:col-span-4 flex gap-2"><button className="btn-primary !py-1" disabled={!f.ref || !f.reason} onClick={async () => { const j = await act("qc_hold", { ref: f.ref, reason: f.reason, severity: f.severity }); setMsg(j.error ? String(j.error) : "Đã giữ lô " + f.ref); setF(null); holds.reload(); lots.reload(); }}>Giữ lô</button><button className="btn-secondary !py-1" onClick={() => setF(null)}>Hủy</button></div></div>}
    {msg && <div className="text-sm text-emerald-800">{msg}</div>}
    <div className="card p-0 overflow-auto"><table className="tbl text-sm"><thead><tr><th className="pl-3">Lô/mẻ</th><th>Lý do</th><th>Mức</th><th>TT</th><th>Người giữ</th><th>Lúc</th><th></th></tr></thead><tbody>
      {(holds.rows ?? []).map((h) => <tr key={String(h.id)} className={h.status === "GIU" ? "bg-red-50" : ""}><td className="pl-3">{String(h.lot_id ?? h.batch_code)}</td><td className="text-xs">{String(h.reason)}</td><td className="text-xs">{String(h.severity)}</td><td className="text-xs">{h.status === "GIU" ? <span className="b-red">đang giữ</span> : <span className="b-gray">{String(h.status)}</span>}{h.disposition ? ` · ${String(h.disposition)}` : ""}</td><td className="text-xs">{String(h.held_by)}</td><td className="text-xs">{fmt.d(h.held_at)}</td><td className="whitespace-nowrap">{h.status === "GIU" && canRel && h.held_by !== sess.staffId && <><button className="btn-primary !py-0.5 !px-2 !text-xs mr-1" onClick={async () => { const d = await prompt({ title: "Giải tỏa lô QC", label: "Kết luận giải tỏa (tái kiểm đạt / lý do)", type: "text", required: false }); if (d === null) return; await act("qc_release", { id: h.id, disposition: d, status: "GIAI_TOA" }); holds.reload(); lots.reload(); }}>Giải tỏa</button><button className="text-xs underline text-red-700" onClick={async () => { const d = await prompt({ title: "Hủy / thu hồi lô", label: "Xử lý (hủy/hạ cấp) — lô sẽ chuyển THU_HOI", type: "text", required: false }); if (!d) return; await act("qc_release", { id: h.id, disposition: d, status: "HUY_BO" }); holds.reload(); lots.reload(); }}>hủy/thu hồi</button></>}</td></tr>)}</tbody></table></div>
  </div>;
}

/** TRẢ HÀNG NHÀ CUNG CẤP — tab trong Mua hàng */
export function SupplierReturnPanel({ sess }: { sess: Sess }) {
  const rets = useData<R>("supplier_returns"); const products = useData<R>("products"); const partners = useData<R>("partners"); const [f, setF] = useState<R | null>(null); const [msg, setMsg] = useState("");
  const canApp = ["owner", "director", "accountant", "tech_head"].includes(sess.role);
  return <div className="space-y-3">
    <div className="card flex items-center gap-2 flex-wrap text-sm"><b>Trả hàng nhà cung cấp (debit note)</b><span className="text-xs text-slate-500">Duyệt → xuất kho (−) + ghi giảm công nợ phải trả (Nợ 331 / Có 156). Người tạo ≠ người duyệt.</span>
      <button className="btn-primary !py-1 !text-xs ml-auto" onClick={() => setF({ supplier_id: "", sku: "", qty: 1, unit_cost: "", amount: "", reason: "", disposition: "TRA_LAI" })}>＋ Phiếu trả</button></div>
    {f && <div className="card grid sm:grid-cols-4 gap-2"><select className="input" value={String(f.supplier_id)} onChange={(e) => setF({ ...f, supplier_id: e.target.value })}><option value="">— NCC —</option>{(partners.rows ?? []).filter((p) => String(p.kind ?? "").includes("NCC") || String(p.role ?? "").includes("SUPP") || true).slice(0, 200).map((p) => <option key={String(p.id)} value={String(p.id)}>{String(p.name)}</option>)}</select><select className="input" value={String(f.sku)} onChange={(e) => setF({ ...f, sku: e.target.value })}><option value="">— hàng —</option>{(products.rows ?? []).map((p) => <option key={String(p.sku)} value={String(p.sku)}>{String(p.name)}</option>)}</select><input className="input" type="number" placeholder="SL" value={String(f.qty)} onChange={(e) => setF({ ...f, qty: e.target.value })} /><input className="input" type="number" placeholder="Đơn giá" value={String(f.unit_cost)} onChange={(e) => { const uc = e.target.value; setF({ ...f, unit_cost: uc, amount: String(Number(uc) * Number(f.qty)) }); }} /><input className="input sm:col-span-3" placeholder="Lý do (hàng lỗi/sai/kém chất lượng)" value={String(f.reason)} onChange={(e) => setF({ ...f, reason: e.target.value })} /><input className="input" type="number" placeholder="Thành tiền" value={String(f.amount)} onChange={(e) => setF({ ...f, amount: e.target.value })} /><div className="sm:col-span-4 flex gap-2"><button className="btn-primary !py-1" disabled={!f.sku || !f.qty} onClick={async () => { const j = await act("supplier_return", f); setMsg(j.error ? String(j.error) : "Đã tạo phiếu trả " + j.id); setF(null); rets.reload(); }}>Tạo phiếu</button><button className="btn-secondary !py-1" onClick={() => setF(null)}>Hủy</button></div></div>}
    {msg && <div className="text-sm text-emerald-800">{msg}</div>}
    <div className="card p-0 overflow-auto"><table className="tbl text-sm"><thead><tr><th className="pl-3">Mã</th><th>NCC</th><th>Hàng</th><th className="text-right">SL</th><th className="text-right">Tiền</th><th>Lý do</th><th>TT</th><th>Debit note</th><th></th></tr></thead><tbody>
      {(rets.rows ?? []).map((r) => <tr key={String(r.id)} className={r.status === "CHO" ? "bg-amber-50" : ""}><td className="pl-3 text-xs">{String(r.id).slice(-8)}</td><td className="text-xs">{String(r.supplier_name ?? "")}</td><td className="text-xs">{String(r.sku)}</td><td className="text-right">{String(r.qty)}</td><td className="text-right">{fmt.vnd(r.amount)}</td><td className="text-xs">{String(r.reason ?? "")}</td><td className="text-xs">{r.status === "CHO" ? <span className="b-yel">chờ duyệt</span> : <span className="b-grn">{String(r.status)}</span>}</td><td className="text-xs">{String(r.debit_note_no ?? "")}</td><td>{r.status === "CHO" && canApp && r.created_by !== sess.staffId && <button className="btn-primary !py-0.5 !px-2 !text-xs" onClick={async () => { const j = await act("approve_supplier_return", { id: r.id }); if (j.error) alert(j.error); rets.reload(); }}>Duyệt</button>}</td></tr>)}</tbody></table></div>
  </div>;
}

/** ĐỊNH BIÊN ↔ QUỸ LƯƠNG KẾ HOẠCH vs THỰC — tab trong Kế hoạch */
export function LaborBudgetPanel({ sess }: { sess: Sess }) {
  const lb = useData<R>("labor_budget"); const [msg, setMsg] = useState(""); const yr = new Date().getFullYear();
  const can = ["owner", "director", "accountant"].includes(sess.role);
  const rows = (lb.rows ?? []).filter((r) => Number(r.budget) > 0 || Number(r.actual) > 0);
  const chart = rows.slice(-12).map((r) => ({ name: fmt.d(r.month).slice(3), "Kế hoạch": Number(r.budget), "Thực chi": Number(r.actual) }));
  return <div className="space-y-3">
    <div className="card flex items-center gap-2 flex-wrap text-sm"><b>Quỹ lương: định biên (kế hoạch) vs thực chi</b><span className="text-xs text-slate-500">Kế hoạch = Σ định biên × lương L1 (từ Nhân sự › Định biên). Thực chi = lương gộp + BH doanh nghiệp (payslips).</span>
      {can && <button className="btn-secondary !py-1 !text-xs ml-auto" onClick={async () => { const j = await act("sync_labor_budget", { year: yr }); setMsg(j.error ? String(j.error) : `Đã ghi quỹ lương ${j.n} tháng vào kế hoạch ${yr}`); lb.reload(); }}>Cập nhật quỹ lương KH {yr}</button>}</div>
    {msg && <div className="text-sm text-emerald-800">{msg}</div>}
    <div className="card"><div style={{ height: 260 }}><ResponsiveContainer><BarChart data={chart}><CartesianGrid strokeDasharray="3 3" /><XAxis dataKey="name" tick={{ fontSize: 10 }} /><YAxis tick={{ fontSize: 9 }} /><Tooltip formatter={(v) => fmt.vnd(v)} /><Legend wrapperStyle={{ fontSize: 11 }} /><Bar dataKey="Kế hoạch" fill="#cbd5e1" /><Bar dataKey="Thực chi" fill="#059669" /></BarChart></ResponsiveContainer></div></div>
    <div className="card p-0 overflow-auto"><table className="tbl text-sm"><thead><tr><th className="pl-3">Tháng</th><th className="text-right">Quỹ KH</th><th className="text-right">Thực chi</th><th className="text-right">Chênh</th><th className="text-right">Số người</th></tr></thead><tbody>
      {rows.map((r) => <tr key={String(r.month)} className={Number(r.variance) > Number(r.budget) * 0.1 ? "bg-red-50" : ""}><td className="pl-3">{fmt.d(r.month).slice(3)}</td><td className="text-right">{fmt.vnd(r.budget)}</td><td className="text-right">{fmt.vnd(r.actual)}</td><td className={`text-right ${Number(r.variance) > 0 ? "text-red-700" : "text-emerald-700"}`}>{fmt.vnd(r.variance)}</td><td className="text-right">{String(r.headcount ?? "—")}</td></tr>)}</tbody></table></div>
    <div className="text-xs text-slate-500">Chênh &gt; 10% quỹ kế hoạch tô đỏ. Vào <a className="underline" href="/nhan-su?tab=bac">Nhân sự › Bậc › Cơ chế lương</a> để chỉnh định biên.</div>
  </div>;
}
