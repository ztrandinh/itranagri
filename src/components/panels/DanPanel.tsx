"use client";
import Tabs from "@/components/Tabs";
import { useEffect, useState } from "react";
import Link from "next/link";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";
import { HerdIntake, MonitoringRing } from "@/components/panels/HerdIntake";
import ChartIcon from "@/components/ChartIcon";

type A = { id: string; visual_tag: string | null; rfid: string | null; species: string; breed: string | null; sex: string | null; status: string; location_name: string | null; group_name: string | null; group_id: string | null; location_id: string | null; last_weight_kg: number | null; withdrawal_until: string | null; tag_pending: boolean; attention: string | null; open_tasks: number };
type Filt = { q: string; attention: boolean; location: string; group: string; status: string; species: string };

/** Đàn theo TẦNG: trại → khu/chuồng → đàn → cá thể (phân trang server, mặc định lọc "cần chú ý" khi quy mô lớn) */
export default function DanPanel({ sess }: { sess: Sess }) {
  const locs = useData("location_summary"); const groups = useData("animal_groups"); const lots = useData("intake_lots"); const herd = useData("herd"); const cycles = useData("cycles"); const locations = useData("locations");
  const [tab, setTab] = useState<"tong" | "cathe" | "dan" | "lo" | "chuky" | "nhaplo" | "theodoi" | "viec">("tong"); const acts = useData("herd_actions");
  const [f, setF] = useState<Filt>({ q: "", attention: false, location: "", group: "", status: "", species: "" });
  const [page, setPage] = useState(0); const [rows, setRows] = useState<A[]>([]); const [total, setTotal] = useState(0); const [sel, setSel] = useState<string[]>([]); const [showNew, setShowNew] = useState(false);
  const LIMIT = 50;
  const load = async () => {
    const qs = new URLSearchParams({ kind: "animals", limit: String(LIMIT), offset: String(page * LIMIT), ...(f.q ? { q: f.q } : {}), ...(f.attention ? { attention: "1" } : {}), ...(f.location ? { location: f.location } : {}), ...(f.group ? { group: f.group } : {}), ...(f.status ? { status: f.status } : {}), ...(f.species ? { species: f.species } : {}) });
    const j = await fetch(`/api/list?${qs}`).then((r) => r.json()); setRows(j.rows ?? []); setTotal(j.total ?? 0);
  };
  useEffect(() => { if (tab === "cathe") void load(); // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, page, f]);
  const canWrite = ["worker", "team_lead", "tech_head", "director"].includes(sess.role);
  const totalHead = (herd.rows ?? []).reduce((a, r) => a + Number(r.head_count), 0);
  const goto = (patch: Partial<Filt>) => { setF({ ...f, ...patch }); setPage(0); setTab("cathe"); };
  return (
    <div className="space-y-3">
      <Tabs items={[["tong", "Tổng quan"], ["cathe", `Cá thể${tab === "cathe" ? ` (${total})` : ""}`], ["theodoi", "🔄 Vòng theo dõi"], ["nhaplo", "⬆ Nhập lô đàn"], ["dan", "Đàn / nhóm"], ["lo", "Lô nhập"], ["chuky", "Chu kỳ"], ["viec", `📋 Việc đàn · lịch sinh sản (${(acts.rows ?? []).length})`]]} value={tab} onChange={(k) => setTab(k as typeof tab)} right={<>{canWrite && <button className="ml-auto btn-secondary !py-2 !text-base whitespace-nowrap" onClick={() => setShowNew(!showNew)}>+ Con mới</button>}</>} />
      {showNew && <NewAnimal groups={groups.rows ?? []} lots={lots.rows ?? []} locations={locations.rows ?? []} onDone={() => { setShowNew(false); locs.reload(); }} />}

      {tab === "nhaplo" && <HerdIntake sess={sess} onDone={() => { locs.reload(); lots.reload(); }} />}
      {tab === "theodoi" && <MonitoringRing />}
      {tab === "tong" && (<div className="space-y-3">
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
          <div className="kpi"><div className="l">Tổng đàn cá thể (bò/dê)</div><div className="v">{fmt.n(totalHead)}</div><div className="text-xs">{(herd.rows ?? []).map((r) => `${r.status}: ${r.head_count}`).join(" · ")}</div></div>
          <div className="kpi"><div className="l">Đàn nhóm (gà/RAS/…)</div><div className="v">{fmt.n((groups.rows ?? []).filter((g) => g.kind !== "BO_NHOM").reduce((a, g) => a + Number(g.head_count), 0))}</div><div className="text-xs">{(groups.rows ?? []).filter((g) => g.kind !== "BO_NHOM").length} nhóm</div></div>
          <button className="kpi text-left hover:bg-amber-50" onClick={() => goto({ attention: true })}><div className="l">Cần chú ý (bệnh · cách ly · ngưng thuốc · chờ tai · có việc)</div><div className="v text-amber-700">{fmt.n((locs.rows ?? []).reduce((a, r) => a + Number(r.attention), 0))}</div><div className="text-xs underline">mở danh sách</div></button>
          <div className="kpi"><div className="l">Việc mở gắn con vật</div><div className="v">{fmt.n((locs.rows ?? []).reduce((a, r) => a + Number(r.open_tasks), 0))}</div></div>
        </div>
        <div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">Tầng 1 · Khu / chuồng / ô — bấm để xuống cá thể</div>
          <table className="tbl"><thead><tr><th className="pl-3">Khu/chuồng</th><th>Loại</th><th className="text-right">Cá thể</th><th className="text-right">Đàn nhóm</th><th className="text-right">Cần chú ý</th><th className="text-right">Việc mở</th></tr></thead><tbody>
            {(locs.rows ?? []).filter((r) => Number(r.head_individual) + Number(r.head_group) > 0 || Number(r.open_tasks) > 0).map((r) => <tr key={String(r.location_id)} className="hover:bg-green-50 cursor-pointer" onClick={() => goto({ location: String(r.location_id) })}><td className="pl-3 font-semibold">{String(r.name)}</td><td className="text-sm text-stone-500">{String(r.kind)}</td><td className="text-right">{fmt.n(r.head_individual)}</td><td className="text-right">{fmt.n(r.head_group)}</td><td className={`text-right ${Number(r.attention) ? "text-amber-700 font-bold" : ""}`}>{fmt.n(r.attention)}</td><td className="text-right">{fmt.n(r.open_tasks)}</td></tr>)}
          </tbody></table></div>
      </div>)}

      {tab === "cathe" && (<div className="space-y-2">
        <div className="card grid sm:grid-cols-6 gap-2 items-end">
          <div className="sm:col-span-2"><label className="text-xs text-stone-500">Tìm (số tai / mã / RFID / giống — không dấu)</label><input className="input" value={f.q} onChange={(e) => { setF({ ...f, q: e.target.value }); setPage(0); }} placeholder="B012, 00123, brahman…" /></div>
          <div><label className="text-xs text-stone-500">Chuồng</label><select className="input" value={f.location} onChange={(e) => { setF({ ...f, location: e.target.value }); setPage(0); }}><option value="">Tất cả</option>{(locations.rows ?? []).map((l) => <option key={String(l.id)} value={String(l.id)}>{String(l.name)}</option>)}</select></div>
          <div><label className="text-xs text-stone-500">Đàn</label><select className="input" value={f.group} onChange={(e) => { setF({ ...f, group: e.target.value }); setPage(0); }}><option value="">Tất cả</option>{(groups.rows ?? []).filter((g) => g.kind === "BO_NHOM" || g.kind === "DE").map((g) => <option key={String(g.id)} value={String(g.id)}>{String(g.name)}</option>)}</select></div>
          <div><label className="text-xs text-stone-500">Trạng thái</label><select className="input" value={f.status} onChange={(e) => { setF({ ...f, status: e.target.value }); setPage(0); }}><option value="">Đang nuôi</option>{["HAU_BI", "PHOI", "KHAM_THAI", "MANG_THAI", "DE", "NUOI_CON", "CAI_SUA", "CHO_PHOI", "SO_SINH", "THEO_ME", "PHA1", "PHA2", "PHA3", "BENH", "CACH_LY", "CHET", "XUAT"].map((x) => <option key={x}>{x}</option>)}</select></div>
          <label className="flex items-center gap-2 py-3"><input type="checkbox" checked={f.attention} onChange={(e) => { setF({ ...f, attention: e.target.checked }); setPage(0); }} /> Chỉ cần chú ý</label>
        </div>
        {sel.length > 0 && canWrite && <BulkBar sel={sel} groups={groups.rows ?? []} locations={locations.rows ?? []} onDone={() => { setSel([]); void load(); }} />}
        <div className="card p-0 overflow-auto"><table className="tbl"><thead><tr><th></th><th className="pl-1">Số tai</th><th>Mã</th><th>Giống/giới</th><th>Trạng thái</th><th>Chuồng · Đàn</th><th className="text-right">Cân</th><th>Chú ý</th></tr></thead><tbody>
          {rows.map((a) => <tr key={a.id} className={a.attention ? "bg-amber-50" : ""}>
            <td className="pl-2"><input type="checkbox" checked={sel.includes(a.id)} onChange={(e) => setSel(e.target.checked ? [...sel, a.id] : sel.filter((x) => x !== a.id))} /></td>
            <td className="font-bold"><Link className="underline" href={`/dan/${a.id}`}>{a.visual_tag ?? "—"}</Link></td><td className="font-mono text-xs">{a.id}</td><td className="text-sm">{a.breed} {a.sex}</td><td><span className={["BENH", "CACH_LY"].includes(a.status) ? "b-yel" : "b-gray"}>{a.status}</span></td>
            <td className="text-sm">{a.location_name}<br /><span className="text-stone-500">{a.group_name}</span></td><td className="text-right">{fmt.n(a.last_weight_kg)}</td>
            <td className="text-sm">{a.attention && <span className="b-yel">{a.attention}</span>} {Number(a.open_tasks) > 0 && <span className="b-gray">{a.open_tasks} việc</span>}</td><td><ChartIcon type="animal" id={String(a.id)} label={String(a.visual_tag ?? a.id)} /></td></tr>)}
          {!rows.length && <tr><td colSpan={8} className="p-4 text-stone-500">Không có con nào khớp.</td></tr>}</tbody></table>
          <div className="flex items-center gap-2 px-3 py-2 text-sm"><span>{total} con · trang {page + 1}/{Math.max(1, Math.ceil(total / LIMIT))}</span><button className="btn-secondary !py-1 !px-3 !text-sm" disabled={page === 0} onClick={() => setPage(page - 1)}>←</button><button className="btn-secondary !py-1 !px-3 !text-sm" disabled={(page + 1) * LIMIT >= total} onClick={() => setPage(page + 1)}>→</button></div></div>
      </div>)}

      {tab === "dan" && (<div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-2">{(groups.rows ?? []).map((g) => <div key={String(g.id)} className="card"><div className="font-bold">{String(g.name)}</div><div className="text-sm text-stone-500">{String(g.id)} · {String(g.kind)} · {String(g.location_name ?? "")}</div><div className="text-2xl font-bold">{fmt.n(g.head_count)} <span className="text-sm font-normal">con</span></div><div className="text-sm">vào {fmt.d(g.started_at)} {g.all_in_all_out ? "· all-in-all-out" : ""} · chu kỳ {String(g.cycle_id ?? "—")}</div><div className="flex gap-3 text-sm mt-1"><Link className="underline" href={`/dan/${g.id}`}>Sự kiện đàn →</Link>{g.kind === "BO_NHOM" && <button className="underline" onClick={() => goto({ group: String(g.id) })}>Cá thể →</button>}</div></div>)}</div>)}
      {tab === "lo" && (<div className="card overflow-auto p-0"><table className="tbl"><thead><tr><th className="pl-3">Lô nhập</th><th>Loại</th><th>Ngày</th><th className="text-right">Số con</th><th>Cách ly đến</th><th>Kiểm dịch</th></tr></thead><tbody>{(lots.rows ?? []).map((l) => <tr key={String(l.id)}><td className="pl-3 font-mono">{String(l.id)}</td><td>{String(l.kind)}</td><td>{fmt.d(l.date)}</td><td className="text-right">{String(l.n)}</td><td>{l.quarantine_until ? (new Date(String(l.quarantine_until)) > new Date() ? <span className="b-yel">{fmt.d(l.quarantine_until)}</span> : fmt.d(l.quarantine_until)) : "—"}</td><td>{String(l.vet_cert_no ?? "")}</td></tr>)}</tbody></table></div>)}
      {tab === "viec" && <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-slate-100 rounded-t-xl font-bold">Lịch sinh sản & hành động 30 ngày tới — tự suy từ sự kiện: khám thai (phối +60), chuẩn bị đẻ (phối +283 −14), tái phối (đẻ +60), cai sữa (180 ngày), cân 14 ngày, loại thải (không đậu ≥3 / &gt;8 tuổi), vỗ béo đủ ngày xuất, đang ngưng thuốc; việc ≤3 ngày tự sinh trong "Ca của tôi"</div><table className="tbl text-sm"><thead><tr><th className="pl-3">Hạn</th><th>Việc</th><th>Con</th><th>Hạng</th><th>Ghi chú</th><th>Ưu tiên</th><th></th></tr></thead><tbody>{(acts.rows ?? []).map((r, i) => <tr key={i} className={new Date(String(r.due)) < new Date() ? "bg-red-50" : r.priority === "CAO" ? "bg-amber-50" : ""}><td className="pl-3">{fmt.d(String(r.due))}</td><td className="font-semibold">{String(r.action)}</td><td><a className="underline" href={`/xem/animal/${r.animal_id}`}>{String(r.visual_tag ?? r.animal_id)}</a></td><td className="text-xs">{String(r.class_code)}</td><td className="text-xs">{String(r.note)}</td><td className="text-xs">{String(r.priority)}</td><td><ChartIcon type="animal" id={String(r.animal_id)} /></td></tr>)}</tbody></table>{!(acts.rows ?? []).length && <div className="p-3 text-sm text-slate-500">Không có việc đàn trong 30 ngày.</div>}</div>}
      {tab === "chuky" && (<div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">Chu kỳ (vụ · lứa · đợt) — so sánh năm/lứa dựa vào đây; đóng chu kỳ = chốt số liệu</div><table className="tbl"><thead><tr><th className="pl-3">Mã</th><th>Loại</th><th>Đối tượng</th><th>Bắt đầu</th><th>Kết thúc</th><th>TT</th><th>Tổng kết</th><th></th></tr></thead><tbody>{(cycles.rows ?? []).map((c) => <tr key={String(c.id)}><td className="pl-3 font-mono text-xs">{String(c.id)}</td><td>{String(c.kind)}</td><td>{String(c.group_name ?? c.plot_name ?? "")}</td><td>{fmt.d(c.start_date)}</td><td>{fmt.d(c.end_date)}</td><td><span className={c.status === "MO" ? "b-grn" : "b-gray"}>{String(c.status)}</span></td><td className="text-xs">{c.summary ? JSON.stringify(c.summary).replace(/[{}"]/g, "") : ""}</td><td>{c.status === "MO" && ["team_lead", "tech_head", "director", "owner"].includes(sess.role) && <button className="btn-secondary !py-1 !px-2 !text-sm" onClick={async () => { if (confirm("Đóng chu kỳ và chốt số liệu?")) { await act("close_cycle", { id: c.id }); cycles.reload(); } }}>Đóng</button>}</td></tr>)}</tbody></table></div>)}
    </div>);
}

function BulkBar({ sel, groups, locations, onDone }: { sel: string[]; groups: Record<string, unknown>[]; locations: Record<string, unknown>[]; onDone: () => void }) {
  const [g, setG] = useState(""); const [l, setL] = useState("");
  return <div className="card flex flex-wrap items-center gap-2 bg-amber-50"><b>{sel.length} con đã chọn</b>
    <select className="input !w-auto" value={g} onChange={(e) => setG(e.target.value)}><option value="">→ chuyển vào đàn…</option>{groups.filter((x) => x.kind === "BO_NHOM" || x.kind === "DE").map((x) => <option key={String(x.id)} value={String(x.id)}>{String(x.name)}</option>)}</select>
    <select className="input !w-auto" value={l} onChange={(e) => setL(e.target.value)}><option value="">→ chuyển chuồng…</option>{locations.map((x) => <option key={String(x.id)} value={String(x.id)}>{String(x.name)}</option>)}</select>
    <button className="btn-primary !py-2" onClick={async () => { await act("bulk_move_animals", { animal_ids: sel, group_id: g || null, location_id: l || null }); onDone(); }}>Chuyển hàng loạt</button></div>;
}

function NewAnimal({ groups, lots, locations, onDone }: { groups: Record<string, unknown>[]; lots: Record<string, unknown>[]; locations: Record<string, unknown>[]; onDone: () => void }) {
  const [f, setF] = useState<Record<string, string>>({ species: "BO", source: "SINH", sex: "F", birth_date: new Date().toISOString().slice(0, 10) });
  const set = (k: string, v: string) => setF({ ...f, [k]: v });
  return (
    <div className="card space-y-2 bg-green-50">
      <div className="font-bold">Con mới — sinh mã tự động; chưa có tai RFID vẫn tạo được ("chờ gắn tai")</div>
      <div className="grid sm:grid-cols-3 gap-2">
        <select className="input" value={f.species} onChange={(e) => set("species", e.target.value)}><option value="BO">Bò</option><option value="DE">Dê</option></select>
        <select className="input" value={f.source} onChange={(e) => set("source", e.target.value)}><option value="SINH">Sinh tại trại</option><option value="MUA">Mua (→ cách ly 21 ngày)</option></select>
        <select className="input" value={f.sex} onChange={(e) => set("sex", e.target.value)}><option value="F">Cái</option><option value="M">Đực</option></select>
        <input className="input" type="date" value={f.birth_date} onChange={(e) => set("birth_date", e.target.value)} />
        <input className="input" placeholder="Giống" value={f.breed ?? ""} onChange={(e) => set("breed", e.target.value)} />
        <input className="input" placeholder="Mã mẹ (F01-BO-…)" value={f.dam_id ?? ""} onChange={(e) => set("dam_id", e.target.value)} />
        <input className="input" placeholder="RFID 15 số (nếu có)" value={f.rfid ?? ""} onChange={(e) => set("rfid", e.target.value)} />
        <input className="input" placeholder="Số tai nhìn (B123)" value={f.visual_tag ?? ""} onChange={(e) => set("visual_tag", e.target.value)} />
        <select className="input" value={f.group_id ?? ""} onChange={(e) => set("group_id", e.target.value)}><option value="">Đàn</option>{groups.filter((g) => g.kind === "BO_NHOM" || g.kind === "DE").map((g) => <option key={String(g.id)} value={String(g.id)}>{String(g.name)}</option>)}</select>
        <select className="input" value={f.location_id ?? ""} onChange={(e) => set("location_id", e.target.value)}><option value="">Chuồng</option>{locations.map((l) => <option key={String(l.id)} value={String(l.id)}>{String(l.name)}</option>)}</select>
        <select className="input" value={f.intake_lot_id ?? ""} onChange={(e) => set("intake_lot_id", e.target.value)}><option value="">Lô nhập</option>{lots.map((l) => <option key={String(l.id)} value={String(l.id)}>{String(l.id)} ({String(l.kind)})</option>)}</select>
      </div>
      <button className="btn-primary" onClick={async () => { const r = await act("new_animal", { ...f, dam_id: f.dam_id || null, rfid: f.rfid || null, visual_tag: f.visual_tag || null, group_id: f.group_id || null, location_id: f.location_id || null, intake_lot_id: f.intake_lot_id || null }); alert(r.code ? `Đã tạo ${r.code}` : r.error); onDone(); }}>Tạo con mới</button>
    </div>);
}
