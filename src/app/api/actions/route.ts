import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
/** Hành động có duyệt / cập nhật cột được phép: approve_adjustment, digitize_paper, ack_alert, ack_recon, approve_checklist, close_incident, void_event */
export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const b = await req.json();
  try {
    const out = await withCtx(s, async (c) => {
      switch (b.action) {
        case "approve_adjustment": {
          if (!["tech_head","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const a = (await c.query("select * from adjustments where id=$1", [b.id])).rows[0];
          if (!a) throw new Error("ERR_NOT_FOUND");
          if (a.requested_by === s.staffId || a.created_by === s.staffId) throw new Error("ERR_SELF_APPROVE");
          const st = b.approve ? "DUYET" : "TU_CHOI";
          await c.query("update adjustments set adj_status=$2, approved_by=$3, approved_at=now() where id=$1", [b.id, st, s.staffId]);
          if (b.approve && a.warehouse_id && a.sku && a.delta) {
            await c.query("insert into inventory_moves(farm_id,created_by,source,warehouse_id,sku,lot_id,direction,qty,reason,ref_type,ref_id) values ($1,$2,'APP',$3,$4,$5,$6,$7,'DIEU_CHINH','adjustments',$8)",
              [s.farmId, s.staffId, a.warehouse_id, a.sku, a.lot_id, a.delta > 0 ? 1 : -1, Math.abs(a.delta), a.id]);
          }
          return { ok: true, status: st };
        }
        case "digitize_paper": {
          await c.query("update paper_scans set digitized=true, digitized_by=$2, digitized_ts=now(), linked_ids=coalesce(linked_ids,'[]'::jsonb)||$3::jsonb where id=$1", [b.id, s.staffId, JSON.stringify(b.linked_ids ?? [])]);
          return { ok: true };
        }
        case "ack_alert": { await c.query("update alerts set acked_by=$2, acked_at=now() where id=$1", [b.id, s.staffId]); return { ok: true }; }
        case "ack_recon": { await c.query("update recon_results set acked_by=$2 where id=$1", [b.id, s.staffId]); return { ok: true }; }
        case "approve_checklist": {
          if (!["team_lead","tech_head","director"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const r = (await c.query("select created_by from checklist_runs where id=$1", [b.id])).rows[0];
          if (r?.created_by === s.staffId) throw new Error("ERR_SELF_APPROVE");
          await c.query("update checklist_runs set approved_by=$2, approved_at=now() where id=$1", [b.id, s.staffId]); return { ok: true };
        }
        case "void_event": {
          if (!["tech_head","director"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          if (!/^[a-z_]+$/.test(b.table)) throw new Error("ERR_BAD_TABLE");
          await c.query(`update ${b.table} set status='VOID' where id=$1 and farm_id=$2`, [b.id, s.farmId]); return { ok: true };
        }
        case "create_task": {
          const r = await c.query("insert into tasks(farm_id,kind,title,detail,target_type,target_id,role_hint,assignee_id,sop_code,due_at,priority,source,rule_code) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,coalesce($10::timestamptz,now()),$11,'MANUAL',$12) returning id",
            [s.farmId, b.kind ?? "KHAC", b.title, JSON.stringify(b.detail ?? {}), b.target_type ?? null, b.target_id ?? null, b.role_hint ?? null, b.assignee_id ?? null, b.sop_code ?? null, b.due_at ?? null, b.priority ?? "BINH_THUONG", b.rule_code ?? "MANUAL-" + Date.now()]);
          return { ok: true, id: r.rows[0].id };
        }
        case "task_status": {
          await c.query("update tasks set status=$2, done_by=case when $2='XONG' then $3 else done_by end, done_at=case when $2='XONG' then now() else done_at end, done_event_id=coalesce($4::uuid,done_event_id), handover_note=coalesce($5,handover_note), assignee_id=coalesce($6,assignee_id) where id=$1 and farm_id=$7",
            [b.id, b.status, s.staffId, b.done_event_id ?? null, b.handover_note ?? null, b.assignee_id ?? null, s.farmId]);
          return { ok: true };
        }
        case "generate_tasks": { const r = await c.query("select itran_generate_tasks_v2($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n }; }
        case "shift_note": {
          const r = await c.query("insert into shift_notes(farm_id,created_by,dept,shift,note,target_type,target_id) values ($1,$2,$3,$4,$5,$6,$7) returning id", [s.farmId, s.staffId, b.dept ?? null, b.shift ?? null, b.note, b.target_type ?? null, b.target_id ?? null]);
          if (b.make_task) await c.query("insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,due_at,priority,source,rule_code,handover_note) values ($1,'GIAO_CA',$2,$3,$4,$5,now()+interval '8 hours','CAO','HANDOVER',$6,$2)", [s.farmId, b.note, b.target_type ?? null, b.target_id ?? null, b.role_hint ?? null, "HO-" + r.rows[0].id]);
          return { ok: true, id: r.rows[0].id };
        }
        case "ack_note": { await c.query("update shift_notes set ack_by=$2, ack_at=now() where id=$1", [b.id, s.staffId]); return { ok: true }; }
        case "create_po": {
          const id = (await c.query("select next_code($1,'PO',4) as c", [s.farmId])).rows[0].c;
          const total = (b.lines as { qty: number; price: number }[]).reduce((a, l) => a + Number(l.qty) * Number(l.price), 0);
          await c.query("insert into purchase_orders(id,farm_id,supplier_id,created_by,lines,total,note) values ($1,$2,$3,$4,$5,$6,$7)", [id, s.farmId, b.supplier_id, s.staffId, JSON.stringify(b.lines), total, b.note ?? null]);
          return { ok: true, id, total };
        }
        case "po_status": {
          if (!["tech_head", "director", "accountant", "team_lead"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const po = (await c.query("select created_by from purchase_orders where id=$1", [b.id])).rows[0];
          if (b.status === "DUYET" && po?.created_by === s.staffId) throw new Error("ERR_SELF_APPROVE");
          await c.query("update purchase_orders set po_status=$2, approved_by=case when $2='DUYET' then $3 else approved_by end, approved_at=case when $2='DUYET' then now() else approved_at end where id=$1", [b.id, b.status, s.staffId]);
          return { ok: true };
        }
        case "create_expense": {
          const id = (await c.query("select next_code($1,'DNC',4) as c", [s.farmId])).rows[0].c;
          await c.query("insert into expense_requests(id,farm_id,requested_by,amount,cost_center,purpose,po_id) values ($1,$2,$3,$4,$5,$6,$7)", [id, s.farmId, s.staffId, b.amount, b.cost_center ?? null, b.purpose, b.po_id ?? null]);
          return { ok: true, id };
        }
        case "approve_expense": {
          const e = (await c.query("select * from expense_requests where id=$1", [b.id])).rows[0];
          if (!e) throw new Error("ERR_NOT_FOUND");
          if (e.requested_by === s.staffId) throw new Error("ERR_SELF_APPROVE");
          const amt = Number(e.amount);
          const limit: Record<string, number> = { team_lead: 2e6, tech_head: 1e7, director: 1e8, owner: Infinity, accountant: 0 };
          if (!b.approve) { await c.query("update expense_requests set status='TU_CHOI', approver1=$2, approved1_at=now() where id=$1", [b.id, s.staffId]); return { ok: true, status: "TU_CHOI" }; }
          if (amt > (limit[s.role] ?? 0)) throw new Error("ERR_OVER_LIMIT");
          const needTwo = amt > 2e7;
          if (needTwo && e.status === "CHO_DUYET") { await c.query("update expense_requests set status='DUYET_1', approver1=$2, approved1_at=now() where id=$1", [b.id, s.staffId]); return { ok: true, status: "DUYET_1", note: "Cần chữ ký thứ 2 (>20 triệu)" }; }
          if (needTwo && e.status === "DUYET_1") { if (e.approver1 === s.staffId) throw new Error("ERR_SAME_SIGNER"); await c.query("update expense_requests set status='DUYET', approver2=$2, approved2_at=now(), owner_notified_at=case when amount>5e7 then now() else null end where id=$1", [b.id, s.staffId]); return { ok: true, status: "DUYET", sms_owner: amt > 5e7 }; }
          await c.query("update expense_requests set status='DUYET', approver1=$2, approved1_at=now() where id=$1", [b.id, s.staffId]); return { ok: true, status: "DUYET" };
        }
        case "change_pin": {
          if (!/^\d{4,8}$/.test(String(b.new_pin))) throw new Error("ERR_PIN_FORMAT");
          const ok = (await c.query("select (pin_hash = crypt($2, pin_hash)) as ok from staff where id=$1", [s.staffId, String(b.old_pin)])).rows[0]?.ok;
          if (!ok) throw new Error("ERR_BAD_CREDENTIALS");
          await c.query("update staff set pin_hash=crypt($2, gen_salt('bf')) where id=$1", [s.staffId, String(b.new_pin)]); return { ok: true };
        }
        case "revoke_sessions": {
          if (!["director", "owner", "it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("update sessions set revoked_at=now() where staff_id=$1 and revoked_at is null", [b.staff_id]); return { ok: true };
        }
        case "bulk_move_animals": {
          if (!Array.isArray(b.animal_ids) || !b.animal_ids.length) throw new Error("ERR_EMPTY");
          for (const aid of b.animal_ids as string[]) {
            await c.query("insert into animal_events(farm_id,created_by,animal_id,event_type,detail,client_ref) values ($1,$2,$3,'CHUYEN',$4,$5)", [s.farmId, s.staffId, aid, JSON.stringify({ to_location: b.location_id ?? null, to_group: b.group_id ?? null, bulk: true }), `bulk-${Date.now()}-${aid}`]);
            if (b.group_id) await c.query("update animals set group_id=$2 where id=$1", [aid, b.group_id]);
          }
          return { ok: true, n: b.animal_ids.length };
        }
        case "assign_tag": {
          await c.query("update animal_tags set to_ts=now(), reason=$3 where animal_id=$1 and tag_type=$2 and to_ts is null", [b.animal_id, b.tag_type, b.reason ?? "thay tai"]);
          await c.query("insert into animal_tags(farm_id,animal_id,tag_type,value,created_by) values ($1,$2,$3,$4,$5)", [s.farmId, b.animal_id, b.tag_type, b.value, s.staffId]);
          if (b.tag_type === "RFID") await c.query("update animals set rfid=$2, tag_pending=false where id=$1", [b.animal_id, b.value]);
          if (b.tag_type === "VISUAL") await c.query("update animals set visual_tag=$2 where id=$1", [b.animal_id, b.value]);
          return { ok: true };
        }
        case "new_animal": {
          const code = (await c.query("select next_code($1,$2,5) as c", [s.farmId, b.species === "DE" ? "DE" : "BO"])).rows[0].c;
          await c.query("insert into animals(id,farm_id,species,breed,sex,birth_date,dam_id,sire_code,rfid,visual_tag,source,intake_lot_id,group_id,status,location_id,tag_pending,cost_center) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)",
            [code, s.farmId, b.species ?? "BO", b.breed ?? null, b.sex ?? null, b.birth_date ?? null, b.dam_id ?? null, b.sire_code ?? null, b.rfid ?? null, b.visual_tag ?? null, b.source ?? "SINH", b.intake_lot_id ?? null, b.group_id ?? null, b.status ?? (b.source === "MUA" ? "CACH_LY" : "SO_SINH"), b.location_id ?? null, !b.rfid, s.farmId + "-CC-BO"]);
          if (b.rfid) await c.query("insert into animal_tags(farm_id,animal_id,tag_type,value,created_by) values ($1,$2,'RFID',$3,$4)", [s.farmId, code, b.rfid, s.staffId]);
          if (b.visual_tag) await c.query("insert into animal_tags(farm_id,animal_id,tag_type,value,created_by) values ($1,$2,'VISUAL',$3,$4)", [s.farmId, code, b.visual_tag, s.staffId]);
          await c.query("insert into animal_events(farm_id,created_by,animal_id,event_type,detail,client_ref) values ($1,$2,$3,$4,$5,$6)", [s.farmId, s.staffId, code, b.source === "MUA" ? "NHAP" : "DE", JSON.stringify({ dam_id: b.dam_id ?? null }), "new-" + code]);
          return { ok: true, code };
        }
        case "lock_period": {
          if (!["director","owner","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("insert into period_locks(farm_id,period_end,locked_by,note) values ($1,$2,$3,$4) on conflict do nothing", [s.farmId, b.period_end, s.staffId, b.note ?? null]); return { ok: true };
        }
        case "close_cycle": {
          if (!["team_lead","tech_head","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const cy = (await c.query("select * from cycles where id=$1 and farm_id=$2", [b.id, s.farmId])).rows[0]; if (!cy) throw new Error("ERR_NOT_FOUND");
          const sum = (await c.query(`select
            (select coalesce(sum(qty_kg),0) from feed_logs where farm_id=$1 and status='ACTIVE' and dest_group_id=$2 and ts::date between $3 and current_date) as feed_kg,
            (select coalesce(sum(value),0) from animal_events where farm_id=$1 and status='ACTIVE' and group_id=$2 and event_type='CHET') as deaths,
            (select coalesce(sum(qty_kg),0) from crop_logs where farm_id=$1 and status='ACTIVE' and plot_id=$4 and activity in ('THU','CAT') and ts::date between $3 and current_date) as harvest_kg`, [s.farmId, cy.group_id, cy.start_date, cy.plot_id])).rows[0];
          await c.query("update cycles set status='DONG', end_date=current_date, closed_by=$2, closed_at=now(), summary=$3 where id=$1", [b.id, s.staffId, JSON.stringify(sum)]);
          return { ok: true, summary: sum };
        }
        case "open_cycle": {
          const id = `${b.group_id ?? b.plot_id}-${b.kind}${new Date().toISOString().slice(2, 10).replace(/-/g, "")}`;
          await c.query("insert into cycles(id,farm_id,kind,name,group_id,plot_id,start_date) values ($1,$2,$3,$4,$5,$6,current_date)", [id, s.farmId, b.kind ?? "KHAC", b.name ?? id, b.group_id ?? null, b.plot_id ?? null]);
          if (b.group_id) await c.query("update animal_groups set cycle_id=$2 where id=$1", [b.group_id, id]); if (b.plot_id) await c.query("update plots set cycle_id=$2 where id=$1", [b.plot_id, id]);
          return { ok: true, id };
        }
        case "create_order": {
          const id = (await c.query("select next_code($1,'DH',5) as c", [s.farmId])).rows[0].c;
          const total = (b.lines as { qty: number; price: number }[]).reduce((a, l) => a + Number(l.qty) * Number(l.price), 0);
          const cutoff = (await c.query("select value from settings where key='order.cutoff' and farm_id in ('GLOBAL',$1) order by (farm_id=$1) desc, version desc limit 1", [s.farmId])).rows[0]?.value ?? "15:00";
          const nowHM = new Date().toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: "Asia/Ho_Chi_Minh" });
          await c.query("insert into orders(id,farm_id,partner_id,channel,deliver_date,lines,total,status,cutoff_ok,created_by,note) values ($1,$2,$3,$4,$5,$6,$7,'CHOT',$8,$9,$10)", [id, s.farmId, b.partner_id, b.channel ?? 1, b.deliver_date ?? null, JSON.stringify(b.lines), total, nowHM <= String(cutoff).replace(/"/g, ""), s.staffId, b.note ?? null]);
          return { ok: true, id, total };
        }
        case "order_status": { await c.query("update orders set status=$2 where id=$1 and farm_id=$3", [b.id, b.status, s.farmId]); if (b.status === "LENH_SX") await c.query("insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,due_at,priority,source,rule_code) values ($1,'LENH_SX','Lệnh sản xuất/đóng gói đơn '||$2,'order',$2,'worker:A7',now()+interval '18 hours','CAO','ORDER','LSX-'||$2)", [s.farmId, b.id]); return { ok: true }; }
        case "create_contract": {
          const id = (await c.query("select next_code($1,'HD',4) as c", [s.farmId])).rows[0].c;
          await c.query("insert into contracts(id,farm_id,partner_id,kind,sku,qty_committed,unit,price,start_date,end_date,note,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)", [id, s.farmId, b.partner_id, b.kind ?? "BAO_TIEU", b.sku ?? null, b.qty_committed ?? null, b.unit ?? null, b.price ?? null, b.start_date ?? null, b.end_date ?? null, b.note ?? null, s.staffId]);
          return { ok: true, id };
        }
        case "create_custody": {
          const id = (await c.query("select next_code($1,'NN',4) as c", [s.farmId])).rows[0].c;
          await c.query("insert into custody_contracts(id,farm_id,partner_id,kind,animal_ids,package,fee,period_months,prepaid,start_date,end_option,consent_at,note,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,current_date,$10,now(),$11,$12)", [id, s.farmId, b.partner_id, b.kind ?? "NHAN_NUOI", b.animal_ids ?? [], b.package ?? null, b.fee ?? null, b.period_months ?? null, b.prepaid ?? null, b.end_option ?? null, b.note ?? null, s.staffId]);
          for (const aid of (b.animal_ids ?? []) as string[]) { await c.query("update animals set owner_type=$2 where id=$1", [aid, b.kind === "KY_GUI" ? "KHACH" : "DONG_SO_HUU"]); await c.query("insert into animal_ownership(animal_id,partner_id,pct,contract_id) values ($1,$2,$3,null)", [aid, b.partner_id, b.kind === "KY_GUI" ? 100 : 50]); }
          return { ok: true, id };
        }
        case "add_season_plan": { await c.query("insert into season_plans(farm_id,cycle_id,plot_id,crop,variety,sow_date,harvest_date,plan_yield_kg,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9)", [s.farmId, b.cycle_id ?? null, b.plot_id, b.crop, b.variety ?? null, b.sow_date ?? null, b.harvest_date ?? null, b.plan_yield_kg ?? null, s.staffId]); return { ok: true }; }
        case "gen_feed_plans": { const r = await c.query("select gen_feed_plans($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n }; }
        case "update_staff": {
          if (!["director","owner","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("update staff set sop_certs=coalesce($2::jsonb,sop_certs), health_check_due=coalesce($3::date,health_check_due), food_safety_training_due=coalesce($4::date,food_safety_training_due), active=coalesce($5,active) where id=$1", [b.staff_id, b.sop_certs ? JSON.stringify(b.sop_certs) : null, b.health_check_due ?? null, b.food_safety_training_due ?? null, b.active ?? null]); return { ok: true };
        }
        case "bulk_approve_checklists": {
          if (!["team_lead","tech_head","director"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const r = await c.query("update checklist_runs set approved_by=$2, approved_at=now() where farm_id=$1 and approved_by is null and all_green and created_by<>$2 and ts::date=current_date returning id", [s.farmId, s.staffId]); return { ok: true, n: r.rowCount };
        }
        case "add_fixed_cost": {
          if (!["accountant","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("insert into cc_fixed_costs(farm_id,month,cost_center,kind,amount,note,created_by) values ($1,$2,$3,$4,$5,$6,$7) on conflict (farm_id,month,cost_center,kind) do update set amount=excluded.amount, note=excluded.note", [s.farmId, b.month, b.cost_center, b.kind, b.amount, b.note ?? null, s.staffId]); return { ok: true };
        }
        case "compute_kpi": { const r = await c.query("select compute_staff_kpi($1, coalesce($2::date, date_trunc('month', now())::date)) as n", [s.farmId, b.month ?? null]); return { ok: true, n: r.rows[0].n }; }
        case "reply_customer": { await c.query("insert into customer_messages(farm_id,contract_id,animal_id,from_customer,body,replied_by,replied_at) values ($1,$2,$3,false,$4,$5,now())", [s.farmId, b.contract_id, b.animal_id ?? null, b.body, s.staffId]); await c.query("update customer_messages set replied_by=$2, replied_at=now() where id=$1", [b.reply_to, s.staffId]); return { ok: true }; }
        case "set_grid": { if (!["director","owner","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update locations set grid_x=$2, grid_y=$3 where id=$1 and farm_id=$4", [b.id, b.x, b.y, s.farmId]); return { ok: true }; }
        case "save_alert_rule": {
          if (!["tech_head","director","owner","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const scope = b.scope === "GLOBAL" && ["owner","it_engineer"].includes(s.role) ? "GLOBAL" : s.farmId;
          const ver = Number((await c.query("select coalesce(max(version),0)+1 as v from alert_rules where code=$1 and farm_id=$2", [b.code, scope])).rows[0].v);
          await c.query("update alert_rules set active=false where code=$1 and farm_id=$2", [b.code, scope]);
          await c.query("insert into alert_rules(code,version,farm_id,name,source,expr,level,recipients,channels,sop_code,cooldown_min,active,updated_by,reason,description,created_by) values ($1,$2,$3,$4,'custom',$5,$6,$7,$8,$9,$10,true,$11,$12,$13,$11)",
            [b.code, ver, scope, b.name, JSON.stringify(b.expr ?? {}), b.level ?? "VANG", b.recipients ?? ["tech_head"], b.channels ?? ["app"], b.sop_code ?? null, b.cooldown_min ?? 720, s.staffId, b.reason ?? "cấu hình qua UI", b.description ?? null]);
          return { ok: true, version: ver };
        }
        case "toggle_alert_rule": { if (!["tech_head","director","owner","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update alert_rules set active=$3, updated_by=$4, updated_at=now() where code=$1 and version=$2", [b.code, b.version, !!b.active, s.staffId]); return { ok: true }; }
        case "run_rules_now": { const { runCustomRules, dispatchEvents } = await import("@/lib/notify"); const f = await runCustomRules(s.farmId); const n = await dispatchEvents(); return { ok: true, fired: f, notified: n }; }
        case "create_farm": {
          if (!["owner","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          if (!/^F\d{2,3}$/.test(String(b.id))) throw new Error("ERR_FARM_ID_FORMAT");
          const r = await c.query("select create_farm($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) as id", [b.id, s.orgId, b.region_id ?? null, b.name, b.province ?? null, b.legal_entity ?? null, b.kind ?? "CAMPUS", b.s_ha ?? null, b.k_factor ?? null, JSON.stringify(b.modules ?? {})]);
          await c.query("update staff set farm_ids = array_append(coalesce(farm_ids,'{}'), $1) where id=$2 and not ($1 = any(coalesce(farm_ids,'{}')))", [b.id, s.staffId]);
          return { ok: true, id: r.rows[0].id };
        }
        case "update_farm": { if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update farms set name=coalesce($2,name), province=coalesce($3,province), legal_entity=coalesce($4,legal_entity), s_ha=coalesce($5,s_ha), k_factor=coalesce($6,k_factor), modules=coalesce($7::jsonb,modules), status=coalesce($8,status), region_id=coalesce($9,region_id) where id=$1", [b.id, b.name ?? null, b.province ?? null, b.legal_entity ?? null, b.s_ha ?? null, b.k_factor ?? null, b.modules ? JSON.stringify(b.modules) : null, b.status ?? null, b.region_id ?? null]); return { ok: true }; }
        case "set_setting": { if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const scope = b.scope === "GLOBAL" && ["owner","it_engineer"].includes(s.role) ? "GLOBAL" : s.farmId; const v = Number((await c.query("select coalesce(max(version),0)+1 as v from settings where farm_id=$1 and key=$2", [scope, b.key])).rows[0].v); await c.query("insert into settings(farm_id,key,value,version,updated_by) values ($1,$2,$3,$4,$5)", [scope, b.key, JSON.stringify(b.value), v, s.staffId]); return { ok: true, version: v }; }
        case "set_norm": { if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into norms(id,org_id,farm_id,kind,subject,value,unit,note) values ($1,$2,$3,$4,$5,$6,$7,$8) on conflict (id) do update set value=excluded.value, unit=excluded.unit, note=excluded.note", [b.id ?? `N-${b.kind}-${b.subject}-${s.farmId}`, s.orgId, b.scope === "GLOBAL" ? null : s.farmId, b.kind, b.subject ?? null, b.value, b.unit ?? null, b.note ?? null]); return { ok: true }; }
        case "assign_staff_farm": { if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update staff set farm_id=coalesce($2,farm_id), farm_ids=(select array_agg(distinct x) from unnest(array_append(coalesce(farm_ids,'{}'),$3)) x) where id=$1", [b.staff_id, b.farm_id ?? null, b.add_farm_id ?? b.farm_id]); return { ok: true }; }
        case "create_staff": {
          if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const id = (await c.query("select next_code($1,'NS',3) as c", [s.orgId])).rows[0].c.replace(s.orgId + "-", "");
          await c.query("insert into staff(id,org_id,farm_id,full_name,role,dept,position,phone,login,pin_hash,farm_ids) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,crypt($10,gen_salt('bf')),$11)", [id, s.orgId, b.farm_id ?? s.farmId, b.full_name, b.role ?? "worker", b.dept ?? null, b.position ?? null, b.phone ?? null, b.login, String(b.pin ?? "1234"), [b.farm_id ?? s.farmId]]);
          return { ok: true, id };
        }
        case "save_process": {
          if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const code = String(b.code ?? "").toUpperCase(); if (!/^P-[A-Z0-9-]{2,30}$/.test(code)) throw new Error("ERR_BAD_CODE: mã dạng P-XX-NN");
          const ex = (await c.query("select status from processes where code=$1", [code])).rows[0];
          if (!ex) await c.query("insert into processes(code,dept_code,name,kind,object_type,trigger_text,description,sla,owner_role,kpi,ui_path,status,farm_id,created_by,coverage,position,auto_start) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'NHAP',$12,$13,'DA_CO',99,$14)", [code, b.dept_code, b.name, b.kind ?? "CORE", b.object_type ?? null, b.trigger_text ?? null, b.description ?? null, b.sla ?? null, b.owner_role ?? null, b.kpi ?? null, b.ui_path ?? null, b.scope === "GLOBAL" ? null : s.farmId, s.staffId, JSON.stringify(b.auto_start ?? {})]);
          else await c.query("update processes set dept_code=$2,name=$3,kind=$4,object_type=$5,trigger_text=$6,description=$7,sla=$8,owner_role=$9,kpi=$10,ui_path=$11,auto_start=$12, inputs=coalesce($13::jsonb,inputs), outputs=coalesce($14::jsonb,outputs), documents=coalesce($15::jsonb,documents), tools=coalesce($16::text[],tools), visible_depts=array_remove(array[$2::text] || coalesce((select array_agg(distinct x) from (select jsonb_array_elements(coalesce($13::jsonb,inputs))->>'from' as x union select jsonb_array_elements(coalesce($14::jsonb,outputs))->>'to') t where x is not null and x<>'*'), '{}'), null) where code=$1", [code, b.dept_code, b.name, b.kind ?? "CORE", b.object_type ?? null, b.trigger_text ?? null, b.description ?? null, b.sla ?? null, b.owner_role ?? null, b.kpi ?? null, b.ui_path ?? null, JSON.stringify(b.auto_start ?? {}), b.inputs ? JSON.stringify(b.inputs) : null, b.outputs ? JSON.stringify(b.outputs) : null, b.documents ? JSON.stringify(b.documents) : null, Array.isArray(b.tools) ? b.tools : null]);
          return { ok: true, code };
        }
        case "save_step": {
          if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const st = b.step ?? {}; const code = String(b.code);
          const stepNo = Number(st.step_no) || Number((await c.query("select coalesce(max(step_no),0)+1 as n from process_steps where process_code=$1", [code])).rows[0].n);
          const tools = Array.isArray(st.tools) ? st.tools : String(st.tools ?? "").split(",").map((x: string) => x.trim()).filter(Boolean);
          await c.query(`insert into process_steps(process_code,step_no,name,actor_role,dept_code,action,system_where,control,output,tools,materials,inputs,outputs,duration_min,sla_hours,form_table,notify_roles,required,parallel_group,checklist)
            values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)
            on conflict (process_code, step_no) do update set name=excluded.name, actor_role=excluded.actor_role, dept_code=excluded.dept_code, action=excluded.action, system_where=excluded.system_where, control=excluded.control, output=excluded.output, tools=excluded.tools, materials=excluded.materials, inputs=excluded.inputs, outputs=excluded.outputs, duration_min=excluded.duration_min, sla_hours=excluded.sla_hours, form_table=excluded.form_table, notify_roles=excluded.notify_roles, required=excluded.required, parallel_group=excluded.parallel_group, checklist=excluded.checklist`,
            [code, stepNo, st.name ?? `Bước ${stepNo}`, st.actor_role ?? null, st.dept_code ?? null, st.action ?? null, st.system_where ?? null, st.control ?? null, st.output ?? null, tools, JSON.stringify(st.materials ?? []), st.inputs ?? null, st.outputs ?? null, st.duration_min ?? null, st.sla_hours ?? null, st.form_table ?? null, Array.isArray(st.notify_roles) ? st.notify_roles : [], st.required ?? true, st.parallel_group ?? null, JSON.stringify(st.checklist ?? [])]);
          if (st.documents) await c.query("update process_steps set documents=$3 where process_code=$1 and step_no=$2", [code, stepNo, JSON.stringify(st.documents)]);
          // phòng ban trong bước tự vào visible_depts (mỗi bộ phận chỉ thấy quy trình liên quan)
          if (st.dept_code) await c.query("update processes set visible_depts = array(select distinct unnest(visible_depts || array[$2::text])) where code=$1", [code, st.dept_code]);
          return { ok: true, step_no: stepNo };
        }
        case "delete_step": {
          if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("insert into audit_log(farm_id,table_name,pk,action,before,by_staff,by_role) select $3, 'process_steps', process_code||'#'||step_no, 'DELETE', to_jsonb(process_steps), $4, $5 from process_steps where process_code=$1 and step_no=$2", [b.code, b.step_no, s.farmId, s.staffId, s.role]);
          await c.query("delete from process_steps where process_code=$1 and step_no=$2", [b.code, b.step_no]);
          await c.query("with o as (select id, row_number() over (order by step_no) as rn from process_steps where process_code=$1) update process_steps p set step_no = -o.rn from o where p.id=o.id", [b.code]);
          await c.query("update process_steps set step_no = -step_no where process_code=$1 and step_no < 0", [b.code]);
          return { ok: true };
        }
        case "move_step": {
          const dir = Number(b.dir); const a = Number(b.step_no); const bNo = a + dir;
          await c.query("update process_steps set step_no=-1 where process_code=$1 and step_no=$2", [b.code, a]);
          await c.query("update process_steps set step_no=$3 where process_code=$1 and step_no=$2", [b.code, bNo, a]);
          await c.query("update process_steps set step_no=$2 where process_code=$1 and step_no=-1", [b.code, bNo]);
          return { ok: true };
        }
        case "publish_process": { if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select publish_process($1,$2)", [b.code, s.staffId]); return { ok: true }; }
        case "unpublish_process": { if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update processes set status=$2 where code=$1", [b.code, b.status ?? "NHAP"]); return { ok: true }; }
        case "start_run": { const r = await c.query("select start_process_run($1,$2,$3,$4,$5,$6,$7) as id", [s.farmId, b.code, s.staffId, b.ref_table ?? null, b.ref_id ?? null, b.title ?? null, JSON.stringify(b.context ?? {})]); return { ok: true, run_id: r.rows[0].id }; }
        case "complete_step": { const r = await c.query("select complete_run_step($1,$2,$3,$4,$5) as r", [b.run_id, b.step_no, s.staffId, b.output ?? null, b.note ?? null]); return { ok: true, result: r.rows[0].r }; }
        case "cancel_run": { if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update process_runs set status='HUY', finished_at=now(), note=$2 where id=$1", [b.run_id, b.note ?? null]); await c.query("update tasks set status='BO_QUA' where ref_table='process_runs' and ref_id=$1 and status in ('MO','DANG_LAM')", [String(b.run_id)]); return { ok: true }; }
        default: throw new Error("ERR_UNKNOWN_ACTION");
      }
    });
    return NextResponse.json(out);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ error: msg.match(/ERR_[A-Z_]+/)?.[0] ?? "ERR", detail: msg }, { status: 400 });
  }
}
