import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
/** POST /api/import/bank — CSV sao kê (cột: ngày, số tiền, ghi chú[, chiều]) → bank_statement_lines (RC10). Chấp nhận nhiều định dạng ngày. */
export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  if (!["accountant","director","owner","it_engineer"].includes(s.role)) return NextResponse.json({ error: "ERR_FORBIDDEN_ROLE" }, { status: 403 });
  const fd = await req.formData(); const f = fd.get("file") as File | null; const bank = String(fd.get("bank") ?? "");
  if (!f) return NextResponse.json({ error: "ERR_NO_FILE" }, { status: 400 });
  const text = (await f.text()).replace(/^\uFEFF/, "");
  const lines = text.split(/\r?\n/).filter((l) => l.trim());
  const sep = lines[0].includes(";") ? ";" : lines[0].includes("\t") ? "\t" : ",";
  const head = lines[0].split(sep).map((h) => h.trim().toLowerCase());
  const idx = (names: string[]) => head.findIndex((h) => names.some((n) => h.includes(n)));
  const iDate = idx(["ngay", "date", "ngày"]), iAmt = idx(["so tien", "amount", "số tiền", "credit", "ghi co", "ghi có"]), iMemo = idx(["noi dung", "memo", "dien giai", "diễn giải", "nội dung", "description"]), iDebit = idx(["debit", "ghi no", "ghi nợ"]);
  if (iDate < 0 || iAmt < 0) return NextResponse.json({ error: "ERR_COLUMNS", head }, { status: 400 });
  const parseDate = (v: string) => { const t = v.trim(); const m = t.match(/^(\d{1,2})[\/.-](\d{1,2})[\/.-](\d{4})/); if (m) return `${m[3]}-${m[2].padStart(2, "0")}-${m[1].padStart(2, "0")}`; const d = new Date(t); return isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10); };
  const num = (v: string) => Number(String(v ?? "").replace(/[^0-9.-]/g, "").replace(/\.(?=\d{3}(\D|$))/g, "")) || 0;
  const batch = "bank-" + Date.now(); let ok = 0, bad = 0;
  await withCtx(s, async (c) => {
    for (const l of lines.slice(1)) { const cols = l.split(sep); const d = parseDate(cols[iDate] ?? ""); const credit = num(cols[iAmt] ?? ""); const debit = iDebit >= 0 ? num(cols[iDebit] ?? "") : 0;
      if (!d || (!credit && !debit)) { bad++; continue; }
      const amount = credit || debit; const dir = credit ? "IN" : "OUT";
      await c.query("insert into bank_statement_lines(farm_id,bank,txn_date,amount,direction,memo,imported_by,import_batch) values ($1,$2,$3,$4,$5,$6,$7,$8)", [s.farmId, bank || null, d, amount, dir, (cols[iMemo] ?? "").slice(0, 300), s.staffId, batch]); ok++; }
  });
  return NextResponse.json({ ok: true, imported: ok, skipped: bad, batch });
}
