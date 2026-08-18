import { NextResponse } from "next/server";
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
