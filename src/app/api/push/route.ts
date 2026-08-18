import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { adminPool } from "@/lib/db";
/** Web Push: GET → VAPID public key; POST {subscription} → lưu; DELETE {endpoint} → hủy */
export async function GET() { return NextResponse.json({ key: process.env.NEXT_PUBLIC_VAPID_KEY ?? process.env.VAPID_PUBLIC_KEY ?? null }); }
export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const b = await req.json().catch(() => null); const sub = b?.subscription; if (!sub?.endpoint || !sub?.keys?.p256dh) return NextResponse.json({ error: "ERR_BAD_SUB" }, { status: 400 });
  await adminPool().query("insert into push_subscriptions(staff_id,endpoint,p256dh,auth,ua) values ($1,$2,$3,$4,$5) on conflict (endpoint) do update set staff_id=excluded.staff_id, p256dh=excluded.p256dh, auth=excluded.auth, fail_count=0", [s.staffId, sub.endpoint, sub.keys.p256dh, sub.keys.auth, req.headers.get("user-agent")?.slice(0, 200) ?? null]);
  return NextResponse.json({ ok: true });
}
export async function DELETE(req: Request) { const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 }); const b = await req.json().catch(() => ({})); await adminPool().query("delete from push_subscriptions where endpoint=$1 and staff_id=$2", [b.endpoint, s.staffId]); return NextResponse.json({ ok: true }); }
