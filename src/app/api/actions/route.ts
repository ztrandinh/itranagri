import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
import { logger } from "@/lib/logger";
import { ACTION_SCHEMAS } from "@/lib/action-schemas";
import * as kho from "./handlers/kho";
import * as van_hanh from "./handlers/van_hanh";
import * as canh_bao from "./handlers/canh_bao";
import * as to_chuc from "./handlers/to_chuc";
import * as mua_hang from "./handlers/mua_hang";
import * as ke_toan from "./handlers/ke_toan";
import * as nhan_su from "./handlers/nhan_su";
import * as chan_nuoi from "./handlers/chan_nuoi";
import * as ban_hang from "./handlers/ban_hang";
import * as giam_sat from "./handlers/giam_sat";
import * as marketing from "./handlers/marketing";
import type { ActionHandler } from "./handlers/kho";

/** Registry action -> handler theo domain (src/app/api/actions/handlers/*.ts) — trước đây 1 switch
 *  147 case trong 1 file (75KB, dòng dài tới 1037 ký tự). Tách CƠ HỌC bằng script (scripts/split-actions.mjs),
 *  giữ nguyên 100% logic từng case — chỉ đổi CÁCH TỔ CHỨC file, không đổi hành vi runtime. */
const REGISTRY: Record<string, ActionHandler> = {
  "approve_adjustment": kho.approveAdjustment,
  "reserve_order": kho.reserveOrder,
  "set_reserve": kho.setReserve,
  "add_reserve_item": kho.addReserveItem,
  "tool_issue": kho.toolIssue,
  "tool_return": kho.toolReturn,
  "tool_move": kho.toolMove,
  "qc_hold": kho.qcHold,
  "qc_release": kho.qcRelease,
  "recall_lot": kho.recallLot,
  "record_intake": kho.recordIntake,
  "refresh_cache": kho.refreshCache,
  "apply_landed_cost": kho.applyLandedCost,
  "digitize_paper": van_hanh.digitizePaper,
  "approve_checklist": van_hanh.approveChecklist,
  "shift_note": van_hanh.shiftNote,
  "close_cycle": van_hanh.closeCycle,
  "open_cycle": van_hanh.openCycle,
  "add_season_plan": van_hanh.addSeasonPlan,
  "bulk_approve_checklists": van_hanh.bulkApproveChecklists,
  "gen_monitoring": van_hanh.genMonitoring,
  "initiative": van_hanh.initiative,
  "approve_initiative": van_hanh.approveInitiative,
  "close_plan": van_hanh.closePlan,
  "ack_alert": canh_bao.ackAlert,
  "ack_recon": canh_bao.ackRecon,
  "void_event": canh_bao.voidEvent,
  "ack_note": canh_bao.ackNote,
  "set_grid": canh_bao.setGrid,
  "save_alert_rule": canh_bao.saveAlertRule,
  "toggle_alert_rule": canh_bao.toggleAlertRule,
  "run_rules_now": canh_bao.runRulesNow,
  "set_setting": canh_bao.setSetting,
  "set_norm": canh_bao.setNorm,
  "ack_sop": canh_bao.ackSop,
  "create_task": to_chuc.createTask,
  "task_status": to_chuc.taskStatus,
  "generate_tasks": to_chuc.generateTasks,
  "create_farm": to_chuc.createFarm,
  "update_farm": to_chuc.updateFarm,
  "save_process": to_chuc.saveProcess,
  "save_step": to_chuc.saveStep,
  "delete_step": to_chuc.deleteStep,
  "move_step": to_chuc.moveStep,
  "publish_process": to_chuc.publishProcess,
  "unpublish_process": to_chuc.unpublishProcess,
  "start_run": to_chuc.startRun,
  "complete_step": to_chuc.completeStep,
  "cancel_run": to_chuc.cancelRun,
  "create_api_key": to_chuc.createApiKey,
  "sync_labor_budget": to_chuc.syncLaborBudget,
  "sync_process_criteria": to_chuc.syncProcessCriteria,
  "publish_year_plan": to_chuc.publishYearPlan,
  "publish_plan": to_chuc.publishPlan,
  "create_po": mua_hang.createPo,
  "receive_po": mua_hang.receivePo,
  "create_po_full": mua_hang.createPoFull,
  "po_status": mua_hang.poStatus,
  "supplier_return": mua_hang.supplierReturn,
  "approve_supplier_return": mua_hang.approveSupplierReturn,
  "approve_return": mua_hang.approveReturn,
  "create_expense": ke_toan.createExpense,
  "approve_expense": ke_toan.approveExpense,
  "lock_period": ke_toan.lockPeriod,
  "add_fixed_cost": ke_toan.addFixedCost,
  "compute_kpi": ke_toan.computeKpi,
  "import_bank_lines": ke_toan.importBankLines,
  "bank_reconcile": ke_toan.bankReconcile,
  "bank_match": ke_toan.bankMatch,
  "close_contribution_bonus": ke_toan.closeContributionBonus,
  "close_bonus": ke_toan.closeBonus,
  "apply_bonus": ke_toan.applyBonus,
  "compute_assumptions": ke_toan.computeAssumptions,
  "set_assumption": ke_toan.setAssumption,
  "pay_supplier": ke_toan.paySupplier,
  "gen_loan_schedule": ke_toan.genLoanSchedule,
  "pay_loan": ke_toan.payLoan,
  "receive_claim": ke_toan.receiveClaim,
  "run_dunning": ke_toan.runDunning,
  "compute_payroll": ke_toan.computePayroll,
  "approve_payroll": ke_toan.approvePayroll,
  "run_depreciation": ke_toan.runDepreciation,
  "change_pin": nhan_su.changePin,
  "revoke_sessions": nhan_su.revokeSessions,
  "update_staff": nhan_su.updateStaff,
  "assign_staff_farm": nhan_su.assignStaffFarm,
  "create_staff": nhan_su.createStaff,
  "unlock_staff": nhan_su.unlockStaff,
  "reset_pin": nhan_su.resetPin,
  "run_grade_review": nhan_su.runGradeReview,
  "sign_grade": nhan_su.signGrade,
  "reject_grade": nhan_su.rejectGrade,
  "appeal_grade": nhan_su.appealGrade,
  "key_position": nhan_su.keyPosition,
  "succession": nhan_su.succession,
  "dependent_claim": nhan_su.dependentClaim,
  "dependent_decide": nhan_su.dependentDecide,
  "suggest_headcount": nhan_su.suggestHeadcount,
  "headcount_set": nhan_su.headcountSet,
  "delegate": nhan_su.delegate,
  "end_delegation": nhan_su.endDelegation,
  "complete_training": nhan_su.completeTraining,
  "gen_training_week": nhan_su.genTrainingWeek,
  "bulk_move_animals": chan_nuoi.bulkMoveAnimals,
  "sell_livestock": chan_nuoi.sellLivestock,
  "assign_tag": chan_nuoi.assignTag,
  "new_animal": chan_nuoi.newAnimal,
  "gen_feed_plans": chan_nuoi.genFeedPlans,
  "intake_herd": chan_nuoi.intakeHerd,
  "record_lab_result": chan_nuoi.recordLabResult,
  "record_energy": chan_nuoi.recordEnergy,
  "record_biochar": chan_nuoi.recordBiochar,
  "record_carbon_credit": chan_nuoi.recordCarbonCredit,
  "record_cea": chan_nuoi.recordCea,
  "record_duckweed": chan_nuoi.recordDuckweed,
  "record_reading": chan_nuoi.recordReading,
  "create_order": ban_hang.createOrder,
  "order_status": ban_hang.orderStatus,
  "create_contract": ban_hang.createContract,
  "create_custody": ban_hang.createCustody,
  "reply_customer": ban_hang.replyCustomer,
  "ship_order": ban_hang.shipOrder,
  "quote_to_order": ban_hang.quoteToOrder,
  "send_quote": ban_hang.sendQuote,
  "redeem_points": ban_hang.redeemPoints,
  "gen_contract_deliveries": ban_hang.genContractDeliveries,
  "price_for": ban_hang.priceFor,
  "plan_gs_rotation": giam_sat.planGsRotation,
  "gs_field_day": giam_sat.gsFieldDay,
  "rate_supervisor": giam_sat.rateSupervisor,
  "capa_set": giam_sat.capaSet,
  "capa_verify": giam_sat.capaVerify,
  "gen_capa": giam_sat.genCapa,
  "gs_ack": giam_sat.gsAck,
  "gen_gs_omissions": giam_sat.genGsOmissions,
  "cross_check_submit": giam_sat.crossCheckSubmit,
  "gen_cross_checks": giam_sat.genCrossChecks,
  "whistle": giam_sat.whistle,
  "whistle_handle": giam_sat.whistleHandle,
  "sup_check": giam_sat.supCheck,
  "run_supervision": giam_sat.runSupervision,
  "mkt_campaign": marketing.mktCampaign,
  "mkt_content": marketing.mktContent,
  "mkt_asset": marketing.mktAsset,
  "mkt_asset_approve": marketing.mktAssetApprove,
  "mkt_mention": marketing.mktMention,
  "mkt_mention_update": marketing.mktMentionUpdate,
};

export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const b = await req.json();
  // Validate hình dạng body THEO ACTION nếu đã có schema (lib/action-schemas.ts) — action chưa có
  // schema thì bỏ qua, giữ nguyên hành vi cũ (thêm dần theo domain, không phải chờ đủ 147 action).
  const schema = ACTION_SCHEMAS[b?.action];
  if (schema) {
    const parsed = schema.safeParse(b);
    if (!parsed.success) return NextResponse.json({ error: "ERR_VALIDATION", detail: parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; ") }, { status: 400 });
  }
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
