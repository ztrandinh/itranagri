-- 0186 · DỌN 5 bước mẫu CŨ (0159 & mẫu KT/TT) còn tham chiếu SKU placeholder KHÔNG có trong products.
-- Map sang SKU CÓ THẬT, giữ nguyên qty/unit, thêm ghi_chu. Guard theo sku placeholder → idempotent,
-- chỉ đổi nếu còn placeholder (không đè nếu đã sửa). Sau migration: mọi materials.sku đều tồn tại trong products.

-- P-KT-01 s2: THE-TAI (thẻ tai — CHƯA có SKU riêng) → CC-BOC-TAI (kìm bấm thẻ tai + kim)
update process_steps set
  materials = '[{"sku":"CC-BOC-TAI","qty":1,"unit":"cái/con","ghi_chu":"bấm thẻ tai/RFID — thẻ tai chưa có SKU riêng, chủ bổ sung"}]'::jsonb
where process_code='P-KT-01' and step_no=2 and materials @> '[{"sku":"THE-TAI"}]'::jsonb;

-- P-KT-02 s2: TINH-BO → TINH-BRAHMAN (tinh bò Brahman; đổi TINH-BBB nếu phối hướng vỗ béo)
update process_steps set
  materials = '[{"sku":"TINH-BRAHMAN","qty":1,"unit":"liều/con","ghi_chu":"tinh phối; đổi TINH-BBB nếu hướng vỗ béo — chủ/thú y chọn"}]'::jsonb
where process_code='P-KT-02' and step_no=2 and materials @> '[{"sku":"TINH-BO"}]'::jsonb;

-- P-KT-03 s2: THUOC → TH-OXY (Oxytetracycline, có ngưng thuốc). Phác đồ tuỳ bệnh.
update process_steps set
  materials = '[{"sku":"TH-OXY","qty":1,"unit":"liều/con","ghi_chu":"phác đồ MINH HOẠ; chọn thuốc theo bệnh + tuân ngưng thuốc — thú y sửa"}]'::jsonb
where process_code='P-KT-03' and step_no=2 and materials @> '[{"sku":"THUOC"}]'::jsonb;

-- P-TT-02 s2: GIONG-BAP → GI-BAP-SK (hạt giống bắp sinh khối)
update process_steps set
  materials = '[{"sku":"GI-BAP-SK","qty":25,"unit":"kg/ha","ghi_chu":"lượng gieo minh hoạ — chủ sửa theo giống/mật độ"}]'::jsonb
where process_code='P-TT-02' and step_no=2 and materials @> '[{"sku":"GIONG-BAP"}]'::jsonb;

-- P-TT-02 s3: PHAN-HUU-CO → PB-HUU-CO (phân hữu cơ ủ hoai)
update process_steps set
  materials = '[{"sku":"PB-HUU-CO","qty":2000,"unit":"kg/ha","ghi_chu":"bón lót minh hoạ — chủ sửa theo phân tích đất"}]'::jsonb
where process_code='P-TT-02' and step_no=3 and materials @> '[{"sku":"PHAN-HUU-CO"}]'::jsonb;
