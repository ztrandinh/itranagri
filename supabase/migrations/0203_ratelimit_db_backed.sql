-- 0203 · Rate-limit CHUYỂN từ in-memory (Map trong proxy.ts) sang đếm ở DB.
--
-- Map trong process không đồng bộ khi chạy NHIỀU instance (Vercel serverless — mỗi lambda 1 Map
-- riêng, giới hạn 900/phút/IP thực chất thành 900×N instance; Docker nhiều replica cũng vậy).
-- Không cần thêm hạ tầng mới (Redis…) — app đã có sẵn Postgres cho mọi request qua proxy() (verifyToken
-- đã query DB để kiểm sessions.revoked_at), nên đếm atomic ngay trong DB cùng transaction round-trip.
create table if not exists rl_counters(
  bucket text primary key,       -- vd 'login:1.2.3.4', 'exports:1.2.3.4'
  window_start timestamptz not null default now(),
  count int not null default 1
);
