import { NextResponse } from "next/server";
import JSZip from "jszip";
import { createHash } from "node:crypto";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";

/** GET /api/exports/{kind}?from&to&sku&lot&farm  — kinds:
 *  all (ZIP CSV toàn bộ + schema + sha256) · audit-pack (ZIP hồ sơ audit ≤24h theo kỳ/SKU) · tt66 (hồ sơ chăn nuôi TT 66/2025) ·
 *  sales-tax (bảng kê bán hàng cho kế toán/thuế – MISA CSV) · stock-ledger · herd · medicine-book · gap-log · epcis (lot JSON-LD) · owner-weekly (1 trang JSON) · table:{tên} */
const EVENT_TABLES = ["animal_events","feed_logs","crop_logs","batch_logs","inventory_moves","weigh_tickets","gate_logs","sales","checklist_runs","incidents","adjustments","stocktakes","calibrations","paper_scans","recon_results","alerts","tasks","shift_notes","purchase_orders","expense_requests"];
const MASTER_TABLES = ["farms","staff","cost_centers","locations","products","partners","devices","recipes","sops","sop_versions","warehouses","plots","animals","animal_groups","intake_lots","animal_ownership","animal_tags","lots","settings","norms","kpi_defs","rc_rules","alert_rules","price_list","paper_form_templates","regions","orgs","audit_anchors"];

function csv(rows: Record<string, unknown>[]): string {
  if (!rows.length) return "";
  const cols = Object.keys(rows[0]);
  const esc = (v: unknown) => { const s = v == null ? "" : typeof v === "object" ? JSON.stringify(v) : String(v); return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; };
  return "﻿" + cols.join(",") + "\n" + rows.map((r) => cols.map((c) => esc(r[c])).join(",")).join("\n");
}

export async function GET(req: Request, { params }: { params: Promise<{ kind: string }> }) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const { kind } = await params; const u = new URL(req.url);
  const farm = u.searchParams.get("farm") ?? s.farmId; const from = u.searchParams.get("from") ?? "2000-01-01"; const to = u.searchParams.get("to") ?? "2100-01-01";
  const sku = u.searchParams.get("sku"); const lot = u.searchParams.get("lot");
  const ctx = { ...s, farmId: farm };
  // BẢO MẬT: trước đây chỉ kind="all" kiểm role — mọi kind khác (audit-pack/tt66/sales-tax/table:*/…)
  // chỉ cần đăng nhập là tải được trọn dữ liệu tuân thủ/tài chính của cả trại (RLS chỉ chặn theo farm_id,
  // KHÔNG chặn theo role khi SELECT). Chặn chung ở đây cho MỌI kind: worker/team_lead không xuất hàng loạt
  // (vẫn xem đủ dữ liệu qua UI bình thường — chỉ export CSV/ZIP toàn trại là bị chặn).
  if (["worker", "team_lead"].includes(s.role)) return NextResponse.json({ error: "ERR_FORBIDDEN_ROLE" }, { status: 403 });
  const zipRes = async (name: string, files: Record<string, string>) => {
    const zip = new JSZip(); const manifest: Record<string, string> = {};
    for (const [n, content] of Object.entries(files)) { zip.file(n, content); manifest[n] = createHash("sha256").update(content).digest("hex"); }
    zip.file("MANIFEST.sha256.json", JSON.stringify({ generated_at: new Date().toISOString(), by: s.staffId, farm, from, to, files: manifest }, null, 2));
    const buf = await zip.generateAsync({ type: "nodebuffer" });
    return new NextResponse(new Uint8Array(buf), { headers: { "content-type": "application/zip", "content-disposition": `attachment; filename="${name}"` } });
  };
  const csvRes = (name: string, rows: Record<string, unknown>[]) => new NextResponse(csv(rows), { headers: { "content-type": "text/csv; charset=utf-8", "content-disposition": `attachment; filename="${name}"` } });

  try {
    return await withCtx(ctx, async (c) => {
      const q = async (sql: string, p: unknown[] = []) => (await c.query(sql, p)).rows as Record<string, unknown>[];
      // Ai xuất gì khi nào (trước đây không nơi nào ghi lại — bằng chứng duy nhất là MANIFEST tự nộp trong
      // chính file ZIP do người tải kiểm soát). Ghi TRƯỚC khi chạy — export lỗi vẫn để lại dấu vết đã yêu cầu.
      await c.query("insert into audit_log(farm_id,table_name,pk,action,after,by_staff,by_role) values ($1,$2,$3,'EXPORT',$4,$5,$6)",
        [farm, kind, farm, JSON.stringify({ from, to, sku, lot }), s.staffId, s.role]).catch(() => {});
      switch (kind) {
        case "all": {
          if (!["director","owner","auditor","it_engineer","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const files: Record<string, string> = {}; const schema: Record<string, string[]> = {};
          for (const t of [...MASTER_TABLES, ...EVENT_TABLES]) {
            const hasFarm = (await q("select 1 from information_schema.columns where table_name=$1 and column_name='farm_id'", [t])).length > 0;
            const rows = await q(hasFarm ? `select * from ${t} where farm_id=$1` : `select * from ${t}`, hasFarm ? [farm] : []);
            files[`${t}.csv`] = csv(rows); schema[t] = rows[0] ? Object.keys(rows[0]) : [];
          }
          files["schema.json"] = JSON.stringify(schema, null, 2);
          files["README.txt"] = `ITRAN AGRI · xuất toàn bộ dữ liệu trại ${farm} · ${new Date().toISOString()}\nDữ liệu thuộc công ty ITRAN FARM. Định dạng CSV UTF-8 (BOM), JSON trong ô = chuỗi JSON. Bảng sự kiện là append-only (status ACTIVE/SUPERSEDED/VOID).`;
          return zipRes(`itranagri-${farm}-all-${new Date().toISOString().slice(0, 10)}.zip`, files);
        }
        case "audit-pack": {
          const files: Record<string, string> = {};
          const w = (t: string) => `where farm_id=$1 and ts::date between $2 and $3${sku && ["sales","inventory_moves"].includes(t) ? " and sku=$4" : ""}`;
          for (const t of ["animal_events","feed_logs","crop_logs","batch_logs","inventory_moves","sales","checklist_runs","incidents","gate_logs","calibrations","paper_scans","adjustments","stocktakes"])
            files[`${t}.csv`] = csv(await q(`select * from ${t} ${w(t)} order by ts`, sku && ["sales","inventory_moves"].includes(t) ? [farm, from, to, sku] : [farm, from, to]));
          files["recon_results.csv"] = csv(await q("select * from recon_results where farm_id=$1 and period between $2 and $3 order by period, rule_code", [farm, from, to]));
          files["alerts.csv"] = csv(await q("select * from alerts where farm_id=$1 and ts::date between $2 and $3 order by ts", [farm, from, to]));
          files["sop_versions.csv"] = csv(await q("select * from sop_versions where status='BAN_HANH'"));
          files["staff_certs.csv"] = csv(await q("select id, full_name, role, position, sop_certs, health_check_due, food_safety_training_due from staff where farm_id=$1 or farm_id is null", [farm]));
          files["lots.csv"] = csv(await q("select * from lots where farm_id=$1", [farm]));
          files["animals.csv"] = csv(await q("select * from animals where farm_id=$1", [farm]));
          files["withdrawal.csv"] = csv(await q("select e.animal_id, e.ts, e.detail->>'note' as note, e.withdrawal_until from animal_events e where e.farm_id=$1 and e.event_type in ('DIEU_TRI','VACCINE') and e.ts::date between $2 and $3 order by ts", [farm, from, to]));
          files["audit_anchors.csv"] = csv(await q("select * from audit_anchors where farm_id=$1 and day between $2 and $3 order by day", [farm, from, to]));
          files["INDEX.md"] = `# Hồ sơ audit ITRAN AGRI\nTrại ${farm} · kỳ ${from} → ${to}${sku ? ` · SKU ${sku}` : ""} · sinh ${new Date().toISOString()} bởi ${s.staffId}\n\nMục lục: nhật ký sự kiện vật nuôi, cho ăn, ruộng, mẻ, kho, bán, checklist, sự cố, cổng, hiệu chuẩn, phiếu giấy, điều chỉnh, kiểm kê, đối soát RC, cảnh báo, SOP ban hành, chứng chỉ nhân sự, lô, đàn, ngưng thuốc, neo audit (hash ngày).\nNguyên tắc: không bản ghi = không tồn tại; sự kiện append-only; mọi bản ghi có người ghi + thời gian + nguồn (APP/PAPER/DEVICE/IMPORT).`;
          return zipRes(`audit-pack-${farm}-${from}_${to}.zip`, files);
        }
        case "tt66": {
          // Hồ sơ chăn nuôi (Thông tư 66/2025/TT-BNNMT): thông tin cơ sở, đàn/lô, xuất nhập, nguồn giống, thuốc thú y/vaccine, xét nghiệm, giết mổ/chế biến
          const files: Record<string, string> = {};
          files["01_co_so.csv"] = csv(await q("select f.id, f.name, f.legal_entity, f.province, f.s_ha, r.name as region from farms f left join regions r on r.id=f.region_id where f.id=$1", [farm]));
          files["02_dan_ca_the.csv"] = csv(await q("select id, species, breed, sex, birth_date, rfid, visual_tag, source, intake_lot_id, status, location_id, dam_id, sire_code from animals where farm_id=$1 order by id", [farm]));
          files["03_dan_nhom.csv"] = csv(await q("select id, species, kind, name, head_count, started_at, all_in_all_out, status from animal_groups where farm_id=$1", [farm]));
          files["04_lo_nhap_nguon_giong.csv"] = csv(await q("select * from intake_lots where farm_id=$1 order by date", [farm]));
          files["05_xuat_nhap_dan.csv"] = csv(await q("select ts, animal_id, group_id, event_type, value, unit, detail, created_by from animal_events where farm_id=$1 and event_type in ('NHAP','XUAT','CHET','LOAI','CHUYEN','SO_LUONG') and ts::date between $2 and $3 order by ts", [farm, from, to]));
          files["06_thuoc_vaccine.csv"] = csv(await q("select e.ts, e.animal_id, e.group_id, e.event_type, e.value, e.unit, e.detail->>'note' as thuoc_ghi_chu, e.withdrawal_until, e.created_by from animal_events e where e.farm_id=$1 and e.event_type in ('DIEU_TRI','VACCINE','BENH') and e.ts::date between $2 and $3 order by ts", [farm, from, to]));
          files["07_xuat_kho_thuoc.csv"] = csv(await q("select m.ts, m.sku, p.name, m.lot_id, m.qty, m.unit, m.reason, m.from_to from inventory_moves m join products p on p.sku=m.sku where m.farm_id=$1 and p.kind in ('THUOC','VACCINE') and m.ts::date between $2 and $3 order by ts", [farm, from, to]));
          files["08_thuc_an.csv"] = csv(await q("select ts, dest_group_id, recipe_id, recipe_version, qty_kg, planned_kg, meal, created_by from feed_logs where farm_id=$1 and ts::date between $2 and $3 order by ts", [farm, from, to]));
          files["09_ban_giet_mo.csv"] = csv(await q("select s.ts, s.partner_id, p.name as khach, s.sku, s.lot_id, s.qty, s.unit, s.price, s.amount, s.channel from sales s left join partners p on p.id=s.partner_id where s.farm_id=$1 and s.ts::date between $2 and $3 order by ts", [farm, from, to]));
          files["10_su_co_dich.csv"] = csv(await q("select ts, code, kind, severity, description, classification, closed_at from incidents where farm_id=$1 and ts::date between $2 and $3 order by ts", [farm, from, to]));
          files["README.txt"] = `Hồ sơ chăn nuôi theo cấu trúc Thông tư 66/2025/TT-BNNMT (trại ${farm}, kỳ ${from}→${to}). Sinh tự động từ ITRAN AGRI ${new Date().toISOString()}. Mọi dòng có người ghi/thời gian; bản ghi gốc không thể sửa xóa.`;
          return zipRes(`ho-so-chan-nuoi-TT66-${farm}-${from}_${to}.zip`, files);
        }
        case "sales-tax": {
          const rows = await q(`select s.ts as ngay, s.invoice_no as so_hoa_don, p.name as ten_khach, p.tax_code as mst, s.sku as ma_hang, pr.name as ten_hang, s.qty as so_luong, s.unit as dvt, s.price as don_gia, s.amount as thanh_tien, s.channel as kenh, s.payment as hinh_thuc_tt, case when s.paid then 'Đã thu' else 'Công nợ' end as trang_thai, s.lot_id as lo, s.created_by as nguoi_ghi
            from sales s left join partners p on p.id=s.partner_id left join products pr on pr.sku=s.sku where s.farm_id=$1 and s.status='ACTIVE' and s.ts::date between $2 and $3 order by s.ts`, [farm, from, to]);
          return csvRes(`bang-ke-ban-hang-${farm}-${from}_${to}.csv`, rows);
        }
        case "purchases": {
          const rows = await q(`select m.ts as ngay, m.from_to as ncc, m.sku as ma_hang, p.name as ten_hang, m.lot_id as lo, m.qty as so_luong, m.unit as dvt, m.unit_cost as don_gia, m.qty*coalesce(m.unit_cost,0) as thanh_tien, m.weigh_point as diem_ghi, m.created_by from inventory_moves m join products p on p.sku=m.sku where m.farm_id=$1 and m.status='ACTIVE' and m.direction=1 and m.reason='NHAP_MUA' and m.ts::date between $2 and $3 order by m.ts`, [farm, from, to]);
          return csvRes(`bang-ke-mua-hang-${farm}-${from}_${to}.csv`, rows);
        }
        case "stock-ledger": return csvRes(`the-kho-${farm}.csv`, await q("select * from v_stock_ledger where farm_id=$1 and ts::date between $2 and $3 order by warehouse_id, sku, ts", [farm, from, to]));
        case "stock-balance": return csvRes(`ton-kho-${farm}.csv`, await q("select * from v_stock_balance where farm_id=$1 order by warehouse_code, sku", [farm]));
        case "herd": return csvRes(`so-dan-${farm}.csv`, await q("select a.*, g.name as group_name from animals a left join animal_groups g on g.id=a.group_id where a.farm_id=$1 order by a.id", [farm]));
        case "medicine-book": return csvRes(`so-thuoc-${farm}.csv`, await q("select e.ts, e.animal_id, e.group_id, e.event_type, e.value, e.unit, e.detail, e.withdrawal_until, e.created_by from animal_events e where e.farm_id=$1 and e.event_type in ('DIEU_TRI','VACCINE') and e.ts::date between $2 and $3 order by ts", [farm, from, to]));
        case "gap-log": return csvRes(`nhat-ky-gap-${farm}.csv`, await q("select c.ts, c.plot_id, p.name as plot, c.activity, c.variety, c.input_lots, c.qty_kg, c.machine_id, c.machine_hours, c.fuel_l, c.water_source, c.water_m3, c.chemical, c.director_order, c.phi_until, c.created_by, c.source from crop_logs c join plots p on p.id=c.plot_id where c.farm_id=$1 and c.ts::date between $2 and $3 order by ts", [farm, from, to]));
        case "crop-dossier": {
          const season = u.searchParams.get("season"); const seasons = await q(season ? "select * from v_crop_dossier where farm_id=$1 and id=$2" : "select * from v_crop_dossier where farm_id=$1 order by sow_date desc", season ? [farm, season] : [farm]);
          const files: Record<string, string> = { "00_mua_vu.csv": csv(seasons) };
          for (const sn of seasons) { const sid = String(sn.id); const pid = String(sn.plot_id); const iso = (v: unknown, d: string) => (v ? new Date(String(v)).toISOString().slice(0, 10) : d); const f0 = iso(sn.sow_date, "2000-01-01"), t0 = iso(sn.harvest_end, "2100-01-01");
            files[`${sn.code}/01_nhat_ky_ruong.csv`] = csv(await q("select ts, activity, variety, qty_kg, moisture_pct, machine_id, machine_hours, fuel_l, water_m3, chemical, phi_until, created_by, source, paper_serial from crop_logs where farm_id=$1 and plot_id=$2 and status='ACTIVE' and ts::date between $3 and $4 order by ts", [farm, pid, f0, t0]));
            files[`${sn.code}/02_vat_tu_phan_bvtv.csv`] = csv(await q("select ts, kind, sku, product_name, qty, unit, dose_per_ha, method, target_pest, phi_days, safe_after, weather, organic_allowed, applicator_id, created_by, lot_no from crop_inputs where farm_id=$1 and (season_id=$2 or (plot_id=$3 and ts::date between $4 and $5)) and status='ACTIVE' order by ts", [farm, sid, pid, f0, t0]));
            files[`${sn.code}/03_thu_hoach.csv`] = csv(await q("select ts, crop, variety, qty_kg, moisture_pct, grade, harvest_lot, dest_warehouse_id, phi_ok, residue_test, weigh_ticket_id, created_by from harvests where farm_id=$1 and (season_id=$2 or (plot_id=$3 and ts::date between $4 and $5)) and status='ACTIVE' order by ts", [farm, sid, pid, f0, t0]));
            files[`${sn.code}/04_mau_lab.csv`] = csv(await q("select * from lab_samples where farm_id=$1 and subject_ref in ($2,$3)", [farm, sid, pid]));
          }
          return zipRes(`nhat-ky-san-xuat-${farm}-${season ?? "tat-ca"}.zip`, files);
        }
        case "harvest-log": return csvRes(`thu-hoach-${farm}.csv`, await q("select h.ts, h.plot_id, p.name as plot, h.crop, h.variety, h.qty_kg, h.moisture_pct, h.grade, h.harvest_lot, h.dest_warehouse_id, h.phi_ok, h.created_by from harvests h left join plots p on p.id=h.plot_id where h.farm_id=$1 and h.status='ACTIVE' and h.ts::date between $2 and $3 order by h.ts", [farm, from, to]));
        case "audit-std": {
          const std = u.searchParams.get("std") ?? "VIETGAP-TT"; const files: Record<string, string> = {};
          const reqs = await q("select r.*, (select string_agg(cc.control_id, ',') from clause_controls cc where cc.requirement_id=r.id) as controls from standard_requirements r where standard_code=$1 order by clause", [std]);
          files["00_dieu_khoan_control.csv"] = csv(reqs);
          const ctls = await q("select c.* from controls c where c.id in (select cc.control_id from clause_controls cc join standard_requirements r on r.id=cc.requirement_id where r.standard_code=$1)", [std]);
          files["01_controls.csv"] = csv(ctls);
          for (const ctl of ctls) { try { const qq = String(ctl.evidence_query ?? ""); if (!/^\s*select/i.test(qq)) continue; const rows = await q(qq.includes("$1") ? qq : qq + " where $1::text is not null", [farm]); files[`evidence/${ctl.id}.csv`] = csv(rows); } catch (e) { files[`evidence/${ctl.id}.err.txt`] = (e as Error).message; } }
          const tables = [...new Set(reqs.flatMap((r) => (r.evidence_tables as string[]) ?? []))].filter((t) => /^[a-z_]+$/.test(t));
          for (const t of tables) { try { const hasFarm = (await q("select 1 from information_schema.columns where table_name=$1 and column_name='farm_id'", [t])).length > 0; const hasTs = (await q("select 1 from information_schema.columns where table_name=$1 and column_name='ts'", [t])).length > 0; const rows = await q(`select * from ${t} where 1=1 ${hasFarm ? "and farm_id=$1" : ""} ${hasTs ? "and ts::date between $2 and $3" : ""} limit 20000`, hasFarm && hasTs ? [farm, from, to] : hasFarm ? [farm] : hasTs ? [] : []); if (rows.length) files[`data/${t}.csv`] = csv(rows); } catch { /* bảng/view không có → bỏ */ } }
          files["02_checks.csv"] = csv(await q("select c.* from compliance_checks c where c.farm_id=$1 and c.standard_code=$2 order by checked_at desc", [farm, std]));
          files["03_certifications.csv"] = csv(await q("select * from certifications where (farm_id=$1 or farm_id is null) and standard_code=$2", [farm, std]));
          return zipRes(`audit-${std}-${farm}.zip`, files);
        }
        case "stock-card": return csvRes(`the-kho-${sku ?? "all"}-${farm}.csv`, await q("select * from v_stock_card where farm_id=$1 and ($2::text is null or sku=$2) and ts::date between $3 and $4 order by sku, lot_id, ts", [farm, sku, from, to]));
        case "recon": return csvRes(`doi-soat-${farm}.csv`, await q("select * from recon_results where farm_id=$1 and period between $2 and $3 order by period, rule_code", [farm, from, to]));
        case "epcis": {
          if (!lot) throw new Error("ERR_LOT_REQUIRED");
          const links = await q("select * from v_trace_links where farm_id=$1 and (input_lot=$2 or output_lot=$2)", [farm, lot]);
          const moves = await q("select * from inventory_moves where farm_id=$1 and lot_id=$2 and status='ACTIVE' order by ts", [farm, lot]);
          const sales = await q("select s.*, p.name as partner_name from sales s left join partners p on p.id=s.partner_id where s.farm_id=$1 and s.lot_id=$2 and s.status='ACTIVE'", [farm, lot]);
          const events = [
            ...links.map((l) => ({ type: "TransformationEvent", eventTime: l.ts, bizStep: "urn:epcglobal:cbv:bizstep:transforming", inputQuantityList: [{ epcClass: `urn:itran:lot:${l.input_lot}` }], outputQuantityList: [{ epcClass: `urn:itran:lot:${l.output_lot}` }], transformationID: l.batch_code, readPoint: { id: `urn:itran:farm:${farm}` } })),
            ...moves.map((m) => ({ type: "ObjectEvent", eventTime: m.ts, action: Number(m.direction) > 0 ? "ADD" : "OBSERVE", bizStep: Number(m.direction) > 0 ? "urn:epcglobal:cbv:bizstep:receiving" : "urn:epcglobal:cbv:bizstep:shipping", quantityList: [{ epcClass: `urn:itran:lot:${lot}`, quantity: Number(m.qty), uom: m.unit }], readPoint: { id: `urn:itran:loc:${m.warehouse_id}` }, bizLocation: { id: `urn:itran:farm:${farm}` } })),
            ...sales.map((x) => ({ type: "TransactionEvent", eventTime: x.ts, action: "ADD", bizStep: "urn:epcglobal:cbv:bizstep:shipping", bizTransactionList: [{ type: "urn:epcglobal:cbv:btt:inv", bizTransaction: `urn:itran:sale:${x.id}` }], quantityList: [{ epcClass: `urn:itran:lot:${lot}`, quantity: Number(x.qty), uom: x.unit }], destinationList: [{ type: "urn:epcglobal:cbv:sdt:owning_party", destination: `urn:itran:partner:${x.partner_id}` }] })),
          ];
          return NextResponse.json({ "@context": ["https://ref.gs1.org/standards/epcis/2.0.0/epcis-context.jsonld"], type: "EPCISDocument", schemaVersion: "2.0", creationDate: new Date().toISOString(), epcisBody: { eventList: events } });
        }
        default: {
          if (kind.startsWith("table:")) { const t = kind.slice(6); if (!/^[a-z_]+$/.test(t) || ![...MASTER_TABLES, ...EVENT_TABLES].includes(t)) throw new Error("ERR_BAD_TABLE"); const hasFarm = (await q("select 1 from information_schema.columns where table_name=$1 and column_name='farm_id'", [t])).length > 0; return csvRes(`${t}-${farm}.csv`, await q(hasFarm ? `select * from ${t} where farm_id=$1` : `select * from ${t}`, hasFarm ? [farm] : [])); }
          throw new Error("ERR_UNKNOWN_KIND");
        }
      }
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const code = msg.match(/ERR_[A-Z_]+/)?.[0];
    if (!code) console.error("[exports]", kind, msg); // không lộ chi tiết driver DB ra client (xem actions/route.ts)
    return NextResponse.json({ error: code ?? "ERR", detail: code ? msg : "Có lỗi xảy ra, vui lòng thử lại hoặc báo kỹ thuật." }, { status: 400 });
  }
}
