-- 0103 — CẤU TRÚC TÀI KHOẢN CỐ ĐỊNH (chỗ ngồi công việc)
--
-- Nguyên tắc: TÀI KHOẢN là chỗ ngồi, bất biến, không xoá. NGƯỜI chỉ là kẻ đang giữ chỗ.
-- Người nghỉ -> đóng nhiệm kỳ, mở nhiệm kỳ mới cho người thay; chỗ ngồi và lịch sử việc giữ nguyên.
-- MỘT tài khoản có thể có NHIỀU người cùng giữ ở CÁC CA khác nhau (sáng / chiều / đêm).
-- Tên, email, số điện thoại là của NGƯỜI GIỮ, khai bên trong tài khoản — không nằm trên tài khoản.
--
-- Mã tài khoản có cấu trúc, đọc là biết ngay: {PHÒNG}-{CẤP BẬC}-{SỐ THỨ TỰ}
--   KTCN-A-03 = phòng Kỹ thuật chăn nuôi · cấp bậc A (công nhân) · chỗ thứ 3
--   D5-T-01   = xưởng D5 · cấp bậc T (trưởng nhóm) · chỗ thứ 1
-- Cấp bậc: A công nhân · T trưởng nhóm · K kỹ thuật trưởng/trưởng phòng · G ban điều hành
--          C kế toán · Q chất lượng–kiểm toán · I kỹ sư công nghệ
--
-- Ba thực thể tách bạch:
--   positions_catalog = LOẠI vị trí (nghề): nghề gì, phòng nào, vai gì, được dùng form nào.
--   job_accounts      = TÀI KHOẢN = một chỗ ngồi cụ thể, mã bất biến.
--   account_holders   = nhiệm kỳ theo CA: ai giữ chỗ nào, ca nào, từ ngày nào đến ngày nào.
--
-- MỌI thứ giao xuống (việc, quy trình, quyền, form) gán vào TÀI KHOẢN.
-- Bản ghi nghiệp vụ vẫn lưu NGƯỜI ghi (truy xuất nguồn gốc / ATTP bắt buộc) — hai việc khác nhau.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Mở rộng danh mục nghề: bổ sung nghề còn thiếu + phủ cả khối quản lý
-- ─────────────────────────────────────────────────────────────────────────────
alter table positions_catalog add column if not exists active boolean default true;
alter table positions_catalog add column if not exists rank_code text;   -- A/T/K/G/C/Q/I
alter table positions_catalog add column if not exists note text;

insert into positions_catalog (code, name, dept_code, role_code, forms, kpis, position) values
  -- Công nhân: nghề còn thiếu trong danh mục gốc
  ('A15','RAS – thuỷ sản tuần hoàn','SH','worker','{animal_events,batch_logs}','{"Tỷ lệ sống","DO/pH đạt"}',15),
  ('A16','Tài xế – vận chuyển – chuỗi lạnh','CCU','worker','{inventory_moves,gate_logs}','{"Giao đúng hạn","Nhiệt độ đạt"}',16),
  ('A17','Mua hàng – vật tư','CCU','worker','{inventory_moves}','{"Giá mua","Giao đúng hẹn"}',17),
  ('A18','Hành chính – chấm công – y tế trại','HCNS','worker','{}','{"Chấm công đủ"}',18),
  -- Trưởng nhóm
  ('T01','Trưởng nhóm chăn nuôi bò','D5','team_lead','{}','{}',31),
  ('T02','Trưởng nhóm sơ chế – kho lạnh','D5','team_lead','{}','{}',32),
  ('T03','Trưởng nhóm khu D (trùn/BSF/biogas)','SH','team_lead','{}','{}',33),
  ('T04','Trưởng nhóm đồng ruộng','TT','team_lead','{}','{}',34),
  ('T05','Thủ kho trưởng','CCU','team_lead','{}','{}',35),
  ('T06','Bác sĩ thú y','KTCN','team_lead','{}','{}',36),
  ('T07','Chuyên viên đào tạo – SOP','HCNS','team_lead','{}','{}',37),
  -- Kỹ thuật trưởng / trưởng phòng chuyên môn
  ('K01','Kỹ thuật trưởng chăn nuôi','D5','tech_head','{}','{}',41),
  ('K02','Kỹ thuật trưởng sinh học','SH','tech_head','{}','{}',42),
  ('K03','KTT Kỹ thuật – Thú y trưởng','KTCN','tech_head','{}','{}',43),
  ('K04','KTT Trồng trọt – Sinh khối','TT','tech_head','{}','{}',44),
  ('K05','Trưởng phòng Chuỗi cung ứng – Mua hàng','CCU','tech_head','{}','{}',45),
  ('K06','Trưởng phòng Công nghệ – Dữ liệu','CNTB','it_engineer','{}','{}',46),
  ('K07','Kỹ sư công nghệ','CNTB','it_engineer','{}','{}',47),
  ('K08','Trưởng R&D – Đổi mới','RD','tech_head','{}','{}',48),
  -- Ban điều hành
  ('G01','Chủ đầu tư','HDQT','owner','{}','{}',51),
  ('G02','Chủ tịch HĐQT','HDQT','owner','{}','{}',52),
  ('G03','Tổng giám đốc','BGD','director','{}','{}',53),
  ('G04','Giám đốc trại','GDT','director','{}','{}',54),
  ('G05','Trưởng phòng Kinh doanh – Marketing','KDM','director','{}','{}',55),
  ('G06','Trưởng phòng HC–NS–Đào tạo','HCNS','director','{}','{}',56),
  ('G07','Ban Phát triển dự án – Nhượng quyền','MR','director','{}','{}',57),
  ('G08','Trưởng phòng XNK – Thị trường QT','XNK','director','{}','{}',58),
  -- Tài chính – kế toán
  ('C01','Kế toán trưởng','TCKT','accountant','{}','{}',61),
  ('C02','Kế toán tổng hợp','TCKT','accountant','{}','{}',62),
  ('C03','Thủ quỹ – kế toán thanh toán','TCKT','accountant','{}','{}',63),
  ('C04','Kế toán trại','HCNS','accountant','{}','{}',64),
  -- Chất lượng – kiểm toán
  ('Q01','Trưởng phòng QA/QC – Tuân thủ','QA','auditor','{}','{}',71),
  ('Q02','QC viên – lấy mẫu – audit nội bộ','QA','auditor','{}','{}',72),
  ('Q03','Kiểm toán độc lập','QA','auditor','{}','{}',73)
on conflict (code) do nothing;

update positions_catalog set rank_code = left(code, 1) where rank_code is null;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. TÀI KHOẢN = chỗ ngồi. Mã có cấu trúc {PHÒNG}-{CẤP BẬC}-{STT}, BẤT BIẾN.
--    `login` là bí danh để đăng nhập (giữ nguyên mã cũ để không gãy gì đang chạy).
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists job_accounts (
  code           text primary key,                    -- KTCN-A-03. KHÔNG đổi, KHÔNG xoá.
  login          text unique,                         -- bí danh đăng nhập (a1, cn-bo2…)
  org_id         text not null default 'ITRAN',
  farm_id        text,
  dept_code      text not null,
  rank_code      text not null,                       -- A/T/K/G/C/Q/I
  seq            int  not null,                       -- số thứ tự trong (phòng, cấp bậc)
  position_code  text references positions_catalog(code),
  title          text not null,                       -- tên chỗ ngồi
  role_code      text not null,                       -- vai dùng phân quyền
  headcount      int default 1,                       -- số người tối đa cùng giữ (nhiều ca)
  active         boolean default true,                -- bỏ chỗ thì tắt, TUYỆT ĐỐI không xoá
  note           text,
  created_at     timestamptz default now()
);
create index if not exists ix_job_accounts_pos on job_accounts(position_code);
create index if not exists ix_job_accounts_dept on job_accounts(dept_code, rank_code, seq);

-- NHIỆM KỲ theo CA. Cùng một chỗ ngồi, ca sáng một người, ca đêm người khác — cả hai đều đang giữ.
create table if not exists account_holders (
  id           bigserial primary key,
  account_code text not null references job_accounts(code),
  staff_id     text not null references staff(id),
  shift        text not null default 'HC',            -- HC hành chính · SANG · CHIEU · DEM
  from_date    date not null default current_date,
  to_date      date,                                  -- null = đang giữ
  is_primary   boolean default true,                  -- người chịu trách nhiệm chính của chỗ
  reason       text,
  created_at   timestamptz default now()
);
create index if not exists ix_holders_acc on account_holders(account_code);
create index if not exists ix_holders_staff on account_holders(staff_id);
-- Một chỗ ngồi + một CA chỉ có đúng một người đang giữ. Khác ca thì được nhiều người.
create unique index if not exists ux_holder_current on account_holders(account_code, shift) where to_date is null;

alter table job_accounts enable row level security;
alter table account_holders enable row level security;
drop policy if exists p_all on job_accounts;
create policy p_all on job_accounts using (true)
  with check (app_role() in ('owner','director','it_engineer','tech_head'));
drop policy if exists p_all on account_holders;
create policy p_all on account_holders using (true)
  with check (app_role() in ('owner','director','it_engineer','tech_head'));
grant select, insert, update on job_accounts, account_holders to app_user;
grant usage on sequence account_holders_id_seq to app_user;

-- Người giữ chỗ cần email liên lạc (SĐT đã có sẵn trên staff.phone).
alter table staff add column if not exists email text;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Dựng tài khoản từ nhân sự hiện có, GÁN LẠI ĐÚNG NGHỀ.
--    Cột position_code cũ trên staff sai hàng loạt (gán máy móc theo con số trong tên):
--    cn-bo2 (chuồng bò) -> A1 (trộn TMR); cn-trun (khu D) -> A6 (ruộng);
--    ktv-tb (bảo trì/IoT) -> A12 (lễ tân); bep/letan/buong -> cùng A13 (hướng dẫn tour)...
--    Bảng dưới là bản gán lại theo NGHỀ THẬT, đọc từ chức danh + phòng ban.
-- ─────────────────────────────────────────────────────────────────────────────
with mapping(login, pos) as (values
  -- D5 · trộn TMR & chế biến
  ('a1','A1'), ('cn-d5-2','A1'),
  ('a7','A7'), ('cn-donggoi','A7'), ('cn-soche','A7'),
  -- KTCN · bò – dê – bê
  ('a2','A2'), ('cn-be','A2'), ('cn-bo2','A2'), ('cn-de','A2'),
  -- KTCN · gà
  ('a3','A3'), ('cn-ga2','A3'), ('cn-gathit','A3'), ('cn-nghi2','A3'),
  -- SH · khu D sinh học
  ('a6','A4'), ('cn-trun','A4'), ('cn-bsf','A4'),
  -- SH · RAS thuỷ sản
  ('a4','A15'),
  -- TT · ruộng – máy nông nghiệp
  ('a5','A6'), ('cn-co1','A6'), ('cn-bap','A6'), ('cn-lua','A6'), ('cn-rau','A6'), ('cn-nghi1','A6'),
  -- CCU · kho – vận chuyển – mua hàng
  ('a8','A8'), ('taixe','A16'), ('muahang','A17'),
  -- KDM · bán hàng
  ('a9','A9'), ('cskh','A9'), ('nvkd1','A9'), ('nvkd2','A9'),
  -- HCNS · cổng – bảo vệ – hành chính
  ('a11','A10'), ('baove2','A10'), ('hanhchinh','A18'),
  -- CNTB · bảo trì – IoT
  ('ktv-tb','A11'),
  -- DL · lễ tân – buồng – bếp
  ('letan','A12'), ('buong','A12'), ('bep','A14'),
  -- Trưởng nhóm
  ('tn-bo','T01'), ('tn-cb','T02'), ('tn-sh','T03'), ('tn-tt','T04'),
  ('thukho','T05'), ('bsty','T06'), ('daotao','T07'),
  -- Kỹ thuật trưởng / trưởng phòng chuyên môn
  ('ktt-cn','K01'), ('ktt-sh','K02'), ('ktt-ty','K03'), ('ktt-tt','K04'),
  ('tp-ccu','K05'), ('tp-cn','K06'), ('ks-cn','K07'), ('rd1','K08'),
  -- Ban điều hành
  ('owner','G01'), ('chutich','G02'), ('tgd','G03'), ('gd','G04'),
  ('tp-kd','G05'), ('tp-hcns','G06'), ('mr1','G07'), ('xnk1','G08'),
  -- Tài chính
  ('ktt-tc','C01'), ('kt-th','C02'), ('thuquy','C03'), ('kt','C04'),
  -- Chất lượng
  ('tp-qa','Q01'), ('qc1','Q02'), ('audit','Q03')
),
nguon as (
  select s.login, s.org_id, s.farm_id, s.dept, s.position, s.role, s.active,
         m.pos as position_code,
         -- cấp bậc suy từ nghề; nghề chưa gán thì suy từ vai
         coalesce(left(m.pos, 1), case s.role when 'worker' then 'A' when 'team_lead' then 'T'
           when 'tech_head' then 'K' when 'it_engineer' then 'I' when 'accountant' then 'C'
           when 'auditor' then 'Q' else 'G' end) as rank_code
  from staff s left join mapping m on m.login = s.login
  where s.login is not null
),
danh_so as (
  select *, row_number() over (partition by dept, rank_code order by position_code nulls last, login) as seq
  from nguon
)
insert into job_accounts (code, login, org_id, farm_id, dept_code, rank_code, seq, position_code, title, role_code, active, note)
select dept || '-' || rank_code || '-' || lpad(seq::text, 2, '0'),
       login, org_id, farm_id, dept, rank_code, seq, position_code, position, role, active,
       case when position_code is null then 'CHUA_GAN_NGHE' end
from danh_so
on conflict (code) do nothing;

-- Nhiệm kỳ hiện tại: người đang làm giữ chính chỗ ngồi của mình, mặc định ca hành chính.
insert into account_holders (account_code, staff_id, shift, from_date, is_primary, reason)
select a.code, s.id,
       case when a.title ~* 'ca đêm|ban đêm' then 'DEM' when a.title ~* 'ca 2|ca chiều' then 'CHIEU' else 'HC' end,
       coalesce(s.hired_on, s.created_at::date, current_date), true, 'Khởi tạo từ nhân sự hiện có'
from job_accounts a join staff s on s.login = a.login
where s.active
on conflict do nothing;

-- Đồng bộ ngược mã nghề đã sửa về staff (cột cũ, giữ cho tương thích).
update staff s set position_code = a.position_code
from job_accounts a where a.login = s.login and a.position_code is not null;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Hàm & view
-- ─────────────────────────────────────────────────────────────────────────────

-- Mã tài khoản của phiên hiện tại (withCtx đặt qua set_config('app.account', ...)).
create or replace function app_account() returns text language sql stable as
$$ select nullif(current_setting('app.account', true), '') $$;

-- Nghề của tài khoản đang đăng nhập — dùng chọn bộ form, giao việc, phân quyền.
create or replace function app_position() returns text language sql stable as
$$ select position_code from job_accounts where code = app_account() $$;

-- BÀN GIAO CHỖ NGỒI theo ca: đóng nhiệm kỳ người cũ của ca đó, mở nhiệm kỳ người mới. Không xoá gì.
create or replace function handover_account(p_account text, p_staff text, p_shift text default 'HC',
                                            p_from date default current_date, p_reason text default null)
returns account_holders language plpgsql security definer as $$
declare r account_holders;
begin
  if not exists (select 1 from job_accounts where code = p_account) then raise exception 'ERR_NO_ACCOUNT'; end if;
  if not exists (select 1 from staff where id = p_staff) then raise exception 'ERR_NO_STAFF'; end if;
  update account_holders set to_date = p_from - 1, reason = coalesce(reason, '') || ' · bàn giao ' || p_from
    where account_code = p_account and shift = p_shift and to_date is null;
  insert into account_holders (account_code, staff_id, shift, from_date, reason)
    values (p_account, p_staff, p_shift, p_from, p_reason) returning * into r;
  return r;
end $$;
grant execute on function handover_account(text,text,text,date,text) to app_user;

-- Danh bạ tài khoản: chỗ ngồi + nghề + NHỮNG người đang giữ theo ca (tên · email · SĐT).
create or replace view v_account_directory as
select a.code as tai_khoan, a.login as dang_nhap, a.title as cho_ngoi, a.dept_code as phong,
       a.rank_code as cap_bac, a.seq as stt, a.role_code as vai,
       a.position_code as ma_nghe, p.name as ten_nghe, a.active, a.note,
       (select count(*) from account_holders h where h.account_code = a.code and h.to_date is null) as so_nguoi_dang_giu,
       (select string_agg(s.full_name || ' (' || h.shift || ')', ' · ' order by h.shift)
          from account_holders h join staff s on s.id = h.staff_id
         where h.account_code = a.code and h.to_date is null) as nguoi_dang_giu
from job_accounts a left join positions_catalog p on p.code = a.position_code;

-- Chi tiết người giữ trong một tài khoản — tên/email/SĐT khai ở đây, không nằm trên tài khoản.
create or replace view v_account_members as
select a.code as tai_khoan, a.title as cho_ngoi, a.dept_code as phong, h.shift as ca,
       s.id as ma_nhan_su, s.full_name as ho_ten, s.email, s.phone as sdt,
       h.from_date as giu_tu, h.to_date as giu_den, h.is_primary as chinh,
       (h.to_date is null) as dang_giu
from job_accounts a
join account_holders h on h.account_code = a.code
join staff s on s.id = h.staff_id;

-- Chỗ ngồi đang TRỐNG — để tuyển/điều người, và để biết việc đang rơi vào khoảng không.
create or replace view v_seats_vacant as
select a.code as tai_khoan, a.title as cho_ngoi, a.dept_code as phong, a.position_code as ma_nghe, p.name as ten_nghe
from job_accounts a left join positions_catalog p on p.code = a.position_code
where a.active and not exists (select 1 from account_holders h where h.account_code = a.code and h.to_date is null);

-- Nghề đã khai trong danh mục nhưng CHƯA CÓ tài khoản nào — lỗ hổng tổ chức.
create or replace view v_positions_unstaffed as
select p.code as ma_nghe, p.name as ten_nghe, p.dept_code as phong, p.role_code as vai
from positions_catalog p
where p.active is not false and not exists (select 1 from job_accounts a where a.position_code = p.code and a.active);

grant select on v_account_directory, v_account_members, v_seats_vacant, v_positions_unstaffed to app_user;
