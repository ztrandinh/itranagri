import type { PoolClient } from "pg";
import type { Session } from "@/lib/auth";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type B = any;
export type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;

export const createOrder: ActionHandler = async (c, s, b) => {
  const id = (await c.query("select next_code($1,'DH',5) as c", [s.farmId])).rows[0].c;
          const total = (b.lines as { qty: number; price: number }[]).reduce((a, l) => a + Number(l.qty) * Number(l.price), 0);
          const cutoff = (await c.query("select value from settings where key='order.cutoff' and farm_id in ('GLOBAL',$1) order by (farm_id=$1) desc, version desc limit 1", [s.farmId])).rows[0]?.value ?? "15:00";
          const nowHM = new Date().toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: "Asia/Ho_Chi_Minh" });
          await c.query("insert into orders(id,farm_id,partner_id,channel,deliver_date,lines,total,status,cutoff_ok,created_by,note) values ($1,$2,$3,$4,$5,$6,$7,'CHOT',$8,$9,$10)", [id, s.farmId, b.partner_id, b.channel ?? 1, b.deliver_date ?? null, JSON.stringify(b.lines), total, nowHM <= String(cutoff).replace(/"/g, ""), s.staffId, b.note ?? null]);
          return { ok: true, id, total };
};

export const orderStatus: ActionHandler = async (c, s, b) => {
  // Trước đây không kiểm role nào — auditor (vai chỉ-đọc theo thiết kế RLS) có thể đổi trạng thái
          // đơn hàng bất kỳ, kể cả kích hoạt LENH_SX. Chặn tối thiểu: auditor không được ghi/đổi trạng thái.
          if (s.role === "auditor") throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("update orders set status=$2 where id=$1 and farm_id=$3", [b.id, b.status, s.farmId]); if (b.status === "LENH_SX") await c.query("insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,due_at,priority,source,rule_code) values ($1,'LENH_SX','Lệnh sản xuất/đóng gói đơn '||$2,'order',$2,'worker:A7',now()+interval '18 hours','CAO','ORDER','LSX-'||$2)", [s.farmId, b.id]); return { ok: true };
};

export const createContract: ActionHandler = async (c, s, b) => {
  // Hợp đồng bao tiêu/cam kết — không có bước "approve_contract" riêng nào khác trong toàn
          // bộ file này để chốt chặn sau, nên phải chặn ngay ở tạo. Dùng đúng role set sell_livestock
          // (hành động cam kết tài sản/quan hệ tương đương) — worker không được tạo hợp đồng.
          if (!["team_lead","tech_head","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const id = (await c.query("select next_code($1,'HD',4) as c", [s.farmId])).rows[0].c;
          await c.query("insert into contracts(id,farm_id,partner_id,kind,sku,qty_committed,unit,price,start_date,end_date,note,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)", [id, s.farmId, b.partner_id, b.kind ?? "BAO_TIEU", b.sku ?? null, b.qty_committed ?? null, b.unit ?? null, b.price ?? null, b.start_date ?? null, b.end_date ?? null, b.note ?? null, s.staffId]);
          return { ok: true, id };
};

export const createCustody: ActionHandler = async (c, s, b) => {
  // Ký gửi/nhận nuôi có phí + thay đổi owner_type vật nuôi — cùng lý do với create_contract.
          if (!["team_lead","tech_head","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const id = (await c.query("select next_code($1,'NN',4) as c", [s.farmId])).rows[0].c;
          await c.query("insert into custody_contracts(id,farm_id,partner_id,kind,animal_ids,package,fee,period_months,prepaid,start_date,end_option,consent_at,note,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,current_date,$10,now(),$11,$12)", [id, s.farmId, b.partner_id, b.kind ?? "NHAN_NUOI", b.animal_ids ?? [], b.package ?? null, b.fee ?? null, b.period_months ?? null, b.prepaid ?? null, b.end_option ?? null, b.note ?? null, s.staffId]);
          for (const aid of (b.animal_ids ?? []) as string[]) { await c.query("update animals set owner_type=$2 where id=$1", [aid, b.kind === "KY_GUI" ? "KHACH" : "DONG_SO_HUU"]); await c.query("insert into animal_ownership(animal_id,partner_id,pct,contract_id) values ($1,$2,$3,null)", [aid, b.partner_id, b.kind === "KY_GUI" ? 100 : 50]); }
          return { ok: true, id };
};

export const replyCustomer: ActionHandler = async (c, s, b) => {
  await c.query("insert into customer_messages(farm_id,contract_id,animal_id,from_customer,body,replied_by,replied_at) values ($1,$2,$3,false,$4,$5,now())", [s.farmId, b.contract_id, b.animal_id ?? null, b.body, s.staffId]); await c.query("update customer_messages set replied_by=$2, replied_at=now() where id=$1", [b.reply_to, s.staffId]); return { ok: true };
};

export const shipOrder: ActionHandler = async (c, s, b) => {
  const r = await c.query("select ship_order($1,$2) as n", [b.id, s.staffId]); return { ok: true, n: r.rows[0].n };
};

export const quoteToOrder: ActionHandler = async (c, s, b) => {
  const r = await c.query("select quote_to_order($1) as id", [b.id]); return { ok: true, order_id: r.rows[0].id };
};

export const sendQuote: ActionHandler = async (c, s, b) => {
  await c.query("update quotes set status='GUI', sent_at=now() where id=$1 and farm_id=$2", [b.id, s.farmId]); await c.query("select publish_event($1,'quote.sent',$2::jsonb)", [s.farmId, JSON.stringify({ id: b.id })]); return { ok: true };
};

export const redeemPoints: ActionHandler = async (c, s, b) => {
  const r = await c.query("select redeem_points($1,$2,$3) as bal", [b.partner_id, Number(b.points), b.ref ?? null]); return { ok: true, balance: r.rows[0].bal };
};

export const genContractDeliveries: ActionHandler = async (c, s, b) => {
  const r = await c.query("select gen_contract_deliveries($1,$2) as n", [b.id, Number(b.every_days ?? 7)]); return { ok: true, n: r.rows[0].n };
};

export const priceFor: ActionHandler = async (c, s, b) => {
  const r = await c.query("select * from price_for($1,$2,$3,$4)", [s.farmId, b.partner_id ?? null, b.sku, Number(b.qty ?? 1)]); return { ok: true, ...r.rows[0] };
};

