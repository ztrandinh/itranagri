"use client";
/** CHẾ ĐỘ NẮNG — bật tương phản tối đa để đọc màn hình ngoài trời (công nhân đi đồng).
 *  Ghi data-sun="1" lên <html>; nhớ theo thiết bị. Chỉ đổi token nên không đụng component nào. */
import { useEffect, useState } from "react";

const KEY = "itran.sun";

export function applySun(on: boolean) {
  const el = document.documentElement;
  if (on) el.setAttribute("data-sun", "1"); else el.removeAttribute("data-sun");
}

export function SunToggle({ compact }: { compact?: boolean }) {
  const [on, setOn] = useState(false);
  useEffect(() => { try { const v = localStorage.getItem(KEY) === "1"; setOn(v); applySun(v); } catch { /* ignore */ } }, []);
  const toggle = () => { const v = !on; setOn(v); applySun(v); try { localStorage.setItem(KEY, v ? "1" : "0"); } catch { /* ignore */ } };
  return (
    <button
      type="button"
      onClick={toggle}
      aria-pressed={on}
      title={on ? "Tắt chế độ nắng" : "Chế độ nắng — đọc rõ ngoài trời"}
      className="text-sm font-semibold whitespace-nowrap"
      style={{
        minHeight: 36, padding: compact ? "4px 10px" : "6px 12px", borderRadius: "var(--r-full)",
        border: `1px solid ${on ? "transparent" : "var(--line)"}`,
        background: on ? "#f59e0b" : "var(--surface)",
        color: on ? "#1c1917" : "var(--muted)",
        transition: "background-color var(--dur-fast) var(--ease), color var(--dur-fast) var(--ease)",
      }}
    >
      <span aria-hidden="true">🌤</span>{!compact && <span className="ml-1 hidden sm:inline">{on ? "Đang bật nắng" : "Chế độ nắng"}</span>}
    </button>
  );
}

/** Nạp sớm để không nháy khi mở trang */
export function SunBoot() {
  useEffect(() => { try { applySun(localStorage.getItem(KEY) === "1"); } catch { /* ignore */ } }, []);
  return null;
}
