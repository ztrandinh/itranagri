import type { PoolClient } from "pg";
import type { Session } from "@/lib/auth";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type B = any;
export type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;

export const planGsRotation: ActionHandler = async (c, s) => {
  if (!["owner","director","auditor","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select plan_gs_rotation($1, current_date, $2) as n", [s.farmId, s.staffId]); return { ok: true, n: r.rows[0].n };
};

export const gsFieldDay: ActionHandler = async (c, s, b) => {
  await c.query("insert into gs_field_days(farm_id,supervisor_id,day,block,dept,note) values ($1,$2,coalesce($3::date,current_date),$4,$5,$6) on conflict (supervisor_id,day) do update set block=excluded.block, dept=excluded.dept, note=excluded.note", [s.farmId, s.staffId, b.day ?? null, b.block ?? null, b.dept ?? null, b.note ?? null]); return { ok: true };
};

export const rateSupervisor: ActionHandler = async (c, s, b) => {
  if (!["tech_head","team_lead","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into supervisor_ratings(farm_id,supervisor_id,rated_by,period,useful,fair,knows,note) values ($1,$2,$3,to_char(current_date,'YYYY-MM'),$4,$5,$6,$7) on conflict (supervisor_id,rated_by,period) do update set useful=excluded.useful, fair=excluded.fair, knows=excluded.knows, note=excluded.note", [s.farmId, b.supervisor_id, s.staffId, Number(b.useful), Number(b.fair), Number(b.knows), b.note ?? null]); return { ok: true };
};

export const capaSet: ActionHandler = async (c, s, b) => {
  await c.query("update supervision_checks set corrective=$3, corrective_due=$4::date where id=$1 and farm_id=$2", [b.id, s.farmId, b.corrective, b.due ?? null]); return { ok: true };
};

export const capaVerify: ActionHandler = async (c, s, b) => {
  await c.query("update supervision_checks set verified_by=$3, verified_at=now() where id=$1 and farm_id=$2 and supervisor_id<>$3 or (id=$1 and farm_id=$2 and $4 in ('auditor','director','owner'))", [b.id, s.farmId, s.staffId, s.role]); return { ok: true };
};

export const genCapa: ActionHandler = async (c, s) => {
  const r = await c.query("select gen_capa_tasks($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n };
};

export const gsAck: ActionHandler = async (c, s, b) => {
  // GS đã xem lỗi hệ thống báo, kết luận (không lỗi / có lỗi) — tính là đã xử lý, hết bỏ sót
          const res = b.result === "LOI" ? "LOI" : "DAT"; const note = (res === "DAT" ? "[đã xem auto] " : "[từ dữ liệu auto] ") + String(b.note ?? "");
          const r = await c.query("insert into supervision_checks(farm_id, created_by, client_ref, supervisor_id, target_staff_id, criteria_id, week_start, item, result, severity, note) values ($1,$2,$3,$2,$4,$5,date_trunc('week', current_date)::date,$6,$7,$8,$9) returning id, points", [s.farmId, s.staffId, crypto.randomUUID(), b.staff_id, b.criteria_id, b.item ?? "auto", res, res === "LOI" ? (b.severity ?? "TRUNG") : null, note]); return { ok: true, ...r.rows[0] };
};

export const genGsOmissions: ActionHandler = async (c, s, b) => {
  if (!["owner","director","auditor","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select gen_gs_omissions($1, coalesce($2::date, current_date-1)) as n", [s.farmId, b.day ?? null]); return { ok: true, n: r.rows[0].n };
};

export const crossCheckSubmit: ActionHandler = async (c, s, b) => {
  const r = await c.query("select submit_cross_check($1::uuid,$2,$3,$4,$5) as j", [b.id, s.staffId, b.result, b.note ?? null, b.evidence_url ?? null]); return { ok: true, ...r.rows[0].j };
};

export const genCrossChecks: ActionHandler = async (c, s) => {
  if (!["owner","director","auditor","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const a = await c.query("select gen_cross_checks($1) as n", [s.farmId]); const b2 = await c.query("select gen_random_spot_checks($1) as n", [s.farmId]); const c2 = await c.query("select gen_collusion_audits($1) as n", [s.farmId]); return { ok: true, cross: a.rows[0].n, spots: b2.rows[0].n, audits: c2.rows[0].n };
};

export const whistle: ActionHandler = async (c, s, b) => {
  const r = await c.query("select whistle_submit($1,$2,$3,$4,$5) as id", [s.farmId, b.category ?? "KHAC", b.target_dept ?? null, b.content, s.staffId]); return { ok: true, id: r.rows[0].id };
};

export const whistleHandle: ActionHandler = async (c, s, b) => {
  if (!["owner","director"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update whistle_reports set status=$3, handled_by=$4, handled_at=now(), note=$5 where id=$1 and farm_id=$2", [b.id, s.farmId, b.status, s.staffId, b.note ?? null]); return { ok: true };
};

export const supCheck: ActionHandler = async (c, s, b) => {
  const r = await c.query("insert into supervision_checks(farm_id, created_by, client_ref, supervisor_id, target_dept, target_staff_id, sop_code, criteria_id, week_start, item, result, severity, note, evidence_url, corrective, corrective_due) values ($1,$2,$3,$2,$4,$5,$6,$7,date_trunc('week', current_date)::date,$8,$9,$10,$11,$12,$13,$14) returning id, points", [s.farmId, s.staffId, b.client_ref ?? crypto.randomUUID(), b.target_dept ?? null, b.target_staff_id ?? null, b.sop_code ?? null, b.criteria_id ?? null, b.item, b.result, b.severity ?? null, b.note ?? null, b.evidence_url ?? null, b.corrective ?? null, b.corrective_due ?? null]); await c.query("select run_supervision_auto($1, date_trunc('week', current_date)::date)", [s.farmId]).catch(() => null); return { ok: true, ...r.rows[0] };
};

export const runSupervision: ActionHandler = async (c, s, b) => {
  const r = await c.query("select run_supervision_auto($1, coalesce($2::date, date_trunc('week', current_date)::date)) as n", [s.farmId, b.week ?? null]); return { ok: true, n: r.rows[0].n };
};

