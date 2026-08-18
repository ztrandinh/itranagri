-- 0087 · Bàn giao khi nghỉ (người thay thế) + Hộp việc thống nhất "Hôm nay của tôi"
-- 1) leave_requests: người thay thế + nội dung bàn giao
alter table leave_requests add column if not exists delegate_id text, add column if not exists handover_note text, add column if not exists manager_id text;
-- 2) Ủy quyền/thay thế (đang nghỉ, đi công tác, hoặc thủ công)
create table if not exists staff_delegations(
  id uuid primary key default gen_random_uuid(), farm_id text not null, from_staff text not null, to_staff text not null,
  from_date date not null, to_date date not null, reason text, source text default 'LEAVE', leave_id uuid, status text default 'ACTIVE',
  tasks_moved int default 0, note text, created_by text, created_at timestamptz default now(), ended_at timestamptz,
  check (from_staff <> to_staff), check (status in ('ACTIVE','ENDED','CANCELLED'))
);
create index if not exists ix_deleg_active on staff_delegations(farm_id, to_staff) where status='ACTIVE';
create index if not exists ix_deleg_from on staff_delegations(farm_id, from_staff) where status='ACTIVE';
alter table staff_delegations enable row level security; drop policy if exists p_all on staff_delegations; create policy p_all on staff_delegations for all using (can_see_farm(farm_id)) with check (true);
grant select, insert, update on staff_delegations to app_user;
-- Ai đang thay tôi / tôi đang thay ai (hôm nay)
create or replace function effective_assignee(p_farm text, p_staff text, p_day date default current_date) returns text language sql stable as $$
  select coalesce((select to_staff from staff_delegations where farm_id=p_farm and from_staff=p_staff and status='ACTIVE' and p_day between from_date and to_date order by created_at desc limit 1), p_staff)
$$;
-- Gợi ý người thay: cùng phòng, cùng vị trí ưu tiên, đang làm việc, không nghỉ trùng kỳ, chưa nhận thay ai khác trong kỳ
create or replace function suggest_delegates(p_farm text, p_staff text, p_from date, p_to date) returns table(staff_id text, full_name text, position_name text, dept text, same_position boolean, load int) language sql stable as $$
  with me as (select dept, position_code, role from staff where id=p_staff)
  select s.id, s.full_name, s.position, s.dept, (s.position_code = me.position_code) as same_position,
    (select count(*)::int from tasks t where t.farm_id=p_farm and t.assignee_id=s.id and t.status in ('MO','DANG_LAM')) as load
  from staff s, me
  where s.farm_id=p_farm and s.active and s.id<>p_staff and s.left_on is null and (s.dept = me.dept or s.role = me.role)
    and not exists (select 1 from leave_requests l where l.staff_id=s.id and l.status in ('CHO','DUYET') and l.from_date<=p_to and l.to_date>=p_from)
    and not exists (select 1 from staff_delegations d where d.to_staff=s.id and d.status='ACTIVE' and d.from_date<=p_to and d.to_date>=p_from)
  order by same_position desc, load asc, s.full_name limit 8
$$;
-- Kích hoạt bàn giao: tạo ủy quyền, chuyển việc mở trong kỳ nghỉ sang người thay, tạo việc BAN_GIAO cho người nghỉ, báo cả hai + quản lý
create or replace function activate_delegation(p_farm text, p_from text, p_to text, p_from_date date, p_to_date date, p_reason text, p_source text default 'LEAVE', p_leave_id uuid default null, p_by text default null) returns uuid language plpgsql as $$
declare d uuid; n int; fname text; tname text;
begin
  select full_name into fname from staff where id=p_from; select full_name into tname from staff where id=p_to;
  insert into staff_delegations(farm_id,from_staff,to_staff,from_date,to_date,reason,source,leave_id,created_by) values (p_farm,p_from,p_to,p_from_date,p_to_date,p_reason,p_source,p_leave_id,p_by) returning id into d;
  -- chuyển việc đang mở đến hạn trong kỳ (giữ dấu vết người gốc)
  update tasks set assignee_id=p_to, detail=coalesce(detail,'{}'::jsonb) || jsonb_build_object('delegated_from',p_from,'delegation_id',d)
   where farm_id=p_farm and assignee_id=p_from and status in ('MO','DANG_LAM','TREO') and coalesce(due_at::date, p_from_date) <= p_to_date;
  get diagnostics n = row_count; update staff_delegations set tasks_moved=n where id=d;
  -- việc bàn giao cho người nghỉ (trước ngày nghỉ): ghi sổ tay, việc dở dang, chìa khóa/thiết bị, báo cáo dở
  insert into tasks(farm_id,kind,title,detail,target_type,target_id,assignee_id,due_at,priority,source,ref_table,ref_id)
   values (p_farm,'BAN_GIAO','Bàn giao công việc cho '||coalesce(tname,p_to)||' trước khi nghỉ ('||to_char(p_from_date,'DD/MM')||'–'||to_char(p_to_date,'DD/MM')||')',
     jsonb_build_object('checklist', jsonb_build_array('Việc dở dang & hạn','Sổ ghi/biểu mẫu giấy đang dùng','Chìa khóa, thiết bị, công cụ','Báo cáo phải nộp trong kỳ','Số điện thoại liên hệ khẩn'),'to',p_to,'tasks_moved',n),
     'staff',p_from,p_from,(p_from_date - 1)::timestamptz + interval '17 hours','CAO','DELEGATION','staff_delegations',d::text);
  insert into notifications(farm_id,staff_id,level,title,body,link,source,source_id) values
   (p_farm,p_to,'INFO','Bạn thay '||coalesce(fname,p_from)||' từ '||to_char(p_from_date,'DD/MM')||' đến '||to_char(p_to_date,'DD/MM'),'Đã chuyển '||n||' việc sang bạn. Ghi chép & báo cáo của vị trí này do bạn thực hiện trong kỳ.','/ca','delegation',d::text),
   (p_farm,p_from,'INFO','Đã cử '||coalesce(tname,p_to)||' thay bạn khi nghỉ','Hãy hoàn thành việc "Bàn giao" trước ngày nghỉ.','/ca','delegation',d::text);
  insert into notifications(farm_id,staff_id,level,title,body,link,source,source_id)
   select p_farm, s.manager_id, 'INFO', coalesce(fname,p_from)||' nghỉ '||to_char(p_from_date,'DD/MM')||'–'||to_char(p_to_date,'DD/MM')||', người thay: '||coalesce(tname,p_to), 'Chuyển '||n||' việc.', '/nhan-su?tab=cc','delegation',d::text from staff s where s.id=p_from and s.manager_id is not null and s.manager_id<>p_to;
  perform publish_event(p_farm,'staff.delegated',jsonb_build_object('delegation_id',d,'from',p_from,'to',p_to,'from_date',p_from_date,'to_date',p_to_date,'tasks_moved',n));
  return d;
end $$;
-- Kết thúc ủy quyền (job ngày): trả việc còn mở về người gốc
create or replace function end_delegations(p_farm text) returns int language plpgsql as $$
declare n int := 0; r record;
begin
  for r in select * from staff_delegations where farm_id=p_farm and status='ACTIVE' and to_date < current_date loop
    update tasks set assignee_id=r.from_staff, detail=detail - 'delegated_from' || jsonb_build_object('returned_from',r.to_staff)
     where farm_id=p_farm and assignee_id=r.to_staff and status in ('MO','DANG_LAM','TREO') and detail->>'delegation_id'=r.id::text;
    update staff_delegations set status='ENDED', ended_at=now() where id=r.id; n := n+1;
    insert into notifications(farm_id,staff_id,level,title,body,link,source,source_id) values (p_farm,r.from_staff,'INFO','Bạn đã trở lại — việc còn mở đã trả về bạn','Xem "Hôm nay của tôi".','/ca','delegation',r.id::text);
  end loop; return n;
end $$;
-- Duyệt nghỉ có người thay → tự kích hoạt
create or replace function trg_leave_delegate() returns trigger language plpgsql as $$
begin
  if new.status='DUYET' and (old.status is distinct from 'DUYET') and new.delegate_id is not null and new.delegate_id<>new.staff_id then
    perform activate_delegation(new.farm_id,new.staff_id,new.delegate_id,new.from_date,new.to_date,'Nghỉ '||new.kind||coalesce(': '||new.reason,''),'LEAVE',new.id,new.approved_by);
  end if; return new;
end $$;
drop trigger if exists leave_delegate on leave_requests; create trigger leave_delegate after update on leave_requests for each row execute function trg_leave_delegate();
-- Đơn nghỉ mới → gửi quản lý trực tiếp
create or replace function trg_leave_notify() returns trigger language plpgsql as $$
declare m text; nm text; begin
  select manager_id, full_name into m, nm from staff where id=new.staff_id; new.manager_id := coalesce(new.manager_id, m);
  if m is not null then insert into notifications(farm_id,staff_id,level,title,body,link,source,source_id) values (new.farm_id,m,'INFO',coalesce(nm,new.staff_id)||' xin nghỉ '||new.kind||' '||to_char(new.from_date,'DD/MM')||'–'||to_char(new.to_date,'DD/MM'),coalesce('Người thay: '||new.delegate_id,'CHƯA có người thay')||coalesce(' · '||new.reason,''),'/phe-duyet','leave',new.id::text); end if;
  return new; end $$;
drop trigger if exists leave_notify on leave_requests; create trigger leave_notify before insert on leave_requests for each row execute function trg_leave_notify();

-- 3) HỘP VIỆC THỐNG NHẤT — mọi thứ một người phải xử lý hôm nay, từ mọi nguồn, 1 hàm
create or replace function my_inbox(p_farm text, p_staff text, p_role text) returns table(kind text, title text, detail text, due_at timestamptz, priority text, link text, ref_table text, ref_id text, on_behalf text) language sql stable as $$
  with me as (select id, dept, position_code, manager_id from staff where id=p_staff),
  u as (
  select 'VIEC', t.title, coalesce(t.detail->>'note', t.kind), t.due_at, t.priority, case when t.target_type='animal' then '/xem/animal/'||t.target_id else '/ca' end, 'tasks', t.id::text, (select full_name from staff where id=t.detail->>'delegated_from')
   from tasks t where t.farm_id=p_farm and t.status in ('MO','DANG_LAM','TREO') and t.due_at <= now() + interval '2 days'
    and (t.assignee_id=p_staff or (t.assignee_id is null and t.role_hint=p_role and t.due_at >= now() - interval '7 days' and coalesce(t.source,'') not in ('MONITOR','HERD')))
  union all -- việc theo dõi/việc đàn hàng loạt theo vai: gom theo loại việc (không liệt kê từng con)
  select 'VIEC', split_part(t.title,' — ',1)||' — '||count(*)||' con', 'gom '||count(*)||' việc · sớm nhất '||to_char(min(t.due_at),'DD/MM'), min(t.due_at), max(t.priority), '/ca', 'tasks', 'group:'||split_part(t.title,' — ',1), null
   from tasks t where t.farm_id=p_farm and t.status in ('MO','DANG_LAM','TREO') and t.due_at <= now() + interval '2 days' and t.due_at >= now() - interval '7 days'
    and t.assignee_id is null and t.role_hint=p_role and coalesce(t.source,'') in ('MONITOR','HERD') group by split_part(t.title,' — ',1)
  union all -- phê duyệt chờ tôi
  select 'DUYET', 'Nghỉ phép: '||s.full_name||' '||to_char(l.from_date,'DD/MM')||'–'||to_char(l.to_date,'DD/MM'), coalesce(l.reason,''), l.from_date::timestamptz, 'CAO', '/phe-duyet', 'leave_requests', l.id::text, null
   from leave_requests l join staff s on s.id=l.staff_id, me where l.farm_id=p_farm and l.status='CHO' and (l.manager_id=p_staff or (l.manager_id is null and p_role in ('owner','director','team_lead','tech_head')))
  union all
  select 'DUYET', 'Đề nghị chi '||coalesce(e.purpose,'')||' '||to_char(e.amount,'FM999G999G999')||'đ', coalesce(e.requested_by,''), e.ts, 'CAO', '/phe-duyet', 'expense_requests', e.id::text, null
   from expense_requests e where e.farm_id=p_farm and e.status in ('CHO_DUYET','DUYET_1') and p_role in ('owner','director','accountant')
  union all
  select 'DUYET', 'PO chờ duyệt '||coalesce(p.supplier_id,''), coalesce(p.note,''), p.ts, 'BINH_THUONG', '/phe-duyet', 'purchase_orders', p.id::text, null
   from purchase_orders p where p.farm_id=p_farm and p.po_status='CHO_DUYET' and p_role in ('owner','director','accountant')
  union all -- thông báo chưa đọc
  select 'TIN', n.title, coalesce(n.body,''), n.ts, case n.level when 'DO' then 'KHAN' when 'CAM' then 'CAO' else 'BINH_THUONG' end, coalesce(n.link,'/thong-bao'), 'notifications', n.id::text, null
   from notifications n where n.farm_id=p_farm and n.staff_id=p_staff and n.read_at is null and n.ts > now() - interval '14 days'
  union all -- đào tạo tuần này (học hoặc dạy)
  select case when t.trainer_id=p_staff then 'DAO_TAO_DAY' else 'DAO_TAO_HOC' end, coalesce(t.topic_title,t.topic_code), 'Tuần '||to_char(t.week_start,'DD/MM')||' · '||coalesce(t.method,''), t.week_start::timestamptz + interval '4 days', 'BINH_THUONG', '/nhan-su?tab=dt', 'training_sessions', t.id::text, null
   from training_sessions t where t.farm_id=p_farm and t.status not in ('XONG','BO_LO') and (t.trainer_id=p_staff or t.trainee_id=p_staff) and t.week_start >= date_trunc('week', current_date)::date - 7
  union all -- giám sát tuần này còn thiếu lượt
  select 'GIAM_SAT', 'Kiểm tra '||coalesce(a.target_dept, s.full_name)||' — còn '||greatest(coalesce(a.checks_per_week,3) - coalesce(c.n,0),0)||' lượt tuần này', coalesce(a.scope,''), date_trunc('week', current_date)::timestamptz + interval '4 days', 'BINH_THUONG', '/giam-sat', 'supervision_assignments', a.id::text, null
   from supervision_assignments a left join staff s on s.id=a.target_staff_id
   left join lateral (select count(*)::int n from supervision_checks c where c.supervisor_id=a.supervisor_id and coalesce(c.target_staff_id,'')=coalesce(a.target_staff_id,'') and coalesce(c.target_dept,'')=coalesce(a.target_dept,'') and c.week_start=date_trunc('week', current_date)::date) c on true
   where a.farm_id=p_farm and a.active and a.supervisor_id=p_staff and coalesce(a.checks_per_week,3) > coalesce(c.n,0)
  union all -- tôi đang thay ai / ai đang thay tôi
  select 'THAY', 'Bạn đang thay '||s.full_name||' đến '||to_char(d.to_date,'DD/MM'), 'Ghi chép & báo cáo của vị trí này do bạn làm', d.to_date::timestamptz, 'BINH_THUONG', '/ca', 'staff_delegations', d.id::text, s.full_name
   from staff_delegations d join staff s on s.id=d.from_staff where d.farm_id=p_farm and d.to_staff=p_staff and d.status='ACTIVE' and current_date between d.from_date and d.to_date
  union all
  select 'THAY', s.full_name||' đang thay bạn đến '||to_char(d.to_date,'DD/MM'), '', d.to_date::timestamptz, 'THAP', '/ca', 'staff_delegations', d.id::text, null
   from staff_delegations d join staff s on s.id=d.to_staff where d.farm_id=p_farm and d.from_staff=p_staff and d.status='ACTIVE' and current_date between d.from_date and d.to_date
  ) select * from u order by case priority when 'KHAN' then 0 when 'CAO' then 1 when 'BINH_THUONG' then 2 else 3 end, due_at nulls last
$$;
grant execute on function my_inbox(text,text,text), suggest_delegates(text,text,date,date), effective_assignee(text,text,date), activate_delegation(text,text,text,date,date,text,text,uuid,text), end_delegations(text) to app_user;
-- Bảng xếp hạng kỷ luật theo phòng (việc quá hạn / tổng việc 30 ngày) cho BGĐ
create or replace view v_dept_discipline as
 select t.farm_id, s.dept, count(*) filter (where t.status in ('MO','DANG_LAM','TREO') and t.due_at < now()) as overdue,
        count(*) filter (where t.status='XONG') as done, count(*) as total,
        round(100.0*count(*) filter (where t.status='XONG' and t.done_at <= t.due_at)/nullif(count(*) filter (where t.status='XONG'),0),0) as on_time_pct
 from tasks t join staff s on s.id=coalesce(t.assignee_id,t.done_by) where t.created_at > now() - interval '30 days' and s.dept is not null group by 1,2;
grant select on v_dept_discipline to app_user;
-- 4) Việc tự sinh (MONITOR/HERD/ALERT/PLAN…) không ai nhận, quá hạn >14 ngày → tự đóng BO_QUA (job đêm), tránh hộp việc phình
create or replace function expire_stale_tasks(p_farm text, p_days int default 14) returns int language plpgsql as $$
declare n int; begin
  update tasks set status='BO_QUA', done_at=now(), handover_note=coalesce(handover_note,'')||' [tự đóng: quá hạn '||p_days||' ngày, không ai nhận]'
   where farm_id=p_farm and status='MO' and assignee_id is null and due_at < now() - (p_days||' days')::interval;
  get diagnostics n = row_count; return n; end $$;
grant execute on function expire_stale_tasks(text,int) to app_user;
