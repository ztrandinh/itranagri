-- 0105 — code_for(): mã TẤT ĐỊNH theo khoá tự nhiên
--
-- Vì sao cần: dữ liệu gốc trong migration và script gieo được ghép mã bằng tay
--   insert into locations ... values (F||'-CH-NAI-1', ...)
--   insert into animal_groups ... values (F||'-DAN-NAI-01', ..., F||'-CH-NAI-1', ...)
-- tức là các bảng THAM CHIẾU CHÉO nhau bằng chính chuỗi mã. Nếu chỉ thay bằng make_code()
-- (sinh số tăng dần) thì hai chỗ gọi sẽ ra hai mã khác nhau và tham chiếu gãy sạch.
--
-- code_for(loại, phạm vi, KHOÁ TỰ NHIÊN) giải bài này: cùng một khoá tự nhiên thì LUÔN trả về
-- cùng một mã, nhớ trong bảng code_alias. Nhờ vậy seed giữ nguyên cách viết dễ đọc
--   code_for('khu_vuc', F, 'CH-NAI-1')
-- mà mã sinh ra vẫn đúng chuẩn F01-KV-00001, và mọi chỗ tham chiếu tới 'CH-NAI-1' đều khớp.
--
-- Đây là sản phẩm đang thử nghiệm: KHÔNG giữ mã cũ, không chạy song song hai hệ.
-- Bỏ luôn cột legacy_pattern trong sổ đăng ký.

-- View cũ đang bám vào cột legacy_pattern → gỡ view trước rồi mới bỏ cột.
drop view if exists v_code_health;
alter table code_registry drop column if exists legacy_pattern;

-- Bảng nhớ: khoá tự nhiên -> mã chuẩn.
create table if not exists code_alias (
  object_type  text not null references code_registry(object_type),
  scope_id     text not null,
  natural_key  text not null,          -- khoá tự nhiên dùng trong seed ('CH-NAI-1', 'DAN-NAI-01'…)
  code         text not null unique,   -- mã chuẩn đã sinh
  created_at   timestamptz default now(),
  primary key (object_type, scope_id, natural_key)
);
create index if not exists ix_code_alias_code on code_alias(code);
grant select on code_alias to app_user;

-- Cùng khoá tự nhiên -> cùng mã. Khoá mới -> sinh mã kế tiếp.
create or replace function code_for(p_type text, p_scope text, p_key text)
returns text language plpgsql security definer as $$
declare c text;
begin
  if p_key is null or p_key = '' then
    raise exception 'ERR_EMPTY_KEY: code_for(%) thiếu khoá tự nhiên', p_type;
  end if;
  select code into c from code_alias
   where object_type = p_type and scope_id = coalesce(nullif(p_scope,''),'ITRAN') and natural_key = p_key;
  if c is not null then return c; end if;

  c := make_code(p_type, p_scope);
  insert into code_alias(object_type, scope_id, natural_key, code)
  values (p_type, coalesce(nullif(p_scope,''),'ITRAN'), p_key, c)
  on conflict (object_type, scope_id, natural_key) do update set code = code_alias.code
  returning code into c;
  return c;
end $$;
grant execute on function code_for(text,text,text) to app_user;

-- Tra ngược: có mã rồi muốn biết khoá tự nhiên nào sinh ra nó (tiện đối chiếu khi sửa seed).
create or replace view v_code_alias as
select a.object_type as loai, r.label as ten_loai, a.scope_id as pham_vi,
       a.natural_key as khoa_tu_nhien, a.code as ma_chuan
from code_alias a join code_registry r on r.object_type = a.object_type;
grant select on v_code_alias to app_user;

-- Sổ đăng ký không còn khái niệm "mã cũ" — dựng lại view sức khoẻ cho đúng.
drop view if exists v_code_health;
create or replace view v_code_health as
select r.object_type as loai_doi_tuong, r.label as ten, r.table_name as bang, r.scope as pham_vi,
       r.prefix as tien_to, r.width as do_rong, r.level as cap_do,
       (select count(*) from code_alias a where a.object_type = r.object_type) as so_ma_da_sinh
from code_registry r where r.active order by r.level, r.object_type;
grant select on v_code_health to app_user;
