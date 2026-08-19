"use client";
import Tabs from "@/components/Tabs";
import { useEffect, useMemo, useState } from "react";
import ThreeTap from "@/components/ThreeTap";
import { buildForms, formsForPosition, type Ref } from "@/lib/forms";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";
import { usePrompt } from "@/components/ui/PromptDialog";
import { useUrlTab } from "@/lib/useUrlTab";

type Task = { id: string; kind: string; title: string; due_at: string; priority: string; status: string; role_hint: string | null; sop_code: string | null; target_type: string | null; target_id: string | null; handover_note: string | null };
type Note = { id: string; ts: string; note: string; by_name: string; ack_by: string | null; dept: string | null };

export default function CaPanel({ sess, forceForms }: { sess: Sess; forceForms?: string[] }) {
  const animals = useData("animals"), groups = useData("animal_groups"), warehouses = useData("warehouses"), products = useData("products"),
    plots = useData("plots"), recipes = useData("recipes"), locations = useData("locations"), sops = useData("sops"), devices = useData("devices"), partners = useData("partners");
  const tasks = useData<Task>("tasks_today"); const notes = useData<Note>("shift_notes"); const recent = useData("events_recent");
  const [form, setForm] = useState<string | null>(null);
  const [noteTxt, setNoteTxt] = useState("");
  // Đọc ?tab= để nút "✍ Ghi" ở thanh dưới (BottomNav) mở đúng tab Ghi 3 chạm
  const [tab, setTab] = useUrlTab(["viec", "ghi", "giaoca", "gan_day"] as const, "viec");
  const { prompt, promptElement } = usePrompt();
  const ref: Ref | null = useMemo(() => animals.rows && groups.rows && warehouses.rows && products.rows && plots.rows && recipes.rows && locations.rows && sops.rows && devices.rows && partners.rows
    ? { animals: animals.rows, groups: groups.rows, warehouses: warehouses.rows, products: products.rows, plots: plots.rows, recipes: recipes.rows, locations: locations.rows, sops: sops.rows, devices: devices.rows, partners: partners.rows } : null,
    [animals.rows, groups.rows, warehouses.rows, products.rows, plots.rows, recipes.rows, locations.rows, sops.rows, devices.rows, partners.rows]);
  const forms = useMemo(() => (ref ? buildForms(ref, sess.farmId) : null), [ref, sess.farmId]);
  const keys = forceForms ?? formsForPosition(sess.position, sess.role, sess.dept);
  // Giữ NGUYÊN một đối tượng spec cho mỗi form: nếu dựng object mới mỗi lần re-render thì
  // ThreeTap bị reset liên tục và công nhân mất dữ liệu đang nhập.
  const reloadRecent = recent.reload;
  const spec = useMemo(() => (forms && form && forms[form] ? { ...forms[form], onDone: () => { reloadRecent(); } } : null), [forms, form, reloadRecent]);
  const myRoleKey = sess.position?.match(/A\d{1,2}/)?.[0];
  const myTasks = (tasks.rows ?? []).filter((t) => !t.role_hint || t.role_hint === sess.role || (myRoleKey && t.role_hint === `worker:${myRoleKey}`) || (t.role_hint?.startsWith("worker:") && sess.role !== "worker") || ["tech_head","director","owner"].includes(sess.role));
  useEffect(() => { void act("generate_tasks", {}).then(() => tasks.reload()); /* sinh việc khi mở ca */ // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  const overdue = myTasks.filter((t) => new Date(t.due_at) < new Date() && t.status !== "XONG");
  return (
    <div className="space-y-4">
      {promptElement}
      <Tabs value={tab} onChange={(k) => setTab(k as typeof tab)} items={[["viec", `Việc hôm nay (${myTasks.length}${overdue.length ? ` · ${overdue.length} quá hạn` : ""})`], ["ghi", "Ghi 3 chạm"], ["giaoca", "Giao ca"], ["gan_day", "Gần đây"]]} />
      
      {tab === "viec" && (
        <div className="space-y-2">
          {!myTasks.length && <div className="card text-stone-500">Không có việc đến hạn. Bấm "Ghi 3 chạm" để ghi việc thường ngày.</div>}
          {myTasks.map((t) => (
            <div key={t.id} className={`card flex items-start gap-3 ${t.priority === "KHAN" ? "border-red-300" : t.priority === "CAO" ? "border-amber-300" : ""}`}>
              <div className="flex-1">
                <div className="font-semibold">{t.title}</div>
                <div className="text-sm text-stone-500">{t.kind} · hạn {fmt.dt(t.due_at)} {new Date(t.due_at) < new Date() && <span className="b-red ml-1">quá hạn</span>} {t.sop_code && <a className="underline ml-1" href={`/sop/${t.sop_code}`}>{t.sop_code}</a>}{t.handover_note && <div className="text-amber-800">📝 {t.handover_note}</div>}</div>
              </div>
              <div className="flex flex-col gap-1">
                <button className="btn-primary !py-2 !px-3 !text-sm" onClick={async () => { await act("task_status", { id: t.id, status: "XONG" }); tasks.reload(); }}>✓ Xong</button>
                {t.kind === "CHECKLIST" && <button className="btn-secondary !py-2 !px-3 !text-sm" onClick={() => { setForm("checklist"); setTab("ghi"); }}>Mở checklist</button>}
                {["KHAM_THAI", "CACH_LY_RA"].includes(t.kind) && <button className="btn-secondary !py-2 !px-3 !text-sm" onClick={() => { setForm("animal_event"); setTab("ghi"); }}>Ghi sự kiện</button>}
                {t.kind === "SO_HOA_GIAY" && <a className="btn-secondary !py-2 !px-3 !text-sm" href="/giay">Nhập từ phiếu</a>}
                {t.kind === "ALERT" && <a className="btn-secondary !py-2 !px-3 !text-sm" href="/canh-bao">Xem cảnh báo</a>}
                <button className="text-xs underline text-stone-500" onClick={async () => { const n = await prompt({ title: "Treo việc sang ca sau", label: "Treo sang ca sau — ghi chú:", type: "text", required: false }); if (n != null) { await act("task_status", { id: t.id, status: "TREO", handover_note: n }); tasks.reload(); } }}>treo</button>
              </div>
            </div>))}
        </div>)}
      {tab === "ghi" && (
        <div className="space-y-3">
          {!forms && <div className="card">Đang tải danh mục… {animals.stale && "(dữ liệu offline)"}</div>}
          {forms && !form && (
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
              {keys.filter((k) => forms[k]).map((k) => <button key={k} className="tile" onClick={() => setForm(k)}><span className="text-lg font-bold">{forms[k].title}</span></button>)}
            </div>)}
          {forms && form && forms[form] && (<div><button className="mb-2 underline text-sm" onClick={() => setForm(null)}>← Chọn việc khác</button><ThreeTap spec={spec!} /></div>)}
        </div>)}
      {tab === "giaoca" && (
        <div className="space-y-3">
          <div className="card">
            <div className="font-semibold mb-1">Ghi sổ giao ca</div>
            <textarea className="input" rows={3} placeholder="Con B012 bỏ ăn sáng, ca sau theo dõi…" aria-label="Con B012 bỏ ăn sáng, ca sau theo dõi…" value={noteTxt} onChange={(e) => setNoteTxt(e.target.value)} />
            <div className="flex gap-2 mt-2"><button className="btn-secondary" onClick={async () => { if (!noteTxt.trim()) return; await act("shift_note", { note: noteTxt, dept: sess.position, shift: new Date().getHours() < 12 ? "SANG" : "CHIEU" }); setNoteTxt(""); notes.reload(); }}>Lưu ghi chú</button><button className="btn-primary" onClick={async () => { if (!noteTxt.trim()) return; await act("shift_note", { note: noteTxt, dept: sess.position, make_task: true, role_hint: myRoleKey ? `worker:${myRoleKey}` : sess.role }); setNoteTxt(""); notes.reload(); tasks.reload(); }}>Lưu + tạo việc cho ca sau</button></div>
          </div>
          {(notes.rows ?? []).map((n) => <div key={n.id} className="card text-base"><div className="text-sm text-stone-500">{fmt.dt(n.ts)} · {n.by_name} · {n.dept}</div><div>{n.note}</div>{!n.ack_by && <button className="text-sm underline mt-1" onClick={async () => { await act("ack_note", { id: n.id }); notes.reload(); }}>Đã đọc</button>}{n.ack_by && <span className="b-grn mt-1">đã nhận</span>}</div>)}
        </div>)}
      {tab === "gan_day" && (
        <div className="card overflow-auto"><table className="tbl"><thead><tr><th>Lúc</th><th>Loại</th><th>Gì</th><th>Đối tượng</th><th>Nguồn</th></tr></thead><tbody>
          {(recent.rows ?? []).slice(0, 60).map((e, i) => <tr key={i}><td>{fmt.dt(e.ts)}</td><td>{String(e.kind)}</td><td>{String(e.what)}</td><td>{String(e.who ?? "")}</td><td>{String(e.source)}{e.is_backfill ? " (bù)" : ""}</td></tr>)}
        </tbody></table></div>)}
    </div>);
}
