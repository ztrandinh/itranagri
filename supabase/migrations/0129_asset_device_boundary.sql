-- 0129 — Ranh giới THIẾT BỊ / TÀI SẢN / PHƯƠNG TIỆN / DỤNG CỤ
--
-- Trước: 4 bảng chồng lấn, không ai trả lời được "cân cầu 40T nằm ở đâu".
-- Chốt: chia theo CÂU HỎI NGHIỆP VỤ, không chia theo loại vật.
--
--   fixed_assets  "Còn bao nhiêu giá trị sổ sách?"  nguyên giá, khấu hao, thanh lý   -> kế toán
--   devices       "Máy có chạy đúng không?"          hiệu chuẩn, bảo trì, đọc số      -> kỹ thuật
--   vehicles      "Xe đang ở đâu, chở gì?"           biển số, chuyến, chuỗi lạnh      -> chuỗi cung ứng
--   tools         "Ai đang cầm cái này?"             cấp phát theo tài khoản          -> kho
--
-- LUẬT QUYẾT ĐỊNH, một câu:
--   cần KHẤU HAO -> có dòng ở fixed_assets
--   cần HIỆU CHUẨN / BẢO TRÌ / ĐỌC SỐ -> có dòng ở devices
--   CẢ HAI đều đúng -> có dòng ở CẢ HAI, nối bằng fixed_assets.device_id (cột đã có sẵn,
--   chưa ai dùng). Không nhân bản dữ liệu; mỗi bảng trả lời đúng câu hỏi của mình.
--
-- Cân cầu 40T: có nguyên giá VÀ phải hiệu chuẩn -> nằm ở cả hai, một device_id nối lại.

comment on table fixed_assets is 'SỔ KẾ TOÁN của tài sản: nguyên giá, khấu hao, thanh lý. Nếu vật đó còn phải hiệu chuẩn/bảo trì thì tạo thêm dòng ở `devices` và nối qua fixed_assets.device_id.';
comment on table devices      is 'SỔ VẬN HÀNH của máy móc: hiệu chuẩn, bảo trì, đọc số, cảm biến. Nếu vật đó còn phải ghi sổ kế toán thì tạo thêm dòng ở `fixed_assets` và nối qua fixed_assets.device_id.';
comment on table vehicles     is 'Phương tiện: biển số, chuyến đi, nhiên liệu, chuỗi lạnh. Xe cũng là tài sản -> nối qua fixed_assets.device_id nếu cần ghi sổ.';
comment on table tools        is 'Dụng cụ TỪNG CÁI, cấp phát theo TÀI KHOẢN (chỗ ngồi) chứ không theo người. Không khấu hao.';
comment on column fixed_assets.device_id is 'Nối sang `devices` khi cùng một vật vừa phải ghi sổ kế toán vừa phải hiệu chuẩn/bảo trì. Đây là cầu nối duy nhất giữa hai sổ — KHÔNG nhân bản dữ liệu sang nhau.';

-- Nối tự động những cặp đã trùng tên giữa hai sổ (cân, máy kéo, xe trộn…).
update fixed_assets a set device_id = d.id
from devices d
where a.device_id is null and a.farm_id = d.farm_id
  and lower(btrim(a.name)) = lower(btrim(d.name));

-- Khai ranh giới vào sổ đăng ký để người sau đọc là biết, khỏi đoán.
update code_registry set note = 'SỔ KẾ TOÁN — cần khấu hao thì vào đây. Nối sang devices qua fixed_assets.device_id nếu vật đó còn phải hiệu chuẩn.' where object_type = 'tai_san';
update code_registry set note = 'SỔ VẬN HÀNH — cần hiệu chuẩn/bảo trì/đọc số thì vào đây. Nối sang fixed_assets nếu vật đó còn phải ghi sổ kế toán.'   where object_type = 'thiet_bi';
update code_registry set note = 'Phương tiện: biển số, chuyến, nhiên liệu, chuỗi lạnh.'                                                              where object_type = 'xe';

-- Một vật, hai sổ, nhìn cùng lúc — để kế toán và kỹ thuật không cãi nhau về cùng cái máy.
create or replace view v_asset_device as
select coalesce(a.id, d.id)  as ma,
       coalesce(a.name, d.name) as ten,
       a.id as ma_tai_san, d.id as ma_thiet_bi,
       case when a.id is not null and d.id is not null then 'Cả hai sổ'
            when a.id is not null then 'Chỉ sổ kế toán'
            else 'Chỉ sổ vận hành' end as thuoc_so,
       a.cost as nguyen_gia, a.accumulated as da_khau_hao,
       (coalesce(a.cost,0) - coalesce(a.accumulated,0)) as gia_tri_con_lai,
       d.kind as loai_may, coalesce(a.farm_id, d.farm_id) as farm_id
from fixed_assets a full outer join devices d on d.id = a.device_id;
grant select on v_asset_device to app_user;
