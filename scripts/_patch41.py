import io, os
R="F:/ITRAN FARM/itran-os/"
def w(p, s): io.open(R+p,"w",encoding="utf-8",newline="\n").write(s); print("w",p)
def rw(p, fn): s=io.open(R+p,encoding="utf-8").read(); n=fn(s); assert n!=s, p; io.open(R+p,"w",encoding="utf-8",newline="\n").write(n); print("ok",p)

# 1) queries
rw("src/lib/queries.ts", lambda s: s.replace("  my_attendance:", '''  my_inbox: { sql: "select * from my_inbox($1, app_staff(), app_role()) limit 400", ttl: 20 },
  my_inbox_counts: { sql: "select kind, count(*)::int as n, min(due_at) as first_due from my_inbox($1, app_staff(), app_role()) group by 1", ttl: 20 },
  suggest_delegates: { sql: "select * from suggest_delegates($1, coalesce(nullif($2,''), app_staff()), $3::date, $4::date)", params: ["staff", "from", "to"] },
  my_delegations: { sql: "select d.*, f.full_name as from_name, t.full_name as to_name from staff_delegations d join staff f on f.id=d.from_staff join staff t on t.id=d.to_staff where d.farm_id=$1 and (d.from_staff=app_staff() or d.to_staff=app_staff() or app_role() in ('owner','director','tech_head','team_lead','accountant')) order by d.status='ACTIVE' desc, d.from_date desc limit 100" },
  dept_discipline: { sql: "select * from v_dept_discipline where farm_id=$1 order by overdue desc", ttl: 60 },
  my_attendance:''',1))
# per-staff cache key
rw("src/app/api/data/[view]/route.ts", lambda s: s.replace("const memKey = `${farm}|${sess.role}|${view}|${args.join(\",\")}`;","const memKey = `${farm}|${sess.role}|${sess.staffId}|${view}|${args.join(\",\")}`;",1))
# 2) actions: delegate manual + end
rw("src/app/api/actions/route.ts", lambda s: s.replace('        case "refresh_cache":', '''        case "delegate": { // ủy quyền thủ công (công tác/đi vắng): from mặc định = tôi
          const b = body as { from?: string; to: string; from_date: string; to_date: string; reason?: string };
          if (!b.to || !b.from_date || !b.to_date) return NextResponse.json({ error: "ERR_MISSING", detail: "to/from_date/to_date" }, { status: 400 });
          const from = b.from && ["owner", "director", "tech_head", "team_lead"].includes(s.role) ? b.from : s.staffId;
          if (from === b.to) return NextResponse.json({ error: "ERR_SELF", detail: "Không tự ủy quyền cho mình" }, { status: 400 });
          const r = await c.query("select activate_delegation($1,$2,$3,$4::date,$5::date,$6,'MANUAL',null,$7) as id", [s.farmId, from, b.to, b.from_date, b.to_date, b.reason ?? "Ủy quyền", s.staffId]);
          return NextResponse.json({ ok: true, id: r.rows[0].id });
        }
        case "end_delegation": { const b = body as { id: string };
          await c.query("update staff_delegations set status='CANCELLED', ended_at=now(), to_date=least(to_date, current_date-1) where id=$1 and farm_id=$2 and status='ACTIVE' and (from_staff=$3 or to_staff=$3 or $4 in ('owner','director','tech_head','team_lead'))", [b.id, s.farmId, s.staffId, s.role]);
          await c.query("update tasks set assignee_id=detail->>'delegated_from', detail=detail - 'delegated_from' where farm_id=$1 and status in ('MO','DANG_LAM','TREO') and detail->>'delegation_id'=$2", [s.farmId, b.id]);
          return NextResponse.json({ ok: true }); }
        case "refresh_cache":''',1))
# 3) job daily: end_delegations
rw("src/app/api/jobs/[job]/route.ts", lambda s: s.replace('    if (job === "tasks" || job === "all") { out[`tasks:${f}`]', '    if (job === "tasks" || job === "all") { out[`deleg_end:${f}`] = (await adminPool().query("select end_delegations($1) as n", [f])).rows[0].n; out[`tasks:${f}`]',1))
# 4) TodayBar + PageNav components
w("src/components/TodayBar.tsx", '''"use client";
import { useEffect, useState } from "react";
import { useData, fmt } from "@/lib/client";
type Row = Record<string, unknown>;
const KIND: Record<string, [string, string]> = { VIEC: ["Việc", "bg-emerald-100 text-emerald-900"], DUYET: ["Chờ tôi duyệt", "bg-amber-100 text-amber-900"], TIN: ["Tin chưa đọc", "bg-sky-100 text-sky-900"], DAO_TAO_HOC: ["Học tuần này", "bg-violet-100 text-violet-900"], DAO_TAO_DAY: ["Dạy tuần này", "bg-violet-100 text-violet-900"], GIAM_SAT: ["Lượt kiểm tra", "bg-rose-100 text-rose-900"], THAY: ["Thay người", "bg-slate-200 text-slate-800"] };
/** HÔM NAY CỦA TÔI — hộp việc thống nhất mọi nguồn (việc/duyệt/tin/đào tạo/giám sát/thay người), đặt đầu mọi trang; thu gọn nhớ theo người */
export default function TodayBar() {
  const counts = useData<Row>("my_inbox_counts"); const [open, setOpen] = useState(false); const [filter, setFilter] = useState<string | null>(null);
  const list = useData<Row>(open ? "my_inbox" : null);
  useEffect(() => { try { setOpen(localStorage.getItem("today:open") === "1"); } catch { /* ignore */ } }, []);
  const toggle = () => { const v = !open; setOpen(v); try { localStorage.setItem("today:open", v ? "1" : "0"); } catch { /* ignore */ } };
  const rows = counts.rows ?? []; const total = rows.reduce((a, r) => a + Number(r.n), 0);
  const items = (list.rows ?? []).filter((r) => !filter || r.kind === filter).slice(0, 40);
  return <div className="rounded-xl border bg-white px-3 py-2 mb-3 text-sm shadow-sm">
    <div className="flex items-center gap-2 flex-wrap">
      <button className="font-black" onClick={toggle}>{open ? "▾" : "▸"} Hôm nay của tôi <span className="text-slate-500 font-normal">({total})</span></button>
      {rows.map((r) => { const k = String(r.kind); const [lbl, cls] = KIND[k] ?? [k, "bg-slate-100"]; return <button key={k} className={`px-2 py-0.5 rounded-full text-xs font-semibold ${cls} ${filter === k ? "ring-2 ring-slate-500" : ""}`} onClick={() => { setFilter(filter === k ? null : k); if (!open) toggle(); }}>{lbl}: {String(r.n)}</button>; })}
      {total === 0 && !counts.loading && <span className="text-xs text-emerald-700">✓ Không có việc tồn — làm tốt!</span>}
      <a className="ml-auto text-xs underline text-slate-600" href="/ca">Ca của tôi</a><a className="text-xs underline text-slate-600" href="/phe-duyet">Phê duyệt</a><a className="text-xs underline text-slate-600" href="/thong-bao">Tin</a>
    </div>
    {open && <div className="mt-2 max-h-72 overflow-auto divide-y">
      {items.map((r, i) => { const k = String(r.kind); const [lbl, cls] = KIND[k] ?? [k, "bg-slate-100"]; const late = r.due_at && new Date(String(r.due_at)) < new Date(); return <a key={i} href={String(r.link ?? "/ca")} className="flex items-center gap-2 py-1.5 hover:bg-slate-50">
        <span className={`px-1.5 rounded text-[11px] font-bold shrink-0 ${cls}`}>{lbl}</span>
        <span className={`shrink-0 text-[11px] font-bold ${r.priority === "KHAN" ? "text-red-700" : r.priority === "CAO" ? "text-amber-700" : "text-slate-400"}`}>{r.priority === "KHAN" ? "KHẨN" : r.priority === "CAO" ? "CAO" : ""}</span>
        <span className="truncate flex-1"><b>{String(r.title)}</b>{r.detail ? <span className="text-slate-500"> — {String(r.detail).slice(0, 80)}</span> : null}{r.on_behalf ? <span className="ml-1 text-[11px] rounded bg-slate-200 px-1">thay {String(r.on_behalf)}</span> : null}</span>
        <span className={`shrink-0 text-xs ${late ? "text-red-600 font-bold" : "text-slate-500"}`}>{r.due_at ? fmt.dt(r.due_at) : ""}</span></a>; })}
      {list.loading && <div className="text-xs text-slate-500 py-2">đang tải…</div>}
      {!list.loading && items.length === 0 && <div className="text-xs text-slate-500 py-2">Không có mục nào.</div>}
      {(list.rows?.length ?? 0) > 40 && <div className="text-xs text-slate-500 py-1">Hiện 40 mục đầu — vào <a className="underline" href="/ca">Ca của tôi</a> để xem hết.</div>}
    </div>}
  </div>;
}
''')
w("src/components/PageNav.tsx", '''"use client";
import { DEPT_HOME } from "@/lib/modules";
/** Thanh điều hướng trong app: ← Quay lại · Phòng tôi · Trang chủ · Tiếp → (không bắt người dùng dùng nút back của trình duyệt) */
export default function PageNav({ dept, title }: { dept?: string | null; title?: string }) {
  const home = (dept && DEPT_HOME[dept]) || "/trang-chu";
  const back = () => { if (typeof window !== "undefined" && window.history.length > 1 && document.referrer.startsWith(window.location.origin)) window.history.back(); else window.location.href = home; };
  return <div className="flex items-center gap-1 mb-2 text-sm">
    <button type="button" className="px-2 py-1 rounded-lg border bg-white hover:bg-slate-50 font-semibold" onClick={back} title="Quay lại trang trước">← Quay lại</button>
    <a className="px-2 py-1 rounded-lg border bg-white hover:bg-slate-50 font-semibold" href={home} title="Về phòng của tôi">🏠 Phòng tôi</a>
    <a className="px-2 py-1 rounded-lg border bg-white hover:bg-slate-50" href="/trang-chu" title="Trang chủ">Trang chủ</a>
    <button type="button" className="px-2 py-1 rounded-lg border bg-white hover:bg-slate-50 font-semibold" onClick={() => window.history.forward()} title="Tiến tới trang vừa quay lại">Tiếp →</button>
    {title && <span className="ml-2 text-slate-500 truncate hidden sm:inline">/ {title}</span>}
  </div>;
}
''')
rw("src/components/withSession.tsx", lambda s: s.replace('import ModuleIntro from "@/components/ModuleIntro";','import ModuleIntro from "@/components/ModuleIntro";\nimport TodayBar from "@/components/TodayBar";\nimport PageNav from "@/components/PageNav";',1).replace('<Shell sess={sess} title={title}><ModuleIntro path={path.split("?")[0]} />{children(sess)}</Shell>','<Shell sess={sess} title={title}><PageNav dept={sess.dept} title={title} /><TodayBar /><ModuleIntro path={path.split("?")[0]} />{children(sess)}</Shell>',1))
# 5) Tabs: prev/next arrows
rw("src/components/Tabs.tsx", lambda s: s.replace('  return (\n    <div className="flex items-start gap-2">','  const idx = items.findIndex(([k]) => k === value); const go = (d: number) => { const n = items[(idx + d + items.length) % items.length]; if (n) onChange(n[0]); };\n  return (\n    <div className="flex items-start gap-2">\n      <button type="button" className="px-2 py-1.5 rounded-lg border bg-white text-slate-600 hover:bg-emerald-50 shrink-0" title="Tab trước" onClick={() => go(-1)}>‹</button>',1).replace('      {right && <div className="shrink-0">{right}</div>}','      <button type="button" className="px-2 py-1.5 rounded-lg border bg-white text-slate-600 hover:bg-emerald-50 shrink-0" title="Tab tiếp" onClick={() => go(1)}>›</button>\n      {right && <div className="shrink-0">{right}</div>}',1))
# 6) Leave form: delegate + handover
def more(s):
    s=s.replace('const leaves = useData("leave_all"); const staff = useData("staff_all");','const leaves = useData("leave_all"); const staff = useData("staff_all"); const deleg = useData("my_delegations");',1)
    s=s.replace('setLf({ kind: "PHEP", from_date: new Date().toISOString().slice(0, 10), to_date: new Date().toISOString().slice(0, 10), days: 1 })','setLf({ kind: "PHEP", from_date: new Date().toISOString().slice(0, 10), to_date: new Date().toISOString().slice(0, 10), days: 1, delegate_id: "", handover_note: "" })',1)
    s=s.replace('<input className="input" placeholder="Lý do" value={String(lf.reason ?? "")} onChange={(e) => setLf({ ...lf, reason: e.target.value })} /><div className="flex gap-2"><button className="btn-primary !py-2" onClick={async () => { const j = await adminPost("leave_requests", { ...lf, staff_id: sess.staffId });',
      '<input className="input" placeholder="Lý do" value={String(lf.reason ?? "")} onChange={(e) => setLf({ ...lf, reason: e.target.value })} /><DelegatePick from={String(lf.from_date)} to={String(lf.to_date)} value={String(lf.delegate_id ?? "")} onChange={(v) => setLf({ ...lf, delegate_id: v })} /><input className="input sm:col-span-3" placeholder="Bàn giao gì: việc dở dang, sổ ghi, chìa khóa, báo cáo phải nộp…" value={String(lf.handover_note ?? "")} onChange={(e) => setLf({ ...lf, handover_note: e.target.value })} /><div className="flex gap-2"><button className="btn-primary !py-2" onClick={async () => { if (!lf.delegate_id) { if (!confirm("Chưa chọn người thay — việc của bạn sẽ không ai nhận trong kỳ nghỉ. Vẫn gửi?")) return; } const j = await adminPost("leave_requests", { ...lf, delegate_id: lf.delegate_id || null, staff_id: sess.staffId });',1)
    s=s.replace('setMsg(j.ok ? "Đã gửi đơn — chờ duyệt ở Phê duyệt" : `${j.error}`);','setMsg(j.ok ? "Đã gửi đơn — quản lý trực tiếp đã nhận tin; khi duyệt, việc sẽ tự chuyển sang người thay" : `${j.error}`);',1)
    # delegations table after leaves table
    s=s.replace('    <div className="text-xs text-slate-500">{(staff.rows ?? []).length} nhân sự · lương = KPI',
      '''    <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-slate-100 rounded-t-xl font-bold flex items-center gap-2">Thay người / ủy quyền ({(deleg.rows ?? []).filter((r) => r.status === "ACTIVE").length} đang hiệu lực)<span className="text-xs font-normal text-slate-500">— nghỉ được duyệt có người thay ⇒ việc tự chuyển; hết kỳ tự trả về</span><ManualDelegate onDone={() => deleg.reload()} /></div><table className="tbl text-sm"><thead><tr><th className="pl-3">Người nghỉ/vắng</th><th>Người thay</th><th>Từ</th><th>Đến</th><th>Lý do</th><th className="text-right">Việc chuyển</th><th>TT</th><th></th></tr></thead><tbody>{(deleg.rows ?? []).map((r) => <tr key={String(r.id)}><td className="pl-3">{String(r.from_name)}</td><td>{String(r.to_name)}</td><td>{fmt.d(r.from_date)}</td><td>{fmt.d(r.to_date)}</td><td>{String(r.reason ?? "")}</td><td className="text-right">{String(r.tasks_moved)}</td><td>{r.status === "ACTIVE" ? <span className="b-grn">đang thay</span> : <span className="b-gray">{String(r.status)}</span>}</td><td>{r.status === "ACTIVE" && (r.from_staff === sess.staffId || r.to_staff === sess.staffId || canMgr) && <button className="text-xs underline" onClick={async () => { await act("end_delegation", { id: r.id }); deleg.reload(); }}>kết thúc sớm</button>}</td></tr>)}</tbody></table></div>
    <div className="text-xs text-slate-500">{(staff.rows ?? []).length} nhân sự · lương = KPI''',1)
    # helper components at end of file
    s += '''
/** Chọn người thay khi nghỉ: gợi ý cùng phòng/cùng vị trí, đang rảnh, không nghỉ trùng */
function DelegatePick({ from, to, value, onChange }: { from: string; to: string; value: string; onChange: (v: string) => void }) {
  const sug = useData("suggest_delegates", { from, to }, [from, to]);
  return <select className="input" value={value} onChange={(e) => onChange(e.target.value)} title="Người thay tôi ghi chép & báo cáo trong kỳ nghỉ">
    <option value="">— Người thay (bắt buộc nên chọn) —</option>
    {(sug.rows ?? []).map((r) => <option key={String(r.staff_id)} value={String(r.staff_id)}>{String(r.full_name)} · {String(r.position_name ?? r.dept ?? "")}{r.same_position ? " ✓ cùng vị trí" : ""} · {String(r.load)} việc</option>)}
  </select>;
}
/** Ủy quyền thủ công (đi công tác/họp/vắng không phải nghỉ phép) */
function ManualDelegate({ onDone }: { onDone: () => void }) {
  const [f, setF] = useState<{ to: string; from_date: string; to_date: string; reason: string } | null>(null); const [m, setM] = useState("");
  if (!f) return <button className="ml-auto btn-secondary !py-1 !text-xs" onClick={() => setF({ to: "", from_date: new Date().toISOString().slice(0, 10), to_date: new Date().toISOString().slice(0, 10), reason: "Đi công tác" })}>＋ Ủy quyền</button>;
  return <div className="ml-auto flex flex-wrap gap-1 items-center font-normal"><DelegatePick from={f.from_date} to={f.to_date} value={f.to} onChange={(v) => setF({ ...f, to: v })} /><input className="input !py-1" type="date" value={f.from_date} onChange={(e) => setF({ ...f, from_date: e.target.value })} /><input className="input !py-1" type="date" value={f.to_date} onChange={(e) => setF({ ...f, to_date: e.target.value })} /><input className="input !py-1" value={f.reason} onChange={(e) => setF({ ...f, reason: e.target.value })} /><button className="btn-primary !py-1 !text-xs" onClick={async () => { const j = await act("delegate", f); setM(j.error ? String(j.error) : "OK"); if (!j.error) { setF(null); onDone(); } }}>Lưu</button><button className="btn-secondary !py-1 !text-xs" onClick={() => setF(null)}>Hủy</button><span className="text-xs">{m}</span></div>;
}
'''
    return s
rw("src/components/panels/More.tsx", more)
# 7) PheDuyet leave: show delegate
rw("src/components/panels/PheDuyet.tsx", lambda s: s.replace('["days", "Ngày"], ["reason", "Lý do"]]} actions={(r) => <><button className="btn-primary !py-1 !px-2 !text-xs mr-1" onClick={async () => { await fetch("/api/admin/leave_requests"','["days", "Ngày"], ["reason", "Lý do"], ["delegate_id", "Người thay"], ["handover_note", "Bàn giao"]]} actions={(r) => <><button className="btn-primary !py-1 !px-2 !text-xs mr-1" onClick={async () => { if (!r.delegate_id && !confirm("Đơn này CHƯA có người thay — duyệt thì việc của người nghỉ không ai nhận. Vẫn duyệt?")) return; await fetch("/api/admin/leave_requests"',1))
# 8) modules registry: nhan-su purpose mention; roles: new views for all
rw("src/lib/roles.ts", lambda s: s.replace('export const VIEW_ROLES', '// my_inbox / suggest_delegates / my_delegations: mọi vai (RLS + app_staff)\nexport const VIEW_ROLES',1))
