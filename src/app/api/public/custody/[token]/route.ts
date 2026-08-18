import { NextResponse } from "next/server";
import { adminPool } from "@/lib/db";
/** PORTAL KHÁCH NHẬN NUÔI (token trong HĐ): GET → HĐ, cá thể, sự kiện 90 ngày, ảnh, tin nhắn; POST {body} → tin nhắn cho trại (event customer.message) */
export async function GET(_req: Request, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params; const p = adminPool();
  const c = (await p.query("select c.*, pt.name as customer_name from custody_contracts c left join partners pt on pt.id=c.partner_id where c.portal_token=$1", [token])).rows[0];
  if (!c) return NextResponse.json({ error: "ERR_NOT_FOUND" }, { status: 404 });
  const ids: string[] = c.animal_ids ?? [];
  const animals = (await p.query("select id, species, breed, sex, birth_date, status, last_weight_kg, last_weight_at, visual_tag, photos, location_id from animals where id = any($1)", [ids])).rows;
  const events = (await p.query("select animal_id, ts, event_type, value, unit, detail, photo_urls from animal_events where animal_id = any($1) and status='ACTIVE' and ts > now() - interval '90 days' and event_type not in ('DIEU_TRI','BENH') order by ts desc limit 200", [ids])).rows;
  const health = (await p.query("select animal_id, count(*) filter (where event_type in ('DIEU_TRI','BENH')) as treatments, max(ts) filter (where event_type='VACCINE') as last_vaccine from animal_events where animal_id = any($1) and status='ACTIVE' group by 1", [ids])).rows;
  const msgs = (await p.query("select * from customer_messages where contract_id=$1 order by ts desc limit 50", [c.id])).rows;
  const live = (await p.query("select value from settings where key='custody.live_hours' order by (farm_id=$1) desc limit 1", [c.farm_id])).rows[0]?.value ?? ["08:00-10:00", "15:00-17:00"];
  return NextResponse.json({ contract: { id: c.id, kind: c.kind, package: c.package, start_date: c.start_date, end_date: c.end_date, status: c.status, customer: c.customer_name, farm: c.farm_id }, animals, events, health, messages: msgs, live_hours: live });
}
export async function POST(req: Request, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params; const p = adminPool(); const b = await req.json().catch(() => ({}));
  const c = (await p.query("select id, farm_id, animal_ids from custody_contracts where portal_token=$1", [token])).rows[0]; if (!c) return NextResponse.json({ error: "ERR_NOT_FOUND" }, { status: 404 });
  const body = String(b.body ?? "").slice(0, 1000); if (!body) return NextResponse.json({ error: "ERR_EMPTY" }, { status: 400 });
  await p.query("insert into customer_messages(farm_id,contract_id,animal_id,from_customer,body) values ($1,$2,$3,true,$4)", [c.farm_id, c.id, b.animal_id ?? (c.animal_ids ?? [])[0] ?? null, body]);
  await p.query("select publish_event($1,'customer.message',$2)", [c.farm_id, JSON.stringify({ contract: c.id, body })]);
  return NextResponse.json({ ok: true });
}
