import { NextResponse } from "next/server";
import { adminPool } from "@/lib/db";
/** PORTAL ĐỐI TÁC (khách B2B / NCC) theo token: GET → hồ sơ, đơn, công nợ, lô + COA + chứng nhận; POST {lines:[{sku,qty}], deliver_date, note} → tạo đơn (orders) + event order.created */
export async function GET(_req: Request, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params; const p = adminPool();
  const pt = (await p.query("select id, name, kind, farm_id, phone, credit_limit, credit_days, approved from partners where portal_token=$1 and active", [token])).rows[0]; if (!pt) return NextResponse.json({ error: "ERR_NOT_FOUND" }, { status: 404 });
  const farm = pt.farm_id ?? "F01";
  const orders = (await p.query("select id, order_date, deliver_date, lines, total, status, note from orders where partner_id=$1 order by order_date desc limit 50", [pt.id])).rows;
  const sales = (await p.query("select ts, sku, lot_id, qty, price, amount, paid, invoice_no from sales where partner_id=$1 and status='ACTIVE' order by ts desc limit 100", [pt.id])).rows;
  const receivable = (await p.query("select coalesce(sum(amount),0) as v from sales where partner_id=$1 and status='ACTIVE' and not paid", [pt.id])).rows[0].v;
  const products = (await p.query("select pr.sku, pr.name, pr.unit, pl.price from products pr left join lateral (select price from price_list where (subject=pr.sku or sku=pr.sku) order by (kind='NIEM_YET') desc, valid_from desc nulls last limit 1) pl on true where pr.active and pr.kind in ('THANH_PHAM','LANH') order by pr.name")).rows;
  const certs = (await p.query("select s.name, c.cert_number, c.body, c.valid_to, c.status from certifications c join standards s on s.code=c.standard_code where (c.farm_id=$1 or c.farm_id is null) and c.status='HIEU_LUC'", [farm])).rows;
  const icfs = (await p.query("select pct, level from v_icfs_summary where farm_id=$1", [farm])).rows[0];
  const lots = (await p.query("select distinct l.id, l.sku, l.mfg_date, l.expiry_date, l.coa_url from sales s join lots l on l.id=s.lot_id where s.partner_id=$1 order by l.mfg_date desc nulls last limit 30", [pt.id])).rows;
  return NextResponse.json({ partner: pt, orders, sales, receivable, products, certs, icfs, lots });
}
export async function POST(req: Request, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params; const p = adminPool(); const b = await req.json().catch(() => ({}));
  const pt = (await p.query("select id, farm_id, name from partners where portal_token=$1 and active", [token])).rows[0]; if (!pt) return NextResponse.json({ error: "ERR_NOT_FOUND" }, { status: 404 });
  const lines = (Array.isArray(b.lines) ? b.lines : []).filter((l: { sku?: string; qty?: number }) => l.sku && Number(l.qty) > 0); if (!lines.length) return NextResponse.json({ error: "ERR_EMPTY" }, { status: 400 });
  const farm = pt.farm_id ?? "F01"; const priced = [] as { sku: string; qty: number; price: number }[];
  for (const l of lines) { const pr = (await p.query("select price from price_list where (subject=$1 or sku=$1) order by (kind='NIEM_YET') desc, valid_from desc nulls last limit 1", [l.sku])).rows[0]; priced.push({ sku: l.sku, qty: Number(l.qty), price: Number(pr?.price ?? 0) }); }
  const total = priced.reduce((a, l) => a + l.qty * l.price, 0); const id = (await p.query("select next_code_free($1,'DH','orders',5) as c", [farm])).rows[0].c;
  await p.query("insert into orders(id,farm_id,partner_id,channel,order_date,deliver_date,lines,total,status,cutoff_ok,created_by,note) values ($1,$2,$3,1,current_date,$4,$5,$6,'NHAP',$7,$8,$9)", [id, farm, pt.id, b.deliver_date ?? null, JSON.stringify(priced), total, new Date().getHours() < 15, "PORTAL:" + pt.id, b.note ?? null]);
  await p.query("select publish_event($1,'order.created',$2)", [farm, JSON.stringify({ table: "orders", id, partner: pt.name, total, source: "portal" })]);
  return NextResponse.json({ ok: true, id, total });
}
