/** Phân quyền đọc theo VAI cho view nhạy cảm & trang: dữ liệu tài chính/lương/nhân sự chỉ vai quản lý/kế toán/kiểm toán; công nhân chỉ thấy phần vận hành liên quan */
export const FIN_ROLES = ["owner", "director", "accountant", "auditor", "it_engineer"];
export const MGMT_ROLES = ["owner", "director", "tech_head", "accountant", "auditor", "it_engineer"];
// my_inbox / suggest_delegates / my_delegations: mọi vai (RLS + app_staff)
export const VIEW_ROLES: Record<string, string[]> = Object.fromEntries([
  ...["gl_trial_balance", "gl_journal", "gl_entries", "gl_by_entity", "consolidated", "pl_month", "pl_summary", "budget_vs_actual", "budgets", "cashflow_forecast", "ap_summary", "ap_aging", "ar_summary", "ar_aging_rows", "receivable_aging", "receivables", "loans", "loan_schedule", "insurance", "insurance_claims", "vat_summary", "payment_calendar", "legal_entities", "expense_requests", "funds", "period_locks", "dunning_log", "sales_performance", "approval_matrix", "recon_latest", "kpi_owner_weekly", "batch_cost"].map((v) => [v, FIN_ROLES]),
  ...["payroll", "payslips", "payroll_runs", "staff_salaries", "attendance_all", "leave_requests_all", "staff_list_full"].map((v) => [v, ["owner", "director", "accountant", "it_engineer"]]),
  ...["bonus_eval", "bonus_ledger", "competency_matrix", "supervision_weekly", "supervision_dept_weekly", "supervision_week", "supervision_checks_recent", "supervision_targets"].map((v) => [v, [...MGMT_ROLES, "team_lead"]]),
  ...["supplier_scorecard", "po_list", "po_all", "po_suggest", "purchases_month", "mrp_run", "plan_scenarios", "plan_supply", "plan_lines", "replenishment", "abc_suggest"].map((v) => [v, [...MGMT_ROLES, "team_lead", "worker"]]),
]);
export const PAGE_ROLES: Record<string, string[]> = {
  "/ke-toan": FIN_ROLES, "/hq": ["owner", "director", "auditor", "it_engineer", "accountant"], "/nhan-su": ["owner", "director", "accountant", "it_engineer", "tech_head", "team_lead"],
  "/quan-tri": ["owner", "director", "it_engineer", "tech_head", "accountant", "auditor", "team_lead"], "/audit": ["owner", "director", "auditor", "it_engineer", "accountant"], "/doi-soat": ["owner", "director", "auditor", "it_engineer", "accountant", "tech_head"],
  "/gd": ["owner", "director", "auditor", "it_engineer"], "/xnk": MGMT_ROLES, "/rd": MGMT_ROLES, "/nhan-rong": ["owner", "director", "it_engineer"], "/mua-hang": [...MGMT_ROLES, "team_lead", "worker"], "/giam-sat": [...MGMT_ROLES, "team_lead", "worker"],
};
export const _x = 0;
export function canView(view: string, role: string) { const r = VIEW_ROLES[view]; return !r || r.includes(role); }
export function canPage(path: string, role: string) { const r = PAGE_ROLES[path]; return !r || r.includes(role); }
