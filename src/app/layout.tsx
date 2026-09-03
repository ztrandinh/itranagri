import type { Metadata, Viewport } from "next";
import { Be_Vietnam_Pro } from "next/font/google";
import "./globals.css";

const sans = Be_Vietnam_Pro({
  subsets: ["latin", "vietnamese"],
  weight: ["400", "500", "600", "700", "800"],
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
export const viewport: Viewport = { themeColor: "#166534", width: "device-width", initialScale: 1 };

/** Đặt data-theme TRƯỚC khi React vẽ khung đầu tiên — tránh nháy tối (máy đặt tối) rồi mới về sáng
 *  khi ThemeBoot (useEffect) chạy sau. Mặc định "light" khớp với DEFAULT_MODE ở ThemeToggle.tsx. */
const THEME_BOOT_SCRIPT = `try{var t=localStorage.getItem("itran.theme")||"light";if(t!=="system")document.documentElement.setAttribute("data-theme",t);}catch(e){}`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi" className={sans.variable}>
      <head><script dangerouslySetInnerHTML={{ __html: THEME_BOOT_SCRIPT }} /></head>
      <body className="min-h-screen antialiased text-[16px]">{children}</body>
    </html>
  );
}
