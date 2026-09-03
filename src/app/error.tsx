"use client";
import { useEffect } from "react";
import { EmptyState } from "@/components/ui/EmptyState";

/** Error boundary toàn cục cho route segment — Next.js App Router bắt buộc "use client".
 * Trước đây không có error.tsx nào trong src/app: lỗi render ở bất kỳ trang nào rơi ra màn trắng
 * mặc định của Next.js thay vì thông báo tiếng Việt + đường quay lại. */
export default function Error({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => { console.error("route error boundary", error); }, [error]);
  return (
    <div className="min-h-[60vh] flex items-center justify-center p-4">
      <EmptyState
        icon="⚠️"
        title="Có lỗi khi hiển thị trang này"
        hint={error.digest ? `Mã lỗi: ${error.digest} — thử tải lại, nếu vẫn lỗi báo bộ phận Công nghệ - Dữ liệu.` : "Thử tải lại, nếu vẫn lỗi báo bộ phận Công nghệ - Dữ liệu."}
        action={
          <div className="flex gap-2 justify-center">
            <button className="btn-primary" onClick={() => reset()}>Thử lại</button>
            <a className="btn-secondary" href="/">Về trang chủ</a>
          </div>
        }
      />
    </div>
  );
}
