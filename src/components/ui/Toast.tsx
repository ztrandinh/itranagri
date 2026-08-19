"use client";
/** Toast: thay window.alert() báo kết quả/lỗi. Store ngoài React (không cần Provider) + <Toaster/>
 *  gắn 1 lần ở Shell. Dùng ở bất kỳ đâu: toast.ok("Đã lưu") / toast.err("Lỗi…") / toast.info(...).
 *  Tự ẩn sau ~4s, có nút đóng, aria-live cho screen-reader. */
import { useSyncExternalStore } from "react";

export type ToastKind = "ok" | "err" | "info";
export type ToastItem = { id: number; kind: ToastKind; msg: string };

let items: ToastItem[] = [];
const listeners = new Set<() => void>();
let seq = 1;
function emit() { for (const l of listeners) l(); }
function push(kind: ToastKind, msg: string) {
  const id = seq++;
  items = [...items, { id, kind, msg }];
  emit();
  setTimeout(() => dismiss(id), 4200);
  return id;
}
function dismiss(id: number) { items = items.filter((t) => t.id !== id); emit(); }

export const toast = {
  ok: (m: string) => push("ok", m),
  err: (m: string) => push("err", m),
  info: (m: string) => push("info", m),
};

function subscribe(cb: () => void) { listeners.add(cb); return () => { listeners.delete(cb); }; }
function snapshot() { return items; }
const emptySnapshot: ToastItem[] = [];

export function Toaster() {
  const list = useSyncExternalStore(subscribe, snapshot, () => emptySnapshot);
  if (!list.length) return null;
  return (
    <div className="fixed bottom-4 left-1/2 -translate-x-1/2 z-[60] flex flex-col gap-2 w-[92vw] max-w-md" aria-live="polite" aria-atomic="false">
      {list.map((t) => (
        <div
          key={t.id}
          role={t.kind === "err" ? "alert" : "status"}
          className={`ui-toast-in flex items-start gap-2 rounded-xl border px-4 py-3 shadow-lg text-sm ${
            t.kind === "err" ? "bg-red-50 border-red-200 text-red-800"
            : t.kind === "ok" ? "bg-emerald-50 border-emerald-200 text-emerald-900"
            : "bg-slate-800 border-slate-700 text-white"
          }`}
        >
          <span className="flex-1 break-words">{t.msg}</span>
          <button className="shrink-0 opacity-70 hover:opacity-100" aria-label="Đóng" onClick={() => dismiss(t.id)}>✕</button>
        </div>
      ))}
    </div>
  );
}
