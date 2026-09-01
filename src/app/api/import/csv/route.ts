import { NextResponse } from "next/server";
import { createHash } from "node:crypto";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
import { findAdmin, IMPORT_EVENT_TABLES, parseCsv, toCsv } from "@/lib/admin";
import { tableCols } from "@/lib/anychart";
import { EVENT_SCHEMAS, WRITE_MATRIX, type EventTable } from "@/lib/events";
/** NHẬP DỮ LIỆU CSV (đối xứng với xuất):
 *  GET  /api/import/csv?template=table          → file mẫu (đúng cột) để điền
 *  POST /api/import/csv  form-data{file, table, mode=preview|commit, upsert=1}  hoặc JSON {table, text, mode}
 *  - Bảng danh mục (ADMIN_TABLES): kiểm tra cột, insert / upsert theo pk; ghi audit_log qua trigger; nhật ký import_batches
 *  - Bảng sự kiện (IMPORT_EVENT_TABLES): mỗi dòng đi qua Zod schema như /api/events (append-only, idempotent theo client_ref = import:{batch}:{row}) */
export async function GET(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const table = new URL(req.url).searchParams.get("template") ?? "";
  const t = findAdmin(table);
  if (t) { const cols = await withCtx(s, (c) => tableCols(c, t.table)); const names = cols.map((x) => x.name).filter((n) => !t.hidden?.includes(n) && !["created_at", "updated_at", "created_by", "updated_by", "org_id"].includes(n)); return new Response(toCsv([], names), { headers: { "content-type": "text/csv; charset=utf-8", "content-disposition": `attachment; filename="mau-${table}.csv"` } }); }
  if (IMPORT_EVENT_TABLES.includes(table)) { const shape = (EVENT_SCHEMAS[table as EventTable] as unknown as { shape: Record<string, unknown> }).shape ?? {}; const names = Object.keys(shape).filter((k) => !["client_ref", "supersedes_id"].includes(k)); return new Response(toCsv([], ["ts", ...names.filter((n) => n !== "ts")]), { headers: { "content-type": "text/csv; charset=utf-8", "content-disposition": `attachment; filename="mau-${table}.csv"` } }); }
  return NextResponse.json({ error: "ERR_UNKNOWN_TABLE" }, { status: 404 });
}
export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  let table = "", text = "", mode = "preview", upsert = false, fileName = "";
  const ct = req.headers.get("content-type") ?? "";
  if (ct.includes("multipart/form-data")) { const fd = await req.formData(); table = String(fd.get("table") ?? ""); mode = String(fd.get("mode") ?? "preview"); upsert = fd.get("upsert") === "1"; const f = fd.get("file"); if (f && typeof f !== "string") { text = await (f as File).text(); fileName = (f as File).name; } else text = String(fd.get("text") ?? ""); }
  else { const b = await req.json().catch(() => ({})); table = b.table ?? ""; text = b.text ?? ""; mode = b.mode ?? "preview"; upsert = !!b.upsert; fileName = b.file_name ?? ""; }
  const rows = parseCsv(text); if (!rows.length) return NextResponse.json({ error: "ERR_EMPTY", detail: "File rỗng hoặc không đọc được" }, { status: 400 });
  if (rows.length > 20000) return NextResponse.json({ error: "ERR_TOO_MANY_ROWS", detail: "Tối đa 20.000 dòng/lần" }, { status: 400 });
  const t = findAdmin(table); const isEvent = IMPORT_EVENT_TABLES.includes(table);
  if (!t && !isEvent) return NextResponse.json({ error: "ERR_UNKNOWN_TABLE" }, { status: 404 });
  if (t && !t.writeRoles.includes(s.role)) return NextResponse.json({ error: "ERR_FORBIDDEN_ROLE" }, { status: 403 });
  if (isEvent && !WRITE_MATRIX[table as EventTable].includes(s.role) && !["owner", "director", "it_engineer", "accountant"].includes(s.role)) return NextResponse.json({ error: "ERR_FORBIDDEN_ROLE" }, { status: 403 });
  try {
    return await withCtx(s, async (c) => {
      const errors: { row: number; error: string }[] = []; let ok = 0; const preview: Record<string, unknown>[] = [];
      const batchId = crypto.randomUUID();
      // Dedupe theo NỘI DUNG file (0195): batchId trước đây luôn là UUID mới mỗi lần POST nên double-click/
      // double-submit đúng file CSV lần 2 không bị chặn, khác hẳn /api/events (idempotent theo client_ref).
      // content_hash + unique index là backstop DB thật; bắt unique_violation để trả lại kết quả batch cũ.
      const contentHash = createHash("sha256").update(`${table}|${text}`).digest("hex");
      if (mode === "commit") {
        await c.query("savepoint import_batch_sp");
        try {
          await c.query("insert into import_batches(id,farm_id,table_name,file_name,rows_total,mode,by_staff,content_hash) values ($1,$2,$3,$4,$5,$6,$7,$8)", [batchId, s.farmId, table, fileName, rows.length, upsert ? "UPSERT" : "INSERT", s.staffId, contentHash]);
        } catch (e) {
          await c.query("rollback to savepoint import_batch_sp");
          if ((e as { code?: string }).code === "23505") {
            const prev = (await c.query("select id, rows_ok, rows_err, errors from import_batches where farm_id=$1 and table_name=$2 and content_hash=$3 and reverted_at is null order by ts desc limit 1", [s.farmId, table, contentHash])).rows[0];
            if (prev) return NextResponse.json({ mode, table, batch: prev.id, rows_total: rows.length, rows_ok: prev.rows_ok, rows_err: prev.rows_err, errors: prev.errors ?? [], preview: [], duplicate: true });
          }
          throw e;
        }
      }
      if (t) {
        const cols = await tableCols(c, t.table); const names = new Set(cols.map((x) => x.name)); const unknown = Object.keys(rows[0]).filter((k) => !names.has(k) && k !== "pin");
        if (unknown.length) errors.push({ row: 0, error: `Cột không tồn tại: ${unknown.join(", ")}` });
        for (let i = 0; i < rows.length; i++) {
          const raw = rows[i]; const data: Record<string, unknown> = {};
          for (const [k, v] of Object.entries(raw)) { if (!names.has(k) || t.hidden?.includes(k)) continue; if (v === "") continue; const col = cols.find((x) => x.name === k)!; data[k] = ["numeric", "integer", "bigint", "double precision", "smallint", "real"].includes(col.type) ? Number(String(v).replace(/\./g, "").replace(",", ".")) || Number(v) : col.type === "boolean" ? ["1", "true", "x", "có", "co", "yes"].includes(v.toLowerCase()) : col.type === "jsonb" ? (() => { try { return JSON.parse(v); } catch { return v; } })() : col.type === "ARRAY" ? v.split("|").map((x) => x.trim()).filter(Boolean) : v; }
          if (t.farmScoped && names.has("farm_id") && !data.farm_id) data.farm_id = s.farmId; if (names.has("org_id") && !data.org_id) data.org_id = s.orgId; if (names.has("created_by") && !data.created_by) data.created_by = s.staffId;
          if (t.table === "staff" && !data.pin_hash) data.pin_hash = (await c.query("select crypt($1, gen_salt('bf')) as h", [String(raw.pin || "1234")])).rows[0].h;
          if (!data[t.pk]) { if (t.codePrefix) data[t.pk] = (await c.query("select next_code($1,$2) as c", [s.farmId, t.codePrefix])).rows[0].c; else if (!["uuid", "integer"].includes(cols.find((x) => x.name === t.pk)?.type ?? "")) { errors.push({ row: i + 1, error: `Thiếu ${t.pk}` }); continue; } }
          if (mode !== "commit") { preview.push(data); ok++; if (preview.length > 20) preview.length = 20; continue; }
          try {
            await c.query("savepoint r");
            const ks = Object.keys(data); const vals = ks.map((k) => (typeof data[k] === "object" && data[k] !== null && !Array.isArray(data[k])) ? JSON.stringify(data[k]) : data[k]);
            const conflict = upsert && data[t.pk] ? ` on conflict (${t.pk}) do update set ${ks.filter((k) => k !== t.pk).map((k) => `${k}=excluded.${k}`).join(",")}` : "";
            await c.query(`insert into ${t.table}(${ks.join(",")}) values (${ks.map((_, j) => `$${j + 1}`).join(",")})${conflict}`, vals); ok++;
            await c.query("release savepoint r");
          } catch (e) { await c.query("rollback to savepoint r"); errors.push({ row: i + 1, error: (e as Error).message.slice(0, 160) }); }
        }
      } else {
        const et = table as EventTable; const schema = EVENT_SCHEMAS[et];
        for (let i = 0; i < rows.length; i++) {
          const raw: Record<string, unknown> = { ...rows[i] };
          for (const k of Object.keys(raw)) { const v = String(raw[k]); if (v === "") { delete raw[k]; continue; } if (/^-?\d+([.,]\d+)?$/.test(v) && !["paper_serial", "plate", "lot_no", "sku", "id", "animal_id", "group_id"].includes(k)) raw[k] = Number(v.replace(",", ".")); else if (v === "true" || v === "false") raw[k] = v === "true"; else if ((v.startsWith("{") || v.startsWith("[")) ) { try { raw[k] = JSON.parse(v); } catch { /* keep */ } } }
          if (raw.ts != null && !/Z$|[+-]\d\d:\d\d$/.test(String(raw.ts))) { const d = new Date(String(raw.ts).replace(" ", "T")); if (!isNaN(d.getTime())) raw.ts = d.toISOString(); }
          raw.client_ref = `import:${batchId}:${i + 1}`; if (!raw.source) raw.source = "IMPORT";
          const parsed = schema.safeParse(raw);
          if (!parsed.success) { errors.push({ row: i + 1, error: parsed.error.issues.map((x) => `${x.path.join(".")}: ${x.message}`).join("; ").slice(0, 200) }); continue; }
          const ev = parsed.data as Record<string, unknown>;
          if (mode !== "commit") { ok++; if (preview.length < 20) preview.push(ev); continue; }
          try {
            await c.query("savepoint r");
            if (et === "inventory_moves" && !ev.lot_id && ev.lot_no) ev.lot_id = (await c.query("select ensure_lot($1,$2,$3) as id", [s.farmId, ev.sku, ev.lot_no])).rows[0].id; delete ev.lot_no;
            if (et === "sales" && ev.amount == null) ev.amount = Number(ev.qty) * Number(ev.price);
            const ks = Object.keys(ev).filter((k) => ev[k] !== undefined); const vals = ks.map((k) => { const v = ev[k]; return (Array.isArray(v) && typeof v[0] === "object") || (v && typeof v === "object" && !Array.isArray(v)) ? JSON.stringify(v) : v; });
            await c.query(`insert into ${et}(farm_id, created_by, ${ks.join(",")}) values ($1,$2,${ks.map((_, j) => `$${j + 3}`).join(",")})`, [s.farmId, s.staffId, ...vals]); ok++;
            await c.query("release savepoint r");
          } catch (e) { await c.query("rollback to savepoint r"); errors.push({ row: i + 1, error: (e as Error).message.match(/ERR_[A-Z_]+/)?.[0] ?? (e as Error).message.slice(0, 160) }); }
        }
      }
      if (mode === "commit") { await c.query("update import_batches set rows_ok=$2, rows_err=$3, errors=$4 where id=$1", [batchId, ok, errors.length, JSON.stringify(errors.slice(0, 500))]); await c.query("select publish_event($1,'import.done',$2)", [s.farmId, JSON.stringify({ table, batch: batchId, ok, err: errors.length, by: s.staffId, file: fileName })]); }
      return NextResponse.json({ mode, table, batch: mode === "commit" ? batchId : null, rows_total: rows.length, rows_ok: ok, rows_err: errors.length, errors: errors.slice(0, 200), preview });
    });
  } catch (e) { return NextResponse.json({ error: "ERR_IMPORT", detail: (e as Error).message }, { status: 500 }); }
}
