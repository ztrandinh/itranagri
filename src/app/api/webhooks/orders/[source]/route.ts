import { NextResponse } from "next/server";
import { createHash } from "node:crypto";
import { adminPool } from "@/lib/db";
/** ĐẤU NỐI KÊNH BÁN ONLINE (Shopee · TikTok Shop · Lazada · Haravan/Sapo/Website · Zalo shop · Facebook): mọi đơn từ ngoài → 1 điểm nhận duy nhất
 *  POST /api/webhooks/orders/{source}  header x-api-key (scope 'orders')  body chuẩn hóa: { external_id, created_at?, customer:{name,phone,address,email?}, lines:[{sku|external_sku, name?, qty, price}], shipping_fee?, discount?, payment_status?, ship_to?, note? }
 *  Bộ chuyển đổi (Shopee/TikTok…) chạy ở middleware/Zapier/n8n hoặc app riêng → gọi vào đây theo mẫu chung; SKU ánh xạ qua products.attrs.external_skus hoặc trùng sku.
 *  Kết quả: partners (KH_ONLINE, upsert theo phone) → orders (channel_code=source, status NHAP, attrs.external) → event order.created → Kinh doanh (xác nhận) · Kho (soạn hàng FEFO) · D5 (lệnh SX nếu thiếu) · Kế toán (thu tiền/COD/đối soát sàn) · Chăm sóc khách. */
export async function POST(req: Request, { params }: { params: Promise<{ source: string }> }) {
  const { source } = await params; const key = req.headers.get("x-api-key") ?? ""; if (!key) return NextResponse.json({ error: "ERR_NO_KEY" }, { status: 401 });
  const p = adminPool(); const k = (await p.query("select * from api_keys where key_hash=$1 and revoked_at is null and ('orders' = any(scopes) or 'write' = any(scopes))", [createHash("sha256").update(key).digest("hex")])).rows[0];
  if (!k) return NextResponse.json({ error: "ERR_BAD_KEY" }, { status: 403 });
  const b = await req.json().catch(() => null); if (!b?.external_id || !Array.isArray(b.lines) || !b.lines.length) return NextResponse.json({ error: "ERR_BAD_BODY", need: "external_id, lines[]" }, { status: 400 });
  const farm = String(b.farm_id ?? k.farm_id ?? "F01"); const src = source.toUpperCase().replace(/[^A-Z0-9_]/g, "").slice(0, 20);
  const dup = (await p.query("select id from orders where farm_id=$1 and attrs->>'external_id'=$2 and attrs->>'source'=$3", [farm, String(b.external_id), src])).rows[0]; if (dup) return NextResponse.json({ ok: true, id: dup.id, duplicate: true });
  // Pre-check trên chỉ là fast-path, không đủ chống race giữa 2 lần sàn TMĐT gọi lại khi timeout —
  // orders_webhook_dedupe_ux (0194) là backstop DB thật, bắt unique_violation bên dưới ở lần insert cuối.
  // khách online: upsert theo SĐT
  const cust = b.customer ?? {}; let partnerId: string | null = null;
  if (cust.phone || cust.name) { const ex = cust.phone ? (await p.query("select id from partners where phone=$1 limit 1", [String(cust.phone)])).rows[0] : null; if (ex) partnerId = ex.id; else { partnerId = (await p.query("select next_code_free($1,'PT','partners',5) as c", [farm])).rows[0].c; await p.query("insert into partners(id,org_id,farm_id,kind,name,phone,address,email,channel,approved,active,attrs) values ($1,'ITRAN',$2,'KH',$3,$4,$5,$6,3,true,true,$7)", [partnerId, farm, String(cust.name ?? cust.phone), cust.phone ?? null, cust.address ?? b.ship_to ?? null, cust.email ?? null, JSON.stringify({ source: src })]); } }
  // ánh xạ SKU
  const lines: { sku: string; qty: number; price: number; name?: string }[] = [];
  for (const l of b.lines) { let sku = String(l.sku ?? ""); if (!sku && l.external_sku) { const m = (await p.query("select sku from products where attrs->'external_skus' ? $1 or sku=$1 limit 1", [String(l.external_sku)])).rows[0]; sku = m?.sku ?? ""; } if (!sku) { const m2 = (await p.query("select sku from products where noaccent(name) like noaccent($1) limit 1", [`%${String(l.name ?? "").slice(0, 30)}%`])).rows[0]; sku = m2?.sku ?? `UNMAPPED:${l.external_sku ?? l.name ?? "?"}`; } lines.push({ sku, qty: Number(l.qty ?? 1), price: Number(l.price ?? 0), name: l.name }); }
  const total = lines.reduce((a, l) => a + l.qty * l.price, 0) + Number(b.shipping_fee ?? 0) - Number(b.discount ?? 0);
  const id = (await p.query("select next_code_free($1,'DH','orders',5) as c", [farm])).rows[0].c;
  try {
    await p.query("insert into orders(id,farm_id,partner_id,channel,order_date,deliver_date,lines,total,status,cutoff_ok,created_by,note,attrs) values ($1,$2,$3,3,coalesce($4::date,current_date),$5,$6,$7,'NHAP',$8,$9,$10,$11)", [id, farm, partnerId, b.created_at ?? null, b.deliver_date ?? null, JSON.stringify(lines), total, new Date().getHours() < 15, `WEBHOOK:${src}`, b.note ?? null, JSON.stringify({ source: src, external_id: String(b.external_id), payment_status: b.payment_status ?? null, ship_to: b.ship_to ?? cust.address ?? null, shipping_fee: b.shipping_fee ?? 0, discount: b.discount ?? 0, unmapped: lines.filter((l) => l.sku.startsWith("UNMAPPED")).length })]);
  } catch (e) {
    if ((e as { code?: string }).code === "23505") { const again = (await p.query("select id from orders where farm_id=$1 and attrs->>'external_id'=$2 and attrs->>'source'=$3", [farm, String(b.external_id), src])).rows[0]; if (again) return NextResponse.json({ ok: true, id: again.id, duplicate: true }); }
    throw e;
  }
  await p.query("select publish_event($1,'order.created',$2)", [farm, JSON.stringify({ table: "orders", id, source: src, external_id: b.external_id, total, partner: cust.name ?? partnerId, unmapped: lines.filter((l) => l.sku.startsWith("UNMAPPED")).length })]);
  await p.query("update api_keys set last_used_at=now() where id=$1", [k.id]);
  return NextResponse.json({ ok: true, id, total, partner_id: partnerId, unmapped: lines.filter((l) => l.sku.startsWith("UNMAPPED")).map((l) => l.sku) });
}
