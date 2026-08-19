-- 0093 · MARKETING – TRUYỀN THÔNG (phòng KDM): chiến dịch → lịch nội dung (duyệt ≠ người viết) → đăng → đo → gắn lead/đơn/booking (ROI) · thương hiệu · lắng nghe & khủng hoảng truyền thông (SOP-KD-05)
create table if not exists mkt_campaigns(
  id uuid primary key default gen_random_uuid(), farm_id text not null, code text, name text not null, objective text, channels text[] default '{}', audience text, product_focus text,
  starts_on date, ends_on date, budget numeric default 0, kpi_target jsonb default '{}', status text not null default 'NHAP' check (status in ('NHAP','DANG_CHAY','TAM_DUNG','XONG','HUY')),
  owner_id text, promo_id uuid, utm_code text, note text, created_at timestamptz default now(), created_by text
);
create table if not exists mkt_contents(
  id uuid primary key default gen_random_uuid(), farm_id text not null, campaign_id uuid references mkt_campaigns on delete set null, planned_at date not null, channel text not null, kind text not null default 'BAI_VIET',
  title text not null, brief text, status text not null default 'Y_TUONG' check (status in ('Y_TUONG','DANG_LAM','CHO_DUYET','DUYET','DA_DANG','HUY')), author_id text, approved_by text, approved_at timestamptz, published_at timestamptz, url text,
  metrics jsonb default '{}', cost numeric default 0, note text, created_at timestamptz default now(), created_by text
);
create table if not exists mkt_assets(id uuid primary key default gen_random_uuid(), farm_id text not null, kind text not null, title text not null, url text, tags text[] default '{}', version text, approved boolean default false, approved_by text, note text, created_at timestamptz default now(), created_by text);
create table if not exists mkt_mentions(
  id uuid primary key default gen_random_uuid(), farm_id text not null, ts timestamptz default now(), channel text not null, source_url text, author text, summary text not null,
  sentiment text not null default 'TRUNG_TINH' check (sentiment in ('TICH_CUC','TRUNG_TINH','TIEU_CUC')), severity text default 'THAP' check (severity in ('THAP','TRUNG','CAO','KHUNG_HOANG')),
  status text not null default 'MOI' check (status in ('MOI','DANG_XU_LY','DA_PHAN_HOI','DONG')), handler_id text, response text, resolved_at timestamptz, created_at timestamptz default now(), created_by text
);
alter table crm_leads add column if not exists campaign_id uuid, add column if not exists utm text;
alter table sales add column if not exists campaign_id uuid;
alter table hosp_bookings add column if not exists campaign_id uuid;
do $$ declare t text; begin foreach t in array array['mkt_campaigns','mkt_contents','mkt_assets','mkt_mentions'] loop
  execute format('alter table %I enable row level security; drop policy if exists p_all on %I; create policy p_all on %I for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update, delete on %I to app_user', t,t,t,t); end loop; end $$;
-- Duyệt nội dung: người duyệt ≠ người viết; nội dung tiêu cực/khủng hoảng → việc KHẨN cho trưởng KDM + GĐ
create or replace function trg_mkt_content_guard() returns trigger language plpgsql as $$
begin
  if new.status in ('DUYET','DA_DANG') and new.approved_by is not null and new.approved_by = new.author_id then raise exception 'ERR_SELF_APPROVE: người viết không tự duyệt nội dung'; end if;
  if new.status = 'DA_DANG' and new.published_at is null then new.published_at := now(); end if;
  return new; end $$;
drop trigger if exists mkt_content_guard on mkt_contents; create trigger mkt_content_guard before insert or update on mkt_contents for each row execute function trg_mkt_content_guard();
create or replace function trg_mkt_mention_alert() returns trigger language plpgsql as $$
declare head text; begin
  if new.sentiment='TIEU_CUC' and new.severity in ('CAO','KHUNG_HOANG') then
    select id into head from staff where (farm_id=new.farm_id or farm_id is null) and dept='KDM' and active and role in ('tech_head','team_lead','director') order by (farm_id=new.farm_id) desc, role='tech_head' desc limit 1;
    insert into tasks(farm_id,kind,title,detail,target_type,target_id,assignee_id,role_hint,due_at,priority,source,ref_table,ref_id)
      values (new.farm_id,'KHUNG_HOANG_TT','Xử lý phản hồi tiêu cực ('||new.severity||') trên '||new.channel||': '||left(new.summary,80), jsonb_build_object('note','SOP-KD-05: xác minh trong 2h, phản hồi công khai trong 24h, báo GĐ; không tranh cãi, không xóa bình luận','url',new.source_url), 'mention', new.id::text, head, 'director', now() + interval '2 hours', 'KHAN', 'MARKETING', 'mkt_mentions', new.id::text);
    insert into notifications(farm_id,staff_id,level,title,body,link,source,source_id) select new.farm_id, s.id, 'DO', 'Truyền thông tiêu cực '||new.severity||' — '||new.channel, left(new.summary,120), '/marketing?tab=tt', 'mkt', new.id::text from staff s where (s.farm_id=new.farm_id or s.farm_id is null) and s.active and (s.role in ('director','owner') or s.id=head) limit 4;
    perform publish_event(new.farm_id, 'marketing.crisis', jsonb_build_object('id',new.id,'channel',new.channel,'severity',new.severity));
  end if; return new; end $$;
drop trigger if exists mkt_mention_alert on mkt_mentions; create trigger mkt_mention_alert after insert on mkt_mentions for each row execute function trg_mkt_mention_alert();
-- Hiệu quả chiến dịch: chi phí (nội dung + ngân sách chi thực) · lead · đơn/doanh thu (sales.campaign_id hoặc promotion) · booking du lịch · CPL · ROAS
create or replace view v_campaign_perf as
 select c.farm_id, c.id, c.code, c.name, c.status, c.starts_on, c.ends_on, c.budget, c.channels, c.kpi_target,
   coalesce((select sum(cost) from mkt_contents x where x.campaign_id=c.id),0) as content_cost,
   (select count(*) from mkt_contents x where x.campaign_id=c.id and x.status='DA_DANG') as posts,
   coalesce((select sum((metrics->>'reach')::numeric) from mkt_contents x where x.campaign_id=c.id),0) as reach,
   coalesce((select sum((metrics->>'clicks')::numeric) from mkt_contents x where x.campaign_id=c.id),0) as clicks,
   (select count(*) from crm_leads l where l.campaign_id=c.id) as leads,
   (select count(*) from crm_leads l where l.campaign_id=c.id and l.stage in ('WON','THANG','DA_MUA','HOP_DONG')) as leads_won,
   (select count(distinct coalesce(order_id::text, id::text)) from sales s where s.campaign_id=c.id or (c.promo_id is not null and s.promotion_id::text=c.promo_id::text)) as orders,
   coalesce((select sum(amount) from sales s where s.campaign_id=c.id or (c.promo_id is not null and s.promotion_id::text=c.promo_id::text)),0) as revenue,
   (select count(*) from hosp_bookings b where b.campaign_id=c.id) as bookings,
   coalesce((select sum(total) from hosp_bookings b where b.campaign_id=c.id),0) as booking_revenue
 from mkt_campaigns c;
grant select on v_campaign_perf to app_user;
create or replace view v_mkt_weekly as
 select farm_id, date_trunc('week', coalesce(published_at, planned_at::timestamptz))::date as week, channel, count(*) filter (where status='DA_DANG') as posted, count(*) as planned,
   coalesce(sum((metrics->>'reach')::numeric),0) as reach, coalesce(sum((metrics->>'clicks')::numeric),0) as clicks, coalesce(sum(cost),0) as cost
 from mkt_contents where planned_at >= current_date - 84 group by 1,2,3;
grant select on v_mkt_weekly to app_user;
create or replace view v_leads_by_channel as
 select farm_id, date_trunc('month', created_at)::date as month, coalesce(source,'KHAC') as source, count(*) as leads, count(*) filter (where stage in ('WON','THANG','DA_MUA','HOP_DONG')) as won, coalesce(sum(est_value),0) as est_value from crm_leads where created_at >= current_date - 365 group by 1,2,3;
grant select on v_leads_by_channel to app_user;
-- Quy trình phòng KDM về marketing (để GS kiểm được) + tiêu chí
insert into processes(code, dept_code, name, kind, trigger_text, inputs, outputs, sla, owner_role, kpi, sop_code, position, active, status, coverage, lifecycle_stage, l1_chain, organ)
values
 ('P-MK-01','KDM','Marketing: kế hoạch tháng → lịch nội dung → viết → duyệt (người khác) → đăng → đo → báo cáo tuần','CORE','Tuần','["Kế hoạch bán/tour tháng","Sự kiện mùa vụ","Ngân sách"]','["Lịch nội dung","Bài đăng có số đo","Báo cáo tuần"]','Đăng đúng lịch ≥90%','team_lead','Bài đúng lịch %; reach; lead/tuần; chi phí/lead','SOP-KD-02',80,true,'BAN_HANH','DA_CO','KINH_DOANH','KDM','KDM'),
 ('P-MK-02','KDM','Lắng nghe & xử lý khủng hoảng truyền thông: ghi nhận → phân loại → xác minh 2h → phản hồi 24h → đóng → rút kinh nghiệm','CORE','Ngày','["Bình luận/đánh giá/bài báo"]','["Phiếu xử lý","Phản hồi công khai"]','Xác minh ≤2h; phản hồi ≤24h','team_lead','Tiêu cực chưa phản hồi >24h = 0','SOP-KD-05',81,true,'BAN_HANH','DA_CO','KINH_DOANH','KDM','KDM'),
 ('P-MK-03','KDM','Chiến dịch & sự kiện: mục tiêu → ngân sách → kênh → mã KM/UTM → chạy → gắn lead/đơn/booking → ROI → đóng','SUPPORT','Theo lịch/ca hoặc sự kiện','["Mục tiêu bán","Ngân sách"]','["Chiến dịch có ROI"]','ROI ≥ 2','tech_head','ROAS; CPL; lead → đơn %','SOP-KD-02',82,true,'BAN_HANH','DA_CO','KINH_DOANH','KDM','KDM')
on conflict (code) do nothing;
insert into process_steps(process_code, step_no, name, actor_role, dept_code, action, control, output, required) values
 ('P-MK-01',1,'Lập lịch nội dung tuần/tháng theo kế hoạch bán & mùa vụ','team_lead','KDM','Tạo mkt_contents planned_at/kênh/loại','Có lịch trước thứ 6 tuần trước','Lịch nội dung',true),
 ('P-MK-01',2,'Viết/quay nội dung theo brief','worker','KDM','Cập nhật DANG_LAM → CHO_DUYET','Đúng nhận diện thương hiệu, có nguồn số liệu, không sai sự thật','Bản nháp',true),
 ('P-MK-01',3,'Duyệt (người duyệt ≠ người viết)','tech_head','KDM','DUYET','Không có thông tin sai/quá lời/vi phạm quảng cáo','Bài được duyệt',true),
 ('P-MK-01',4,'Đăng đúng giờ, ghi link','worker','KDM','DA_DANG + url','Đăng ≤30 phút so lịch','Bài đã đăng',true),
 ('P-MK-01',5,'Đo & cập nhật số liệu sau 48h/7 ngày','worker','KDM','metrics reach/clicks/leads','Có số sau 7 ngày','Số đo',true),
 ('P-MK-02',1,'Ghi nhận phản hồi/bình luận/bài báo','worker','KDM','Tạo mkt_mentions','Mọi tiêu cực được ghi trong ngày','Phiếu ghi nhận',true),
 ('P-MK-02',2,'Phân loại mức độ; CAO/KHỦNG HOẢNG → báo GĐ tức thì','team_lead','KDM','severity','≤2h','Phân loại',true),
 ('P-MK-02',3,'Xác minh sự thật với bộ phận liên quan','team_lead','KDM','ghi response nháp','≤2h','Kết luận',true),
 ('P-MK-02',4,'Phản hồi công khai (không tranh cãi, không xóa), theo dõi','team_lead','KDM','DA_PHAN_HOI','≤24h','Phản hồi',true),
 ('P-MK-02',5,'Đóng & rút kinh nghiệm → cập nhật SOP/FAQ','tech_head','KDM','DONG','Có bài học ghi lại','Bài học',true),
 ('P-MK-03',1,'Lập chiến dịch: mục tiêu, ngân sách, kênh, mã KM/UTM','tech_head','KDM','mkt_campaigns','Có KPI đích','Chiến dịch',true),
 ('P-MK-03',2,'Chạy & gắn nguồn: lead/đơn/booking ghi campaign_id','worker','KDM','crm_leads.campaign_id, sales.campaign_id','≥90% lead có nguồn','Dữ liệu gắn nguồn',true),
 ('P-MK-03',3,'Đóng chiến dịch, tính ROI, đề xuất tiếp','tech_head','KDM','XONG','ROI có số','Báo cáo ROI',true)
on conflict do nothing;
select sync_process_criteria();
