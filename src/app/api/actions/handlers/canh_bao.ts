import type { PoolClient } from "pg";
import type { Session } from "@/lib/auth";
import { EVENT_TABLES } from "@/lib/events";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type B = any;
export type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;

export const ackAlert: ActionHandler = async (c, s, b) => {
  await c.query("update alerts set acked_by=$2, acked_at=now() where id=$1", [b.id, s.staffId]); return { ok: true };
};

export const ackRecon: ActionHandler = async (c, s, b) => {
  await c.query("update recon_results set acked_by=$2 where id=$1", [b.id, s.staffId]); return { ok: true };
};

export const voidEvent: ActionHandler = async (c, s, b) => {
  if (!["tech_head","director"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          // BẢO MẬT: chỉ cho void đúng BẢNG SỰ KIỆN đã đăng ký (EVENT_TABLES, nguồn: lib/events.ts) — whitelist thật,
          // không phải regex tên bảng (trước đây `/^[a-z_]+$/` cho phép nhắm bất kỳ bảng nào có cột id/farm_id/status).
          if (!(EVENT_TABLES as readonly string[]).includes(b.table)) throw new Error("ERR_BAD_TABLE");
          // Trong số bảng sự kiện hợp lệ, vẫn cấm void bảng KIỂM SOÁT (ATTP/tài chính/truy xuất) — sửa sai đi qua
          // supersede/adjustment/quy trình chuyên trách (luật 2), không được set status='VOID' để lách control
          // (vd void đơn → xoá doanh thu; void lab KHÔNG ĐẠT → xoá bằng chứng).
          const PROTECTED = new Set(["sales","sales_returns","supplier_returns","expense_requests","approvals","approval_matrix","payroll_runs","salary_scales","bonus_ledger","loans","loan_schedule","insurance_claims","insurance_policies","lots","qc_holds","lab_samples","recalls","food_samples","certifications","compliance_gaps","customs_declarations","import_permits","trade_contracts","trade_documents","shipments","grade_reviews","staff_grades","whistle_reports","cross_checks","gs_omissions","production_orders","contracts","custody_contracts","stock_reservations","journal_entries","adjustments"]);
          if (PROTECTED.has(b.table)) throw new Error("ERR_PROTECTED_TABLE: bảng kiểm soát không được void — dùng quy trình chuyên trách (giải toả QC / điều chỉnh có duyệt / thu hồi / supersede)");
          await c.query(`update ${b.table} set status='VOID' where id=$1 and farm_id=$2`, [b.id, s.farmId]); return { ok: true };
};

export const ackNote: ActionHandler = async (c, s, b) => {
  await c.query("update shift_notes set ack_by=$2, ack_at=now() where id=$1", [b.id, s.staffId]); return { ok: true };
};

export const setGrid: ActionHandler = async (c, s, b) => {
  if (!["director","owner","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update locations set grid_x=$2, grid_y=$3 where id=$1 and farm_id=$4", [b.id, b.x, b.y, s.farmId]); return { ok: true };
};

export const saveAlertRule: ActionHandler = async (c, s, b) => {
  if (!["tech_head","director","owner","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const scope = b.scope === "GLOBAL" && ["owner","it_engineer"].includes(s.role) ? "GLOBAL" : s.farmId;
          const ver = Number((await c.query("select coalesce(max(version),0)+1 as v from alert_rules where code=$1 and farm_id=$2", [b.code, scope])).rows[0].v);
          await c.query("update alert_rules set active=false where code=$1 and farm_id=$2", [b.code, scope]);
          await c.query("insert into alert_rules(code,version,farm_id,name,source,expr,level,recipients,channels,sop_code,cooldown_min,active,updated_by,reason,description,created_by) values ($1,$2,$3,$4,'custom',$5,$6,$7,$8,$9,$10,true,$11,$12,$13,$11)",
            [b.code, ver, scope, b.name, JSON.stringify(b.expr ?? {}), b.level ?? "VANG", b.recipients ?? ["tech_head"], b.channels ?? ["app"], b.sop_code ?? null, b.cooldown_min ?? 720, s.staffId, b.reason ?? "cấu hình qua UI", b.description ?? null]);
          return { ok: true, version: ver };
};

export const toggleAlertRule: ActionHandler = async (c, s, b) => {
  if (!["tech_head","director","owner","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update alert_rules set active=$3, updated_by=$4, updated_at=now() where code=$1 and version=$2", [b.code, b.version, !!b.active, s.staffId]); return { ok: true };
};

export const runRulesNow: ActionHandler = async (c, s) => {
  const { runCustomRules, dispatchEvents } = await import("@/lib/notify"); const f = await runCustomRules(s.farmId); const n = await dispatchEvents(); return { ok: true, fired: f, notified: n };
};

export const setSetting: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const scope = b.scope === "GLOBAL" && ["owner","it_engineer"].includes(s.role) ? "GLOBAL" : s.farmId; const v = Number((await c.query("select coalesce(max(version),0)+1 as v from settings where farm_id=$1 and key=$2", [scope, b.key])).rows[0].v); await c.query("insert into settings(farm_id,key,value,version,updated_by) values ($1,$2,$3,$4,$5)", [scope, b.key, JSON.stringify(b.value), v, s.staffId]); return { ok: true, version: v };
};

export const setNorm: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into norms(id,org_id,farm_id,kind,subject,value,unit,note) values ($1,$2,$3,$4,$5,$6,$7,$8) on conflict (id) do update set value=excluded.value, unit=excluded.unit, note=excluded.note", [b.id ?? `N-${b.kind}-${b.subject}-${s.farmId}`, s.orgId, b.scope === "GLOBAL" ? null : s.farmId, b.kind, b.subject ?? null, b.value, b.unit ?? null, b.note ?? null]); return { ok: true };
};

export const ackSop: ActionHandler = async (c, s, b) => {
  await c.query("select ack_sop($1,$2,$3,$4,$5)", [s.farmId, b.sop_code, s.staffId, b.kind ?? "DOC_HIEU", b.score == null ? null : Number(b.score)]); return { ok: true };
};

