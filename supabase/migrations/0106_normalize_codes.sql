-- 0106 — normalize_codes(): đổi TOÀN BỘ mã cũ sang chuẩn mới, không sót tham chiếu nào
--
-- Vì sao không sửa tay 200 mã cứng trong 19 file seed/migration:
--   1. Các bảng tham chiếu chéo nhau bằng chính chuỗi mã, sửa lệch một chỗ là gãy im lặng.
--   2. Quan trọng hơn: soát ra 157 CỘT TEXT trỏ tới đối tượng mà KHÔNG khai khoá ngoại
--      (animal_groups.location_id, feed_logs.dest_group_id, crop_seasons.plot_id…).
--      Nên mẹo "ON UPDATE CASCADE" sẽ âm thầm làm gãy 157 cột đó.
--   3. Và còn mã nằm TRONG jsonb (event_bus.payload, audit_log, notifications) —
--      khoá ngoại không bao giờ với tới.
--
-- Cách làm: mã là chuỗi DUY NHẤT TOÀN CỤC (F01-CH-NAI-1…), nên thay đúng chuỗi ở
-- mọi cột text và mọi cột jsonb của toàn CSDL là đủ và không thể sót.
-- Sản phẩm đang thử nghiệm nên đổi thẳng, KHÔNG giữ mã cũ, không chạy song song hai hệ.

-- Nhiều loại đối tượng dùng CHUNG một bảng (bò/dê/cừu đều nằm trong `animals`), nên cần
-- điều kiện lọc để biết dòng nào thuộc loại nào. Thiếu cột này thì bộ soát đếm 1.149 con
-- ba lần cho ba loài.
alter table code_registry add column if not exists filter_sql text;
update code_registry set filter_sql = 'species = ''BO'''  where object_type = 'bo'  and filter_sql is null;
update code_registry set filter_sql = 'species = ''DE'''  where object_type = 'de'  and filter_sql is null;
update code_registry set filter_sql = 'species = ''CUU''' where object_type = 'cuu' and filter_sql is null;

-- Ánh xạ mã cũ -> mã chuẩn.
create table if not exists code_rename (
  old_code text primary key,
  new_code text not null unique,
  object_type text not null,
  done_at timestamptz
);
grant select on code_rename to app_user;

-- Bước 1 — dựng ánh xạ: đọc khoá chính hiện có của từng bảng đã khai trong sổ đăng ký,
-- lấy phần đuôi làm khoá tự nhiên, sinh mã chuẩn qua code_for().
create or replace function build_code_rename() returns int language plpgsql security definer as $$
declare r record; q text; n int := 0; rec record; k text; sc text; pat text;
begin
  delete from code_rename where done_at is null;
  for r in
    select cr.object_type, cr.table_name, cr.scope, cr.prefix, cr.width, cr.filter_sql
    from code_registry cr
    where cr.active and cr.width > 0 and cr.table_name is not null
      and to_regclass('public.' || cr.table_name) is not null
  loop
    -- Bảng phải có cột id kiểu text mới đổi được
    if not exists (select 1 from information_schema.columns c
                    where c.table_schema='public' and c.table_name=r.table_name
                      and c.column_name='id' and c.data_type='text') then continue; end if;

    q := format('select id, %s as sc from %I where %s',
                case when r.scope = 'FARM' and exists (select 1 from information_schema.columns c
                        where c.table_schema='public' and c.table_name=r.table_name and c.column_name='farm_id')
                     then 'farm_id' else quote_literal('ITRAN') end,
                r.table_name, coalesce(r.filter_sql, 'true'));
    -- ÉP ĐÚNG ĐỘ RỘNG SỐ: nếu chỉ kiểm '[0-9]+' thì F01-TB-001 (3 số) lọt qua trong khi
    -- chuẩn là 5 số — đúng cái bệnh "mỗi nơi một độ rộng" đang phải chữa.
    pat := '^(F[0-9]+|ITRAN)-' || r.prefix || '-[0-9]{' || r.width || '}$';
    for rec in execute q loop
      if rec.id is null then continue; end if;
      -- CỐ Ý đổi mã CẢ những dòng đã đúng chuẩn. Nếu bỏ qua chúng thì bộ đếm vẫn bắt đầu từ 0
      -- và sẽ cấp lại đúng những số mà chúng đang giữ -> trùng khoá chính
      -- (đã dính thật: animals.id duplicate key, vì 124/629 con bò sẵn có mã 5 số).
      -- Đánh số lại toàn bộ thì dãy mã liền mạch và chắc chắn không đụng nhau.
      sc := coalesce(nullif(rec.sc,''), 'ITRAN');
      -- khoá tự nhiên = bỏ tiền tố phạm vi nếu có, giữ phần còn lại cho dễ đối chiếu
      k := regexp_replace(rec.id, '^(F[0-9]+|ITRAN)-', '');
      insert into code_rename(old_code, new_code, object_type)
      values (rec.id, code_for(r.object_type, sc, k), r.object_type)
      on conflict (old_code) do nothing;
      n := n + 1;
    end loop;
  end loop;
  return n;
end $$;

-- Đổi mã bên trong một chuỗi JSON. Chỉ duyệt đúng những mã CÓ MẶT trong chuỗi đó
-- (rút ra bằng regex rồi nối với bảng ánh xạ), thay vì quét cả 1.400 ánh xạ cho từng dòng.
create or replace function apply_code_map(s text) returns text language plpgsql immutable as $$
declare r record; out text := s;
begin
  -- HAI NHỊP: mã cũ và mã mới cùng một dạng nên mã mới của dòng này có thể trùng mã cũ của
  -- dòng kia; đổi một nhịp sẽ đổi chồng lên nhau. Nhịp 1 đẩy sang vùng đệm '#', nhịp 2 mới về mã thật.
  for r in
    select distinct m.old_code, m.new_code
    from regexp_matches(s, '"((?:F[0-9]+|ITRAN)-[^"]+)"', 'g') g(arr)
    join code_rename m on m.old_code = g.arr[1]
  loop
    out := replace(out, '"' || r.old_code || '"', '"#' || r.old_code || '"');
  end loop;
  for r in
    select distinct m.old_code, m.new_code
    from regexp_matches(out, '"#((?:F[0-9]+|ITRAN)-[^"]+)"', 'g') g(arr)
    join code_rename m on m.old_code = g.arr[1]
  loop
    out := replace(out, '"#' || r.old_code || '"', '"' || r.new_code || '"');
  end loop;
  return out;
end $$;

-- Bước 2 — áp ánh xạ vào MỌI cột text và MỌI cột jsonb của toàn CSDL.
-- Thay theo GIÁ TRỊ ĐÚNG BẰNG (cột text) và theo chuỗi JSON có ngoặc kép (cột jsonb),
-- nên không có chuyện 'F01-K1' ăn nhầm vào 'F01-K10'.
create or replace function apply_code_rename() returns int language plpgsql security definer as $$
declare c record; n int := 0; cnt int;
begin
  -- BẮT BUỘC: tắt kiểm khoá ngoại trong lúc đổi.
  -- Lần chạy đầu tôi không tắt: các cột được cập nhật theo thứ tự bất kỳ nên có bảng CON đổi
  -- trước bảng CHA, khoá ngoại chặn, lỗi bị nuốt mất, kết quả là 1.716 tham chiếu mồ côi
  -- (feed_logs.dest_group_id 1.569 · crop_seasons.plot_id 97 · harvests.plot_id 50).
  -- Tắt kiểm trong transaction thì thứ tự không còn quan trọng; đổi xong dữ liệu lại nhất quán.
  set constraints all deferred;
  perform set_config('session_replication_role', 'replica', true);

  -- 2a. cột text/varchar
  for c in
    select col.table_name as t, col.column_name as k
    from information_schema.columns col
    join pg_class pc on pc.relname = col.table_name
    join pg_namespace ns on ns.oid = pc.relnamespace and ns.nspname = 'public'
    where col.table_schema = 'public' and pc.relkind = 'r' and not pc.relispartition
      and col.data_type in ('text','character varying')
      and col.table_name not in ('code_rename','code_alias','code_registry','schema_migrations')
  loop
    -- NHỊP 1: đẩy mọi giá trị trùng mã cũ sang vùng đệm '#'.
    begin
      execute format('update %I t set %I = ''#'' || t.%I from code_rename m where t.%I = m.old_code', c.t, c.k, c.k, c.k);
    exception when others then
      -- KHÔNG nuốt lỗi im lặng nữa — im lặng chính là thứ đã tạo ra 1.716 tham chiếu mồ côi.
      raise notice 'BỎ QUA (nhịp 1) %.% : %', c.t, c.k, sqlerrm;
    end;
  end loop;

  -- NHỊP 2: từ vùng đệm về mã chuẩn. Tách hai nhịp vì mã cũ và mã mới CÙNG MỘT DẠNG,
  -- nên mã mới của dòng này có thể trùng mã cũ của dòng kia -> đổi một nhịp là trùng khoá chính
  -- (đã dính thật ở animals, staff, plots, warehouses, bins, crop_seasons, norms, animal_groups).
  for c in
    select col.table_name as t, col.column_name as k
    from information_schema.columns col
    join pg_class pc on pc.relname = col.table_name
    join pg_namespace ns on ns.oid = pc.relnamespace and ns.nspname = 'public'
    where col.table_schema = 'public' and pc.relkind = 'r' and not pc.relispartition
      and col.data_type in ('text','character varying')
      and col.table_name not in ('code_rename','code_alias','code_registry','schema_migrations')
  loop
    begin
      execute format('update %I t set %I = m.new_code from code_rename m where t.%I = ''#'' || m.old_code', c.t, c.k, c.k);
      get diagnostics cnt = row_count; n := n + cnt;
    exception when others then
      raise notice 'BỎ QUA (nhịp 2) %.% : %', c.t, c.k, sqlerrm;
    end;
  end loop;

  -- 2b. cột jsonb — mã nằm trong payload sự kiện, nhật ký kiểm toán, thông báo;
  -- khoá ngoại không bao giờ với tới những chỗ này.
  for c in
    select col.table_name as t, col.column_name as k
    from information_schema.columns col
    join pg_class pc on pc.relname = col.table_name
    join pg_namespace ns on ns.oid = pc.relnamespace and ns.nspname = 'public'
    where col.table_schema = 'public' and pc.relkind = 'r'
      and not pc.relispartition            -- bảng con của phân mảnh: sửa qua bảng cha
      and col.data_type in ('jsonb','json')
      and col.table_name not in ('code_rename','code_alias','code_registry')
  loop
    begin
      execute format(
        'update %I t set %I = apply_code_map(t.%I::text)::jsonb'
        || ' where t.%I::text ~ ''"(F[0-9]+|ITRAN)-[^"]+"''',
        c.t, c.k, c.k, c.k);
      get diagnostics cnt = row_count; n := n + cnt;
    exception when others then
      raise notice 'BỎ QUA jsonb %.% : %', c.t, c.k, sqlerrm;
    end;
  end loop;

  perform set_config('session_replication_role', 'origin', true);
  update code_rename set done_at = now() where done_at is null;
  return n;
end $$;

-- Gọi một phát: dựng ánh xạ rồi áp.
create or replace function normalize_codes() returns text language plpgsql security definer as $$
declare a int; b int;
begin
  a := build_code_rename();
  b := apply_code_rename();
  return format('Đổi %s mã, chạm %s ô dữ liệu', a, b);
end $$;

-- Bước 3 — soát tuân thủ: bảng nào còn mã lệch chuẩn.
create or replace function check_code_compliance()
returns table(bang text, loai text, tong bigint, dung_chuan bigint, con_lech bigint)
language plpgsql security definer as $$
declare r record; t bigint; ok bigint;
begin
  for r in select cr.object_type, cr.table_name, cr.scope, cr.prefix, cr.width, cr.filter_sql from code_registry cr
            where cr.active and cr.width > 0 and cr.table_name is not null
              and to_regclass('public.' || cr.table_name) is not null loop
    if not exists (select 1 from information_schema.columns c where c.table_schema='public'
                    and c.table_name=r.table_name and c.column_name='id' and c.data_type='text') then continue; end if;
    execute format('select count(*), count(*) filter (where id ~ %L) from %I where %s',
                   '^(F[0-9]+|ITRAN)-' || r.prefix || '-[0-9]{' || r.width || '}$',
                   r.table_name, coalesce(r.filter_sql, 'true')) into t, ok;
    if t = 0 then continue; end if;
    bang := r.table_name; loai := r.object_type; tong := t; dung_chuan := ok; con_lech := t - ok;
    return next;
  end loop;
end $$;
grant execute on function check_code_compliance() to app_user;
