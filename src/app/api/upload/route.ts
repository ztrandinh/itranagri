import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { withCtx } from "@/lib/db";
/** Upload file/ảnh → public/uploads/{farm}/ (hoặc UPLOAD_DIR) + (tùy chọn) ghi vào bảng documents gắn đối tượng (ref_table, ref_id, kind, title, tags, expires_on).
 *  Ảnh nén ở client (lib/client). Prod: đổi sang object storage bằng cách thay hàm save(). */
export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const fd = await req.formData(); const f = fd.get("file") as File | null; if (!f) return NextResponse.json({ error: "ERR_NO_FILE" }, { status: 400 });
  if (f.size > 25e6) return NextResponse.json({ error: "ERR_TOO_LARGE" }, { status: 413 });
  const buf = Buffer.from(await f.arrayBuffer()); const sha = createHash("sha256").update(buf).digest("hex");
  const ext = (f.name.split(".").pop() || "bin").toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 8);
  const base = process.env.UPLOAD_DIR ?? join(process.cwd(), "public", "uploads"); const dir = join(base, s.farmId); await mkdir(dir, { recursive: true });
  const name = `${Date.now()}-${sha.slice(0, 16)}.${ext}`; await writeFile(join(dir, name), buf); const url = `/uploads/${s.farmId}/${name}`;
  let doc: Record<string, unknown> | null = null;
  const refTable = fd.get("ref_table"), refId = fd.get("ref_id");
  if (refTable && refId) { doc = await withCtx(s, async (c) => (await c.query("insert into documents(farm_id,ref_table,ref_id,kind,title,file,mime,size_bytes,sha256,tags,expires_on,uploaded_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) returning *", [s.farmId, String(refTable), String(refId), String(fd.get("kind") ?? "FILE"), String(fd.get("title") ?? f.name), url, f.type, buf.length, sha, String(fd.get("tags") ?? "").split(",").map((x) => x.trim()).filter(Boolean), fd.get("expires_on") ? String(fd.get("expires_on")) : null, s.staffId])).rows[0]); }
  return NextResponse.json({ url, sha256: sha, size: buf.length, document: doc });
}
