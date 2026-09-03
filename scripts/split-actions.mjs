// Tách switch (b.action) khổng lồ trong src/app/api/actions/route.ts thành registry theo domain.
// Chạy: node scripts/split-actions.mjs
// Kỹ thuật: đếm độ sâu ngoặc { } để tách CHÍNH XÁC từng case (giữ nguyên source text, không format lại)
// — tránh rủi ro gõ tay lại 147 case (dễ lỗi transcription hơn parse tự động).
import fs from "node:fs";

const SRC = "src/app/api/actions/route.ts";
const src = fs.readFileSync(SRC, "utf8");

const switchStart = src.indexOf("switch (b.action) {");
if (switchStart < 0) throw new Error("Không tìm thấy switch (b.action) {");
const bodyStart = switchStart + "switch (b.action) {".length;

// Tìm } đóng switch bằng đếm độ sâu từ bodyStart.
let depth = 1, i = bodyStart;
for (; i < src.length && depth > 0; i++) {
  if (src[i] === "{") depth++;
  else if (src[i] === "}") depth--;
}
const switchBody = src.slice(bodyStart, i - 1); // không gồm } cuối

// Tách từng case theo regex `case "name": {` ở TOP LEVEL của switchBody (không nằm trong ngoặc lồng).
const caseRe = /case\s+"([a-z_0-9]+)"\s*:\s*\{/g;
const cases = [];
let m;
const positions = [];
while ((m = caseRe.exec(switchBody))) positions.push({ name: m[1], bodyStart: m.index + m[0].length, matchStart: m.index });
for (let k = 0; k < positions.length; k++) {
  const { name, bodyStart: bs } = positions[k];
  let d = 1, j = bs;
  for (; j < switchBody.length && d > 0; j++) {
    if (switchBody[j] === "{") d++;
    else if (switchBody[j] === "}") d--;
  }
  const body = switchBody.slice(bs, j - 1).trim();
  cases.push({ name, body });
}

const defaultMatch = switchBody.match(/default:\s*([^\n]+)/);
console.log(`Tách được ${cases.length} case (kỳ vọng 147). default: ${defaultMatch ? defaultMatch[1].trim() : "KHÔNG THẤY"}`);
if (cases.length !== 147) { console.error("SỐ LƯỢNG KHÔNG KHỚP — dừng lại, không ghi file."); process.exit(1); }

// ---- Phân nhóm domain (chỉ ảnh hưởng TỔ CHỨC FILE, không đổi hành vi — mọi handler vẫn gộp
// chung 1 registry để dispatch, phân nhóm sai chỗ chỉ là vấn đề thẩm mỹ, không phải bug). ----
const DOMAIN = {
  kho: ["approve_adjustment","tool_issue","tool_move","tool_return","apply_landed_cost","recall_lot","qc_hold","qc_release","record_intake","add_reserve_item","set_reserve","reserve_order","refresh_cache"],
  chan_nuoi: ["new_animal","assign_tag","bulk_move_animals","intake_herd","sell_livestock","record_reading","record_cea","record_duckweed","record_biochar","record_energy","gen_feed_plans","record_lab_result","record_carbon_credit"],
  ban_hang: ["create_order","order_status","ship_order","send_quote","quote_to_order","price_for","redeem_points","reply_customer","create_contract","create_custody","gen_contract_deliveries"],
  mua_hang: ["create_po","create_po_full","receive_po","po_status","approve_supplier_return","supplier_return","approve_return"],
  ke_toan: ["pay_supplier","pay_loan","gen_loan_schedule","run_depreciation","bank_match","bank_reconcile","import_bank_lines","lock_period","apply_bonus","close_bonus","close_contribution_bonus","receive_claim","compute_kpi","run_dunning","add_fixed_cost","compute_assumptions","set_assumption","compute_payroll","approve_payroll","create_expense","approve_expense"],
  nhan_su: ["create_staff","update_staff","unlock_staff","reset_pin","change_pin","revoke_sessions","delegate","end_delegation","assign_staff_farm","headcount_set","suggest_headcount","complete_training","gen_training_week","dependent_claim","dependent_decide","appeal_grade","reject_grade","sign_grade","run_grade_review","succession","key_position"],
  giam_sat: ["gs_ack","gs_field_day","plan_gs_rotation","sup_check","cross_check_submit","gen_cross_checks","rate_supervisor","run_supervision","gen_gs_omissions","capa_set","capa_verify","gen_capa","whistle","whistle_handle"],
  to_chuc: ["save_process","publish_process","unpublish_process","save_step","move_step","delete_step","start_run","cancel_run","complete_step","generate_tasks","sync_process_criteria","create_task","task_status","publish_plan","publish_year_plan","sync_labor_budget","create_farm","update_farm","create_api_key"],
  marketing: ["mkt_asset","mkt_asset_approve","mkt_campaign","mkt_content","mkt_mention","mkt_mention_update"],
  canh_bao: ["ack_alert","ack_recon","ack_note","ack_sop","save_alert_rule","toggle_alert_rule","run_rules_now","set_norm","set_setting","set_grid","void_event"],
  van_hanh: ["approve_checklist","bulk_approve_checklists","shift_note","initiative","approve_initiative","close_cycle","open_cycle","close_plan","digitize_paper","gen_monitoring","add_season_plan"],
};
const nameToDomain = {};
for (const [dom, names] of Object.entries(DOMAIN)) for (const n of names) nameToDomain[n] = dom;
const unmapped = cases.filter((c) => !nameToDomain[c.name]);
if (unmapped.length) { console.error("Chưa phân nhóm:", unmapped.map((c) => c.name)); process.exit(1); }

const byDomain = new Map();
for (const c of cases) { const d = nameToDomain[c.name]; if (!byDomain.has(d)) byDomain.set(d, []); byDomain.get(d).push(c); }

fs.mkdirSync("src/app/api/actions/handlers", { recursive: true });
const registryImports = [];
const registryEntries = [];
for (const [dom, list] of byDomain) {
  const fnName = (n) => n.replace(/_([a-z0-9])/g, (_, ch) => ch.toUpperCase());
  const needsEventTables = list.some((c) => /\bEVENT_TABLES\b/.test(c.body));
  let out = `import type { PoolClient } from "pg";\nimport type { Session } from "@/lib/auth";\n${needsEventTables ? 'import { EVENT_TABLES } from "@/lib/events";\n' : ""}// eslint-disable-next-line @typescript-eslint/no-explicit-any\ntype B = any;\nexport type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;\n\n`;
  for (const c of list) {
    // "b" không dùng trong body (mọi case đều dùng "c" cho query) -> bỏ hẳn tham số cuối thay vì giữ
    // biến không dùng (switch cũ dùng chung 1 scope nên trước đây không bị flag riêng từng case;
    // dự án không cấu hình argsIgnorePattern cho "_", nên bỏ tham số thừa thay vì prefix "_").
    // TS cho phép hàm khai báo ÍT tham số hơn kiểu ActionHandler yêu cầu (hiệp biến tham số chuẩn JS).
    const usesB = new RegExp(`\\bb\\b`).test(c.body);
    const params = usesB ? "c, s, b" : "c, s";
    out += `export const ${fnName(c.name)}: ActionHandler = async (${params}) => {\n  ${c.body}\n};\n\n`;
  }
  fs.writeFileSync(`src/app/api/actions/handlers/${dom}.ts`, out, "utf8");
  registryImports.push(`import * as ${dom} from "./handlers/${dom}";`);
  for (const c of list) registryEntries.push(`  ${JSON.stringify(c.name)}: ${dom}.${fnName(c.name)},`);
}

const newRoute = `import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
import { logger } from "@/lib/logger";
${registryImports.join("\n")}
import type { ActionHandler } from "./handlers/kho";

/** Registry action -> handler theo domain (src/app/api/actions/handlers/*.ts) — trước đây 1 switch
 *  147 case trong 1 file (75KB, dòng dài tới 1037 ký tự). Tách CƠ HỌC bằng script (scripts/split-actions.mjs),
 *  giữ nguyên 100% logic từng case — chỉ đổi CÁCH TỔ CHỨC file, không đổi hành vi runtime. */
const REGISTRY: Record<string, ActionHandler> = {
${registryEntries.join("\n")}
};

export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const b = await req.json();
  try {
    const out = await withCtx(s, async (c) => {
      const handler = REGISTRY[b.action];
      if (!handler) throw new Error("ERR_UNKNOWN_ACTION");
      return await handler(c, s, b);
    });
    return NextResponse.json(out);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const code = msg.match(/ERR_[A-Z_]+/)?.[0];
    // Có mã ERR_* = lỗi nghiệp vụ do chính app ném ra, message vốn viết cho người dùng đọc — giữ nguyên.
    // KHÔNG có mã = exception thô (thường từ driver Postgres: lộ tên bảng/cột/constraint nội bộ) —
    // không trả nguyên văn ra client (mọi role kể cả worker gọi được endpoint này), chỉ log ở server.
    if (!code) logger.error({ action: b?.action, err: msg }, "actions: lỗi driver thô");
    return NextResponse.json({ error: code ?? "ERR", detail: code ? msg : "Có lỗi xảy ra, vui lòng thử lại hoặc báo kỹ thuật." }, { status: 400 });
  }
}
`;
fs.writeFileSync(SRC, newRoute, "utf8");
console.log("Đã ghi", byDomain.size, "file domain +", SRC);
for (const [dom, list] of byDomain) console.log(" ", dom, list.length);
