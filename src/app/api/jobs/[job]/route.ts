import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { runRecon, runAlerts, backfillAgg } from "@/lib/jobs";
import { adminPool } from "@/lib/db";
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
    if (job === "agg") out[`agg:${f}`] = await backfillAgg(f, Number(url.searchParams.get("days") ?? 35));
    if (job === "tasks" || job === "all") out[`tasks:${f}`] = (await adminPool().query("select itran_generate_tasks_v2($1) as n", [f])).rows[0].n;
    await adminPool().query("insert into job_runs(farm_id,job,finished_at,ok,detail) values ($1,$2,now(),true,$3)", [f, job, JSON.stringify({ date, keys: Object.keys(out).filter((k) => k.endsWith(":" + f)) })]);
  }
  return NextResponse.json({ ok: true, date, out });
}
