"use client";
import { get, set, del, keys } from "idb-keyval";

/** `last_error` = máy chủ TỪ CHỐI vì dữ liệu (phải sửa mới gửi được).
 *  `net_error` = LỖI MẠNG (fetch ném / máy chủ không trả lời) — chỉ cần chờ có mạng, KHÔNG phải sửa.
 *  Trước đây gộp cả hai vào last_error nên mất mạng lại báo "máy chủ từ chối" — công nhân tưởng ghi sai. */
export type Queued = { key: string; table: string; event: Record<string, unknown>; created_at: number; tries: number; last_error?: string; net_error?: boolean };
const PREFIX = "q:";
const listeners = new Set<() => void>();
export function onQueueChange(fn: () => void) { listeners.add(fn); return () => { listeners.delete(fn); }; }
const emit = () => listeners.forEach((f) => f());

export function newClientRef(): string {
  // UUID v7-ish (thời gian + ngẫu nhiên) sinh được offline
  const t = Date.now().toString(16).padStart(12, "0");
  const r = crypto.getRandomValues(new Uint8Array(10));
  const hex = Array.from(r, (b) => b.toString(16).padStart(2, "0")).join("");
  return `${t.slice(0, 8)}-${t.slice(8, 12)}-7${hex.slice(0, 3)}-${(8 + (r[2] & 3)).toString(16)}${hex.slice(4, 7)}-${hex.slice(7, 19)}`;
}

// Trước đây không giới hạn dung lượng hàng đợi — nếu công nhân mất mạng nhiều ngày liên tục (thực tế
// ở trại vùng sâu), IndexedDB có thể chạm hạn ngạch trình duyệt và set() ném lỗi quota không rõ ràng,
// hoặc hàng đợi phình quá lớn khiến 1 lần đồng bộ gửi hàng nghìn bản ghi cùng lúc (dễ timeout trên
// mạng yếu). Chặn NGƯỠNG rõ ràng, báo lỗi có ý nghĩa thay vì để trình duyệt tự ném lỗi quota mơ hồ.
const MAX_QUEUE = 500;
export async function enqueue(table: string, event: Record<string, unknown>): Promise<Queued> {
  const n = (await keys()).filter((k) => String(k).startsWith(PREFIX)).length;
  if (n >= MAX_QUEUE) throw new Error(`ERR_QUEUE_FULL: hàng đợi offline đã đầy (${MAX_QUEUE} bản ghi) — cần có mạng để đồng bộ bớt trước khi ghi tiếp, báo tổ trưởng/IT nếu lặp lại.`);
  const key = PREFIX + (event.client_ref as string);
  const item: Queued = { key, table, event, created_at: Date.now(), tries: 0 };
  await set(key, item);
  emit();
  void flush();
  return item;
}
export async function pending(): Promise<Queued[]> {
  const ks = (await keys()).filter((k) => String(k).startsWith(PREFIX));
  const items = await Promise.all(ks.map((k) => get<Queued>(k)));
  return items.filter(Boolean).sort((a, b) => a!.created_at - b!.created_at) as Queued[];
}
/** Lượt gửi đang chạy. Trước đây là cờ boolean và flush() thoát ngay khi thấy cờ bật —
 *  nên nơi gọi `await flush()` KHÔNG hề chờ, tưởng đã gửi xong trong khi lượt gửi thật
 *  vẫn đang bay. Đo được: form báo "đã lưu trong máy (chưa có mạng)" dù đang online và
 *  máy chủ vừa từ chối bản ghi. Nay trả về chính promise đang chạy để nơi gọi chờ đúng lượt. */
let flushing: Promise<{ sent: number; failed: number }> | null = null;
export function flush(): Promise<{ sent: number; failed: number }> {
  if (flushing) return flushing;
  if (typeof navigator !== "undefined" && !navigator.onLine) return Promise.resolve({ sent: 0, failed: 0 });
  flushing = doFlush().finally(() => { flushing = null; emit(); });
  return flushing;
}
async function doFlush(): Promise<{ sent: number; failed: number }> {
  let sent = 0, failed = 0;
  {
    const items = await pending();
    const byTable = new Map<string, Queued[]>();
    for (const it of items) byTable.set(it.table, [...(byTable.get(it.table) ?? []), it]);
    for (const [table, list] of byTable) {
      try {
        const res = await fetch(`/api/events/${table}`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ events: list.map((l) => l.event) }) });
        if (res.status === 401) { window.location.href = "/login"; return { sent, failed }; }
        const j = await res.json();
        const results: { client_ref: string; status: string; errors?: string[] }[] = j.results ?? [];
        for (const it of list) {
          const r = results.find((x) => x.client_ref === it.event.client_ref);
          if (r && (r.status === "CREATED" || r.status === "DUPLICATE")) { await del(it.key); sent++; }
          else if (r && r.status === "REJECTED") {
            // Máy chủ từ chối vì DỮ LIỆU (không phải mạng): giữ lại để người dùng sửa.
            await set(it.key, { ...it, tries: it.tries + 1, last_error: r.errors?.join("; "), net_error: false }); failed++;
          } else { await set(it.key, { ...it, tries: it.tries + 1, last_error: "no-result", net_error: false }); failed++; }
        }
      } catch (e) {
        // fetch NÉM = lỗi MẠNG, không phải máy chủ chối. Đánh dấu net_error để chờ có mạng gửi lại.
        for (const it of list) await set(it.key, { ...it, tries: it.tries + 1, net_error: true, last_error: undefined });
        failed += list.length;
      }
    }
  }
  return { sent, failed };
}
export async function discard(key: string) { await del(key); emit(); }

if (typeof window !== "undefined") {
  window.addEventListener("online", () => void flush());
  setInterval(() => void flush(), 30000);
}
