-- seed-history-ref.sql — Nối ref cho move seed lịch sử về sự kiện nguồn (truy xuất seed)
--
-- Bối cảnh: seed-history.sql sinh move tiêu thụ/sản xuất (XUAT_CHO_AN/XUAT_SX/NHAP_SX) ĐỘC LẬP
-- với feed_logs/batch_logs (sinh ở seed-history-2.sql), nên ref_type NULL. Đường LIVE đã set ref
-- qua trigger 0134/0136; đây chỉ vá phần seed lịch sử để bản dựng lại cũng truy xuất được.
--
-- Cách nối (chính xác về ngữ nghĩa, không bịa): mỗi move nối tới sự kiện có SKU thực sự tham gia,
-- GẦN THỜI ĐIỂM nhất (ưu tiên cùng nhóm với move cho ăn). Chỉ đụng move seed (source='IMPORT')
-- còn ref NULL. Move append-only → tạm tắt trigger bằng session_replication_role.

set session_replication_role = 'replica';

-- 1) XUAT_CHO_AN → feed_log có recipe chứa sku, cùng nhóm (from_to↔dest_group_id) & gần ts nhất
update inventory_moves im set ref_type='feed_logs', ref_id = (
  select fl.id::text from feed_logs fl join recipes r on r.id = fl.recipe_id
  where fl.farm_id = im.farm_id
    and r.components @> jsonb_build_array(jsonb_build_object('sku', im.sku))
  order by (fl.dest_group_id = im.from_to) desc, abs(extract(epoch from (fl.ts - im.ts))) asc
  limit 1)
where im.reason='XUAT_CHO_AN' and im.ref_type is null and im.source='IMPORT'
  and exists(select 1 from feed_logs fl join recipes r on r.id=fl.recipe_id
             where fl.farm_id=im.farm_id and r.components @> jsonb_build_array(jsonb_build_object('sku', im.sku)));

-- 2) XUAT_SX → batch_log có sku trong INPUTS, gần ts nhất
update inventory_moves im set ref_type='batch_logs', ref_id = (
  select bl.id::text from batch_logs bl
  where bl.farm_id = im.farm_id and bl.inputs @> jsonb_build_array(jsonb_build_object('sku', im.sku))
  order by abs(extract(epoch from (bl.ts - im.ts))) asc limit 1)
where im.reason='XUAT_SX' and im.ref_type is null and im.source='IMPORT'
  and exists(select 1 from batch_logs bl where bl.farm_id=im.farm_id and bl.inputs @> jsonb_build_array(jsonb_build_object('sku', im.sku)));

-- 3) NHAP_SX → batch_log có sku trong OUTPUTS, gần ts nhất
update inventory_moves im set ref_type='batch_logs', ref_id = (
  select bl.id::text from batch_logs bl
  where bl.farm_id = im.farm_id and bl.outputs @> jsonb_build_array(jsonb_build_object('sku', im.sku))
  order by abs(extract(epoch from (bl.ts - im.ts))) asc limit 1)
where im.reason='NHAP_SX' and im.ref_type is null and im.source='IMPORT'
  and exists(select 1 from batch_logs bl where bl.farm_id=im.farm_id and bl.outputs @> jsonb_build_array(jsonb_build_object('sku', im.sku)));

-- 4) XUAT_BAN → sale bán thành phẩm: khớp theo LÔ (chính xác), fallback sku, gần ts nhất
update inventory_moves im set ref_type='sales', ref_id = (
  select s.id::text from sales s
  where s.farm_id = im.farm_id and s.status='ACTIVE'
    and (s.lot_id = im.lot_id or s.sku = im.sku)
  order by (s.lot_id = im.lot_id) desc, abs(extract(epoch from (s.ts - im.ts))) asc limit 1)
where im.reason='XUAT_BAN' and im.ref_type is null and im.source='IMPORT'
  and exists(select 1 from sales s where s.farm_id=im.farm_id and (s.lot_id=im.lot_id or s.sku=im.sku));

set session_replication_role = 'origin';

-- Báo cáo độ phủ sau backfill (để soi khi chạy seed)
select reason,
       count(*) filter (where source='IMPORT') as seed_move,
       count(*) filter (where source='IMPORT' and ref_type is not null) as co_ref
from inventory_moves where reason in ('XUAT_CHO_AN','XUAT_SX','NHAP_SX') group by reason order by reason;
