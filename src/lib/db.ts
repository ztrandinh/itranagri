import { Pool, type PoolClient } from "pg";

declare global {
  // eslint-disable-next-line no-var
  var __itranPools: { app?: Pool; admin?: Pool } | undefined;
}
const g = globalThis as typeof globalThis & { __itranPools?: { app?: Pool; admin?: Pool } };
g.__itranPools ??= {};

// Fallback dev mặc định (khớp .env.example) để worktree/clone không có .env vẫn chạy; prod luôn set env nên fallback không kích hoạt.
const DEV_APP_URL = "postgres://app_user:app_user_pw@localhost:54499/itranagri";
const DEV_ADMIN_URL = "postgres://postgres:itranagri@localhost:54499/itranagri";

export function appPool(): Pool {
  g.__itranPools!.app ??= new Pool({ connectionString: process.env.DATABASE_URL ?? DEV_APP_URL, max: 10 });
  return g.__itranPools!.app;
}
export function adminPool(): Pool {
  g.__itranPools!.admin ??= new Pool({ connectionString: process.env.DATABASE_ADMIN_URL ?? DEV_ADMIN_URL, max: 3 });
  return g.__itranPools!.admin;
}

export type Ctx = { orgId: string; farmId: string; role: string; staffId: string; farmIds: string[] };

/** Chạy fn trong 1 transaction với ngữ cảnh RLS (SET LOCAL app.*). */
export async function withCtx<T>(ctx: Ctx, fn: (c: PoolClient) => Promise<T>): Promise<T> {
  const c = await appPool().connect();
  try {
    await c.query("begin");
    await c.query("select set_config('app.org_id',$1,true), set_config('app.farm_id',$2,true), set_config('app.role',$3,true), set_config('app.staff_id',$4,true), set_config('app.farm_ids',$5,true)",
      [ctx.orgId, ctx.farmId, ctx.role, ctx.staffId, ctx.farmIds.join(",")]);
    const r = await fn(c);
    await c.query("commit");
    return r;
  } catch (e) {
    await c.query("rollback").catch(() => {});
    throw e;
  } finally {
    c.release();
  }
}

export async function q<T = Record<string, unknown>>(ctx: Ctx, sql: string, params: unknown[] = []): Promise<T[]> {
  return withCtx(ctx, async (c) => (await c.query(sql, params)).rows as T[]);
}
