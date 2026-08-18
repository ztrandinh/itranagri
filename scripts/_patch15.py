import io, os
R = "F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R + p) or R, exist_ok=True); io.open(R + p, "w", encoding="utf-8", newline="\n").write(s); print("w", p)
def rw(p, fn): s = io.open(R + p, encoding="utf-8").read(); n = fn(s); assert n != s, p; io.open(R + p, "w", encoding="utf-8", newline="\n").write(n); print("ok", p)

# ---------- 1. Docker / compose / CI ----------
w("Dockerfile", '''# ITRAN OS — Next.js 16 standalone
FROM node:22-alpine AS base
RUN corepack enable && apk add --no-cache postgresql17-client
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm build
FROM node:22-alpine AS run
RUN apk add --no-cache postgresql17-client tzdata && corepack enable
ENV NODE_ENV=production TZ=Asia/Ho_Chi_Minh PORT=3000 SCHEDULER=1
WORKDIR /app
COPY --from=base /app/.next/standalone ./
COPY --from=base /app/.next/static ./.next/static
COPY --from=base /app/public ./public
COPY --from=base /app/supabase ./supabase
COPY --from=base /app/scripts ./scripts
COPY --from=base /app/node_modules/tsx ./node_modules/tsx
EXPOSE 3000
CMD ["node", "server.js"]
''')
w("docker-compose.yml", '''# ITRAN OS — chạy trọn bộ: Postgres 17 + app (dữ liệu & backup để ngoài ổ C: đặt DATA_DIR/BACKUP_DIR)
services:
  db:
    image: public.ecr.aws/supabase/postgres:17.6.1.155
    restart: unless-stopped
    environment: { POSTGRES_PASSWORD: "${PG_PASSWORD:-itranos}", POSTGRES_DB: itranos }
    volumes: ["${DATA_DIR:-./data/pg}:/var/lib/postgresql/data"]
    ports: ["${PG_PORT:-54499}:5432"]
    healthcheck: { test: ["CMD-SHELL", "pg_isready -U postgres"], interval: 10s, retries: 10 }
  app:
    build: .
    restart: unless-stopped
    depends_on: { db: { condition: service_healthy } }
    environment:
      DATABASE_ADMIN_URL: "postgres://postgres:${PG_PASSWORD:-itranos}@db:5432/itranos"
      DATABASE_URL: "postgres://app_user:app_user_pw@db:5432/itranos"
      SESSION_SECRET: "${SESSION_SECRET:?set SESSION_SECRET}"
      JOB_KEY: "${JOB_KEY:-dev-job-key}"
      BACKUP_DIR: /backups
      UPLOAD_DIR: /uploads
      SCHEDULER: "1"
    volumes: ["${BACKUP_DIR:-./data/backups}:/backups", "${UPLOAD_DIR:-./data/uploads}:/uploads"]
    ports: ["${APP_PORT:-3111}:3000"]
    command: sh -c "node node_modules/tsx/dist/cli.mjs scripts/migrate.ts && node server.js"
''')
w(".github/workflows/ci.yml", '''name: CI
on: { push: { branches: [main] }, pull_request: {} }
jobs:
  build-test:
    runs-on: ubuntu-latest
    services:
      pg:
        image: postgres:17
        env: { POSTGRES_PASSWORD: itranos, POSTGRES_DB: itranos }
        ports: ["54499:5432"]
        options: >-
          --health-cmd "pg_isready -U postgres" --health-interval 10s --health-timeout 5s --health-retries 10
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: 10 }
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - name: Migrate
        env: { DATABASE_ADMIN_URL: "postgres://postgres:itranos@localhost:54499/itranos", DATABASE_URL: "postgres://app_user:app_user_pw@localhost:54499/itranos", SESSION_SECRET: ci-secret }
        run: pnpm db:migrate
      - name: Lint & types
        run: pnpm lint && pnpm exec tsc --noEmit
      - name: Tests
        env: { DATABASE_ADMIN_URL: "postgres://postgres:itranos@localhost:54499/itranos", DATABASE_URL: "postgres://app_user:app_user_pw@localhost:54499/itranos", SESSION_SECRET: ci-secret }
        run: pnpm test
      - name: Build
        env: { DATABASE_ADMIN_URL: "postgres://postgres:itranos@localhost:54499/itranos", DATABASE_URL: "postgres://app_user:app_user_pw@localhost:54499/itranos", SESSION_SECRET: ci-secret }
        run: pnpm build
''')
rw("next.config.ts", lambda s: s.replace("const nextConfig: NextConfig = {\n  /* config options here */\n};", "const nextConfig: NextConfig = {\n  output: \"standalone\",\n  serverExternalPackages: [\"pg\"],\n};"))
w(".dockerignore", "node_modules\n.next\nbackups\ndata\npublic/uploads\n.env\n.git\n")

# ---------- 2. Backup: pg_dump + off-site + retention ----------
def jobs(s):
    return s.replace('''      out[`backup:${f}`] = { file: `backups/${f}/${name}`, bytes: buf.length, tables: Object.keys(manifest).length };''', '''      out[`backup:${f}`] = { file: `backups/${f}/${name}`, bytes: buf.length, tables: Object.keys(manifest).length };
      // OFF-SITE: sao chép sang BACKUP_DIR (ổ khác/NAS/mount cloud) + pg_dump toàn DB (docker exec hoặc pg_dump cục bộ) + xóa bản >30 ngày
      const off = process.env.BACKUP_DIR; if (off) { try { await mkdir(join(off, f), { recursive: true }); await writeFile(join(off, f, name), buf); out[`backup_offsite:${f}`] = join(off, f, name); } catch (e) { out[`backup_offsite:${f}`] = `ERR ${(e as Error).message}`; } }
      try { const { execFile } = await import("node:child_process"); const { promisify } = await import("node:util"); const run = promisify(execFile); const dumpDir = off ?? join(process.cwd(), "backups"); const dumpName = join(dumpDir, `itranos-${new Date().toISOString().slice(0, 10)}.dump`);
        const url = process.env.DATABASE_ADMIN_URL ?? ""; const m = url.match(/^postgres(?:ql)?:\\/\\/([^:]+):([^@]+)@([^:/]+):?(\\d+)?\\/(.+)$/);
        try { await run("pg_dump", ["-Fc", "-f", dumpName, url], { timeout: 600e3 }); out["pg_dump"] = dumpName; }
        catch { if (m) { const cont = process.env.PG_CONTAINER ?? "itranos_db"; const { stdout } = await run("docker", ["exec", cont, "pg_dump", "-U", m[1], "-Fc", m[5]], { maxBuffer: 2e9, encoding: "buffer", timeout: 600e3 }); await writeFile(dumpName, stdout as unknown as Buffer); out["pg_dump"] = `${dumpName} (via docker exec ${cont})`; } }
        const { readdir, stat, unlink } = await import("node:fs/promises"); const keepDays = Number(process.env.BACKUP_KEEP_DAYS ?? 30); for (const d of [dumpDir, join(dumpDir, f)]) { try { for (const fn of await readdir(d)) { const p = join(d, fn); const st = await stat(p); if (st.isFile() && Date.now() - st.mtimeMs > keepDays * 86400e3) await unlink(p); } } catch { /* */ } }
      } catch (e) { out["pg_dump"] = `ERR ${(e as Error).message.slice(0, 120)}`; }''')
rw("src/app/api/jobs/[job]/route.ts", jobs)

# ---------- 3. Scheduler nội bộ (instrumentation) ----------
w("src/instrumentation.ts", '''/** Lịch chạy nội bộ (không cần cron ngoài): bật bằng SCHEDULER=1. Mỗi phút: dispatch thông báo + kênh gửi + webhook; 01:15 hằng đêm: jobs/all + backup; 06:00: tasks. Chạy 1 lần/process (Node runtime). */
export async function register() {
  if (process.env.NEXT_RUNTIME !== "nodejs" || process.env.SCHEDULER !== "1") return;
  const g = globalThis as unknown as { __itranSched?: boolean }; if (g.__itranSched) return; g.__itranSched = true;
  const { dispatchEvents } = await import("@/lib/notify"); const { deliverChannels } = await import("@/lib/channels"); const { adminPool } = await import("@/lib/db");
  const port = process.env.PORT ?? "3000"; const key = process.env.JOB_KEY ?? "dev-job-key";
  const farms = async () => (await adminPool().query("select id from farms where status='ACTIVE'")).rows.map((r) => String(r.id));
  const call = async (job: string, farm: string) => { try { await fetch(`http://127.0.0.1:${port}/api/jobs/${job}?farm=${farm}`, { method: "POST", headers: { "x-job-key": key } }); } catch (e) { console.error("sched", job, farm, (e as Error).message); } };
  setInterval(async () => { try { await dispatchEvents(); await deliverChannels(); } catch (e) { console.error("sched:dispatch", (e as Error).message); } }, 60e3);
  let lastNight = "", lastMorning = "";
  setInterval(async () => { const now = new Date(); const hm = now.toTimeString().slice(0, 5); const day = now.toISOString().slice(0, 10);
    if (hm === "01:15" && lastNight !== day) { lastNight = day; for (const f of await farms()) { await call("all", f); await call("backup", f); } }
    if (hm === "06:00" && lastMorning !== day) { lastMorning = day; for (const f of await farms()) await call("tasks", f); }
  }, 30e3);
  console.log("[ITRAN OS] scheduler on: dispatch mỗi phút · jobs/all+backup 01:15 · tasks 06:00");
}
''')

# ---------- 4. Auth hardening ----------
def auth(s):
    return s.replace('''  const s = r.rows[0];
  if (!s || !s.ok || !s.active) return null;''', '''  const s = r.rows[0];
  // khóa sau 5 lần sai trong 15 phút (15 phút), ghi nhật ký đăng nhập
  const fails = Number((await adminPool().query("select count(*) as n from login_attempts where login=$1 and not ok and ts > now() - interval '15 minutes'", [loginId])).rows[0].n);
  if (fails >= 5 || (s?.locked_until && new Date(s.locked_until) > new Date())) { await adminPool().query("insert into login_attempts(login, ok) values ($1,false)", [loginId]); throw new Error("ERR_LOCKED: sai quá 5 lần — thử lại sau 15 phút hoặc nhờ quản trị mở khóa"); }
  await adminPool().query("insert into login_attempts(login, ok) values ($1,$2)", [loginId, !!(s && s.ok && s.active)]);
  if (!s || !s.ok || !s.active) return null;''').replace("select s.id, s.org_id, s.farm_id, s.role, s.full_name, s.position, s.farm_ids, s.active,", "select s.id, s.org_id, s.farm_id, s.role, s.full_name, s.position, s.farm_ids, s.active, s.locked_until, s.must_change_pin, s.pin_changed_at,")
rw("src/lib/auth.ts", auth)
def loginr(s):
    return s.replace('''  const s = await login(String(l), String(pin), device_id);
  if (!s) return NextResponse.json({ error: "ERR_BAD_CREDENTIALS" }, { status: 401 });''', '''  let s; try { s = await login(String(l), String(pin), device_id); } catch (e) { return NextResponse.json({ error: (e as Error).message }, { status: 423 }); }
  if (!s) return NextResponse.json({ error: "ERR_BAD_CREDENTIALS" }, { status: 401 });''')
rw("src/app/api/auth/login/route.ts", loginr)
def actions(s):
    return s.replace('''          if (!/^\\d{4,8}$/.test(String(b.new_pin))) throw new Error("ERR_PIN_FORMAT");''', '''          // Chính sách PIN: công nhân ≥4 số; quản lý/kế toán/IT/chủ ≥6 số; không trùng 1234/0000/1111…; không trùng PIN cũ
          const np = String(b.new_pin); const minLen = ["owner","director","accountant","it_engineer","auditor","tech_head"].includes(s.role) ? 6 : 4;
          if (!new RegExp(`^\\\\d{${minLen},8}$`).test(np)) throw new Error(`ERR_PIN_FORMAT: PIN phải ${minLen}–8 chữ số`);
          if (/^(\\d)\\1+$/.test(np) || ["1234","123456","12345678","0000","1111","4321","654321"].includes(np)) throw new Error("ERR_PIN_WEAK: PIN quá dễ đoán");
          if (String(b.old_pin) === np) throw new Error("ERR_PIN_SAME");''').replace('''          await c.query("update staff set pin_hash=crypt($2, gen_salt('bf')) where id=$1", [s.staffId, String(b.new_pin)]); return { ok: true };''', '''          await c.query("update staff set pin_hash=crypt($2, gen_salt('bf')), pin_changed_at=now(), must_change_pin=false where id=$1", [s.staffId, np]); return { ok: true };''').replace('        default: throw new Error("ERR_UNKNOWN_ACTION");', '''        case "unlock_staff": { if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update staff set locked_until=null where id=$1", [b.staff_id]); await c.query("delete from login_attempts where login in (select login from staff where id=$1)", [b.staff_id]); return { ok: true }; }
        case "reset_pin": { if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const tmp = String(Math.floor(100000 + Math.random() * 900000)); await c.query("update staff set pin_hash=crypt($2, gen_salt('bf')), must_change_pin=true, locked_until=null where id=$1", [b.staff_id, tmp]); await c.query("update sessions set revoked_at=now() where staff_id=$1 and revoked_at is null", [b.staff_id]); return { ok: true, temp_pin: tmp, note: "PIN tạm — nhân viên phải đổi ngay khi đăng nhập" }; }
        default: throw new Error("ERR_UNKNOWN_ACTION");''')
rw("src/app/api/actions/route.ts", actions)
# rate limit in proxy (in-memory per IP: 600 req / phút cho API; 20 req / phút cho login)
def proxy(s):
    s = s.replace('export async function proxy(req: NextRequest) {\n  const { pathname } = req.nextUrl;', '''const RL = new Map<string, { n: number; t: number }>();
function limited(key: string, max: number): boolean { const now = Date.now(); const e = RL.get(key); if (!e || now - e.t > 60e3) { RL.set(key, { n: 1, t: now }); return false; } e.n++; if (RL.size > 5000) RL.clear(); return e.n > max; }
export async function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "local";
  if (pathname.startsWith("/api/auth/login") && limited(`login:${ip}`, 20)) return NextResponse.json({ error: "ERR_RATE_LIMIT" }, { status: 429 });
  if (pathname.startsWith("/api/") && limited(`api:${ip}`, 900)) return NextResponse.json({ error: "ERR_RATE_LIMIT" }, { status: 429 });''')
    return s
rw("src/proxy.ts", proxy)

# ---------- 5. SW: đọc offline cho /api/data & /api/series (network-first, fallback cache) ----------
def sw(s):
    return s.replace('''  if (e.request.method !== "GET" || u.pathname.startsWith("/api/")) return;''', '''  if (e.request.method !== "GET") return;
  if (u.pathname.startsWith("/api/")) {
    // Đọc offline: /api/data, /api/series, /api/list, /api/admin (GET) → network-first, rơi về cache khi mất mạng
    if (/^\\/api\\/(data|series|list|admin|notifications|search)/.test(u.pathname)) e.respondWith(fetch(e.request).then(r => { if (r.ok) { const cp = r.clone(); caches.open(V + "-api").then(c => c.put(e.request, cp)); } return r; }).catch(() => caches.match(e.request).then(r => r || new Response(JSON.stringify({ rows: [], offline: true }), { headers: { "content-type": "application/json" } }))));
    return;
  }''').replace('const V = "itran-v3";', 'const V = "itran-v4";').replace('ks.filter(k => k !== V)', 'ks.filter(k => k !== V && k !== V + "-api")')
rw("public/sw.js", sw)
