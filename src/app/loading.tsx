import { SkeletonTable } from "@/components/ui/Skeleton";

/** Fallback streaming toàn cục khi 1 route segment đang tải — trước đây không có
 * loading.tsx/error.tsx/not-found.tsx nào trong src/app, không tận dụng streaming/error-boundary
 * chuẩn của Next.js App Router (mỗi panel tự lo tải/lỗi riêng, không nhất quán). */
export default function Loading() {
  return (
    <div className="p-4">
      <SkeletonTable rows={6} cols={5} />
    </div>
  );
}
