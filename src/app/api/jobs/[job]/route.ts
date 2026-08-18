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
    if (job === "kpi") out[`kpi:${f}`] = (await adminPool().query("select compute_staff_kpi($1, date_trunc('month', now())::date) as n", [f])).rows[0].n;
    if (job === "all") { await adminPool().query("select compute_staff_kpi($1, date_trunc('month', now())::date)", [f]); }
    if (job === "dispatch" || job === "recon" || job === "all") { out[`dispatch:${f}`] = await dispatchEvents(); out[`channels:${f}`] = await deliverChannels(); }
    if (job === "channels") out[`channels:${f}`] = await deliverChannels();
    if (job === "agg") out[`agg:${f}`] = await backfillAgg(f, Number(url.searchParams.get("days") ?? 35));
    if (job === "tasks" || job === "all") { out[`tasks:${f}`] = (await adminPool().query("select itran_generate_tasks_v2($1) as n", [f])).rows[0].n; out[`monitor:${f}`] = (await adminPool().query("select gen_monitoring_tasks($1) as n", [f])).rows[0].n; }
    await adminPool().query("insert into job_runs(farm_id,job,finished_at,ok,detail) values ($1,$2,now(),true,$3)", [f, job, JSON.stringify({ date, keys: Object.keys(out).filter((k) => k.endsWith(":" + f)) })]);
  }
  return NextResponse.json({ ok: true, date, out });
}
