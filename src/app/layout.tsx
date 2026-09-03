import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

// Trước đây load 5 weight (400/500/600/700/800) — nhưng weight 800 (font-extrabold) KHÔNG hề dùng
// ở đâu trong codebase (grep xác nhận 0 kết quả), trong khi `font-black` (weight 900, dùng ~40 lần
// cho tiêu đề toàn app) lại KHÔNG được load — mọi tiêu đề "font-black" trước đây render sai độ đậm
// (browser tự chọn weight gần nhất thay vì 900 thật). Sửa đúng bộ weight thật sự dùng (400/600/700/900,
// gộp font-medium hiếm dùng vào font-semibold — xem Field.tsx) — vừa giảm 1 weight vừa vá đúng lỗi hiển thị.
const sans = Inter({
  subsets: ["latin", "vietnamese"],
  weight: ["400", "600", "700", "900"],
  variable: "--font-sans",
  display: "swap",
});

export const metadata: Metadata = {
  title: "ITRAN AGRI",
  description: "Hệ điều hành số trang trại tuần hoàn ITRAN FARM",
  manifest: "/manifest.webmanifest",
  appleWebApp: { capable: true, title: "ITRAN AGRI", statusBarStyle: "default" },
};
// Bỏ maximumScale để không chặn phóng to (WCAG 1.4.4 Resize text) — người thị lực kém phóng to được.
// #1f6f78 = --brand (light mode) — khớp màu thương hiệu teal hiện tại, không phải xanh lá cũ trước khi đổi hướng màu.
export const viewport: Viewport = { themeColor: "#1f6f78", width: "device-width", initialScale: 1 };

/** Đặt data-theme TRƯỚC khi React vẽ khung đầu tiên — tránh nháy tối (máy đặt tối) rồi mới về sáng
 *  khi ThemeBoot (useEffect) chạy sau. Mặc định "light" khớp với DEFAULT_MODE ở ThemeToggle.tsx. */
const THEME_BOOT_SCRIPT = `try{var t=localStorage.getItem("itran.theme")||"light";if(t!=="system")document.documentElement.setAttribute("data-theme",t);}catch(e){}`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi" className={sans.variable} suppressHydrationWarning>
      <head><script dangerouslySetInnerHTML={{ __html: THEME_BOOT_SCRIPT }} /></head>
      <body className="min-h-screen antialiased text-[16px]">{children}</body>
    </html>
  );
}
