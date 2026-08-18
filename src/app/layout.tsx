import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ITRAN OS",
  description: "Hệ điều hành số trang trại tuần hoàn ITRAN FARM",
  manifest: "/manifest.webmanifest",
  appleWebApp: { capable: true, title: "ITRAN OS", statusBarStyle: "default" },
};
// Bỏ maximumScale để không chặn phóng to (WCAG 1.4.4 Resize text) — người thị lực kém phóng to được.
export const viewport: Viewport = { themeColor: "#166534", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi">
      <body className="min-h-screen bg-stone-50 text-stone-900 antialiased text-[17px]">{children}</body>
    </html>
  );
}
