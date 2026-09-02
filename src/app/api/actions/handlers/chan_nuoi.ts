import type { PoolClient } from "pg";
import type { Session } from "@/lib/auth";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type B = any;
export type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;

export const bulkMoveAnimals: ActionHandler = async (c, s, b) => {
  // Cùng mức rủi ro với intake_herd (thao tác hàng loạt trên vật nuôi) — trước đây bulk lại
          // KHÔNG có role check trong khi bản đơn lẻ qua /api/events (animal_events) và intake_herd
          // đều giới hạn worker..owner. Đồng bộ theo đúng role set intake_herd đã dùng.
          if (!["worker","team_lead","tech_head","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          if (!Array.isArray(b.animal_ids) || !b.animal_ids.length) throw new Error("ERR_EMPTY");
          for (const aid of b.animal_ids as string[]) {
            await c.query("insert into animal_events(farm_id,created_by,animal_id,event_type,detail,client_ref) values ($1,$2,$3,'CHUYEN',$4,$5)", [s.farmId, s.staffId, aid, JSON.stringify({ to_location: b.location_id ?? null, to_group: b.group_id ?? null, bulk: true }), `bulk-${Date.now()}-${aid}`]);
            if (b.group_id) await c.query("update animals set group_id=$2 where id=$1", [aid, b.group_id]);
          }
          return { ok: true, n: b.animal_ids.length };
};

export const sellLivestock: ActionHandler = async (c, s, b) => {
  // Bán vật hơi (xuất chuồng): 1 đơn cho cả lô, sinh sự kiện XUAT từng con + nối truy xuất đơn⇄con.
          if (!["team_lead", "tech_head", "director", "owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          if (!Array.isArray(b.animal_ids) || !b.animal_ids.length) throw new Error("ERR_EMPTY");
          const r = await c.query("select sell_livestock($1,$2,$3::text[],$4,$5,$6) as sale_id", [s.farmId, s.staffId, b.animal_ids, b.buyer ?? null, Number(b.price_per_kg), b.sku ?? "SKU-BO-HOI"]);
          const saleId = r.rows[0].sale_id;
          // 2-bộ-hồ-sơ: có ảnh phiếu cân/bán GIẤY → lưu paper_scans (BM06 SALE) nối vào đơn, không mất chứng cứ
          if (b.photo_url) {
            const sc = await c.query("select next_code($1,'BM06') as serial", [s.farmId]);
            await c.query("insert into paper_scans(farm_id,created_by,source,form_code,serial,photo_url,uploaded_by,linked_ids) values($1,$2,'APP','BM06',$3,$4,$2,$5::jsonb)",
              [s.farmId, s.staffId, sc.rows[0].serial, b.photo_url, JSON.stringify([saleId])]);
          }
          return { ok: true, sale_id: saleId };
};

export const assignTag: ActionHandler = async (c, s, b) => {
  // Đồng bộ với intake_herd/bulk_move_animals — thay đổi định danh vật nuôi (luật 4) không nên
          // mở cho accountant/auditor/it_engineer trong khi các thao tác vật nuôi khác đều giới hạn.
          if (!["worker","team_lead","tech_head","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("update animal_tags set to_ts=now(), reason=$3 where animal_id=$1 and tag_type=$2 and to_ts is null", [b.animal_id, b.tag_type, b.reason ?? "thay tai"]);
          await c.query("insert into animal_tags(farm_id,animal_id,tag_type,value,created_by) values ($1,$2,$3,$4,$5)", [s.farmId, b.animal_id, b.tag_type, b.value, s.staffId]);
          if (b.tag_type === "RFID") await c.query("update animals set rfid=$2, tag_pending=false where id=$1", [b.animal_id, b.value]);
          if (b.tag_type === "VISUAL") await c.query("update animals set visual_tag=$2 where id=$1", [b.animal_id, b.value]);
          return { ok: true };
};

export const newAnimal: ActionHandler = async (c, s, b) => {
  if (!["worker","team_lead","tech_head","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const code = (await c.query("select next_code($1,$2,5) as c", [s.farmId, b.species === "DE" ? "DE" : "BO"])).rows[0].c;
          await c.query("insert into animals(id,farm_id,species,breed,sex,birth_date,dam_id,sire_code,rfid,visual_tag,source,intake_lot_id,group_id,status,location_id,tag_pending,cost_center) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)",
            [code, s.farmId, b.species ?? "BO", b.breed ?? null, b.sex ?? null, b.birth_date ?? null, b.dam_id ?? null, b.sire_code ?? null, b.rfid ?? null, b.visual_tag ?? null, b.source ?? "SINH", b.intake_lot_id ?? null, b.group_id ?? null, b.status ?? (b.source === "MUA" ? "CACH_LY" : "SO_SINH"), b.location_id ?? null, !b.rfid, s.farmId + "-CC-BO"]);
          if (b.rfid) await c.query("insert into animal_tags(farm_id,animal_id,tag_type,value,created_by) values ($1,$2,'RFID',$3,$4)", [s.farmId, code, b.rfid, s.staffId]);
          if (b.visual_tag) await c.query("insert into animal_tags(farm_id,animal_id,tag_type,value,created_by) values ($1,$2,'VISUAL',$3,$4)", [s.farmId, code, b.visual_tag, s.staffId]);
          await c.query("insert into animal_events(farm_id,created_by,animal_id,event_type,detail,client_ref) values ($1,$2,$3,$4,$5,$6)", [s.farmId, s.staffId, code, b.source === "MUA" ? "NHAP" : "DE", JSON.stringify({ dam_id: b.dam_id ?? null }), "new-" + code]);
          return { ok: true, code };
};

export const genFeedPlans: ActionHandler = async (c, s) => {
  const r = await c.query("select gen_feed_plans($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n };
};

export const intakeHerd: ActionHandler = async (c, s, b) => {
  if (!["worker","team_lead","tech_head","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          if (!Array.isArray(b.animals) || !b.animals.length || b.animals.length > 2000) throw new Error("ERR_EMPTY: cần 1–2000 con");
          const r = await c.query("select intake_herd($1,$2,$3,$4) as r", [s.farmId, s.staffId, JSON.stringify(b.lot ?? {}), JSON.stringify(b.animals)]);
          await c.query("select gen_monitoring_tasks($1)", [s.farmId]);
          return { ok: true, ...r.rows[0].r };
};

export const recordLabResult: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","team_lead","auditor","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); if (!b.subject || !b.verdict) throw new Error("ERR_MISSING"); const r = await c.query("select record_lab_result($1,$2,$3,$4,$5,$6,$7,$8) as id", [s.farmId, s.staffId, b.subject, b.kind ?? "TA", b.verdict, b.value ?? null, b.file ?? null, b.note ?? null]); return { ok: true, id: r.rows[0].id };
};

export const recordEnergy: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","team_lead","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); if (!b.stream || b.value == null) throw new Error("ERR_MISSING"); await c.query("insert into energy_logs(farm_id,created_by,stream,value,unit,note,photo_urls) values($1,$2,$3,$4,$5,$6,$7)", [s.farmId, s.staffId, b.stream, Number(b.value), b.unit ?? "kWh", b.note ?? null, b.photo_urls ?? []]); return { ok: true };
};

export const recordBiochar: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","team_lead","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); if (b.biochar_kg == null) throw new Error("ERR_MISSING"); await c.query("insert into biochar_batches(farm_id,created_by,feedstock,input_kg,biochar_kg,note,photo_urls) values($1,$2,$3,$4,$5,$6,$7)", [s.farmId, s.staffId, b.feedstock ?? null, b.input_kg ?? null, Number(b.biochar_kg), b.note ?? null, b.photo_urls ?? []]); return { ok: true };
};

export const recordCarbonCredit: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); if (!b.entry_type || b.co2e_tonnes == null) throw new Error("ERR_MISSING"); await c.query("insert into carbon_credits(farm_id,created_by,entry_type,co2e_tonnes,batch_id,buyer,mrv_standard,note,photo_urls) values($1,$2,$3,$4,$5,$6,$7,$8,$9)", [s.farmId, s.staffId, b.entry_type, Number(b.co2e_tonnes), b.batch_id ?? null, b.buyer ?? null, b.mrv_standard ?? null, b.note ?? null, b.photo_urls ?? []]); return { ok: true };
};

export const recordCea: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","team_lead","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); if (!b.crop || b.area_m2 == null) throw new Error("ERR_MISSING"); await c.query("insert into cea_batches(farm_id,created_by,house_id,crop,area_m2,nutrient_source,note,photo_urls) values($1,$2,$3,$4,$5,coalesce($6,'DIGESTATE'),$7,$8)", [s.farmId, s.staffId, b.house_id ?? null, b.crop, Number(b.area_m2), b.nutrient_source ?? null, b.note ?? null, b.photo_urls ?? []]); return { ok: true };
};

export const recordDuckweed: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","team_lead","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); if (b.area_m2 == null) throw new Error("ERR_MISSING"); await c.query("insert into duckweed_batches(farm_id,created_by,pond_id,area_m2,note,photo_urls) values($1,$2,$3,$4,$5,$6)", [s.farmId, s.staffId, b.pond_id ?? null, Number(b.area_m2), b.note ?? null, b.photo_urls ?? []]); return { ok: true };
};

export const recordReading: ActionHandler = async (c, s, b) => {
  const r = await c.query("select record_reading($1,$2,$3,$4,$5,$6,$7,$8,'APP') as res", [s.farmId, b.metric_id, Number(b.value), b.ts ?? null, b.paper_serial ?? null, b.note ?? null, s.staffId, b.client_ref ?? `rd-${b.metric_id}-${Date.now()}`]); return { ok: true, ...(r.rows[0].res as object) };
};

