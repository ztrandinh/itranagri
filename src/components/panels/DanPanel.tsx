"use client";
import { useMemo, useState } from "react";
import Link from "next/link";
import { useData, act, fmt, noAccent } from "@/lib/client";
import type { Sess } from "@/components/Shell";

type A = { id: string; visual_tag: string | null; rfid: string | null; species: string; breed: string | null; sex: string | null; birth_date: string | null; status: string; location_name: string | null; group_name: string | null; group_id: string | null; last_weight_kg: number | null; withdrawal_until: string | null; tag_pending: boolean; intake_lot_id: string | null; owner_type: string };

export default function DanPanel({ sess }: { sess: Sess }) {
  const animals = useData<A>("animals"); const groups = useData("animal_groups"); const lots = useData("intake_lots"); const locations = useData("locations");
  const [q, setQ] = useState(""); const [tab, setTab] = useState<"cathe" | "dan" | "lo">("cathe"); const [sel, setSel] = useState<string[]>([]);
  const [showNew, setShowNew] = useState(false);
  const rows = useMemo(() => (animals.rows ?? []).filter((a) => !q || noAccent(`${a.id} ${a.visual_tag} ${a.rfid} ${a.status} ${a.location_name} ${a.group_name}`).includes(noAccent(q))), [animals.rows, q]);
  const canWrite = ["worker","team_lead","tech_head","director"].includes(sess.role);
  return (
    <div className="space-y-3">
      <div className="flex gap-2">{[["cathe", `Cá thể (${animals.rows?.length ?? "…"})`], ["dan", "Đàn / nhóm"], ["lo", "Lô nhập"]].map(([k, l]) => <button key={k} className={`px-4 py-2 rounded-xl font-semibold ${tab === k ? "bg-green-700 text-white" : "bg-white border"}`} onClick={() => setTab(k as typeof tab)}>{l}</button>)}
        {canWrite && tab === "cathe" && <button className="ml-auto btn-secondary !py-2 !text-base" onClick={() => setShowNew(!showNew)}>+ Con mới (bê sinh / nhập)</button>}</div>
      {showNew && <NewAnimal sess={sess} groups={groups.rows ?? []} lots={lots.rows ?? []} locations={locations.rows ?? []} dams={(animals.rows ?? []).filter((a) => a.sex === "F")} onDone={() => { setShowNew(false); animals.reload(); }} />}
      {tab === "cathe" && (<>
        <input className="input" placeholder="Tìm mã / số tai / RFID / trạng thái / chuồng (không dấu)" value={q} onChange={(e) => setQ(e.target.value)} />
        {sel.length > 0 && canWrite && (
          <div className="card flex flex-wrap items-center gap-2 bg-amber-50"><b>{sel.length} con đã chọn</b>
            <select id="bulkgrp" className="input !w-auto"><option value="">→ chuyển vào đàn…</option>{(groups.rows ?? []).filter((g) => g.kind === "BO_NHOM" || g.kind === "DE").map((g) => <option key={String(g.id)} value={String(g.id)}>{String(g.name)}</option>)}</select>
            <select id="bulkloc" className="input !w-auto"><option value="">→ chuyển chuồng…</option>{(locations.rows ?? []).map((l) => <option key={String(l.id)} value={String(l.id)}>{String(l.name)}</option>)}</select>
            <button className="btn-primary !py-2" onClick={async () => { const g = (document.getElementById("bulkgrp") as HTMLSelectElement).value; const l = (document.getElementById("bulkloc") as HTMLSelectElement).value; await act("bulk_move_animals", { animal_ids: sel, group_id: g || null, location_id: l || null }); setSel([]); animals.reload(); }}>Chuyển hàng loạt</button>
            <button className="underline text-sm" onClick={() => setSel([])}>bỏ chọn</button></div>)}
        <div className="card overflow-auto p-0"><table className="tbl"><thead><tr><th></th><th>Số tai</th><th>Mã</th><th>Giống/giới</th><th>Trạng thái</th><th>Chuồng · Đàn</th><th>Cân</th><th>Ngưng thuốc</th></tr></thead><tbody>
          {rows.map((a) => <tr key={a.id} className={a.tag_pending ? "bg-amber-50" : ""}>
            <td className="pl-2"><input type="checkbox" checked={sel.includes(a.id)} onChange={(e) => setSel(e.target.checked ? [...sel, a.id] : sel.filter((x) => x !== a.id))} /></td>
            <td className="font-bold"><Link className="underline" href={`/dan/${a.id}`}>{a.visual_tag ?? "—"}</Link>{a.tag_pending && <span className="b-yel ml-1">chờ tai</span>}</td>
            <td className="font-mono text-sm">{a.id}</td><td>{a.breed} {a.sex}</td><td><span className={["BENH","CACH_LY"].includes(a.status) ? "b-yel" : "b-gray"}>{a.status}</span></td>
            <td className="text-sm">{a.location_name}<br /><span className="text-stone-500">{a.group_name}</span></td><td>{fmt.n(a.last_weight_kg)} kg</td>
            <td>{a.withdrawal_until && new Date(a.withdrawal_until) > new Date() ? <span className="b-red">đến {fmt.d(a.withdrawal_until)}</span> : ""}</td></tr>)}
        </tbody></table></div></>)}
      {tab === "dan" && (<div className="grid sm:grid-cols-2 gap-2">{(groups.rows ?? []).map((g) => <div key={String(g.id)} className="card"><div className="font-bold">{String(g.name)}</div><div className="text-sm text-stone-500">{String(g.id)} · {String(g.kind)} · {String(g.location_name ?? "")}</div><div className="text-2xl font-bold">{fmt.n(g.head_count)} <span className="text-sm font-normal">con</span></div><div className="text-sm">vào {fmt.d(g.started_at)} {g.all_in_all_out ? "· all-in-all-out" : ""}</div><Link className="underline text-sm" href={`/dan/${g.id}`}>Sự kiện đàn →</Link></div>)}</div>)}
      {tab === "lo" && (<div className="card overflow-auto p-0"><table className="tbl"><thead><tr><th>Lô nhập</th><th>Loại</th><th>Ngày</th><th>Số con</th><th>Cách ly đến</th><th>Kiểm dịch</th></tr></thead><tbody>{(lots.rows ?? []).map((l) => <tr key={String(l.id)}><td className="font-mono">{String(l.id)}</td><td>{String(l.kind)}</td><td>{fmt.d(l.date)}</td><td>{String(l.n)}</td><td>{l.quarantine_until ? (new Date(String(l.quarantine_until)) > new Date() ? <span className="b-yel">{fmt.d(l.quarantine_until)}</span> : fmt.d(l.quarantine_until)) : "—"}</td><td>{String(l.vet_cert_no ?? "")}</td></tr>)}</tbody></table></div>)}
    </div>);
}

function NewAnimal({ groups, lots, locations, dams, onDone }: { sess: Sess; groups: Record<string, unknown>[]; lots: Record<string, unknown>[]; locations: Record<string, unknown>[]; dams: A[]; onDone: () => void }) {
  const [f, setF] = useState<Record<string, string>>({ species: "BO", source: "SINH", sex: "F", birth_date: new Date().toISOString().slice(0, 10) });
  const set = (k: string, v: string) => setF({ ...f, [k]: v });
  return (
    <div className="card space-y-2 bg-green-50">
      <div className="font-bold">Con mới — sinh mã tự động; chưa có tai RFID vẫn tạo được (đánh dấu "chờ gắn tai")</div>
      <div className="grid sm:grid-cols-3 gap-2">
        <select className="input" value={f.species} onChange={(e) => set("species", e.target.value)}><option value="BO">Bò</option><option value="DE">Dê</option></select>
        <select className="input" value={f.source} onChange={(e) => set("source", e.target.value)}><option value="SINH">Sinh tại trại</option><option value="MUA">Mua (→ cách ly 21 ngày)</option></select>
        <select className="input" value={f.sex} onChange={(e) => set("sex", e.target.value)}><option value="F">Cái</option><option value="M">Đực</option></select>
        <input className="input" type="date" value={f.birth_date} onChange={(e) => set("birth_date", e.target.value)} />
        <input className="input" placeholder="Giống" value={f.breed ?? ""} onChange={(e) => set("breed", e.target.value)} />
        <select className="input" value={f.dam_id ?? ""} onChange={(e) => set("dam_id", e.target.value)}><option value="">Mẹ (nếu sinh)</option>{dams.map((d) => <option key={d.id} value={d.id}>{d.visual_tag} · {d.id}</option>)}</select>
        <input className="input" placeholder="RFID 15 số (nếu có)" value={f.rfid ?? ""} onChange={(e) => set("rfid", e.target.value)} />
        <input className="input" placeholder="Số tai nhìn (B123)" value={f.visual_tag ?? ""} onChange={(e) => set("visual_tag", e.target.value)} />
        <select className="input" value={f.group_id ?? ""} onChange={(e) => set("group_id", e.target.value)}><option value="">Đàn</option>{groups.filter((g) => g.kind === "BO_NHOM" || g.kind === "DE").map((g) => <option key={String(g.id)} value={String(g.id)}>{String(g.name)}</option>)}</select>
        <select className="input" value={f.location_id ?? ""} onChange={(e) => set("location_id", e.target.value)}><option value="">Chuồng</option>{locations.map((l) => <option key={String(l.id)} value={String(l.id)}>{String(l.name)}</option>)}</select>
        <select className="input" value={f.intake_lot_id ?? ""} onChange={(e) => set("intake_lot_id", e.target.value)}><option value="">Lô nhập</option>{lots.map((l) => <option key={String(l.id)} value={String(l.id)}>{String(l.id)} ({String(l.kind)})</option>)}</select>
      </div>
      <button className="btn-primary" onClick={async () => { const r = await act("new_animal", { ...f, dam_id: f.dam_id || null, rfid: f.rfid || null, visual_tag: f.visual_tag || null, group_id: f.group_id || null, location_id: f.location_id || null, intake_lot_id: f.intake_lot_id || null }); alert(r.code ? `Đã tạo ${r.code}` : r.error); onDone(); }}>Tạo con mới</button>
    </div>);
}
