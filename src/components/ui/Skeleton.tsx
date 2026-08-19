"use client";
/** Skeleton — khung xám nhấp nháy dịu thay cho màn trống khi đang tải.
 *  Tôn trọng prefers-reduced-motion (tắt nhấp nháy). */
export function Skeleton({ className = "", style }: { className?: string; style?: React.CSSProperties }) {
  return <span aria-hidden="true" className={`ui-skel block ${className}`} style={{ borderRadius: "var(--r-sm)", ...style }} />;
}

/** Vài dòng chữ giả */
export function SkeletonText({ lines = 3, className = "" }: { lines?: number; className?: string }) {
  return (
    <div className={`space-y-2 ${className}`} aria-busy="true" aria-live="polite">
      <span className="sr-only">Đang tải…</span>
      {Array.from({ length: lines }).map((_, i) => (
        <Skeleton key={i} style={{ height: 12, width: i === lines - 1 ? "60%" : "100%" }} />
      ))}
    </div>
  );
}

/** Khung bảng đang tải */
export function SkeletonTable({ rows = 5, cols = 4 }: { rows?: number; cols?: number }) {
  return (
    <div className="p-3 space-y-2" aria-busy="true" aria-live="polite">
      <span className="sr-only">Đang tải bảng…</span>
      {Array.from({ length: rows }).map((_, r) => (
        <div key={r} className="flex gap-3">
          {Array.from({ length: cols }).map((_, c) => (
            <Skeleton key={c} style={{ height: 14, flex: c === 0 ? 2 : 1 }} />
          ))}
        </div>
      ))}
    </div>
  );
}
