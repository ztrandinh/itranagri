import type { PoolClient } from "pg";
import type { Session } from "@/lib/auth";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type B = any;
export type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;

export const createPo: ActionHandler = async (c, s, b) => {
  const id = (await c.query("select next_code($1,'PO',4) as c", [s.farmId])).rows[0].c;
          const total = (b.lines as { qty: number; price: number }[]).reduce((a, l) => a + Number(l.qty) * Number(l.price), 0);
          await c.query("insert into purchase_orders(id,farm_id,supplier_id,created_by,lines,total,note) values ($1,$2,$3,$4,$5,$6,$7)", [id, s.farmId, b.supplier_id, s.staffId, JSON.stringify(b.lines), total, b.note ?? null]);
          return { ok: true, id, total };
};

export const receivePo: ActionHandler = async (c, s, b) => {
  if (!["worker","team_lead","tech_head","accountant","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select receive_po($1,$2,$3::jsonb) as n", [b.id, b.warehouse_id ?? null, b.lines ? JSON.stringify(b.lines) : null]); return { ok: true, n: r.rows[0].n };
};

export const createPoFull: ActionHandler = async (c, s, b) => {
  const id = (await c.query("select next_code($1,'PO',4) as c", [s.farmId])).rows[0].c;
          const lines = (b.lines as { sku: string; qty: number; price: number }[]).filter((l) => l.sku && Number(l.qty) > 0); if (!lines.length) throw new Error("ERR_LINES");
          const total = lines.reduce((a, l) => a + Number(l.qty) * Number(l.price ?? 0), 0);
          await c.query("insert into purchase_orders(id,farm_id,supplier_id,created_by,lines,total,note,expected_at,kind,requested_by_dept) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)", [id, s.farmId, b.supplier_id, s.staffId, JSON.stringify(lines), total, b.note ?? null, b.expected_at ?? null, b.kind ?? "VAT_TU", b.dept ?? null]);
          await c.query("select publish_event($1,'po.created',$2::jsonb)", [s.farmId, JSON.stringify({ po_id: id, total, kind: b.kind ?? "VAT_TU", supplier_id: b.supplier_id })]).catch(() => null);
          return { ok: true, id, total };
};

export const poStatus: ActionHandler = async (c, s, b) => {
  if (!["tech_head", "director", "accountant", "team_lead"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const po = (await c.query("select created_by from purchase_orders where id=$1", [b.id])).rows[0];
          if (b.status === "DUYET" && po?.created_by === s.staffId) throw new Error("ERR_SELF_APPROVE");
          await c.query("update purchase_orders set po_status=$2, approved_by=case when $2='DUYET' then $3 else approved_by end, approved_at=case when $2='DUYET' then now() else approved_at end where id=$1", [b.id, b.status, s.staffId]);
          return { ok: true };
};

export const supplierReturn: ActionHandler = async (c, s, b) => {
  const id = `${s.farmId}-SRET-${Date.now().toString(36)}`; await c.query("insert into supplier_returns(id,farm_id,po_id,supplier_id,sku,lot_id,qty,unit_cost,amount,reason,disposition,warehouse_id,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)", [id, s.farmId, b.po_id ?? null, b.supplier_id ?? null, b.sku ?? null, b.lot_id ?? null, Number(b.qty), b.unit_cost == null ? null : Number(b.unit_cost), b.amount == null ? null : Number(b.amount), b.reason ?? null, b.disposition ?? "TRA_LAI", b.warehouse_id ?? null, s.staffId]); return { ok: true, id };
};

export const approveSupplierReturn: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select approve_supplier_return($1,$2)", [b.id, s.staffId]); return { ok: true };
};

export const approveReturn: ActionHandler = async (c, s, b) => {
  if (!["director","owner","accountant","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select approve_return($1,$2)", [b.id, s.staffId]); return { ok: true };
};

