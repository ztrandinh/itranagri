"use client";
import { useEffect, useState, useCallback } from "react";
import { get, set } from "idb-keyval";

/** Đọc view qua /api/data với cache offline (IndexedDB) — hiển thị số cũ khi mất mạng. */
export function useData<T = Record<string, unknown>>(view: string | null, params: Record<string, string | undefined> = {}, deps: unknown[] = []) {
  const [rows, setRows] = useState<T[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [stale, setStale] = useState(false);
  const [loading, setLoading] = useState(true);
  const qs = new URLSearchParams(Object.entries(params).filter(([, v]) => v != null) as [string, string][]).toString();
  const cacheKey = `data:${view}?${qs}`;
  const load = useCallback(async () => {
    if (!view) { setLoading(false); return; }
    setLoading(true);
    try {
      const r = await fetch(`/api/data/${view}?${qs}`);
      if (r.status === 401) { window.location.href = "/login"; return; }
      const j = await r.json();
      if (j.rows) { setRows(j.rows); setStale(false); setError(null); void set(cacheKey, { rows: j.rows, at: Date.now() }); }
      else setError(j.error ?? "ERR");
    } catch {
      const c = await get<{ rows: T[] }>(cacheKey);
      if (c) { setRows(c.rows); setStale(true); } else setError("offline");
    } finally {
      setLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [view, qs, ...deps]);
  useEffect(() => { void load(); }, [load]);
  return { rows, error, stale, loading, reload: load };
}

export async function act(action: string, payload: Record<string, unknown>) {
  const r = await fetch("/api/actions", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ action, ...payload }) });
  return r.json();
}
export const fmt = {
  n: (v: unknown, d = 0) => v == null ? "—" : Number(v).toLocaleString("vi-VN", { maximumFractionDigits: d }),
  vnd: (v: unknown) => v == null ? "—" : Number(v).toLocaleString("vi-VN") + " đ",
  dt: (v: unknown) => v ? new Date(String(v)).toLocaleString("vi-VN", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "2-digit" }) : "—",
  d: (v: unknown) => v ? new Date(String(v)).toLocaleDateString("vi-VN") : "—",
};
export function noAccent(s: string) { return s.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d").replace(/Đ/g, "D").toLowerCase(); }

/** Che số điện thoại/PII: giữ 3 số đầu + 2 số cuối, giữa thay ••• (0901234567 → 090•••67).
 *  Dùng cho danh sách khách/nhân sự với vai không được xem đầy đủ (privacy-by-default). */
export function maskPhone(v: unknown): string {
  const s = String(v ?? "").trim();
  if (!s) return "—";
  const digits = s.replace(/\D/g, "");
  if (digits.length < 6) return "•".repeat(s.length);
  return digits.slice(0, 3) + "•••" + digits.slice(-2);
}
