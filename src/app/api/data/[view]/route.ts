import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
import { QUERIES } from "@/lib/queries";
export async function GET(req: Request, { params }: { params: Promise<{ view: string }> }) {
  const sess = await getSession();
  if (!sess) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const { view } = await params;
  const qd = QUERIES[view];
  if (!qd) return NextResponse.json({ error: "ERR_UNKNOWN_VIEW" }, { status: 404 });
  const url = new URL(req.url);
  const farm = url.searchParams.get("farm") ?? sess.farmId;
  const ctx = { ...sess, farmId: farm };
  const args: unknown[] = qd.sql.includes("$1") ? [farm] : [];
  for (const p of qd.params ?? []) args.push(url.searchParams.get(p));
  try {
    const rows = await withCtx(ctx, async (c) => (await c.query(qd.sql, args)).rows);
    return NextResponse.json({ rows });
  } catch (e) {
    return NextResponse.json({ error: "ERR_QUERY", detail: e instanceof Error ? e.message : String(e) }, { status: 500 });
  }
}
