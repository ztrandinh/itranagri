import io, os
R = "F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R + p) or R, exist_ok=True); io.open(R + p, "w", encoding="utf-8", newline="\n").write(s); print("w", p)
def rw(p, fn): s = io.open(R + p, encoding="utf-8").read(); n = fn(s); assert n != s, p; io.open(R + p, "w", encoding="utf-8", newline="\n").write(n); print("ok", p)

# ---- upload: ghi documents (đính kèm mọi đối tượng), UPLOAD_DIR ----
w("src/app/api/upload/route.ts", '''import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { withCtx } from "@/lib/db";
/** Upload file/ảnh → public/uploads/{farm}/ (hoặc UPLOAD_DIR) + (tùy chọn) ghi vào bảng documents gắn đối tượng (ref_table, ref_id, kind, title, tags, expires_on).
 *  Ảnh nén ở client (lib/client). Prod: đổi sang object storage bằng cách thay hàm save(). */
export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const fd = await req.formData(); const f = fd.get("file") as File | null; if (!f) return NextResponse.json({ error: "ERR_NO_FILE" }, { status: 400 });
  if (f.size > 25e6) return NextResponse.json({ error: "ERR_TOO_LARGE" }, { status: 413 });
  const buf = Buffer.from(await f.arrayBuffer()); const sha = createHash("sha256").update(buf).digest("hex");
  const ext = (f.name.split(".").pop() || "bin").toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 8);
  const base = process.env.UPLOAD_DIR ?? join(process.cwd(), "public", "uploads"); const dir = join(base, s.farmId); await mkdir(dir, { recursive: true });
  const name = `${Date.now()}-${sha.slice(0, 16)}.${ext}`; await writeFile(join(dir, name), buf); const url = `/uploads/${s.farmId}/${name}`;
  let doc: Record<string, unknown> | null = null;
  const refTable = fd.get("ref_table"), refId = fd.get("ref_id");
  if (refTable && refId) { doc = await withCtx(s, async (c) => (await c.query("insert into documents(farm_id,ref_table,ref_id,kind,title,file,mime,size_bytes,sha256,tags,expires_on,uploaded_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) returning *", [s.farmId, String(refTable), String(refId), String(fd.get("kind") ?? "FILE"), String(fd.get("title") ?? f.name), url, f.type, buf.length, sha, String(fd.get("tags") ?? "").split(",").map((x) => x.trim()).filter(Boolean), fd.get("expires_on") ? String(fd.get("expires_on")) : null, s.staffId])).rows[0]); }
  return NextResponse.json({ url, sha256: sha, size: buf.length, document: doc });
}
''')
# ---- Attachments component ----
w("src/components/Attachments.tsx", '''"use client";
import { useEffect, useState } from "react";
import { fmt } from "@/lib/client";
type Doc = { id: string; kind: string; title: string; file: string; mime: string | null; size_bytes: number | null; tags: string[]; expires_on: string | null; uploaded_by: string; created_at: string; status: string };
const KINDS = [["FILE", "File"], ["GIAY_PHEP", "Giấy phép/chứng nhận"], ["HOP_DONG", "Hợp đồng"], ["HOA_DON", "Hóa đơn/chứng từ"], ["COA", "COA/kết quả xét nghiệm"], ["ANH", "Ảnh"], ["BAN_VE", "Bản vẽ/sơ đồ"], ["BIEN_BAN", "Biên bản"], ["KHAC", "Khác"]];
/** TÀI LIỆU ĐÍNH KÈM cho mọi đối tượng (ref_table + ref_id): tải lên, loại, thẻ, hạn; hết hạn báo đỏ */
export default function Attachments({ refTable, refId, compact }: { refTable: string; refId: string; compact?: boolean }) {
  const [docs, setDocs] = useState<Doc[]>([]); const [kind, setKind] = useState("FILE"); const [title, setTitle] = useState(""); const [exp, setExp] = useState(""); const [busy, setBusy] = useState(false); const [msg, setMsg] = useState("");
  const load = () => fetch(`/api/admin/documents?q=&limit=200`).then((r) => r.json()).then((j) => setDocs(((j.rows ?? []) as Doc[]).filter((d) => (d as unknown as { ref_table: string; ref_id: string }).ref_table === refTable && (d as unknown as { ref_id: string }).ref_id === refId && d.status !== "ARCHIVED")));
  useEffect(() => { load(); }, [refTable, refId]); // eslint-disable-line react-hooks/exhaustive-deps
  const up = async (f: File) => { setBusy(true); const fd = new FormData(); fd.set("file", f); fd.set("ref_table", refTable); fd.set("ref_id", refId); fd.set("kind", kind); fd.set("title", title || f.name); if (exp) fd.set("expires_on", exp); const j = await fetch("/api/upload", { method: "POST", body: fd }).then((r) => r.json()); setBusy(false); setMsg(j.document ? "Đã đính kèm" : j.error ?? "lỗi"); setTitle(""); load(); };
  return (<div className={compact ? "" : "card"}>
    <div className="flex items-center gap-2 flex-wrap text-sm"><b>📎 Tài liệu đính kèm ({docs.length})</b><select className="input !w-44 !py-1 !text-xs" value={kind} onChange={(e) => setKind(e.target.value)}>{KINDS.map(([k, l]) => <option key={k} value={k}>{l}</option>)}</select><input className="input !w-44 !py-1 !text-xs" placeholder="tiêu đề (tùy chọn)" value={title} onChange={(e) => setTitle(e.target.value)} /><input type="date" className="input !w-36 !py-1 !text-xs" title="hết hạn" value={exp} onChange={(e) => setExp(e.target.value)} /><label className="btn-secondary !py-1 !px-3 !text-sm cursor-pointer">{busy ? "…" : "＋ Tải lên"}<input type="file" className="hidden" onChange={(e) => e.target.files?.[0] && up(e.target.files[0])} /></label>{msg && <span className="text-emerald-700">{msg}</span>}</div>
    <div className="mt-2 flex flex-wrap gap-2">{docs.map((d) => { const expired = d.expires_on && new Date(d.expires_on) < new Date(); return <a key={d.id} href={d.file} target="_blank" className={`rounded-lg border px-2 py-1 text-xs flex items-center gap-1 ${expired ? "border-red-400 bg-red-50" : "bg-white"}`}>{d.mime?.startsWith("image/") ? <img src={d.file} alt="" className="h-8 w-8 object-cover rounded" /> : "📄"}<span><b>{d.title}</b> <span className="text-slate-500">{d.kind}</span>{d.expires_on ? <span className={expired ? "text-red-700" : "text-slate-500"}> · hạn {fmt.d(d.expires_on)}</span> : null}<div className="text-[10px] text-slate-400">{fmt.dt(d.created_at)} · {d.uploaded_by}</div></span></a>; })}{!docs.length && <span className="text-xs text-slate-500">Chưa có tài liệu.</span>}</div>
  </div>);
}
''')
# Obj360 + FarmProfile + QuanTri edit: attach
rw("src/components/panels/Obj360.tsx", lambda s: s.replace('import AnyChart, { RecordsTable } from "@/components/AnyChart";', 'import AnyChart, { RecordsTable } from "@/components/AnyChart";\nimport Attachments from "@/components/Attachments";').replace('      {cfg.charts.length > 0 && <div className="grid md:grid-cols-2 gap-3">', '      <Attachments refTable={cfg.table} refId={id} />\n      {cfg.charts.length > 0 && <div className="grid md:grid-cols-2 gap-3">'))
rw("src/components/panels/FarmProfile.tsx", lambda s: s.replace('import AnyChart from "@/components/AnyChart";', 'import AnyChart from "@/components/AnyChart";\nimport Attachments from "@/components/Attachments";').replace('      <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-stone-100 rounded-t-2xl flex items-center gap-2"><b>Nhà công năng', '      <Attachments refTable="farms" refId={farmId} />\n      <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-stone-100 rounded-t-2xl flex items-center gap-2"><b>Nhà công năng'))
# QuanTri: custom fields (attrs) + attachments in edit
def qt(s):
    s = s.replace('import { RecordsTable } from "@/components/AnyChart";', 'import { RecordsTable } from "@/components/AnyChart";\nimport Attachments from "@/components/Attachments";')
    s = s.replace('const [meta, setMeta] = useState<{ cols: Col[]; canWrite: boolean; table: T } | null>(null);', 'const [meta, setMeta] = useState<{ cols: Col[]; canWrite: boolean; table: T; customFields?: { field: string; label: string; type: string; options?: string[]; required?: boolean }[] } | null>(null);')
    s = s.replace('const cols = useMemo(() => (meta?.cols ?? []).filter((c) => !SYS.has(c.name)), [meta]);', 'const cols = useMemo(() => (meta?.cols ?? []).filter((c) => !SYS.has(c.name) && c.name !== "attrs"), [meta]); const hasAttrs = !!(meta?.cols ?? []).find((c) => c.name === "attrs"); const cfs = meta?.customFields ?? [];')
    # add custom fields UI + attachments after the grid of cols in "them" tab
    s = s.replace('''          {table === "staff" && !edit.id && <label className="text-sm"><span className="text-xs text-stone-500">pin (mặc định 1234)</span>''', '''          {hasAttrs && cfs.length > 0 && <div className="sm:col-span-2 lg:col-span-3 rounded-xl border border-dashed p-2"><div className="text-xs font-bold text-slate-600 mb-1">Trường tùy biến (custom_fields) — <a className="underline" href="/quan-tri?t=custom_fields">định nghĩa</a></div><div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-2">{cfs.map((f) => { const a = (edit.attrs as Record<string, unknown>) ?? {}; const set = (v: unknown) => setEdit({ ...edit, attrs: { ...a, [f.field]: v } }); return <label key={f.field} className="text-sm"><span className="text-xs text-stone-500">{f.label}{f.required ? " *" : ""}</span>{f.type === "select" ? <select className="input" value={String(a[f.field] ?? "")} onChange={(e) => set(e.target.value)}><option value="">—</option>{(f.options ?? []).map((o) => <option key={o}>{o}</option>)}</select> : f.type === "bool" ? <select className="input" value={a[f.field] == null ? "" : String(a[f.field])} onChange={(e) => set(e.target.value === "" ? null : e.target.value === "true")}><option value="">—</option><option value="true">Có</option><option value="false">Không</option></select> : <input className="input" type={f.type === "number" ? "number" : f.type === "date" ? "date" : "text"} value={String(a[f.field] ?? "")} onChange={(e) => set(f.type === "number" ? Number(e.target.value) : e.target.value)} />}</label>; })}</div></div>}
          {hasAttrs && !cfs.length && <div className="text-xs text-slate-500 sm:col-span-2 lg:col-span-3">Bảng này hỗ trợ trường tùy biến — <a className="underline" href="/quan-tri?t=custom_fields">thêm định nghĩa</a> (table_name = {table}).</div>}
          {edit[t?.pk ?? "id"] ? <div className="sm:col-span-2 lg:col-span-3"><Attachments refTable={table} refId={String(edit[t?.pk ?? "id"])} compact /></div> : null}
          {table === "staff" && !edit.id && <label className="text-sm"><span className="text-xs text-stone-500">pin (mặc định 1234)</span>''')
    return s
rw("src/components/panels/QuanTri.tsx", qt)
# admin API: attrs jsonb accepted (already generic jsonb handled). custom_fields validation required: skip.

# ---- Phê duyệt inbox ----
w("src/components/panels/PheDuyet.tsx", '''"use client";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";
type R = Record<string, unknown>;
/** HỘP PHÊ DUYỆT: mọi thứ đang chờ tôi duyệt (đề nghị chi 2 chữ ký, điều chỉnh kho, checklist, PO, đơn giảm giá, nghỉ phép, NC) — bấm 1 nút; không ai duyệt việc của mình (DB chặn) */
export default function PheDuyet({ sess }: { sess: Sess }) {
  const exp = useData("expenses_pending"); const adj = useData("adjustments_pending"); const chk = useData("checklists_pending"); const po = useData("po_pending"); const leave = useData("leave_pending"); const nc = useData("nc_open");
  const role = sess.role; const canMoney = ["director", "owner", "accountant"].includes(role); const canOps = ["tech_head", "director", "owner"].includes(role);
  const reload = () => { exp.reload(); adj.reload(); chk.reload(); po.reload(); leave.reload(); nc.reload(); };
  const total = (exp.rows?.length ?? 0) + (adj.rows?.length ?? 0) + (chk.rows?.length ?? 0) + (po.rows?.length ?? 0) + (leave.rows?.length ?? 0);
  return (<div className="space-y-3">
    <div className="grid grid-cols-2 sm:grid-cols-6 gap-2">{[["Tổng chờ", total], ["Đề nghị chi", exp.rows?.length], ["Điều chỉnh kho", adj.rows?.length], ["Checklist", chk.rows?.length], ["PO", po.rows?.length], ["Nghỉ phép", leave.rows?.length]].map(([l, v]) => <div key={String(l)} className="kpi !p-2"><div className="l">{String(l)}</div><div className="text-2xl font-black">{String(v ?? 0)}</div></div>)}</div>
    {canMoney && <Sec title="Đề nghị chi (>20tr cần 2 chữ ký · >50tr báo chủ)" rows={exp.rows ?? []} cols={[["ts", "Lúc"], ["requested_by", "Người đề nghị"], ["amount", "Số tiền"], ["cost_center", "CC"], ["purpose", "Mục đích"], ["status", "TT"]]} actions={(r) => <><button className="btn-primary !py-1 !px-2 !text-xs mr-1" onClick={async () => { const j = await act("approve_expense", { id: r.id, approve: true }); if (j.error) alert(j.error); reload(); }}>Duyệt</button><button className="btn-secondary !py-1 !px-2 !text-xs" onClick={async () => { await act("approve_expense", { id: r.id, approve: false }); reload(); }}>Từ chối</button></>} />}
    {canOps && <Sec title="Điều chỉnh kho / kiểm kê" rows={adj.rows ?? []} cols={[["ts", "Lúc"], ["created_by", "Người tạo"], ["sku", "Hàng"], ["delta", "±"], ["reason", "Lý do"]]} actions={(r) => <><button className="btn-primary !py-1 !px-2 !text-xs mr-1" onClick={async () => { const j = await act("approve_adjustment", { id: r.id, approve: true }); if (j.error) alert(j.error); reload(); }}>Duyệt</button><button className="btn-secondary !py-1 !px-2 !text-xs" onClick={async () => { await act("approve_adjustment", { id: r.id, approve: false }); reload(); }}>Từ chối</button></>} />}
    {(canOps || role === "team_lead") && <Sec title="Checklist chờ duyệt" rows={chk.rows ?? []} cols={[["ts", "Lúc"], ["created_by", "Người ghi"], ["sop_code", "SOP"], ["shift", "Ca"], ["all_green", "Xanh hết"]]} actions={(r) => <button className="btn-primary !py-1 !px-2 !text-xs" onClick={async () => { const j = await act("approve_checklist", { id: r.id }); if (j.error) alert(j.error); reload(); }}>Duyệt</button>} />}
    {canMoney && <Sec title="Đơn mua (PO) chờ duyệt" rows={po.rows ?? []} cols={[["ts", "Lúc"], ["created_by", "Người tạo"], ["supplier_id", "NCC"], ["total", "Tổng"], ["po_status", "TT"]]} actions={(r) => <><button className="btn-primary !py-1 !px-2 !text-xs mr-1" onClick={async () => { const j = await act("po_status", { id: r.id, status: "DUYET" }); if (j.error) alert(j.error); reload(); }}>Duyệt</button><button className="btn-secondary !py-1 !px-2 !text-xs" onClick={async () => { await act("po_status", { id: r.id, status: "HUY" }); reload(); }}>Hủy</button></>} />}
    {(canOps || canMoney || role === "team_lead") && <Sec title="Nghỉ phép chờ duyệt" rows={leave.rows ?? []} cols={[["created_at", "Lúc"], ["staff_id", "Nhân sự"], ["kind", "Loại"], ["from_date", "Từ"], ["to_date", "Đến"], ["days", "Ngày"], ["reason", "Lý do"]]} actions={(r) => <><button className="btn-primary !py-1 !px-2 !text-xs mr-1" onClick={async () => { await fetch("/api/admin/leave_requests", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ row: { id: r.id, status: "DUYET", approved_by: sess.staffId, approved_at: new Date().toISOString() } }) }); reload(); }}>Duyệt</button><button className="btn-secondary !py-1 !px-2 !text-xs" onClick={async () => { await fetch("/api/admin/leave_requests", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ row: { id: r.id, status: "TU_CHOI", approved_by: sess.staffId, approved_at: new Date().toISOString() } }) }); reload(); }}>Từ chối</button></>} />}
    <Sec title="Điểm không phù hợp (NC) đang mở — theo dõi khắc phục" rows={nc.rows ?? []} cols={[["checked_at", "Lúc"], ["standard_code", "Chuẩn"], ["nc_severity", "Mức"], ["evidence", "Bằng chứng"], ["due_date", "Hạn"]]} actions={() => <a className="underline text-xs" href="/tuan-thu">xử lý</a>} />
  </div>);
}
function Sec({ title, rows, cols, actions }: { title: string; rows: R[]; cols: [string, string][]; actions: (r: R) => React.ReactNode }) {
  return <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-slate-100 rounded-t-xl font-bold">{title} ({rows.length})</div>{rows.length ? <table className="tbl text-sm"><thead><tr>{cols.map(([k, l]) => <th key={k} className="pl-2">{l}</th>)}<th></th></tr></thead><tbody>{rows.map((r, i) => <tr key={String(r.id ?? i)}>{cols.map(([k]) => <td key={k} className="pl-2">{/ts|_at|date/.test(k) && r[k] ? (String(r[k]).length > 10 ? fmt.dt(r[k]) : fmt.d(r[k])) : k === "amount" || k === "total" ? fmt.vnd(r[k]) : typeof r[k] === "boolean" ? (r[k] ? "✓" : "✗") : String(r[k] ?? "")}</td>)}<td className="whitespace-nowrap">{actions(r)}</td></tr>)}</tbody></table> : <div className="p-3 text-slate-500 text-sm">Không có.</div>}</div>;
}
''')
w("src/app/phe-duyet/page.tsx", '''import { Page } from "@/components/withSession"; import PheDuyet from "@/components/panels/PheDuyet";
export default function P() { return <Page title="Phê duyệt — mọi thứ đang chờ tôi">{(s) => <PheDuyet sess={s} />}</Page>; }
''')
rw("src/lib/queries.ts", lambda s: s.replace("  me: {", '''  expenses_pending: { sql: "select * from expense_requests where farm_id=$1 and status in ('CHO','CHO_KY_2','CHO_DUYET') order by ts" },
  checklists_pending: { sql: "select * from checklist_runs where farm_id=$1 and status='ACTIVE' and approved_by is null order by ts desc limit 200" },
  po_pending: { sql: "select * from purchase_orders where farm_id=$1 and po_status in ('MOI','CHO_DUYET') order by ts" },
  leave_pending: { sql: "select * from leave_requests where farm_id=$1 and status='CHO' order by created_at" },
  nc_open: { sql: "select * from compliance_checks where farm_id=$1 and result='KHONG_DAT' and closed_at is null order by checked_at desc" },
  attendance_month: { sql: "select a.*, s.full_name from v_attendance_month a join staff s on s.id=a.staff_id where a.farm_id=$1 and a.month >= date_trunc('month', now()) - interval '2 months' order by month desc, staff_id" },
  attendance_today: { sql: "select a.*, s.full_name from attendance a join staff s on s.id=a.staff_id where a.farm_id=$1 and a.day=current_date order by check_in" },
  my_attendance: { sql: "select * from attendance where farm_id=$1 and staff_id=app_staff() order by day desc limit 40" },
  leave_all: { sql: "select l.*, s.full_name from leave_requests l join staff s on s.id=l.staff_id where l.farm_id=$1 order by created_at desc limit 200" },
  gl_trial_balance: { sql: "select * from v_gl_trial_balance where farm_id=$1 and period >= date_trunc('month', now()) - interval '3 months' order by period desc, acct" },
  gl_ledger: { sql: "select * from v_gl_ledger where farm_id=$1 order by ts desc limit 500" },
  gl_accounts: { sql: "select * from gl_accounts where active order by code" },
  ghg_month: { sql: "select * from v_ghg_month where farm_id=$1 order by month desc, species" },
  me: {''', 1))
rw("src/lib/admin.ts", lambda s: s.replace('  { table: "documents", pk: "id",', '''  { table: "attendance", pk: "id", label: "Chấm công", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "accountant", "team_lead", "tech_head", "worker", "it_engineer"] },
  { table: "leave_requests", pk: "id", label: "Nghỉ phép", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "accountant", "team_lead", "tech_head", "worker", "it_engineer"] },
  { table: "journal_entries", pk: "id", label: "Kế toán · bút toán (sổ nhật ký chung)", group: "Kế toán", farmScoped: true, softDelete: null, writeRoles: ["owner", "accountant"] },
  { table: "gl_accounts", pk: "code", label: "Kế toán · hệ thống tài khoản", group: "Kế toán", farmScoped: false, softDelete: "active", writeRoles: ["owner", "accountant"] },
  { table: "notification_deliveries", pk: "id", label: "Nhật ký gửi Zalo/SMS/Email", group: "Tích hợp", farmScoped: false, softDelete: null, writeRoles: ["owner", "it_engineer"] },
  { table: "webhook_deliveries", pk: "id", label: "Nhật ký webhook", group: "Tích hợp", farmScoped: false, softDelete: null, writeRoles: ["owner", "it_engineer"] },
  { table: "login_attempts", pk: "ts", label: "Nhật ký đăng nhập", group: "Tích hợp", farmScoped: false, softDelete: null, writeRoles: ["owner", "it_engineer"] },
  { table: "documents", pk: "id",''', 1))
# nav
rw("src/components/Shell.tsx", lambda s: s.replace('{ key: "ca", icon: "📝", label: "Ghi chép hàng ngày", desc: "Việc của tôi, 3 chạm theo vị trí, phiếu giấy", roles: ["*"], items: [{ href: "/ca", label: "Ca của tôi" }, { href: "/giay", label: "Phiếu giấy" }, { href: "/sop", label: "SOP" }] },', '{ key: "ca", icon: "📝", label: "Ghi chép hàng ngày", desc: "Việc của tôi, 3 chạm theo vị trí, phiếu giấy, phê duyệt", roles: ["*"], items: [{ href: "/ca", label: "Ca của tôi" }, { href: "/phe-duyet", label: "Phê duyệt", roles: ["team_lead", "tech_head", "director", "owner", "accountant"] }, { href: "/giay", label: "Phiếu giấy" }, { href: "/sop", label: "SOP" }] },'))
