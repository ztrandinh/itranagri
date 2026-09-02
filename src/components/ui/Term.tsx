"use client";
/** Term — thuật ngữ có giải thích. Gạch chân chấm; chạm/hover/focus hiện nghĩa tiếng Việt.
 *  Dùng: <Term k="FEFO" /> hoặc <Term k="PHI">thời gian cách ly</Term>.
 *  Mục đích: giữ mã nghiệp vụ (để tra cứu) nhưng ai cũng hiểu được nghĩa. */
import { useId, useState } from "react";
import { lookup } from "@/lib/glossary";

export function Term({ k, children }: { k: string; children?: React.ReactNode }) {
  const d = lookup(k);
  const id = useId();
  const [open, setOpen] = useState(false);
  if (!d) return <>{children ?? k}</>;
  const text = d.long ? `${d.short} — ${d.long}` : d.short;
  return (
    <span className="relative inline-block">
      <button
        type="button"
        aria-describedby={open ? id : undefined}
        aria-label={`${k}: ${text}`}
        onClick={() => setOpen(!open)}
        onMouseEnter={() => setOpen(true)}
        onMouseLeave={() => setOpen(false)}
        onFocus={() => setOpen(true)}
        onBlur={() => setOpen(false)}
        className="cursor-help font-inherit"
        style={{ textDecoration: "underline dotted", textUnderlineOffset: 3, textDecorationColor: "var(--muted)", background: "none", padding: "8px 2px", margin: "-8px -2px", font: "inherit", color: "inherit" }}
      >
        {children ?? k}
      </button>
      {open && (
        <span
          id={id}
          role="tooltip"
          className="ui-fade absolute left-0 top-full mt-1 block text-left font-normal"
          style={{
            zIndex: "var(--z-toast)", width: "max-content", maxWidth: 260,
            background: "var(--surface)", color: "var(--ink)", border: "1px solid var(--line)",
            borderRadius: "var(--r-md)", boxShadow: "var(--sh-2)", padding: "8px 10px", fontSize: 13, lineHeight: 1.45,
            // nhãn KPI dùng uppercase/tracking — tooltip phải trả về chữ thường bình thường
            textTransform: "none", letterSpacing: "normal", fontWeight: 400,
          }}
        >
          <b>{d.short}</b>
          {d.long && <span style={{ display: "block", color: "var(--muted)", marginTop: 2 }}>{d.long}</span>}
        </span>
      )}
    </span>
  );
}
