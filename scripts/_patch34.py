import io, os
R="F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R+p) or R, exist_ok=True); io.open(R+p,"w",encoding="utf-8",newline="\n").write(s); print("w",p)
def rw(p, fn): s=io.open(R+p,encoding="utf-8").read(); n=fn(s); assert n!=s, p; io.open(R+p,"w",encoding="utf-8",newline="\n").write(n); print("ok",p)
# F2a: role gate cho view nhạy cảm (tài chính/lương/nhân sự) — data API
w("src/lib/roles.ts", '''/** Phân quyền đọc theo VAI cho view nhạy cảm & trang: dữ liệu tài chính/lương/nhân sự chỉ vai quản lý/kế toán/kiểm toán; công nhân chỉ thấy phần vận hành liên quan */
export const FIN_ROLES = ["owner", "director", "accountant", "auditor", "it_engineer"];
export const MGMT_ROLES = ["owner", "director", "tech_head", "accountant", "auditor", "it_engineer"];
export const VIEW_ROLES: Record<string, string[]> = Object.fromEntries([
  ...["gl_trial_balance", "gl_journal", "gl_entries", "gl_by_entity", "consolidated", "pl_month", "pl_summary", "budget_vs_actual", "budgets", "cashflow_forecast", "ap_summary", "ap_aging", "ar_summary", "ar_aging_rows", "receivable_aging", "receivables", "loans", "loan_schedule", "insurance", "insurance_claims", "vat_summary", "payment_calendar", "legal_entities", "expense_requests", "funds", "period_locks", "dunning_log", "sales_performance", "approval_matrix", "recon_latest", "kpi_owner_weekly", "batch_cost"].map((v) => [v, FIN_ROLES]),
  ...["payroll", "payslips", "payroll_runs", "staff_salaries", "attendance_all", "leave_requests_all", "staff_list_full"].map((v) => [v, ["owner", "director", "accountant", "it_engineer"]]),
  ...["supplier_scorecard", "po_list", "po_all", "po_suggest", "purchases_month", "mrp_run", "plan_scenarios", "plan_supply", "plan_lines", "replenishment", "abc_suggest"].map((v) => [v, [...MGMT_ROLES, "team_lead", "worker"]]),
]);
export const PAGE_ROLES: Record<string, string[]> = {
  "/ke-toan": FIN_ROLES, "/hq": ["owner", "director", "auditor", "it_engineer", "accountant"], "/nhan-su": ["owner", "director", "accountant", "it_engineer", "tech_head", "team_lead"],
  "/quan-tri": ["owner", "director", "it_engineer", "tech_head", "accountant", "auditor", "team_lead"], "/audit": ["owner", "director", "auditor", "it_engineer", "accountant"], "/doi-soat": ["owner", "director", "auditor", "it_engineer", "accountant", "tech_head"],
  "/gd": ["owner", "director", "auditor", "it_engineer"], "/xnk": MGMT_ROLES, "/rd": MGMT_ROLES, "/nhan-rong": ["owner", "director", "it_engineer"], "/mua-hang": [...MGMT_ROLES, "team_lead", "worker"],
};
export function canView(view: string, role: string) { const r = VIEW_ROLES[view]; return !r || r.includes(role); }
export function canPage(path: string, role: string) { const r = PAGE_ROLES[path]; return !r || r.includes(role); }
''')
rw("src/app/api/data/[view]/route.ts", lambda s: s.replace('  const qd = QUERIES[view];\n  if (!qd) return NextResponse.json({ error: "ERR_UNKNOWN_VIEW" }, { status: 404 });','  const qd = QUERIES[view];\n  if (!qd) return NextResponse.json({ error: "ERR_UNKNOWN_VIEW" }, { status: 404 });\n  if (!canView(view, sess.role)) return NextResponse.json({ error: "ERR_FORBIDDEN_ROLE", detail: `Vai ${sess.role} không được xem ${view}` }, { status: 403 });',1).replace('import { QUERIES }','import { canView } from "@/lib/roles";\nimport { QUERIES }',1))
# F2b: page gate in Page()
rw("src/components/withSession.tsx", lambda s: s.replace('  return <Shell sess={sess} title={title}>{children(sess)}</Shell>;','  const path = (await headers()).get("x-pathname") ?? ""; if (path && !canPage(path, sess.role)) return <Shell sess={sess} title={title}><div className="card"><b>Không có quyền xem trang này</b><div className="text-sm text-slate-600 mt-1">Vai <b>{sess.role}</b> không thuộc phạm vi {path}. Liên hệ quản trị nếu cần cấp quyền.</div></div></Shell>;\n  return <Shell sess={sess} title={title}>{children(sess)}</Shell>;',1).replace('import { getSession }','import { headers } from "next/headers";\nimport { canPage } from "@/lib/roles";\nimport { getSession }',1))
# F5: admin auto code
rw("src/app/api/admin/[table]/route.ts", lambda s: s.replace('pk = String(code); data[t.pk] = pk; }','pk = String(code); data[t.pk] = pk; if (cols.find((x) => x.name === "code") && data.code == null) data.code = pk; }',1))
