/* rl_counters (0203): rate-limit đếm ở DB thay Map trong process — đúng khi chạy nhiều instance. */
import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { Client } from "pg";
import "dotenv/config";
import { rateLimited } from "../src/lib/ratelimit";
const ADMIN = process.env.DATABASE_ADMIN_URL ?? "postgres://postgres:itranagri@localhost:54499/itranagri";
let admin: Client;
const bucket = (s: string) => `test-rl-${s}-${process.pid}`;
beforeAll(async () => { admin = new Client({ connectionString: ADMIN }); await admin.connect(); });
afterAll(async () => { await admin.query("delete from rl_counters where bucket like 'test-rl-%'"); await admin.end(); });

describe("rl_counters (0203)", () => {
  it("dưới ngưỡng → không chặn; vượt ngưỡng → chặn", async () => {
    const b = bucket("a");
    for (let i = 0; i < 3; i++) expect(await rateLimited(b, 3)).toBe(false);
    expect(await rateLimited(b, 3)).toBe(true);
  });
  it("2 bucket khác nhau không đụng độ đếm của nhau", async () => {
    const b1 = bucket("b1"), b2 = bucket("b2");
    for (let i = 0; i < 5; i++) await rateLimited(b1, 2);
    expect(await rateLimited(b2, 2)).toBe(false);
  });
  it("qua cửa sổ 1 phút thì đếm lại từ đầu", async () => {
    const b = bucket("window");
    await admin.query("insert into rl_counters(bucket, window_start, count) values ($1, now() - interval '90 seconds', 999) on conflict (bucket) do update set window_start=excluded.window_start, count=excluded.count", [b]);
    expect(await rateLimited(b, 3)).toBe(false);
    const row = (await admin.query("select count from rl_counters where bucket=$1", [b])).rows[0];
    expect(Number(row.count)).toBe(1);
  });
});
