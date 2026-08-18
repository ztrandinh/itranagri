import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
/** Chạy evidence_query của 1 control (SQL lưu trong bảng controls, do QA/IT quản lý; $1 = farm) → bằng chứng sống */
export async function GET(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const id = new URL(req.url).searchParams.get("control") ?? "";
  try { return await withCtx(s, async (c) => { const ctl = (await c.query("select * from controls where id=$1", [id])).rows[0]; if (!ctl?.evidence_query) return NextResponse.json({ error: "ERR_NO_QUERY" }, { status: 404 }); const q = String(ctl.evidence_query); if (!/^\s*select/i.test(q)) return NextResponse.json({ error: "ERR_NOT_SELECT" }, { status: 400 }); const rows = (await c.query(q.includes("$1") ? q : q + " where $1::text is not null", [s.farmId])).rows; return NextResponse.json({ control: ctl, rows }); }); }
  catch (e) { return NextResponse.json({ error: "ERR_QUERY", detail: (e as Error).message }, { status: 500 }); }
}
