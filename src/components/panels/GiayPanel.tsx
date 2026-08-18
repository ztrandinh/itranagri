"use client";
import { useMemo, useState } from "react";
import ThreeTap from "@/components/ThreeTap";
import { buildForms, type Ref } from "@/lib/forms";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";

const FORM_MAP: Record<string, string> = { BM01: "feed_tmr", BM02: "animal_event", BM03: "crop_log", BM04: "bio_batch", BM05: "stock_in", BM06: "sale", BM07: "checklist", BM08: "gate", BM09: "stocktake", BM10: "incident" };

export default function GiayPanel({ sess }: { sess: Sess }) {
  const pending = useData("paper_pending"); const all = useData("paper_all");
  const animals = useData("animals"), groups = useData("animal_groups"), warehouses = useData("warehouses"), products = useData("products"), plots = useData("plots"), recipes = useData("recipes"), locations = useData("locations"), sops = useData("sops"), devices = useData("devices"), partners = useData("partners");
  const [tab, setTab] = useState<"nop" | "nhap" | "audit">("nop"); const [cur, setCur] = useState<Record<string, unknown> | null>(null); const [n, setN] = useState(0);
  const ref: Ref | null = useMemo(() => animals.rows && groups.rows && warehouses.rows && products.rows && plots.rows && recipes.rows && locations.rows && sops.rows && devices.rows && partners.rows ? { animals: animals.rows, groups: groups.rows, warehouses: warehouses.rows, products: products.rows, plots: plots.rows, recipes: recipes.rows, locations: locations.rows, sops: sops.rows, devices: devices.rows, partners: partners.rows } : null, [animals.rows, groups.rows, warehouses.rows, products.rows, plots.rows, recipes.rows, locations.rows, sops.rows, devices.rows, partners.rows]);
  const forms = ref ? buildForms(ref, sess.farmId) : null;
  return (
    <div className="space-y-3">
      <div className="flex gap-2">{[["nop", "📷 Nộp phiếu giấy"], ["nhap", `Nhập từ phiếu (${pending.rows?.length ?? 0})`], ["audit", "Đối chiếu giấy–số"]].map(([k, l]) => <button key={k} className={`px-4 py-2 rounded-xl font-semibold ${tab === k ? "bg-green-700 text-white" : "bg-white border"}`} onClick={() => setTab(k as typeof tab)}>{l}</button>)}</div>
      <div className="text-sm text-stone-600">Luật giấy–số (SPEC-02): ghi tay tại chỗ → cuối ca chụp → upload theo số seri → nhập máy gắn <code>paper_serial</code> → tick ĐÃ SỐ HÓA → lưu cứng 5 năm. RC11: chưa số hóa &gt;24h = VÀNG; seri nhảy quãng = ĐỎ.</div>
      {tab === "nop" && forms && <ThreeTap spec={{ ...forms.paper_submit, onDone: () => { pending.reload(); all.reload(); } }} />}
      {tab === "nhap" && (<div className="space-y-3">
        {!cur && <div className="grid sm:grid-cols-2 gap-2">{(pending.rows ?? []).map((p) => <button key={String(p.id)} className="tile" onClick={() => { setCur(p); setN(0); }}><span className="font-bold">{String(p.serial)}</span><span className="text-sm text-stone-500">{String(p.form_code)} · chụp {fmt.dt(p.ts)} {new Date(String(p.ts)) < new Date(Date.now() - 86400e3) && <span className="b-yel">&gt;24h</span>}</span>{p.anomaly ? <span className="text-red-700 text-sm">⚠ {String(p.anomaly)}</span> : null}</button>)}{pending.rows?.length === 0 && <div className="card text-stone-500">Không có phiếu chờ số hóa.</div>}</div>}
        {cur && forms && (<div className="grid lg:grid-cols-2 gap-3">
          <div className="card"><div className="flex justify-between"><b>{String(cur.serial)}</b><button className="underline text-sm" onClick={() => setCur(null)}>← danh sách</button></div>{cur.photo_url ? <img src={String(cur.photo_url)} alt="phiếu" className="mt-2 w-full rounded-xl border" /> : <div className="text-stone-500 mt-2">Không có ảnh — đối chiếu bản cứng.</div>}<div className="mt-2 text-sm">Đã nhập {n} dòng từ tờ này.</div><button className="btn-primary mt-2 w-full" onClick={async () => { await act("digitize_paper", { id: cur.id }); setCur(null); pending.reload(); all.reload(); }}>✓ ĐÃ SỐ HÓA xong tờ này</button></div>
          <div>{FORM_MAP[String(cur.form_code)] && <ThreeTap spec={{ ...forms[FORM_MAP[String(cur.form_code)]], paper: { serial: String(cur.serial) }, onDone: () => setN((x) => x + 1) }} />}</div>
        </div>)}
      </div>)}
      {tab === "audit" && (<div className="card p-0 overflow-auto"><table className="tbl"><thead><tr><th className="pl-3">Seri</th><th>Mẫu</th><th>Chụp</th><th>Số hóa</th><th>Người nhập</th><th>Bất thường</th><th>Ảnh</th></tr></thead><tbody>{(all.rows ?? []).map((p) => <tr key={String(p.id)}><td className="pl-3 font-mono">{String(p.serial)}</td><td>{String(p.form_code)}</td><td>{fmt.dt(p.ts)}</td><td>{p.digitized ? <span className="b-grn">{fmt.dt(p.digitized_ts)}</span> : <span className="b-yel">chưa</span>}</td><td>{String(p.digitized_by ?? "")}</td><td className="text-red-700">{String(p.anomaly ?? "")}</td><td>{p.photo_url ? <a href={String(p.photo_url)} target="_blank">📷</a> : null}</td></tr>)}</tbody></table></div>)}
    </div>);
}
