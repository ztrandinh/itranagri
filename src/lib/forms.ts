"use client";
import type { ThreeTapSpec, Option } from "@/components/ThreeTap";

export type Ref = {
  animals: Record<string, unknown>[]; groups: Record<string, unknown>[]; warehouses: Record<string, unknown>[]; products: Record<string, unknown>[]; bins?: Record<string, unknown>[];
  plots: Record<string, unknown>[]; recipes: Record<string, unknown>[]; locations: Record<string, unknown>[]; sops: Record<string, unknown>[]; devices: Record<string, unknown>[]; partners: Record<string, unknown>[];
};
const s = (v: unknown) => (v == null ? "" : String(v));
const animalOpts = (r: Ref, filter?: (a: Record<string, unknown>) => boolean): Option[] =>
  r.animals.filter((a) => !["CHET", "XUAT"].includes(s(a.status)) && (!filter || filter(a))).map((a) => ({ id: s(a.id), label: `${s(a.visual_tag) || s(a.id)} · ${s(a.id).slice(-5)}`, sub: `${s(a.status)} · ${s(a.location_name) || s(a.group_name)}`, meta: { rfid: s(a.rfid), visual_tag: s(a.visual_tag) } }));
const groupOpts = (r: Ref, kinds?: string[]): Option[] => r.groups.filter((g) => !kinds || kinds.includes(s(g.kind))).map((g) => ({ id: s(g.id), label: s(g.name), sub: `${s(g.head_count)} con` }));
const binOpts = (r: Ref): Option[] => (r.bins ?? []).map((b) => ({ id: s(b.id), label: `${s(b.warehouse_code)} · ${s(b.code)}`, sub: s(b.zone) }));
const whOpts = (r: Ref, codes?: string[]): Option[] => r.warehouses.filter((w) => !codes || codes.includes(s(w.code))).map((w) => ({ id: s(w.id), label: `${s(w.code)} ${s(w.name)}`.slice(0, 40) }));
const prodOpts = (r: Ref, kinds?: string[]): Option[] => r.products.filter((p) => !kinds || kinds.includes(s(p.kind))).map((p) => ({ id: s(p.sku), label: s(p.name), sub: `${s(p.sku)} · ${s(p.unit)}` }));
const locOpts = (r: Ref, kinds?: string[]): Option[] => r.locations.filter((l) => !kinds || kinds.includes(s(l.kind))).map((l) => ({ id: s(l.id), label: s(l.name), sub: s(l.code) }));

/** Danh sách form theo vai/vị trí — mã form → spec */
export function buildForms(r: Ref, farmId: string): Record<string, ThreeTapSpec> {
  const nowIso = () => new Date().toISOString();
  return {
    // A1 · TMR cho ăn
    feed_tmr: {
      table: "feed_logs", title: "Mẻ TMR / cho ăn", targetLabel: "Chọn khu / đàn nhận", targetKey: "dest_group_id",
      targets: [...groupOpts(r, ["BO_NHOM", "GA_DE", "GA_THIT", "RAS", "AO", "DE"])],
      fields: [
        { key: "recipe_id", label: "Công thức", type: "choice", options: r.recipes.map((x) => ({ id: s(x.id), label: s(x.name) })), required: true },
        { key: "meal", label: "Cữ", type: "choice", options: [{ id: "SANG", label: "Sáng" }, { id: "CHIEU", label: "Chiều" }, { id: "KHAC", label: "Khác" }], required: true },
        { key: "qty_kg", label: "Khối lượng thực (cân xe trộn)", type: "number", unit: "kg", min: 0, step: 10, required: true },
        { key: "planned_kg", label: "Kế hoạch mẻ", type: "number", unit: "kg", min: 0, step: 10 },
        { key: "leftover_pct", label: "Thừa máng hôm trước", type: "number", unit: "%", min: 0, max: 100, step: 1 },
        { key: "photo", label: "Ảnh máng", type: "photo" },
      ],
      build: (t, v) => ({ ...v, recipe_version: Number(r.recipes.find((x) => s(x.id) === v.recipe_id)?.version ?? 1), dest_location_id: s(r.groups.find((g) => s(g.id) === t.id)?.location_id) || null }),
    },
    // A2 · sự kiện bò
    animal_event: {
      table: "animal_events", title: "Sự kiện con vật", targetLabel: "Quét tai / chọn con", targetKey: "animal_id", targets: animalOpts(r), allowScanInput: true,
      fields: [
        { key: "event_type", label: "Loại sự kiện", type: "choice", required: true, options: [
          { id: "DONG_DUC", label: "Động dục" }, { id: "PHOI", label: "Phối TTNT" }, { id: "KHAM_THAI", label: "Khám thai" }, { id: "DE", label: "Đẻ" }, { id: "CAI_SUA", label: "Cai sữa" },
          { id: "CAN", label: "Cân" }, { id: "BCS", label: "Thể trạng BCS (1–5)" }, { id: "VAT_SUA", label: "Vắt sữa (kg)" }, { id: "AN_THUA", label: "Ăn thừa (kg)" }, { id: "TAY_KY_SINH", label: "Tẩy ký sinh" }, { id: "BENH", label: "Bệnh nghi" }, { id: "DIEU_TRI", label: "Điều trị" }, { id: "VACCINE", label: "Vaccine" }, { id: "CHUYEN", label: "Chuyển chuồng" }, { id: "CHET", label: "Chết" }, { id: "GHI_CHU", label: "Ghi chú" }] },
        { key: "value", label: "Giá trị (kg cân / BCS 1–5 / kg sữa / số liều …)", type: "number", step: 0.5, min: 0 },
        { key: "result", label: "Kết quả (khám thai + / −)", type: "choice", options: [{ id: "+", label: "Dương (+)" }, { id: "-", label: "Âm (−)" }] },
        { key: "vaccine_name", label: "Vaccine (nếu tiêm)", type: "choice", options: [{ id: "LMLM (lở mồm long móng)", label: "LMLM" }, { id: "Tụ huyết trùng", label: "Tụ huyết trùng" }, { id: "Viêm da nổi cục", label: "Viêm da nổi cục" }, { id: "Newcastle", label: "Newcastle" }, { id: "Gumboro", label: "Gumboro" }, { id: "Cúm gia cầm H5N1", label: "Cúm H5N1" }] },
        { key: "withdrawal_days", label: "Ngưng thuốc (ngày) — nếu điều trị", type: "number", min: 0, max: 90, step: 1 },
        { key: "note", label: "Ghi chú", type: "text", placeholder: "triệu chứng / thuốc / mã tinh…" },
        { key: "photo", label: "Ảnh", type: "photo" },
      ],
      build: (t, v) => {
        const et = s(v.event_type); const detail: Record<string, unknown> = { note: v.note ?? null, ...(et === "VACCINE" && v.vaccine_name ? { vaccine: v.vaccine_name } : {}) };
        if (et === "KHAM_THAI") { detail.result = v.result ?? null; if (v.result === "+") detail.new_status = "MANG_THAI"; }
        if (et === "PHOI") detail.new_status = "PHOI"; if (et === "DE") detail.new_status = "NUOI_CON"; if (et === "CAI_SUA") detail.new_status = "CHO_PHOI";
        if (et === "CAN") { detail.gain_kg = null; }
        const wd = v.withdrawal_days ? new Date(Date.now() + Number(v.withdrawal_days) * 86400e3).toISOString().slice(0, 10) : null;
        const { result, withdrawal_days, note, vaccine_name, ...rest } = v; void result; void withdrawal_days; void note; void vaccine_name;
        return { ...rest, event_type: et, unit: et === "CAN" || et === "VAT_SUA" || et === "AN_THUA" ? "kg" : et === "BCS" ? "diem" : et === "VACCINE" || et === "DIEU_TRI" || et === "TAY_KY_SINH" ? "lieu" : null, detail, withdrawal_until: et === "DIEU_TRI" || et === "VACCINE" ? wd : null };
      },
    },
    // A3 · gà: trứng, chết, đếm
    poultry_daily: {
      table: "animal_events", title: "Gà — chết / loại / đếm", targetLabel: "Chọn khối/lứa", targetKey: "group_id", targets: groupOpts(r, ["GA_DE", "GA_THIT"]),
      fields: [
        { key: "event_type", label: "Việc", type: "choice", required: true, options: [{ id: "CHET", label: "Chết" }, { id: "LOAI", label: "Loại" }, { id: "SO_LUONG", label: "Đếm trứng băng chuyền" }, { id: "GHI_CHU", label: "Ghi chú (anolyte, đệm lót)" }] },
        { key: "value", label: "Số con / số quả", type: "number", min: 0, step: 1, required: true },
        { key: "note", label: "Ghi chú", type: "text" },
      ],
      build: (t, v) => ({ ...v, unit: v.event_type === "SO_LUONG" ? "qua" : "con", detail: v.event_type === "SO_LUONG" ? { metric: "eggs_counted", note: v.note ?? null } : { note: v.note ?? null }, note: undefined }),
    },
    egg_in: {
      table: "inventory_moves", title: "Nhập trứng cuối ca → K5", targetLabel: "Chọn kho K5", targetKey: "warehouse_id", targets: whOpts(r, ["K5"]),
      fields: [{ key: "qty", label: "Số vỉ (10 quả)", type: "number", min: 0, step: 10, required: true }, { key: "grade", label: "Loại", type: "choice", options: [{ id: "A", label: "Loại A" }, { id: "B", label: "Loại B" }] }],
      build: (t, v) => ({ ...v, sku: "SKU-TRUNG-10", lot_no: `${farmId}-ME-${nowIso().slice(2, 10).replace(/-/g, "")}-TR${v.grade ?? "A"}`, direction: 1, unit: "vi", reason: "NHAP_SX", from_to: "GA-DE", weigh_point: "APP", grade: undefined }),
    },
    // A4 · RAS
    ras_daily: {
      table: "animal_events", title: "RAS — chết vớt / DO tay", targetLabel: "Chọn bể", targetKey: "group_id", targets: groupOpts(r, ["RAS", "AO", "BE"]),
      fields: [{ key: "event_type", label: "Việc", type: "choice", required: true, options: [{ id: "CHET", label: "Chết vớt" }, { id: "GHI_CHU", label: "DO/pH đo tay" }, { id: "SO_LUONG", label: "Ước sinh khối (kg)" }] }, { key: "value", label: "Số con / DO mg/l / kg", type: "number", min: 0, step: 1, required: true }, { key: "note", label: "Ghi chú", type: "text" }],
      build: (t, v) => ({ ...v, unit: v.event_type === "CHET" ? "con" : "kg", detail: { metric: v.event_type === "GHI_CHU" ? "DO" : v.event_type === "SO_LUONG" ? "biomass_kg" : null, note: v.note ?? null }, note: undefined }),
    },
    ras_feed: {
      table: "feed_logs", title: "Cho ăn bể RAS", targetLabel: "Chọn bể", targetKey: "dest_group_id", targets: groupOpts(r, ["RAS", "AO", "BE"]),
      fields: [{ key: "qty_kg", label: "Lượng viên", type: "number", unit: "kg", min: 0, step: 0.5, required: true }, { key: "meal", label: "Cữ", type: "choice", options: [{ id: "SANG", label: "Sáng" }, { id: "TRUA", label: "Trưa" }, { id: "CHIEU", label: "Chiều" }, { id: "TOI", label: "Tối" }], required: true }],
    },
    // A5 · trồng trọt
    crop_log: {
      table: "crop_logs", title: "Nhật ký lô", targetLabel: "Chọn lô đất", targetKey: "plot_id", targets: r.plots.map((p) => ({ id: s(p.id), label: s(p.name), sub: `${s(p.area_ha)} ha · ${s(p.current_crop)}` })),
      fields: [
        { key: "activity", label: "Hoạt động", type: "choice", required: true, options: [{ id: "LAM_DAT", label: "Làm đất" }, { id: "GIEO", label: "Gieo/trồng" }, { id: "BON", label: "Bón phân" }, { id: "PHUN", label: "Phun (sinh học)" }, { id: "TUOI", label: "Tưới" }, { id: "CAT", label: "Cắt cỏ" }, { id: "THU", label: "Thu hoạch" }] },
        { key: "machine_id", label: "Máy", type: "choice", options: r.devices.filter((d) => ["MAY_KEO", "MAY_THU", "XE_TRON", "DRONE"].includes(s(d.kind))).map((d) => ({ id: s(d.id), label: s(d.name) })) },
        { key: "machine_hours", label: "Giờ máy", type: "number", unit: "giờ", min: 0, step: 0.5 },
        { key: "qty_kg", label: "Khối lượng thu/cắt (kg, theo vé cân)", type: "number", unit: "kg", min: 0, step: 100 },
        { key: "fuel_l", label: "Nhiên liệu", type: "number", unit: "lít", min: 0, step: 5 },
        { key: "photo", label: "Ảnh", type: "photo" },
      ],
    },
    irrigation: {
      table: "irrigation_logs", title: "Tưới nước", targetLabel: "Chọn lô đất", targetKey: "plot_id", targets: r.plots.map((p) => ({ id: s(p.id), label: s(p.name), sub: `${s(p.area_ha)} ha · ${s(p.current_crop)}` })),
      fields: [
        { key: "method", label: "Cách tưới", type: "choice", required: true, options: [{ id: "PHUN_MUA", label: "Phun mưa" }, { id: "NHO_GIOT", label: "Nhỏ giọt" }, { id: "TRAN", label: "Tràn" }, { id: "RANH", label: "Rãnh" }, { id: "BOM_TAY", label: "Vòi/bơm tay" }, { id: "DRONE", label: "Drone" }] },
        { key: "minutes", label: "Thời gian", type: "number", unit: "phút", min: 0, step: 5, required: true },
        { key: "volume_m3", label: "Lượng nước", type: "number", unit: "m³", min: 0, step: 1 },
        { key: "energy_kwh", label: "Điện bơm", type: "number", unit: "kWh", min: 0, step: 0.5 },
        { key: "photo", label: "Ảnh", type: "photo" },
      ],
    },
    pest_scout: {
      table: "pest_scouting", title: "Điều tra sâu bệnh", targetLabel: "Chọn lô đất", targetKey: "plot_id", targets: r.plots.map((p) => ({ id: s(p.id), label: s(p.name), sub: `${s(p.area_ha)} ha · ${s(p.current_crop)}` })),
      fields: [
        { key: "pest_kind", label: "Loại", type: "choice", required: true, options: [{ id: "SAU", label: "Sâu" }, { id: "BENH", label: "Bệnh" }, { id: "CO_DAI", label: "Cỏ dại" }, { id: "CHUOT", label: "Chuột" }, { id: "OC", label: "Ốc" }, { id: "KHAC", label: "Khác" }] },
        { key: "pest", label: "Tên đối tượng", type: "text", required: true },
        { key: "density", label: "Mật độ", type: "number", unit: "con/m² hoặc %", min: 0, step: 1 },
        { key: "threshold", label: "Ngưỡng", type: "number", unit: "", min: 0, step: 1 },
        { key: "severity", label: "Mức hại 0–5", type: "number", unit: "", min: 0, step: 1 },
        { key: "photo", label: "Ảnh", type: "photo" },
      ],
    },
    fuel_out: {
      table: "inventory_moves", title: "Đổ dầu (trạm dầu K7)", targetLabel: "Máy nhận dầu", targetKey: "from_to", targets: r.devices.filter((d) => d.fuel_l_per_h).map((d) => ({ id: s(d.id), label: s(d.name) })),
      fields: [{ key: "qty", label: "Lít", type: "number", unit: "l", min: 0, step: 5, required: true }],
      build: (t, v) => ({ ...v, warehouse_id: s(r.warehouses.find((w) => s(w.code) === "K7")?.id), sku: "NL-DAU", direction: -1, unit: "l", reason: "XUAT_SX", weigh_point: "TRAM_DAU", ref_type: "device", ref_id: t.id }),
    },
    // A6 · khu D
    bio_batch: {
      table: "batch_logs", title: "Khu D — nạp / thu", targetLabel: "Chọn ô/luống/hầm", targetKey: "location_id", targets: locOpts(r, ["O", "KHU", "NHA"]).filter((o) => /TR-|KHU-D|BSF|BG|CP/.test(o.sub ?? "")),
      fields: [
        { key: "line", label: "Dây chuyền", type: "choice", required: true, options: [{ id: "TRUN_NAP", label: "Nạp trùn" }, { id: "TRUN_THU", label: "Thu phân trùn" }, { id: "BSF", label: "BSF" }, { id: "BIOGAS", label: "Biogas" }, { id: "COMPOST", label: "Compost" }, { id: "IMO_EM", label: "Nhân IMO/EM" }, { id: "ANOLYTE", label: "Anolyte" }] },
        { key: "kg", label: "Khối lượng (kg)", type: "number", unit: "kg", min: 0, step: 50, required: true },
        { key: "temp_c", label: "Nhiệt độ đống/luống", type: "number", unit: "°C", min: 0, max: 90, step: 1 },
        { key: "photo", label: "Ảnh", type: "photo" },
      ],
      build: (t, v) => {
        const line = s(v.line); const kg = Number(v.kg); const { kg: _k, ...rest } = v; void _k;
        if (line === "TRUN_NAP" && Number(v.temp_c) >= 35) throw new Error("ERR_MANURE_TOO_HOT");
        return { ...rest, inputs: ["TRUN_NAP", "BSF", "BIOGAS", "COMPOST"].includes(line) ? [{ sku: "PHAN_UOT", kg }] : [], outputs: line === "TRUN_THU" ? [{ sku: "SKU-PTR-25", kg, lot_id: null }] : ["IMO_EM", "ANOLYTE"].includes(line) ? [{ sku: line, kg }] : [] };
      },
    },
    // A7 · D5 / chế biến
    d5_batch: {
      table: "batch_logs", title: "Mẻ D5 / chế biến", targetLabel: "Chọn dây chuyền/máy", targetKey: "location_id", targets: locOpts(r, ["NHA"]).filter((o) => /D5/.test(o.sub ?? "")),
      fields: [
        { key: "line", label: "Loại mẻ", type: "choice", required: true, options: [{ id: "D5_TMR", label: "TMR" }, { id: "D5_VIEN", label: "Ép viên" }, { id: "U_CHUA", label: "Ủ chua" }, { id: "SO_CHE", label: "Sơ chế" }, { id: "SAY", label: "Sấy" }, { id: "DONG_GOI", label: "Đóng gói" }] },
        { key: "recipe_id", label: "Công thức", type: "choice", options: r.recipes.map((x) => ({ id: s(x.id), label: s(x.name) })) },
        { key: "kg_out", label: "Kg ra", type: "number", unit: "kg", min: 0, step: 10, required: true },
        { key: "labels", label: "Số tem dán", type: "number", min: 0, step: 1 },
        { key: "moisture_pct", label: "Ẩm % (CCP sấy)", type: "number", unit: "%", min: 0, max: 100, step: 0.5 },
        { key: "metal_ok", label: "Kim loại/dị vật đạt", type: "bool" },
      ],
      build: (t, v) => { const { kg_out, labels, metal_ok, ...rest } = v; return { ...rest, outputs: [{ sku: v.line === "D5_VIEN" ? "TA-VIEN-GA" : v.line === "D5_TMR" ? "TA-TMR-VO" : "SP", kg: kg_out, labels: labels ?? 0 }], ccp_readings: [{ ccp: "KIM_LOAI", ok: !!metal_ok }, ...(v.moisture_pct != null ? [{ ccp: "AM_SAY", value: v.moisture_pct, limit: 12 }] : [])] }; },
    },
    // A8 · kho
    stock_in: {
      table: "inventory_moves", title: "NHẬP kho (quét mã)", targetLabel: "Chọn hàng", targetKey: "sku", targets: prodOpts(r),
      fields: [
        { key: "warehouse_id", label: "Kho", type: "choice", options: whOpts(r), required: true },
        { key: "qty", label: "Số lượng", type: "number", min: 0, step: 1, required: true },
        { key: "lot_no", label: "Số lô (NCC / mẻ)", type: "text", required: true, placeholder: "R2608-03" },
        { key: "bin_id", label: "Vị trí bin (kệ/pallet)", type: "choice", options: binOpts(r) },
        { key: "unit_cost", label: "Đơn giá", type: "number", unit: "đ", min: 0, step: 100 },
        { key: "reason", label: "Lý do", type: "choice", options: [{ id: "NHAP_MUA", label: "Mua" }, { id: "NHAP_SX", label: "Sản xuất" }, { id: "TRA", label: "Trả lại" }, { id: "CHUYEN", label: "Chuyển đến" }], required: true },
        { key: "weigh_point", label: "Điểm ghi", type: "choice", options: [{ id: "CAN_CAU_D", label: "Cân cầu D" }, { id: "CUA_KHO", label: "Cửa kho quét" }, { id: "CAN_CONG", label: "Cân cổng" }] },
      ],
      build: (t, v) => ({ ...v, direction: 1, unit: s(r.products.find((p) => s(p.sku) === t.id)?.unit) }),
    },
    stock_out: {
      table: "inventory_moves", title: "XUẤT kho (quét mã)", targetLabel: "Chọn hàng", targetKey: "sku", targets: prodOpts(r),
      fields: [
        { key: "warehouse_id", label: "Kho", type: "choice", options: whOpts(r), required: true },
        { key: "qty", label: "Số lượng", type: "number", min: 0, step: 1, required: true },
        { key: "bin_id", label: "Lấy từ bin", type: "choice", options: binOpts(r) },
        { key: "lot_no", label: "Số lô (FEFO gợi ý)", type: "text", placeholder: "để trống = lô hết hạn trước" },
        { key: "reason", label: "Lý do", type: "choice", options: [{ id: "XUAT_CHO_AN", label: "Cho ăn" }, { id: "XUAT_SX", label: "Sản xuất" }, { id: "XUAT_BAN", label: "Bán" }, { id: "CHUYEN", label: "Chuyển đi" }, { id: "HUY", label: "Hủy/hỏng" }], required: true },
        { key: "from_to", label: "Đến đâu", type: "text", placeholder: "khu / khách / lệnh SX" },
      ],
      build: (t, v) => ({ ...v, direction: -1, unit: s(r.products.find((p) => s(p.sku) === t.id)?.unit), weigh_point: "CUA_KHO" }),
    },
    stocktake: {
      table: "stocktakes", title: "Kiểm kê (đếm mù)", targetLabel: "Chọn kho", targetKey: "warehouse_id", targets: whOpts(r),
      fields: [{ key: "sku", label: "Hàng đếm", type: "choice", options: prodOpts(r), required: true }, { key: "counted", label: "Số đếm được", type: "number", min: 0, step: 1, required: true }, { key: "note", label: "Ghi chú", type: "text" }],
      build: (t, v) => ({ note: v.note ?? null, warehouse_id: v.warehouse_id, client_ref: v.client_ref, ts: v.ts, lines: [{ sku: v.sku, counted: v.counted }] }),
    },
    // A9 · bán hàng
    sale: {
      table: "sales", title: "Bán hàng / giao", targetLabel: "Chọn khách", targetKey: "partner_id", targets: r.partners.filter((p) => ["KH", "KH_NCC"].includes(s(p.kind))).map((p) => ({ id: s(p.id), label: s(p.name), sub: `kênh ${s(p.channel)}` })),
      fields: [
        { key: "sku", label: "Sản phẩm", type: "choice", options: prodOpts(r, ["THANH_PHAM", "BAN_TP"]), required: true },
        { key: "qty", label: "Số lượng", type: "number", min: 0, step: 1, required: true },
        { key: "price", label: "Đơn giá", type: "number", unit: "đ", min: 0, step: 1000, required: true },
        { key: "channel", label: "Kênh", type: "choice", options: [{ id: "1", label: "1 B2B/HĐ" }, { id: "2", label: "2 Quầy/NH" }, { id: "3", label: "3 Online/nhận nuôi" }, { id: "4", label: "4 Resort" }, { id: "5", label: "5 Giống/đào tạo" }], required: true },
        { key: "payment", label: "Thanh toán", type: "choice", options: [{ id: "CK", label: "Chuyển khoản" }, { id: "VIETQR", label: "VietQR" }, { id: "POS", label: "POS" }, { id: "CONG_NO", label: "Ghi nợ" }], required: true },
        { key: "lot_id", label: "Lô (truy xuất)", type: "text", placeholder: "F01-LOT-…" },
      ],
      build: (t, v) => ({ ...v, channel: Number(v.channel), paid: v.payment !== "CONG_NO", unit: s(r.products.find((p) => s(p.sku) === v.sku)?.unit) }),
    },
    // A11 · cổng
    gate: {
      table: "gate_logs", title: "Nhật ký cổng", targetLabel: "Biển số xe (gõ/OCR)", targetKey: "plate", targets: [], allowScanInput: true,
      fields: [{ key: "direction", label: "Chiều", type: "choice", options: [{ id: "VAO", label: "Vào" }, { id: "RA", label: "Ra" }], required: true }, { key: "weighed", label: "Đã qua cân", type: "bool" }, { key: "anolyte_wash", label: "Đã rửa hố anolyte", type: "bool" }, { key: "purpose", label: "Mục đích", type: "text" }, { key: "photo", label: "Ảnh xe", type: "photo" }],
    },
    // Chung · sự cố · checklist
    incident: {
      table: "incidents", title: "Báo sự cố / near-miss", targetLabel: "Nơi xảy ra", targetKey: "location_id", targets: locOpts(r), allowScanInput: true,
      fields: [{ key: "kind", label: "Loại", type: "choice", required: true, options: [{ id: "VAN_HANH", label: "Vận hành" }, { id: "ATTP", label: "ATTP" }, { id: "ATLD", label: "ATLĐ" }, { id: "AN_NINH", label: "An ninh" }, { id: "MOI_TRUONG", label: "Môi trường" }, { id: "THIET_BI", label: "Thiết bị" }, { id: "TAI_LIEU", label: "Tài liệu" }] }, { key: "severity", label: "Mức", type: "choice", required: true, options: [{ id: "NEAR_MISS", label: "Suýt xảy ra" }, { id: "THAP", label: "Thấp" }, { id: "TRUNG", label: "Trung" }, { id: "CAO", label: "Cao" }, { id: "NGHIEM_TRONG", label: "Nghiêm trọng" }] }, { key: "description", label: "Mô tả", type: "text", required: true }, { key: "photo", label: "Ảnh", type: "photo" }],
    },
    checklist: {
      table: "checklist_runs", title: "Checklist ca theo SOP", targetLabel: "Chọn SOP", targetKey: "sop_code", targets: r.sops.filter((x) => s(x.status) === "BAN_HANH").map((x) => ({ id: s(x.code), label: s(x.title), sub: s(x.code) })),
      fields: [{ key: "shift", label: "Ca", type: "choice", options: [{ id: "SANG", label: "Sáng" }, { id: "CHIEU", label: "Chiều" }, { id: "DEM", label: "Đêm" }], required: true }, { key: "all_green", label: "Tất cả bước ĐẠT", type: "bool" }, { key: "note", label: "Nếu có bước không đạt: lý do", type: "text" }],
      build: (t, v) => ({ ...v, sop_version: Number(r.sops.find((x) => s(x.code) === t.id)?.version ?? 1), results: (r.sops.find((x) => s(x.code) === t.id)?.steps as { n: number; a: string }[] | undefined ?? []).map((st) => ({ n: st.n, a: st.a, ok: !!v.all_green })) }),
    },
    paper_submit: {
      table: "paper_scans", title: "📷 Nộp phiếu giấy", targetLabel: "Chọn mẫu phiếu", targetKey: "form_code",
      targets: ["BM01 FEED_LOG", "BM02 EVENT_ANIMAL", "BM03 CROP_LOG", "BM04 BATCH_LOG", "BM05 INVENTORY_MOVE", "BM06 SALE", "BM07 CHECKLIST", "BM08 GATE_LOG", "BM09 KIEM_KE", "BM10 SU_CO"].map((x) => ({ id: x.slice(0, 4), label: x })),
      fields: [{ key: "serial_no", label: "Số seri trên tờ (6 số)", type: "number", min: 1, max: 999999, step: 1, required: true }, { key: "photo", label: "Ảnh tờ phiếu (đủ 4 góc)", type: "photo", required: true }, { key: "anomaly", label: "Bất thường (tờ hỏng, thiếu chữ ký)", type: "text" }],
      build: (t, v) => { const { serial_no, photo_urls, ...rest } = v as Record<string, unknown> & { photo_urls?: string[] }; return { ...rest, serial: `${farmId}-${t.id}-${String(serial_no).padStart(6, "0")}`, photo_url: photo_urls?.[0] ?? null }; },
    },
  };
}

/** Form gợi ý theo vị trí (Phụ lục A) */
export const ROLE_FORMS: Record<string, string[]> = {
  A1: ["feed_tmr", "animal_event", "stock_in", "stock_out", "checklist", "incident", "paper_submit"],
  A2: ["animal_event", "stock_in", "stock_out", "checklist", "incident", "paper_submit"],
  A3: ["poultry_daily", "egg_in", "feed_tmr", "stock_in", "stock_out", "checklist", "incident", "paper_submit"],
  A4: ["ras_daily", "ras_feed", "stock_in", "stock_out", "checklist", "incident", "paper_submit"],
  A5: ["crop_log", "irrigation", "pest_scout", "fuel_out", "stock_in", "stock_out", "checklist", "incident", "paper_submit"],
  A6: ["bio_batch", "stock_in", "stock_out", "checklist", "incident", "paper_submit"],
  A7: ["d5_batch", "stock_in", "checklist", "incident", "paper_submit"],
  A8: ["stock_in", "stock_out", "stocktake", "sale", "checklist", "incident", "paper_submit"],
  A9: ["sale", "stock_in", "stock_out", "incident", "paper_submit"],
  A11: ["gate", "stock_in", "stock_out", "incident", "paper_submit"],
  ALL: ["animal_event", "feed_tmr", "poultry_daily", "egg_in", "ras_daily", "ras_feed", "crop_log", "irrigation", "pest_scout", "fuel_out", "bio_batch", "d5_batch", "stock_in", "stock_out", "stocktake", "sale", "gate", "checklist", "incident", "paper_submit"],
};
export function formsForPosition(position: string | null | undefined, role: string): string[] {
  const m = position?.match(/A(\d{1,2})/); const key = m ? `A${m[1]}` : null;
  if (key && ROLE_FORMS[key]) return ROLE_FORMS[key];
  return role === "worker" ? ROLE_FORMS.A2 : ROLE_FORMS.ALL;
}
