-- 0007 · TASK engine · PO · đề nghị chi · giao ca · giá tham chiếu · thẻ tai · quy đổi đơn vị · head_count tự cập nhật
-- ===== TASKS ("Việc hôm nay" theo vai) =====
create table if not exists tasks(
  id uuid primary key default gen_random_uuid(), farm_id text not null references farms,
  kind text not null,               -- KHAM_THAI|VACCINE|CAI_SUA|BAO_DUONG|KIEM_KE|RA_SOP|SO_HOA_GIAY|CACH_LY_RA|CHECKLIST|ALERT|GIAO_CA|KHAC
  title text not null, detail jsonb default '{}'::jsonb,
  target_type text, target_id text,  -- animal|group|device|warehouse|sop|paper|alert
  role_hint text, assignee_id text,   -- vai gợi ý (worker:A2…) / người cụ thể
  sop_code text, due_at timestamptz not null, priority text default 'BINH_THUONG' check (priority in ('THAP','BINH_THUONG','CAO','KHAN')),
  status text not null default 'MO' check (status in ('MO','DANG_LAM','XONG','BO_QUA','TREO')),
  source text default 'RULE', rule_code text, done_by text, done_at timestamptz, done_event_id uuid, handover_note text,
  created_at timestamptz default now(), unique(farm_id, rule_code, target_id, due_at));
create index if not exists tasks_farm_due_ix on tasks(farm_id, status, due_at);
alter table tasks enable row level security;
drop policy if exists p_sel on tasks; create policy p_sel on tasks for select using (can_see_farm(farm_id));
drop policy if exists p_ins on tasks; create policy p_ins on tasks for insert with check (farm_id=app_farm() and app_role() not in ('auditor','anon'));
drop policy if exists p_upd on tasks; create policy p_upd on tasks for update using (farm_id=app_farm() and app_role() not in ('auditor','anon'));
grant select, insert, update on tasks to app_user;

-- Sổ giao ca
create table if not exists shift_notes(
  id uuid primary key default gen_random_uuid(), farm_id text not null references farms, ts timestamptz default now(), created_by text,
  dept text, shift text, note text not null, target_type text, target_id text, ack_by text, ack_at timestamptz);
alter table shift_notes enable row level security;
drop policy if exists p_sel on shift_notes; create policy p_sel on shift_notes for select using (can_see_farm(farm_id));
drop policy if exists p_ins on shift_notes; create policy p_ins on shift_notes for insert with check (farm_id=app_farm() and app_role() not in ('auditor','anon'));
drop policy if exists p_upd on shift_notes; create policy p_upd on shift_notes for update using (farm_id=app_farm());
grant select, insert, update on shift_notes to app_user;

-- ===== PO & đề nghị chi =====
create table if not exists purchase_orders(
  id text primary key, farm_id text not null references farms, supplier_id text references partners, ts timestamptz default now(), created_by text,
  lines jsonb not null default '[]'::jsonb,   -- [{sku, qty, unit, price}]
  total numeric, po_status text default 'CHO_DUYET' check (po_status in ('CHO_DUYET','DUYET','TU_CHOI','DA_NHAN','HUY')),
  approved_by text, approved_at timestamptz, note text);
create table if not exists expense_requests(
  id text primary key, farm_id text not null references farms, ts timestamptz default now(), requested_by text,
  amount numeric not null, cost_center text, purpose text not null, po_id text, attachments text[] default '{}',
  status text default 'CHO_DUYET' check (status in ('CHO_DUYET','DUYET_1','DUYET','TU_CHOI','DA_CHI')),
  approver1 text, approved1_at timestamptz, approver2 text, approved2_at timestamptz, owner_notified_at timestamptz, paid_at timestamptz, paid_ref text);
do $$ declare t text; begin
  for t in select unnest(array['purchase_orders','expense_requests']) loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_sel on %I', t); execute format('create policy p_sel on %I for select using (can_see_farm(farm_id))', t);
    execute format('drop policy if exists p_ins on %I', t); execute format('create policy p_ins on %I for insert with check (farm_id=app_farm() and app_role() not in (''auditor'',''anon''))', t);
    execute format('drop policy if exists p_upd on %I', t); execute format('create policy p_upd on %I for update using (farm_id=app_farm() and app_role() in (''team_lead'',''tech_head'',''director'',''owner'',''accountant''))', t);
    execute format('grant select, insert, update on %I to app_user', t);
  end loop; end $$;

-- ===== Giá tham chiếu =====
create table if not exists price_list(
  id uuid primary key default gen_random_uuid(), org_id text references orgs, farm_id text, region_id text, sku text, kind text not null, -- THI_TRUONG|SAN|SO_DAN|CHUYEN_NOI_BO
  subject text, price numeric not null, unit text, valid_from date default current_date, valid_to date, source text, updated_by text);
alter table price_list enable row level security;
drop policy if exists p_all on price_list; create policy p_all on price_list for select using (true);
drop policy if exists p_w on price_list; create policy p_w on price_list for all using (app_role() in ('tech_head','director','owner','accountant')) with check (true);
grant select, insert, update on price_list to app_user;
insert into price_list(org_id,region_id,kind,subject,price,unit,source) values ('ITRAN','BAC-BAI-SONG','THI_TRUONG','BO_HOI',85000,'đ/kg','chợ đầu mối'),('ITRAN',null,'SAN','SKU-PTR-25',75000,'đ/bao','GĐ duyệt quý'),('ITRAN',null,'SAN','SKU-TRUNG-10',38000,'đ/vỉ','GĐ duyệt quý'),('ITRAN',null,'SAN','SKU-TMR-25',95000,'đ/bao','GĐ duyệt quý') on conflict do nothing;

-- ===== Thẻ tai: lịch sử RFID/số tai (bê chưa gắn tai, thay tai) =====
create table if not exists animal_tags(
  id uuid primary key default gen_random_uuid(), farm_id text not null references farms, animal_id text references animals, tag_type text not null check (tag_type in ('RFID','VISUAL','BOLUS','QR')),
  value text not null, from_ts timestamptz default now(), to_ts timestamptz, reason text, created_by text);
create index if not exists animal_tags_val_ix on animal_tags(value) where to_ts is null;
alter table animal_tags enable row level security;
drop policy if exists p_sel on animal_tags; create policy p_sel on animal_tags for select using (can_see_farm(farm_id));
drop policy if exists p_ins on animal_tags; create policy p_ins on animal_tags for insert with check (farm_id=app_farm() and app_role() not in ('auditor','anon'));
drop policy if exists p_upd on animal_tags; create policy p_upd on animal_tags for update using (farm_id=app_farm() and app_role() not in ('auditor','anon','worker'));
grant select, insert, update on animal_tags to app_user;
-- animals: cho phép chưa có tai nhưng phải có visual/QR (qr_token luôn có) → nới constraint, thêm cờ tag_pending
alter table animals drop constraint if exists animals_identity;
alter table animals add column if not exists tag_pending bool default false;
insert into animal_tags(farm_id,animal_id,tag_type,value) select farm_id,id,'RFID',rfid from animals where rfid is not null on conflict do nothing;
insert into animal_tags(farm_id,animal_id,tag_type,value) select farm_id,id,'VISUAL',visual_tag from animals where visual_tag is not null on conflict do nothing;

-- ===== Quy đổi đơn vị 2 =====
alter table products add column if not exists unit2_factor numeric; -- 1 unit = unit2_factor × unit2 (vỉ 10 = 10 quả)
update products set unit2_factor=10 where sku='SKU-TRUNG-10';
update products set unit2_factor=25 where sku in ('SKU-PTR-25','SKU-TMR-25');
update products set unit2_factor=100 where sku='TH-OXY';

-- ===== head_count đàn nhóm tự cập nhật từ sự kiện =====
create or replace function itran_group_count_after() returns trigger language plpgsql as $$
begin
  if new.group_id is null then return new; end if;
  if new.event_type in ('CHET','LOAI','XUAT') then update animal_groups set head_count = greatest(0, head_count - coalesce(new.value,0)::int) where id=new.group_id;
  elsif new.event_type in ('NHAP') then update animal_groups set head_count = head_count + coalesce(new.value,0)::int where id=new.group_id;
  elsif new.event_type='SO_LUONG' and coalesce(new.detail->>'metric','')='head_count' then update animal_groups set head_count = coalesce(new.value,0)::int where id=new.group_id;
  end if;
  return new;
end $$;
drop trigger if exists animal_events_grp on animal_events;
create trigger animal_events_grp after insert on animal_events for each row execute function itran_group_count_after();
-- animals đổi group → cập nhật membership + head_count nhóm cá thể
create or replace function itran_animal_group_change() returns trigger language plpgsql as $$
begin
  if new.group_id is distinct from old.group_id then
    update group_membership set to_ts=now() where animal_id=new.id and to_ts is null;
    if new.group_id is not null then insert into group_membership(animal_id,group_id) values (new.id,new.group_id); end if;
    update animal_groups g set head_count=(select count(*) from animals a where a.group_id=g.id and a.status not in ('CHET','XUAT')) where g.id in (old.group_id,new.group_id) and g.kind='BO_NHOM';
  end if;
  return new;
end $$;
drop trigger if exists animals_grp_change on animals;
create trigger animals_grp_change after update of group_id on animals for each row execute function itran_animal_group_change();
update animal_groups g set head_count=(select count(*) from animals a where a.group_id=g.id and a.status not in ('CHET','XUAT')) where g.kind='BO_NHOM';

-- ===== Ngày-tồn từng nguyên liệu mua (K2) =====
create or replace view v_days_of_stock as
select b.farm_id, b.sku, b.product_name, sum(b.qty) as qty,
  (select coalesce(sum(m.qty),0)/14.0 from inventory_moves m where m.farm_id=b.farm_id and m.sku=b.sku and m.status='ACTIVE' and m.direction=-1 and m.ts>=now()-interval '14 days') as use_per_day,
  case when (select coalesce(sum(m.qty),0) from inventory_moves m where m.farm_id=b.farm_id and m.sku=b.sku and m.status='ACTIVE' and m.direction=-1 and m.ts>=now()-interval '14 days')>0
       then round(sum(b.qty)/((select sum(m.qty) from inventory_moves m where m.farm_id=b.farm_id and m.sku=b.sku and m.status='ACTIVE' and m.direction=-1 and m.ts>=now()-interval '14 days')/14.0),1) end as days
from v_stock_balance b where b.warehouse_code in ('K2','K3','K4','K1','K7') group by b.farm_id, b.sku, b.product_name;
grant select on v_days_of_stock to app_user;

-- ===== TASK GENERATOR (gọi bởi job/UI): sinh việc từ trạng thái & lịch =====
create or replace function itran_generate_tasks(p_farm text) returns int language plpgsql as $$
declare n int := 0; r record; begin
  -- 1) Khám thai 60 ngày sau PHOI (chưa có KHAM_THAI sau đó)
  for r in select e.animal_id, e.ts from animal_events e where e.farm_id=p_farm and e.status='ACTIVE' and e.event_type='PHOI' and e.ts <= now()-interval '60 days' and e.ts >= now()-interval '120 days'
           and not exists (select 1 from animal_events k where k.animal_id=e.animal_id and k.event_type='KHAM_THAI' and k.ts>e.ts and k.status='ACTIVE') loop
    insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,sop_code,due_at,priority,rule_code) values (p_farm,'KHAM_THAI','Khám thai '||r.animal_id||' (60 ngày sau phối)','animal',r.animal_id,'worker:A2','SOP-BO-03.1',(r.ts+interval '60 days'),'CAO','T-KHAM-THAI') on conflict do nothing; n:=n+1;
  end loop;
  -- 2) Hết cách ly 21 ngày
  for r in select il.id, il.quarantine_until from intake_lots il where il.farm_id=p_farm and il.quarantine_until is not null and il.quarantine_until<=current_date+1
           and exists (select 1 from animals a where a.intake_lot_id=il.id and a.status='CACH_LY') loop
    insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,sop_code,due_at,priority,rule_code) values (p_farm,'CACH_LY_RA','Kết thúc cách ly lô '||r.id||' (khám + chuyển đàn)','intake_lot',r.id,'tech_head','SOP-BO-02.1',r.quarantine_until::timestamptz,'CAO','T-CACH-LY') on conflict do nothing; n:=n+1;
  end loop;
  -- 3) Bảo dưỡng máy theo giờ
  for r in select d.id, d.name, d.machine_hours, d.maint_cycle_h from devices d where d.farm_id=p_farm and d.maint_cycle_h is not null and d.machine_hours >= d.maint_cycle_h*0.9 loop
    insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,due_at,priority,rule_code) values (p_farm,'BAO_DUONG','Bảo dưỡng '||r.name||' ('||r.machine_hours||'/'||r.maint_cycle_h||' giờ)','device',r.id,'worker:A5',now()+interval '3 days','BINH_THUONG','T-BAO-DUONG') on conflict do nothing; n:=n+1;
  end loop;
  -- 4) Kiểm kê chu kỳ (tuần: K4–K8; tháng: K1–K3,K9) nếu chưa có stocktake trong kỳ
  for r in select w.id, w.code, w.count_cycle from warehouses w where w.farm_id=p_farm loop
    if not exists (select 1 from stocktakes s where s.farm_id=p_farm and s.warehouse_id=r.id and s.status='ACTIVE' and s.ts >= case when r.count_cycle='TUAN' then date_trunc('week',now()) else date_trunc('month',now()) end) then
      insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,sop_code,due_at,priority,rule_code) values (p_farm,'KIEM_KE','Kiểm kê '||r.code||' ('||lower(r.count_cycle)||', người ngoài bộ phận)','warehouse',r.id,'team_lead','SOP-KHO-01.1',
        case when r.count_cycle='TUAN' then date_trunc('week',now())+interval '5 days' else date_trunc('month',now())+interval '27 days' end,'BINH_THUONG','T-KIEM-KE') on conflict do nothing; n:=n+1;
    end if;
  end loop;
  -- 5) Số hóa phiếu giấy chưa số hóa
  for r in select p.id, p.serial from paper_scans p where p.farm_id=p_farm and p.status='ACTIVE' and not p.digitized loop
    insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,due_at,priority,rule_code) values (p_farm,'SO_HOA_GIAY','Nhập từ phiếu '||r.serial,'paper',r.id::text,'team_lead',now()+interval '24 hours','BINH_THUONG','T-SO-HOA') on conflict do nothing; n:=n+1;
  end loop;
  -- 6) Rà SOP đến hạn 30 ngày
  for r in select v.sop_code, v.review_due from sop_versions v where v.status='BAN_HANH' and v.review_due <= current_date+30 loop
    insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,due_at,priority,rule_code) values (p_farm,'RA_SOP','Rà SOP '||r.sop_code||' (hạn '||r.review_due||')','sop',r.sop_code,'tech_head',r.review_due::timestamptz,'THAP','T-RA-SOP') on conflict do nothing; n:=n+1;
  end loop;
  -- 7) Cảnh báo ĐỎ chưa ack → việc
  for r in select a.id, a.rule_code, a.subject from alerts a where a.farm_id=p_farm and a.acked_at is null and a.level='DO' loop
    insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,due_at,priority,rule_code) values (p_farm,'ALERT','Xử lý cảnh báo ĐỎ '||a_label(r.rule_code)||' '||coalesce(r.subject,''),'alert',r.id::text,'tech_head',now(),'KHAN','T-ALERT') on conflict do nothing; n:=n+1;
  end loop;
  -- 8) Việc cố định theo SOP hằng ngày cho vai (checklist ca) — sáng
  insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,sop_code,due_at,priority,rule_code) select p_farm,'CHECKLIST','Checklist ca sáng '||s.code||' — '||s.title,'sop',s.code,
     case s.dept when 'BO' then 'worker:A1' when 'GA' then 'worker:A3' when 'SH' then 'worker:A6' when 'KHO' then 'worker:A8' when 'AN' then 'worker:A11' else 'worker' end, s.code, date_trunc('day',now())+interval '6 hours','BINH_THUONG','T-CHECKLIST'
     from sops s where s.status='BAN_HANH' on conflict do nothing;
  return n;
end $$;
create or replace function a_label(t text) returns text language sql immutable as $$ select coalesce(t,'') $$;
grant execute on function itran_generate_tasks(text) to app_user;
