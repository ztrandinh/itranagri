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
        default: throw new Error("ERR_UNKNOWN_ACTION");
      }
    });
    return NextResponse.json(out);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ error: msg.match(/ERR_[A-Z_]+/)?.[0] ?? "ERR", detail: msg }, { status: 400 });
  }
}
