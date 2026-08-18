/** Danh mục chỉ số cho trang Số liệu — mỗi chỉ số = SQL chuỗi thời gian; {B} = biểu thức bucket, $1 farm, $2 from, $3 to.
 * Trả về cột: t (bucket), dim (chiều, có thể null), v (giá trị). */
export type Metric = { code: string; name: string; unit: string; group: string; sql: string; dims?: string[]; agg?: "sum" | "avg" | "count"; records?: string; norm?: string };
// records: SQL trả bản ghi gốc cho 1 điểm: {T} = bucket expr, $1 farm, $2 t (bucket start), $3 dimval; {DF} = điều kiện chiều
const B = "{B}";
export const METRICS: Metric[] = [
  // Cho ăn
  { code: "feed_kg", name: "Thức ăn cho ăn (kg)", unit: "kg", group: "Chăn nuôi", agg: "sum", dims: ["dest_group_id", "recipe_id", "meal"], norm: "TA_KG_CON_NGAY",
    sql: `select ${B} as t, {D} as dim, sum(qty_kg) as v from feed_logs where farm_id=$1 and status='ACTIVE' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, dest_group_id, recipe_id, meal, planned_kg, qty_kg, source, is_backfill, paper_serial from feed_logs where farm_id=$1 and status='ACTIVE' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "feed_err", name: "Sai số mẻ TMR (%)", unit: "%", group: "Chăn nuôi", agg: "avg", dims: ["dest_group_id", "created_by"],
    sql: `select ${B} as t, {D} as dim, avg(abs(qty_kg-planned_kg)/nullif(planned_kg,0))*100 as v from feed_logs where farm_id=$1 and status='ACTIVE' and planned_kg>0 and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, dest_group_id, planned_kg, qty_kg, round(abs(qty_kg-planned_kg)/nullif(planned_kg,0)*100,2) as err_pct, source from feed_logs where farm_id=$1 and status='ACTIVE' and planned_kg>0 and {T}=$2::timestamptz {DF} order by ts` },
  { code: "weight_avg", name: "Cân nặng TB (kg)", unit: "kg", group: "Chăn nuôi", agg: "avg", dims: ["animal_id", "group_id"],
    sql: `select ${B} as t, {D} as dim, avg(value) as v from animal_events where farm_id=$1 and status='ACTIVE' and event_type='CAN' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, animal_id, group_id, value as kg, source from animal_events where farm_id=$1 and status='ACTIVE' and event_type='CAN' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "deaths", name: "Chết (con)", unit: "con", group: "Chăn nuôi", agg: "sum", dims: ["group_id", "animal_id"],
    sql: `select ${B} as t, {D} as dim, sum(coalesce(value,1)) as v from animal_events where farm_id=$1 and status='ACTIVE' and event_type='CHET' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, animal_id, group_id, value, detail, source from animal_events where farm_id=$1 and status='ACTIVE' and event_type='CHET' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "repro_events", name: "Sự kiện sinh sản (số lần)", unit: "lần", group: "Chăn nuôi", agg: "sum", dims: ["event_type"],
    sql: `select ${B} as t, {D} as dim, count(*) as v from animal_events where farm_id=$1 and status='ACTIVE' and event_type in ('DONG_DUC','PHOI','KHAM_THAI','DE','CAI_SUA') and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, animal_id, event_type, detail from animal_events where farm_id=$1 and status='ACTIVE' and event_type in ('DONG_DUC','PHOI','KHAM_THAI','DE','CAI_SUA') and {T}=$2::timestamptz {DF} order by ts` },
  { code: "treatments", name: "Điều trị / vaccine (lần)", unit: "lần", group: "Chăn nuôi", agg: "sum", dims: ["event_type", "animal_id"],
    sql: `select ${B} as t, {D} as dim, count(*) as v from animal_events where farm_id=$1 and status='ACTIVE' and event_type in ('DIEU_TRI','VACCINE','BENH') and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, animal_id, event_type, value, withdrawal_until, detail from animal_events where farm_id=$1 and status='ACTIVE' and event_type in ('DIEU_TRI','VACCINE','BENH') and {T}=$2::timestamptz {DF} order by ts` },
  { code: "eggs", name: "Trứng nhập kho (vỉ)", unit: "vỉ", group: "Gia cầm", agg: "sum", dims: ["lot_id"],
    sql: `select ${B} as t, {D} as dim, sum(qty) as v from inventory_moves m where farm_id=$1 and status='ACTIVE' and direction=1 and sku like 'SKU-TRUNG%' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, warehouse_id, sku, lot_id, qty, source from inventory_moves where farm_id=$1 and status='ACTIVE' and direction=1 and sku like 'SKU-TRUNG%' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "eggs_counted", name: "Trứng đếm băng chuyền (quả)", unit: "quả", group: "Gia cầm", agg: "sum", dims: ["group_id"],
    sql: `select ${B} as t, {D} as dim, sum(value) as v from animal_events where farm_id=$1 and status='ACTIVE' and event_type='SO_LUONG' and detail->>'metric'='eggs_counted' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, group_id, value from animal_events where farm_id=$1 and status='ACTIVE' and event_type='SO_LUONG' and detail->>'metric'='eggs_counted' and {T}=$2::timestamptz {DF} order by ts` },
  // Trồng trọt
  { code: "harvest_kg", name: "Thu hoạch / cắt sinh khối (kg)", unit: "kg", group: "Trồng trọt", agg: "sum", dims: ["plot_id", "variety", "activity"],
    sql: `select ${B} as t, {D} as dim, sum(qty_kg) as v from crop_logs where farm_id=$1 and status='ACTIVE' and activity in ('THU','CAT') and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, plot_id, activity, variety, qty_kg, moisture_pct, machine_id, weigh_ticket_id, source from crop_logs where farm_id=$1 and status='ACTIVE' and activity in ('THU','CAT') and {T}=$2::timestamptz {DF} order by ts` },
  { code: "machine_hours", name: "Giờ máy", unit: "giờ", group: "Trồng trọt", agg: "sum", dims: ["machine_id", "plot_id", "activity"],
    sql: `select ${B} as t, {D} as dim, sum(machine_hours) as v from crop_logs where farm_id=$1 and status='ACTIVE' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, plot_id, activity, machine_id, machine_hours, fuel_l from crop_logs where farm_id=$1 and status='ACTIVE' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "fuel_l", name: "Nhiên liệu xuất K7 (lít)", unit: "l", group: "Trồng trọt", agg: "sum", dims: ["from_to"],
    sql: `select ${B} as t, {D} as dim, sum(qty) as v from inventory_moves where farm_id=$1 and status='ACTIVE' and direction=-1 and sku='NL-DAU' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, from_to, qty, weigh_point from inventory_moves where farm_id=$1 and status='ACTIVE' and direction=-1 and sku='NL-DAU' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "crop_activities", name: "Hoạt động ruộng (số lần)", unit: "lần", group: "Trồng trọt", agg: "sum", dims: ["activity", "plot_id"],
    sql: `select ${B} as t, {D} as dim, count(*) as v from crop_logs where farm_id=$1 and status='ACTIVE' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, plot_id, activity, variety, qty_kg, machine_id from crop_logs where farm_id=$1 and status='ACTIVE' and {T}=$2::timestamptz {DF} order by ts` },
  // Khu D / D5 / chế biến
  { code: "batch_in_kg", name: "Khu D nạp liệu (kg)", unit: "kg", group: "Sinh học – D5", agg: "sum", dims: ["line", "location_id"],
    sql: `select ${B} as t, {D} as dim, sum((i->>'kg')::numeric) as v from batch_logs b, jsonb_array_elements(b.inputs) i where farm_id=$1 and status='ACTIVE' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, batch_code, line, location_id, inputs, temp_c from batch_logs where farm_id=$1 and status='ACTIVE' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "batch_out_kg", name: "Sản phẩm mẻ ra (kg)", unit: "kg", group: "Sinh học – D5", agg: "sum", dims: ["line", "location_id"],
    sql: `select ${B} as t, {D} as dim, sum((o->>'kg')::numeric) as v from batch_logs b, jsonb_array_elements(b.outputs) o where farm_id=$1 and status='ACTIVE' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, batch_code, line, location_id, outputs, qc from batch_logs where farm_id=$1 and status='ACTIVE' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "batches", name: "Số mẻ", unit: "mẻ", group: "Sinh học – D5", agg: "sum", dims: ["line"],
    sql: `select ${B} as t, {D} as dim, count(*) as v from batch_logs where farm_id=$1 and status='ACTIVE' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, batch_code, line, location_id from batch_logs where farm_id=$1 and status='ACTIVE' and {T}=$2::timestamptz {DF} order by ts` },
  // Kho
  { code: "stock_in", name: "Nhập kho (số lượng)", unit: "đv", group: "Kho", agg: "sum", dims: ["sku", "warehouse_id", "reason"],
    sql: `select ${B} as t, {D} as dim, sum(qty) as v from inventory_moves where farm_id=$1 and status='ACTIVE' and direction=1 and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, warehouse_id, sku, lot_id, qty, unit, unit_cost, reason, from_to, weigh_point from inventory_moves where farm_id=$1 and status='ACTIVE' and direction=1 and {T}=$2::timestamptz {DF} order by ts` },
  { code: "stock_out", name: "Xuất kho (số lượng)", unit: "đv", group: "Kho", agg: "sum", dims: ["sku", "warehouse_id", "reason"],
    sql: `select ${B} as t, {D} as dim, sum(qty) as v from inventory_moves where farm_id=$1 and status='ACTIVE' and direction=-1 and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, warehouse_id, sku, lot_id, qty, unit, reason, from_to, weigh_point from inventory_moves where farm_id=$1 and status='ACTIVE' and direction=-1 and {T}=$2::timestamptz {DF} order by ts` },
  { code: "stock_value_in", name: "Giá trị nhập mua (đ)", unit: "đ", group: "Kho", agg: "sum", dims: ["sku", "from_to"],
    sql: `select ${B} as t, {D} as dim, sum(qty*coalesce(unit_cost,0)) as v from inventory_moves where farm_id=$1 and status='ACTIVE' and direction=1 and reason='NHAP_MUA' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, sku, lot_id, qty, unit_cost, qty*coalesce(unit_cost,0) as amount, from_to from inventory_moves where farm_id=$1 and status='ACTIVE' and direction=1 and reason='NHAP_MUA' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "silage_days", name: "Ngày-tồn ủ chua (kỳ đối soát)", unit: "ngày", group: "Kho", agg: "avg", dims: [],
    sql: `select ${B} as t, null as dim, avg(case when rule_code='RC1' then null end) as v from recon_results where farm_id=$1 and period between $2 and $3 group by 1 order by 1` },
  // Bán hàng
  { code: "sales_amount", name: "Doanh thu (đ)", unit: "đ", group: "Kinh doanh", agg: "sum", dims: ["channel", "sku", "partner_id", "payment"],
    sql: `select ${B} as t, {D} as dim, sum(amount) as v from sales where farm_id=$1 and status='ACTIVE' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, partner_id, sku, qty, price, amount, channel, payment, paid, lot_id from sales where farm_id=$1 and status='ACTIVE' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "sales_qty", name: "Sản lượng bán", unit: "đv", group: "Kinh doanh", agg: "sum", dims: ["sku", "channel"],
    sql: `select ${B} as t, {D} as dim, sum(qty) as v from sales where farm_id=$1 and status='ACTIVE' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, partner_id, sku, qty, price, amount, channel from sales where farm_id=$1 and status='ACTIVE' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "receivable_new", name: "Bán ghi nợ (đ)", unit: "đ", group: "Kinh doanh", agg: "sum", dims: ["partner_id"],
    sql: `select ${B} as t, {D} as dim, sum(amount) as v from sales where farm_id=$1 and status='ACTIVE' and not paid and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, partner_id, sku, amount, channel from sales where farm_id=$1 and status='ACTIVE' and not paid and {T}=$2::timestamptz {DF} order by ts` },
  // Vận hành
  { code: "records", name: "Số bản ghi (mọi bảng)", unit: "bản ghi", group: "Vận hành", agg: "sum", dims: ["created_by", "source"],
    sql: `select ${B} as t, {D} as dim, count(*) as v from (select ts, created_by, source from animal_events where farm_id=$1 union all select ts, created_by, source from feed_logs where farm_id=$1 union all select ts, created_by, source from crop_logs where farm_id=$1 union all select ts, created_by, source from batch_logs where farm_id=$1 union all select ts, created_by, source from inventory_moves where farm_id=$1 union all select ts, created_by, source from checklist_runs where farm_id=$1 union all select ts, created_by, source from sales where farm_id=$1) u where ts::date between $2 and $3 group by 1,2 order by 1` },
  { code: "alerts", name: "Cảnh báo (số)", unit: "cảnh báo", group: "Vận hành", agg: "sum", dims: ["level", "rule_code"],
    sql: `select ${B} as t, {D} as dim, count(*) as v from alerts where farm_id=$1 and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, rule_code, level, subject, acked_by from alerts where farm_id=$1 and {T}=$2::timestamptz {DF} order by ts` },
  { code: "recon_diff", name: "Đối soát: % lệch", unit: "%", group: "Vận hành", agg: "avg", dims: ["rule_code"],
    sql: `select ${B} as t, {D} as dim, avg(diff_pct) as v from recon_results where farm_id=$1 and period between $2 and $3 group by 1,2 order by 1`,
    records: `select id, period as ts, rule_code, expected, actual, diff_pct, status from recon_results where farm_id=$1 and {T}=$2::timestamptz {DF} order by period` },
  { code: "tasks_done", name: "Việc hoàn thành", unit: "việc", group: "Vận hành", agg: "sum", dims: ["kind", "done_by"],
    sql: `select ${B} as t, {D} as dim, count(*) as v from tasks where farm_id=$1 and status='XONG' and done_at::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, done_at as ts, done_by as created_by, kind, title from tasks where farm_id=$1 and status='XONG' and {T}=$2::timestamptz {DF} order by done_at` },
  { code: "gate", name: "Xe qua cổng", unit: "xe", group: "Vận hành", agg: "sum", dims: ["direction", "purpose"],
    sql: `select ${B} as t, {D} as dim, count(*) as v from gate_logs where farm_id=$1 and status='ACTIVE' and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select id, ts, created_by, plate, direction, weighed, anolyte_wash, purpose from gate_logs where farm_id=$1 and status='ACTIVE' and {T}=$2::timestamptz {DF} order by ts` },
  { code: "sensor", name: "Cảm biến (TB)", unit: "", group: "IoT", agg: "avg", dims: ["metric", "device_id"],
    sql: `select ${B} as t, {D} as dim, avg(value) as v from sensor_reads where farm_id=$1 and ts::date between $2 and $3 group by 1,2 order by 1`,
    records: `select ts, device_id, metric, value from sensor_reads where farm_id=$1 and {T}=$2::timestamptz {DF} order by ts limit 500` },
];
export const BUCKETS: Record<string, string> = { day: "date_trunc('day', ts)", week: "date_trunc('week', ts)", month: "date_trunc('month', ts)", quarter: "date_trunc('quarter', ts)", year: "date_trunc('year', ts)" };
export function buildSeriesSql(m: Metric, bucket: string, dim: string | null): string {
  const b = BUCKETS[bucket] ?? BUCKETS.day;
  const tsCol = m.code === "tasks_done" ? "done_at" : m.code === "recon_diff" || m.code === "silage_days" ? "period" : "ts";
  let sql = m.sql.replace(B, b.replace("ts", tsCol));
  const safeDim = dim && m.dims?.includes(dim) ? dim : null;
  sql = sql.replace("{D}", safeDim ? `${safeDim}::text` : "null");
  return sql;
}

export function buildRecordsSql(m: Metric, bucket: string, dim: string | null, hasDimVal: boolean): string {
  const b = BUCKETS[bucket] ?? BUCKETS.day;
  const tsCol = m.code === "tasks_done" ? "done_at" : m.code === "recon_diff" || m.code === "silage_days" ? "period" : "ts";
  const safeDim = dim && m.dims?.includes(dim) ? dim : null;
  const base = m.records ?? `select * from (${m.sql.replace("{B}", b).replace("{D}", "null")}) x where t=$2::timestamptz`;
  return base.replace("{T}", b.replace("ts", tsCol)).replace("{DF}", safeDim && hasDimVal ? `and ${safeDim}::text = $3` : "and ($3::text is null or true)");
}
