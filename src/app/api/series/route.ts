import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
import { METRICS, buildSeriesSql, buildRecordsSql } from "@/lib/metrics";
/** GET /api/series?metric=&bucket=&from=&to=&dim=&farm=  |  ?list=1  |  ?records=1&metric=&t=&bucket=&dim=&dimval= (drill 2 chạm) */
export async function GET(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const u = new URL(req.url); const p = (k: string) => u.searchParams.get(k);
  if (p("list")) return NextResponse.json({ metrics: METRICS.map(({ sql: _s, records: _r, ...m }) => { void _s; void _r; return m; }) });
  const m = METRICS.find((x) => x.code === p("metric")); if (!m) return NextResponse.json({ error: "ERR_UNKNOWN_METRIC" }, { status: 404 });
  const bucket = p("bucket") ?? "day"; const dim = p("dim"); const farm = p("farm") ?? s.farmId;
  const from = p("from") ?? new Date(Date.now() - 30 * 86400e3).toISOString().slice(0, 10); const to = p("to") ?? new Date().toISOString().slice(0, 10);
  try {
    if (p("records")) {
      const rows = await withCtx({ ...s, farmId: farm }, async (c) => (await c.query(buildRecordsSql(m, bucket, dim, !!p("dimval")), [farm, p("t"), p("dimval") ?? null])).rows);
      return NextResponse.json({ rows });
    }
    const rows = await withCtx({ ...s, farmId: farm }, async (c) => (await c.query(buildSeriesSql(m, bucket, dim), [farm, from, to])).rows);
    // kỳ trước để so sánh
    const span = (new Date(to).getTime() - new Date(from).getTime()) / 86400e3 + 1;
    const pf = new Date(new Date(from).getTime() - span * 86400e3).toISOString().slice(0, 10), pt = new Date(new Date(from).getTime() - 86400e3).toISOString().slice(0, 10);
    const prev = p("compare") ? await withCtx({ ...s, farmId: farm }, async (c) => (await c.query(buildSeriesSql(m, bucket, dim), [farm, pf, pt])).rows) : [];
    return NextResponse.json({ metric: m.code, unit: m.unit, bucket, dim, rows, prev, prev_range: [pf, pt] });
  } catch (e) { return NextResponse.json({ error: "ERR_QUERY", detail: (e as Error).message }, { status: 500 }); }
}
