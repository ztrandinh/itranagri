import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";
import { adminPool, type Ctx } from "./db";

const COOKIE = "itran_session";
const DEV_DEFAULT_SECRET = "dev-secret-change-me-please-32chars!!";
// Trước đây chỉ docker-compose.yml (`SESSION_SECRET:?set SESSION_SECRET`) chặn thiếu biến — đường
// deploy không qua compose (vd Vercel) có thể âm thầm ký JWT bằng secret mặc định công khai này.
// Chặn khi THỰC SỰ ký/xác minh token ở production (không đặt ở module top-level: `next build` tự
// chạy với NODE_ENV=production để thu thập page data, import module này mà chưa handle request nào
// — kiểm ở đó làm vỡ build ngay cả khi .env dev chỉ dùng để build, chưa từng chạy request thật).
function secret() {
  const v = process.env.SESSION_SECRET;
  if (process.env.NODE_ENV === "production" && (!v || v === DEV_DEFAULT_SECRET || v.length < 32)) {
    throw new Error("ERR_SESSION_SECRET_UNSAFE: SESSION_SECRET chưa set, dùng giá trị mặc định công khai, hoặc quá ngắn (<32 ký tự) — bắt buộc set giá trị ngẫu nhiên riêng ở production.");
  }
  return new TextEncoder().encode(v ?? DEV_DEFAULT_SECRET);
}

export type Session = Ctx & { sid: string; staffName: string; position: string | null; dept?: string | null; farmName?: string };

export async function login(loginId: string, pin: string, deviceId?: string): Promise<Session | null> {
  const r = await adminPool().query(
    `select s.id, s.org_id, s.farm_id, s.role, s.full_name, s.position, s.dept, s.farm_ids, s.active, s.locked_until, s.must_change_pin, s.pin_changed_at,
            a.code as account, a.position_code,
            (s.pin_hash = crypt($2, s.pin_hash)) as ok
       from staff s
       left join job_accounts a on a.login = s.login
      where (s.login=$1 or s.phone=$1)`,
    [loginId, pin]);
  const s = r.rows[0];
  const ok = !!(s && s.ok && s.active);
  // khóa sau 5 lần sai trong 15 phút — trước đây "đếm rồi mới ghi" là 2 câu lệnh tách rời (race:
  // nhiều request sai gần như đồng thời có thể cùng đọc "chưa đủ 5 lần" trước khi cái nào ghi log,
  // vượt quá ngưỡng khóa). Dùng advisory lock theo loginId để đếm+ghi atomic trong 1 transaction.
  const lock = await adminPool().connect();
  let locked = false;
  try {
    await lock.query("begin");
    await lock.query("select pg_advisory_xact_lock(hashtext($1))", [loginId]);
    const fails = Number((await lock.query("select count(*) as n from login_attempts where login=$1 and not ok and ts > now() - interval '15 minutes'", [loginId])).rows[0].n);
    locked = fails >= 5 || !!(s?.locked_until && new Date(s.locked_until) > new Date());
    await lock.query("insert into login_attempts(login, ok) values ($1,$2)", [loginId, locked ? false : ok]);
    await lock.query("commit");
  } catch (e) { await lock.query("rollback").catch(() => {}); throw e; } finally { lock.release(); }
  if (locked) throw new Error("ERR_LOCKED: sai quá 5 lần — thử lại sau 15 phút hoặc nhờ quản trị mở khóa");
  if (!ok) return null;
  const farmIds: string[] = s.farm_ids?.length ? s.farm_ids : s.farm_id ? [s.farm_id] : [];
  const farmId = s.farm_id ?? farmIds[0] ?? "";
  const sessionRow = await adminPool().query("insert into sessions(staff_id, farm_id, device_id, expires_at) values ($1,$2,$3, now() + interval '7 days') returning id", [s.id, farmId, deviceId ?? null]);
  const sess: Session = { sid: sessionRow.rows[0].id, orgId: s.org_id, farmId, role: s.role, staffId: s.id, farmIds, staffName: s.full_name, position: s.position, dept: s.dept, account: s.account ?? null, positionCode: s.position_code ?? null };
  return sess;
}

export async function setSessionCookie(sess: Session) {
  const token = await new SignJWT(sess as unknown as Record<string, unknown>).setProtectedHeader({ alg: "HS256" }).setExpirationTime("7d").sign(secret());
  (await cookies()).set(COOKIE, token, { httpOnly: true, secure: true, sameSite: "lax", path: "/", maxAge: 7 * 86400 });
}
export async function clearSession() { (await cookies()).delete(COOKIE); }

/** Phiên đã bị thu hồi (revoke_sessions/reset_pin) hoặc hết hạn ở DB thì token dù còn hợp lệ chữ ký cũng vô hiệu. */
async function isSessionLive(sid: unknown): Promise<boolean> {
  if (typeof sid !== "string" || !sid) return false;
  const r = await adminPool().query("select 1 from sessions where id=$1 and revoked_at is null and expires_at > now()", [sid]);
  return (r.rowCount ?? 0) > 0;
}
export async function getSession(): Promise<Session | null> {
  const t = (await cookies()).get(COOKIE)?.value;
  if (!t) return null;
  try {
    const { payload } = await jwtVerify(t, secret());
    if (!(await isSessionLive((payload as unknown as Session).sid))) return null;
    return payload as unknown as Session;
  } catch { return null; }
}
export async function requireSession(): Promise<Session> {
  const s = await getSession();
  if (!s) throw new Error("ERR_UNAUTHENTICATED");
  return s;
}
export async function verifyToken(t: string): Promise<Session | null> {
  try {
    const { payload } = await jwtVerify(t, secret());
    if (!(await isSessionLive((payload as unknown as Session).sid))) return null;
    return payload as unknown as Session;
  } catch { return null; }
}
export const COOKIE_NAME = COOKIE;

/** Vai → phân hệ được ghi (ABAC nhẹ) */
export const ROLE_HOME: Record<string, string> = {
  worker: "/ca", team_lead: "/ca", tech_head: "/ktt", director: "/gd", owner: "/hq", auditor: "/audit", accountant: "/kho", it_engineer: "/ktt",
};
