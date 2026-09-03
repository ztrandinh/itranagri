"use client";
import { useEffect, useState } from "react";
import { useData, fmt } from "@/lib/client";
import { IconChevronDown, IconChevronRight, IconCheck } from "@/components/icons/UiIcons";
type Row = Record<string, unknown>;
const KIND: Record<string, [string, string]> = { VIEC: ["Việc", "bg-brand-soft text-brand"], DUYET: ["Chờ tôi duyệt", "bg-warning-soft-tok text-warning-tok"], TIN: ["Tin chưa đọc", "bg-info-soft-tok text-info-tok"], DAO_TAO_HOC: ["Học tuần này", "bg-violet-100 text-violet-900"], DAO_TAO_DAY: ["Dạy tuần này", "bg-violet-100 text-violet-900"], GIAM_SAT: ["Lượt kiểm tra", "bg-rose-100 text-rose-900"], THAY: ["Thay người", "bg-surface-2 text-ink"], GS_NGAY: ["Giám sát hôm nay", "bg-danger-soft-tok text-danger-tok"] };
/** HÔM NAY CỦA TÔI — hộp việc thống nhất mọi nguồn (việc/duyệt/tin/đào tạo/giám sát/thay người), đặt đầu mọi trang; thu gọn nhớ theo người */
export default function TodayBar() {
  const counts = useData<Row>("my_inbox_counts"); const [open, setOpen] = useState(false); const [filter, setFilter] = useState<string | null>(null);
  const list = useData<Row>(open ? "my_inbox" : null);
  useEffect(() => { try { setOpen(localStorage.getItem("today:open") === "1"); } catch { /* ignore */ } }, []);
  const toggle = () => { const v = !open; setOpen(v); try { localStorage.setItem("today:open", v ? "1" : "0"); } catch { /* ignore */ } };
  const rows = counts.rows ?? [];
  // Số chính = việc CẦN LÀM (không tính "Tin" — tin tức không phải việc tồn); rút gọn số lớn cho gọn.
  const actionable = rows.filter((r) => String(r.kind) !== "TIN").reduce((a, r) => a + Number(r.n), 0);
  const cap = (n: number) => (n > 999 ? "999+" : String(n));
  const items = (list.rows ?? []).filter((r) => !filter || r.kind === filter).slice(0, 40);
  return <div className="rounded-xl border bg-surface px-3 py-2 mb-3 text-sm shadow-sm">
    <div className="flex items-center gap-2 flex-wrap">
      <button className="font-black py-2 -my-2 inline-flex items-center gap-1.5" onClick={toggle}>{open ? <IconChevronDown size={15} /> : <IconChevronRight size={15} />} Hôm nay của tôi <span className="text-muted font-normal">({cap(actionable)})</span></button>
      {rows.map((r) => { const k = String(r.kind); const [lbl, cls] = KIND[k] ?? [k, "bg-surface-2"]; return <button key={k} className={`px-2 py-0.5 rounded-full text-xs font-semibold ${cls} ${filter === k ? "ring-2 ring-slate-500" : ""}`} onClick={() => { setFilter(filter === k ? null : k); if (!open) toggle(); }}>{lbl}: {cap(Number(r.n))}</button>; })}
      {actionable === 0 && !counts.loading && <span className="text-xs text-brand inline-flex items-center gap-1"><IconCheck size={12} /> Không có việc tồn — làm tốt!</span>}
      <a className="ml-auto text-xs underline text-muted py-2 px-1 -my-2" href="/ca">Ca của tôi</a><a className="text-xs underline text-muted py-2 px-1 -my-2" href="/phe-duyet">Phê duyệt</a><a className="text-xs underline text-muted py-2 px-1 -my-2" href="/thong-bao">Tin</a>
    </div>
    {open && <div className="mt-2 max-h-72 overflow-auto divide-y">
      {items.map((r, i) => { const k = String(r.kind); const [lbl, cls] = KIND[k] ?? [k, "bg-surface-2"]; const late = r.due_at && new Date(String(r.due_at)) < new Date(); return <a key={i} href={String(r.link ?? "/ca")} className="flex items-center gap-2 py-1.5 hover:bg-slate-50">
        <span className={`px-1.5 rounded text-[11px] font-bold shrink-0 ${cls}`}>{lbl}</span>
        <span className={`shrink-0 text-[11px] font-bold ${r.priority === "KHAN" ? "text-danger-tok" : r.priority === "CAO" ? "text-warning-tok" : "text-muted"}`}>{r.priority === "KHAN" ? "KHẨN" : r.priority === "CAO" ? "CAO" : ""}</span>
        <span className="truncate flex-1"><b>{String(r.title)}</b>{r.detail ? <span className="text-muted"> — {String(r.detail).slice(0, 80)}</span> : null}{r.on_behalf ? <span className="ml-1 text-[11px] rounded bg-surface-2 px-1">thay {String(r.on_behalf)}</span> : null}</span>
        <span className={`shrink-0 text-xs ${late ? "text-danger-tok font-bold" : "text-muted"}`}>{r.due_at ? fmt.dt(r.due_at) : ""}</span></a>; })}
      {list.loading && <div className="text-xs text-muted py-2">đang tải…</div>}
      {!list.loading && items.length === 0 && <div className="text-xs text-muted py-2">Không có mục nào.</div>}
      {(list.rows?.length ?? 0) > 40 && <div className="text-xs text-muted py-1">Hiện 40 mục đầu — vào <a className="underline" href="/ca">Ca của tôi</a> để xem hết.</div>}
    </div>}
  </div>;
}
