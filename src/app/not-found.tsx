import { EmptyState } from "@/components/ui/EmptyState";

/** Trước đây không có not-found.tsx — URL sai/link cũ rơi vào trang 404 mặc định của Next.js
 * (tiếng Anh, không khớp giao diện/ngôn ngữ tiếng Việt của app). */
export default function NotFound() {
  return (
    <div className="min-h-[60vh] flex items-center justify-center p-4">
      <EmptyState
        icon="🔍"
        title="Không tìm thấy trang này"
        hint="Đường dẫn có thể đã đổi hoặc không còn tồn tại."
        action={<a className="btn-primary" href="/">Về trang chủ</a>}
      />
    </div>
  );
}
