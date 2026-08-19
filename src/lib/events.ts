import { z } from "zod";

/** Cột chung EventBase (client được gửi) */
const base = {
  client_ref: z.string().min(8).max(64),
  ts: z.string().datetime({ offset: true }).optional(),
  source: z.enum(["APP", "PAPER", "IMPORT", "DEVICE", "API", "BACKFILL"]).default("APP"),
  is_backfill: z.boolean().default(false),
  paper_serial: z.string().max(40).nullable().optional(),
  supersedes_id: z.string().uuid().nullable().optional(),
  device_id: z.string().max(64).nullable().optional(),
};
const num = z.coerce.number();
const strArr = z.array(z.string()).default([]);

export const EVENT_SCHEMAS = {
  animal_events: z.object({
    ...base,
    animal_id: z.string().nullable().optional(),
    group_id: z.string().nullable().optional(),
    event_type: z.enum(["NHAP","CACH_LY_VAO","CACH_LY_RA","PHOI","DONG_DUC","KHAM_THAI","DE","CAI_SUA","PHAN_LOAI","CAN","BENH","DIEU_TRI","VACCINE","CHUYEN","CHET","LOAI","XUAT","SO_LUONG","GHI_CHU"]),
    value: num.nullable().optional(), unit: z.string().nullable().optional(),
    detail: z.record(z.string(), z.unknown()).default({}),
    withdrawal_until: z.string().nullable().optional(), photo_urls: strArr,
  }).refine((v) => v.animal_id || v.group_id, { message: "ERR_IDENTITY_REQUIRED" }),
  feed_logs: z.object({
    ...base, batch_ref: z.string().nullable().optional(), recipe_id: z.string().nullable().optional(), recipe_version: num.nullable().optional(),
    dest_location_id: z.string().nullable().optional(), dest_group_id: z.string().nullable().optional(),
    planned_kg: num.nullable().optional(), qty_kg: num.positive(), meal: z.string().nullable().optional(), leftover_pct: num.nullable().optional(), photo_urls: strArr,
  }),
  crop_logs: z.object({
    ...base, plot_id: z.string(), activity: z.enum(["LAM_DAT","GIEO","BON","PHUN","TUOI","CAT","THU","GIEO_LAI","NDVI"]),
    variety: z.string().nullable().optional(), input_lots: z.array(z.record(z.string(), z.unknown())).default([]),
    qty_kg: num.nullable().optional(), moisture_pct: num.nullable().optional(), machine_id: z.string().nullable().optional(), machine_hours: num.nullable().optional(),
    fuel_l: num.nullable().optional(), water_source: z.string().nullable().optional(), water_m3: num.nullable().optional(),
    chemical: z.boolean().default(false), director_order: z.string().nullable().optional(), phi_until: z.string().nullable().optional(), photo_urls: strArr,
  }),
  batch_logs: z.object({
    ...base, batch_code: z.string().nullable().optional(), line: z.string(), recipe_id: z.string().nullable().optional(), recipe_version: num.nullable().optional(),
    location_id: z.string().nullable().optional(), inputs: z.array(z.record(z.string(), z.unknown())).default([]), outputs: z.array(z.record(z.string(), z.unknown())).default([]),
    qc: z.record(z.string(), z.unknown()).default({}), ccp_readings: z.array(z.record(z.string(), z.unknown())).default([]), temp_c: num.nullable().optional(), moisture_pct: num.nullable().optional(),
  }),
  inventory_moves: z.object({
    ...base, warehouse_id: z.string(), sku: z.string(), lot_id: z.string().nullable().optional(), lot_no: z.string().nullable().optional(),
    direction: z.union([z.literal(1), z.literal(-1)]), qty: num.positive(), unit: z.string().nullable().optional(), unit_cost: num.nullable().optional(),
    reason: z.string(), from_to: z.string().nullable().optional(), weigh_point: z.string().nullable().optional(), ref_type: z.string().nullable().optional(), ref_id: z.string().nullable().optional(), bin_id: z.string().nullable().optional(), to_bin_id: z.string().nullable().optional(),
  }),
  weigh_tickets: z.object({ ...base, scale_device_id: z.string().nullable().optional(), plate: z.string().nullable().optional(), gross_kg: num.nullable().optional(), tare_kg: num.nullable().optional(), net_kg: num, purpose: z.string().nullable().optional(), sku: z.string().nullable().optional(), partner_id: z.string().nullable().optional(), photo_urls: strArr }),
  gate_logs: z.object({ ...base, plate: z.string(), direction: z.enum(["VAO","RA"]), weighed: z.boolean().default(false), anolyte_wash: z.boolean().default(false), purpose: z.string().nullable().optional(), driver: z.string().nullable().optional(), photo_urls: strArr }),
  sales: z.object({ ...base, partner_id: z.string(), sku: z.string(), lot_id: z.string().nullable().optional(), qty: num.positive(), unit: z.string().nullable().optional(), price: num, amount: num.optional(), channel: num.int().min(1).max(5), payment: z.string().default("CK"), paid: z.boolean().default(false), invoice_no: z.string().nullable().optional() , detail: z.record(z.string(), z.unknown()).nullable().optional(), sales_rep_id: z.string().nullable().optional()}),
  checklist_runs: z.object({ ...base, sop_code: z.string(), sop_version: num.nullable().optional(), shift: z.string(), results: z.array(z.record(z.string(), z.unknown())).default([]), all_green: z.boolean().default(false), note: z.string().nullable().optional() }),
  incidents: z.object({ ...base, kind: z.string(), severity: z.enum(["THAP","TRUNG","CAO","NGHIEM_TRONG","NEAR_MISS"]), description: z.string(), location_id: z.string().nullable().optional(), photo_urls: strArr }),
  stocktakes: z.object({ ...base, warehouse_id: z.string(), counted_by: z.string().nullable().optional(), lines: z.array(z.record(z.string(), z.unknown())).default([]), camera_count: num.nullable().optional(), note: z.string().nullable().optional() }),
  adjustments: z.object({ ...base, target_table: z.string(), target_id: z.string().uuid().nullable().optional(), warehouse_id: z.string().nullable().optional(), sku: z.string().nullable().optional(), lot_id: z.string().nullable().optional(), delta: num.nullable().optional(), reason: z.string().min(3) }),
  paper_scans: z.object({ ...base, form_code: z.string().regex(/^BM\d{2}$/), serial: z.string().regex(/^F\d{2}-BM\d{2}-\d{6}$/), photo_url: z.string().nullable().optional(), anomaly: z.string().nullable().optional() }),
  crop_inputs: z.object({ ...base, season_id: z.string().nullable().optional(), plot_id: z.string(), sku: z.string().nullable().optional(), product_name: z.string().nullable().optional(), kind: z.string(), qty: num, unit: z.string().nullable().optional(), dose_per_ha: num.nullable().optional(), method: z.string().nullable().optional(), target_pest: z.string().nullable().optional(), phi_days: num.nullable().optional(), safe_after: z.string().nullable().optional(), applicator_id: z.string().nullable().optional(), weather: z.string().nullable().optional(), temp_c: num.nullable().optional(), wind: z.string().nullable().optional(), ppe_ok: z.boolean().nullable().optional(), organic_allowed: z.boolean().nullable().optional(), lot_no: z.string().nullable().optional(), note: z.string().nullable().optional() }),
  irrigation_logs: z.object({ ...base, plot_id: z.string(), season_id: z.string().nullable().optional(), method: z.string().nullable().optional(), minutes: num.nullable().optional(), volume_m3: num.nullable().optional(), flow_m3h: num.nullable().optional(), water_source: z.string().nullable().optional(), pump_id: z.string().nullable().optional(), energy_kwh: num.nullable().optional(), ec_water: num.nullable().optional(), ph_water: num.nullable().optional(), note: z.string().nullable().optional() }),
  pest_scouting: z.object({ ...base, plot_id: z.string(), season_id: z.string().nullable().optional(), pest: z.string(), pest_kind: z.string().nullable().optional(), stage: z.string().nullable().optional(), density: num.nullable().optional(), unit: z.string().nullable().optional(), threshold: num.nullable().optional(), sample_points: num.nullable().optional(), incidence_pct: num.nullable().optional(), severity: num.nullable().optional(), natural_enemies: z.string().nullable().optional(), ipm_level: z.string().nullable().optional(), action: z.string().nullable().optional(), action_due: z.string().nullable().optional(), note: z.string().nullable().optional() }),
  harvests: z.object({ ...base, season_id: z.string().nullable().optional(), plot_id: z.string(), crop: z.string().nullable().optional(), variety: z.string().nullable().optional(), qty_kg: num, unit: z.string().nullable().optional(), moisture_pct: num.nullable().optional(), grade: z.string().nullable().optional(), brix: num.nullable().optional(), harvest_lot: z.string().nullable().optional(), crew: strArr, machine_id: z.string().nullable().optional(), weigh_ticket_id: z.string().nullable().optional(), dest_warehouse_id: z.string().nullable().optional(), dest_lot_id: z.string().nullable().optional(), phi_ok: z.boolean().nullable().optional(), residue_test: z.string().nullable().optional(), buyer_partner_id: z.string().nullable().optional(), price: num.nullable().optional(), note: z.string().nullable().optional() }),
  pos_receipts: z.object({ ...base, shift_id: z.string().nullable().optional(), receipt_no: z.string().nullable().optional(), partner_id: z.string().nullable().optional(), lines: z.array(z.object({ sku: z.string(), qty: num, price: num, amount: num.optional(), name: z.string().optional() })).min(1), subtotal: num.nullable().optional(), discount: num.nullable().optional(), promotion_id: z.string().nullable().optional(), tax: num.nullable().optional(), total: num, payment: z.string().default("TM"), paid: num.nullable().optional(), change_due: num.nullable().optional(), channel_code: z.string().default("POS"), note: z.string().nullable().optional() }),
  // Lưu mẫu thức ăn — nghĩa vụ BẮT BUỘC theo ATTP, trước đây bếp không có chỗ nào để ghi.
  food_samples: z.object({ ...base, meal: z.enum(["SANG","TRUA","CHIEU","TIEC"]), dish_name: z.string().min(1), sample_gram: num.positive(), stored_at: z.string().nullable().optional(), temp_c: num.nullable().optional(), keep_until: z.string().nullable().optional(), note: z.string().nullable().optional(), photo_urls: strArr }),
  // Nhiệt độ chuỗi lạnh trên đường — thiếu mắt xích này thì chuỗi truy xuất lạnh đứt.
  cold_chain_logs: z.object({ ...base, vehicle_id: z.string().nullable().optional(), leg: z.enum(["XEP_HANG","DOC_DUONG","GIAO_HANG"]), temp_c: num, temp_max_c: num.nullable().optional(), door_open: z.boolean().default(false), location_note: z.string().nullable().optional(), note: z.string().nullable().optional(), photo_urls: strArr }),
  // Hiệu chuẩn thiết bị — bảng đã có sẵn từ trước, chỉ thiếu form cho KTV thiết bị.
  calibrations: z.object({ ...base, target_device_id: z.string(), method: z.string().nullable().optional(), before_val: num.nullable().optional(), after_val: num.nullable().optional(), result: z.enum(["DAT","KHONG_DAT","DA_HIEU_CHINH"]), next_due: z.string().nullable().optional() }),
  hosp_folio: z.object({ ...base, booking_id: z.string().nullable().optional(), event_id: z.string().nullable().optional(), tour_booking_id: z.string().nullable().optional(), guest_partner_id: z.string().nullable().optional(), kind: z.string(), description: z.string().nullable().optional(), service_id: z.string().nullable().optional(), menu_id: z.string().nullable().optional(), sku: z.string().nullable().optional(), qty: num.nullable().optional(), unit_price: num.nullable().optional(), amount: num, payment: z.string().nullable().optional(), note: z.string().nullable().optional() }),
} as const;

export type EventTable = keyof typeof EVENT_SCHEMAS;
export const EVENT_TABLES = Object.keys(EVENT_SCHEMAS) as EventTable[];

/** Vai nào ghi bảng nào (worker theo phân hệ — kiểm thêm ở UI). */
export const WRITE_MATRIX: Record<EventTable, string[]> = {
  animal_events: ["worker","team_lead","tech_head","director"], feed_logs: ["worker","team_lead","tech_head"], crop_logs: ["worker","team_lead","tech_head"],
  batch_logs: ["worker","team_lead","tech_head"], inventory_moves: ["worker","team_lead","tech_head","accountant","director"], weigh_tickets: ["worker","team_lead","tech_head"],
  gate_logs: ["worker","team_lead","tech_head","director"], sales: ["worker","team_lead","director","accountant"], checklist_runs: ["worker","team_lead","tech_head"],
  incidents: ["worker","team_lead","tech_head","director","it_engineer","accountant"], stocktakes: ["worker","team_lead","tech_head","accountant"],
  adjustments: ["team_lead","tech_head","accountant","director"], paper_scans: ["worker","team_lead","tech_head","director","accountant"],
  irrigation_logs: ["worker","team_lead","tech_head","director"], pest_scouting: ["worker","team_lead","tech_head","director"], crop_inputs: ["worker","team_lead","tech_head","director"], harvests: ["worker","team_lead","tech_head","director"], pos_receipts: ["worker","team_lead","director","accountant"], hosp_folio: ["worker","team_lead","director","accountant"],
  food_samples: ["worker","team_lead","tech_head","auditor"], cold_chain_logs: ["worker","team_lead","tech_head"], calibrations: ["worker","team_lead","tech_head","it_engineer"],
};
