import io, os
R = "F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R + p) or R, exist_ok=True); io.open(R + p, "w", encoding="utf-8", newline="\n").write(s); print("w", p)
def rw(p, fn): s = io.open(R + p, encoding="utf-8").read(); n = fn(s); assert n != s, p; io.open(R + p, "w", encoding="utf-8", newline="\n").write(n); print("ok", p)
w("src/app/api/compliance/evidence/route.ts", '''import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
/** Chạy evidence_query của 1 control (SQL lưu trong bảng controls, do QA/IT quản lý; $1 = farm) → bằng chứng sống */
export async function GET(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const id = new URL(req.url).searchParams.get("control") ?? "";
  try { return await withCtx(s, async (c) => { const ctl = (await c.query("select * from controls where id=$1", [id])).rows[0]; if (!ctl?.evidence_query) return NextResponse.json({ error: "ERR_NO_QUERY" }, { status: 404 }); const q = String(ctl.evidence_query); if (!/^\\s*select/i.test(q)) return NextResponse.json({ error: "ERR_NOT_SELECT" }, { status: 400 }); const rows = (await c.query(q.includes("$1") ? q : q + " where $1::text is not null", [s.farmId])).rows; return NextResponse.json({ control: ctl, rows }); }); }
  catch (e) { return NextResponse.json({ error: "ERR_QUERY", detail: (e as Error).message }, { status: 500 }); }
}
''')
rw("src/lib/queries.ts", lambda s: s.replace("  me: {", '''  compliance_coverage: { sql: "select * from v_compliance_coverage" },
  controls: { sql: "select c.*, (select count(*) from clause_controls cc where cc.control_id=c.id) as clauses from controls c where active order by id" },
  clause_controls: { sql: "select cc.*, r.standard_code, r.clause, r.title from clause_controls cc join standard_requirements r on r.id=cc.requirement_id" },
  compliance_gaps: { sql: "select g.*, r.standard_code, r.clause, r.title, r.level from compliance_gaps g join standard_requirements r on r.id=g.requirement_id where g.status<>'DONG' order by r.level, r.standard_code" },
  sop_library: { sql: "select s.*, p.name as l2_name, p.organ, p.dept_code from sops s left join processes p on p.code=s.l2_code order by s.l1_chain, s.l2_code, s.l3_no, s.code" },
  me: {''', 1))
rw("src/lib/admin.ts", lambda s: s.replace('  { table: "documents", pk: "id",', '''  { table: "controls", pk: "id", label: "Tuân thủ · Control (vật thật trong app)", group: "Chất lượng", farmScoped: false, softDelete: "active", writeRoles: ["owner", "it_engineer", "auditor", "tech_head"] },
  { table: "clause_controls", pk: "requirement_id", label: "Tuân thủ · Điều khoản ↔ control", group: "Chất lượng", farmScoped: false, softDelete: null, writeRoles: ["owner", "it_engineer", "auditor", "tech_head"] },
  { table: "compliance_gaps", pk: "id", label: "Tuân thủ · Gap", group: "Chất lượng", farmScoped: false, softDelete: "status", writeRoles: ["owner", "it_engineer", "auditor", "tech_head"] },
  { table: "sops", pk: "code", label: "Thư viện SOP (L3)", group: "Danh mục", farmScoped: false, softDelete: "status", writeRoles: OPS },
  { table: "documents", pk: "id",''', 1))
# TuanThu: coverage + controls + gaps
def tt(s):
    s = s.replace('  const icfs = useData("icfs_score"); const icfsSum = useData("icfs_summary");', '  const icfs = useData("icfs_score"); const icfsSum = useData("icfs_summary"); const cov = useData("compliance_coverage"); const ctls = useData("controls"); const gaps = useData("compliance_gaps"); const cc = useData("clause_controls"); const [ev, setEv] = useState<{ id: string; rows: R[] } | null>(null);')
    s = s.replace('      <div className="text-sm text-slate-600">Số điều khoản là bản tóm tắt', '''      <div className="card"><div className="flex items-center gap-2 flex-wrap"><b>Độ phủ theo SPEC-05: điều khoản → CONTROL (vật thật trong app)</b><span className="text-xs text-slate-500">chuẩn = cặp kính soi vào 1 bộ quy trình; điều khoản không trỏ được control = gap đỏ</span><span className="ml-auto text-sm">Gap mở: <b className={(gaps.rows ?? []).length ? "text-red-700" : "text-emerald-700"}>{(gaps.rows ?? []).length}</b></span></div>
        <div className="flex flex-wrap gap-1 mt-2">{(cov.rows ?? []).map((c) => <span key={String(c.standard_code)} className={`rounded-full px-2 py-1 text-xs border ${Number(c.pct) === 100 ? "bg-emerald-50 border-emerald-400" : Number(c.pct) >= 80 ? "bg-amber-50 border-amber-400" : "bg-red-50 border-red-400"}`} title={`ưu tiên ${c.priority} · ${c.spec_code ?? ""}`}>{String(c.standard_code)} {String(c.with_control)}/{String(c.clauses)} · MAJOR {String(c.major_with_control)}/{String(c.major)}</span>)}</div>
        <div className="mt-2 text-sm"><b>{(ctls.rows ?? []).length} control</b> — bấm để chạy bằng chứng sống:</div>
        <div className="flex flex-wrap gap-1 mt-1">{(ctls.rows ?? []).map((c) => <button key={String(c.id)} className={`rounded-lg border px-2 py-1 text-xs text-left ${ev?.id === c.id ? "bg-emerald-100 border-emerald-500" : "bg-white"}`} title={`${c.kind} · ${c.ref}`} onClick={async () => { const j = await fetch(`/api/compliance/evidence?control=${c.id}`).then((r) => r.json()); setEv({ id: String(c.id), rows: j.rows ?? [{ error: j.error, detail: j.detail }] }); }}><b>{String(c.id)}</b> <span className="text-slate-500">{String(c.kind)} · {String(c.clauses)} đk</span></button>)}</div>
        {ev && <div className="mt-2 rounded-xl bg-slate-50 p-2 text-sm"><b>{ev.id}</b> — {String((ctls.rows ?? []).find((c) => c.id === ev.id)?.description ?? "")}<div className="text-xs text-slate-500">ref: {String((ctls.rows ?? []).find((c) => c.id === ev.id)?.ref ?? "")}</div><pre className="text-xs mt-1 overflow-auto">{JSON.stringify(ev.rows, null, 1)}</pre><div className="text-xs">Điều khoản: {(cc.rows ?? []).filter((x) => x.control_id === ev.id).map((x) => `${x.standard_code}:${x.clause}`).join(" · ")}</div></div>}
        {(gaps.rows ?? []).length > 0 && <table className="tbl text-xs mt-2"><thead><tr><th className="pl-2">Chuẩn</th><th>Điều</th><th>Yêu cầu</th><th>Mức</th><th>Kế hoạch</th></tr></thead><tbody>{(gaps.rows ?? []).map((g) => <tr key={String(g.id)} className="bg-red-50"><td className="pl-2">{String(g.standard_code)}</td><td>{String(g.clause)}</td><td>{String(g.title)}</td><td>{String(g.level)}</td><td>{String(g.plan ?? "")}</td></tr>)}</tbody></table>}
        <div className="text-xs text-slate-500 mt-1">Thêm/sửa control & map: <a className="underline" href="/quan-tri?t=controls">controls</a> · <a className="underline" href="/quan-tri?t=clause_controls">clause_controls</a> · gói audit theo chuẩn: <a className="underline" href={`/api/exports/audit-std?std=${sel ?? "VIETGAP-TT"}`}>tải ZIP</a></div></div>
      <div className="text-sm text-slate-600">Số điều khoản là bản tóm tắt''', 1)
    return s
rw("src/components/panels/TuanThu.tsx", tt)
# exports: audit-std zip per standard
rw("src/app/api/exports/[kind]/route.ts", lambda s: s.replace('        case "recon": return csvRes(', '''        case "audit-std": {
          const std = u.searchParams.get("std") ?? "VIETGAP-TT"; const files: Record<string, string> = {};
          const reqs = await q("select r.*, (select string_agg(cc.control_id, ',') from clause_controls cc where cc.requirement_id=r.id) as controls from standard_requirements r where standard_code=$1 order by clause", [std]);
          files["00_dieu_khoan_control.csv"] = csv(reqs);
          const ctls = await q("select c.* from controls c where c.id in (select cc.control_id from clause_controls cc join standard_requirements r on r.id=cc.requirement_id where r.standard_code=$1)", [std]);
          files["01_controls.csv"] = csv(ctls);
          for (const ctl of ctls) { try { const qq = String(ctl.evidence_query ?? ""); if (!/^\\s*select/i.test(qq)) continue; const rows = await q(qq.includes("$1") ? qq : qq + " where $1::text is not null", [farm]); files[`evidence/${ctl.id}.csv`] = csv(rows); } catch (e) { files[`evidence/${ctl.id}.err.txt`] = (e as Error).message; } }
          const tables = [...new Set(reqs.flatMap((r) => (r.evidence_tables as string[]) ?? []))].filter((t) => /^[a-z_]+$/.test(t));
          for (const t of tables) { try { const hasFarm = (await q("select 1 from information_schema.columns where table_name=$1 and column_name='farm_id'", [t])).length > 0; const hasTs = (await q("select 1 from information_schema.columns where table_name=$1 and column_name='ts'", [t])).length > 0; const rows = await q(`select * from ${t} where 1=1 ${hasFarm ? "and farm_id=$1" : ""} ${hasTs ? "and ts::date between $2 and $3" : ""} limit 20000`, hasFarm && hasTs ? [farm, from, to] : hasFarm ? [farm] : hasTs ? [] : []); if (rows.length) files[`data/${t}.csv`] = csv(rows); } catch { /* bảng/view không có → bỏ */ } }
          files["02_checks.csv"] = csv(await q("select c.* from compliance_checks c where c.farm_id=$1 and c.standard_code=$2 order by checked_at desc", [farm, std]));
          files["03_certifications.csv"] = csv(await q("select * from certifications where (farm_id=$1 or farm_id is null) and standard_code=$2", [farm, std]));
          return zipRes(`audit-${std}-${farm}.zip`, files);
        }
        case "recon": return csvRes(''', 1))
# ToChuc: SOP library tab
def tc(s):
    s = s.replace('const cov = useData("process_coverage");', 'const cov = useData("process_coverage"); const lib = useData("sop_library"); const [libQ, setLibQ] = useState("");')
    s = s.replace('useState<"sodo" | "quytrinh" | "thietke" | "chay" | "io" | "bus" | "hoso" | "phu">', 'useState<"sodo" | "quytrinh" | "thietke" | "chay" | "io" | "bus" | "hoso" | "phu" | "sop">')
    s = s.replace('["phu", "Độ phủ theo đối tượng"], ["io", "Đầu vào ↔ đầu ra"]', '["phu", "Độ phủ theo đối tượng"], ["sop", `Thư viện SOP L1→L2→L3 (${(lib.rows ?? []).length})`], ["io", "Đầu vào ↔ đầu ra"]')
    s = s.replace('      {tab === "io" && <div className="space-y-3">', '''      {tab === "sop" && <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-stone-100 rounded-t-2xl flex items-center gap-2 flex-wrap"><b>Thư viện SOP theo bộ gốc (Quyển 3 §15): 8 chuỗi L1 · 81 quy trình L2 · 422 SOP L3</b><input className="input !w-64 !py-1 text-sm" placeholder="tìm SOP…" value={libQ} onChange={(e) => setLibQ(e.target.value)} /><a className="ml-auto underline text-sm" href="/quan-tri?t=sops">sửa · nhập CSV · ban hành</a><a className="underline text-sm" href="/api/admin/sops?csv=1">xuất</a></div>
        {[...new Set((lib.rows ?? []).map((r) => String(r.l1_chain ?? "")))].filter(Boolean).map((l1) => <div key={l1}><div className="px-3 py-1 text-xs font-bold text-emerald-800 bg-emerald-50">{l1}</div>{[...new Set((lib.rows ?? []).filter((r) => r.l1_chain === l1).map((r) => String(r.l2_code)))].map((l2) => { const rows = (lib.rows ?? []).filter((r) => r.l2_code === l2 && (!libQ || JSON.stringify(r).toLowerCase().includes(libQ.toLowerCase()))); return rows.length ? <div key={l2} className="border-b"><div className="px-3 py-1 text-sm font-semibold flex items-center gap-2"><button className="underline" onClick={() => { setSelP(l2); setTab("quytrinh"); }}>{l2}</button> {String(rows[0].l2_name)} <span className="text-xs text-slate-500">· {String(rows[0].dept_code)} · {rows.length} SOP</span></div><div className="px-3 pb-1 flex flex-wrap gap-1">{rows.map((r) => <span key={String(r.code)} className={`rounded-lg border px-2 py-0.5 text-xs ${r.ccp ? "border-red-400 bg-red-50" : r.published_at ? "bg-emerald-50 border-emerald-300" : "bg-white"}`} title={`${r.tools ?? ""} · ${r.evidence ?? ""}${r.ccp ? ` · CCP: ${r.ccp_limit}` : ""}`}><span className="font-mono">{String(r.code)}</span> {String(r.title)}{Array.isArray(r.std_clauses) && (r.std_clauses as string[]).length ? <span className="text-slate-500"> [{(r.std_clauses as string[]).join(",")}]</span> : null}</span>)}</div></div> : null; })}</div>)}
        <div className="p-3 text-xs text-slate-600">Đỏ = SOP có CCP (giới hạn tới hạn + hành động khắc phục) · [mã] = điều khoản chuẩn SOP phục vụ (trường 11) · xanh = đã ban hành. Mỗi SOP L3 = 1 bước trong quy trình L2 (Khai báo quy trình → sửa/thêm bước; xuất bản → thông báo bộ phận).</div></div>}
      {tab === "io" && <div className="space-y-3">''', 1)
    return s
rw("src/components/panels/ToChuc.tsx", tc)
# jobs: gen_compliance_tasks in tasks job
rw("src/app/api/jobs/[job]/route.ts", lambda s: s.replace('out[`monitor:${f}`] = (await adminPool().query("select gen_monitoring_tasks($1) as n", [f])).rows[0].n; }', 'out[`monitor:${f}`] = (await adminPool().query("select gen_monitoring_tasks($1) as n", [f])).rows[0].n; out[`compliance:${f}`] = (await adminPool().query("select gen_compliance_tasks($1) as n", [f])).rows[0].n; await adminPool().query("select refresh_compliance_gaps()"); }'))
