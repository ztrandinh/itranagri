import io, os
R = "F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R + p) or R, exist_ok=True); io.open(R + p, "w", encoding="utf-8", newline="\n").write(s); print("w", p)
def rw(p, fn): s = io.open(R + p, encoding="utf-8").read(); n = fn(s); assert n != s, p; io.open(R + p, "w", encoding="utf-8", newline="\n").write(n); print("ok", p)
# migration push subs
w("supabase/migrations/0038_push_health.sql", '''-- 0038 · Web Push subscriptions (thông báo nổi trên điện thoại kể cả khi đóng app) + health checks log
create table if not exists push_subscriptions(id uuid primary key default gen_random_uuid(), staff_id text not null, endpoint text not null unique, p256dh text not null, auth text not null, ua text, created_at timestamptz default now(), last_ok timestamptz, fail_count int default 0);
alter table push_subscriptions enable row level security; drop policy if exists p_all on push_subscriptions; create policy p_all on push_subscriptions for all using (staff_id=app_staff() or app_role() in ('owner','it_engineer')) with check (true); grant select, insert, update, delete on push_subscriptions to app_user;
alter table notification_deliveries drop constraint if exists notification_deliveries_channel_check;
''')
# API push subscribe
w("src/app/api/push/route.ts", '''import { NextResponse } from "next/server";
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
''')
# health
w("src/app/api/health/route.ts", '''import { NextResponse } from "next/server";
import { adminPool } from "@/lib/db";
/** HEALTH: DB, số event chưa xử lý, job đêm gần nhất, backup gần nhất, cảnh báo ĐỎ mở, dung lượng DB — dùng cho uptime monitor / docker healthcheck */
export async function GET() {
  const t0 = Date.now(); const out: Record<string, unknown> = { ok: true, ts: new Date().toISOString(), version: process.env.APP_VERSION ?? "dev" };
  try { const p = adminPool();
    out.db_ms = Date.now() - t0; out.db = (await p.query("select 1")).rowCount === 1;
    out.event_bus_pending = Number((await p.query("select count(*) from event_bus where processed_at is null")).rows[0].count);
    out.last_job = (await p.query("select job, farm_id, finished_at, ok from job_runs order by finished_at desc nulls last limit 1")).rows[0] ?? null;
    out.last_backup = (await p.query("select finished_at from job_runs where job='backup' order by finished_at desc nulls last limit 1")).rows[0]?.finished_at ?? null;
    out.red_alerts_open = Number((await p.query("select count(*) from alerts where level='DO' and acked_at is null")).rows[0].count);
    out.db_size = (await p.query("select pg_size_pretty(pg_database_size(current_database())) as s")).rows[0].s;
    out.push_failed = Number((await p.query("select count(*) from notification_deliveries where channel='push' and status='FAILED' and ts>now()-interval '1 day'")).rows[0].count);
    const staleBackup = !out.last_backup || Date.now() - new Date(String(out.last_backup)).getTime() > 2 * 86400e3; out.warnings = [...(staleBackup ? ["backup > 48h"] : []), ...(Number(out.event_bus_pending) > 500 ? ["event_bus tồn > 500"] : [])];
    return NextResponse.json(out, { status: 200 });
  } catch (e) { return NextResponse.json({ ok: false, error: (e as Error).message }, { status: 503 }); }
}
''')
rw("src/proxy.ts", lambda s: s.replace('pathname.startsWith("/api/webhooks/") ||', 'pathname.startsWith("/api/webhooks/") || pathname === "/api/health" ||'))
# channels: push delivery
def ch(s):
    s = s.replace('import { adminPool } from "./db";', 'import { adminPool } from "./db";\nimport webpush from "web-push";')
    s = s.replace('/** Đẩy notifications có kênh zalo/sms/email chưa gửi', '''/** WEB PUSH: mọi notification mới (2 ngày) chưa push → gửi tới các subscription của staff (thông báo nổi trên điện thoại) */
export async function deliverPush(limit = 300): Promise<{ sent: number; failed: number }> {
  const pub = process.env.VAPID_PUBLIC_KEY ?? process.env.NEXT_PUBLIC_VAPID_KEY, priv = process.env.VAPID_PRIVATE_KEY; if (!pub || !priv) return { sent: 0, failed: 0 };
  webpush.setVapidDetails(process.env.VAPID_SUBJECT ?? "mailto:admin@itran.farm", pub, priv);
  const p = adminPool(); let sent = 0, failed = 0;
  const rows = (await p.query("select n.id, n.staff_id, n.title, n.body, n.link, n.level from notifications n where n.ts > now() - interval '2 days' and not exists (select 1 from notification_deliveries d where d.notification_id=n.id and d.channel='push') order by n.ts limit $1", [limit])).rows;
  for (const n of rows) {
    const subs = (await p.query("select * from push_subscriptions where staff_id=$1 and fail_count < 5", [n.staff_id])).rows;
    if (!subs.length) { await p.query("insert into notification_deliveries(notification_id,channel,status,error) values ($1,'push','SKIPPED','không có subscription')", [n.id]); continue; }
    for (const s of subs) { try { await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify({ title: n.title, body: n.body ?? "", url: n.link ?? "/", level: n.level, id: n.id }), { TTL: 3600 }); await p.query("update push_subscriptions set last_ok=now(), fail_count=0 where id=$1", [s.id]); sent++; }
      catch (e) { const code = (e as { statusCode?: number }).statusCode; if (code === 404 || code === 410) await p.query("delete from push_subscriptions where id=$1", [s.id]); else await p.query("update push_subscriptions set fail_count=fail_count+1 where id=$1", [s.id]); failed++; } }
    await p.query("insert into notification_deliveries(notification_id,channel,to_addr,status,provider,sent_at) values ($1,'push',$2,$3,'webpush',now())", [n.id, `${subs.length} thiết bị`, failed ? "FAILED" : "SENT"]);
  }
  return { sent, failed };
}
/** Đẩy notifications có kênh zalo/sms/email chưa gửi''')
    s = s.replace('  await deliverWebhooks();\n  return { queued, sent, failed, skipped };', '  await deliverWebhooks(); await deliverPush();\n  return { queued, sent, failed, skipped };')
    return s
rw("src/lib/channels.ts", ch)
# SW: push handler + notificationclick
rw("public/sw.js", lambda s: s + '''
// WEB PUSH: hiện thông báo nổi + mở đúng trang khi bấm
self.addEventListener("push", (e) => { let d = {}; try { d = e.data ? e.data.json() : {}; } catch { d = { title: "ITRAN OS", body: e.data && e.data.text() }; }
  e.waitUntil(self.registration.showNotification(d.title || "ITRAN OS", { body: d.body || "", icon: "/icon.svg", badge: "/icon.svg", tag: d.id || undefined, data: { url: d.url || "/" }, vibrate: d.level === "DO" ? [200, 100, 200] : [80], requireInteraction: d.level === "DO" })); });
self.addEventListener("notificationclick", (e) => { e.notification.close(); const url = (e.notification.data && e.notification.data.url) || "/"; e.waitUntil(clients.matchAll({ type: "window", includeUncontrolled: true }).then((ws) => { for (const w of ws) { if ("focus" in w) { w.navigate(url); return w.focus(); } } return clients.openWindow(url); })); });
''')
# Bell: enable push button
def bell(s):
    return s.replace('<button className="underline" onClick={async () => { await fetch("/api/notifications", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ all: true }) }); load(); }}>đã đọc hết</button>', '<button className="underline" onClick={async () => { await fetch("/api/notifications", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ all: true }) }); load(); }}>đã đọc hết</button><button className="underline" title="Nhận thông báo nổi trên điện thoại kể cả khi đóng app" onClick={async () => { try { const perm = await Notification.requestPermission(); if (perm !== "granted") return alert("Bạn chưa cho phép thông báo"); const reg = await navigator.serviceWorker.ready; const { key } = await fetch("/api/push").then((r) => r.json()); if (!key) return alert("Máy chủ chưa cấu hình VAPID"); const sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key }); await fetch("/api/push", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ subscription: sub }) }); alert("Đã bật thông báo nổi trên thiết bị này"); } catch (e) { alert("Không bật được: " + (e as Error).message); } }}>🔔 bật push</button>')
rw("src/components/panels/Notify.tsx", bell)
# QR scan in ThreeTap search
def tt(s):
    s = s.replace('"use client";', '"use client";\nimport QrScan from "@/components/QrScan";', 1) if 'import QrScan' not in s else s
    return s.replace('<input className="input" autoFocus placeholder="Quét QR/RFID hoặc gõ mã / tên (không dấu được)" value={search} onChange={(e) => setSearch(e.target.value)}', '<div className="flex gap-2"><QrScan onResult={(v) => setSearch(v)} /><input className="input" autoFocus placeholder="Quét QR/RFID hoặc gõ mã / tên (không dấu được)" value={search} onChange={(e) => setSearch(e.target.value)}')
rw("src/components/ThreeTap.tsx", tt)
# search box header: QR button
rw("src/components/Search.tsx", lambda s: s.replace('import { useEffect, useRef, useState } from "react";', 'import { useEffect, useRef, useState } from "react";\nimport QrScan from "@/components/QrScan";').replace('  return (<div className={`relative ${big ? "" : "hidden md:block"}`}>', '  return (<div className={`relative flex items-center gap-1 ${big ? "" : "hidden md:flex"}`}><QrScan className={big ? "btn-secondary !py-2 !px-3" : "rounded-lg border border-slate-300 px-2 py-1 text-sm"} onResult={(v) => { setQ(v); }} />'))
# restore drill doc + script
w("scripts/restore.md", '''# Diễn tập phục hồi (Restore drill) — làm mỗi quý, ghi vào compliance_checks (ICFS 6.4)

## Sao lưu đang có
- `backups/itranos-YYYY-MM-DD.dump` (pg_dump -Fc toàn DB) và `backups/{FARM}/{FARM}-YYYY-MM-DD.zip` (CSV mọi bảng + MANIFEST sha256) — cả ở `BACKUP_DIR` (ổ khác/NAS).
- Job: 01:15 hằng đêm (`instrumentation.ts`) hoặc `POST /api/jobs/backup?farm=F01` (x-job-key).

## Phục hồi thử vào DB tạm (không đụng DB thật)
```bash
docker exec itranos_db psql -U postgres -c "drop database if exists itranos_restore; create database itranos_restore"
docker cp backups/itranos-2026-08-18.dump itranos_db:/tmp/r.dump
docker exec itranos_db pg_restore -U postgres -d itranos_restore --no-owner /tmp/r.dump
docker exec itranos_db psql -U postgres -d itranos_restore -c "select count(*) animals from animals; select max(ts) last_event from animal_events;"
```
Kiểm: số con, sự kiện cuối, sổ cái cân (`select sum(debit)-sum(credit) from v_gl_ledger`) trùng DB thật tại thời điểm dump → ĐẠT. Ghi kết quả vào /tuan-thu (ITRAN-STD 6.4).

## Phục hồi thật (sự cố)
1. Dừng app; 2. `pg_restore -c -d itranos` bản dump gần nhất; 3. chạy `pnpm db:migrate` (bù migration mới); 4. bật app, kiểm `/api/health`; 5. bù dữ liệu từ hàng đợi offline điện thoại (tự đồng bộ) và phiếu giấy.
''')
w("scripts/restore-drill.sh", '''#!/usr/bin/env bash
# Diễn tập phục hồi: restore dump mới nhất vào DB tạm và so đếm. Dùng: bash scripts/restore-drill.sh [container]
set -e; C=${1:-itranos_db}; D=$(ls -t backups/*.dump | head -1); echo "dump: $D"
docker exec $C psql -U postgres -c "drop database if exists itranos_restore" -c "create database itranos_restore" >/dev/null
docker cp "$D" $C:/tmp/r.dump && docker exec $C pg_restore -U postgres -d itranos_restore --no-owner /tmp/r.dump 2>/dev/null || true
for t in animals animal_events inventory_moves sales journal_entries; do a=$(docker exec $C psql -U postgres -d itranos -Atc "select count(*) from $t"); b=$(docker exec $C psql -U postgres -d itranos_restore -Atc "select count(*) from $t"); echo "$t: live=$a restored=$b"; done
docker exec $C psql -U postgres -c "drop database itranos_restore" >/dev/null; echo "OK — ghi kết quả vào /tuan-thu (ITRAN-STD 6.4)"
''')
