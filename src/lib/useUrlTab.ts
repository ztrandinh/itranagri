"use client";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";

/** Chọn tab từ ?tab= mà KHÔNG gây hydration mismatch VÀ vẫn phản ứng khi URL đổi.
 *  - Server + paint đầu: render `fallback` (tất định) → không lệch server/client.
 *  - Sau khi mount: đọc ?tab=; và mỗi lần URL đổi (điều hướng client-side, ví dụ bấm
 *    "✍ Ghi" ở thanh dưới khi ĐANG ở /ca) thì cập nhật lại — vì Next KHÔNG remount
 *    component khi chỉ đổi query, useEffect chạy-một-lần sẽ bỏ sót.
 *  `alias` ánh xạ giá trị URL → key nội bộ (vd { "nhan-nuoi": "nn" }). */
export function useUrlTab<T extends string>(valid: readonly T[], fallback: T, alias?: Record<string, T>) {
  const [tab, setTab] = useState<T>(fallback);
  const sp = useSearchParams();
  const raw = sp?.get("tab") ?? null;
  useEffect(() => {
    if (!raw) return;
    const v = (alias?.[raw] ?? raw) as T;
    if ((valid as readonly string[]).includes(v)) setTab(v);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [raw]);
  return [tab, setTab] as const;
}
