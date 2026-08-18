import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { runRecon, runAlerts, backfillAgg } from "@/lib/jobs";
import { deliverChannels } from "@/lib/channels";
import { dispatchEvents } from "@/lib/notify";
import { adminPool } from "@/lib/db";
import JSZip from "jszip";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { createHash } from "node:crypto";
/** POST /api/jobs/{recon|alerts|tasks|all}?farm=F01&date=YYYY-MM-DD — chạy tay (KTT/GĐ/KS CN) hoặc cron với header x-job-key */
export async function POST(req: Request, { params }: { params: Promise<{ job: string }> }) {
  const { job } = await params; const url = new URL(req.url);
  const s = await getSession(); const key = req.headers.get("x-job-key");
  if (!s && key !== (process.env.JOB_KEY ?? "dev-job-key")) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  if (s && !["tech_head","director","owner","it_engineer"].includes(s.role)) return NextResponse.json({ error: "ERR_FORBIDDEN_ROLE" }, { status: 403 });
  const farms = url.searchParams.get("farm") ? [url.searchParams.get("farm")!] : (await adminPool().query("select id from farms where status='ACTIVE'")).rows.map((r) => r.id as string);
  const date = url.searchParams.get("date") ?? new Date(Date.now() - 86400e3).toISOString().slice(0, 10);
  const out: Record<string, unknown> = {};
  for (const f of farms) {
    if (job === "recon" || job === "all") out[`recon:${f}`] = await runRecon(f, date);
    if (job === "alerts" || job === "all") out[`alerts:${f}`] = await runAlerts(f);
    if (job === "backup") {
      // xuất CSV toàn bộ bảng của trại → backups/{farm}/{date}.zip (P4 dữ liệu công ty; sao chép ra ổ ngoài hằng tuần)
      const zip = new JSZip(); const tables = (await adminPool().query("select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE' and table_name not like 'sensor_reads_2%'")).rows.map((r) => r.table_name as string);
      const manifest: Record<string, string> = {};
      for (const t of tables) { const hasFarm = (await adminPool().query("select 1 from information_schema.columns where table_name=$1 and column_name='farm_id'", [t])).rows.length > 0; const rows = (await adminPool().query(hasFarm ? `select * from ${t} where farm_id=$1` : `select * from ${t}`, hasFarm ? [f] : [])).rows as Record<string, unknown>[]; if (!rows.length) continue; const cols = Object.keys(rows[0]); const esc = (v: unknown) => { const x = v == null ? "" : typeof v === "object" ? JSON.stringify(v) : String(v); return /[",\n\r]/.test(x) ? `"${x.replace(/"/g, '""')}"` : x; }; const csv = "\uFEFF" + cols.join(",") + "\n" + rows.map((r) => cols.map((c) => esc(r[c])).join(",")).join("\n"); zip.file(`${t}.csv`, csv); manifest[t] = createHash("sha256").update(csv).digest("hex"); }
      zip.file("MANIFEST.sha256.json", JSON.stringify({ farm: f, at: new Date().toISOString(), tables: manifest }, null, 2));
      const buf = await zip.generateAsync({ type: "nodebuffer" }); const dir = join(process.cwd(), "backups", f); await mkdir(dir, { recursive: true }); const name = `${f}-${new Date().toISOString().slice(0, 10)}.zip`; await writeFile(join(dir, name), buf);
      out[`backup:${f}`] = { file: `backups/${f}/${name}`, bytes: buf.length, tables: Object.keys(manifest).length };
      // OFF-SITE: sao chép sang BACKUP_DIR (ổ khác/NAS/mount cloud) + pg_dump toàn DB (docker exec hoặc pg_dump cục bộ) + xóa bản >30 ngày
      const off = process.env.BACKUP_DIR; if (off) { try { await mkdir(join(off, f), { recursive: true }); await writeFile(join(off, f, name), buf); out[`backup_offsite:${f}`] = join(off, f, name); } catch (e) { out[`backup_offsite:${f}`] = `ERR ${(e as Error).message}`; } }
      try { const { execFile } = await import("node:child_process"); const { promisify } = await import("node:util"); const run = promisify(execFile); const dumpDir = off ?? join(process.cwd(), "backups"); const dumpName = join(dumpDir, `itranos-${new Date().toISOString().slice(0, 10)}.dump`);
        const url = process.env.DATABASE_ADMIN_URL ?? ""; const m = url.match(/^postgres(?:ql)?:\/\/([^:]+):([^@]+)@([^:/]+):?(\d+)?\/(.+)$/);
        try { await run("pg_dump", ["-Fc", "-f", dumpName, url], { timeout: 600e3 }); out["pg_dump"] = dumpName; }
        catch { if (m) { const cont = process.env.PG_CONTAINER ?? "itranos_db"; const { stdout } = await run("docker", ["exec", cont, "pg_dump", "-U", m[1], "-Fc", m[5]], { maxBuffer: 2e9, encoding: "buffer", timeout: 600e3 }); await writeFile(dumpName, stdout as unknown as Buffer); out["pg_dump"] = `${dumpName} (via docker exec ${cont})`; } }
        const { readdir, stat, unlink } = await import("node:fs/promises"); const keepDays = Number(process.env.BACKUP_KEEP_DAYS ?? 30); for (const d of [dumpDir, join(dumpDir, f)]) { try { for (const fn of await readdir(d)) { const p = join(d, fn); const st = await stat(p); if (st.isFile() && Date.now() - st.mtimeMs > keepDays * 86400e3) await unlink(p); } } catch { /* */ } }
      } catch (e) { out["pg_dump"] = `ERR ${(e as Error).message.slice(0, 120)}`; }
    }
    if (job === "all") { try { out[`depreciation:${f}`] = (await adminPool().query("select run_depreciation($1, date_trunc('month', now())::date) as n", [f])).rows[0].n; } catch (e) { out[`depreciation:${f}`] = `skip ${(e as Error).message.slice(0, 40)}`; } }
    if (job === "reports" || job === "all") { // báo cáo định kỳ theo report_schedules → notifications (app + email/zalo qua channels)
      const scheds = (await adminPool().query("select * from report_schedules where active and (farm_id=$1 or farm_id is null)", [f])).rows; const now = new Date(); const dow = now.getDay(); const dom = now.getDate(); let sentN = 0;
      for (const sc of scheds) { const due = sc.cron === "daily" || (sc.cron === "weekly" && dow === 1) || (sc.cron === "monthly" && dom === 3) || job === "reports"; if (!due) continue; if (sc.last_sent && new Date(sc.last_sent).toDateString() === now.toDateString() && job !== "reports") continue;
        const { resolveRecipients } = await import("@/lib/notify"); const recips = await resolveRecipients(f, sc.recipients ?? ["owner"]); const base = process.env.PUBLIC_URL ?? "";
        const icfs = (await adminPool().query("select pct, level from v_icfs_summary where farm_id=$1", [f])).rows[0]; const red = Number((await adminPool().query("select count(*) from alerts where farm_id=$1 and level='DO' and acked_at is null", [f])).rows[0].count); const cash = (await adminPool().query("select cash_end from v_cashflow_forecast where farm_id=$1 order by week_start limit 1", [f])).rows[0];
        const title = sc.kind === "pl-thang" ? `Báo cáo tháng ${now.getMonth() + 1}/${now.getFullYear()} — ${f}` : `Báo cáo tuần — ${f} — ${now.toLocaleDateString("vi-VN")}`;
        const body = `ICFS ${icfs?.pct ?? "—"}% (${icfs?.level ?? ""}) · cảnh báo ĐỎ mở ${red} · số dư dự báo tuần này ${Number(cash?.cash_end ?? 0).toLocaleString("vi-VN")} đ · xem/in: ${base}/in/bao-cao-tuan/all?farm=${f} · P&L/ngân sách/dòng tiền: ${base}/ke-toan`;
        for (const sid of recips) { await adminPool().query("insert into notifications(farm_id,staff_id,level,title,body,link,source,source_id,channels) values ($1,$2,'INFO',$3,$4,$5,'report',$6,$7)", [f, sid, title, body, `/in/bao-cao-tuan/all?farm=${f}`, `${sc.id}:${now.toISOString().slice(0, 10)}`, sc.channels ?? ["app"]]); sentN++; }
        await adminPool().query("update report_schedules set last_sent=now() where id=$1", [sc.id]); }
      out[`reports:${f}`] = sentN; }
    if (job === "kpi") out[`kpi:${f}`] = (await adminPool().query("select compute_staff_kpi($1, date_trunc('month', now())::date) as n", [f])).rows[0].n;
    if (job === "all") { await adminPool().query("select compute_staff_kpi($1, date_trunc('month', now())::date)", [f]); }
    if (job === "dispatch" || job === "recon" || job === "all") { out[`dispatch:${f}`] = await dispatchEvents(); out[`channels:${f}`] = await deliverChannels(); }
    if (job === "channels") out[`channels:${f}`] = await deliverChannels();
    if (job === "agg") out[`agg:${f}`] = await backfillAgg(f, Number(url.searchParams.get("days") ?? 35));
    if (job === "cache" || job === "dispatch" || job === "all") { const dirty = (await adminPool().query("select 1 from cache_dirty where farm_id=$1 and dirty_at > coalesce((select max(refreshed_at) from cache_kv where farm_id=$1), '1970-01-01')", [f])).rowCount; const old = (await adminPool().query("select coalesce(max(refreshed_at), '1970-01-01') < now() - interval '15 minutes' as old from cache_kv where farm_id=$1", [f])).rows[0]?.old; if (job === "cache" || job === "all" || dirty || old) { out[`cache:${f}`] = (await adminPool().query("select refresh_farm_cache($1) as r", [f])).rows[0].r; await adminPool().query("delete from cache_dirty where farm_id=$1", [f]); } }
    if (job === "maint" || (job === "all" && new Date().getDay() === 0)) { out[`maint:${f}`] = (await adminPool().query("select itran_maintenance() as r")).rows[0].r; }
    if (job === "anticollusion" || (job === "all" && [1, 4, 5].includes(new Date().getDay()))) { const d = new Date().getDay(); if (d === 1 || job !== "all") { out[`spots:${f}`] = (await adminPool().query("select gen_random_spot_checks($1) as n", [f])).rows[0].n; out[`collusion_audits:${f}`] = (await adminPool().query("select gen_collusion_audits($1) as n", [f])).rows[0].n; } if (d >= 4 || job !== "all") out[`cross_checks:${f}`] = (await adminPool().query("select gen_cross_checks($1) as n", [f])).rows[0].n; }
    if (job === "capa" || (job === "all" && new Date().getDay() === 5)) { out[`capa:${f}`] = (await adminPool().query("select gen_capa_tasks($1) as n", [f])).rows[0].n; }
    if (job === "grade" || (job === "all" && new Date().getDate() === 1)) { out[`probation:${f}`] = (await adminPool().query("select confirm_probation_grades($1) as n", [f])).rows[0].n; const d = new Date(); if (job === "grade" || d.getMonth() % 3 === 0) out[`grade_review:${f}`] = (await adminPool().query("select run_grade_review($1,$2) as n", [f, `${d.getFullYear()}-Q${Math.floor(d.getMonth() / 3) + 1}`])).rows[0].n; }
    if (job === "tasks" || job === "all") { out[`deleg_end:${f}`] = (await adminPool().query("select end_delegations($1) as n", [f])).rows[0].n; out[`stale_closed:${f}`] = (await adminPool().query("select expire_stale_tasks($1) as n", [f])).rows[0].n; out[`tasks:${f}`] = (await adminPool().query("select itran_generate_tasks_v2($1) as n", [f])).rows[0].n; out[`monitor:${f}`] = (await adminPool().query("select gen_monitoring_tasks($1) as n", [f])).rows[0].n; out[`compliance:${f}`] = (await adminPool().query("select gen_compliance_tasks($1) as n", [f])).rows[0].n; out[`herd:${f}`] = (await adminPool().query("select gen_herd_actions($1) as n", [f])).rows[0].n; out[`cyclecount:${f}`] = (await adminPool().query("select gen_cycle_counts($1) as n", [f])).rows[0].n; out[`dunning:${f}`] = (await adminPool().query("select run_dunning($1) as n", [f])).rows[0].n; out[`supervision:${f}`] = (await adminPool().query("select run_supervision_auto($1) as n", [f])).rows[0].n; if (new Date().getDay() === 1) { out[`training:${f}`] = (await adminPool().query("select gen_training_week($1) as n", [f])).rows[0].n; out[`sup_tasks:${f}`] = (await adminPool().query("select gen_supervision_tasks($1) as n", [f])).rows[0].n; await adminPool().query("select run_supervision_auto($1, (date_trunc('week', current_date) - interval '7 days')::date)", [f]); } await adminPool().query("select refresh_compliance_gaps()"); }
    await adminPool().query("insert into job_runs(farm_id,job,finished_at,ok,detail) values ($1,$2,now(),true,$3)", [f, job, JSON.stringify({ date, keys: Object.keys(out).filter((k) => k.endsWith(":" + f)) })]);
  }
  return NextResponse.json({ ok: true, date, out });
}
