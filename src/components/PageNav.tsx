"use client";
import { DEPT_HOME } from "@/lib/modules";
/** Thanh điều hướng trong app: ← Quay lại · Phòng tôi · Trang chủ · Tiếp → (không bắt người dùng dùng nút back của trình duyệt) */
export default function PageNav({ dept, title }: { dept?: string | null; title?: string }) {
  const home = (dept && DEPT_HOME[dept]) || "/trang-chu";
  const back = () => { if (typeof window !== "undefined" && window.history.length > 1 && document.referrer.startsWith(window.location.origin)) window.history.back(); else window.location.href = home; };
  return <div className="flex items-center gap-1 mb-2 text-sm">
    <button type="button" className="px-2 py-1 rounded-lg border bg-white hover:bg-slate-50 font-semibold" onClick={back} title="Quay lại trang trước">← Quay lại</button>
    <a className="px-2 py-1 rounded-lg border bg-white hover:bg-slate-50 font-semibold" href={home} title="Về phòng của tôi">🏠 Phòng tôi</a>
    <a className="px-2 py-1 rounded-lg border bg-white hover:bg-slate-50" href="/trang-chu" title="Trang chủ">Trang chủ</a>
    {/* KHÔNG đặt tên "Tiếp →": trùng với nút "Tiếp →" của form ghi 3 chạm → công nhân bấm nhầm,
        nhảy sang trang khác và mất dữ liệu đang nhập. Dùng ký hiệu tiến/lùi rõ ràng. */}
    <button type="button" className="px-2 py-1 rounded-lg border bg-white hover:bg-slate-50 font-semibold" onClick={() => window.history.forward()} title="Tiến tới trang vừa quay lại" aria-label="Tiến tới trang vừa quay lại">↷</button>
    {title && <span className="ml-2 text-slate-500 truncate hidden sm:inline">/ {title}</span>}
  </div>;
}
