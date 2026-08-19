"use client";
/** EmptyState — trạng thái rỗng có ý nghĩa: nói rõ vì sao trống + việc nên làm tiếp.
 *  Thay cho dòng chữ xám cụt ("Không có bản ghi"). */
export function EmptyState({ icon = "📭", title, hint, action, className = "" }: {
  icon?: string; title: string; hint?: string; action?: React.ReactNode; className?: string;
}) {
  return (
    <div className={`flex flex-col items-center justify-center text-center px-4 py-8 ${className}`}>
      <div aria-hidden="true" style={{ fontSize: 30, lineHeight: 1, opacity: .75 }}>{icon}</div>
      <div className="mt-2 font-semibold" style={{ color: "var(--ink)" }}>{title}</div>
      {hint && <div className="mt-1 text-sm" style={{ color: "var(--muted)", maxWidth: "46ch" }}>{hint}</div>}
      {action && <div className="mt-3">{action}</div>}
    </div>
  );
}
