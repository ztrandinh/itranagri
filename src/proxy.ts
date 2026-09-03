import { NextResponse, type NextRequest } from "next/server";
import { verifyToken, COOKIE_NAME } from "@/lib/auth";
import { rateLimited } from "@/lib/ratelimit";
export async function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "local";
  if (pathname.startsWith("/api/auth/login") && await rateLimited(`login:${ip}`, 20)) return NextResponse.json({ error: "ERR_RATE_LIMIT" }, { status: 429 });
  // Ngưỡng riêng CHẶT hơn cho endpoint nhạy cảm (audit-pack/sales-tax export nặng dữ liệu tuân thủ,
  // upload/job dễ bị dò/spam) — trước đây chỉ có 1 ngưỡng chung 900/phút/IP cho MỌI route kể cả các
  // endpoint này, không phân hoá theo độ nhạy cảm.
  if (pathname.startsWith("/api/exports/") && await rateLimited(`exports:${ip}`, 30)) return NextResponse.json({ error: "ERR_RATE_LIMIT" }, { status: 429 });
  if (pathname.startsWith("/api/upload") && await rateLimited(`upload:${ip}`, 120)) return NextResponse.json({ error: "ERR_RATE_LIMIT" }, { status: 429 });
  if (pathname.startsWith("/api/jobs/") && await rateLimited(`jobs:${ip}`, 60)) return NextResponse.json({ error: "ERR_RATE_LIMIT" }, { status: 429 });
  if (pathname.startsWith("/api/") && await rateLimited(`api:${ip}`, 900)) return NextResponse.json({ error: "ERR_RATE_LIMIT" }, { status: 429 });
  const pub = pathname === "/login" || pathname.startsWith("/api/auth/login") || pathname.startsWith("/trace") || pathname.startsWith("/chuan") || pathname.startsWith("/api/public") || pathname.startsWith("/api/ingest/") || pathname.startsWith("/api/webhooks/") || pathname === "/api/health" || pathname.startsWith("/khach/") || pathname.startsWith("/doi-tac/") || pathname.startsWith("/_next") || pathname === "/manifest.webmanifest" || pathname === "/sw.js" || /\.(png|svg|ico|jpg|webp)$/.test(pathname);
  // Vercel Cron gọi GET kèm "Authorization: Bearer $CRON_SECRET" (không có x-job-key) — trước đây
  // middleware chỉ cho qua đường x-job-key, request Vercel Cron rơi thẳng vào nhánh "chưa đăng nhập"
  // bên dưới dù route handler (jobs/[job]/route.ts) đã hỗ trợ CRON_SECRET.
  const cronAuthed = !!process.env.CRON_SECRET && req.headers.get("authorization") === `Bearer ${process.env.CRON_SECRET}`;
  if (pub || (pathname.startsWith("/api/jobs/") && (req.headers.get("x-job-key") || cronAuthed))) return NextResponse.next();
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
