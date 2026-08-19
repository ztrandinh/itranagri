-- 0107 — provision_accounts(): cấp tài khoản cho MỌI nhân sự, chạy lại được
--
-- Lỗi phát hiện khi dựng lại từ CSDL trắng: migration 0103 tạo tài khoản NGAY LÚC MIGRATE,
-- mà lúc đó `staff` mới chỉ có nhân sự nền của 0005. Nhân sự thật do script gieo thêm
-- (seed-history-staff.sql) chạy SAU nên không được cấp chỗ ngồi:
--     67 nhân sự có đăng nhập  ->  chỉ 18 tài khoản
-- Hậu quả đo được: đăng nhập cn-bo2 và taixe trả về account = null.
-- Vậy việc cấp tài khoản phải là HÀM chạy lại được sau mỗi lần gieo, không phải một lần trong migration.

-- Bảng ánh xạ nghề (trước nằm trong mệnh đề VALUES một lần của 0103 nên không dùng lại được).
create table if not exists account_position_map (
  login text primary key,
  position_code text references positions_catalog(code)
);
grant select on account_position_map to app_user;

insert into account_position_map(login, position_code) values
  ('a1','A1'), ('cn-d5-2','A1'),
  ('a7','A7'), ('cn-donggoi','A7'), ('cn-soche','A7'),
  ('a2','A2'), ('cn-be','A2'), ('cn-bo2','A2'), ('cn-de','A2'),
  ('a3','A3'), ('cn-ga2','A3'), ('cn-gathit','A3'), ('cn-nghi2','A3'),
  ('a6','A4'), ('cn-trun','A4'), ('cn-bsf','A4'),
  ('a4','A15'),
  ('a5','A6'), ('cn-co1','A6'), ('cn-bap','A6'), ('cn-lua','A6'), ('cn-rau','A6'), ('cn-nghi1','A6'),
  ('a8','A8'), ('taixe','A16'), ('muahang','A17'),
  ('a9','A9'), ('cskh','A9'), ('nvkd1','A9'), ('nvkd2','A9'),
  ('a11','A10'), ('baove2','A10'), ('hanhchinh','A18'),
  ('ktv-tb','A11'),
  ('letan','A12'), ('buong','A12'), ('bep','A14'),
  ('tn-bo','T01'), ('tn-cb','T02'), ('tn-sh','T03'), ('tn-tt','T04'),
  ('thukho','T05'), ('bsty','T06'), ('daotao','T07'),
  ('ktt-cn','K01'), ('ktt-sh','K02'), ('ktt-ty','K03'), ('ktt-tt','K04'),
  ('tp-ccu','K05'), ('tp-cn','K06'), ('ks-cn','K07'), ('rd1','K08'),
  ('owner','G01'), ('chutich','G02'), ('tgd','G03'), ('gd','G04'),
  ('tp-kd','G05'), ('tp-hcns','G06'), ('mr1','G07'), ('xnk1','G08'),
  ('ktt-tc','C01'), ('kt-th','C02'), ('thuquy','C03'), ('kt','C04'),
  ('tp-qa','Q01'), ('qc1','Q02'), ('audit','Q03')
on conflict (login) do nothing;

create or replace function provision_accounts() returns text language plpgsql security definer as $$
declare n_tk int := 0; n_nk int := 0;
begin
  -- 1. Cấp chỗ ngồi cho nhân sự chưa có tài khoản. Số thứ tự chạy tiếp trong (phòng, cấp bậc).
  with moi as (
    select s.login, s.org_id, s.farm_id, s.dept, s.position, s.role, s.active,
           m.position_code,
           coalesce(left(m.position_code, 1),
                    case s.role when 'worker' then 'A' when 'team_lead' then 'T'
                                when 'tech_head' then 'K' when 'it_engineer' then 'I'
                                when 'accountant' then 'C' when 'auditor' then 'Q' else 'G' end) as rank_code
    from staff s
    left join account_position_map m on m.login = s.login
    where s.login is not null and s.dept is not null
      and not exists (select 1 from job_accounts a where a.login = s.login)
  ),
  danh_so as (
    select moi.*,
           coalesce((select max(a.seq) from job_accounts a where a.dept_code = moi.dept and a.rank_code = moi.rank_code), 0)
           + row_number() over (partition by dept, rank_code order by position_code nulls last, login) as seq
    from moi
  )
  insert into job_accounts (code, login, org_id, farm_id, dept_code, rank_code, seq, position_code, title, role_code, active, note)
  select dept || '-' || rank_code || '-' || lpad(seq::text, 2, '0'),
         login, org_id, farm_id, dept, rank_code, seq, position_code, position, role, active,
         case when position_code is null then 'CHUA_GAN_NGHE' end
  from danh_so
  on conflict (code) do nothing;
  get diagnostics n_tk = row_count;

  -- 2. Mở nhiệm kỳ cho người đang làm mà chỗ ngồi chưa có ai giữ ở ca đó.
  insert into account_holders (account_code, staff_id, shift, from_date, is_primary, reason)
  select a.code, s.id,
         case when a.title ~* 'ca đêm|ban đêm' then 'DEM'
              when a.title ~* 'ca 2|ca chiều' then 'CHIEU' else 'HC' end,
         coalesce(s.hired_on, s.created_at::date, current_date), true, 'Cấp tự động theo nhân sự đang làm'
  from job_accounts a join staff s on s.login = a.login
  where s.active
    and not exists (select 1 from account_holders h where h.account_code = a.code and h.to_date is null)
  on conflict do nothing;
  get diagnostics n_nk = row_count;

  -- 3. Đồng bộ mã nghề về staff (cột cũ, giữ cho tương thích).
  update staff s set position_code = a.position_code
  from job_accounts a where a.login = s.login and a.position_code is not null
    and s.position_code is distinct from a.position_code;

  return format('Cấp %s tài khoản, mở %s nhiệm kỳ. Tổng: %s tài khoản / %s nhân sự có đăng nhập',
                n_tk, n_nk,
                (select count(*) from job_accounts),
                (select count(*) from staff where login is not null));
end $$;
grant execute on function provision_accounts() to app_user;

select provision_accounts();

-- Nhân sự có đăng nhập mà VẪN chưa có tài khoản — phải luôn rỗng.
create or replace view v_staff_no_account as
select s.id, s.login, s.full_name, s.dept, s.role, s.position
from staff s where s.login is not null and not exists (select 1 from job_accounts a where a.login = s.login);
grant select on v_staff_no_account to app_user;
