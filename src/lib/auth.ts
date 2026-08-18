import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";
import { adminPool, type Ctx } from "./db";

const COOKIE = "itran_session";
const secret = () => new TextEncoder().encode(process.env.SESSION_SECRET ?? "dev-secret-change-me-please-32chars!!");

export type Session = Ctx & { staffName: string; position: string | null; farmName?: string };

export async function login(loginId: string, pin: string, deviceId?: string): Promise<Session | null> {
  const r = await adminPool().query(
    `select s.id, s.org_id, s.farm_id, s.role, s.full_name, s.position, s.farm_ids, s.active,
            (s.pin_hash = crypt($2, s.pin_hash)) as ok
       from staff s where (s.login=$1 or s.phone=$1)`,
    [loginId, pin]);
  const s = r.rows[0];
  if (!s || !s.ok || !s.active) return null;
  const farmIds: string[] = s.farm_ids?.length ? s.farm_ids : s.farm_id ? [s.farm_id] : [];
  const farmId = s.farm_id ?? farmIds[0] ?? "";
  const sess: Session = { orgId: s.org_id, farmId, role: s.role, staffId: s.id, farmIds, staffName: s.full_name, position: s.position };
  await adminPool().query("insert into sessions(staff_id, farm_id, device_id, expires_at) values ($1,$2,$3, now() + interval '7 days')", [s.id, farmId, deviceId ?? null]);
  return sess;
}

export async function setSessionCookie(sess: Session) {
  const token = await new SignJWT(sess as unknown as Record<string, unknown>).setProtectedHeader({ alg: "HS256" }).setExpirationTime("7d").sign(secret());
  (await cookies()).set(COOKIE, token, { httpOnly: true, sameSite: "lax", path: "/", maxAge: 7 * 86400 });
}
export async function clearSession() { (await cookies()).delete(COOKIE); }

export async function getSession(): Promise<Session | null> {
  const t = (await cookies()).get(COOKIE)?.value;
  if (!t) return null;
  try { const { payload } = await jwtVerify(t, secret()); return payload as unknown as Session; } catch { return null; }
}
export async function requireSession(): Promise<Session> {
  const s = await getSession();
  if (!s) throw new Error("ERR_UNAUTHENTICATED");
  return s;
}
export async function verifyToken(t: string): Promise<Session | null> {
  try { const { payload } = await jwtVerify(t, secret()); return payload as unknown as Session; } catch { return null; }
}
export const COOKIE_NAME = COOKIE;

/** Vai → phân hệ được ghi (ABAC nhẹ) */
export const ROLE_HOME: Record<string, string> = {
  worker: "/ca", team_lead: "/ca", tech_head: "/ktt", director: "/gd", owner: "/hq", auditor: "/audit", accountant: "/kho", it_engineer: "/ktt",
};
