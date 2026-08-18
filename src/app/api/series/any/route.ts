import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
import { ANY_TABLES, tableCols, buildAnySql, buildAnyRecordsSql, distinctSql, type AnyQuery } from "@/lib/anychart";
/** GET /api/series/any?tables=1 | ?cols=table | ?distinct=table&col= | ?table=&col=&agg=&bucket=&dim=&from=&to=&f.<col>=v… | &records=1&t=&dimval= */
export async function GET(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const u = new URL(req.url); const p = (k: string) => u.searchParams.get(k);
  if (p("tables")) return NextResponse.json({ tables: ANY_TABLES.map(({ table, label, ts, jsonb }) => ({ table, label, ts, jsonb })) });
  const tname = p("cols") ?? p("distinct") ?? p("table"); const tdef = ANY_TABLES.find((t) => t.table === tname);
  if (!tdef) return NextResponse.json({ error: "ERR_UNKNOWN_TABLE" }, { status: 404 });
  const farm = p("farm") ?? s.farmId;
  try {
    return await withCtx({ ...s, farmId: farm }, async (c) => {
      const cols = await tableCols(c, tdef.table);
      if (p("cols")) {
        // khóa jsonb phổ biến (soi 2000 dòng gần nhất) để chọn làm chiều/giá trị
        const jkeys: Record<string, string[]> = {};
        for (const jc of (tdef.jsonb ?? []).filter((j) => cols.find((c) => c.name === j && c.type === "jsonb"))) { const r = (await c.query(`select distinct k from (select jsonb_object_keys(${jc}) k from ${tdef.table} where farm_id=$1 and jsonb_typeof(${jc})='object' order by ${tdef.ts} desc limit 2000) x limit 50`, [farm])).rows; jkeys[jc] = r.map((x) => String(x.k)); }
        return NextResponse.json({ table: tdef.table, ts: tdef.ts, cols, jsonKeys: jkeys });
      }
      if (p("distinct")) { const col = p("col") ?? ""; const [jc, key] = col.split("."); const jk = tdef.jsonb?.includes(jc) && key ? { jc, key } : null; if (!jk && !cols.find((x) => x.name === col)) return NextResponse.json({ error: "ERR_BAD_COLUMN" }, { status: 400 }); return NextResponse.json({ values: (await c.query(distinctSql(tdef, col, jk), [farm])).rows }); }
      const filters: Record<string, string> = {}; u.searchParams.forEach((v, k) => { if (k.startsWith("f.")) filters[k.slice(2)] = v; });
      const q: AnyQuery = { table: tdef.table, col: p("col") ?? "id", agg: (p("agg") as AnyQuery["agg"]) ?? "sum", bucket: p("bucket") ?? "day", dim: p("dim"), filters };
      if (p("records")) { const { sql, params } = buildAnyRecordsSql(q, cols, tdef, !!p("dimval")); return NextResponse.json({ rows: (await c.query(sql, [farm, p("t"), p("dimval") ?? null, ...params])).rows }); }
      const from = p("from") ?? new Date(Date.now() - 30 * 86400e3).toISOString().slice(0, 10); const to = p("to") ?? new Date().toISOString().slice(0, 10);
      const { sql, params } = buildAnySql(q, cols, tdef);
      const rows = (await c.query(sql, [farm, from, to, ...params])).rows;
      let prev: unknown[] = [];
      if (p("compare")) { const span = (new Date(to).getTime() - new Date(from).getTime()) / 86400e3 + 1; const pf = new Date(new Date(from).getTime() - span * 86400e3).toISOString().slice(0, 10), pt = new Date(new Date(from).getTime() - 86400e3).toISOString().slice(0, 10); prev = (await c.query(sql, [farm, pf, pt, ...params])).rows; }
      return NextResponse.json({ q, rows, prev });
    });
  } catch (e) { return NextResponse.json({ error: "ERR_QUERY", detail: (e as Error).message }, { status: 500 }); }
}
