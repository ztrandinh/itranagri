/* Chạy migration SQL thuần theo thứ tự tên file; ghi schema_migrations. Dùng: pnpm db:migrate [--reset] */
import { Client } from "pg";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import "dotenv/config";

const ADMIN_URL = process.env.DATABASE_ADMIN_URL ?? "postgres://postgres:itranos@localhost:54499/itranos";
const dir = join(process.cwd(), "supabase", "migrations");

async function main() {
  const reset = process.argv.includes("--reset");
  const c = new Client({ connectionString: ADMIN_URL });
  await c.connect();
  if (reset) {
    console.log("!! RESET schema public");
    await c.query("drop schema public cascade; create schema public; grant all on schema public to public;");
  }
  await c.query("create table if not exists schema_migrations(name text primary key, applied_at timestamptz default now())");
  const done = new Set((await c.query("select name from schema_migrations")).rows.map((r) => r.name));
  const files = readdirSync(dir).filter((f) => f.endsWith(".sql")).sort();
  for (const f of files) {
    if (done.has(f)) continue;
    const sql = readFileSync(join(dir, f), "utf8");
    process.stdout.write(`applying ${f} … `);
    try {
      await c.query("begin");
      await c.query(sql);
      await c.query("insert into schema_migrations(name) values ($1)", [f]);
      await c.query("commit");
      console.log("ok");
    } catch (e) {
      await c.query("rollback");
      console.error("\nFAILED", f, e);
      process.exit(1);
    }
  }
  await c.end();
  console.log("migrations up to date");
}
main();
