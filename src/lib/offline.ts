"use client";
import { get, set, del, keys } from "idb-keyval";

export type Queued = { key: string; table: string; event: Record<string, unknown>; created_at: number; tries: number; last_error?: string };
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

export async function enqueue(table: string, event: Record<string, unknown>): Promise<Queued> {
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
let flushing = false;
export async function flush(): Promise<{ sent: number; failed: number }> {
  if (flushing || typeof navigator !== "undefined" && !navigator.onLine) return { sent: 0, failed: 0 };
  flushing = true;
  let sent = 0, failed = 0;
  try {
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
            // Bị từ chối do dữ liệu (không phải mạng): giữ lại để người dùng sửa, đánh dấu lỗi
            await set(it.key, { ...it, tries: it.tries + 1, last_error: r.errors?.join("; ") }); failed++;
          } else { await set(it.key, { ...it, tries: it.tries + 1, last_error: "no-result" }); failed++; }
        }
      } catch (e) {
        for (const it of list) await set(it.key, { ...it, tries: it.tries + 1, last_error: (e as Error).message });
        failed += list.length;
      }
    }
  } finally { flushing = false; emit(); }
  return { sent, failed };
}
export async function discard(key: string) { await del(key); emit(); }

if (typeof window !== "undefined") {
  window.addEventListener("online", () => void flush());
  setInterval(() => void flush(), 30000);
}
