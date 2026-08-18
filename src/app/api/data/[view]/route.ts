import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
import { canView } from "@/lib/roles";
import { adminPool } from "@/lib/db";
const MEM = new Map<string, { at: number; rows: unknown[] }>(); const REFRESHING = new Set<string>();
const HEAVY = new Set(["stock_dashboard", "warehouse_fill", "herd_forecast_series", "feed_forecast_series", "supervision_weekly", "supervision_dept_weekly", "bonus_eval", "competency_matrix", "mrp_run", "plan_supply", "replenishment", "supplier_scorecard", "abc_suggest", "kpi_owner_weekly", "consolidated"]);
async function ensureFarmCache(farm: string) { const key = "cache:" + farm; if (REFRESHING.has(key)) return; try { const r = (await adminPool().query("select (select max(refreshed_at) from cache_kv where farm_id=$1) as at, (select dirty_at from cache_dirty where farm_id=$1) as dirty", [farm])).rows[0]; const stale = !r?.at || Date.now() - new Date(r.at).getTime() > 15 * 60e3 || (r?.dirty && new Date(r.dirty) > new Date(r.at)); if (!stale) return; REFRESHING.add(key); adminPool().query("select refresh_farm_cache($1)", [farm]).then(() => adminPool().query("delete from cache_dirty where farm_id=$1 and dirty_at <= (select max(refreshed_at) from cache_kv where farm_id=$1)", [farm])).catch(() => null).finally(() => { REFRESHING.delete(key); for (const k of MEM.keys()) if (k.startsWith(farm + "|")) MEM.delete(k); }); } catch { REFRESHING.delete(key); } }
import { QUERIES } from "@/lib/queries";
export async function GET(req: Request, { params }: { params: Promise<{ view: string }> }) {
  const sess = await getSession();
  if (!sess) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const { view } = await params;
  const qd = QUERIES[view];
  if (!qd) return NextResponse.json({ error: "ERR_UNKNOWN_VIEW" }, { status: 404 });
  if (!canView(view, sess.role)) return NextResponse.json({ error: "ERR_FORBIDDEN_ROLE", detail: `Vai ${sess.role} không được xem ${view}` }, { status: 403 });
  const url = new URL(req.url);
  const farm = url.searchParams.get("farm") ?? sess.farmId;
  const ctx = { ...sess, farmId: farm };
  const args: unknown[] = qd.sql.includes("$1") ? [farm] : [];
  for (const p of qd.params ?? []) args.push(url.searchParams.get(p));
  try {
    if (qd.cache || view === "stock_dashboard") { void ensureFarmCache(farm); }
    const memKey = `${farm}|${sess.role}|${sess.staffId}|${view}|${args.join(",")}`; const ttl = (qd.ttl ?? (HEAVY.has(view) ? 60 : 0)) * 1000; const hit = ttl ? MEM.get(memKey) : undefined;
    if (hit && Date.now() - hit.at < ttl && !url.searchParams.has("fresh")) return NextResponse.json({ rows: hit.rows, cached: true }, { headers: { "x-cache": "HIT", "cache-control": "private, max-age=30" } });
    const rows = await withCtx(ctx, async (c) => (await c.query(qd.sql, args)).rows);
    if (ttl) { MEM.set(memKey, { at: Date.now(), rows }); if (MEM.size > 2000) MEM.delete(MEM.keys().next().value as string); }
    return NextResponse.json({ rows }, { headers: { "x-cache": ttl ? "MISS" : "BYPASS" } });
  } catch (e) {
    return NextResponse.json({ error: "ERR_QUERY", detail: e instanceof Error ? e.message : String(e) }, { status: 500 });
  }
}
