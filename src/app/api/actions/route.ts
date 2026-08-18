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
        case "receive_po": { if (!["worker","team_lead","tech_head","accountant","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select receive_po($1,$2,$3::jsonb) as n", [b.id, b.warehouse_id ?? null, b.lines ? JSON.stringify(b.lines) : null]); return { ok: true, n: r.rows[0].n }; }
        case "create_po_full": {
          const id = (await c.query("select next_code($1,'PO',4) as c", [s.farmId])).rows[0].c;
          const lines = (b.lines as { sku: string; qty: number; price: number }[]).filter((l) => l.sku && Number(l.qty) > 0); if (!lines.length) throw new Error("ERR_LINES");
          const total = lines.reduce((a, l) => a + Number(l.qty) * Number(l.price ?? 0), 0);
          await c.query("insert into purchase_orders(id,farm_id,supplier_id,created_by,lines,total,note,expected_at,kind,requested_by_dept) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)", [id, s.farmId, b.supplier_id, s.staffId, JSON.stringify(lines), total, b.note ?? null, b.expected_at ?? null, b.kind ?? "VAT_TU", b.dept ?? null]);
          await c.query("select publish_event($1,'po.created',$2::jsonb)", [s.farmId, JSON.stringify({ po_id: id, total, kind: b.kind ?? "VAT_TU", supplier_id: b.supplier_id })]).catch(() => null);
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
          // Ma trận ủy quyền = dữ liệu (approval_matrix): hạn mức theo vai, ngưỡng 2 chữ ký, ngưỡng báo chủ — sửa ở /quan-tri?t=approval_matrix, không sửa code
          const am = (await c.query("select * from approval_limit('CHI',$1,$2)", [s.role, s.farmId])).rows[0];
          const roleMax = am ? (am.max_amount == null ? Infinity : Number(am.max_amount)) : 0; const twoOver = Number(am?.two_sign_over ?? 2e7); const ownerOver = Number(am?.notify_owner_over ?? 5e7);
          if (!b.approve) { await c.query("update expense_requests set status='TU_CHOI', approver1=$2, approved1_at=now() where id=$1", [b.id, s.staffId]); return { ok: true, status: "TU_CHOI" }; }
          if (amt > roleMax) throw new Error("ERR_OVER_LIMIT");
          const needTwo = amt > twoOver;
          if (needTwo && e.status === "CHO_DUYET") { await c.query("update expense_requests set status='DUYET_1', approver1=$2, approved1_at=now() where id=$1", [b.id, s.staffId]); return { ok: true, status: "DUYET_1", note: "Cần chữ ký thứ 2 (>20 triệu)" }; }
          if (needTwo && e.status === "DUYET_1") { if (e.approver1 === s.staffId) throw new Error("ERR_SAME_SIGNER"); await c.query("update expense_requests set status='DUYET', approver2=$2, approved2_at=now(), owner_notified_at=case when amount>$3 then now() else null end where id=$1", [b.id, s.staffId, ownerOver]); return { ok: true, status: "DUYET", sms_owner: amt > 5e7 }; }
          await c.query("update expense_requests set status='DUYET', approver1=$2, approved1_at=now() where id=$1", [b.id, s.staffId]); return { ok: true, status: "DUYET" };
        }
        case "change_pin": {
          // Chính sách PIN: công nhân ≥4 số; quản lý/kế toán/IT/chủ ≥6 số; không trùng 1234/0000/1111…; không trùng PIN cũ
          const np = String(b.new_pin); const minLen = ["owner","director","accountant","it_engineer","auditor","tech_head"].includes(s.role) ? 6 : 4;
          if (!new RegExp(`^\\d{${minLen},8}$`).test(np)) throw new Error(`ERR_PIN_FORMAT: PIN phải ${minLen}–8 chữ số`);
          if (/^(\d)\1+$/.test(np) || ["1234","123456","12345678","0000","1111","4321","654321"].includes(np)) throw new Error("ERR_PIN_WEAK: PIN quá dễ đoán");
          if (String(b.old_pin) === np) throw new Error("ERR_PIN_SAME");
          const ok = (await c.query("select (pin_hash = crypt($2, pin_hash)) as ok from staff where id=$1", [s.staffId, String(b.old_pin)])).rows[0]?.ok;
          if (!ok) throw new Error("ERR_BAD_CREDENTIALS");
          await c.query("update staff set pin_hash=crypt($2, gen_salt('bf')), pin_changed_at=now(), must_change_pin=false where id=$1", [s.staffId, np]); return { ok: true };
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
        case "create_api_key": {
          if (!["owner","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const raw = "itk_" + [...crypto.getRandomValues(new Uint8Array(24))].map((x) => x.toString(16).padStart(2, "0")).join("");
          const { createHash } = await import("node:crypto"); const h = createHash("sha256").update(raw).digest("hex");
          const r = await c.query("insert into api_keys(org_id,farm_id,name,key_hash,scopes,created_by) values ($1,$2,$3,$4,$5,$6) returning id", [s.orgId, b.farm_id ?? s.farmId, b.name ?? "key", h, Array.isArray(b.scopes) ? b.scopes : ["ingest"], s.staffId]);
          return { ok: true, id: r.rows[0].id, key: raw, note: "Lưu khóa này ngay — hệ thống chỉ giữ sha256" };
        }
        case "unlock_staff": { if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update staff set locked_until=null where id=$1", [b.staff_id]); await c.query("delete from login_attempts where login in (select login from staff where id=$1)", [b.staff_id]); return { ok: true }; }
        case "reset_pin": { if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const tmp = String(Math.floor(100000 + Math.random() * 900000)); await c.query("update staff set pin_hash=crypt($2, gen_salt('bf')), must_change_pin=true, locked_until=null where id=$1", [b.staff_id, tmp]); await c.query("update sessions set revoked_at=now() where staff_id=$1 and revoked_at is null", [b.staff_id]); return { ok: true, temp_pin: tmp, note: "PIN tạm — nhân viên phải đổi ngay khi đăng nhập" }; }
        case "intake_herd": {
          if (!["worker","team_lead","tech_head","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          if (!Array.isArray(b.animals) || !b.animals.length || b.animals.length > 2000) throw new Error("ERR_EMPTY: cần 1–2000 con");
          const r = await c.query("select intake_herd($1,$2,$3,$4) as r", [s.farmId, s.staffId, JSON.stringify(b.lot ?? {}), JSON.stringify(b.animals)]);
          await c.query("select gen_monitoring_tasks($1)", [s.farmId]);
          return { ok: true, ...r.rows[0].r };
        }
        case "gen_monitoring": { const r = await c.query("select gen_monitoring_tasks($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n }; }
        case "reserve_order": { const r = await c.query("select gen_production_from_shortage($1,$2) as lsx", [b.id, s.staffId]); const sh = await c.query("select jsonb_agg(jsonb_build_object('sku',sku,'short',(select (l->>'qty')::numeric from orders o, jsonb_array_elements(o.lines) l where o.id=$1 and l->>'sku'=p.sku limit 1) - coalesce((select sum(qty) from stock_reservations x where x.order_id=$1 and x.sku=p.sku and x.status='GIU'),0))) as short from (select distinct sku from production_orders where order_id=$1 and status in ('MOI','DANG_LAM')) p", [b.id]); return { ok: true, lsx: r.rows[0].lsx, short: sh.rows[0].short ?? [] }; }
        case "ship_order": { const r = await c.query("select ship_order($1,$2) as n", [b.id, s.staffId]); return { ok: true, n: r.rows[0].n }; }
        case "set_reserve": { if (!["owner","director","tech_head","it_engineer","accountant","team_lead"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update products set reserve=$2 where sku=$1", [b.sku, !!b.reserve]); return { ok: true }; }
        case "add_reserve_item": { if (!["owner","director","tech_head","it_engineer","team_lead"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const g = (await c.query("select * from stock_groups where code=$1", [b.group])).rows[0]; if (!g) throw new Error("ERR_GROUP"); const sku = String(b.sku ?? ("SKU-" + String(b.name).normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/gi, "d").toUpperCase().replace(/[^A-Z0-9]+/g, "-").slice(0, 24))); await c.query("insert into products(sku, org_id, name, kind, unit, stock_group, reserve, active, shelf_life_days) values ($1,'ITRAN',$2,$3,$4,$5,true,true,$6) on conflict (sku) do update set reserve=true, stock_group=excluded.stock_group", [sku, b.name, g.kind_default ?? "NGUYEN_LIEU", b.unit ?? g.unit_default ?? "kg", b.group, b.shelf_life_days ?? null]); return { ok: true, sku }; }
        case "tool_issue": { const r = await c.query("insert into tool_issues(farm_id, warehouse_id, sku, qty, staff_id, dept, purpose, due_back) values ($1,$2,$3,$4,$5,$6,$7,$8) returning id", [s.farmId, b.warehouse_id, b.sku, Number(b.qty ?? 1), b.staff_id ?? null, b.dept ?? null, b.purpose ?? null, b.due_back ?? null]); return { ok: true, id: r.rows[0].id }; }
        case "tool_return": { const t = (await c.query("select * from tool_issues where id=$1 and farm_id=$2", [b.id, s.farmId])).rows[0]; if (!t) throw new Error("ERR_NOT_FOUND"); const cond = String(b.condition ?? "TOT"); const rq = Number(b.returned_qty ?? t.qty); await c.query("update tool_issues set returned_at=now(), returned_qty=$2, condition=$3, note=coalesce(note,'')||$4 where id=$1", [b.id, rq, cond, b.note ? " · " + b.note : ""]); if ((cond === "HONG" || cond === "MAT") && Number(t.qty) - rq > 0) { await c.query("insert into inventory_moves(farm_id, created_by, warehouse_id, sku, direction, qty, unit, reason, from_to, ref_type, ref_id, client_ref) values ($1,$2,$3,$4,-1,$5,(select unit from products where sku=$4),$6,$7,'tool_issue',$8,$9)", [s.farmId, s.staffId, t.warehouse_id, t.sku, Number(t.qty) - rq, cond, "Cấp phát #" + b.id, String(b.id), "tool-" + b.id + "-" + cond]); } return { ok: true }; }
        case "tool_move": { const q = Number(b.qty); if (!(q > 0)) throw new Error("ERR_QTY"); const u = (await c.query("select unit from products where sku=$1", [b.sku])).rows[0]?.unit; const ref = "toolmove-" + Date.now(); await c.query("insert into inventory_moves(farm_id, created_by, warehouse_id, sku, direction, qty, unit, reason, from_to, client_ref) values ($1,$2,$3,$4,-1,$5,$6,'CHUYEN',$7,$8)", [s.farmId, s.staffId, b.from_wh, b.sku, q, u, "→ " + b.to_wh, ref + "-out"]); await c.query("insert into inventory_moves(farm_id, created_by, warehouse_id, sku, direction, qty, unit, reason, from_to, client_ref) values ($1,$2,$3,$4,1,$5,$6,'CHUYEN',$7,$8)", [s.farmId, s.staffId, b.to_wh, b.sku, q, u, "← " + b.from_wh, ref + "-in"]); return { ok: true }; }
        case "run_grade_review": { if (!["owner","director","accountant","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select run_grade_review($1,$2) as n", [s.farmId, b.quarter]); return { ok: true, n: r.rows[0].n }; }
        case "sign_grade": { const r = await c.query("select sign_grade_review($1::uuid,$2,$3) as j", [b.id, s.staffId, b.slot]); return { ok: true, ...r.rows[0].j }; }
        case "reject_grade": { if (!["owner","director","tech_head","team_lead","accountant"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update grade_reviews set status='TU_CHOI', note=$3, decided_at=now() where id=$1 and farm_id=$2 and staff_id<>$4", [b.id, s.farmId, b.note ?? null, s.staffId]); return { ok: true }; }
        case "appeal_grade": { await c.query("update grade_reviews set status='KHANG_NGHI', appeal_note=$3 where id=$1 and farm_id=$2 and staff_id=$4", [b.id, s.farmId, b.note ?? null, s.staffId]); return { ok: true }; }
        case "plan_gs_rotation": { if (!["owner","director","auditor","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select plan_gs_rotation($1, current_date, $2) as n", [s.farmId, s.staffId]); return { ok: true, n: r.rows[0].n }; }
        case "key_position": { if (!["owner","director","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into key_positions(farm_id,code,title,dept,holder_id,min_grade,track) values ($1,$2,$3,$4,nullif($5,''),$6,$7) on conflict (farm_id,code,year) do update set title=excluded.title, dept=excluded.dept, holder_id=excluded.holder_id, min_grade=excluded.min_grade, track=excluded.track", [s.farmId, b.code, b.title, b.dept ?? null, b.holder_id ?? "", b.min_grade ?? "B3", b.track ?? "CM"]); return { ok: true }; }
        case "succession": { if (!["owner","director","it_engineer","tech_head"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into succession_plans(farm_id,key_position_id,successor_id,readiness,dev_plan,updated_by) values ($1,$2,$3,$4,$5,$6) on conflict (key_position_id,successor_id) do update set readiness=excluded.readiness, dev_plan=excluded.dev_plan, updated_at=now(), updated_by=excluded.updated_by", [s.farmId, b.key_position_id, b.successor_id, b.readiness ?? "2_NAM", b.dev_plan ?? null, s.staffId]); return { ok: true }; }
        case "initiative": { await c.query("insert into initiatives(farm_id,staff_id,title,benefit,description,kind) values ($1,$2,$3,$4,$5,$6)", [s.farmId, s.staffId, b.title, b.benefit ?? null, b.description ?? null, b.kind ?? "CAI_TIEN"]); return { ok: true }; }
        case "approve_initiative": { if (!["owner","director","tech_head","team_lead","auditor"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update initiatives set status='DUYET', approved_by=$3, approved_at=now() where id=$1 and farm_id=$2 and staff_id<>$3", [b.id, s.farmId, s.staffId]); return { ok: true }; }
        case "gs_field_day": { await c.query("insert into gs_field_days(farm_id,supervisor_id,day,block,dept,note) values ($1,$2,coalesce($3::date,current_date),$4,$5,$6) on conflict (supervisor_id,day) do update set block=excluded.block, dept=excluded.dept, note=excluded.note", [s.farmId, s.staffId, b.day ?? null, b.block ?? null, b.dept ?? null, b.note ?? null]); return { ok: true }; }
        case "rate_supervisor": { if (!["tech_head","team_lead","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into supervisor_ratings(farm_id,supervisor_id,rated_by,period,useful,fair,knows,note) values ($1,$2,$3,to_char(current_date,'YYYY-MM'),$4,$5,$6,$7) on conflict (supervisor_id,rated_by,period) do update set useful=excluded.useful, fair=excluded.fair, knows=excluded.knows, note=excluded.note", [s.farmId, b.supervisor_id, s.staffId, Number(b.useful), Number(b.fair), Number(b.knows), b.note ?? null]); return { ok: true }; }
        case "capa_set": { await c.query("update supervision_checks set corrective=$3, corrective_due=$4::date where id=$1 and farm_id=$2", [b.id, s.farmId, b.corrective, b.due ?? null]); return { ok: true }; }
        case "capa_verify": { await c.query("update supervision_checks set verified_by=$3, verified_at=now() where id=$1 and farm_id=$2 and supervisor_id<>$3 or (id=$1 and farm_id=$2 and $4 in ('auditor','director','owner'))", [b.id, s.farmId, s.staffId, s.role]); return { ok: true }; }
        case "gen_capa": { const r = await c.query("select gen_capa_tasks($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n }; }
        case "dependent_claim": { const n = Number(b.dependents); if (!(n >= 0 && n <= 20)) throw new Error("ERR_VALUE"); await c.query("insert into dependent_claims(farm_id,staff_id,dependents,note) values ($1,$2,$3,$4)", [s.farmId, s.staffId, n, b.note ?? null]); await c.query("insert into notifications(farm_id,staff_id,level,title,body,link,source) select $1, id, 'INFO', $2, $3, '/nhan-su?tab=bac', 'dependent' from staff where farm_id=$1 and dept='HCNS' and active limit 2", [s.farmId, `Khai người phụ thuộc: ${s.staffName} → ${n}`, String(b.note ?? "")]); return { ok: true }; }
        case "dependent_decide": { if (!["owner","director","accountant"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("update dependent_claims set status=$3, decided_by=$4, decided_at=now() where id=$1 and farm_id=$2 and staff_id<>$4 returning staff_id, dependents", [b.id, s.farmId, b.approve ? "DUYET" : "TU_CHOI", s.staffId]); if (b.approve && r.rows[0]) await c.query("update staff set dependents=$2 where id=$1", [r.rows[0].staff_id, r.rows[0].dependents]); return { ok: true }; }
        case "mkt_campaign": { if (b.id) { const sets: string[] = []; const vals: unknown[] = [b.id, s.farmId]; for (const k of ["name","status","budget","ends_on","starts_on","objective","audience","kpi_target","channels","note"]) if (b[k] !== undefined) { vals.push(k === "kpi_target" ? JSON.stringify(b[k]) : b[k]); sets.push(`${k}=$${vals.length}`); } if (sets.length) await c.query(`update mkt_campaigns set ${sets.join(",")} where id=$1 and farm_id=$2`, vals); return { ok: true }; }
          const r = await c.query("insert into mkt_campaigns(farm_id,code,name,objective,channels,audience,starts_on,ends_on,budget,kpi_target,status,owner_id,utm_code,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$12) returning id", [s.farmId, b.code, b.name, b.objective ?? null, b.channels ?? [], b.audience ?? null, b.starts_on ?? null, b.ends_on ?? null, Number(b.budget ?? 0), JSON.stringify(b.kpi_target ?? {}), b.status ?? "NHAP", s.staffId, String(b.code ?? "").toLowerCase()]); return { ok: true, id: r.rows[0].id }; }
        case "mkt_content": { if (b.id) { const sets: string[] = []; const vals: unknown[] = [b.id, s.farmId]; for (const k of ["status","approved_by","url","metrics","title","brief","planned_at","channel","kind","campaign_id","cost","note"]) if (b[k] !== undefined) { vals.push(k === "metrics" ? JSON.stringify(b[k]) : b[k]); sets.push(`${k}=$${vals.length}`); } if (b.status === "DUYET") { vals.push(s.staffId); sets.push(`approved_by=$${vals.length}`, "approved_at=now()"); } if (sets.length) await c.query(`update mkt_contents set ${sets.join(",")} where id=$1 and farm_id=$2`, vals); return { ok: true }; }
          const r = await c.query("insert into mkt_contents(farm_id,campaign_id,planned_at,channel,kind,title,brief,author_id,created_by,status) values ($1,$2,$3,$4,$5,$6,$7,$8,$8,'Y_TUONG') returning id", [s.farmId, b.campaign_id ?? null, b.planned_at, b.channel, b.kind ?? "BAI_VIET", b.title, b.brief ?? null, s.staffId]); return { ok: true, id: r.rows[0].id }; }
        case "mkt_asset": { await c.query("insert into mkt_assets(farm_id,kind,title,url,tags,version,created_by) values ($1,$2,$3,$4,$5,$6,$7)", [s.farmId, b.kind, b.title, b.url ?? null, b.tags ?? [], b.version ?? null, s.staffId]); return { ok: true }; }
        case "mkt_asset_approve": { if (!["tech_head","team_lead","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update mkt_assets set approved=true, approved_by=$3 where id=$1 and farm_id=$2 and created_by is distinct from $3", [b.id, s.farmId, s.staffId]); return { ok: true }; }
        case "mkt_mention": { const r = await c.query("insert into mkt_mentions(farm_id,channel,source_url,author,summary,sentiment,severity,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8) returning id", [s.farmId, b.channel, b.source_url ?? null, b.author ?? null, b.summary, b.sentiment ?? "TRUNG_TINH", b.severity ?? "THAP", s.staffId]); return { ok: true, id: r.rows[0].id }; }
        case "mkt_mention_update": { await c.query("update mkt_mentions set status=$3, response=coalesce($4,response), handler_id=$5, resolved_at=case when $3='DONG' then now() else resolved_at end where id=$1 and farm_id=$2", [b.id, s.farmId, b.status, b.response ?? null, s.staffId]); if (b.status === "DONG") await c.query("update tasks set status='XONG', done_by=$3, done_at=now() where farm_id=$1 and ref_table='mkt_mentions' and ref_id=$2 and status<>'XONG'", [s.farmId, b.id, s.staffId]); return { ok: true }; }
        case "gs_ack": { // GS đã xem lỗi hệ thống báo, kết luận (không lỗi / có lỗi) — tính là đã xử lý, hết bỏ sót
          const res = b.result === "LOI" ? "LOI" : "DAT"; const note = (res === "DAT" ? "[đã xem auto] " : "[từ dữ liệu auto] ") + String(b.note ?? "");
          const r = await c.query("insert into supervision_checks(farm_id, created_by, client_ref, supervisor_id, target_staff_id, criteria_id, week_start, item, result, severity, note) values ($1,$2,$3,$2,$4,$5,date_trunc('week', current_date)::date,$6,$7,$8,$9) returning id, points", [s.farmId, s.staffId, crypto.randomUUID(), b.staff_id, b.criteria_id, b.item ?? "auto", res, res === "LOI" ? (b.severity ?? "TRUNG") : null, note]); return { ok: true, ...r.rows[0] }; }
        case "sync_process_criteria": { if (!["owner","director","auditor","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select sync_process_criteria() as n"); return { ok: true, n: r.rows[0].n }; }
        case "gen_gs_omissions": { if (!["owner","director","auditor","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select gen_gs_omissions($1, coalesce($2::date, current_date-1)) as n", [s.farmId, b.day ?? null]); return { ok: true, n: r.rows[0].n }; }
        case "suggest_headcount": { if (!["owner","director","accountant","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select suggest_headcount($1,$2,$3) as n", [s.farmId, Number(b.year ?? new Date().getFullYear()), s.staffId]); return { ok: true, n: r.rows[0].n }; }
        case "headcount_set": { if (!["owner","director","accountant","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update headcount_plans set planned=$3, budget_month=$4 where id=$1 and farm_id=$2", [b.id, s.farmId, Number(b.planned), b.budget_month == null ? null : Number(b.budget_month)]); return { ok: true }; }
        case "close_contribution_bonus": { if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select close_contribution_bonus($1,$2,$3) as n", [s.farmId, b.quarter, s.staffId]); return { ok: true, n: r.rows[0].n }; }
        case "cross_check_submit": { const r = await c.query("select submit_cross_check($1::uuid,$2,$3,$4,$5) as j", [b.id, s.staffId, b.result, b.note ?? null, b.evidence_url ?? null]); return { ok: true, ...r.rows[0].j }; }
        case "gen_cross_checks": { if (!["owner","director","auditor","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const a = await c.query("select gen_cross_checks($1) as n", [s.farmId]); const b2 = await c.query("select gen_random_spot_checks($1) as n", [s.farmId]); const c2 = await c.query("select gen_collusion_audits($1) as n", [s.farmId]); return { ok: true, cross: a.rows[0].n, spots: b2.rows[0].n, audits: c2.rows[0].n }; }
        case "whistle": { const r = await c.query("select whistle_submit($1,$2,$3,$4,$5) as id", [s.farmId, b.category ?? "KHAC", b.target_dept ?? null, b.content, s.staffId]); return { ok: true, id: r.rows[0].id }; }
        case "whistle_handle": { if (!["owner","director"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update whistle_reports set status=$3, handled_by=$4, handled_at=now(), note=$5 where id=$1 and farm_id=$2", [b.id, s.farmId, b.status, s.staffId, b.note ?? null]); return { ok: true }; }
        case "delegate": { // ủy quyền thủ công (công tác/đi vắng): from mặc định = tôi
          if (!b.to || !b.from_date || !b.to_date) throw new Error("ERR_MISSING");
          const from = b.from && ["owner", "director", "tech_head", "team_lead"].includes(s.role) ? String(b.from) : s.staffId;
          if (from === b.to) throw new Error("ERR_SELF");
          const r = await c.query("select activate_delegation($1,$2,$3,$4::date,$5::date,$6,'MANUAL',null,$7) as id", [s.farmId, from, b.to, b.from_date, b.to_date, b.reason ?? "Ủy quyền", s.staffId]);
          return { ok: true, id: r.rows[0].id };
        }
        case "end_delegation": {
          await c.query("update staff_delegations set status='CANCELLED', ended_at=now(), to_date=least(to_date, current_date-1) where id=$1 and farm_id=$2 and status='ACTIVE' and (from_staff=$3 or to_staff=$3 or $4 in ('owner','director','tech_head','team_lead'))", [b.id, s.farmId, s.staffId, s.role]);
          await c.query("update tasks set assignee_id=detail->>'delegated_from', detail=detail - 'delegated_from' where farm_id=$1 and status in ('MO','DANG_LAM','TREO') and detail->>'delegation_id'=$2", [s.farmId, b.id]);
          return { ok: true }; }
        case "refresh_cache": { const r = await c.query("select refresh_farm_cache($1) as r", [s.farmId]); await c.query("delete from cache_dirty where farm_id=$1", [s.farmId]).catch(() => null); return { ok: true, ...r.rows[0].r }; }
        case "sup_check": { const r = await c.query("insert into supervision_checks(farm_id, created_by, client_ref, supervisor_id, target_dept, target_staff_id, sop_code, criteria_id, week_start, item, result, severity, note, evidence_url, corrective, corrective_due) values ($1,$2,$3,$2,$4,$5,$6,$7,date_trunc('week', current_date)::date,$8,$9,$10,$11,$12,$13,$14) returning id, points", [s.farmId, s.staffId, b.client_ref ?? crypto.randomUUID(), b.target_dept ?? null, b.target_staff_id ?? null, b.sop_code ?? null, b.criteria_id ?? null, b.item, b.result, b.severity ?? null, b.note ?? null, b.evidence_url ?? null, b.corrective ?? null, b.corrective_due ?? null]); await c.query("select run_supervision_auto($1, date_trunc('week', current_date)::date)", [s.farmId]).catch(() => null); return { ok: true, ...r.rows[0] }; }
        case "run_supervision": { const r = await c.query("select run_supervision_auto($1, coalesce($2::date, date_trunc('week', current_date)::date)) as n", [s.farmId, b.week ?? null]); return { ok: true, n: r.rows[0].n }; }
        case "complete_training": { const r = await c.query("select complete_training($1,$2,$3,$4,$5) as j", [b.id, Number(b.hours ?? 2), Number(b.score ?? 0), b.examiner_id ?? null, b.notes ?? null]); return { ok: true, ...r.rows[0].j }; }
        case "gen_training_week": { if (!["owner","director","tech_head","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select gen_training_week($1) as n", [s.farmId]); const r2 = await c.query("select gen_supervision_tasks($1) as n", [s.farmId]); return { ok: true, training: r.rows[0].n, supervision: r2.rows[0].n }; }
        case "close_bonus": { if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select close_bonus($1,$2) as n", [s.farmId, b.period]); return { ok: true, n: r.rows[0].n }; }
        case "apply_bonus": { if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select apply_bonus_to_payroll($1,$2::date) as n", [s.farmId, b.month]); return { ok: true, n: r.rows[0].n }; }
        case "compute_assumptions": { const r = await c.query("select compute_assumptions($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n }; }
        case "set_assumption": { if (!["owner","director","tech_head","accountant","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into plan_assumptions(farm_id, key, value, unit, source, note) values ($1,$2,$3,$4,'MANUAL',$5) on conflict (farm_id, key) do update set value=excluded.value, source=case when $3 is null then 'AUTO' else 'MANUAL' end, note=excluded.note, computed_at=now()", [s.farmId, b.key, b.value ?? null, b.unit ?? null, b.note ?? null]); if (b.value == null) await c.query("select compute_assumptions($1)", [s.farmId]); return { ok: true }; }
        case "close_plan": { if (!["owner","director","tech_head","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select close_plan($1) as n", [b.id]); return { ok: true, n: r.rows[0].n }; }
        case "publish_year_plan": { if (!["owner","director"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select publish_year_plan($1) as n", [b.id]); return { ok: true, n: r.rows[0].n }; }
        case "publish_plan": { if (!["director","owner","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select publish_plan($1) as n", [b.id]); return { ok: true, n: r.rows[0].n }; }
        case "pay_supplier": { if (!["director","owner","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select pay_supplier($1,$2,$3)", [b.id, Number(b.amount), b.ref ?? null]); return { ok: true }; }
        case "gen_loan_schedule": { const r = await c.query("select gen_loan_schedule($1) as n", [b.id]); return { ok: true, n: r.rows[0].n }; }
        case "pay_loan": { if (!["director","owner","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select pay_loan_installment($1,$2)", [b.id, b.ref ?? null]); return { ok: true }; }
        case "receive_claim": { if (!["director","owner","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select receive_claim($1,$2)", [b.id, Number(b.amount)]); return { ok: true }; }
        case "quote_to_order": { const r = await c.query("select quote_to_order($1) as id", [b.id]); return { ok: true, order_id: r.rows[0].id }; }
        case "send_quote": { await c.query("update quotes set status='GUI', sent_at=now() where id=$1 and farm_id=$2", [b.id, s.farmId]); await c.query("select publish_event($1,'quote.sent',$2::jsonb)", [s.farmId, JSON.stringify({ id: b.id })]); return { ok: true }; }
        case "run_dunning": { if (!["director","owner","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select run_dunning($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n }; }
        case "redeem_points": { const r = await c.query("select redeem_points($1,$2,$3) as bal", [b.partner_id, Number(b.points), b.ref ?? null]); return { ok: true, balance: r.rows[0].bal }; }
        case "gen_contract_deliveries": { const r = await c.query("select gen_contract_deliveries($1,$2) as n", [b.id, Number(b.every_days ?? 7)]); return { ok: true, n: r.rows[0].n }; }
        case "price_for": { const r = await c.query("select * from price_for($1,$2,$3,$4)", [s.farmId, b.partner_id ?? null, b.sku, Number(b.qty ?? 1)]); return { ok: true, ...r.rows[0] }; }
        case "approve_return": { if (!["director","owner","accountant","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select approve_return($1,$2)", [b.id, s.staffId]); return { ok: true }; }
        case "compute_payroll": { if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select compute_payroll($1,$2::date,$3) as id", [s.farmId, b.month, s.staffId]); return { ok: true, run_id: r.rows[0].id }; }
        case "approve_payroll": { if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select approve_payroll($1,$2)", [b.run_id, s.staffId]); return { ok: true }; }
        case "run_depreciation": { if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select run_depreciation($1, date_trunc('month', coalesce($2::date, now()))::date) as n", [s.farmId, b.month ?? null]); return { ok: true, n: r.rows[0].n }; }
        case "apply_landed_cost": { if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select apply_landed_cost($1) as n", [b.shipment_id]); return { ok: true, n: r.rows[0].n }; }
        default: throw new Error("ERR_UNKNOWN_ACTION");
      }
    });
    return NextResponse.json(out);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ error: msg.match(/ERR_[A-Z_]+/)?.[0] ?? "ERR", detail: msg }, { status: 400 });
  }
}
