import { z } from "zod";

/** Validate body của POST /api/actions THEO ACTION — cùng phong cách EVENT_SCHEMAS (lib/events.ts).
 *  Action CHƯA có schema ở đây thì bỏ qua validate (route.ts giữ nguyên hành vi cũ, không chặn) —
 *  cho phép thêm dần theo domain, không phải làm hết 147 action trong 1 lần mới an toàn deploy.
 *  Chỉ validate HÌNH DẠNG dữ liệu đầu vào (đủ field/đúng kiểu) — KHÔNG thêm luật nghiệp vụ mới
 *  (role/limit vẫn nằm trong handler như cũ) và KHÔNG siết chặt hơn hành vi hiện có (vd bankMatch
 *  không có sale_id lẫn expense_id vẫn qua được như code gốc — đó là hành vi cũ, không phải bug ở đây).
 */
const num = z.coerce.number();
const dateStr = z.string().min(8); // "YYYY-MM-DD" hoặc tương đương — cột đích tự ép ::date ở SQL

export const ACTION_SCHEMAS: Record<string, z.ZodTypeAny> = {
  // ===== ke_toan (tài chính — ưu tiên cao nhất vì liên quan tiền) =====
  create_expense: z.object({ amount: num.positive(), cost_center: z.string().nullable().optional(), purpose: z.string().min(1), po_id: z.string().nullable().optional() }),
  approve_expense: z.object({ id: z.string().min(1), approve: z.boolean() }),
  lock_period: z.object({ period_end: dateStr, note: z.string().nullable().optional() }),
  add_fixed_cost: z.object({ month: dateStr, cost_center: z.string().min(1), kind: z.string().min(1), amount: num, note: z.string().nullable().optional() }),
  compute_kpi: z.object({ month: dateStr.nullable().optional() }),
  import_bank_lines: z.object({ lines: z.array(z.object({
    bank: z.string().nullable().optional(), account: z.string().nullable().optional(), txn_date: dateStr,
    amount: num, direction: z.enum(["IN", "OUT"]).nullable().optional(), ref: z.string().nullable().optional(), memo: z.string().nullable().optional(),
  })).default([]) }),
  bank_reconcile: z.object({ id: z.string().min(1), reconciled: z.boolean().optional() }),
  bank_match: z.object({ id: z.string().min(1), sale_id: z.string().nullable().optional(), expense_id: z.string().nullable().optional() }),
  close_contribution_bonus: z.object({ quarter: z.string().min(1) }),
  close_bonus: z.object({ period: z.string().min(1) }),
  apply_bonus: z.object({ month: dateStr }),
  set_assumption: z.object({ key: z.string().min(1), value: num.nullable().optional(), unit: z.string().nullable().optional(), note: z.string().nullable().optional() }),
  pay_supplier: z.object({ id: z.string().min(1), amount: num.positive(), ref: z.string().nullable().optional() }),
  gen_loan_schedule: z.object({ id: z.string().min(1) }),
  pay_loan: z.object({ id: z.string().min(1), ref: z.string().nullable().optional() }),
  receive_claim: z.object({ id: z.string().min(1), amount: num.positive() }),
  compute_payroll: z.object({ month: dateStr }),
  approve_payroll: z.object({ run_id: z.string().min(1) }),
  run_depreciation: z.object({ month: dateStr.nullable().optional() }),
};
