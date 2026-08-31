"use client";
/** Chuyển giao diện Sáng / Tối / Theo máy — ghi data-theme lên <html>, nhớ theo thiết bị.
 *  Mọi màu đã đi qua token nên chỉ cần đổi thuộc tính này. */
import { useEffect, useState } from "react";

type Mode = "light" | "dark" | "system";
const KEY = "itran.theme";

export function applyTheme(m: Mode) {
  const el = document.documentElement;
  if (m === "system") el.removeAttribute("data-theme");
  else el.setAttribute("data-theme", m);
}

export function ThemeToggle({ compact }: { compact?: boolean }) {
  const [mode, setMode] = useState<Mode>("system");
  useEffect(() => {
    try { const v = (localStorage.getItem(KEY) as Mode) || "system"; setMode(v); applyTheme(v); } catch { /* ignore */ }
  }, []);
  const set = (m: Mode) => { setMode(m); applyTheme(m); try { localStorage.setItem(KEY, m); } catch { /* ignore */ } };
  const opts: [Mode, string, string][] = [["light", "☀", "Sáng"], ["dark", "🌙", "Tối"], ["system", "🖥", "Theo máy"]];
  return (
    <div role="group" aria-label="Giao diện sáng tối" className="inline-flex items-center gap-1 p-1" style={{ background: "var(--surface-2)", borderRadius: "var(--r-full)", border: "1px solid var(--line)" }}>
      {opts.map(([m, icon, label]) => (
        <button
          key={m}
          type="button"
          aria-pressed={mode === m}
          title={label}
          onClick={() => set(m)}
          className="text-sm font-semibold"
          style={{
            padding: compact ? "2px 8px" : "4px 10px", borderRadius: "var(--r-full)",
            background: mode === m ? "var(--brand)" : "transparent",
            color: mode === m ? "var(--bg)" : "var(--muted)",
            transition: `background-color var(--dur-fast) var(--ease), color var(--dur-fast) var(--ease)`,
          }}
        >
          <span aria-hidden="true">{icon}</span>{!compact && <span className="ml-1 hidden sm:inline">{label}</span>}
        </button>
      ))}
    </div>
  );
}

/** Nạp theme sớm để tránh nháy sáng→tối khi mở trang (đặt trong Shell). */
export function ThemeBoot() {
  useEffect(() => { try { applyTheme(((localStorage.getItem(KEY) as Mode) || "system")); } catch { /* ignore */ } }, []);
  return null;
}
