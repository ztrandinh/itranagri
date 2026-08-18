"use client";
import { useEffect, useState } from "react";

/** Chọn tab ban đầu từ ?tab= mà KHÔNG gây hydration mismatch.
 *  Server + lần paint đầu render `fallback` (tất định), rồi đọc URL trong useEffect sau khi mount.
 *  `alias` ánh xạ giá trị trên URL → key tab nội bộ (vd { "nhan-nuoi": "nn" }).
 *  Thay cho pattern useState(typeof window !== "undefined" && new URLSearchParams(...).get("tab")…)
 *  vốn khiến server render một tab, client render tab khác → lỗi hydration. */
export function useUrlTab<T extends string>(valid: readonly T[], fallback: T, alias?: Record<string, T>) {
  const [tab, setTab] = useState<T>(fallback);
  useEffect(() => {
    const raw = new URLSearchParams(window.location.search).get("tab");
    if (!raw) return;
    const v = (alias?.[raw] ?? raw) as T;
    if ((valid as readonly string[]).includes(v)) setTab(v);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return [tab, setTab] as const;
}
