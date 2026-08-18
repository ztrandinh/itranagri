import { NextResponse, type NextRequest } from "next/server";
import { verifyToken, COOKIE_NAME } from "@/lib/auth";
const RL = new Map<string, { n: number; t: number }>();
function limited(key: string, max: number): boolean { const now = Date.now(); const e = RL.get(key); if (!e || now - e.t > 60e3) { RL.set(key, { n: 1, t: now }); return false; } e.n++; if (RL.size > 5000) RL.clear(); return e.n > max; }
export async function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "local";
  if (pathname.startsWith("/api/auth/login") && limited(`login:${ip}`, 20)) return NextResponse.json({ error: "ERR_RATE_LIMIT" }, { status: 429 });
  if (pathname.startsWith("/api/") && limited(`api:${ip}`, 900)) return NextResponse.json({ error: "ERR_RATE_LIMIT" }, { status: 429 });
  const pub = pathname === "/login" || pathname.startsWith("/api/auth/login") || pathname.startsWith("/trace") || pathname.startsWith("/chuan") || pathname.startsWith("/api/public") || pathname.startsWith("/api/ingest/") || pathname.startsWith("/api/webhooks/") || pathname === "/api/health" || pathname.startsWith("/khach/") || pathname.startsWith("/doi-tac/") || pathname.startsWith("/_next") || pathname === "/manifest.webmanifest" || pathname === "/sw.js" || /\.(png|svg|ico|jpg|webp)$/.test(pathname);
  if (pub || (pathname.startsWith("/api/jobs/") && req.headers.get("x-job-key"))) return NextResponse.next();
  const t = req.cookies.get(COOKIE_NAME)?.value;
  const s = t ? await verifyToken(t) : null;
  if (!s) {
    if (pathname.startsWith("/api/")) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
    return NextResponse.redirect(new URL("/login?next=" + encodeURIComponent(pathname), req.url));
  }
  const h = new Headers(req.headers); h.set("x-pathname", pathname);
  return NextResponse.next({ request: { headers: h } });
}
export const config = { matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"] };
