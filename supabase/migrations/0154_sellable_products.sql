-- 0154 · Khai DANH MỤC sản phẩm BÁN RA còn thiếu (config = dữ liệu, luật 7). Chỉ THÊM (on conflict do nothing).
--
-- Chủ chốt danh mục bán: bò · dê · HƯƠU · gà · trứng · tôm/cá(lươn) · phân (trùn quế · bò · dê · gà).
-- Đã có: bò/dê/gà hơi+thịt, trứng, trùn (SKU-PTR-25/TRUN-TUOI), BSF, phân hữu cơ (PB-HUU-CO/PB-NPK).
-- Thiếu → khai: HƯƠU (nhung + hơi), thuỷ sản thương phẩm (lươn/cá/tôm), phân THÔ theo loài (bò/dê/gà).
-- "Bán ra" = suy từ kind (THANH_PHAM/PHAN_BON), không cần cột riêng. Giá để price_list riêng (ref_price null).

insert into products(sku, name, kind, unit, shelf_life_days) values
  -- Hươu (nuôi lấy nhung là chính; có thể bán hươu hơi)
  ('SKU-NHUNG-HUOU', 'Nhung hươu tươi',        'THANH_PHAM', 'kg',  7),
  ('SKU-HUOU-HOI',   'Hươu hơi',               'THANH_PHAM', 'kg',  1),
  -- Thuỷ sản thương phẩm (RAS/ao — loài LUON đã có trong đàn)
  ('SKU-LUON-THIT',  'Lươn thương phẩm',       'THANH_PHAM', 'kg',  2),
  ('SKU-CA-THIT',    'Cá thương phẩm',         'THANH_PHAM', 'kg',  2),
  ('SKU-TOM-THIT',   'Tôm thương phẩm',        'THANH_PHAM', 'kg',  2),
  -- Phân THÔ theo loài (bán ra / làm nguyên liệu ủ)
  ('SKU-PHAN-BO',    'Phân bò thô',            'PHAN_BON',   'kg', 365),
  ('SKU-PHAN-DE',    'Phân dê thô',            'PHAN_BON',   'kg', 365),
  ('SKU-PHAN-GA',    'Phân gà thô',            'PHAN_BON',   'kg', 365)
on conflict (sku) do nothing;
