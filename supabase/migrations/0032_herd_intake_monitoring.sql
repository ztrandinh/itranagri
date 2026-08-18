-- 0032 · NHẬP LÔ ĐÀN (nhiều con/lần) + VÒNG THÔNG SỐ THEO DÕI từng con (monitoring params theo loài/lớp → lịch đến hạn → việc)
create table if not exists monitoring_params(id serial primary key, species_code text not null, class_code text, -- null = mọi lớp
  code text not null, name text not null, event_type text not null, -- sự kiện phải ghi (CAN, BCS, VACCINE, KHAM_THAI, TAY_KY_SINH, VAT_SUA…)
  every_days int, -- chu kỳ lặp; null = 1 lần theo tuổi
  age_days_min int, age_days_max int, after_event text, after_days int, -- ví dụ KHAM_THAI sau PHOI 35 ngày
  target_min numeric, target_max numeric, unit text, level text default 'MAJOR', role_hint text default 'worker', sop_code text, active bool default true, position int default 0);
create unique index if not exists monitoring_params_ux on monitoring_params(species_code, coalesce(class_code,''), code);
alter table monitoring_params enable row level security; drop policy if exists p_all on monitoring_params; create policy p_all on monitoring_params for all using (true) with check (app_role() in ('owner','director','it_engineer','tech_head')); grant select, insert, update on monitoring_params to app_user; grant usage, select on all sequences in schema public to app_user;
drop trigger if exists audit_monitoring_params on monitoring_params; create trigger audit_monitoring_params after insert or update or delete on monitoring_params for each row execute function itran_audit();
insert into monitoring_params(species_code,class_code,code,name,event_type,every_days,age_days_min,age_days_max,after_event,after_days,target_min,target_max,unit,level,role_hint,position) values
('BO',null,'CAN30','Cân định kỳ 30 ngày','CAN',30,null,null,null,null,null,null,'kg','MAJOR','worker',1),
('BO',null,'BCS30','Điểm thể trạng BCS hằng tháng','BCS',30,null,null,null,null,2.5,3.5,'điểm','MINOR','worker',2),
('BO','BO-BE','CAN-SS','Cân sơ sinh & 7 ngày','CAN',null,0,7,null,null,20,35,'kg','MAJOR','worker',3),
('BO','BO-BE','CAI-SUA','Cai sữa 90–180 ngày','CAI_SUA',null,90,180,null,null,null,null,null,'MAJOR','worker',4),
('BO',null,'TAY-KST','Tẩy ký sinh trùng 6 tháng','TAY_KY_SINH',180,60,null,null,null,null,null,null,'MAJOR','worker',5),
('BO',null,'VX-LMLM','Vaccine LMLM (lặp 6 tháng)','VACCINE',180,120,null,null,null,null,null,null,'CRITICAL','tech_head',6),
('BO',null,'VX-THT','Vaccine tụ huyết trùng (lặp 6 tháng)','VACCINE',180,120,null,null,null,null,null,null,'CRITICAL','tech_head',7),
('BO','BO-CAI-SS','KHAM-THAI','Khám thai 35 ngày sau phối','KHAM_THAI',null,null,null,'PHOI',35,null,null,null,'MAJOR','tech_head',8),
('BO','BO-CAI-SS','DONG-DUC','Theo dõi động dục 21 ngày sau đẻ/phối hụt','DONG_DUC',21,null,null,'DE',45,null,null,null,'MAJOR','worker',9),
('BO','BO-CAI-SS','DE-DU-KIEN','Đẻ dự kiến 283 ngày sau phối (+)','DE',null,null,null,'PHOI',283,null,null,null,'CRITICAL','worker',10),
('BO','BO-VO-BEO','ADG','Tăng trọng ≥0,8 kg/ngày (đánh giá mỗi lần cân)','CAN',30,null,null,null,null,0.8,null,'kg/ngày','MAJOR','tech_head',11),
('DE',null,'CAN30','Cân định kỳ 30 ngày','CAN',30,null,null,null,null,null,null,'kg','MAJOR','worker',1),
('DE',null,'TAY-KST','Tẩy ký sinh trùng 4 tháng','TAY_KY_SINH',120,45,null,null,null,null,null,null,'MAJOR','worker',2),
('DE','DE-CAI-SS','KHAM-THAI','Khám thai 30 ngày sau phối','KHAM_THAI',null,null,null,'PHOI',30,null,null,null,'MAJOR','tech_head',3),
('DE','DE-CAI-SS','DE-DU-KIEN','Đẻ dự kiến 150 ngày sau phối','DE',null,null,null,'PHOI',150,null,null,null,'CRITICAL','worker',4)
on conflict (species_code, coalesce(class_code,''), code) do nothing;
-- View: đến hạn theo dõi cho từng cá thể (BO/DE): lần cuối, hạn kế, quá hạn?
create or replace view v_animal_monitoring as
with a as (select * from animals where status not in ('CHET','XUAT','LOAI') and species in (select code from species where identify_level='CA_THE')),
p as (select * from monitoring_params where active),
last_ev as (select animal_id, event_type, max(ts) as last_ts, max(detail->>'result') as last_result from animal_events where status='ACTIVE' group by 1,2)
select a.farm_id, a.id as animal_id, a.species, a.class_code, p.code as param_code, p.name as param_name, p.event_type, p.level, p.role_hint,
  le.last_ts,
  case
    when p.after_event is not null then (select max(ts)::date + p.after_days from animal_events e where e.animal_id=a.id and e.status='ACTIVE' and e.event_type=p.after_event)
    when p.every_days is not null then coalesce(le.last_ts::date, greatest(coalesce(a.birth_date, a.created_at::date) + coalesce(p.age_days_min,0), a.created_at::date)) + case when le.last_ts is null then 0 else p.every_days end
    else coalesce(a.birth_date, a.created_at::date) + coalesce(p.age_days_min,0) end as due_date,
  p.target_min, p.target_max, p.unit
from a join p on p.species_code=a.species and (p.class_code is null or p.class_code=a.class_code)
left join last_ev le on le.animal_id=a.id and le.event_type=p.event_type
where (p.age_days_max is null or coalesce(a.birth_date, a.created_at::date) + p.age_days_max >= current_date or le.last_ts is null)
  and not (p.after_event is not null and not exists (select 1 from animal_events e where e.animal_id=a.id and e.status='ACTIVE' and e.event_type=p.after_event));
grant select on v_animal_monitoring to app_user;
-- Tổng hợp cần chú ý: đến hạn/quá hạn theo trại
create or replace view v_monitoring_due as select * from v_animal_monitoring where due_date <= current_date + 7 order by due_date, level;
grant select on v_monitoring_due to app_user;
-- Sinh việc từ vòng theo dõi (gọi trong itran_generate_tasks_v2 hoặc job tasks): 1 việc/param/con quá hạn, không trùng
create or replace function gen_monitoring_tasks(p_farm text) returns int language plpgsql as $$
declare n int := 0; r record; begin
  for r in select * from v_animal_monitoring where farm_id=p_farm and due_date <= current_date + 3 loop
    if not exists (select 1 from tasks t where t.farm_id=p_farm and t.kind='THEO_DOI' and t.target_id=r.animal_id and t.detail->>'param'=r.param_code and t.status in ('MO','DANG_LAM')) then
      insert into tasks(farm_id,kind,title,detail,target_type,target_id,role_hint,priority,due_at,source) values (p_farm,'THEO_DOI',r.param_name||' — '||r.animal_id, jsonb_build_object('param',r.param_code,'event_type',r.event_type,'target_min',r.target_min,'target_max',r.target_max,'unit',r.unit,'last',r.last_ts), 'animal', r.animal_id, r.role_hint, case when r.level='CRITICAL' then 'CAO' when r.due_date < current_date then 'CAO' else 'BINH_THUONG' end, r.due_date::timestamptz + interval '17 hours', 'MONITOR'); n := n + 1;
    end if;
  end loop; return n; end $$;
grant execute on function gen_monitoring_tasks(text) to app_user;
-- Nhập lô đàn: hàm tạo lô + N cá thể (mã tự sinh, RFID/thẻ tùy chọn), sự kiện NHAP + CACH_LY_VAO, cập nhật head_count lô
create or replace function intake_herd(p_farm text, p_by text, p_lot jsonb, p_animals jsonb) returns jsonb language plpgsql as $$
declare lot_id text; a jsonb; code text; ids text[] := '{}'; sp text; begin
  lot_id := coalesce(p_lot->>'id', next_code(p_farm, 'LN', 4));
  insert into intake_lots(id,farm_id,kind,date,source_partner_id,quarantine_until,vet_cert_no,price,head_count,note) values (lot_id,p_farm,coalesce(p_lot->>'kind','MUA'),coalesce((p_lot->>'date')::date,current_date),nullif(p_lot->>'source_partner_id',''),coalesce((p_lot->>'quarantine_until')::date,current_date+21),p_lot->>'vet_cert_no',(p_lot->>'price')::numeric,jsonb_array_length(p_animals),p_lot->>'note') on conflict (id) do update set head_count=intake_lots.head_count+jsonb_array_length(p_animals);
  for a in select * from jsonb_array_elements(p_animals) loop
    sp := coalesce(a->>'species', p_lot->>'species', 'BO'); code := coalesce(nullif(a->>'id',''), next_code(p_farm, sp, 5));
    insert into animals(id,farm_id,species,breed,sex,birth_date,rfid,visual_tag,source,intake_lot_id,group_id,status,location_id,tag_pending,last_weight_kg,last_weight_at,unit_value,class_code,attrs)
    values (code,p_farm,sp,coalesce(a->>'breed',p_lot->>'breed'),a->>'sex',(a->>'birth_date')::date,nullif(a->>'rfid',''),nullif(a->>'visual_tag',''),'MUA',lot_id,nullif(coalesce(a->>'group_id',p_lot->>'group_id'),''),'CACH_LY',nullif(coalesce(a->>'location_id',p_lot->>'location_id'),''),(nullif(a->>'rfid','') is null and nullif(a->>'visual_tag','') is null),(a->>'weight_kg')::numeric,case when a->>'weight_kg' is not null then now() end,coalesce((a->>'unit_value')::numeric,(p_lot->>'price')::numeric),a->>'class_code',coalesce(a->'attrs','{}'::jsonb));
    if nullif(a->>'rfid','') is not null then insert into animal_tags(farm_id,animal_id,tag_type,value,created_by) values (p_farm,code,'RFID',a->>'rfid',p_by); end if;
    if nullif(a->>'visual_tag','') is not null then insert into animal_tags(farm_id,animal_id,tag_type,value,created_by) values (p_farm,code,'VISUAL',a->>'visual_tag',p_by); end if;
    insert into animal_events(farm_id,created_by,animal_id,event_type,value,unit,detail,client_ref) values (p_farm,p_by,code,'NHAP',(a->>'weight_kg')::numeric,'kg',jsonb_build_object('lot',lot_id,'source',p_lot->>'source_partner_id'),'intake-'||code);
    insert into animal_events(farm_id,created_by,animal_id,event_type,detail,client_ref) values (p_farm,p_by,code,'CACH_LY_VAO',jsonb_build_object('until',coalesce((p_lot->>'quarantine_until')::date,current_date+21)),'quar-'||code);
    ids := ids || code;
  end loop;
  perform publish_event(p_farm,'animal.intake',jsonb_build_object('table','intake_lots','id',lot_id,'n',array_length(ids,1),'by',p_by));
  return jsonb_build_object('lot_id',lot_id,'animals',to_jsonb(ids)); end $$;
grant execute on function intake_herd(text,text,jsonb,jsonb) to app_user;
-- gắn class cho animals còn thiếu (bò) và job tasks gọi monitoring
update animals a set class_code = case when species='BO' and age(coalesce(birth_date, current_date-600)) < interval '6 months' then 'BO-BE' when species='BO' and age(coalesce(birth_date, current_date-600)) < interval '18 months' then 'BO-TO' when species='BO' and sex='F' then 'BO-CAI-SS' when species='BO' and sex='M' then 'BO-VO-BEO' else class_code end where class_code is null and species='BO';
