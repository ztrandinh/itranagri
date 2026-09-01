import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
import { EVENT_SCHEMAS, WRITE_MATRIX, type EventTable } from "@/lib/events";

/** POST /api/events/{table}  body: {events:[...]}  → 207 per-item (idempotent theo client_ref) */
export async function POST(req: Request, { params }: { params: Promise<{ table: string }> }) {
  const sess = await getSession();
  if (!sess) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const { table } = await params;
  if (!(table in EVENT_SCHEMAS)) return NextResponse.json({ error: "ERR_UNKNOWN_TABLE" }, { status: 404 });
  const t = table as EventTable;
  if (!WRITE_MATRIX[t].includes(sess.role)) return NextResponse.json({ error: "ERR_FORBIDDEN_ROLE" }, { status: 403 });
  const body = await req.json().catch(() => null);
  const events: unknown[] = Array.isArray(body?.events) ? body.events : body ? [body] : [];
  if (!events.length) return NextResponse.json({ error: "ERR_EMPTY" }, { status: 400 });

  const results: unknown[] = [];
  for (const raw of events) {
    const parsed = EVENT_SCHEMAS[t].safeParse(raw);
    if (!parsed.success) { results.push({ client_ref: (raw as { client_ref?: string })?.client_ref, status: "REJECTED", errors: parsed.error.issues.map(i => `${i.path.join(".")}: ${i.message}`) }); continue; }
    const ev = parsed.data as Record<string, unknown>;
    // BẢO MẬT: client KHÔNG được tự nhận provenance seed/import để lách các guard skip IMPORT/backfill
    // (CCP hold HACCP, trừ kho, oversell carbon...). Import thật đi /api/import/csv; seed đi SQL trực tiếp.
    if (ev.source === "IMPORT" || ev.source === "BACKFILL") ev.source = "APP";
    // is_backfill=true chỉ hợp lệ ở luồng số hoá phiếu GIẤY (ThreeTap: source=PAPER + có seri); còn lại ép false
    if (ev.is_backfill === true && !(ev.source === "PAPER" && ev.paper_serial)) ev.is_backfill = false;
    // luật supersede 72h (worker); after → cần adjustment
    try {
      const r = await withCtx(sess, async (c) => {
        const dup = await c.query(`select id from ${t} where farm_id=$1 and client_ref=$2`, [sess.farmId, ev.client_ref]);
        if (dup.rows[0]) return { status: "DUPLICATE", id: dup.rows[0].id };
        if (ev.supersedes_id) {
          const old = await c.query(`select created_at from ${t} where id=$1`, [ev.supersedes_id]);
          if (!old.rows[0]) return { status: "REJECTED", errors: ["ERR_SUPERSEDE_TARGET_NOT_FOUND"] };
          const hours = (Date.now() - new Date(old.rows[0].created_at).getTime()) / 3.6e6;
          if (hours > 72 && sess.role === "worker") return { status: "REJECTED", errors: ["ERR_SUPERSEDE_WINDOW_EXPIRED"] };
        }
        // inventory_moves: tự tạo lot từ lot_no
        if (t === "inventory_moves" && !ev.lot_id && ev.lot_no) {
          const lot = await c.query("select ensure_lot($1,$2,$3) as id", [sess.farmId, ev.sku, ev.lot_no]);
          ev.lot_id = lot.rows[0].id;
        }
        delete ev.lot_no;
        if (t === "sales" && ev.amount == null) ev.amount = Number(ev.qty) * Number(ev.price);
        // TRUY XUẤT: SKU theo lô (products.lot_tracked) bắt buộc có lot_id khi bán — chặn tận server, không chỉ UI required
        // (vật sống lot_tracked=false → đi sell_livestock, không vướng; dịch vụ/không-lô không bị chặn)
        if (t === "sales" && !ev.lot_id && ev.sku) {
          const lt = await c.query("select lot_tracked from products where sku=$1", [ev.sku]);
          if (lt.rows[0]?.lot_tracked) return { status: "REJECTED", errors: ["ERR_LOT_REQUIRED: SKU " + String(ev.sku) + " theo lô — phải nhập mã lô để truy xuất/thu hồi"] };
        }
        if (t === "batch_logs" && !ev.batch_code) { const bc = await c.query("select next_code($1,'ME',3) as code", [sess.farmId]); ev.batch_code = bc.rows[0].code.replace("-ME-", `-ME-${new Date().toISOString().slice(2,10).replace(/-/g,"")}-`); }
        if (t === "incidents") { const ic = await c.query("select next_code($1,'INC',4) as code", [sess.farmId]); ev.code = ic.rows[0].code; }
        const cols = Object.keys(ev).filter((k) => ev[k] !== undefined);
        const vals = cols.map((k) => { const v = ev[k]; return (Array.isArray(v) && typeof v[0] === "object") || (v && typeof v === "object" && !Array.isArray(v)) ? JSON.stringify(v) : v; });
        const sql = `insert into ${t} (farm_id, created_by, ${cols.join(",")}) values ($1,$2,${cols.map((_, i) => `$${i + 3}`).join(",")}) returning id, ts`;
        const ins = await c.query(sql, [sess.farmId, sess.staffId, ...vals]);
        return { status: "CREATED", id: ins.rows[0].id, ts: ins.rows[0].ts };
      });
      results.push({ client_ref: ev.client_ref, ...r });
    } catch (e) {
      // Race hiếm: 2 request cùng client_ref gần như đồng thời (đúng kịch bản retry offline) có thể
      // cùng qua bước SELECT kiểm trùng ở trên trước khi cái nào commit — unique index (farm_id,
      // client_ref) vẫn chặn đúng ở tầng DB, nhưng trước đây cái thua cuộc bị báo REJECTED/ERR_DB
      // (client tưởng ghi lỗi, có thể tự ý thử lại lần nữa) thay vì DUPLICATE sạch như bình thường.
      if ((e as { code?: string }).code === "23505") {
        try {
          const found = await withCtx(sess, (c) => c.query(`select id from ${t} where farm_id=$1 and client_ref=$2`, [sess.farmId, ev.client_ref]));
          if (found.rows[0]) { results.push({ client_ref: ev.client_ref, status: "DUPLICATE", id: found.rows[0].id }); continue; }
        } catch { /* rơi xuống nhánh lỗi chung bên dưới nếu tra lại cũng fail */ }
      }
      const msg = e instanceof Error ? e.message : String(e);
      const code = msg.match(/ERR_[A-Z_]+/)?.[0] ?? "ERR_DB";
      results.push({ client_ref: ev.client_ref, status: "REJECTED", errors: [code, msg.slice(0, 200)] });
    }
  }
  return NextResponse.json({ results }, { status: 207 });
}

/** GET /api/events/{table}?limit=50 — đọc gần nhất (theo RLS) */
export async function GET(req: Request, { params }: { params: Promise<{ table: string }> }) {
  const sess = await getSession();
  if (!sess) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const { table } = await params;
  if (!(table in EVENT_SCHEMAS)) return NextResponse.json({ error: "ERR_UNKNOWN_TABLE" }, { status: 404 });
  const url = new URL(req.url);
  const limit = Math.min(Number(url.searchParams.get("limit") ?? 50), 500);
  const rows = await withCtx(sess, async (c) => (await c.query(`select * from ${table} where farm_id=$1 order by ts desc limit $2`, [sess.farmId, limit])).rows);
  return NextResponse.json({ rows });
}
