import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
import { ADMIN_TABLES, findAdmin, toCsv } from "@/lib/admin";
import { tableCols } from "@/lib/anychart";
/** Quản trị danh mục (thêm/sửa/gỡ/lịch sử/xuất):
 *  GET  /api/admin/{table}?q=&limit=&offset=&all=1&csv=1  | ?meta=1 | ?history=1&pk= | ?tables=1
 *  POST /api/admin/{table}  {row:{...}}  → thêm (không có pk) hoặc sửa (có pk); ghi audit_log qua trigger; sự kiện master.changed → admin
 *  DELETE /api/admin/{table}?pk=  → gỡ mềm (active=false / status=ARCHIVED); bảng không có cờ mềm → 409 (không xóa cứng dữ liệu) */
const ident = (s: string) => /^[a-z_][a-z0-9_]*$/.test(s);
export async function GET(req: Request, { params }: { params: Promise<{ table: string }> }) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const { table } = await params; const u = new URL(req.url); const p = (k: string) => u.searchParams.get(k);
  if (table === "_tables") return NextResponse.json({ tables: ADMIN_TABLES.map((t) => ({ ...t, canWrite: t.writeRoles.includes(s.role) })) });
  const t = findAdmin(table); if (!t) return NextResponse.json({ error: "ERR_UNKNOWN_TABLE" }, { status: 404 });
  const farm = p("farm") ?? s.farmId;
  try {
    return await withCtx({ ...s, farmId: farm }, async (c) => {
      const cols = await tableCols(c, t.table);
      if (p("meta")) {
        const cf = (await c.query("select field,label,type,options,required from custom_fields where table_name=$1 and active order by position", [t.table])).rows;
        return NextResponse.json({ table: t, cols: cols.filter((x) => !t.hidden?.includes(x.name)), customFields: cf, canWrite: t.writeRoles.includes(s.role) });
      }
      if (p("history")) { const rows = (await c.query("select * from audit_log where table_name=$1 and ($2::text is null or pk=$2) order by ts desc limit 300", [t.table, p("pk")])).rows; return NextResponse.json({ rows }); }
      const where: string[] = []; const args: unknown[] = [];
      if (t.farmScoped && !p("all")) { args.push(farm); where.push(`(farm_id=$${args.length} or farm_id is null)`); }
      if (p("q")) { const txt = cols.filter((x) => ["text", "character varying"].includes(x.type)).slice(0, 8).map((x) => `coalesce(${x.name}::text,'')`); if (txt.length) { args.push(`%${p("q")}%`); where.push(`(${txt.join(" || ' ' || ")}) ilike $${args.length}`); } }
      if (!p("inactive")) { if (t.softDelete === "active" && cols.find((x) => x.name === "active")) where.push("coalesce(active,true)"); if (t.softDelete === "status" && cols.find((x) => x.name === "status")) where.push("coalesce(status,'') not in ('ARCHIVED','NGUNG','HUY')"); }
      const limit = Math.min(Number(p("limit") ?? 200), 5000), offset = Number(p("offset") ?? 0);
      const order = cols.find((x) => x.name === "created_at") ? "created_at desc" : `${t.pk} asc`;
      const sql = `select * from ${t.table} ${where.length ? "where " + where.join(" and ") : ""} order by ${order} limit ${limit} offset ${offset}`;
      const rows = (await c.query(sql, args)).rows; const total = Number((await c.query(`select count(*) as n from ${t.table} ${where.length ? "where " + where.join(" and ") : ""}`, args)).rows[0].n);
      if (p("csv")) { const vis = cols.filter((x) => !t.hidden?.includes(x.name)).map((x) => x.name); return new Response(toCsv(rows.map((r) => Object.fromEntries(vis.map((k) => [k, r[k]]))), vis), { headers: { "content-type": "text/csv; charset=utf-8", "content-disposition": `attachment; filename="${t.table}-${farm}.csv"` } }); }
      return NextResponse.json({ rows: rows.map((r) => { const o = { ...r }; for (const h of t.hidden ?? []) delete o[h]; return o; }), total, limit, offset });
    });
  } catch (e) { return NextResponse.json({ error: "ERR_QUERY", detail: (e as Error).message }, { status: 500 }); }
}
export async function POST(req: Request, { params }: { params: Promise<{ table: string }> }) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const { table } = await params; const t = findAdmin(table); if (!t) return NextResponse.json({ error: "ERR_UNKNOWN_TABLE" }, { status: 404 });
  if (!t.writeRoles.includes(s.role)) return NextResponse.json({ error: "ERR_FORBIDDEN_ROLE" }, { status: 403 });
  const body = await req.json().catch(() => null); const row = (body?.row ?? body) as Record<string, unknown>; if (!row || typeof row !== "object") return NextResponse.json({ error: "ERR_EMPTY" }, { status: 400 });
  try {
    return await withCtx(s, async (c) => {
      const cols = await tableCols(c, t.table); const names = new Set(cols.map((x) => x.name));
      const data: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(row)) { if (!ident(k) || !names.has(k) || t.readonly?.includes(k) || t.hidden?.includes(k)) continue; const col = cols.find((x) => x.name === k)!; data[k] = v === "" ? null : col.type === "jsonb" && typeof v === "string" ? (() => { try { return JSON.parse(v); } catch { return v; } })() : col.type === "ARRAY" && typeof v === "string" ? v.split(",").map((x) => x.trim()).filter(Boolean) : v; }
      if (t.farmScoped && names.has("farm_id") && !data.farm_id) data.farm_id = s.farmId;
      if (names.has("org_id") && !data.org_id) data.org_id = s.orgId;
      let pk = data[t.pk] as string | undefined; const exists = pk ? (await c.query(`select 1 from ${t.table} where ${t.pk}=$1`, [pk])).rows[0] : null;
      if (!exists) {
        if (!pk) { if (t.codePrefix) { const code = (await c.query("select next_code($1,$2) as c", [t.farmScoped ? s.farmId : "HQ", t.codePrefix])).rows[0].c; pk = String(code); data[t.pk] = pk; } else if (cols.find((x) => x.name === t.pk)?.type === "uuid" || cols.find((x) => x.name === t.pk)?.type === "integer") { delete data[t.pk]; } else return NextResponse.json({ error: "ERR_PK_REQUIRED", detail: `Cần nhập ${t.pk}` }, { status: 400 }); }
        if (names.has("created_by") && !data.created_by) data.created_by = s.staffId; if (t.table === "staff" && !data.pin_hash) { const pin = String(row.pin ?? "1234"); data.pin_hash = (await c.query("select crypt($1, gen_salt('bf')) as h", [pin])).rows[0].h; }
        const ks = Object.keys(data); const r = await c.query(`insert into ${t.table}(${ks.join(",")}) values (${ks.map((_, i) => `$${i + 1}`).join(",")}) returning *`, ks.map((k) => Array.isArray(data[k]) || (typeof data[k] === "object" && data[k] !== null) ? (cols.find((x) => x.name === k)?.type === "ARRAY" ? data[k] : JSON.stringify(data[k])) : data[k]));
        return NextResponse.json({ ok: true, action: "INSERT", row: r.rows[0] });
      }
      const ks = Object.keys(data).filter((k) => k !== t.pk); if (names.has("updated_at")) { ks.push("updated_at"); data.updated_at = new Date().toISOString(); } if (names.has("updated_by")) { ks.push("updated_by"); data.updated_by = s.staffId; }
      if (!ks.length) return NextResponse.json({ error: "ERR_NOTHING_TO_UPDATE" }, { status: 400 });
      const r = await c.query(`update ${t.table} set ${ks.map((k, i) => `${k}=$${i + 2}`).join(",")} where ${t.pk}=$1 returning *`, [pk, ...ks.map((k) => Array.isArray(data[k]) || (typeof data[k] === "object" && data[k] !== null) ? (cols.find((x) => x.name === k)?.type === "ARRAY" ? data[k] : JSON.stringify(data[k])) : data[k])]);
      return NextResponse.json({ ok: true, action: "UPDATE", row: r.rows[0] });
    });
  } catch (e) { return NextResponse.json({ error: "ERR_WRITE", detail: (e as Error).message }, { status: 400 }); }
}
export async function DELETE(req: Request, { params }: { params: Promise<{ table: string }> }) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const { table } = await params; const t = findAdmin(table); if (!t) return NextResponse.json({ error: "ERR_UNKNOWN_TABLE" }, { status: 404 });
  if (!t.writeRoles.includes(s.role)) return NextResponse.json({ error: "ERR_FORBIDDEN_ROLE" }, { status: 403 });
  const pk = new URL(req.url).searchParams.get("pk"); if (!pk) return NextResponse.json({ error: "ERR_PK_REQUIRED" }, { status: 400 });
  const restore = new URL(req.url).searchParams.get("restore");
  try {
    return await withCtx(s, async (c) => {
      if (t.softDelete === "active") await c.query(`update ${t.table} set active=$2 where ${t.pk}=$1`, [pk, !!restore]);
      else if (t.softDelete === "status") await c.query(`update ${t.table} set status=$2 where ${t.pk}=$1`, [pk, restore ? "ACTIVE" : "ARCHIVED"]);
      else return NextResponse.json({ error: "ERR_NO_SOFT_DELETE", detail: "Bảng này không gỡ được (giữ vết); hãy sửa hoặc thêm bản mới." }, { status: 409 });
      return NextResponse.json({ ok: true, action: restore ? "RESTORE" : "SOFT_DELETE", pk });
    });
  } catch (e) { return NextResponse.json({ error: "ERR_WRITE", detail: (e as Error).message }, { status: 400 }); }
}
