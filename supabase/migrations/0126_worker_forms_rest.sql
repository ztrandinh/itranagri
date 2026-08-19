-- 0126 — Nốt các nghề còn lại chưa ghi được việc chính (mục 3.1 biên bản 21)
--
--   A18 Hành chính — CHẤM CÔNG: bảng `attendance` là bảng TỔNG HỢP (một dòng một ngày,
--       có check_in/check_out/hours/approved_by), không phải sổ ghi append-only nên không
--       nhét vào ghi-3-chạm được. Dựng sổ ghi riêng, `attendance` vẫn là bảng tổng hợp.
--   A11 KTV thiết bị — BẢO TRÌ / SỬA CHỮA: chưa có bảng nào.
--   A12 Lễ tân — ĐẶT PHÒNG / TOUR: `hosp_folio` đã có sẵn lược đồ, chỉ thiếu form.
--   A6  CN ủ chua — Ủ CHUA: `batch_logs` đã có sẵn, chỉ thiếu dây chuyền và form.

create table if not exists attendance_logs (
  id            uuid primary key default gen_random_uuid(),
  farm_id       text not null,
  ts            timestamptz not null default now(),
  created_at    timestamptz default now(),
  created_by    text default app_staff(),
  source        text default 'APP',
  is_backfill   boolean default false,
  paper_serial  text,
  client_ref    text not null,
  supersedes_id uuid references attendance_logs(id),
  device_id     text,
  staff_id      text not null,                 -- người được chấm
  kind          text not null,                 -- VAO_CA / RA_CA / NGHI_PHEP / NGHI_OM / DI_MUON / TANG_CA
  shift         text,
  minutes       numeric,                       -- số phút tăng ca / đi muộn
  reason        text,
  note          text,
  photo_urls    text[] default '{}'
);
create unique index if not exists ux_attendance_logs_ref on attendance_logs(farm_id, client_ref);
create index if not exists ix_attendance_logs_staff on attendance_logs(staff_id, ts desc);

create table if not exists maintenance_logs (
  id            uuid primary key default gen_random_uuid(),
  farm_id       text not null,
  ts            timestamptz not null default now(),
  created_at    timestamptz default now(),
  created_by    text default app_staff(),
  source        text default 'APP',
  is_backfill   boolean default false,
  paper_serial  text,
  client_ref    text not null,
  supersedes_id uuid references maintenance_logs(id),
  device_id     text,
  target_device_id text not null,              -- thiết bị được bảo trì
  kind          text not null,                 -- DINH_KY / SUA_CHUA / THAY_THE / KIEM_TRA
  symptom       text,
  action        text,
  parts         text,
  downtime_min  numeric,
  cost          numeric,
  result        text,                          -- XONG / CHO_PHU_TUNG / NGUNG_DUNG
  next_due      date,
  note          text,
  photo_urls    text[] default '{}'
);
create unique index if not exists ux_maintenance_logs_ref on maintenance_logs(farm_id, client_ref);
create index if not exists ix_maintenance_logs_dev on maintenance_logs(target_device_id, ts desc);

do $$ declare t text; begin
  foreach t in array array['attendance_logs','maintenance_logs'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_farm on %I', t);
    execute format($p$create policy p_farm on %I
        using (farm_id = any(string_to_array(current_setting('app.farm_ids', true), ',')))
        with check (farm_id = any(string_to_array(current_setting('app.farm_ids', true), ',')))$p$, t);
    execute format('grant select, insert on %I to app_user', t);
    execute format('revoke update, delete on %I from app_user', t);
    execute format('drop trigger if exists %s_noupd on %I', t, t);
    execute format('create trigger %s_noupd before update or delete on %I for each row execute function itran_no_update_delete()', t, t);
  end loop;
end $$;

-- Bổ sung form vào đúng nghề
update positions_catalog set forms = '{timekeep,incident,paper_submit}'                                    where code = 'A18';
update positions_catalog set forms = '{calibration,maintenance,checklist,stock_in,stock_out,incident,paper_submit}' where code = 'A11';
update positions_catalog set forms = '{booking,sale,incident,paper_submit}'                                where code = 'A12';
update positions_catalog set forms = forms || '{silage}'  where code = 'A6'  and not ('silage' = any(forms));
update positions_catalog set forms = forms || '{silage}'  where code = 'T04' and not ('silage' = any(forms));
update positions_catalog set forms = forms || '{maintenance}' where code in ('K06','K07') and not ('maintenance' = any(forms));
-- Trưởng phòng HCNS duyệt chấm công
update positions_catalog set forms = forms || '{timekeep}' where code = 'G06' and not ('timekeep' = any(forms));

insert into code_registry (object_type, label, table_name, scope, prefix, width, level, note) values
  ('cham_cong','Bản ghi chấm công','attendance_logs','FARM','CC',5,'CA_THE','Sổ ghi append-only; bảng `attendance` vẫn là bảng tổng hợp'),
  ('bao_tri','Bản ghi bảo trì / sửa chữa','maintenance_logs','FARM','BT',5,'CA_THE',null)
on conflict (object_type) do nothing;
