/* Sinh dữ liệu "trại đã vận hành 30 tháng" cho F01 + cơ cấu nhân sự đầy đủ. Chạy: pnpm db:seed:history */
import { Client } from "pg"; import { readFileSync } from "fs"; import "dotenv/config";
const ADMIN = process.env.DATABASE_ADMIN_URL ?? "postgres://postgres:itranos@localhost:54499/itranos";
async function main() { const c = new Client({ connectionString: ADMIN }); await c.connect();
  for (const f of ["scripts/seed-history.sql", "scripts/seed-history-staff.sql"]) { const t0 = Date.now(); const r = await c.query(readFileSync(f, "utf8")); const last = Array.isArray(r) ? r[r.length - 1] : r; console.log(f, "ok", Math.round((Date.now() - t0) / 1000) + "s"); if (last?.rows) console.table(last.rows); }
  await c.end(); }
main().catch((e) => { console.error(e); process.exit(1); });
