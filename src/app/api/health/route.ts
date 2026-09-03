import { NextResponse } from "next/server";
import { adminPool } from "@/lib/db";
/** HEALTH: DB, số event chưa xử lý, job đêm gần nhất, backup gần nhất, cảnh báo ĐỎ mở, dung lượng DB — dùng cho uptime monitor / docker healthcheck */
export async function GET() {
  const t0 = Date.now(); const out: Record<string, unknown> = { ok: true, ts: new Date().toISOString(), version: process.env.APP_VERSION ?? "dev" };
  try { const p = adminPool();
    out.db_ms = Date.now() - t0; out.db = (await p.query("select 1")).rowCount === 1;
    out.event_bus_pending = Number((await p.query("select count(*) from event_bus where processed_at is null")).rows[0].count);
    // dead_letter_at (0197): sự kiện đã thử lại đủ số lần vẫn lỗi — trước đây các lỗi này bị đánh
    // "processed_at" ngay lập tức, mất hẳn, không nơi nào đọc lại. Nay hiện trong health + cảnh báo.
    out.event_bus_dead_letter_24h = Number((await p.query("select count(*) from event_bus where dead_letter_at > now() - interval '24 hours'")).rows[0].count);
    out.last_job = (await p.query("select job, farm_id, finished_at, ok from job_runs order by finished_at desc nulls last limit 1")).rows[0] ?? null;
    out.last_backup = (await p.query("select finished_at from job_runs where job='backup' order by finished_at desc nulls last limit 1")).rows[0]?.finished_at ?? null;
    // job_runs>0 trong 24h qua = cron còn sống (setInterval/instrumentation.ts hay Vercel Cron, dù chạy đường nào);
    // failed_jobs_24h = job_runs.ok=false ghi lại từ 0190 (trước đây farm lỗi giữa chừng không để lại dấu vết nào).
    out.jobs_last_24h = Number((await p.query("select count(*) from job_runs where finished_at > now() - interval '24 hours'")).rows[0].count);
    out.failed_jobs_24h = (await p.query("select job, farm_id, finished_at from job_runs where ok=false and finished_at > now() - interval '24 hours' order by finished_at desc limit 20")).rows;
    out.red_alerts_open = Number((await p.query("select count(*) from alerts where level='DO' and acked_at is null")).rows[0].count);
    out.db_size = (await p.query("select pg_size_pretty(pg_database_size(current_database())) as s")).rows[0].s;
    out.push_failed = Number((await p.query("select count(*) from notification_deliveries where channel='push' and status='FAILED' and ts>now()-interval '1 day'")).rows[0].count);
    const staleBackup = !out.last_backup || Date.now() - new Date(String(out.last_backup)).getTime() > 2 * 86400e3;
    const staleJobs = Number(out.jobs_last_24h) === 0;
    out.warnings = [...(staleBackup ? ["backup > 48h"] : []), ...(Number(out.event_bus_pending) > 500 ? ["event_bus tồn > 500"] : []), ...(staleJobs ? ["job đêm KHÔNG chạy lần nào trong 24h qua — kiểm tra scheduler/cron"] : []), ...((out.failed_jobs_24h as unknown[]).length ? [`${(out.failed_jobs_24h as unknown[]).length} lượt job lỗi trong 24h qua`] : []), ...(Number(out.event_bus_dead_letter_24h) > 0 ? [`${out.event_bus_dead_letter_24h} sự kiện event_bus dead-letter (đã thử lại đủ số lần vẫn lỗi) trong 24h qua`] : [])];
    return NextResponse.json(out, { status: 200 });
  } catch (e) { return NextResponse.json({ ok: false, error: (e as Error).message }, { status: 503 }); }
}
