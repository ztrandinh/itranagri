-- 0187 — cấp quyền pgcrypto cho app_user để reset_pin/change_pin/tạo staff chạy được
-- BUG (chỉ trên DB kiểu Supabase, pgcrypto nằm schema 'extensions'): app_user KHÔNG có USAGE
-- schema extensions → mọi thao tác PIN qua withCtx(app_user) lỗi:
--   'function gen_salt(unknown) does not exist' / 'permission denied for schema extensions'.
--   (login KHÔNG lỗi vì auth.ts dùng adminPool = superuser.)
-- REBUILD TRẮNG: 0001 chạy 'create extension pgcrypto' KHÔNG chỉ schema → pgcrypto vào PUBLIC,
--   app_user thấy được → không cần vá. Nên migration PHẢI phòng thủ: chỉ grant khi extensions tồn tại.
-- Idempotent, an toàn rebuild.

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'extensions') then
    grant usage on schema extensions to app_user;
    grant execute on all functions in schema extensions to app_user;
    -- app_user gọi crypt()/gen_salt() KHÔNG chỉ schema → phải có extensions trong search_path mặc định của role
    execute 'alter role app_user set search_path = "$user", public, extensions';
  end if;
end $$;
