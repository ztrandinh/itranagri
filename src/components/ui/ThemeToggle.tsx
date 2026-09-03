"use client";
/** Chuyển giao diện Sáng / Tối / Theo máy — ghi data-theme lên <html>, nhớ theo thiết bị.
 *  Mọi màu đã đi qua token nên chỉ cần đổi thuộc tính này. */
import { useEffect, useState } from "react";
import { IconSun, IconMoon, IconMonitor } from "@/components/icons/UiIcons";

type Mode = "light" | "dark" | "system";
const KEY = "itran.theme";
/** Mặc định SÁNG (chuyên nghiệp, đồng nhất cho ảnh chụp/demo) — máy đặt tối không tự áp nữa;
 *  ai muốn tối bấm "Theo máy" hoặc "Tối" — chọn xong nhớ theo localStorage. */
const DEFAULT_MODE: Mode = "light";

export function applyTheme(m: Mode) {
  const el = document.documentElement;
  if (m === "system") el.removeAttribute("data-theme");
  else el.setAttribute("data-theme", m);
}

export function ThemeToggle({ compact }: { compact?: boolean }) {
  const [mode, setMode] = useState<Mode>(DEFAULT_MODE);
  useEffect(() => {
    try { const v = (localStorage.getItem(KEY) as Mode) || DEFAULT_MODE; setMode(v); applyTheme(v); } catch { /* ignore */ }
  }, []);
  const set = (m: Mode) => { setMode(m); applyTheme(m); try { localStorage.setItem(KEY, m); } catch { /* ignore */ } };
  const opts: [Mode, (p: { size?: number }) => React.ReactNode, string][] = [["light", IconSun, "Sáng"], ["dark", IconMoon, "Tối"], ["system", IconMonitor, "Theo máy"]];
  return (
    <div role="group" aria-label="Giao diện sáng tối" className="inline-flex items-center gap-1 p-1" style={{ background: "var(--surface-2)", borderRadius: "var(--r-full)", border: "1px solid var(--line)" }}>
      {opts.map(([m, Icon, label]) => (
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
          <span aria-hidden="true"><Icon size={14} /></span>{!compact && <span className="ml-1 hidden sm:inline">{label}</span>}
        </button>
      ))}
    </div>
  );
}

/** Nạp theme sớm để tránh nháy sáng→tối khi mở trang (đặt trong Shell). */
export function ThemeBoot() {
  useEffect(() => { try { applyTheme(((localStorage.getItem(KEY) as Mode) || DEFAULT_MODE)); } catch { /* ignore */ } }, []);
  return null;
}
