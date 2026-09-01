-- 0196 · Seed GLOBAL cho các ngưỡng alert engine (jobs.ts runAlerts()) vừa chuyển từ hard-code sang
-- data-driven qua `settings` (luật 7 "cấu hình = dữ liệu") — đúng giá trị mặc định cũ, không đổi hành vi.
-- `paper.digitize_hours` đã có sẵn từ 0005_seed.sql, không seed lại ở đây.
insert into settings(farm_id,key,value,updated_by) values
 ('GLOBAL','deaths.poultry_red_per_day','5','SYSTEM'),
 ('GLOBAL','ras.do_min_mgl','4','SYSTEM'),
 ('GLOBAL','coldchain.temp_max_c','8','SYSTEM'),
 ('GLOBAL','coldchain.window_min','30','SYSTEM'),
 ('GLOBAL','sensor.offline_min','60','SYSTEM'),
 ('GLOBAL','debt.max_days','30','SYSTEM'),
 ('GLOBAL','feed.miss_offset_min','60','SYSTEM'),
 ('GLOBAL','feed.miss_grace_hours','2','SYSTEM')
 on conflict do nothing;
