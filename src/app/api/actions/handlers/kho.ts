import type { PoolClient } from "pg";
import type { Session } from "@/lib/auth";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type B = any;
export type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;

export const approveAdjustment: ActionHandler = async (c, s, b) => {
  if (!["tech_head","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const a = (await c.query("select * from adjustments where id=$1", [b.id])).rows[0];
          if (!a) throw new Error("ERR_NOT_FOUND");
          if (a.requested_by === s.staffId || a.created_by === s.staffId) throw new Error("ERR_SELF_APPROVE");
          const st = b.approve ? "DUYET" : "TU_CHOI";
          await c.query("update adjustments set adj_status=$2, approved_by=$3, approved_at=now() where id=$1", [b.id, st, s.staffId]);
          if (b.approve && a.warehouse_id && a.sku && a.delta) {
            await c.query("insert into inventory_moves(farm_id,created_by,source,warehouse_id,sku,lot_id,direction,qty,reason,ref_type,ref_id) values ($1,$2,'APP',$3,$4,$5,$6,$7,'DIEU_CHINH','adjustments',$8)",
              [s.farmId, s.staffId, a.warehouse_id, a.sku, a.lot_id, a.delta > 0 ? 1 : -1, Math.abs(a.delta), a.id]);
          }
          return { ok: true, status: st };
};

export const reserveOrder: ActionHandler = async (c, s, b) => {
  const r = await c.query("select gen_production_from_shortage($1,$2) as lsx", [b.id, s.staffId]); const sh = await c.query("select jsonb_agg(jsonb_build_object('sku',sku,'short',(select (l->>'qty')::numeric from orders o, jsonb_array_elements(o.lines) l where o.id=$1 and l->>'sku'=p.sku limit 1) - coalesce((select sum(qty) from stock_reservations x where x.order_id=$1 and x.sku=p.sku and x.status='GIU'),0))) as short from (select distinct sku from production_orders where order_id=$1 and status in ('MOI','DANG_LAM')) p", [b.id]); return { ok: true, lsx: r.rows[0].lsx, short: sh.rows[0].short ?? [] };
};

export const setReserve: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","it_engineer","accountant","team_lead"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update products set reserve=$2 where sku=$1", [b.sku, !!b.reserve]); return { ok: true };
};

export const addReserveItem: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","it_engineer","team_lead"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const g = (await c.query("select * from stock_groups where code=$1", [b.group])).rows[0]; if (!g) throw new Error("ERR_GROUP"); const sku = String(b.sku ?? ("SKU-" + String(b.name).normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/gi, "d").toUpperCase().replace(/[^A-Z0-9]+/g, "-").slice(0, 24))); await c.query("insert into products(sku, org_id, name, kind, unit, stock_group, reserve, active, shelf_life_days) values ($1,'ITRAN',$2,$3,$4,$5,true,true,$6) on conflict (sku) do update set reserve=true, stock_group=excluded.stock_group", [sku, b.name, g.kind_default ?? "NGUYEN_LIEU", b.unit ?? g.unit_default ?? "kg", b.group, b.shelf_life_days ?? null]); return { ok: true, sku };
};

export const toolIssue: ActionHandler = async (c, s, b) => {
  const r = await c.query("insert into tool_issues(farm_id, warehouse_id, sku, qty, staff_id, dept, purpose, due_back) values ($1,$2,$3,$4,$5,$6,$7,$8) returning id", [s.farmId, b.warehouse_id, b.sku, Number(b.qty ?? 1), b.staff_id ?? null, b.dept ?? null, b.purpose ?? null, b.due_back ?? null]); return { ok: true, id: r.rows[0].id };
};

export const toolReturn: ActionHandler = async (c, s, b) => {
  const t = (await c.query("select * from tool_issues where id=$1 and farm_id=$2", [b.id, s.farmId])).rows[0]; if (!t) throw new Error("ERR_NOT_FOUND"); const cond = String(b.condition ?? "TOT"); const rq = Number(b.returned_qty ?? t.qty); await c.query("update tool_issues set returned_at=now(), returned_qty=$2, condition=$3, note=coalesce(note,'')||$4 where id=$1", [b.id, rq, cond, b.note ? " · " + b.note : ""]); if ((cond === "HONG" || cond === "MAT") && Number(t.qty) - rq > 0) { await c.query("insert into inventory_moves(farm_id, created_by, warehouse_id, sku, direction, qty, unit, reason, from_to, ref_type, ref_id, client_ref) values ($1,$2,$3,$4,-1,$5,(select unit from products where sku=$4),$6,$7,'tool_issue',$8,$9)", [s.farmId, s.staffId, t.warehouse_id, t.sku, Number(t.qty) - rq, cond, "Cấp phát #" + b.id, String(b.id), "tool-" + b.id + "-" + cond]); } return { ok: true };
};

export const toolMove: ActionHandler = async (c, s, b) => {
  const q = Number(b.qty); if (!(q > 0)) throw new Error("ERR_QTY"); const u = (await c.query("select unit from products where sku=$1", [b.sku])).rows[0]?.unit; const ref = "toolmove-" + Date.now();
          // ref_type/ref_id trước đây bỏ trống — đứt truy xuất (2 dòng move cùng 1 lần chuyển không nối được nhau qua báo cáo). Gắn ref_type='TOOL_MOVE', ref_id=ref chung cho cả 2 dòng.
          await c.query("insert into inventory_moves(farm_id, created_by, warehouse_id, sku, direction, qty, unit, reason, from_to, client_ref, ref_type, ref_id) values ($1,$2,$3,$4,-1,$5,$6,'CHUYEN',$7,$8,'TOOL_MOVE',$9)", [s.farmId, s.staffId, b.from_wh, b.sku, q, u, "→ " + b.to_wh, ref + "-out", ref]);
          await c.query("insert into inventory_moves(farm_id, created_by, warehouse_id, sku, direction, qty, unit, reason, from_to, client_ref, ref_type, ref_id) values ($1,$2,$3,$4,1,$5,$6,'CHUYEN',$7,$8,'TOOL_MOVE',$9)", [s.farmId, s.staffId, b.to_wh, b.sku, q, u, "← " + b.from_wh, ref + "-in", ref]);
          return { ok: true };
};

export const qcHold: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","team_lead","auditor","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select qc_hold($1,$2,$3,$4,$5,$6) as id", [s.farmId, b.ref_type ?? "LOT", b.ref, b.reason, b.severity ?? "TRUNG", s.staffId]); return { ok: true, id: r.rows[0].id };
};

export const qcRelease: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","auditor"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select qc_release($1::uuid,$2,$3,$4)", [b.id, s.staffId, b.disposition ?? null, b.status ?? "GIAI_TOA"]); return { ok: true };
};

export const recallLot: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","auditor"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); if (!b.lot_id || !b.reason) throw new Error("ERR_MISSING"); const r = await c.query("select recall_lot($1,$2,$3,$4,$5) as id", [s.farmId, b.lot_id, b.reason, s.staffId, b.severity ?? "NANG"]); return { ok: true, recall_id: r.rows[0].id };
};

export const recordIntake: ActionHandler = async (c, s, b) => {
  if (s.role === "auditor") throw new Error("ERR_FORBIDDEN_ROLE"); if (!b.sku || !b.qty) throw new Error("ERR_MISSING"); const r = await c.query("select record_intake($1,$2,$3,$4,$5,$6,$7,coalesce($8::date,current_date),$9,$10,$11) as j", [s.farmId, b.sku, Number(b.qty), s.staffId, b.source_type ?? null, b.source_id ?? null, b.client_ref ?? null, b.date ?? null, b.grade ?? null, b.unit ?? null, b.warehouse ?? null]); return { ok: true, ...r.rows[0].j };
};

export const refreshCache: ActionHandler = async (c, s) => {
  const r = await c.query("select refresh_farm_cache($1) as r", [s.farmId]); await c.query("delete from cache_dirty where farm_id=$1", [s.farmId]).catch(() => null); return { ok: true, ...r.rows[0].r };
};

export const applyLandedCost: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select apply_landed_cost($1) as n", [b.shipment_id]); return { ok: true, n: r.rows[0].n };
};

