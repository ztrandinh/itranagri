import type { PoolClient } from "pg";
import type { Session } from "@/lib/auth";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type B = any;
export type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;

export const changePin: ActionHandler = async (c, s, b) => {
  // Chính sách PIN: công nhân ≥4 số; quản lý/kế toán/IT/chủ ≥6 số; không trùng 1234/0000/1111…; không trùng PIN cũ
          const np = String(b.new_pin); const minLen = ["owner","director","accountant","it_engineer","auditor","tech_head"].includes(s.role) ? 6 : 4;
          if (!new RegExp(`^\\d{${minLen},8}$`).test(np)) throw new Error(`ERR_PIN_FORMAT: PIN phải ${minLen}–8 chữ số`);
          if (/^(\d)\1+$/.test(np) || ["1234","123456","12345678","0000","1111","4321","654321"].includes(np)) throw new Error("ERR_PIN_WEAK: PIN quá dễ đoán");
          if (String(b.old_pin) === np) throw new Error("ERR_PIN_SAME");
          const ok = (await c.query("select (pin_hash = crypt($2, pin_hash)) as ok from staff where id=$1", [s.staffId, String(b.old_pin)])).rows[0]?.ok;
          if (!ok) throw new Error("ERR_BAD_CREDENTIALS");
          await c.query("update staff set pin_hash=crypt($2, gen_salt('bf')), pin_changed_at=now(), must_change_pin=false where id=$1", [s.staffId, np]); return { ok: true };
};

export const revokeSessions: ActionHandler = async (c, s, b) => {
  if (!["director", "owner", "it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("update sessions set revoked_at=now() where staff_id=$1 and revoked_at is null", [b.staff_id]); return { ok: true };
};

export const updateStaff: ActionHandler = async (c, s, b) => {
  if (!["director","owner","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("update staff set sop_certs=coalesce($2::jsonb,sop_certs), health_check_due=coalesce($3::date,health_check_due), food_safety_training_due=coalesce($4::date,food_safety_training_due), active=coalesce($5,active) where id=$1", [b.staff_id, b.sop_certs ? JSON.stringify(b.sop_certs) : null, b.health_check_due ?? null, b.food_safety_training_due ?? null, b.active ?? null]); return { ok: true };
};

export const assignStaffFarm: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update staff set farm_id=coalesce($2,farm_id), farm_ids=(select array_agg(distinct x) from unnest(array_append(coalesce(farm_ids,'{}'),$3)) x) where id=$1", [b.staff_id, b.farm_id ?? null, b.add_farm_id ?? b.farm_id]); return { ok: true };
};

export const createStaff: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const id = (await c.query("select next_code($1,'NS',3) as c", [s.orgId])).rows[0].c.replace(s.orgId + "-", "");
          // Không đặt PIN mặc định "1234" mà không ép đổi (như reset_pin đã làm đúng) — tài khoản mới
          // dùng PIN mặc định công khai sẽ bị đánh dấu phải đổi ngay khi đăng nhập lần đầu.
          const usedDefault = b.pin == null;
          await c.query("insert into staff(id,org_id,farm_id,full_name,role,dept,position,phone,login,pin_hash,farm_ids,must_change_pin) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,crypt($10,gen_salt('bf')),$11,$12)", [id, s.orgId, b.farm_id ?? s.farmId, b.full_name, b.role ?? "worker", b.dept ?? null, b.position ?? null, b.phone ?? null, b.login, String(b.pin ?? "1234"), [b.farm_id ?? s.farmId], usedDefault]);
          return { ok: true, id };
};

export const unlockStaff: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update staff set locked_until=null where id=$1", [b.staff_id]); await c.query("delete from login_attempts where login in (select login from staff where id=$1)", [b.staff_id]); return { ok: true };
};

export const resetPin: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const tmp = String(Math.floor(100000 + Math.random() * 900000)); await c.query("update staff set pin_hash=crypt($2, gen_salt('bf')), must_change_pin=true, locked_until=null where id=$1", [b.staff_id, tmp]); await c.query("update sessions set revoked_at=now() where staff_id=$1 and revoked_at is null", [b.staff_id]); return { ok: true, temp_pin: tmp, note: "PIN tạm — nhân viên phải đổi ngay khi đăng nhập" };
};

export const runGradeReview: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select run_grade_review($1,$2) as n", [s.farmId, b.quarter]); return { ok: true, n: r.rows[0].n };
};

export const signGrade: ActionHandler = async (c, s, b) => {
  const r = await c.query("select sign_grade_review($1::uuid,$2,$3) as j", [b.id, s.staffId, b.slot]); return { ok: true, ...r.rows[0].j };
};

export const rejectGrade: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","team_lead","accountant"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update grade_reviews set status='TU_CHOI', note=$3, decided_at=now() where id=$1 and farm_id=$2 and staff_id<>$4", [b.id, s.farmId, b.note ?? null, s.staffId]); return { ok: true };
};

export const appealGrade: ActionHandler = async (c, s, b) => {
  await c.query("update grade_reviews set status='KHANG_NGHI', appeal_note=$3 where id=$1 and farm_id=$2 and staff_id=$4", [b.id, s.farmId, b.note ?? null, s.staffId]); return { ok: true };
};

export const keyPosition: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into key_positions(farm_id,code,title,dept,holder_id,min_grade,track) values ($1,$2,$3,$4,nullif($5,''),$6,$7) on conflict (farm_id,code,year) do update set title=excluded.title, dept=excluded.dept, holder_id=excluded.holder_id, min_grade=excluded.min_grade, track=excluded.track", [s.farmId, b.code, b.title, b.dept ?? null, b.holder_id ?? "", b.min_grade ?? "B3", b.track ?? "CM"]); return { ok: true };
};

export const succession: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer","tech_head"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into succession_plans(farm_id,key_position_id,successor_id,readiness,dev_plan,updated_by) values ($1,$2,$3,$4,$5,$6) on conflict (key_position_id,successor_id) do update set readiness=excluded.readiness, dev_plan=excluded.dev_plan, updated_at=now(), updated_by=excluded.updated_by", [s.farmId, b.key_position_id, b.successor_id, b.readiness ?? "2_NAM", b.dev_plan ?? null, s.staffId]); return { ok: true };
};

export const dependentClaim: ActionHandler = async (c, s, b) => {
  const n = Number(b.dependents); if (!(n >= 0 && n <= 20)) throw new Error("ERR_VALUE"); await c.query("insert into dependent_claims(farm_id,staff_id,dependents,note) values ($1,$2,$3,$4)", [s.farmId, s.staffId, n, b.note ?? null]); await c.query("insert into notifications(farm_id,staff_id,level,title,body,link,source) select $1, id, 'INFO', $2, $3, '/nhan-su?tab=bac', 'dependent' from staff where farm_id=$1 and dept='HCNS' and active limit 2", [s.farmId, `Khai người phụ thuộc: ${s.staffName} → ${n}`, String(b.note ?? "")]); return { ok: true };
};

export const dependentDecide: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("update dependent_claims set status=$3, decided_by=$4, decided_at=now() where id=$1 and farm_id=$2 and staff_id<>$4 returning staff_id, dependents", [b.id, s.farmId, b.approve ? "DUYET" : "TU_CHOI", s.staffId]); if (b.approve && r.rows[0]) await c.query("update staff set dependents=$2 where id=$1", [r.rows[0].staff_id, r.rows[0].dependents]); return { ok: true };
};

export const suggestHeadcount: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select suggest_headcount($1,$2,$3) as n", [s.farmId, Number(b.year ?? new Date().getFullYear()), s.staffId]); return { ok: true, n: r.rows[0].n };
};

export const headcountSet: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update headcount_plans set planned=$3, budget_month=$4 where id=$1 and farm_id=$2", [b.id, s.farmId, Number(b.planned), b.budget_month == null ? null : Number(b.budget_month)]); return { ok: true };
};

export const delegate: ActionHandler = async (c, s, b) => {
  // ủy quyền thủ công (công tác/đi vắng): from mặc định = tôi
          if (!b.to || !b.from_date || !b.to_date) throw new Error("ERR_MISSING");
          const from = b.from && ["owner", "director", "tech_head", "team_lead"].includes(s.role) ? String(b.from) : s.staffId;
          if (from === b.to) throw new Error("ERR_SELF");
          const r = await c.query("select activate_delegation($1,$2,$3,$4::date,$5::date,$6,'MANUAL',null,$7) as id", [s.farmId, from, b.to, b.from_date, b.to_date, b.reason ?? "Ủy quyền", s.staffId]);
          return { ok: true, id: r.rows[0].id };
};

export const endDelegation: ActionHandler = async (c, s, b) => {
  await c.query("update staff_delegations set status='CANCELLED', ended_at=now(), to_date=least(to_date, current_date-1) where id=$1 and farm_id=$2 and status='ACTIVE' and (from_staff=$3 or to_staff=$3 or $4 in ('owner','director','tech_head','team_lead'))", [b.id, s.farmId, s.staffId, s.role]);
          await c.query("update tasks set assignee_id=detail->>'delegated_from', detail=detail - 'delegated_from' where farm_id=$1 and status in ('MO','DANG_LAM','TREO') and detail->>'delegation_id'=$2", [s.farmId, b.id]);
          return { ok: true };
};

export const completeTraining: ActionHandler = async (c, s, b) => {
  const r = await c.query("select complete_training($1,$2,$3,$4,$5) as j", [b.id, Number(b.hours ?? 2), Number(b.score ?? 0), b.examiner_id ?? null, b.notes ?? null]); return { ok: true, ...r.rows[0].j };
};

export const genTrainingWeek: ActionHandler = async (c, s) => {
  if (!["owner","director","tech_head","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select gen_training_week($1) as n", [s.farmId]); const r2 = await c.query("select gen_supervision_tasks($1) as n", [s.farmId]); return { ok: true, training: r.rows[0].n, supervision: r2.rows[0].n };
};

