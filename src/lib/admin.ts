/** Quản trị dữ liệu danh mục: sổ đăng ký bảng (whitelist) cho thêm/sửa/gỡ/nhập/xuất + lịch sử (audit_log). */
export type AdminTable = { table: string; pk: string; label: string; group: string; farmScoped: boolean; softDelete: "active" | "status" | null; writeRoles: string[]; hidden?: string[]; readonly?: string[]; note?: string; codePrefix?: string };
const MGR = ["owner", "director", "it_engineer"]; const OPS = [...MGR, "tech_head"]; const ACC = [...MGR, "accountant"];
export const ADMIN_TABLES: AdminTable[] = [
  { table: "farms", pk: "id", label: "Trại (hồ sơ, diện tích, hạ tầng)", group: "Công ty", farmScoped: false, softDelete: "status", writeRoles: ["owner", "it_engineer"], hidden: ["created_at"], readonly: ["id", "org_id"] },
  { table: "regions", pk: "id", label: "Vùng", group: "Công ty", farmScoped: false, softDelete: "active", writeRoles: ["owner", "it_engineer"] },
  { table: "facilities", pk: "id", label: "Nhà công năng / hạ tầng", group: "Trại", farmScoped: true, softDelete: "active", writeRoles: OPS, codePrefix: "FC", hidden: ["created_at", "created_by", "updated_at", "updated_by"] },
  { table: "locations", pk: "id", label: "Khu / vị trí / chuồng", group: "Trại", farmScoped: true, softDelete: "active", writeRoles: OPS, codePrefix: "LOC" },
  { table: "plots", pk: "id", label: "Ô/thửa ruộng", group: "Trại", farmScoped: true, softDelete: "active", writeRoles: OPS, codePrefix: "PLOT" },
  { table: "warehouses", pk: "id", label: "Kho", group: "Trại", farmScoped: true, softDelete: "active", writeRoles: MGR, codePrefix: "K" },
  { table: "cost_centers", pk: "id", label: "Trung tâm chi phí", group: "Trại", farmScoped: true, softDelete: "active", writeRoles: ACC, codePrefix: "CC" },
  { table: "devices", pk: "id", label: "Thiết bị / máy / cảm biến", group: "Trại", farmScoped: true, softDelete: "active", writeRoles: OPS, codePrefix: "DEV" },
  { table: "animal_groups", pk: "id", label: "Đàn / nhóm vật nuôi", group: "Trại", farmScoped: true, softDelete: "active", writeRoles: OPS, codePrefix: "GRP" },
  { table: "staff", pk: "id", label: "Nhân sự", group: "Nhân sự", farmScoped: true, softDelete: "active", writeRoles: MGR, hidden: ["pin_hash", "created_at"], readonly: ["pin_hash"], codePrefix: "NS" },
  { table: "products", pk: "sku", label: "Mặt hàng / SKU", group: "Danh mục", farmScoped: false, softDelete: "active", writeRoles: OPS },
  { table: "partners", pk: "id", label: "Đối tác (NCC / khách / hộ liên kết)", group: "Danh mục", farmScoped: false, softDelete: "active", writeRoles: OPS, codePrefix: "PT" },
  { table: "recipes", pk: "id", label: "Công thức TMR / thức ăn", group: "Danh mục", farmScoped: true, softDelete: "active", writeRoles: OPS, codePrefix: "RCP" },
  { table: "sops", pk: "code", label: "SOP", group: "Danh mục", farmScoped: false, softDelete: null, writeRoles: OPS },
  { table: "price_list", pk: "id", label: "Bảng giá", group: "Danh mục", farmScoped: true, softDelete: null, writeRoles: ACC },
  { table: "vaccine_schedules", pk: "id", label: "Lịch vaccine", group: "Thú y", farmScoped: false, softDelete: null, writeRoles: OPS },
  { table: "treatment_protocols", pk: "id", label: "Phác đồ điều trị", group: "Thú y", farmScoped: false, softDelete: null, writeRoles: OPS },
  { table: "settings", pk: "key", label: "Cài đặt", group: "Cấu hình", farmScoped: true, softDelete: null, writeRoles: MGR },
  { table: "norms", pk: "id", label: "Định mức", group: "Cấu hình", farmScoped: true, softDelete: null, writeRoles: MGR },
  { table: "kpi_defs", pk: "code", label: "Định nghĩa KPI", group: "Cấu hình", farmScoped: false, softDelete: null, writeRoles: MGR },
  { table: "rc_rules", pk: "code", label: "Luật đối soát", group: "Cấu hình", farmScoped: false, softDelete: "active", writeRoles: ["owner", "it_engineer"] },
  { table: "custom_fields", pk: "id", label: "Trường tùy biến", group: "Cấu hình", farmScoped: false, softDelete: "active", writeRoles: ["owner", "it_engineer"] },
  { table: "module_manifest", pk: "code", label: "Danh mục module", group: "Cấu hình", farmScoped: false, softDelete: null, writeRoles: ["it_engineer", "owner"] },
  { table: "rd_trials", pk: "id", label: "R&D · Thử nghiệm", group: "R&D", farmScoped: true, softDelete: "status", writeRoles: OPS, codePrefix: "RD" },
  { table: "rd_trial_arms", pk: "id", label: "R&D · Nhánh thử nghiệm", group: "R&D", farmScoped: false, softDelete: null, writeRoles: OPS, codePrefix: "ARM" },
  { table: "lab_samples", pk: "id", label: "R&D · Mẫu lab", group: "R&D", farmScoped: true, softDelete: "status", writeRoles: OPS, codePrefix: "LAB" },
  { table: "knowledge_articles", pk: "id", label: "R&D · Tri thức", group: "R&D", farmScoped: false, softDelete: "status", writeRoles: OPS, codePrefix: "KB" },
  { table: "market_profiles", pk: "id", label: "XNK · Thị trường", group: "Xuất nhập khẩu", farmScoped: false, softDelete: null, writeRoles: MGR },
  { table: "trade_partners", pk: "id", label: "XNK · Đối tác quốc tế", group: "Xuất nhập khẩu", farmScoped: false, softDelete: "active", writeRoles: MGR, codePrefix: "TP" },
  { table: "trade_contracts", pk: "id", label: "XNK · Hợp đồng ngoại", group: "Xuất nhập khẩu", farmScoped: true, softDelete: "status", writeRoles: MGR, codePrefix: "TC" },
  { table: "shipments", pk: "id", label: "XNK · Lô hàng", group: "Xuất nhập khẩu", farmScoped: true, softDelete: "status", writeRoles: MGR, codePrefix: "SHP" },
  { table: "trade_documents", pk: "id", label: "XNK · Chứng từ", group: "Xuất nhập khẩu", farmScoped: false, softDelete: "status", writeRoles: MGR },
  { table: "customs_declarations", pk: "id", label: "XNK · Tờ khai hải quan", group: "Xuất nhập khẩu", farmScoped: false, softDelete: "status", writeRoles: MGR, codePrefix: "CD" },
  { table: "import_permits", pk: "id", label: "XNK · Giấy phép nhập", group: "Xuất nhập khẩu", farmScoped: false, softDelete: "status", writeRoles: MGR, codePrefix: "IP" },
  { table: "fx_rates", pk: "day", label: "XNK · Tỷ giá", group: "Xuất nhập khẩu", farmScoped: false, softDelete: null, writeRoles: ACC },
  { table: "franchise_packages", pk: "id", label: "Nhân rộng · Gói mẫu trại", group: "Nhân rộng", farmScoped: false, softDelete: "status", writeRoles: ["owner", "director"], codePrefix: "FP" },
  { table: "franchise_sites", pk: "id", label: "Nhân rộng · Điểm triển khai", group: "Nhân rộng", farmScoped: false, softDelete: null, writeRoles: ["owner", "director"], codePrefix: "FS" },
  { table: "integrations", pk: "id", label: "Tích hợp (Zalo/SMS/Bank/GIS/MQTT)", group: "Tích hợp", farmScoped: true, softDelete: "active", writeRoles: ["it_engineer", "owner"], hidden: ["secret_ref"] },
  { table: "webhooks", pk: "id", label: "Webhook", group: "Tích hợp", farmScoped: true, softDelete: "active", writeRoles: ["it_engineer", "owner"], hidden: ["secret"] },
  { table: "crop_seasons", pk: "id", label: "Mùa vụ / hồ sơ canh tác", group: "Trại", farmScoped: true, softDelete: "status", writeRoles: OPS, codePrefix: "CS" },
  { table: "sales_channels", pk: "code", label: "Kênh bán", group: "Danh mục", farmScoped: false, softDelete: "active", writeRoles: MGR },
  { table: "crm_leads", pk: "id", label: "CRM · Lead/khách tiềm năng", group: "Kinh doanh", farmScoped: true, softDelete: null, writeRoles: [...OPS, "worker"], codePrefix: "LD" },
  { table: "promotions", pk: "id", label: "Khuyến mãi", group: "Kinh doanh", farmScoped: true, softDelete: "active", writeRoles: MGR, codePrefix: "KM" },
  { table: "hosp_room_types", pk: "id", label: "Du lịch · Hạng phòng", group: "Du lịch", farmScoped: true, softDelete: "active", writeRoles: MGR, codePrefix: "RT" },
  { table: "hosp_rooms", pk: "id", label: "Du lịch · Phòng", group: "Du lịch", farmScoped: true, softDelete: "active", writeRoles: MGR, codePrefix: "RM" },
  { table: "hosp_services", pk: "id", label: "Du lịch · Dịch vụ/tour/trải nghiệm", group: "Du lịch", farmScoped: true, softDelete: "active", writeRoles: MGR, codePrefix: "SV" },
  { table: "hosp_menus", pk: "id", label: "Du lịch · Thực đơn", group: "Du lịch", farmScoped: true, softDelete: "active", writeRoles: MGR, codePrefix: "MN" },
  { table: "hosp_bookings", pk: "id", label: "Du lịch · Booking lưu trú", group: "Du lịch", farmScoped: true, softDelete: "status", writeRoles: [...MGR, "worker", "team_lead"], codePrefix: "BK" },
  { table: "hosp_events", pk: "id", label: "Du lịch · Tiệc / sự kiện", group: "Du lịch", farmScoped: true, softDelete: "status", writeRoles: [...MGR, "team_lead"], codePrefix: "EV" },
  { table: "hosp_tours", pk: "id", label: "Du lịch · Lịch tour", group: "Du lịch", farmScoped: true, softDelete: "status", writeRoles: [...MGR, "team_lead"], codePrefix: "TR" },
  { table: "records_catalog", pk: "code", label: "Danh mục hồ sơ", group: "Cấu hình", farmScoped: false, softDelete: null, writeRoles: ["owner", "it_engineer", "auditor"] },
  { table: "departments", pk: "code", label: "Phòng ban", group: "Tổ chức", farmScoped: false, softDelete: "active", writeRoles: ["owner", "director", "it_engineer"] },
  { table: "processes", pk: "code", label: "Quy trình", group: "Tổ chức", farmScoped: false, softDelete: "active", writeRoles: ["owner", "director", "it_engineer", "tech_head"] },
  { table: "process_steps", pk: "id", label: "Bước quy trình", group: "Tổ chức", farmScoped: false, softDelete: null, writeRoles: ["owner", "director", "it_engineer", "tech_head"] },
  { table: "event_topics", pk: "topic", label: "Chủ đề event bus", group: "Tổ chức", farmScoped: false, softDelete: null, writeRoles: ["owner", "it_engineer"] },
  { table: "roles_catalog", pk: "code", label: "Vai trò (định nghĩa)", group: "Đối tượng", farmScoped: false, softDelete: null, writeRoles: ["owner", "it_engineer"] },
  { table: "positions_catalog", pk: "code", label: "Vị trí công việc", group: "Đối tượng", farmScoped: false, softDelete: null, writeRoles: ["owner", "director", "it_engineer"] },
  { table: "species", pk: "code", label: "Loài vật nuôi", group: "Đối tượng", farmScoped: false, softDelete: "active", writeRoles: OPS },
  { table: "animal_classes", pk: "code", label: "Lớp vật nuôi", group: "Đối tượng", farmScoped: false, softDelete: null, writeRoles: OPS },
  { table: "crops", pk: "code", label: "Cây trồng (định nghĩa)", group: "Đối tượng", farmScoped: false, softDelete: "active", writeRoles: OPS },
  { table: "product_kinds", pk: "code", label: "Nhóm sản phẩm/vật tư", group: "Đối tượng", farmScoped: false, softDelete: null, writeRoles: MGR },
  { table: "standards", pk: "code", label: "Tiêu chuẩn (VietGAP/ISO/Halal…)", group: "Chất lượng", farmScoped: false, softDelete: "active", writeRoles: ["owner", "it_engineer", "auditor", "tech_head"] },
  { table: "standard_requirements", pk: "id", label: "Yêu cầu tiêu chuẩn → bằng chứng", group: "Chất lượng", farmScoped: false, softDelete: null, writeRoles: ["owner", "it_engineer", "auditor", "tech_head"] },
  { table: "certifications", pk: "id", label: "Sổ chứng nhận", group: "Chất lượng", farmScoped: true, softDelete: "status", writeRoles: ["owner", "director", "it_engineer", "auditor", "tech_head"], codePrefix: "CERT" },
  { table: "compliance_checks", pk: "id", label: "Tự đánh giá / NC", group: "Chất lượng", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "it_engineer", "auditor", "tech_head"] },
  { table: "variable_catalog", pk: "code", label: "Biến đầu vào/đầu ra (chăn nuôi · trồng trọt)", group: "Đối tượng", farmScoped: false, softDelete: null, writeRoles: ["owner", "director", "it_engineer", "tech_head"] },
  { table: "api_keys", pk: "id", label: "Khóa API (IoT ingest / tích hợp)", group: "Tích hợp", farmScoped: true, softDelete: null, writeRoles: ["owner", "it_engineer"], hidden: ["key_hash"] },
  { table: "attendance", pk: "id", label: "Chấm công", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "accountant", "team_lead", "tech_head", "worker", "it_engineer"] },
  { table: "leave_requests", pk: "id", label: "Nghỉ phép", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "accountant", "team_lead", "tech_head", "worker", "it_engineer"] },
  { table: "journal_entries", pk: "id", label: "Kế toán · bút toán (sổ nhật ký chung)", group: "Kế toán", farmScoped: true, softDelete: null, writeRoles: ["owner", "accountant"] },
  { table: "gl_accounts", pk: "code", label: "Kế toán · hệ thống tài khoản", group: "Kế toán", farmScoped: false, softDelete: "active", writeRoles: ["owner", "accountant"] },
  { table: "notification_deliveries", pk: "id", label: "Nhật ký gửi Zalo/SMS/Email", group: "Tích hợp", farmScoped: false, softDelete: null, writeRoles: ["owner", "it_engineer"] },
  { table: "webhook_deliveries", pk: "id", label: "Nhật ký webhook", group: "Tích hợp", farmScoped: false, softDelete: null, writeRoles: ["owner", "it_engineer"] },
  { table: "login_attempts", pk: "ts", label: "Nhật ký đăng nhập", group: "Tích hợp", farmScoped: false, softDelete: null, writeRoles: ["owner", "it_engineer"] },
  { table: "documents", pk: "id", label: "Tài liệu / hồ sơ đính kèm", group: "Tài liệu", farmScoped: true, softDelete: "status", writeRoles: OPS },
];
export const findAdmin = (t: string) => ADMIN_TABLES.find((x) => x.table === t);
/** Bảng sự kiện nhập được qua CSV (đi qua /api/events để giữ luật append-only/idempotent) */
export const IMPORT_EVENT_TABLES = ["inventory_moves", "crop_logs", "feed_logs", "animal_events", "batch_logs", "sales", "weigh_tickets", "gate_logs", "checklist_runs", "crop_inputs", "harvests", "pos_receipts", "hosp_folio"];
/** CSV đơn giản (RFC4180 cơ bản: dấu ngoặc kép, dấu phẩy/chấm phẩy) */
export function parseCsv(text: string): Record<string, string>[] {
  const lines = text.replace(/^﻿/, "").split(/\r?\n/).filter((l) => l.trim().length);
  if (!lines.length) return [];
  const sep = (lines[0].match(/;/g)?.length ?? 0) > (lines[0].match(/,/g)?.length ?? 0) ? ";" : ",";
  const split = (l: string) => { const out: string[] = []; let cur = "", q = false; for (let i = 0; i < l.length; i++) { const ch = l[i]; if (ch === '"') { if (q && l[i + 1] === '"') { cur += '"'; i++; } else q = !q; } else if (ch === sep && !q) { out.push(cur); cur = ""; } else cur += ch; } out.push(cur); return out.map((s) => s.trim()); };
  const head = split(lines[0]).map((h) => h.toLowerCase());
  return lines.slice(1).map((l) => { const v = split(l); const o: Record<string, string> = {}; head.forEach((h, i) => { o[h] = v[i] ?? ""; }); return o; });
}
export function toCsv(rows: Record<string, unknown>[], cols?: string[]): string {
  if (!rows.length && !cols) return ""; const c = cols ?? Object.keys(rows[0]);
  const esc = (v: unknown) => { const s = v == null ? "" : typeof v === "object" ? JSON.stringify(v) : String(v); return /[",\n;]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; };
  return "﻿" + [c.join(","), ...rows.map((r) => c.map((k) => esc(r[k])).join(","))].join("\n");
}
