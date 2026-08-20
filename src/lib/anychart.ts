/** Biểu đồ MỌI TRƯỜNG: bất kỳ cột số nào của bảng nghiệp vụ đều vẽ được theo ngày/tuần/tháng/quý/năm,
 * nhóm & lọc theo bất kỳ cột chữ nào (kể cả khóa jsonb detail/qc/inputs). Danh mục lấy từ information_schema → thêm bảng/cột = tự có biểu đồ. */
import type { PoolClient } from "pg";
import { BUCKETS } from "./metrics";
export type AnyTable = { table: string; label: string; ts: string; status?: boolean; jsonb?: string[]; note?: string };
/** Bảng cho phép + cột thời gian (whitelist; cột thì soi tự động) */
export const ANY_TABLES: AnyTable[] = [
  { table: "inventory_moves", label: "Kho: nhập/xuất (mọi mặt hàng: cỏ, ngô, cám, thuốc, dầu, sản phẩm…)", ts: "ts", status: true, jsonb: ["detail"] },
  { table: "weather_daily", label: "Thời tiết ngày (tmin/tmax/mưa/ET0)", ts: "day", status: false },
  { table: "irrigation_logs", label: "Tưới (m3, phút, kWh)", ts: "ts", status: true },
  { table: "pest_scouting", label: "Điều tra dịch hại IPM (mật độ, % nhiễm)", ts: "ts", status: true },
  { table: "soil_tests", label: "Phân tích đất (pH, OM, N/P/K)", ts: "sampled_at", status: false },
  { table: "crop_logs", label: "Trồng trọt: gieo/cắt/thu/tưới/bón (kg, giờ máy, ẩm độ)", ts: "ts", status: true, jsonb: ["detail"] },
  { table: "feed_logs", label: "Cho ăn (kg thực/kế hoạch)", ts: "ts", status: true },
  { table: "animal_events", label: "Sự kiện vật nuôi (cân, sinh sản, điều trị, chết, số lượng)", ts: "ts", status: true, jsonb: ["detail"] },
  { table: "batch_logs", label: "Mẻ khu D/D5/chế biến (nhiệt độ, QC)", ts: "ts", status: true, jsonb: ["qc", "detail"] },
  { table: "weigh_tickets", label: "Phiếu cân", ts: "ts", status: true },
  { table: "gate_logs", label: "Cổng", ts: "ts", status: true },
  { table: "sales", label: "Bán hàng", ts: "ts", status: true },
  { table: "pos_receipts", label: "POS: hóa đơn quầy (doanh thu, thanh toán)", ts: "ts", status: false, jsonb: ["lines"] },
  { table: "checklist_runs", label: "Checklist", ts: "ts", status: true },
  { table: "incidents", label: "Sự cố", ts: "ts", status: true },
  { table: "adjustments", label: "Điều chỉnh", ts: "ts" },
  { table: "stocktakes", label: "Kiểm kê", ts: "ts", status: true },
  { table: "calibrations", label: "Hiệu chuẩn", ts: "ts", status: true },
  { table: "sensor_reads", label: "Cảm biến (mọi metric)", ts: "ts" },
  { table: "tasks", label: "Công việc", ts: "created_at" },
  { table: "purchase_orders", label: "Đơn mua", ts: "created_at" },
  { table: "expense_requests", label: "Đề nghị chi", ts: "created_at" },
  { table: "orders", label: "Đơn bán", ts: "created_at" },
  { table: "alerts", label: "Cảnh báo", ts: "ts" },
  { table: "recon_results", label: "Đối soát", ts: "period" },
  { table: "kpi_results", label: "KPI nhân sự", ts: "period_start" },
  { table: "cc_fixed_costs", label: "Chi phí cố định theo CC", ts: "period" },
  { table: "bank_statement_lines", label: "Sao kê ngân hàng", ts: "ts" },
  { table: "agg_daily", label: "Chỉ số ngày (đã tổng hợp)", ts: "day" },
  { table: "stock_daily", label: "Tồn kho theo ngày (snapshot)", ts: "day" },
  { table: "herd_daily", label: "Đàn theo ngày (snapshot)", ts: "day" },
  { table: "v_animal_feed_daily", label: "Thức ăn nạp/cá thể (phân bổ từ đàn ÷ đầu con)", ts: "ts" },
  { table: "v_animal_growth_month", label: "Tăng trưởng cá thể/tháng (cân · tăng trọng · FCR · ADG)", ts: "ts" },
  { table: "v_plot_yield", label: "Năng suất cây trồng (kg/ha theo ô · cây · mùa)", ts: "ts" },
  { table: "v_group_feed_daily", label: "Thức ăn theo ĐÀN (tổng · /đầu con · theo khẩu phần)", ts: "ts" },
];
const NUM = new Set(["integer", "bigint", "numeric", "double precision", "real", "smallint"]);
const TXT = new Set(["text", "character varying", "boolean", "date", "uuid", "integer", "smallint"]);
export type ColInfo = { name: string; type: string; kind: "num" | "dim" | "other" };
const cache = new Map<string, { at: number; cols: ColInfo[] }>();
export async function tableCols(c: PoolClient, table: string): Promise<ColInfo[]> {
  const hit = cache.get(table); if (hit && Date.now() - hit.at < 600e3) return hit.cols;
  const rows = (await c.query("select column_name, data_type from information_schema.columns where table_schema='public' and table_name=$1 order by ordinal_position", [table])).rows as { column_name: string; data_type: string }[];
  const cols: ColInfo[] = rows.map((r) => ({ name: r.column_name, type: r.data_type, kind: NUM.has(r.data_type) && !/_id$|^id$|version|direction/.test(r.column_name) ? "num" : TXT.has(r.data_type) || r.data_type.startsWith("timestamp") ? "dim" : r.data_type === "jsonb" ? "other" : "other" }));
  cache.set(table, { at: Date.now(), cols }); return cols;
}
const ident = (s: string) => /^[a-z_][a-z0-9_]*$/.test(s);
export type AnyQuery = { table: string; col: string; agg: "sum" | "avg" | "count" | "min" | "max"; bucket: string; dim?: string | null; filters?: Record<string, string>; jsonKey?: string | null };
/** Sinh SQL series: $1 farm, $2 from, $3 to, $4.. filter values */
export function buildAnySql(q: AnyQuery, cols: ColInfo[], tdef: AnyTable): { sql: string; params: string[] } {
  const b = (BUCKETS[q.bucket] ?? BUCKETS.day).replace("ts", tdef.ts);
  const colOk = cols.find((x) => x.name === q.col && (x.kind === "num" || q.agg === "count"));
  const jsonCol = (s: string) => { const [jc, key] = s.split("."); return tdef.jsonb?.includes(jc) && ident(jc) && cols.find((x) => x.name === jc && x.type === "jsonb") && /^[A-Za-z0-9_]+$/.test(key ?? "") ? { jc, key } : null; };
  let vexpr: string;
  if (q.agg === "count") vexpr = "count(*)";
  else if (colOk) vexpr = `${q.agg}(${q.col})`;
  else { const j = jsonCol(q.col); if (!j) throw new Error("ERR_BAD_COLUMN"); vexpr = `${q.agg}(nullif(${j.jc}->>'${j.key}','')::numeric)`; }
  let dexpr = "null";
  if (q.dim) { if (cols.find((x) => x.name === q.dim && x.kind !== "other")) dexpr = `${q.dim}::text`; else { const j = jsonCol(q.dim); if (j) dexpr = `${j.jc}->>'${j.key}'`; } }
  const where: string[] = [`farm_id=$1`, `${tdef.ts}::date between $2 and $3`]; if (tdef.status) where.push("status='ACTIVE'");
  const params: string[] = [];
  for (const [k, v] of Object.entries(q.filters ?? {})) {
    if (v === "" || v == null) continue;
    if (cols.find((x) => x.name === k)) { params.push(v); where.push(`${k}::text = $${params.length + 3}`); }
    else { const j = jsonCol(k); if (j) { params.push(v); where.push(`${j.jc}->>'${j.key}' = $${params.length + 3}`); } }
  }
  return { sql: `select ${b} as t, ${dexpr} as dim, ${vexpr} as v from ${tdef.table} where ${where.join(" and ")} group by 1,2 order by 1`, params };
}
/** Bản ghi gốc của 1 điểm (drill): $1 farm, $2 t, $3 dimval|null, $4.. filters */
export function buildAnyRecordsSql(q: AnyQuery, cols: ColInfo[], tdef: AnyTable, hasDimVal: boolean): { sql: string; params: string[] } {
  const b = (BUCKETS[q.bucket] ?? BUCKETS.day).replace("ts", tdef.ts);
  const where: string[] = [`farm_id=$1`, `${b}=$2::timestamptz`]; if (tdef.status) where.push("status='ACTIVE'");
  if (q.dim && hasDimVal) { if (cols.find((x) => x.name === q.dim)) where.push(`${q.dim}::text=$3`); else { const [jc, key] = q.dim.split("."); if (tdef.jsonb?.includes(jc) && /^[A-Za-z0-9_]+$/.test(key ?? "")) where.push(`${jc}->>'${key}'=$3`); } }
  const params: string[] = [];
  for (const [k, v] of Object.entries(q.filters ?? {})) { if (v === "" || v == null) continue; if (cols.find((x) => x.name === k)) { params.push(v); where.push(`${k}::text=$${params.length + 3}`); } }
  return { sql: `select * from ${tdef.table} where ${where.join(" and ")} order by ${tdef.ts} desc limit 500`, params };
}
/** Giá trị phân biệt của 1 chiều (để dựng dropdown lọc) */
export function distinctSql(tdef: AnyTable, col: string, jsonKey: { jc: string; key: string } | null): string {
  const e = jsonKey ? `${jsonKey.jc}->>'${jsonKey.key}'` : `${col}::text`;
  return `select ${e} as v, count(*) as n from ${tdef.table} where farm_id=$1 and ${e} is not null group by 1 order by 2 desc limit 200`;
}
