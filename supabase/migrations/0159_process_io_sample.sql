-- 0159 · MẪU đầu vào/đầu ra ĐỊNH LƯỢNG cho bước quy trình (process_steps.materials + output) — chứng minh
-- format + hiển thị. Khung ĐÃ CÓ (materials jsonb [{sku,qty,unit}] + output; UI ProcessDesigner đã render +
-- sửa được). Chỉ THIẾU DỮ LIỆU (650 bước, mới ~6 điền). Áp dụng TOÀN CỤC mọi lĩnh vực — đây chỉ là 1 mẫu
-- (gà úm) để chủ thấy cách điền; số lượng là MINH HOẠ, chủ/thú y sửa số thật. Điền hàng loạt → chip riêng.
-- unit mã hoá "biến": g/con/ngày, kg/ha, kWh/lứa… (định lượng theo đầu con/diện tích/lứa).

update process_steps set
  materials = '[
    {"sku":"GI-GA-CON","qty":1000,"unit":"con","ghi_chu":"gà con 1 ngày tuổi/lứa"},
    {"sku":"TA-VIEN-GA","qty":11,"unit":"g/con/ngày","ghi_chu":"khẩu phần úm — MINH HOẠ, sửa theo tuần tuổi"},
    {"sku":"VX-THT","qty":1,"unit":"liều/con","ghi_chu":"vaccine theo lịch"}
  ]'::jsonb,
  output = 'đàn hậu bị (animal_groups) — hao hụt mục tiêu ≤3%'
where process_code = 'P-VN-08' and step_no = 1 and coalesce(materials,'[]'::jsonb) = '[]'::jsonb;
