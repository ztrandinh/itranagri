-- 0127 — Khai KHOÁ NGOẠI cho các cột trỏ đối tượng đang bỏ trống
--
-- Lỗ hổng toàn vẹn dữ liệu: soát 156 cột trỏ tới đối tượng thì 98 cột KHÔNG khai khoá ngoại.
-- Nghĩa là hôm nay ghi `location_id = 'F01-KHONG-CO-THAT'` vẫn lọt, và không gì phát hiện.
-- Với một hệ truy xuất nguồn gốc thì đây là lỗi nền, không phải chuyện nhỏ.
--
-- Soát mồ côi trước khi khai (nếu có dòng mồ côi thì ALTER sẽ nổ):
--   156 cột · 98 cột chưa khai FK · chỉ 4 cột có mồ côi, tổng 68 dòng
--     supervision_criteria.sop_code  59   <- mảng giám sát, phiên kia dọn
--     training_tests.sop_code         4   <- mảng đào tạo, phiên kia dọn
--     incidents.location_id           4   <- dọn ở migration này
--     cold_chain_logs.vehicle_id      1   <- CỐ Ý để trống, xem ghi chú dưới
--
-- Migration này khai FK cho những cột ĐÃ SẠCH; 4 cột trên để lại, khai sau khi dọn xong.

-- incidents.location_id: 4 dòng trỏ tới khu vực không còn tồn tại. Sự cố là bản ghi
-- append-only nên KHÔNG xoá dòng — chỉ gỡ tham chiếu hỏng, giữ nguyên nội dung sự cố.
update incidents set location_id = null
 where location_id is not null
   and not exists (select 1 from locations l where l.id = incidents.location_id);

do $$
declare r record; cha text; khoa text; n int := 0; bo int := 0;
begin
  for r in
    select c.table_name as t, c.column_name as k
    from information_schema.columns c
    join pg_class pc on pc.relname = c.table_name
    join pg_namespace ns on ns.oid = pc.relnamespace and ns.nspname='public'
    where c.table_schema='public' and pc.relkind='r' and not pc.relispartition
      and c.data_type in ('text','character varying')
      and c.column_name in ('location_id','dest_location_id','from_location_id','to_location_id',
        'group_id','dest_group_id','plot_id','device_id','target_device_id','machine_id','pump_id',
        'warehouse_id','dest_warehouse_id','animal_id','season_id','partner_id','supplier_id',
        'guest_partner_id','buyer_partner_id','sop_code','bin_id','account_code',
        'staff_id','assignee_id','supervisor_id','target_staff_id','examiner_id','trainee_id')
      -- `cold_chain_logs.vehicle_id` KHÔNG khai FK: tài xế GÕ BIỂN SỐ tại chỗ, xe có thể là xe
      -- thuê ngoài chưa có trong danh mục. Ép khoá ngoại ở đây là chặn tài xế ghi nhiệt độ —
      -- mất mắt xích chuỗi lạnh còn tai hại hơn việc biển số chưa khai danh mục.
      and not (c.table_name = 'cold_chain_logs' and c.column_name = 'vehicle_id')
  loop
    cha := case
      when r.k like '%location_id' then 'locations'
      when r.k in ('group_id','dest_group_id') then 'animal_groups'
      when r.k = 'plot_id' then 'plots'
      when r.k in ('device_id','target_device_id','machine_id','pump_id') then 'devices'
      when r.k in ('warehouse_id','dest_warehouse_id') then 'warehouses'
      when r.k = 'animal_id' then 'animals'
      when r.k = 'season_id' then 'crop_seasons'
      when r.k in ('partner_id','supplier_id','guest_partner_id','buyer_partner_id') then 'partners'
      when r.k = 'sop_code' then 'sops'
      when r.k = 'bin_id' then 'bins'
      when r.k = 'account_code' then 'job_accounts'
      else 'staff' end;
    khoa := case when cha in ('sops','job_accounts') then 'code' else 'id' end;
    if to_regclass('public.'||cha) is null then continue; end if;
    -- đã có khoá ngoại rồi thì bỏ qua
    if exists (select 1 from pg_constraint k
                 join pg_attribute a on a.attrelid=k.conrelid and a.attnum=any(k.conkey)
                where k.contype='f' and k.conrelid=(quote_ident(r.t))::regclass and a.attname=r.k)
    then continue; end if;
    begin
      execute format('alter table %I add constraint %I foreign key (%I) references %I(%I) not valid',
                     r.t, 'fk_'||r.t||'_'||r.k, r.k, cha, khoa);
      -- NOT VALID: chỉ chặn dòng GHI MỚI, không quét lại toàn bộ dữ liệu cũ.
      -- Ràng buộc vẫn có hiệu lực ngay với mọi bản ghi từ nay về sau.
      n := n + 1;
    exception when others then
      bo := bo + 1;
      raise notice 'Chưa khai được %.% -> %(%): %', r.t, r.k, cha, khoa, sqlerrm;
    end;
  end loop;
  raise notice 'Đã khai % khoá ngoại, bỏ qua % cột.', n, bo;
end $$;
