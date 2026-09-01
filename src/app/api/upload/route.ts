import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { withCtx } from "@/lib/db";
/** Upload file/ảnh → public/uploads/{farm}/ (hoặc UPLOAD_DIR) + (tùy chọn) ghi vào bảng documents gắn đối tượng (ref_table, ref_id, kind, title, tags, expires_on).
 *  Ảnh nén ở client (lib/client). Prod: đổi sang object storage bằng cách thay hàm save(). */

// BẢO MẬT: trước đây tin thẳng đuôi file/Content-Type do client khai — không soi nội dung thật.
// File nằm ở public/uploads được Next serve tĩnh same-origin, không có CSP; upload .html/.svg
// chứa script có thể chạy same-origin (stored XSS) nếu chỉ đổi đuôi/Content-Type giả. Nay đọc
// magic bytes thật, và LẤY ĐUÔI THEO LOẠI ĐÃ NHẬN DIỆN (bỏ hoàn toàn đuôi client khai) — loại
// không nhận diện được (kể cả html/svg tự xưng là ảnh) bị từ chối thẳng.
function sniffExt(buf: Buffer): string | null {
  const b = buf;
  if (b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "jpg";
  if (b.length >= 8 && b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return "png";
  if (b.length >= 6 && b.subarray(0, 3).toString("ascii") === "GIF" && (b.subarray(3, 6).toString("ascii") === "87a" || b.subarray(3, 6).toString("ascii") === "89a")) return "gif";
  if (b.length >= 12 && b.subarray(0, 4).toString("ascii") === "RIFF" && b.subarray(8, 12).toString("ascii") === "WEBP") return "webp";
  if (b.length >= 5 && b.subarray(0, 5).toString("ascii") === "%PDF-") return "pdf";
  // ZIP container (docx/xlsx/pptx dùng chung định dạng) — không mở nội dung ra kiểm, chỉ chấp
  // nhận khi client khai đúng 1 trong 3 đuôi Office, tránh nhận bừa mọi file .zip là tài liệu.
  if (b.length >= 4 && (b[0] === 0x50 && b[1] === 0x4b && (b[2] === 0x03 || b[2] === 0x05 || b[2] === 0x07))) return "zip";
  return null;
}
const OFFICE_EXT = new Set(["docx", "xlsx", "pptx"]);

export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const fd = await req.formData(); const f = fd.get("file") as File | null; if (!f) return NextResponse.json({ error: "ERR_NO_FILE" }, { status: 400 });
  if (f.size > 25e6) return NextResponse.json({ error: "ERR_TOO_LARGE" }, { status: 413 });
  const buf = Buffer.from(await f.arrayBuffer()); const sha = createHash("sha256").update(buf).digest("hex");
  const sniffed = sniffExt(buf);
  const claimedExt = (f.name.split(".").pop() || "").toLowerCase().replace(/[^a-z0-9]/g, "");
  const ext = sniffed === "zip" ? (OFFICE_EXT.has(claimedExt) ? claimedExt : null) : sniffed;
  if (!ext) return NextResponse.json({ error: "ERR_UNSUPPORTED_FILE_TYPE", detail: "Chỉ nhận ảnh (jpg/png/gif/webp), PDF, hoặc Word/Excel/PowerPoint (docx/xlsx/pptx)." }, { status: 415 });
  const base = process.env.UPLOAD_DIR ?? join(process.cwd(), "public", "uploads"); const dir = join(base, s.farmId); await mkdir(dir, { recursive: true });
  const name = `${Date.now()}-${sha.slice(0, 16)}.${ext}`; await writeFile(join(dir, name), buf); const url = `/uploads/${s.farmId}/${name}`;
  let doc: Record<string, unknown> | null = null;
  const refTable = fd.get("ref_table"), refId = fd.get("ref_id");
  if (refTable && refId) { doc = await withCtx(s, async (c) => (await c.query("insert into documents(farm_id,ref_table,ref_id,kind,title,file,mime,size_bytes,sha256,tags,expires_on,uploaded_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) returning *", [s.farmId, String(refTable), String(refId), String(fd.get("kind") ?? "FILE"), String(fd.get("title") ?? f.name), url, f.type, buf.length, sha, String(fd.get("tags") ?? "").split(",").map((x) => x.trim()).filter(Boolean), fd.get("expires_on") ? String(fd.get("expires_on")) : null, s.staffId])).rows[0]); }
  return NextResponse.json({ url, sha256: sha, size: buf.length, document: doc });
}
