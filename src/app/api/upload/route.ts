import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { createHash } from "node:crypto";
/** Dev: lưu ảnh vào public/uploads/{farm}/; prod Supabase Storage. */
export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const fd = await req.formData();
  const f = fd.get("file") as File | null;
  if (!f) return NextResponse.json({ error: "ERR_NO_FILE" }, { status: 400 });
  const buf = Buffer.from(await f.arrayBuffer());
  const sha = createHash("sha256").update(buf).digest("hex").slice(0, 16);
  const ext = (f.name.split(".").pop() || "jpg").toLowerCase().replace(/[^a-z0-9]/g, "");
  const dir = join(process.cwd(), "public", "uploads", s.farmId);
  await mkdir(dir, { recursive: true });
  const name = `${Date.now()}-${sha}.${ext}`;
  await writeFile(join(dir, name), buf);
  return NextResponse.json({ url: `/uploads/${s.farmId}/${name}`, sha256: sha, size: buf.length });
}
