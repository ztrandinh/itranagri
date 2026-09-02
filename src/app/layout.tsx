import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const sans = Inter({
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
// #1f6f78 = --brand (light mode) — khớp màu thương hiệu teal hiện tại, không phải xanh lá cũ trước khi đổi hướng màu.
export const viewport: Viewport = { themeColor: "#1f6f78", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi" className={sans.variable}>
      <body className="min-h-screen antialiased text-[16px]">{children}</body>
    </html>
  );
}
