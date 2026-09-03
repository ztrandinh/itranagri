"use client";
/** DataBoundary: chuẩn hoá 4 trạng thái của một danh sách dữ liệu — LOADING / ERROR / EMPTY / OK.
 *  Sửa bug toàn hệ thống: panel kiểm tra !rows?.length nên lúc đang tải (rows===null) hiện "không có
 *  dữ liệu" nhấp nháy. Dùng: <DataBoundary loading={loading} error={error} empty={!rows?.length}
 *  onRetry={reload}>...</DataBoundary> — phân biệt rõ đang tải với thật sự rỗng, và luôn báo lỗi tải. */
export function DataBoundary({ loading, error, empty, onRetry, emptyText, skeletonRows = 3, children }: {
  loading?: boolean;
  error?: string | null;
  empty?: boolean;
  onRetry?: () => void;
  emptyText?: string;
  skeletonRows?: number;
  children: React.ReactNode;
}) {
  if (loading) {
    return (
      <div className="animate-pulse space-y-2 py-2" aria-busy="true" aria-live="polite">
        <span className="sr-only">Đang tải…</span>
        {Array.from({ length: skeletonRows }).map((_, i) => (
          <div key={i} className="h-8 rounded-lg bg-surface-2" />
        ))}
      </div>
    );
  }
  if (error) {
    return (
      <div role="alert" className="rounded-xl bg-danger-soft-tok border border-danger-tok text-danger-tok px-3 py-3 text-sm flex items-center justify-between gap-3">
        <span>{error === "offline" ? "Mất mạng — chưa tải được dữ liệu." : `Lỗi tải dữ liệu: ${error}`}</span>
        {onRetry && <button className="btn-secondary !py-1.5 !px-3 !text-sm shrink-0" onClick={onRetry}>Thử lại</button>}
      </div>
    );
  }
  if (empty) {
    return <div className="text-muted py-6 text-center text-sm">{emptyText ?? "Chưa có dữ liệu."}</div>;
  }
  return <>{children}</>;
}
