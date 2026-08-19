"use client";
/** VỎ LAZY cho biểu đồ — giữ nguyên API cũ (`import AnyChart from "@/components/AnyChart"`),
 *  nhưng thư viện biểu đồ (recharts ~400KB) chỉ tải KHI thật sự vẽ biểu đồ.
 *  Trước đây mọi trang có AnyChart/ChartIcon đều phải tải recharts ngay cả khi người dùng
 *  không mở biểu đồ lần nào. Nội dung thật nằm ở AnyChartInner.tsx. */
import dynamic from "next/dynamic";
import { SkeletonText } from "@/components/ui/Skeleton";
import type { AnyChartProps } from "@/components/AnyChartInner";

export type { AnyChartProps };

const load = () => import("@/components/AnyChartInner");
const fallback = () => <div className="p-3"><SkeletonText lines={4} /></div>;

const AnyChart = dynamic(load, { ssr: false, loading: fallback });
export default AnyChart;

/** Bảng bản ghi gốc (drill) — cũng nằm trong module biểu đồ nên lazy chung. */
export const RecordsTable = dynamic(() => load().then((m) => ({ default: m.RecordsTable })), { ssr: false, loading: fallback });

/** Trình khám phá "biểu đồ mọi trường" (trang Số liệu). */
export const AnyExplorer = dynamic(() => load().then((m) => ({ default: m.AnyExplorer })), { ssr: false, loading: fallback });
