import io
R="F:/ITRAN FARM/itran-os/"
def rw(p, fn): s=io.open(R+p,encoding="utf-8").read(); n=fn(s); assert n!=s, p; io.open(R+p,"w",encoding="utf-8",newline="\n").write(n); print("ok",p)

# ===== 1) forms.ts: ThreeTapSpec.record + RECORD_MAP + attach =====
def forms(s):
    s=s.replace("export function buildForms(r: Ref, farmId: string): Record<string, ThreeTapSpec> {",
"""/** Bản đồ hồ sơ chuẩn theo bảng ghi (mirror records_catalog) — để công nhân biết đang ghi vào sổ gì, phục vụ chuẩn nào */
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
export function buildForms(r: Ref, farmId: string): Record<string, ThreeTapSpec> {""",1)
    # attach record at the end of buildForms before `return defs`/`return f`
    # find the return of the forms object. The function ends with `};\n  };\n  return ...` — safer: wrap after object literal `return forms;` ? Let's find `return f;` or similar.
    return s
rw("src/lib/forms.ts", forms)

# add record field to ThreeTapSpec type + attach loop
def forms2(s):
    s=s.replace("export type ThreeTapSpec = {\n  table: string;\n  title: string;",
                "export type ThreeTapSpec = {\n  table: string;\n  title: string;\n  record?: { code: string; name: string; std: string };",1)
    return s
rw("src/lib/forms.ts", forms2)

# ===== 2) ThreeTap.tsx badge under title =====
rw("src/components/ThreeTap.tsx", lambda s: s.replace(
  '        <h2 className="text-xl font-bold">{spec.title}</h2>',
  '        <div><h2 className="text-xl font-bold">{spec.title}</h2>{spec.record && <div className="text-xs text-emerald-700 mt-0.5" title={spec.record.std}>📋 Ghi vào hồ sơ: <b>{spec.record.name}</b> ({spec.record.code}) · {spec.record.std}</div>}</div>',1))

# ===== 3) queries.ts =====
rw("src/lib/queries.ts", lambda s: s.replace("  gs_today:", '''  record_for_table: { sql: "select * from v_record_for_table" },
  labor_budget: { sql: "select * from v_labor_budget_vs_actual where farm_id=$1 order by month", ttl: 120 },
  order_margin: { sql: "select * from v_order_margin where farm_id=$1 and revenue>0 order by ts desc limit 300", ttl: 60 },
  sale_margin: { sql: "select * from v_sale_margin where farm_id=$1 order by ts desc limit 300", ttl: 60 },
  qc_holds: { sql: "select * from qc_holds where farm_id=$1 order by status='GIU' desc, held_at desc limit 200" },
  supplier_returns: { sql: "select r.*, p.name as supplier_name from supplier_returns r left join partners p on p.id=r.supplier_id where r.farm_id=$1 order by r.status='CHO' desc, r.created_at desc limit 200" },
  bank_recon: { sql: "select * from v_bank_reconciliation where farm_id=$1 order by txn_date desc limit 400" },
  sop_signoff: { sql: "select * from v_sop_signoff where dept is not null order by (need-signed) desc, dept limit 300" },
  my_sop_todo: { sql: "select s.code, s.title, s.dept, s.version, s.video_url from sops s where s.status='BAN_HANH' and s.l3_no is null and (s.dept = (select dept from staff where id=app_staff()) or s.dept is null) and not exists (select 1 from sop_acknowledgments a where a.sop_code=s.code and a.sop_version=s.version and a.staff_id=app_staff() and a.kind='DOC_HIEU') order by s.code limit 100" },
  lots_sellable: { sql: "select id, sku, lot_no, status, expiry_date from lots where farm_id=$1 and status in ('KHA_DUNG','GIU_QC','CO_LAP') order by status='GIU_QC' desc, expiry_date limit 200" },
  gs_today:''',1))

# ===== 4) actions/route.ts =====
rw("src/app/api/actions/route.ts", lambda s: s.replace('        case "gs_ack":', '''        case "qc_hold": { if (!["owner","director","tech_head","team_lead","auditor","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select qc_hold($1,$2,$3,$4,$5,$6) as id", [s.farmId, b.ref_type ?? "LOT", b.ref, b.reason, b.severity ?? "TRUNG", s.staffId]); return { ok: true, id: r.rows[0].id }; }
        case "qc_release": { if (!["owner","director","tech_head","auditor"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select qc_release($1::uuid,$2,$3,$4)", [b.id, s.staffId, b.disposition ?? null, b.status ?? "GIAI_TOA"]); return { ok: true }; }
        case "supplier_return": { const id = `${s.farmId}-SRET-${Date.now().toString(36)}`; await c.query("insert into supplier_returns(id,farm_id,po_id,supplier_id,sku,lot_id,qty,unit_cost,amount,reason,disposition,warehouse_id,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)", [id, s.farmId, b.po_id ?? null, b.supplier_id ?? null, b.sku ?? null, b.lot_id ?? null, Number(b.qty), b.unit_cost == null ? null : Number(b.unit_cost), b.amount == null ? null : Number(b.amount), b.reason ?? null, b.disposition ?? "TRA_LAI", b.warehouse_id ?? null, s.staffId]); return { ok: true, id }; }
        case "approve_supplier_return": { if (!["owner","director","accountant","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select approve_supplier_return($1,$2)", [b.id, s.staffId]); return { ok: true }; }
        case "import_bank_lines": { if (!["owner","director","accountant","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const lines = (b.lines ?? []) as Record<string, unknown>[]; const batch = `bank-${Date.now().toString(36)}`; let n = 0; for (const ln of lines) { await c.query("select import_bank_line($1,$2,$3,$4::date,$5,$6,$7,$8,$9,$10)", [s.farmId, ln.bank ?? "NH", ln.account ?? "", ln.txn_date, Number(ln.amount), ln.direction ?? (Number(ln.amount) >= 0 ? "IN" : "OUT"), ln.ref ?? null, ln.memo ?? null, batch, s.staffId]); n++; } const m = await c.query("select auto_match_bank($1) as n", [s.farmId]); return { ok: true, imported: n, matched: m.rows[0].n }; }
        case "bank_reconcile": { if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update bank_statement_lines set reconciled=$3, reconciled_by=$4 where id=$1 and farm_id=$2", [b.id, s.farmId, b.reconciled !== false, s.staffId]); return { ok: true }; }
        case "bank_match": { if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); if (b.sale_id) await c.query("update bank_statement_lines set matched_sale_id=$3::uuid, matched_kind='SALE' where id=$1 and farm_id=$2", [b.id, s.farmId, b.sale_id]); else if (b.expense_id) await c.query("update bank_statement_lines set matched_expense_id=$3, matched_kind='EXPENSE' where id=$1 and farm_id=$2", [b.id, s.farmId, b.expense_id]); return { ok: true }; }
        case "ack_sop": { await c.query("select ack_sop($1,$2,$3,$4,$5)", [s.farmId, b.sop_code, s.staffId, b.kind ?? "DOC_HIEU", b.score == null ? null : Number(b.score)]); return { ok: true }; }
        case "sync_labor_budget": { if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select sync_labor_budget($1,$2,$3) as n", [s.farmId, Number(b.year ?? new Date().getFullYear()), s.staffId]); return { ok: true, n: r.rows[0].n }; }
        case "gs_ack":''',1))

# ===== 5) admin registry =====
rw("src/lib/admin.ts", lambda s: s.replace('  { table: "dependent_claims",', '''  { table: "qc_holds", pk: "id", label: "QC · giữ lô không đạt (chặn xuất bán)", group: "Chất lượng", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "tech_head", "auditor", "it_engineer"] },
  { table: "supplier_returns", pk: "id", label: "Mua hàng · trả nhà cung cấp (debit note)", group: "Kho & mua", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "accountant", "tech_head", "it_engineer"] },
  { table: "bank_statement_lines", pk: "id", label: "Kế toán · sao kê ngân hàng & đối chiếu", group: "Tài chính", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "accountant", "it_engineer"] },
  { table: "sop_acknowledgments", pk: "id", label: "SOP · ký ban hành / đọc hiểu / xem video", group: "Tổ chức", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "tech_head", "team_lead", "it_engineer"] },
  { table: "dependent_claims",''',1))
