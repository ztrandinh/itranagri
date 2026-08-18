import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
import { dispatchEvents } from "@/lib/notify";
/** GET hộp thư của tôi (+ đếm chưa đọc); POST {ids|all} đánh dấu đã đọc; PUT prefs */
export async function GET(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const u = new URL(req.url); if (u.searchParams.get("dispatch")) await dispatchEvents();
  const r = await withCtx(s, async (c) => ({
    rows: (await c.query("select * from notifications where staff_id=$1 order by ts desc limit 100", [s.staffId])).rows,
    unread: Number((await c.query("select count(*) as n from notifications where staff_id=$1 and read_at is null", [s.staffId])).rows[0].n),
    prefs: (await c.query("select * from notification_prefs where staff_id=$1", [s.staffId])).rows,
  }));
  return NextResponse.json(r);
}
export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const b = await req.json();
  await withCtx(s, async (c) => { if (b.all) await c.query("update notifications set read_at=now() where staff_id=$1 and read_at is null", [s.staffId]); else await c.query("update notifications set read_at=now() where staff_id=$1 and id = any($2::uuid[])", [s.staffId, b.ids ?? []]); });
  return NextResponse.json({ ok: true });
}
export async function PUT(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const b = await req.json();
  await withCtx(s, async (c) => c.query("insert into notification_prefs(staff_id,rule_code,level_min,channels,quiet_from,quiet_to,muted) values ($1,$2,$3,$4,$5,$6,$7) on conflict (staff_id,rule_code) do update set level_min=excluded.level_min, channels=excluded.channels, quiet_from=excluded.quiet_from, quiet_to=excluded.quiet_to, muted=excluded.muted",
    [s.staffId, b.rule_code ?? "*", b.level_min ?? "XANH", b.channels ?? ["app"], b.quiet_from ?? null, b.quiet_to ?? null, !!b.muted]));
  return NextResponse.json({ ok: true });
}
