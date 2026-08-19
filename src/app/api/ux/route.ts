import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";

/** POST /api/ux — ghi sự kiện trải nghiệm (HEART). Chỉ nhận trường đo lường, KHÔNG nhận dữ liệu nghiệp vụ. */
const KINDS = ["task_start", "task_done", "task_abandon", "form_error", "nav", "search"];

export async function POST(req: Request) {
  const s = await getSession();
  if (!s) return NextResponse.json({ ok: false }, { status: 401 });
  const b = await req.json().catch(() => ({}));
  const kind = String(b.kind ?? "");
  if (!KINDS.includes(kind)) return NextResponse.json({ error: "ERR_KIND" }, { status: 400 });
  const task = b.task ? String(b.task).slice(0, 60) : null;
  const path = b.path ? String(b.path).slice(0, 120) : null;
  const ms = Number.isFinite(Number(b.ms)) ? Math.max(0, Math.min(3_600_000, Math.round(Number(b.ms)))) : null;
  const ok = typeof b.ok === "boolean" ? b.ok : null;
  const detail = b.detail && typeof b.detail === "object" ? b.detail : {};
  try {
    await withCtx(s, async (c) => {
      await c.query(
        "insert into ux_events(farm_id, staff_id, role, dept, kind, task, path, ms, ok, detail) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)",
        [s.farmId, s.staffId, s.role, s.dept ?? null, kind, task, path, ms, ok, JSON.stringify(detail)],
      );
    });
    return NextResponse.json({ ok: true });
  } catch {
    // đo lường không được phép làm hỏng nghiệp vụ
    return NextResponse.json({ ok: false });
  }
}
