import type { PoolClient } from "pg";
import type { Session } from "@/lib/auth";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type B = any;
export type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;

export const digitizePaper: ActionHandler = async (c, s, b) => {
  await c.query("update paper_scans set digitized=true, digitized_by=$2, digitized_ts=now(), linked_ids=coalesce(linked_ids,'[]'::jsonb)||$3::jsonb where id=$1", [b.id, s.staffId, JSON.stringify(b.linked_ids ?? [])]);
          return { ok: true };
};

export const approveChecklist: ActionHandler = async (c, s, b) => {
  if (!["team_lead","tech_head","director"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const r = (await c.query("select created_by from checklist_runs where id=$1", [b.id])).rows[0];
          if (r?.created_by === s.staffId) throw new Error("ERR_SELF_APPROVE");
          await c.query("update checklist_runs set approved_by=$2, approved_at=now() where id=$1", [b.id, s.staffId]); return { ok: true };
};

export const shiftNote: ActionHandler = async (c, s, b) => {
  const r = await c.query("insert into shift_notes(farm_id,created_by,dept,shift,note,target_type,target_id) values ($1,$2,$3,$4,$5,$6,$7) returning id", [s.farmId, s.staffId, b.dept ?? null, b.shift ?? null, b.note, b.target_type ?? null, b.target_id ?? null]);
          if (b.make_task) await c.query("insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,due_at,priority,source,rule_code,handover_note) values ($1,'GIAO_CA',$2,$3,$4,$5,now()+interval '8 hours','CAO','HANDOVER',$6,$2)", [s.farmId, b.note, b.target_type ?? null, b.target_id ?? null, b.role_hint ?? null, "HO-" + r.rows[0].id]);
          return { ok: true, id: r.rows[0].id };
};

export const closeCycle: ActionHandler = async (c, s, b) => {
  if (!["team_lead","tech_head","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const cy = (await c.query("select * from cycles where id=$1 and farm_id=$2", [b.id, s.farmId])).rows[0]; if (!cy) throw new Error("ERR_NOT_FOUND");
          const sum = (await c.query(`select
            (select coalesce(sum(qty_kg),0) from feed_logs where farm_id=$1 and status='ACTIVE' and dest_group_id=$2 and ts::date between $3 and current_date) as feed_kg,
            (select coalesce(sum(value),0) from animal_events where farm_id=$1 and status='ACTIVE' and group_id=$2 and event_type='CHET') as deaths,
            (select coalesce(sum(qty_kg),0) from crop_logs where farm_id=$1 and status='ACTIVE' and plot_id=$4 and activity in ('THU','CAT') and ts::date between $3 and current_date) as harvest_kg`, [s.farmId, cy.group_id, cy.start_date, cy.plot_id])).rows[0];
          await c.query("update cycles set status='DONG', end_date=current_date, closed_by=$2, closed_at=now(), summary=$3 where id=$1", [b.id, s.staffId, JSON.stringify(sum)]);
          return { ok: true, summary: sum };
};

export const openCycle: ActionHandler = async (c, s, b) => {
  const id = `${b.group_id ?? b.plot_id}-${b.kind}${new Date().toISOString().slice(2, 10).replace(/-/g, "")}`;
          await c.query("insert into cycles(id,farm_id,kind,name,group_id,plot_id,start_date) values ($1,$2,$3,$4,$5,$6,current_date)", [id, s.farmId, b.kind ?? "KHAC", b.name ?? id, b.group_id ?? null, b.plot_id ?? null]);
          if (b.group_id) await c.query("update animal_groups set cycle_id=$2 where id=$1", [b.group_id, id]); if (b.plot_id) await c.query("update plots set cycle_id=$2 where id=$1", [b.plot_id, id]);
          return { ok: true, id };
};

export const addSeasonPlan: ActionHandler = async (c, s, b) => {
  await c.query("insert into season_plans(farm_id,cycle_id,plot_id,crop,variety,sow_date,harvest_date,plan_yield_kg,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9)", [s.farmId, b.cycle_id ?? null, b.plot_id, b.crop, b.variety ?? null, b.sow_date ?? null, b.harvest_date ?? null, b.plan_yield_kg ?? null, s.staffId]); return { ok: true };
};

export const bulkApproveChecklists: ActionHandler = async (c, s) => {
  if (!["team_lead","tech_head","director"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const r = await c.query("update checklist_runs set approved_by=$2, approved_at=now() where farm_id=$1 and approved_by is null and all_green and created_by<>$2 and ts::date=current_date returning id", [s.farmId, s.staffId]); return { ok: true, n: r.rowCount };
};

export const genMonitoring: ActionHandler = async (c, s) => {
  const r = await c.query("select gen_monitoring_tasks($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n };
};

export const initiative: ActionHandler = async (c, s, b) => {
  await c.query("insert into initiatives(farm_id,staff_id,title,benefit,description,kind) values ($1,$2,$3,$4,$5,$6)", [s.farmId, s.staffId, b.title, b.benefit ?? null, b.description ?? null, b.kind ?? "CAI_TIEN"]); return { ok: true };
};

export const approveInitiative: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","team_lead","auditor"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update initiatives set status='DUYET', approved_by=$3, approved_at=now() where id=$1 and farm_id=$2 and staff_id<>$3", [b.id, s.farmId, s.staffId]); return { ok: true };
};

export const closePlan: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select close_plan($1) as n", [b.id]); return { ok: true, n: r.rows[0].n };
};

