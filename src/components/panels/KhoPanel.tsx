"use client";
import { useMemo, useState } from "react";
import ThreeTap from "@/components/ThreeTap";
import { buildForms, type Ref } from "@/lib/forms";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";

export default function KhoPanel({ sess }: { sess: Sess }) {
  const stock = useData("stock"); const dos = useData("days_of_stock"); const fefo = useData("fefo_red"); const adj = useData("adjustments_pending"); const silage = useData("days_silage"); const herd = useData("herd_value");
  const animals = useData("animals"), groups = useData("animal_groups"), warehouses = useData("warehouses"), products = useData("products"), plots = useData("plots"), recipes = useData("recipes"), locations = useData("locations"), sops = useData("sops"), devices = useData("devices"), partners = useData("partners");
  const [tab, setTab] = useState<"ton" | "ghi" | "kiemke" | "so">("ton"); const [form, setForm] = useState("stock_in"); const [sku, setSku] = useState<string | null>(null);
  const ledger = useData(sku ? "stock_ledger" : null, { sku: sku ?? undefined });
  const ref: Ref | null = useMemo(() => animals.rows && groups.rows && warehouses.rows && products.rows && plots.rows && recipes.rows && locations.rows && sops.rows && devices.rows && partners.rows ? { animals: animals.rows, groups: groups.rows, warehouses: warehouses.rows, products: products.rows, plots: plots.rows, recipes: recipes.rows, locations: locations.rows, sops: sops.rows, devices: devices.rows, partners: partners.rows } : null, [animals.rows, groups.rows, warehouses.rows, products.rows, plots.rows, recipes.rows, locations.rows, sops.rows, devices.rows, partners.rows]);
  const forms = ref ? buildForms(ref, sess.farmId) : null;
  const byWh = useMemo(() => { const m = new Map<string, Record<string, unknown>[]>(); for (const r of stock.rows ?? []) m.set(String(r.warehouse_code), [...(m.get(String(r.warehouse_code)) ?? []), r]); return [...m.entries()].sort(); }, [stock.rows]);
  const canApprove = ["tech_head","director","accountant"].includes(sess.role);
  const ds = silage.rows?.[0]; const hv = herd.rows?.[0];
  return (
    <div className="space-y-3">
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
        <div className="kpi"><div className="l">Ngày-tồn ủ chua (K3)</div><div className={`v ${ds && Number(ds.days_silage) < 30 ? "text-red-700" : ds && Number(ds.days_silage) < 45 ? "text-amber-700" : ""}`}>{ds?.days_silage != null ? fmt.n(ds.days_silage) : "—"}</div><div className="text-xs">{fmt.n(ds?.k3_kg)} kg / {fmt.n(ds?.kg_per_day)} kg·ngày</div></div>
        <div className="kpi"><div className="l">Sổ đàn K8</div><div className="v">{fmt.n(hv?.head_count)} con</div><div className="text-xs">{fmt.vnd(hv?.value)}</div></div>
        <div className="kpi"><div className="l">FEFO đỏ (&lt;20% hạn)</div><div className={`v ${(fefo.rows?.length ?? 0) > 0 ? "text-red-700" : ""}`}>{fefo.rows?.length ?? "—"}</div></div>
        <div className="kpi"><div className="l">Điều chỉnh chờ duyệt</div><div className="v">{adj.rows?.length ?? "—"}</div></div>
      </div>
      <div className="flex gap-2 overflow-x-auto">{[["ton", "Tồn kho"], ["ghi", "Nhập / Xuất"], ["kiemke", "Kiểm kê · Điều chỉnh"], ["so", "Ngày-tồn nguyên liệu"]].map(([k, l]) => <button key={k} className={`px-4 py-2 rounded-xl font-semibold whitespace-nowrap ${tab === k ? "bg-green-700 text-white" : "bg-white border"}`} onClick={() => setTab(k as typeof tab)}>{l}</button>)}</div>
      {tab === "ton" && byWh.map(([wh, rows]) => (
        <div key={wh} className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">{wh} · {String(warehouses.rows?.find((w) => w.code === wh)?.name ?? "")}</div>
          <table className="tbl"><thead><tr><th className="pl-3">Hàng</th><th>Lô</th><th>Hạn</th><th className="text-right">Tồn</th><th className="text-right">Giá vốn BQ</th><th></th></tr></thead><tbody>
            {rows.map((r, i) => <tr key={i}><td className="pl-3">{String(r.product_name)}<div className="text-xs text-stone-500">{String(r.sku)}</div></td><td className="font-mono text-xs">{String(r.lot_id ?? "").split("-").slice(3).join("-")}{r.lot_status !== "KHA_DUNG" && r.lot_status ? <span className="b-red ml-1">{String(r.lot_status)}</span> : null}</td><td className="text-sm">{fmt.d(r.expiry_date)}</td><td className="text-right font-bold">{fmt.n(r.qty, 1)} {String(r.unit ?? "")}</td><td className="text-right">{fmt.vnd(r.avg_cost)}</td><td><button className="underline text-sm" onClick={() => { setSku(String(r.sku)); setTab("so"); }}>thẻ kho</button></td></tr>)}
          </tbody></table></div>))}
      {tab === "ghi" && forms && (<div className="space-y-2"><div className="flex gap-2 flex-wrap">{["stock_in", "stock_out", "fuel_out", "egg_in"].map((k) => <button key={k} className={`btn !py-2 !text-base ${form === k ? "bg-green-700 text-white" : "bg-white border"}`} onClick={() => setForm(k)}>{forms[k].title}</button>)}</div><ThreeTap spec={{ ...forms[form], onDone: () => stock.reload() }} /></div>)}
      {tab === "kiemke" && (<div className="space-y-3">
        {forms && <ThreeTap spec={{ ...forms.stocktake, onDone: () => adj.reload() }} />}
        <div className="card"><h3 className="font-bold">Phiếu điều chỉnh tồn (cần KTT/GĐ/KT duyệt — người khác người đề nghị)</h3>
          <AdjForm sess={sess} warehouses={warehouses.rows ?? []} products={products.rows ?? []} onDone={() => adj.reload()} />
          <table className="tbl mt-2"><thead><tr><th>Lúc</th><th>Kho</th><th>Hàng</th><th>±</th><th>Lý do</th><th>Đề nghị</th><th></th></tr></thead><tbody>
            {(adj.rows ?? []).map((r) => <tr key={String(r.id)}><td>{fmt.dt(r.ts)}</td><td>{String(r.warehouse_id ?? "").slice(-2)}</td><td>{String(r.sku ?? r.target_table)}</td><td className="font-bold">{fmt.n(r.delta, 1)}</td><td>{String(r.reason)}</td><td>{String(r.created_by)}</td><td>{canApprove && <><button className="btn-primary !py-1 !px-2 !text-sm mr-1" onClick={async () => { const j = await act("approve_adjustment", { id: r.id, approve: true }); if (j.error) alert(j.error); adj.reload(); stock.reload(); }}>Duyệt</button><button className="btn-secondary !py-1 !px-2 !text-sm" onClick={async () => { await act("approve_adjustment", { id: r.id, approve: false }); adj.reload(); }}>Từ chối</button></>}</td></tr>)}
          </tbody></table></div></div>)}
      {tab === "so" && (<div className="space-y-3">
        <div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">Ngày-tồn theo mặt hàng (tồn / tiêu thụ TB 14 ngày) — R7: ≤35%/nguồn, tồn 60 ngày</div><table className="tbl"><thead><tr><th className="pl-3">Hàng</th><th className="text-right">Tồn</th><th className="text-right">Dùng/ngày</th><th className="text-right">Ngày còn</th></tr></thead><tbody>{(dos.rows ?? []).map((r, i) => <tr key={i}><td className="pl-3">{String(r.product_name)}</td><td className="text-right">{fmt.n(r.qty)}</td><td className="text-right">{fmt.n(r.use_per_day, 1)}</td><td className={`text-right font-bold ${r.days != null && Number(r.days) < 30 ? "text-red-700" : r.days != null && Number(r.days) < 45 ? "text-amber-700" : ""}`}>{r.days != null ? fmt.n(r.days) : "—"}</td></tr>)}</tbody></table></div>
        {sku && <div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">Thẻ kho {sku}</div><table className="tbl"><thead><tr><th className="pl-3">Lúc</th><th>Kho</th><th>Lô</th><th>±</th><th>Lý do</th><th>Điểm ghi</th><th className="text-right">Tồn sau</th></tr></thead><tbody>{(ledger.rows ?? []).map((r) => <tr key={String(r.id)}><td className="pl-3">{fmt.dt(r.ts)}</td><td>{String(r.warehouse_id).slice(-2)}</td><td className="font-mono text-xs">{String(r.lot_id ?? "")}</td><td className={Number(r.direction) > 0 ? "text-green-700" : "text-red-700"}>{Number(r.direction) > 0 ? "+" : "−"}{fmt.n(r.qty, 1)}</td><td>{String(r.reason)}</td><td className="text-xs">{String(r.weigh_point ?? "")}</td><td className="text-right font-bold">{fmt.n(r.balance_after, 1)}</td></tr>)}</tbody></table></div>}
      </div>)}
    </div>);
}
function AdjForm({ warehouses, products, onDone }: { sess: Sess; warehouses: Record<string, unknown>[]; products: Record<string, unknown>[]; onDone: () => void }) {
  const [wh, setWh] = useState(""); const [sku, setSku] = useState(""); const [delta, setDelta] = useState(""); const [reason, setReason] = useState("");
  return (<div className="flex flex-wrap gap-2 items-center">
    <select className="input !w-auto" value={wh} onChange={(e) => setWh(e.target.value)}><option value="">Kho</option>{warehouses.map((w) => <option key={String(w.id)} value={String(w.id)}>{String(w.code)}</option>)}</select>
    <select className="input !w-auto" value={sku} onChange={(e) => setSku(e.target.value)}><option value="">Hàng</option>{products.map((p) => <option key={String(p.sku)} value={String(p.sku)}>{String(p.name)}</option>)}</select>
    <input className="input !w-32" type="number" placeholder="± số lượng" value={delta} onChange={(e) => setDelta(e.target.value)} />
    <input className="input !w-64" placeholder="Lý do (bắt buộc)" value={reason} onChange={(e) => setReason(e.target.value)} />
    <button className="btn-secondary !py-2" onClick={async () => { if (!wh || !sku || !delta || reason.length < 3) return alert("Thiếu thông tin"); const r = await fetch("/api/events/adjustments", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ client_ref: crypto.randomUUID(), target_table: "inventory_moves", warehouse_id: wh, sku, delta: Number(delta), reason }) }); const j = await r.json(); if (j.results?.[0]?.status !== "CREATED") alert(JSON.stringify(j)); setDelta(""); setReason(""); onDone(); }}>Tạo phiếu điều chỉnh</button>
  </div>);
}
