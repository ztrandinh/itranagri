import type { NextConfig } from "next";
import bundleAnalyzer from "@next/bundle-analyzer";

const nextConfig: NextConfig = {
  output: "standalone",
  serverExternalPackages: ["pg"],
};

// Trước đây không có tool phân tích bundle size nào — không có chốt chặn nếu ai đó vô tình import
// thư viện nặng vào layout dùng chung. `ANALYZE=true pnpm build` sinh report .next/analyze/*.html.
const withBundleAnalyzer = bundleAnalyzer({ enabled: process.env.ANALYZE === "true" });

export default withBundleAnalyzer(nextConfig);
