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

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi" className={sans.variable}>
      <body className="min-h-screen antialiased text-[16px]">{children}</body>
    </html>
  );
}
