-- 0104 — SỔ ĐĂNG KÝ MÃ: mọi đối tượng đều có mã, khai một chỗ duy nhất
--
-- Soát 180 bảng trước khi làm migration này:
--   68 bảng khoá uuid (khoá kỹ thuật — chấp nhận)
--   15 bảng khoá số tự tăng (người không đọc được)
--   16 bảng đúng quy ước {phạm vi}-{loại}-{số}
--   80 bảng KHÔNG theo quy ước nào
-- Bệnh cụ thể tìm được:
--   · thiết bị chẻ làm 3 bảng, 3 kiểu mã: devices F01-TB-001 / fixed_assets F01-TS-0001 / vehicles F01-XE-01
--   · dụng cụ KHÔNG có mã từng cái — tool_issues cấp theo sku 'CC-XE-RUA' qty 2, hỏng 1 cái không biết cái nào
--   · crop_seasons sinh mã lỗi: 'F01-CS--G1A' (hai gạch liền — ghép chuỗi với đoạn rỗng), 97/97 dòng dính
--   · độ rộng số mỗi nơi một kiểu: BO-00122 (5) · TB-001 (3) · TS-0001 (4) · XE-01 (2)
--   · đuôi mã là chữ mô tả: F01-FC-CHUONG-BO, F01-LO-G1A — đổi tên là mã sai nghĩa
--
-- NGUYÊN TẮC QUAN TRỌNG: KHÔNG đổi mã đã phát hành. Mã cũ đã in ra giấy, dán lên chuồng,
-- in trên tem QR, nằm trong hơn 110.000 bản ghi. Đổi mã cũ = gãy truy xuất và hồ sơ pháp lý.
-- Quy ước dưới đây áp cho mã SINH MỚI; mã cũ khai vào cột legacy_pattern để nhận diện, giữ nguyên.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Sổ đăng ký: mỗi loại đối tượng khai đúng một dòng
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists code_registry (
  object_type    text primary key,          -- khoá kỹ thuật, không dấu (vd 'thiet_bi')
  label          text not null,             -- tên tiếng Việt hiển thị
  table_name     text,                      -- bảng chứa đối tượng
  scope          text not null,             -- ORG (toàn công ty) · FARM (một trại) · DEPT (phòng ban)
  prefix         text not null,             -- vế giữa của mã: BO, DAN, TB, DC…
  width          int  not null default 5,   -- số chữ số ở vế cuối
  level          text not null,             -- CA_THE (từng cái) · NHOM (đàn/lô/bộ) · LOAI (chủng loại)
  parent_type    text references code_registry(object_type),  -- cá thể thuộc nhóm nào
  legacy_pattern text,                      -- mẫu mã cũ đang tồn tại (giữ nguyên, không đổi)
  note           text,
  active         boolean default true
);
alter table code_registry enable row level security;
drop policy if exists p_all on code_registry;
create policy p_all on code_registry using (true)
  with check (app_role() in ('owner','director','it_engineer','tech_head'));
grant select on code_registry to app_user;

insert into code_registry (object_type, label, table_name, scope, prefix, width, level, parent_type, legacy_pattern, note) values
  -- ─── Vật nuôi: ba cấp định danh ───
  ('dan_vat_nuoi','Đàn / bể vật nuôi','animal_groups','FARM','DAN',5,'NHOM',null,'F01-DAN-*, F01-GA-*, F01-GT-*, F01-RAS-*','Gà, cá, lươn, tôm, trùn đếm theo ĐÀN — không đánh mã từng con'),
  ('lo_nhap','Lô nhập','animal_lots','FARM','LN',5,'NHOM','dan_vat_nuoi',null,'Cùng nguồn, cùng ngày, cùng giấy kiểm dịch'),
  ('bo','Bò (cá thể)','animals','FARM','BO',5,'CA_THE','dan_vat_nuoi',null,'Con giá trị cao: bắt buộc mã từng con, có bệnh án và phả hệ'),
  ('de','Dê (cá thể)','animals','FARM','DE',5,'CA_THE','dan_vat_nuoi',null,'Bắt buộc mã từng con'),
  ('cuu','Cừu (cá thể)','animals','FARM','CUU',5,'CA_THE','dan_vat_nuoi',null,null),
  -- ─── Cây trồng: định danh theo cặp Ô THỬA × VỤ ───
  ('o_thua','Ô thửa','plots','FARM','LO',5,'CA_THE',null,'F01-LO-G1A','Mảnh đất — cố định theo không gian'),
  ('vu_mua','Vụ mùa','crop_seasons','FARM','VU',5,'CA_THE','o_thua','F01-CS--* (LỖI: hai gạch liền)','Cùng mảnh trồng nhiều vụ — truy xuất phải ra đúng VỤ, không chỉ đúng mảnh'),
  -- ─── Thiết bị · tài sản · dụng cụ ───
  ('thiet_bi','Thiết bị / máy','devices','FARM','TB',5,'CA_THE',null,'F01-TB-001 (3 số)','Máy móc, cân, cảm biến'),
  ('tai_san','Tài sản cố định','fixed_assets','FARM','TS',5,'CA_THE',null,'F01-TS-0001 (4 số)','Tài sản ghi sổ kế toán'),
  ('xe','Phương tiện','vehicles','FARM','XE',5,'CA_THE',null,'F01-XE-01 (2 số)','Xe tải, xe lạnh, máy kéo'),
  ('dung_cu','Dụng cụ (từng cái)','tools','FARM','DC',5,'CA_THE','loai_dung_cu',null,'MỚI: trước đây dụng cụ chỉ có mã LOẠI (sku), cấp 2 cái hỏng 1 không biết cái nào'),
  ('loai_dung_cu','Loại dụng cụ','products','ORG','LDC',5,'LOAI',null,'CC-*','Chủng loại dụng cụ trong danh mục hàng hoá'),
  ('phieu_cap_dung_cu','Phiếu cấp dụng cụ','tool_issues','FARM','PCD',5,'CA_THE',null,'số tự tăng','Trước đây khoá bằng số tự tăng, không có mã đọc được'),
  -- ─── Kho · vị trí · cơ sở ───
  ('kho','Kho','warehouses','FARM','K',5,'CA_THE',null,'F01-K1',null),
  ('vi_tri_kho','Vị trí kệ / pallet','bins','FARM','BIN',5,'CA_THE','kho','F01-BIN-K1-A01',null),
  ('khu_vuc','Khu vực / điểm ghi','locations','FARM','KV',5,'CA_THE',null,'F01-CH-CL',null),
  ('co_so','Cơ sở / công trình','facilities','FARM','FC',5,'CA_THE',null,'F01-FC-CHUONG-BO',null),
  -- ─── Con người · tổ chức ───
  ('nhan_su','Nhân sự (con người)','staff','ORG','NS',5,'CA_THE',null,'NS-115 (3 số, không có phạm vi)','NGƯỜI — có thể nghỉ, thay đổi'),
  ('tai_khoan','Tài khoản / chỗ ngồi','job_accounts','DEPT','',0,'CA_THE','phong_ban','{PHÒNG}-{CẤP BẬC}-{STT}','CHỖ NGỒI — bất biến, không xoá. Mã theo phòng ban + cấp bậc + số thứ tự'),
  ('phong_ban','Phòng ban','departments','ORG','PB',3,'NHOM',null,'HDQT, KTCN (mã chữ, không có số)',null),
  ('vi_tri_nghe','Vị trí nghề','positions_catalog','ORG','',0,'LOAI',null,'A1…A18, T01…, K01…, G01…, C01…, Q01…','Chủng loại nghề — tài khoản trỏ vào đây'),
  -- ─── Danh mục dùng chung ───
  ('san_pham','Sản phẩm / hàng hoá','products','ORG','SP',5,'LOAI',null,'BB-BAO-25 (không có phạm vi)',null),
  ('doi_tac','Đối tác','partners','ORG','DT',5,'CA_THE',null,null,null),
  ('cong_thuc','Công thức thức ăn','recipes','ORG','RC',5,'LOAI',null,'RC-TMR-VO',null),
  ('sop','SOP','sops','ORG','SOP',5,'LOAI',null,'SOP-BO-08.1',null),
  ('quy_trinh','Quy trình','processes','ORG','P',5,'LOAI',null,'P-QA-02',null),
  ('dinh_muc','Định mức','norms','ORG','N',5,'LOAI',null,'N-PHAN-BO',null)
on conflict (object_type) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Bộ sinh mã đọc sổ đăng ký — thay cho việc mỗi chỗ tự ghép chuỗi
-- ─────────────────────────────────────────────────────────────────────────────
-- Bộ đếm riêng cho sổ đăng ký. KHÔNG dùng lại id_sequences vì bảng đó khoá ngoại vào `farms`,
-- nên không đếm được mã cấp công ty (ORG) hay cấp phòng ban (DEPT).
create table if not exists code_counters (
  scope_id text not null,
  prefix   text not null,
  last_no  bigint not null default 0,
  primary key (scope_id, prefix)
);
grant select on code_counters to app_user;

create or replace function make_code(p_type text, p_scope text default null)
returns text language plpgsql security definer as $$
declare r code_registry; s text; n bigint;
begin
  select * into r from code_registry where object_type = p_type and active;
  if not found then raise exception 'ERR_UNKNOWN_OBJECT_TYPE: % chưa khai trong code_registry', p_type; end if;
  if r.width = 0 then raise exception 'ERR_CUSTOM_CODE: % dùng quy tắc mã riêng, không sinh tự động', p_type; end if;

  s := case r.scope when 'ORG' then coalesce(nullif(p_scope,''), nullif(current_setting('app.org_id', true),''), 'ITRAN')
                    else nullif(p_scope, '') end;
  -- Chặn đúng lỗi đã gặp: crop_seasons sinh ra 'F01-CS--G1A' vì một đoạn rỗng vẫn được ghép vào.
  if s is null or s = '' then raise exception 'ERR_EMPTY_SCOPE: sinh mã % mà thiếu phạm vi (trại/phòng) — sẽ ra mã hỏng kiểu F01-CS--G1A', p_type; end if;
  if r.prefix is null or r.prefix = '' then raise exception 'ERR_EMPTY_PREFIX: % chưa khai tiền tố', p_type; end if;

  insert into code_counters(scope_id, prefix, last_no) values (s, r.prefix, 1)
    on conflict (scope_id, prefix) do update set last_no = code_counters.last_no + 1
    returning last_no into n;
  return s || '-' || r.prefix || '-' || lpad(n::text, r.width, '0');
end $$;
grant execute on function make_code(text, text) to app_user;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. DỤNG CỤ TỪNG CÁI — lấp đúng lỗ hổng: trước đây chỉ có mã loại (sku)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists tools (
  id            text primary key,                 -- F01-DC-00001
  farm_id       text not null,
  sku           text,                             -- loại dụng cụ (products.sku)
  name          text not null,
  serial_no     text,                             -- số máy của nhà sản xuất nếu có
  warehouse_id  text,                             -- kho quản lý
  holder_account text references job_accounts(code),  -- ĐANG do TÀI KHOẢN nào giữ (không phải người)
  status        text default 'SAN_SANG',          -- SAN_SANG · DANG_MUON · HONG · THANH_LY
  bought_on     date,
  note          text,
  created_at    timestamptz default now()
);
create index if not exists ix_tools_farm on tools(farm_id);
create index if not exists ix_tools_holder on tools(holder_account);
alter table tools enable row level security;
drop policy if exists p_farm on tools;
create policy p_farm on tools using (farm_id = any(string_to_array(current_setting('app.farm_ids', true), ',')))
  with check (farm_id = any(string_to_array(current_setting('app.farm_ids', true), ',')));
grant select, insert, update on tools to app_user;

-- Phiếu cấp phát trỏ được tới TỪNG CÁI dụng cụ (giữ nguyên sku cho vật tư cấp theo số lượng).
alter table tool_issues add column if not exists tool_id text references tools(id);
alter table tool_issues add column if not exists code text;   -- mã phiếu đọc được: F01-PCD-00001
create index if not exists ix_tool_issues_tool on tool_issues(tool_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Bảng theo dõi sức khoẻ mã — biết ngay bảng nào đang lệch quy ước
-- ─────────────────────────────────────────────────────────────────────────────
create or replace view v_code_health as
select r.object_type as loai_doi_tuong, r.label as ten, r.table_name as bang, r.scope as pham_vi,
       r.prefix as tien_to, r.width as do_rong, r.level as cap_do,
       coalesce(r.legacy_pattern, '—') as ma_cu_dang_ton_tai,
       case when r.width = 0 then 'quy tắc riêng'
            when r.legacy_pattern is null then 'sạch'
            else 'có mã cũ — giữ nguyên, chỉ áp quy ước cho mã mới' end as tinh_trang
from code_registry r where r.active order by r.level, r.object_type;
grant select on v_code_health to app_user;

-- Cặp CÁ THỂ ↔ NHÓM: đọc là biết đối tượng nào đánh mã từng cái, đối tượng nào đánh mã theo nhóm.
create or replace view v_code_levels as
select r.level as cap_do, r.label as doi_tuong, p.label as thuoc_nhom, r.prefix as tien_to, r.note as ghi_chu
from code_registry r left join code_registry p on p.object_type = r.parent_type
where r.active order by case r.level when 'NHOM' then 1 when 'CA_THE' then 2 else 3 end, r.object_type;
grant select on v_code_levels to app_user;
