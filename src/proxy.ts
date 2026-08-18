import { NextResponse, type NextRequest } from "next/server";
import { verifyToken, COOKIE_NAME } from "@/lib/auth";
export async function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const pub = pathname === "/login" || pathname.startsWith("/api/auth/login") || pathname.startsWith("/trace") || pathname.startsWith("/chuan") || pathname.startsWith("/api/public") || pathname.startsWith("/_next") || pathname === "/manifest.webmanifest" || pathname === "/sw.js" || /\.(png|svg|ico|jpg|webp)$/.test(pathname);
  if (pub || (pathname.startsWith("/api/jobs/") && req.headers.get("x-job-key"))) return NextResponse.next();
  const t = req.cookies.get(COOKIE_NAME)?.value;
  const s = t ? await verifyToken(t) : null;
  if (!s) {
    if (pathname.startsWith("/api/")) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
    return NextResponse.redirect(new URL("/login?next=" + encodeURIComponent(pathname), req.url));
  }
  return NextResponse.next();
}
export const config = { matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"] };
