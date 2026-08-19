"use client";
import type { ThreeTapSpec, Option } from "@/components/ThreeTap";

export type Ref = {
  animals: Record<string, unknown>[]; groups: Record<string, unknown>[]; warehouses: Record<string, unknown>[]; products: Record<string, unknown>[]; bins?: Record<string, unknown>[];
  plots: Record<string, unknown>[]; recipes: Record<string, unknown>[]; locations: Record<string, unknown>[]; sops: Record<string, unknown>[]; devices: Record<string, unknown>[]; partners: Record<string, unknown>[];
  staff?: Record<string, unknown>[];   // để hành chính chấm công cho người khác
};
const s = (v: unknown) => (v == null ? "" : String(v));
const animalOpts = (r: Ref, filter?: (a: Record<string, unknown>) => boolean): Option[] =>
  r.animals.filter((a) => !["CHET", "XUAT"].includes(s(a.status)) && (!filter || filter(a))).map((a) => ({ id: s(a.id), label: `${s(a.visual_tag) || s(a.id)} · ${s(a.id).slice(-5)}`, sub: `${s(a.status)} · ${s(a.location_name) || s(a.group_name)}`, meta: { rfid: s(a.rfid), visual_tag: s(a.visual_tag) } }));
/** Đàn để CHỌN khi ghi việc: chỉ đàn đang nuôi. Đàn đã đóng sổ (status DONG, 0 con) vẫn nằm
 *  trong danh mục để tra cứu lịch sử, nhưng KHÔNG được mời chọn — công nhân đã gặp cảnh
 *  form TMR bày ra "Gà đẻ lứa 00 (đã loại) · 0 con" bên cạnh đàn thật. */
/** Gom SOP thành QUY TRÌNH (L2) kèm danh sách BƯỚC (L3). Bảng `sops` không có dòng riêng cho
 *  L2 — L2 chỉ tồn tại dưới dạng giá trị `l2_code` trên các dòng L3, nên phải gom lại ở đây. */
const sopL2Opts = (r: Ref): Option[] => {
  const nhom = new Map<string, { ten: string; buoc: { n: number; a: string; code: string }[] }>();
  for (const x of r.sops) {
    const l2 = s(x.l2_code); const n = Number(x.l3_no);
    if (!l2 || !Number.isFinite(n) || x.l3_no == null) continue;
    if (!nhom.has(l2)) nhom.set(l2, { ten: s(x.l2_group) || l2, buoc: [] });
    nhom.get(l2)!.buoc.push({ n, a: s(x.title), code: s(x.code) });
  }
  return [...nhom.entries()]
    .map(([code, v]) => ({ id: code, label: v.ten === code ? code : `${v.ten}`, sub: `${code} · ${v.buoc.length} bước`, meta: { steps: v.buoc.sort((a, b) => a.n - b.n) } }))
    .sort((a, b) => a.id.localeCompare(b.id));
};
const groupOpts = (r: Ref, kinds?: string[]): Option[] => r.groups
  .filter((g) => (!kinds || kinds.includes(s(g.kind))) && !["DONG", "CLOSED", "HUY"].includes(s(g.status).toUpperCase()))
  .map((g) => ({ id: s(g.id), label: s(g.name), sub: `${s(g.head_count)} con` }));
const binOpts = (r: Ref): Option[] => (r.bins ?? []).map((b) => ({ id: s(b.id), label: `${s(b.warehouse_code)} · ${s(b.code)}`, sub: s(b.zone) }));
const whOpts = (r: Ref, codes?: string[]): Option[] => r.warehouses.filter((w) => !codes || codes.includes(s(w.code))).map((w) => ({ id: s(w.id), label: `${s(w.code)} ${s(w.name)}`.slice(0, 40) }));
const prodOpts = (r: Ref, kinds?: string[]): Option[] => r.products.filter((p) => !kinds || kinds.includes(s(p.kind))).map((p) => ({ id: s(p.sku), label: s(p.name), sub: `${s(p.sku)} · ${s(p.unit)}` }));
const locOpts = (r: Ref, kinds?: string[]): Option[] => r.locations.filter((l) => !kinds || kinds.includes(s(l.kind))).map((l) => ({ id: s(l.id), label: s(l.name), sub: s(l.code) }));

/** Danh sách form theo vai/vị trí — mã form → spec */
/** Bản đồ hồ sơ chuẩn theo bảng ghi (mirror records_catalog) — để công nhân biết đang ghi vào sổ gì, phục vụ chuẩn nào */
export const RECORD_MAP: Record<string, { code: string; name: string; std: string }> = {
  feed_logs: { code: "HS-THUC-AN", name: "Hồ sơ thức ăn & công thức", std: "NĐ 13/2020 (TACN) · ATTP" },
  animal_events: { code: "HS-THU-Y", name: "Sổ dịch bệnh – thuốc – vaccine", std: "Luật Thú y · TT 12/2020 (ngưng thuốc)" },
  crop_logs: { code: "HS-CANH-TAC", name: "Nhật ký sản xuất trồng trọt", std: "VietGAP (TCVN 11892-1) · hữu cơ" },
  irrigation_logs: { code: "HS-DAT-NUOC", name: "Hồ sơ đất – nước – môi trường", std: "VietGAP · QCVN 08/09" },
  pest_scouting: { code: "HS-CANH-TAC", name: "Nhật ký BVTV – IPM – PHI", std: "VietGAP (cách ly PHI)" },
  soil_tests: { code: "HS-DAT-NUOC", name: "Hồ sơ đất – nước", std: "VietGAP · hữu cơ" },
  harvests: { code: "HS-THU-HOACH", name: "Hồ sơ thu hoạch & sơ chế", std: "VietGAP thu hoạch · ATTP" },
  weigh_tickets: { code: "HS-THU-HOACH", name: "Phiếu cân thu hoạch", std: "VietGAP · ATTP" },
  batch_logs: { code: "HS-ATTP", name: "Hồ sơ ATTP / HACCP / mẻ", std: "HACCP · ISO 22000 · TT 38/2018" },
  inventory_moves: { code: "HS-KHO", name: "Thẻ kho – nhập xuất tồn – FEFO", std: "TT 200/133 · ATTP lô/hạn" },
  stocktakes: { code: "HS-KHO", name: "Kiểm kê kho", std: "TT 200/133" },
  sales: { code: "HS-BAN-HANG", name: "Hồ sơ bán hàng – công nợ", std: "Luật TM · TT 78/2021 HĐĐT" },
  gate_logs: { code: "HS-KHO", name: "Nhật ký cổng – cân", std: "An ninh · truy xuất" },
  checklist_runs: { code: "HS-ATTP", name: "Checklist ca theo SOP", std: "ATTP · HACCP" },
  incidents: { code: "HS-ATTP", name: "Sự cố / near-miss", std: "ATTP · môi trường" },
  paper_scans: { code: "HS-PHAP-LY", name: "Số hóa phiếu giấy BM01–BM10", std: "Lưu trữ · đối chiếu seri" },
};
export function buildForms(r: Ref, farmId: string): Record<string, ThreeTapSpec> {
  const nowIso = () => new Date().toISOString();
  const _defs: Record<string, ThreeTapSpec> = {
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
    // A14 Bếp · LƯU MẪU THỨC ĂN — nghĩa vụ BẮT BUỘC theo ATTP. Trước đây bếp trưởng không có
    // chỗ nào để ghi, tức là trại không có bằng chứng lưu mẫu khi đoàn kiểm tra hỏi.
    food_sample: {
      table: "food_samples", title: "Lưu mẫu thức ăn", targetLabel: "Bữa / suất ăn", targetKey: "meal", allowScanInput: false,
      targets: [{ id: "SANG", label: "Sáng" }, { id: "TRUA", label: "Trưa" }, { id: "CHIEU", label: "Chiều" }, { id: "TIEC", label: "Tiệc / đoàn khách" }],
      fields: [
        { key: "dish_name", label: "Tên món", type: "text", required: true, placeholder: "Gà kho gừng…" },
        { key: "sample_gram", label: "Khối lượng mẫu", type: "number", unit: "g", min: 0, step: 10, default: 100, required: true },
        { key: "stored_at", label: "Lưu ở đâu", type: "text", placeholder: "Tủ mẫu bếp" },
        { key: "temp_c", label: "Nhiệt độ tủ mẫu", type: "number", unit: "°C", min: -30, max: 30, step: 1 },
        { key: "note", label: "Ghi chú", type: "text" },
        { key: "photo", label: "Ảnh mẫu đã dán nhãn", type: "photo" },
      ],
      build: (t, v) => ({ ...v, meal: t.id, keep_until: new Date(Date.now() + 24 * 3600 * 1000).toISOString() }),
    },
    // A16 Tài xế · NHIỆT ĐỘ CHUỖI LẠNH trên đường. Thiếu mắt xích này thì hàng tới nơi
    // không chứng minh được đã giữ đúng nhiệt suốt hành trình.
    cold_chain: {
      // Nhãn dùng luôn trong câu trạng thái rỗng ("gõ <nhãn> vào ô trên") nên phải là một
      // danh từ đọc xuôi, không phải câu lệnh kiểu "Chọn xe".
      table: "cold_chain_logs", title: "Nhiệt độ xe lạnh", targetLabel: "Biển số xe", targetKey: "vehicle_id", allowScanInput: true,
      // Lọc CHÍNH XÁC xe vận chuyển lạnh. Dùng /XE/ chung là sai: nó bắt luôn XE_TRON
      // (xe trộn TMR) — đo được lúc thử, tài xế được mời ghi nhiệt độ cho xe trộn thức ăn.
      // Danh sách rỗng cũng không sao: form cho gõ tay biển số ở Bước 1.
      targets: r.devices.filter((d) => /^(XE_LANH|XE_TAI|XE_DONG_LANH|REEFER|TRUCK)/i.test(s(d.kind))).map((d) => ({ id: s(d.id), label: s(d.name), sub: s(d.kind) })),
      fields: [
        { key: "leg", label: "Chặng", type: "choice", required: true, options: [{ id: "XEP_HANG", label: "Lúc xếp hàng" }, { id: "DOC_DUONG", label: "Dọc đường" }, { id: "GIAO_HANG", label: "Lúc giao hàng" }] },
        { key: "temp_c", label: "Nhiệt độ đo được", type: "number", unit: "°C", min: -30, max: 30, step: 1, required: true },
        { key: "temp_max_c", label: "Ngưỡng cho phép của lô", type: "number", unit: "°C", min: -30, max: 30, step: 1 },
        { key: "door_open", label: "Có mở cửa thùng không", type: "bool" },
        { key: "location_note", label: "Đang ở đâu", type: "text", placeholder: "Quốc lộ 20, km 45…" },
        { key: "photo", label: "Ảnh đồng hồ nhiệt", type: "photo" },
      ],
    },
    // A11 KTV thiết bị · PHIẾU HIỆU CHUẨN. Bảng `calibrations` có sẵn từ lâu, chỉ thiếu form.
    calibration: {
      table: "calibrations", title: "Hiệu chuẩn thiết bị", targetLabel: "Chọn thiết bị cần hiệu chuẩn", targetKey: "target_device_id", allowScanInput: true,
      targets: r.devices.map((d) => ({ id: s(d.id), label: s(d.name), sub: s(d.kind) })),
      fields: [
        { key: "method", label: "Cách hiệu chuẩn", type: "choice", required: true, options: [{ id: "QUA_CAN_CHUAN", label: "Quả cân chuẩn" }, { id: "DUNG_DICH_CHUAN", label: "Dung dịch chuẩn" }, { id: "MAY_CHUAN", label: "Máy chuẩn" }, { id: "DON_VI_NGOAI", label: "Đơn vị ngoài" }] },
        { key: "before_val", label: "Số đo TRƯỚC hiệu chuẩn", type: "number", step: 0.1 },
        { key: "after_val", label: "Số đo SAU hiệu chuẩn", type: "number", step: 0.1 },
        { key: "result", label: "Kết quả", type: "choice", required: true, options: [{ id: "DAT", label: "Đạt" }, { id: "DA_HIEU_CHINH", label: "Đã hiệu chỉnh" }, { id: "KHONG_DAT", label: "Không đạt — ngừng dùng" }] },
        { key: "next_due", label: "Hạn hiệu chuẩn kế tiếp", type: "date" },
      ],
    },
    // A18 Hành chính · CHẤM CÔNG. `attendance` là bảng TỔNG HỢP nên ghi vào sổ riêng.
    timekeep: {
      table: "attendance_logs", title: "Chấm công", targetLabel: "Chọn người", targetKey: "staff_id", allowScanInput: true,
      targets: (r.staff ?? []).filter((x: Record<string, unknown>) => x.active !== false).map((x: Record<string, unknown>) => ({ id: s(x.id), label: s(x.full_name), sub: s(x.position) })),
      fields: [
        { key: "kind", label: "Loại", type: "choice", required: true, options: [{ id: "VAO_CA", label: "Vào ca" }, { id: "RA_CA", label: "Ra ca" }, { id: "DI_MUON", label: "Đi muộn" }, { id: "TANG_CA", label: "Tăng ca" }, { id: "NGHI_PHEP", label: "Nghỉ phép" }, { id: "NGHI_OM", label: "Nghỉ ốm" }] },
        { key: "shift", label: "Ca", type: "choice", options: [{ id: "SANG", label: "Sáng" }, { id: "CHIEU", label: "Chiều" }, { id: "DEM", label: "Đêm" }] },
        { key: "minutes", label: "Số phút (tăng ca / đi muộn)", type: "number", unit: "phút", min: 0, step: 15 },
        { key: "reason", label: "Lý do", type: "text" },
      ],
    },
    // A11 KTV thiết bị · BẢO TRÌ / SỬA CHỮA.
    maintenance: {
      table: "maintenance_logs", title: "Bảo trì / sửa chữa", targetLabel: "Thiết bị", targetKey: "target_device_id", allowScanInput: true,
      targets: r.devices.map((d) => ({ id: s(d.id), label: s(d.name), sub: s(d.kind) })),
      fields: [
        { key: "kind", label: "Loại việc", type: "choice", required: true, options: [{ id: "DINH_KY", label: "Bảo trì định kỳ" }, { id: "SUA_CHUA", label: "Sửa chữa hỏng" }, { id: "THAY_THE", label: "Thay phụ tùng" }, { id: "KIEM_TRA", label: "Kiểm tra" }] },
        { key: "symptom", label: "Hiện tượng hỏng", type: "text", placeholder: "Kêu to, rung, không lên nguồn…" },
        { key: "action", label: "Đã làm gì", type: "text", required: true },
        { key: "parts", label: "Phụ tùng đã thay", type: "text" },
        { key: "downtime_min", label: "Máy ngừng bao lâu", type: "number", unit: "phút", min: 0, step: 15 },
        { key: "result", label: "Kết quả", type: "choice", required: true, options: [{ id: "XONG", label: "Xong, chạy lại được" }, { id: "CHO_PHU_TUNG", label: "Chờ phụ tùng" }, { id: "NGUNG_DUNG", label: "Ngừng dùng — chờ xử lý" }] },
        { key: "next_due", label: "Hạn bảo trì kế tiếp", type: "date" },
        { key: "photo", label: "Ảnh", type: "photo" },
      ],
    },
    // A12 Lễ tân · ĐẶT PHÒNG / TOUR — ghi vào sổ khách `hosp_folio` đã có sẵn.
    booking: {
      table: "hosp_folio", title: "Đặt phòng / tour", targetLabel: "Khách", targetKey: "guest_partner_id", allowScanInput: true,
      targets: r.partners.map((p) => ({ id: s(p.id), label: s(p.name), sub: s(p.kind) })),
      fields: [
        { key: "kind", label: "Dịch vụ", type: "choice", required: true, options: [{ id: "PHONG", label: "Phòng nghỉ" }, { id: "TOUR", label: "Tour trải nghiệm" }, { id: "AN_UONG", label: "Ăn uống" }, { id: "TIEC", label: "Tiệc / đoàn" }, { id: "DICH_VU", label: "Dịch vụ khác" }] },
        { key: "description", label: "Nội dung", type: "text", required: true, placeholder: "2 phòng đôi, 2 đêm…" },
        { key: "qty", label: "Số lượng", type: "number", min: 0, step: 1, default: 1 },
        { key: "unit_price", label: "Đơn giá", type: "number", unit: "đ", min: 0, step: 50000 },
        { key: "amount", label: "Thành tiền", type: "number", unit: "đ", min: 0, step: 50000, required: true },
        { key: "payment", label: "Thanh toán", type: "choice", options: [{ id: "TM", label: "Tiền mặt" }, { id: "CK", label: "Chuyển khoản" }, { id: "NO", label: "Ghi nợ" }] },
      ],
    },
    // A6 CN ủ chua · Ủ CHUA — dùng `batch_logs` đã có sẵn, thêm dây chuyền U_CHUA.
    silage: {
      table: "batch_logs", title: "Ủ chua (hố / bao)", targetLabel: "Chọn hố / kho ủ", targetKey: "location_id", allowScanInput: true,
      targets: locOpts(r),
      fields: [
        { key: "line", label: "Việc", type: "choice", required: true, options: [{ id: "U_CHUA_NAP", label: "Nạp hố / vào bao" }, { id: "U_CHUA_NEN", label: "Nén – phủ bạt" }, { id: "U_CHUA_MO", label: "Mở hố lấy dùng" }] },
        { key: "kg", label: "Khối lượng", type: "number", unit: "kg", min: 0, step: 100, required: true },
        { key: "moisture_pct", label: "Độ ẩm nguyên liệu", type: "number", unit: "%", min: 0, max: 100, step: 1 },
        { key: "ph", label: "pH (đo khi mở hố)", type: "number", min: 3, max: 9, step: 0.1 },
        { key: "temp_c", label: "Nhiệt độ khối ủ", type: "number", unit: "°C", min: 0, max: 80, step: 1 },
        { key: "note", label: "Ghi chú (mùi, nấm mốc…)", type: "text" },
        { key: "photo", label: "Ảnh", type: "photo" },
      ],
      build: (t, v) => ({ ...v, location_id: t.id, batch_code: `UC-${new Date().toISOString().slice(0, 10)}`, qc: v.ph != null ? { ph: v.ph } : {} }),
    },
    // Chung · sự cố · checklist
    incident: {
      table: "incidents", title: "Báo sự cố / near-miss", targetLabel: "Nơi xảy ra", targetKey: "location_id", targets: locOpts(r), allowScanInput: true,
      fields: [{ key: "kind", label: "Loại", type: "choice", required: true, options: [{ id: "VAN_HANH", label: "Vận hành" }, { id: "ATTP", label: "ATTP" }, { id: "ATLD", label: "ATLĐ" }, { id: "AN_NINH", label: "An ninh" }, { id: "MOI_TRUONG", label: "Môi trường" }, { id: "THIET_BI", label: "Thiết bị" }, { id: "TAI_LIEU", label: "Tài liệu" }] }, { key: "severity", label: "Mức", type: "choice", required: true, options: [{ id: "NEAR_MISS", label: "Suýt xảy ra" }, { id: "THAP", label: "Thấp" }, { id: "TRUNG", label: "Trung" }, { id: "CAO", label: "Cao" }, { id: "NGHIEM_TRONG", label: "Nghiêm trọng" }] }, { key: "description", label: "Mô tả", type: "text", required: true }, { key: "photo", label: "Ảnh", type: "photo" }],
    },
    checklist: {
      // Quy trình nằm ở SOP cấp L2 (81 mã), các BƯỚC là 422 dòng SOP cấp L3 trỏ về qua l2_code.
      // Trước đây form lấy thẳng r.sops lọc status='BAN_HANH' — mà chỉ 3/425 SOP đã ban hành,
      // nên công nhân chỉ thấy 2 lựa chọn và không có bước nào để tích.
      table: "checklist_runs", title: "Checklist ca theo SOP", targetLabel: "Quy trình cần chạy", targetKey: "sop_code",
      targets: sopL2Opts(r),
      fields: [
        { key: "shift", label: "Ca", type: "choice", options: [{ id: "SANG", label: "Sáng" }, { id: "CHIEU", label: "Chiều" }, { id: "DEM", label: "Đêm" }], required: true },
        { key: "results", label: "Chấm từng bước", type: "steps", required: true },
        { key: "note", label: "Bước nào không đạt: ghi rõ lý do", type: "text" },
      ],
      build: (t, v) => {
        const ds = (v.results as { n: number; a: string; code?: string; ok?: boolean | null }[] | undefined) ?? [];
        return { ...v, results: ds, all_green: ds.length > 0 && ds.every((x) => x.ok === true), sop_version: 1 };
      },
    },
    paper_submit: {
      table: "paper_scans", title: "📷 Nộp phiếu giấy", targetLabel: "Chọn mẫu phiếu", targetKey: "form_code",
      targets: ["BM01 FEED_LOG", "BM02 EVENT_ANIMAL", "BM03 CROP_LOG", "BM04 BATCH_LOG", "BM05 INVENTORY_MOVE", "BM06 SALE", "BM07 CHECKLIST", "BM08 GATE_LOG", "BM09 KIEM_KE", "BM10 SU_CO"].map((x) => ({ id: x.slice(0, 4), label: x })),
      fields: [{ key: "serial_no", label: "Số seri trên tờ (6 số)", type: "number", min: 1, max: 999999, step: 1, required: true }, { key: "photo", label: "Ảnh tờ phiếu (đủ 4 góc)", type: "photo", required: true }, { key: "anomaly", label: "Bất thường (tờ hỏng, thiếu chữ ký)", type: "text" }],
      build: (t, v) => { const { serial_no, photo_urls, ...rest } = v as Record<string, unknown> & { photo_urls?: string[] }; return { ...rest, serial: `${farmId}-${t.id}-${String(serial_no).padStart(6, "0")}`, photo_url: photo_urls?.[0] ?? null }; },
    },
  };
  for (const k in _defs) _defs[k].record = RECORD_MAP[_defs[k].table];
  return _defs;
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
/** Nhận diện vị trí theo TỪ KHOÁ (cho các chức danh KHÔNG có mã A1–A14).
 *  Trước đây chỉ khớp mã Axx nên 25/35 công nhân (bếp, lễ tân, tài xế, CN trùn, CN dê…)
 *  đều rơi vào mặc định "A2 Sinh sản" → thấy form ghi sinh sản bò, không phải việc của mình. */
/** Thứ tự QUAN TRỌNG: luật cụ thể đặt trước luật chung.
 *  Cẩn thận với từ ngắn: "ca" trong "ca 2"/"ca đêm" từng khớp nhầm luật cá/lươn → dùng \b và có dấu. */
const KEYWORD_FORMS: [RegExp, string[]][] = [
  [/b(ả|a)o v(ệ|e)|c(ổ|o)ng|h(à|a)nh ch(í|i)nh|ch(ấ|a)m c(ô|o)ng|y t(ế|e) tr(ạ|a)i/i, ROLE_FORMS.A11],
  [/thi(ế|e)t b(ị|i)|hi(ệ|e)u chu(ẩ|a)n|IoT/i, ROLE_FORMS.A8],
  [/tr(ù|u)n|compost|BSF|b(ế|e)p r(á|a)c|sinh h(ọ|o)c tu(ầ|a)n ho(à|a)n|khu D\b/i, ROLE_FORMS.A6],
  [/\bRAS\b|l(ư|u)(ơ|o)n|th(ủ|u)y s(ả|a)n|\bcá\b|b(ể|e) c(á|a)/i, ROLE_FORMS.A4],
  [/\bg(à|a)\b|g(à|a) (đ|d)(ẻ|e)|g(à|a) th(ị|i)t|tr(ứ|u)ng|gia c(ầ|a)m/i, ROLE_FORMS.A3],
  [/(é|e)p vi(ê|e)n|tr(ộ|o)n TMR|\bD5\b|s(ơ|o) ch(ế|e)|(đ|d)(ó|o)ng g(ó|o)i|\btem\b|h(ú|u)t ch(â|a)n kh(ô|o)ng|ch(ế|e) bi(ế|e)n|s(ấ|a)y/i, ROLE_FORMS.A7],
  [/b(ò|o)\b|b(ê|e)\b|d(ê|e)\b|sinh s(ả|a)n|cai s(ữ|u)a|v(ỗ|o) b(é|e)o|chu(ồ|o)ng/i, ROLE_FORMS.A2],
  [/c(ỏ|o)\b|b(ắ|a)p|l(ú|u)a|rau|n(ấ|a)m|t(ư|u)(ớ|o)i|(đ|d)(ồ|o)ng c(ỏ|o)|sinh kh(ố|o)i|nh(à|a) l(ư|u)(ớ|o)i|li(ê|e)n k(ế|e)t h(ộ|o)|(ủ|u) chua/i, ROLE_FORMS.A5],
  [/kho\b|th(ủ|u) kho|giao h(à|a)ng|t(à|a)i x(ế|e)|v(ậ|a)n t(ả|a)i|mua h(à|a)ng|cung (ứ|u)ng/i, ROLE_FORMS.A8],
  [/kinh doanh|NVKD|b(á|a)n h(à|a)ng|CSKH|hotline|nh(ậ|a)n nu(ô|o)i|l(ễ|e) t(â|a)n|tour|(đ|d)(ặ|a)t ph(ò|o)ng|b(ế|e)p|farm-to-table|bu(ồ|o)ng ph(ò|o)ng/i, ROLE_FORMS.A9],
];
/** Dự phòng theo PHÒNG BAN khi không khớp từ khoá nào. */
const DEPT_FORMS: Record<string, string[]> = {
  KTCN: ROLE_FORMS.A2, SH: ROLE_FORMS.A6, TT: ROLE_FORMS.A5, D5: ROLE_FORMS.A7,
  CCU: ROLE_FORMS.A8, KDM: ROLE_FORMS.A9, DL: ROLE_FORMS.A9, HCNS: ROLE_FORMS.A11, CNTB: ROLE_FORMS.A5,
};

export function formsForPosition(position: string | null | undefined, role: string, dept?: string | null): string[] {
  const m = position?.match(/A(\d{1,2})/); const key = m ? `A${m[1]}` : null;
  if (key && ROLE_FORMS[key]) return ROLE_FORMS[key];
  if (position) { for (const [re, forms] of KEYWORD_FORMS) if (re.test(position)) return forms; }
  if (dept && DEPT_FORMS[dept]) return DEPT_FORMS[dept];
  return role === "worker" ? ROLE_FORMS.ALL : ROLE_FORMS.ALL;
}
