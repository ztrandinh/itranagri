"use client";
import Tabs from "@/components/Tabs";
import { useEffect, useMemo, useState } from "react";
import ThreeTap from "@/components/ThreeTap";
import { buildForms, formsForPosition, type Ref } from "@/lib/forms";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";
import { usePrompt } from "@/components/ui/PromptDialog";
import { useUrlTab } from "@/lib/useUrlTab";

type Task = { id: string; kind: string; title: string; due_at: string; priority: string; status: string; role_hint: string | null; sop_code: string | null; target_type: string | null; target_id: string | null; handover_note: string | null; assignee_id: string | null;
  /** Việc lặp đã được GOM ở truy vấn: `group_ids` là toàn bộ việc con trong nhóm.
   *  Bấm ✓ Xong phải đóng trọn nhóm, nếu không công nhân bấm một cái mà 119 việc còn treo. */
  group_ids?: string[]; group_n?: number };
type Note = { id: string; ts: string; note: string; by_name: string; ack_by: string | null; dept: string | null };

export default function CaPanel({ sess, forceForms }: { sess: Sess; forceForms?: string[] }) {
  const animals = useData("animals"), groups = useData("animal_groups"), warehouses = useData("warehouses"), products = useData("products"),
    plots = useData("plots"), recipes = useData("recipes"), locations = useData("locations"), sops = useData("sops"), devices = useData("devices"), partners = useData("partners"),
    // danh sách nhân sự: hành chính cần để chấm công cho người khác
    nhanSu = useData("staff"), xeCo = useData("vehicles");
  const tasks = useData<Task>("tasks_today"); const notes = useData<Note>("shift_notes"); const recent = useData("events_mine");
  const [form, setForm] = useState<string | null>(null);
  const [noteTxt, setNoteTxt] = useState("");
  // Đọc ?tab= để nút "✍ Ghi" ở thanh dưới (BottomNav) mở đúng tab Ghi 3 chạm
  const [tab, setTab] = useUrlTab(["viec", "ghi", "giaoca", "gan_day"] as const, "viec");
  const { prompt, promptElement } = usePrompt();
  const ref: Ref | null = useMemo(() => animals.rows && groups.rows && warehouses.rows && products.rows && plots.rows && recipes.rows && locations.rows && sops.rows && devices.rows && partners.rows
    ? { animals: animals.rows, groups: groups.rows, warehouses: warehouses.rows, products: products.rows, plots: plots.rows, recipes: recipes.rows, locations: locations.rows, sops: sops.rows, devices: devices.rows, partners: partners.rows, staff: nhanSu.rows ?? [], vehicles: xeCo.rows ?? [] } : null,
    [animals.rows, groups.rows, warehouses.rows, products.rows, plots.rows, recipes.rows, locations.rows, sops.rows, devices.rows, partners.rows, nhanSu.rows, xeCo.rows]);
  const forms = useMemo(() => (ref ? buildForms(ref, sess.farmId) : null), [ref, sess.farmId]);
  // Bộ form lấy theo MÃ NGHỀ từ danh mục (positions_catalog.forms). Trước đây phải dò chữ
  // trong chức danh tự do vì mã nghề sai hàng loạt; nay mã đã đúng nên tra thẳng.
  // Vẫn giữ formsForPosition() làm đường lui cho tài khoản chưa gán nghề — thà thừa form
  // còn hơn công nhân mở app ra thấy màn trắng.
  const posForms = useData<{ position_code: string; forms: string[] }>("position_forms");
  const theoNghe = useMemo(() => {
    if (!sess.positionCode || !posForms.rows) return null;
    const r = posForms.rows.find((x) => x.position_code === sess.positionCode);
    return r?.forms?.length ? r.forms : null;
  }, [posForms.rows, sess.positionCode]);
  const keys = forceForms ?? theoNghe ?? formsForPosition(sess.position, sess.role, sess.dept);
  // Giữ NGUYÊN một đối tượng spec cho mỗi form: nếu dựng object mới mỗi lần re-render thì
  // ThreeTap bị reset liên tục và công nhân mất dữ liệu đang nhập.
  const reloadRecent = recent.reload;
  const spec = useMemo(() => (forms && form && forms[form] ? { ...forms[form], onDone: () => { reloadRecent(); } } : null), [forms, form, reloadRecent]);
  // Mã nghề lấy từ DANH MỤC (positionCode), không dò regex trên chức danh tự do nữa.
  // Dò chữ thì "A11 Bảo vệ" ra A11, trong khi nghề thật của bảo vệ là A10 — lệch hẳn,
  // và đó cũng là lý do màn Ca đếm khác với "Hôm nay của tôi" (my_inbox dùng mã danh mục).
  const myRoleKey = sess.positionCode ?? sess.position?.match(/A\d{1,2}/)?.[0];
  const myTasks = (tasks.rows ?? []).filter((t) => !t.role_hint || t.role_hint === sess.role || (myRoleKey && t.role_hint === `worker:${myRoleKey}`) || (t.role_hint?.startsWith("worker:") && sess.role !== "worker") || ["tech_head","director","owner"].includes(sess.role));
  useEffect(() => { void act("generate_tasks", {}).then(() => tasks.reload()); /* sinh việc khi mở ca */ // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  const overdue = myTasks.filter((t) => new Date(t.due_at) < new Date() && t.status !== "XONG");
  // Tách "việc ĐÍCH DANH của tôi" khỏi "việc chung chưa có người nhận".
  // Lý do: hiện có 12.751 việc mở nhưng chỉ 34 việc (0,27%) có người nhận; riêng nhóm role_hint='worker'
  // có 2.310 việc và MỌI công nhân đều nhận chung, nên A1 TMR, A3 Gà, A4 RAS, A5 Lái máy mở máy ra đều
  // thấy y hệt "300 việc · 296 quá hạn", đứng đầu là "Cân định kỳ bò" — không ai biết việc nào là của mình.
  // Trộn chung như cũ thì danh sách vô nghĩa: công nhân bỏ qua toàn bộ, kể cả việc thật của họ.
  const laCuaToi = (t: Task) => t.assignee_id === sess.staffId || (!!myRoleKey && t.role_hint === `worker:${myRoleKey}`);
  const theoHan = (a: Task, b: Task) => new Date(a.due_at).getTime() - new Date(b.due_at).getTime();
  const viecCuaToi = myTasks.filter(laCuaToi).sort(theoHan);
  const viecChung = myTasks.filter((t) => !laCuaToi(t)).sort(theoHan);
  const chungQuaHan = viecChung.filter((t) => new Date(t.due_at) < new Date()).length;
  const quaHanCuaToi = viecCuaToi.filter((t) => new Date(t.due_at) < new Date()).length;
  return (
    <div className="space-y-4">
      {promptElement}
      <Tabs value={tab} onChange={(k) => setTab(k as typeof tab)} items={[["viec", `Việc hôm nay (${viecCuaToi.length}${quaHanCuaToi ? ` · ${quaHanCuaToi} quá hạn` : ""})`], ["ghi", "Ghi 3 chạm"], ["giaoca", "Giao ca"], ["gan_day", "Tôi vừa ghi"]]} />

      {tab === "viec" && (
        <div className="space-y-2">
          {!viecCuaToi.length && <div className="card text-muted">Bạn không có việc nào được giao đích danh. Bấm "Ghi 3 chạm" để ghi việc thường ngày.</div>}
          {viecCuaToi.map((t) => (
            <div key={t.id} className={`card flex items-start gap-3 ${t.priority === "KHAN" ? "border-danger-tok" : t.priority === "CAO" ? "border-amber-300" : ""}`}>
              <div className="flex-1">
                <div className="font-semibold">{t.title}</div>
                {/* Nói rõ bấm một cái là đóng bao nhiêu việc — đừng để công nhân bấm mà không
                    biết mình vừa đóng 120 bản ghi. */}
                {(t.group_n ?? 1) > 1 && <div className="text-xs text-warning-tok">Gồm {t.group_n} việc giống nhau — bấm ✓ Xong là đóng cả nhóm</div>}
                <div className="text-sm text-muted">{t.kind} · hạn {fmt.dt(t.due_at)} {new Date(t.due_at) < new Date() && <span className="b-red ml-1">quá hạn</span>} {t.sop_code && <a className="underline ml-1" href={`/sop/${t.sop_code}`}>{t.sop_code}</a>}{t.handover_note && <div className="text-warning-tok">📝 {t.handover_note}</div>}</div>
              </div>
              <div className="flex flex-col gap-1">
                <button className="btn-primary !py-2 !px-3 !text-sm" onClick={async () => { await act("task_status", { ids: t.group_ids ?? [t.id], status: "XONG" }); tasks.reload(); }}>✓ Xong</button>
                {t.kind === "CHECKLIST" && <button className="btn-secondary !py-2 !px-3 !text-sm" onClick={() => { setForm("checklist"); setTab("ghi"); }}>Mở checklist</button>}
                {["KHAM_THAI", "CACH_LY_RA"].includes(t.kind) && <button className="btn-secondary !py-2 !px-3 !text-sm" onClick={() => { setForm("animal_event"); setTab("ghi"); }}>Ghi sự kiện</button>}
                {t.kind === "SO_HOA_GIAY" && <a className="btn-secondary !py-2 !px-3 !text-sm" href="/giay">Nhập từ phiếu</a>}
                {t.kind === "ALERT" && <a className="btn-secondary !py-2 !px-3 !text-sm" href="/canh-bao">Xem cảnh báo</a>}
                <button className="text-xs underline text-muted" onClick={async () => { const n = await prompt({ title: "Treo việc sang ca sau", label: "Treo sang ca sau — ghi chú:", type: "text", required: false }); if (n != null) { await act("task_status", { ids: t.group_ids ?? [t.id], status: "TREO", handover_note: n }); tasks.reload(); } }}>treo</button>
              </div>
            </div>))}
          {/* KHÔNG xoá việc chung — chỉ gấp lại để nó không nhấn chìm việc đích danh. */}
          {!!viecChung.length && (
            <details className="card">
              <summary className="cursor-pointer font-semibold">Việc chung của bộ phận, chưa giao ai — {viecChung.length}{chungQuaHan ? ` · ${chungQuaHan} quá hạn` : ""}</summary>
              <div className="text-sm text-muted mt-1 mb-2">Đây là việc hệ thống sinh cho cả nhóm, chưa chỉ định người làm. Ai làm thì bấm ✓ Xong; nếu thấy đúng là việc của mình, báo tổ trưởng giao đích danh để lần sau hiện ở trên.</div>
              <div className="space-y-2">
                {viecChung.slice(0, 30).map((t) => (
                  <div key={t.id} className="rounded-xl border px-3 py-2 flex items-start gap-3">
                    <div className="flex-1">
                      <div className="font-semibold">{t.title}</div>
                      <div className="text-sm text-muted">{t.kind} · hạn {fmt.dt(t.due_at)} {new Date(t.due_at) < new Date() && <span className="b-red ml-1">quá hạn</span>}</div>
                    </div>
                    <button className="btn-secondary !py-2 !px-3 !text-sm" onClick={async () => { await act("task_status", { ids: t.group_ids ?? [t.id], status: "XONG" }); tasks.reload(); }}>✓ Xong</button>
                  </div>))}
                {viecChung.length > 30 && <div className="text-sm text-muted">…còn {viecChung.length - 30} việc nữa. Danh sách quá dài là do việc được sinh mà không giao người — cần tổ trưởng phân công.</div>}
              </div>
            </details>)}
        </div>)}
      {tab === "ghi" && (
        <div className="space-y-3">
          {/* Chờ CẢ danh mục nghề rồi mới bày ô việc. Nếu vẽ trước bằng bộ dự phòng thì khi
              danh mục về, danh sách ô đổi ngay dưới tay công nhân — họ đang chạm thì ô nhảy chỗ. */}
          {(!forms || posForms.loading) && <div className="card">Đang tải danh mục… {animals.stale && "(dữ liệu offline)"}</div>}
          {forms && !posForms.loading && !form && (
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
          {(notes.rows ?? []).map((n) => <div key={n.id} className="card text-base"><div className="text-sm text-muted">{fmt.dt(n.ts)} · {n.by_name} · {n.dept}</div><div>{n.note}</div>{!n.ack_by && <button className="text-sm underline mt-1" onClick={async () => { await act("ack_note", { id: n.id }); notes.reload(); }}>Đã đọc</button>}{n.ack_by && <span className="b-grn mt-1">đã nhận</span>}</div>)}
        </div>)}
      {tab === "gan_day" && (
        <div className="card overflow-auto">
          {recent.rows && !recent.rows.length
            ? <div className="text-muted py-6 text-center">Bạn chưa ghi gì. Mọi bản ghi bạn tạo sẽ hiện ở đây ngay sau khi lưu.</div>
            : <table className="tbl"><thead><tr><th>Lúc</th><th>Loại</th><th>Gì</th><th>Đối tượng</th><th>Nguồn</th></tr></thead><tbody>
              {(recent.rows ?? []).slice(0, 60).map((e, i) => <tr key={i}><td>{fmt.dt(e.ts)}</td><td>{String(e.kind)}</td><td>{String(e.what)}</td><td>{String(e.who ?? "")}</td><td>{String(e.source)}{e.is_backfill ? " (bù)" : ""}</td></tr>)}
            </tbody></table>}
        </div>)}
    </div>);
}
