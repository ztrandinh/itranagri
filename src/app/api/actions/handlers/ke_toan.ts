import type { PoolClient } from "pg";
import type { Session } from "@/lib/auth";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type B = any;
export type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;

export const createExpense: ActionHandler = async (c, s, b) => {
  const id = (await c.query("select next_code($1,'DNC',4) as c", [s.farmId])).rows[0].c;
          await c.query("insert into expense_requests(id,farm_id,requested_by,amount,cost_center,purpose,po_id) values ($1,$2,$3,$4,$5,$6,$7)", [id, s.farmId, s.staffId, b.amount, b.cost_center ?? null, b.purpose, b.po_id ?? null]);
          return { ok: true, id };
};

export const approveExpense: ActionHandler = async (c, s, b) => {
  const e = (await c.query("select * from expense_requests where id=$1", [b.id])).rows[0];
          if (!e) throw new Error("ERR_NOT_FOUND");
          if (e.requested_by === s.staffId) throw new Error("ERR_SELF_APPROVE");
          const amt = Number(e.amount);
          // Ma trận ủy quyền = dữ liệu (approval_matrix): hạn mức theo vai, ngưỡng 2 chữ ký, ngưỡng báo chủ — sửa ở /quan-tri?t=approval_matrix, không sửa code
          const am = (await c.query("select * from approval_limit('CHI',$1,$2)", [s.role, s.farmId])).rows[0];
          const roleMax = am ? (am.max_amount == null ? Infinity : Number(am.max_amount)) : 0; const twoOver = Number(am?.two_sign_over ?? 2e7); const ownerOver = Number(am?.notify_owner_over ?? 5e7);
          if (!b.approve) { await c.query("update expense_requests set status='TU_CHOI', approver1=$2, approved1_at=now() where id=$1", [b.id, s.staffId]); return { ok: true, status: "TU_CHOI" }; }
          if (amt > roleMax) throw new Error("ERR_OVER_LIMIT");
          const needTwo = amt > twoOver;
          if (needTwo && e.status === "CHO_DUYET") { await c.query("update expense_requests set status='DUYET_1', approver1=$2, approved1_at=now() where id=$1", [b.id, s.staffId]); return { ok: true, status: "DUYET_1", note: "Cần chữ ký thứ 2 (>20 triệu)" }; }
          if (needTwo && e.status === "DUYET_1") { if (e.approver1 === s.staffId) throw new Error("ERR_SAME_SIGNER"); await c.query("update expense_requests set status='DUYET', approver2=$2, approved2_at=now(), owner_notified_at=case when amount>$3 then now() else null end where id=$1", [b.id, s.staffId, ownerOver]); return { ok: true, status: "DUYET", sms_owner: amt > 5e7 }; }
          await c.query("update expense_requests set status='DUYET', approver1=$2, approved1_at=now() where id=$1", [b.id, s.staffId]); return { ok: true, status: "DUYET" };
};

export const lockPeriod: ActionHandler = async (c, s, b) => {
  if (!["director","owner","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("insert into period_locks(farm_id,period_end,locked_by,note) values ($1,$2,$3,$4) on conflict do nothing", [s.farmId, b.period_end, s.staffId, b.note ?? null]); return { ok: true };
};

export const addFixedCost: ActionHandler = async (c, s, b) => {
  if (!["accountant","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("insert into cc_fixed_costs(farm_id,month,cost_center,kind,amount,note,created_by) values ($1,$2,$3,$4,$5,$6,$7) on conflict (farm_id,month,cost_center,kind) do update set amount=excluded.amount, note=excluded.note", [s.farmId, b.month, b.cost_center, b.kind, b.amount, b.note ?? null, s.staffId]); return { ok: true };
};

export const computeKpi: ActionHandler = async (c, s, b) => {
  const r = await c.query("select compute_staff_kpi($1, coalesce($2::date, date_trunc('month', now())::date)) as n", [s.farmId, b.month ?? null]); return { ok: true, n: r.rows[0].n };
};

export const importBankLines: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const lines = (b.lines ?? []) as Record<string, unknown>[]; const batch = `bank-${Date.now().toString(36)}`; let n = 0; for (const ln of lines) { await c.query("select import_bank_line($1,$2,$3,$4::date,$5,$6,$7,$8,$9,$10)", [s.farmId, ln.bank ?? "NH", ln.account ?? "", ln.txn_date, Number(ln.amount), ln.direction ?? (Number(ln.amount) >= 0 ? "IN" : "OUT"), ln.ref ?? null, ln.memo ?? null, batch, s.staffId]); n++; } const m = await c.query("select auto_match_bank($1) as n", [s.farmId]); return { ok: true, imported: n, matched: m.rows[0].n };
};

export const bankReconcile: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update bank_statement_lines set reconciled=$3, reconciled_by=$4 where id=$1 and farm_id=$2", [b.id, s.farmId, b.reconciled !== false, s.staffId]); return { ok: true };
};

export const bankMatch: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); if (b.sale_id) await c.query("update bank_statement_lines set matched_sale_id=$3::uuid, matched_kind='SALE' where id=$1 and farm_id=$2", [b.id, s.farmId, b.sale_id]); else if (b.expense_id) await c.query("update bank_statement_lines set matched_expense_id=$3, matched_kind='EXPENSE' where id=$1 and farm_id=$2", [b.id, s.farmId, b.expense_id]); return { ok: true };
};

export const closeContributionBonus: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select close_contribution_bonus($1,$2,$3) as n", [s.farmId, b.quarter, s.staffId]); return { ok: true, n: r.rows[0].n };
};

export const closeBonus: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select close_bonus($1,$2) as n", [s.farmId, b.period]); return { ok: true, n: r.rows[0].n };
};

export const applyBonus: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select apply_bonus_to_payroll($1,$2::date) as n", [s.farmId, b.month]); return { ok: true, n: r.rows[0].n };
};

export const computeAssumptions: ActionHandler = async (c, s) => {
  const r = await c.query("select compute_assumptions($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n };
};

export const setAssumption: ActionHandler = async (c, s, b) => {
  if (!["owner","director","tech_head","accountant","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into plan_assumptions(farm_id, key, value, unit, source, note) values ($1,$2,$3,$4,'MANUAL',$5) on conflict (farm_id, key) do update set value=excluded.value, source=case when $3 is null then 'AUTO' else 'MANUAL' end, note=excluded.note, computed_at=now()", [s.farmId, b.key, b.value ?? null, b.unit ?? null, b.note ?? null]); if (b.value == null) await c.query("select compute_assumptions($1)", [s.farmId]); return { ok: true };
};

export const paySupplier: ActionHandler = async (c, s, b) => {
  if (!["director","owner","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select pay_supplier($1,$2,$3)", [b.id, Number(b.amount), b.ref ?? null]); return { ok: true };
};

export const genLoanSchedule: ActionHandler = async (c, s, b) => {
  const r = await c.query("select gen_loan_schedule($1) as n", [b.id]); return { ok: true, n: r.rows[0].n };
};

export const payLoan: ActionHandler = async (c, s, b) => {
  if (!["director","owner","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select pay_loan_installment($1,$2)", [b.id, b.ref ?? null]); return { ok: true };
};

export const receiveClaim: ActionHandler = async (c, s, b) => {
  if (!["director","owner","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select receive_claim($1,$2)", [b.id, Number(b.amount)]); return { ok: true };
};

export const runDunning: ActionHandler = async (c, s) => {
  if (!["director","owner","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select run_dunning($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n };
};

export const computePayroll: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select compute_payroll($1,$2::date,$3) as id", [s.farmId, b.month, s.staffId]); return { ok: true, run_id: r.rows[0].id };
};

export const approvePayroll: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select approve_payroll($1,$2)", [b.run_id, s.staffId]); return { ok: true };
};

export const runDepreciation: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select run_depreciation($1, date_trunc('month', coalesce($2::date, now()))::date) as n", [s.farmId, b.month ?? null]); return { ok: true, n: r.rows[0].n };
};

