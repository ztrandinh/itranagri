import { NextResponse } from "next/server";
import { login, setSessionCookie, ROLE_HOME } from "@/lib/auth";
export async function POST(req: Request) {
  const { login: l, pin, device_id } = await req.json().catch(() => ({}));
  if (!l || !pin) return NextResponse.json({ error: "ERR_MISSING" }, { status: 400 });
  let s; try { s = await login(String(l), String(pin), device_id); } catch (e) { return NextResponse.json({ error: (e as Error).message }, { status: 423 }); }
  if (!s) return NextResponse.json({ error: "ERR_BAD_CREDENTIALS" }, { status: 401 });
  await setSessionCookie(s);
  return NextResponse.json({ session: s, home: ROLE_HOME[s.role] ?? "/ca" });
}
