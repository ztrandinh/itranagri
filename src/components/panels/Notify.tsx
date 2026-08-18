"use client";
import { useEffect, useState } from "react";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";

type Noti = { id: string; level: string; title: string; body: string | null; link: string | null; ts: string; read_at: string | null; channels: string[] };
const LV = (l: string) => (l === "DO" ? "b-red" : l === "VANG" || l === "CAM" ? "b-yel" : "b-grn");

/** Chuông + hộp thư (poll 60s; bấm để mở) */
export function Bell() {
  const [n, setN] = useState(0); const [open, setOpen] = useState(false); const [rows, setRows] = useState<Noti[]>([]);
  const load = async () => { try { const j = await fetch("/api/notifications").then((r) => r.json()); setN(j.unread ?? 0); setRows(j.rows ?? []); } catch { /* offline */ } };
  useEffect(() => { void load(); const t = setInterval(load, 60000); return () => clearInterval(t); }, []);
  return (<div className="relative">
    <button className={`rounded-full px-2.5 py-1 text-xs font-semibold ${n ? "bg-red-500 text-white" : "bg-slate-100 text-slate-700"}`} onClick={() => { setOpen(!open); void load(); }} title="Thông báo">🔔 {n || ""}</button>
    {open && <div className="absolute right-0 mt-1 w-[92vw] sm:w-[420px] max-h-[70vh] overflow-auto bg-white text-stone-900 rounded-2xl shadow-xl border z-50 p-2">
      <div className="flex items-center justify-between px-1 pb-1 border-b"><b>Hộp thư của tôi</b><div className="flex gap-2 text-xs"><button className="underline" onClick={async () => { await fetch("/api/notifications", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ all: true }) }); load(); }}>đã đọc hết</button><button className="underline" title="Nhận thông báo nổi trên điện thoại kể cả khi đóng app" onClick={async () => { try { const perm = await Notification.requestPermission(); if (perm !== "granted") return alert("Bạn chưa cho phép thông báo"); const reg = await navigator.serviceWorker.ready; const { key } = await fetch("/api/push").then((r) => r.json()); if (!key) return alert("Máy chủ chưa cấu hình VAPID"); const sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key }); await fetch("/api/push", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ subscription: sub }) }); alert("Đã bật thông báo nổi trên thiết bị này"); } catch (e) { alert("Không bật được: " + (e as Error).message); } }}>🔔 bật push</button><a className="underline" href="/canh-bao?tab=caidat">cài đặt</a></div></div>
      {rows.map((r) => <a key={r.id} href={r.link ?? "#"} className={`block px-2 py-2 border-b hover:bg-stone-50 ${r.read_at ? "opacity-60" : ""}`} onClick={async () => { await fetch("/api/notifications", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ ids: [r.id] }) }); }}><div className="flex items-center gap-2"><span className={LV(r.level)}>{r.level}</span><span className="font-semibold text-sm flex-1">{r.title}</span><span className="text-xs text-stone-500">{fmt.dt(r.ts)}</span></div>{r.body && <div className="text-sm text-stone-600">{r.body.slice(0, 140)}</div>}</a>)}
      {!rows.length && <div className="p-3 text-stone-500 text-sm">Chưa có thông báo.</div>}
    </div>}
  </div>);
}

const RECIP = ["owner", "director", "tech_head", "team_lead", "accountant", "it_engineer", "auditor", "worker:A1", "worker:A2", "worker:A3", "worker:A4", "worker:A5", "worker:A6", "worker:A7", "worker:A8", "worker:A9", "worker:A11", "all"];
const METRICS = [["lay_pct", "Tỷ lệ đẻ 7 ngày (%)"], ["feed_err", "Sai số mẻ TMR 7 ngày (%)"], ["deaths_week", "Số con chết 7 ngày"], ["days_silage", "Ngày-tồn ủ chua"], ["conception_pct", "Đậu thai % 12 tháng"], ["receivable_30", "Công nợ >30 ngày (đ)"], ["red_alerts_open", "Cảnh báo ĐỎ chưa xử lý"], ["agg:harvest_kg", "Thu hoạch 7 ngày (kg)"], ["agg:sales_amount", "Doanh thu 7 ngày (đ)"], ["agg:eggs", "Trứng 7 ngày (quả)"], ["agg:feed_kg", "Thức ăn 7 ngày (kg)"]];

/** Cài đặt cảnh báo: luật cấu hình + người nhận + kênh + sở thích cá nhân */
export function AlertSettings({ sess }: { sess: Sess }) {
  const rules = useData("alert_rules"); const products = useData("products");
  const [f, setF] = useState<Record<string, unknown>>({ type: "stock_days", op: "<", value: 30, level: "VANG", recipients: ["tech_head"], channels: ["app"], cooldown_min: 720, sku: "*", metric: "lay_pct", scope: "FARM" });
  const [prefs, setPrefs] = useState<{ level_min: string; channels: string[]; muted: boolean; quiet_from: string; quiet_to: string }>({ level_min: "XANH", channels: ["app"], muted: false, quiet_from: "", quiet_to: "" });
  const [msg, setMsg] = useState("");
  useEffect(() => { fetch("/api/notifications").then((r) => r.json()).then((j) => { const p = (j.prefs ?? []).find((x: { rule_code: string }) => x.rule_code === "*"); if (p) setPrefs({ level_min: p.level_min, channels: p.channels, muted: p.muted, quiet_from: p.quiet_from ?? "", quiet_to: p.quiet_to ?? "" }); }); }, []);
  const canW = ["tech_head","director","owner","it_engineer"].includes(sess.role);
  const toggle = (arr: string[], v: string) => (arr.includes(v) ? arr.filter((x) => x !== v) : [...arr, v]);
  const t = String(f.type);
  return (
    <div className="space-y-4">
      <div className="card"><h3 className="font-bold">Sở thích nhận thông báo của tôi ({sess.staffName})</h3>
        <div className="flex flex-wrap gap-3 items-center mt-2 text-sm"><label>Mức tối thiểu <select className="input !w-auto !py-1" value={prefs.level_min} onChange={(e) => setPrefs({ ...prefs, level_min: e.target.value })}>{["XANH","VANG","CAM","DO"].map((l) => <option key={l}>{l}</option>)}</select></label>
          <span>Kênh: {["app","zalo","sms","email"].map((c) => <label key={c} className="ml-2"><input type="checkbox" checked={prefs.channels.includes(c)} onChange={() => setPrefs({ ...prefs, channels: toggle(prefs.channels, c) })} /> {c}</label>)}</span>
          <label>Im lặng từ <input type="time" className="input !w-28 !py-1" value={prefs.quiet_from} onChange={(e) => setPrefs({ ...prefs, quiet_from: e.target.value })} /> đến <input type="time" className="input !w-28 !py-1" value={prefs.quiet_to} onChange={(e) => setPrefs({ ...prefs, quiet_to: e.target.value })} /></label>
          <label><input type="checkbox" checked={prefs.muted} onChange={(e) => setPrefs({ ...prefs, muted: e.target.checked })} /> Tắt hết (trừ ĐỎ vẫn báo cấp trên)</label>
          <button className="btn-secondary !py-1 !px-3 !text-sm" onClick={async () => { await fetch("/api/notifications", { method: "PUT", headers: { "content-type": "application/json" }, body: JSON.stringify({ rule_code: "*", ...prefs, quiet_from: prefs.quiet_from || null, quiet_to: prefs.quiet_to || null }) }); setMsg("Đã lưu sở thích"); }}>Lưu</button></div>
        <div className="text-xs text-stone-500 mt-1">Zalo/SMS/email: kênh được xếp hàng (cột sent) — kích hoạt khi có Zalo OA/brandname; app luôn có.</div></div>
      {canW && <div className="card"><h3 className="font-bold">Tạo / sửa luật cảnh báo (không cần code — thêm luật mới bất kỳ lúc nào)</h3>
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-2 mt-2">
          <input className="input" placeholder="Mã luật (AL-…)" value={String(f.code ?? "")} onChange={(e) => setF({ ...f, code: e.target.value.toUpperCase() })} />
          <input className="input lg:col-span-2" placeholder="Tên luật" value={String(f.name ?? "")} onChange={(e) => setF({ ...f, name: e.target.value })} />
          <select className="input" value={t} onChange={(e) => setF({ ...f, type: e.target.value })}><option value="stock_days">Ngày-tồn mặt hàng (kho sắp hết)</option><option value="metric_threshold">Chỉ số vượt/dưới ngưỡng</option><option value="overdue_tasks">Việc quá hạn</option><option value="expand_biomass">Cần mở rộng vùng trồng (ủ chua thấp & đàn tăng)</option><option value="missing_event">Vắng bản ghi trong ngày</option><option value="due">Hiệu chuẩn thiết bị đến hạn</option></select>
          {t === "stock_days" && <select className="input" value={String(f.sku)} onChange={(e) => setF({ ...f, sku: e.target.value })}><option value="*">Mọi mặt hàng</option>{(products.rows ?? []).map((p) => <option key={String(p.sku)} value={String(p.sku)}>{String(p.name)}</option>)}</select>}
          {t === "metric_threshold" && <select className="input" value={String(f.metric)} onChange={(e) => setF({ ...f, metric: e.target.value })}>{METRICS.map(([k, l]) => <option key={k} value={k}>{l}</option>)}</select>}
          {t === "missing_event" && <select className="input" value={String(f.table ?? "feed_logs")} onChange={(e) => setF({ ...f, table: e.target.value })}>{["feed_logs","animal_events","crop_logs","batch_logs","inventory_moves","checklist_runs","gate_logs"].map((x) => <option key={x}>{x}</option>)}</select>}
          {["stock_days","metric_threshold","overdue_tasks"].includes(t) && <select className="input" value={String(f.op)} onChange={(e) => setF({ ...f, op: e.target.value })}>{["<","<=",">",">=","="].map((o) => <option key={o}>{o}</option>)}</select>}
          <input className="input" type="number" placeholder={t === "missing_event" ? "sau giờ" : "ngưỡng"} value={String(f.value ?? "")} onChange={(e) => setF({ ...f, value: Number(e.target.value) })} />
          <select className="input" value={String(f.level)} onChange={(e) => setF({ ...f, level: e.target.value })}>{["XANH","VANG","CAM","DO"].map((l) => <option key={l}>{l}</option>)}</select>
          <input className="input" type="number" placeholder="Cooldown phút" value={String(f.cooldown_min)} onChange={(e) => setF({ ...f, cooldown_min: Number(e.target.value) })} />
          <select className="input" value={String(f.scope)} onChange={(e) => setF({ ...f, scope: e.target.value })}><option value="FARM">Áp trại {sess.farmId}</option>{["owner","it_engineer"].includes(sess.role) && <option value="GLOBAL">Áp toàn công ty</option>}</select>
        </div>
        <div className="mt-2 text-sm"><b>Người/nhóm nhận:</b> {RECIP.map((r) => <label key={r} className="ml-2 inline-block"><input type="checkbox" checked={(f.recipients as string[]).includes(r)} onChange={() => setF({ ...f, recipients: toggle(f.recipients as string[], r) })} /> {r}</label>)}</div>
        <div className="mt-1 text-sm"><b>Kênh:</b> {["app","zalo","sms","email","coi"].map((c) => <label key={c} className="ml-2 inline-block"><input type="checkbox" checked={(f.channels as string[]).includes(c)} onChange={() => setF({ ...f, channels: toggle(f.channels as string[], c) })} /> {c}</label>)}</div>
        <div className="flex gap-2 mt-2"><button className="btn-primary !py-2" onClick={async () => { if (!f.code || !f.name) return alert("Thiếu mã/tên"); const expr: Record<string, unknown> = { type: t, op: f.op, value: f.value }; if (t === "stock_days") expr.sku = f.sku; if (t === "metric_threshold") expr.metric = f.metric; if (t === "missing_event") { expr.table = f.table ?? "feed_logs"; expr.after_hour = f.value; } const j = await act("save_alert_rule", { ...f, expr }); setMsg(j.ok ? `Đã lưu ${f.code} v${j.version}` : j.error); rules.reload(); }}>Lưu luật</button><button className="btn-secondary !py-2" onClick={async () => { const j = await act("run_rules_now", {}); setMsg(`Đã chạy: ${(j.fired ?? []).length} cảnh báo, ${j.notified} thông báo`); rules.reload(); }}>▶ Chạy luật ngay</button>{msg && <span className="text-sm self-center">{msg}</span>}</div></div>}
      <div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">Danh mục luật (có phiên bản, có vết ai sửa)</div><table className="tbl"><thead><tr><th className="pl-3">Mã</th><th>Tên</th><th>Loại</th><th>Mức</th><th>Người nhận</th><th>Kênh</th><th>Phạm vi</th><th className="text-right">Đã nổ</th><th>TT</th></tr></thead><tbody>
        {(rules.rows ?? []).map((r) => <tr key={`${r.code}-${r.version}-${r.farm_id}`} className={r.active ? "" : "opacity-50"}><td className="pl-3 font-mono text-sm">{String(r.code)} <span className="text-xs">v{String(r.version)}</span></td><td>{String(r.name)}</td><td className="text-xs">{String((r.expr as Record<string, unknown>)?.type ?? r.source)} {JSON.stringify(r.expr).slice(0, 50)}</td><td><span className={LV(String(r.level))}>{String(r.level)}</span></td><td className="text-xs">{(r.recipients as string[] ?? []).join(", ")}</td><td className="text-xs">{(r.channels as string[] ?? []).join(",")}</td><td className="text-xs">{String(r.farm_id)}</td><td className="text-right">{String(r.fire_count ?? 0)}</td><td>{canW && <button className="underline text-xs" onClick={async () => { await act("toggle_alert_rule", { code: r.code, version: r.version, active: !r.active }); rules.reload(); }}>{r.active ? "tắt" : "bật"}</button>}</td></tr>)}
      </tbody></table></div>
    </div>);
}
