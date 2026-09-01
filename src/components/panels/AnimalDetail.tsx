"use client";
import { useEffect, useMemo, useState } from "react";
import ThreeTap from "@/components/ThreeTap";
import { buildForms, type Ref } from "@/lib/forms";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";
import { MonitoringRing } from "@/components/panels/HerdIntake";
import { PedigreePanel } from "@/components/panels/Pedigree";

export default function AnimalDetail({ sess, code }: { sess: Sess; code: string }) {
  const a = useData("animal", { code }); const tags = useData("animal_tags", { code }); const parity = useData("animal_parity", { code });
  const [evPage, setEvPage] = useState(0); const [evType, setEvType] = useState(""); const [evRows, setEvRows] = useState<Record<string, unknown>[]>([]); const [evTotal, setEvTotal] = useState(0);
  const loadEv = async () => { const j = await fetch(`/api/list?kind=events&code=${encodeURIComponent(code)}&limit=50&offset=${evPage * 50}${evType ? `&type=${evType}` : ""}`).then((r) => r.json()); setEvRows(j.rows ?? []); setEvTotal(j.total ?? 0); };
  useEffect(() => { void loadEv(); // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [code, evPage, evType]);
  const ev = { rows: evRows, reload: loadEv };
  const animals = useData("animals"), groups = useData("animal_groups"), warehouses = useData("warehouses"), products = useData("products"), plots = useData("plots"), recipes = useData("recipes"), locations = useData("locations"), sops = useData("sops"), devices = useData("devices"), partners = useData("partners");
  const [showTag, setShowTag] = useState(false); const [tagVal, setTagVal] = useState(""); const [tagType, setTagType] = useState("RFID");
  const ref: Ref | null = useMemo(() => animals.rows && groups.rows && warehouses.rows && products.rows && plots.rows && recipes.rows && locations.rows && sops.rows && devices.rows && partners.rows ? { animals: animals.rows, groups: groups.rows, warehouses: warehouses.rows, products: products.rows, plots: plots.rows, recipes: recipes.rows, locations: locations.rows, sops: sops.rows, devices: devices.rows, partners: partners.rows } : null, [animals.rows, groups.rows, warehouses.rows, products.rows, plots.rows, recipes.rows, locations.rows, sops.rows, devices.rows, partners.rows]);
  const isGroup = code.includes("-GA-") || code.includes("-GT-") || code.includes("-RAS-") || code.includes("-DAN-") || code.includes("-AO-");
  const an = a.rows?.[0]; const grp = groups.rows?.find((g) => g.id === code);
  const spec = ref ? (isGroup ? buildForms(ref, sess.farmId)[code.includes("-RAS-") ? "ras_daily" : code.includes("-GA-") || code.includes("-GT-") ? "poultry_daily" : "animal_event"] : buildForms(ref, sess.farmId).animal_event) : null;
  const pinned = spec ? { ...spec, targets: spec.targets.filter((t) => t.id === (an?.id ?? code)), onDone: () => { ev.reload(); a.reload(); } } : null;
  const weights = (ev.rows ?? []).filter((e) => e.event_type === "CAN").map((e) => ({ ts: String(e.ts), kg: Number(e.value) })).reverse();
  const adg = weights.length >= 2 ? Math.round(((weights[weights.length - 1].kg - weights[0].kg) * 1000) / Math.max(1, (new Date(weights[weights.length - 1].ts).getTime() - new Date(weights[0].ts).getTime()) / 86400e3)) : null;
  return (
    <div className="space-y-3">
      <div className="card">
        {an ? (<>
          <div className="flex flex-wrap items-center gap-2"><span className="text-3xl font-black">{String(an.visual_tag ?? "—")}</span><span className="font-mono">{String(an.id)}</span><span className="b-gray">{String(an.status)}</span>{an.tag_pending ? <span className="b-yel">chờ gắn tai</span> : null}{an.withdrawal_until && new Date(String(an.withdrawal_until)) > new Date() ? <span className="b-red">NGƯNG THUỐC đến {fmt.d(an.withdrawal_until)} — không xuất</span> : null}<span className="ml-auto text-xs text-muted">QR: /trace/{String(an.qr_token)}</span></div>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mt-2 text-sm">
            <div><div className="text-muted">Giống · giới</div><b>{String(an.breed ?? "")} {String(an.sex ?? "")}</b></div>
            <div><div className="text-muted">Ngày sinh</div><b>{fmt.d(an.birth_date)}</b> {an.birth_date ? <span>({Math.floor((Date.now() - new Date(String(an.birth_date)).getTime()) / 2.592e9)} tháng)</span> : null}</div>
            <div><div className="text-muted">Mẹ · cha/tinh</div><b>{String(an.dam_id ?? "—")}</b> · {String(an.sire_code ?? "—")}</div>
            <div><div className="text-muted">RFID</div><b className="font-mono">{String(an.rfid ?? "—")}</b></div>
            <div><div className="text-muted">Đàn</div><b>{String(an.group_name ?? "—")}</b></div>
            <div><div className="text-muted">Lô nhập</div><b>{String(an.intake_lot_id ?? "—")}</b> {an.intake_kind ? `(${String(an.intake_kind)} ${fmt.d(an.intake_date)})` : ""}</div>
            <div><div className="text-muted">Cân gần nhất</div><b>{fmt.n(an.last_weight_kg)} kg</b> {adg != null && <span>· ADG {adg} g/ngày</span>}</div>
            <div><div className="text-muted">Sở hữu · giá sổ đàn</div><b>{String(an.owner_type)}</b> · {fmt.vnd(an.unit_value)}</div>
          </div>
          <div className="mt-2 flex gap-2 flex-wrap"><button className="btn-secondary !py-2 !text-sm" onClick={() => setShowTag(!showTag)}>Gắn/thay tai</button><a className="btn-secondary !py-2 !text-sm" href={`/trace/${String(an.qr_token)}`} target="_blank">Xem trang QR công khai</a></div>
          {showTag && <div className="mt-2 flex gap-2 flex-wrap items-center bg-warning-soft-tok p-2 rounded-xl"><select className="input !w-auto" value={tagType} onChange={(e) => setTagType(e.target.value)}><option>RFID</option><option>VISUAL</option><option>BOLUS</option></select><input className="input !w-64" placeholder="Giá trị thẻ" aria-label="Giá trị thẻ" value={tagVal} onChange={(e) => setTagVal(e.target.value)} /><button className="btn-primary !py-2" onClick={async () => { await act("assign_tag", { animal_id: an.id, tag_type: tagType, value: tagVal }); setTagVal(""); setShowTag(false); a.reload(); tags.reload(); }}>Lưu thẻ</button></div>}
          {tags.rows && tags.rows.length > 0 && <div className="text-xs text-muted mt-1">Lịch sử thẻ: {tags.rows.map((t) => `${t.tag_type}:${t.value}${t.to_ts ? "(cũ)" : ""}`).join(" · ")}</div>}
        </>) : grp ? (<div><div className="text-2xl font-black">{String(grp.name)}</div><div>{String(grp.id)} · {String(grp.kind)} · <b>{fmt.n(grp.head_count)} con</b> · {String(grp.location_name ?? "")}</div></div>) : <div>Đang tải…</div>}
      </div>
      {pinned && ["worker","team_lead","tech_head","director"].includes(sess.role) && <ThreeTap spec={pinned} />}
      <PedigreePanel animalId={code} />
      <div className="card"><MonitoringRing animalId={code} />
      <div className="flex flex-wrap items-center gap-2 mb-2"><h3 className="font-bold">Hồ sơ sự kiện ({evTotal})</h3>{parity.rows?.[0] ? <span className="b-gray">lứa {String(parity.rows[0].parity)} · KC lứa {String(parity.rows[0].calving_interval_days ?? "—")} ngày</span> : null}<select className="input !w-auto !py-1 !text-sm ml-auto" value={evType} onChange={(e) => { setEvType(e.target.value); setEvPage(0); }}><option value="">Mọi loại</option>{["CAN","PHOI","KHAM_THAI","DE","CAI_SUA","DIEU_TRI","VACCINE","BENH","CHUYEN","GHI_CHU"].map((t) => <option key={t}>{t}</option>)}</select><button className="btn-secondary !py-1 !px-2 !text-sm" disabled={evPage === 0} onClick={() => setEvPage(evPage - 1)}>←</button><span className="text-sm">{evPage + 1}/{Math.max(1, Math.ceil(evTotal / 50))}</span><button className="btn-secondary !py-1 !px-2 !text-sm" disabled={(evPage + 1) * 50 >= evTotal} onClick={() => setEvPage(evPage + 1)}>→</button></div>
        <div className="overflow-auto"><table className="tbl"><thead><tr><th>Lúc</th><th>Sự kiện</th><th>Giá trị</th><th>Chi tiết</th><th>Người ghi</th><th>Nguồn</th></tr></thead><tbody>
          {(ev.rows ?? []).map((e) => <tr key={String(e.id)} className={e.status !== "ACTIVE" ? "line-through text-muted" : ""}><td>{fmt.dt(e.ts)}</td><td><b>{String(e.event_type)}</b></td><td>{e.value != null ? `${fmt.n(e.value, 1)} ${String(e.unit ?? "")}` : ""}{e.withdrawal_until ? ` · ngưng đến ${fmt.d(e.withdrawal_until)}` : ""}</td><td className="text-sm">{JSON.stringify(e.detail ?? {}).replace(/[{}"]/g, "").slice(0, 80)}{Array.isArray(e.photo_urls) && (e.photo_urls as string[]).map((u) => <a key={u} href={u} target="_blank" className="ml-1">📷</a>)}</td><td>{String(e.by_name ?? e.created_by)}</td><td className="text-xs">{String(e.source)}{e.is_backfill ? " bù" : ""}{e.paper_serial ? ` ${e.paper_serial}` : ""}</td></tr>)}
        </tbody></table></div></div>
    </div>);
}
