-- 0149 · Giám sát LÔ HẾT HẠN CÒN TỒN — an toàn thực phẩm (không bán/dùng hàng quá hạn).
--
-- Read-side: view drill-down + cảnh báo GOM 1 việc/TRẠI (KHÔNG nổ 1 việc/lô — tránh nhiễu khi có
-- nhiều lô). Chỉ tính lô CÒN TỒN thật (sum direction*qty > 0) và còn KHA_DUNG/GIU_QC. Không hard-guard.
-- (Lưu ý dữ liệu seed: nhiều lô cũ để mở không đóng → con số dev cao bất thường; logic vẫn đúng trên data thật.)

create or replace view v_lot_expiry_watch as
with onhand as (
  select lot_id, sum(direction * qty) as ton
  from inventory_moves where status = 'ACTIVE' and lot_id is not null group by lot_id
)
select l.farm_id, l.id as lot_id, l.sku, l.expiry_date, coalesce(o.ton, 0) as ton,
       case when l.expiry_date < current_date        then 'HET_HAN'
            when l.expiry_date < current_date + 7     then 'SAP_HET_7'
            else                                           'SAP_HET_30' end as tinh_trang
from lots l
join onhand o on o.lot_id = l.id
where l.status in ('KHA_DUNG','GIU_QC')
  and coalesce(o.ton, 0) > 0
  and l.expiry_date is not null
  and l.expiry_date < current_date + 30;

-- Cảnh báo GOM: 1 việc/trại (idempotent, tự đóng khi hết lô quá hạn còn tồn)
create or replace function gen_lot_expiry_alerts(p_farm text) returns int language plpgsql as $$
declare c_het int; c_sap int; open_task uuid; begin
  select count(*) filter (where tinh_trang = 'HET_HAN'),
         count(*) filter (where tinh_trang in ('SAP_HET_7','SAP_HET_30'))
    into c_het, c_sap from v_lot_expiry_watch where farm_id = p_farm;
  select id into open_task from tasks
    where farm_id = p_farm and ref_table = 'lot_expiry' and ref_id = p_farm and status <> 'XONG' limit 1;
  if coalesce(c_het,0) + coalesce(c_sap,0) > 0 then
    if open_task is null then
      insert into tasks(farm_id, kind, title, detail, target_type, target_id, role_hint, due_at, priority, source, ref_table, ref_id)
        values (p_farm, 'LOT_EXPIRY',
          '⚠ '||c_het||' lô HẾT HẠN + '||c_sap||' lô sắp hết (còn tồn) — cách ly/tiêu huỷ/ưu tiên xuất',
          jsonb_build_object('het_han', c_het, 'sap_het', c_sap,
            'note', 'Rà v_lot_expiry_watch: lô HẾT HẠN phải cô lập/tiêu huỷ (cấm bán); lô sắp hết ưu tiên xuất trước (FEFO).'),
          'FARM', p_farm, 'tech_head', now() + interval '1 day', 'CAO', 'FOOD_SAFETY', 'lot_expiry', p_farm);
      return 1;
    end if;
    return 0;
  else
    update tasks set status = 'XONG', done_at = now(), done_by = 'system'
      where farm_id = p_farm and ref_table = 'lot_expiry' and ref_id = p_farm and status <> 'XONG';
    return 0;
  end if;
end $$;
grant execute on function gen_lot_expiry_alerts(text) to app_user;
grant select on v_lot_expiry_watch to app_user;
