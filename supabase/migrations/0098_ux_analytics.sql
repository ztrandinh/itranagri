-- 0098 · ĐO LƯỜNG TRẢI NGHIỆM (HEART) — không đo được thì mọi cải tiến UX là cảm tính.
-- Ghi sự kiện hành vi ẩn danh-theo-vai: bắt đầu/xong/bỏ dở tác vụ, thời gian, lỗi form.
-- KHÔNG lưu nội dung nghiệp vụ, chỉ lưu "ai (vai) làm gì, ở đâu, mất bao lâu, có lỗi không".

create table if not exists ux_events(
  id bigserial primary key,
  farm_id text,
  staff_id text,
  role text,
  dept text,
  kind text not null,              -- task_start | task_done | task_abandon | form_error | nav | search
  task text,                       -- tên tác vụ: ghi_3_cham, duyet_chi, nhap_kho…
  path text,                       -- trang
  ms int,                          -- thời gian hoàn tất (task_done)
  ok bool,                         -- thành công?
  detail jsonb default '{}'::jsonb,
  ts timestamptz default now()
);
create index if not exists ux_events_farm_ts on ux_events(farm_id, ts desc);
create index if not exists ux_events_task on ux_events(task, kind);
alter table ux_events enable row level security;
drop policy if exists ux_events_rw on ux_events;
create policy ux_events_rw on ux_events for all
  using (farm_id is null or farm_id = current_setting('app.farm_id', true))
  with check (farm_id is null or farm_id = current_setting('app.farm_id', true));
grant select, insert on ux_events to app_user;
grant usage, select on sequence ux_events_id_seq to app_user;

-- HEART: tỷ lệ hoàn tất & thời gian trung vị theo tác vụ và theo vai
create or replace view v_ux_task_success as
select
  farm_id, task, role,
  count(*) filter (where kind = 'task_start')   as bat_dau,
  count(*) filter (where kind = 'task_done')    as hoan_tat,
  count(*) filter (where kind = 'task_abandon') as bo_do,
  round(100.0 * count(*) filter (where kind = 'task_done')
        / nullif(count(*) filter (where kind = 'task_start'), 0), 1) as ty_le_thanh_cong_pct,
  round(percentile_cont(0.5) within group (order by ms) filter (where kind = 'task_done')) as thoi_gian_trung_vi_ms,
  count(*) filter (where kind = 'form_error')   as so_loi_form
from ux_events
where ts > now() - interval '30 days'
group by 1,2,3;

-- Màn hay bị bỏ dở nhất (chỗ người dùng vấp)
create or replace view v_ux_friction as
select farm_id, path, role,
       count(*) filter (where kind = 'task_abandon') as bo_do,
       count(*) filter (where kind = 'form_error')   as loi_form
from ux_events
where ts > now() - interval '30 days'
group by 1,2,3
having count(*) filter (where kind in ('task_abandon','form_error')) > 0;
