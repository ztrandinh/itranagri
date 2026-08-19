-- 0096 · Đánh bóng đóng tồn: (1) v_sop_signoff lấy đúng 81 L2 SOP thật (gộp theo l2_code) · (2) ack_sop tra version theo l2_code · (3) COGS: backfill products.last_cost từ giá nhập gần nhất + cập nhật last_cost khi nhận PO

-- ===== (1) KÝ SOP THEO L2 THẬT =====
-- Thư viện SOP lưu 81 nhóm L2 dưới dạng hàng L3 (l2_code + l3_no), status='NHAP'; KHÔNG có hàng header L2 'BAN_HANH'.
-- v_sop_signoff cũ lọc (l3_no is null and status='BAN_HANH') → rỗng. Định nghĩa lại: 1 dòng / l2_code (tên = l2_group, phòng = dept nhóm).
create or replace view v_sop_signoff as
with l2 as (
  select l2_code as code,
         max(l2_group)                         as title,
         (array_agg(dept order by l3_no))[1]   as dept,
         max(version)                          as version,
         max(owner_role)                       as owner_role,
         max(video_url)                        as video_url,
         max(published_at)                     as published_at,
         count(*)                              as steps
  from sops where l2_code is not null and l3_no is not null
  group by l2_code
)
select l2.code, l2.title, l2.dept, l2.version, l2.owner_role, l2.video_url, l2.published_at,
  (select count(*) from staff st where st.active and (st.dept = l2.dept or l2.dept is null)) as need,
  (select count(distinct a.staff_id) from sop_acknowledgments a where a.sop_code = l2.code and a.kind='DOC_HIEU') as signed,
  l2.steps
from l2;
grant select on v_sop_signoff to app_user;

-- ===== (2) ack_sop: tra version theo cả code trực tiếp lẫn l2_code (khi ký cả nhóm L2) =====
create or replace function ack_sop(p_farm text, p_sop text, p_staff text, p_kind text, p_score numeric default null) returns void language plpgsql as $$
declare v int; begin
  select max(version) into v from sops where code=p_sop or l2_code=p_sop;
  insert into sop_acknowledgments(farm_id, sop_code, sop_version, staff_id, kind, score) values (p_farm, p_sop, coalesce(v,1), p_staff, p_kind, p_score)
    on conflict (sop_code, sop_version, staff_id, kind) do update set acknowledged_at=now(), score=coalesce(excluded.score, sop_acknowledgments.score);
end $$;
grant execute on function ack_sop(text,text,text,text,numeric) to app_user;

-- ===== (3) COGS: products.last_cost = giá nhập mua gần nhất =====
-- Backfill: giá của lần nhập có giá gần nhất mỗi SKU (ưu tiên NHAP_MUA, else bất kỳ dòng nhập có đơn giá)
update products p set last_cost = m.unit_cost
from (
  select distinct on (sku) sku, unit_cost
  from inventory_moves
  where direction=1 and unit_cost > 0
  order by sku, (reason='NHAP_MUA') desc, ts desc
) m
where m.sku = p.sku and (p.last_cost is null or p.last_cost = 0);

-- Cập nhật last_cost mỗi khi nhận PO (giá nhập mới nhất) — tái tạo receive_po từ 0071 + 1 dòng update last_cost
create or replace function receive_po(p_po text, p_wh text default null, p_lines jsonb default null) returns int language plpgsql as $$
declare po record; l jsonb; v_sku text; v_qty numeric; v_price numeric; v_wh text; v_lot text; n int := 0; v_kind text; v_lotno text; v_exp date; v_partial bool := false; begin
  select * into po from purchase_orders where id=p_po; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  if po.po_status not in ('DUYET','NHAN_MOT_PHAN') then raise exception 'ERR_PO_NOT_APPROVED'; end if;
  for l in select * from jsonb_array_elements(coalesce(p_lines, po.lines)) loop
    v_sku := l->>'sku'; v_qty := coalesce((l->>'received_qty')::numeric, (l->>'qty')::numeric); v_price := (l->>'price')::numeric; if v_qty is null or v_qty<=0 then continue; end if;
    if (l->>'received_qty') is not null and (l->>'received_qty')::numeric < (l->>'qty')::numeric then v_partial := true; end if;
    select kind into v_kind from products where sku=v_sku;
    v_wh := coalesce(l->>'warehouse_id', p_wh, (select id from warehouses w where w.farm_id=po.farm_id and w.code = case when v_kind='CONG_CU' then 'KCC-CB' when v_kind in ('THUOC','VACCINE','GIONG','VAT_TU','PHAN_BON') then 'K1' when v_kind='NHIEN_LIEU' then 'K7' when v_kind='BAO_BI' then 'K9' when v_kind='THANH_PHAM' then 'K5' else 'K2' end limit 1));
    if v_wh is null then select id into v_wh from warehouses where farm_id=po.farm_id and code='K2'; end if;
    v_lotno := coalesce(l->>'lot_no', 'PO-'||right(p_po,5)||'-'||to_char(now(),'YYMMDD')); v_exp := coalesce((l->>'expiry')::date, (current_date + coalesce((select shelf_life_days from products where sku=v_sku), 365))::date);
    v_lot := ensure_lot(po.farm_id, v_sku, v_lotno, po.supplier_id, v_exp);
    if l->>'coa_url' is not null then update lots set coa_url=l->>'coa_url' where id=v_lot; end if;
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to, weigh_point, ref_type, ref_id)
    values (po.farm_id, now(), app_staff(), 'APP', 'po-'||p_po||'-'||v_sku||'-'||to_char(clock_timestamp(),'YYMMDDHH24MISSMS'), v_wh, v_sku, v_lot, 1, v_qty, coalesce((select unit from products where sku=v_sku),'kg'), v_price, 'NHAP_MUA', po.supplier_id, 'CUA_KHO', 'purchase_orders', p_po);
    if v_price is not null and v_price > 0 then update products set last_cost=v_price where sku=v_sku; end if;
    n := n+1;
  end loop;
  update purchase_orders set po_status=case when v_partial then 'NHAN_MOT_PHAN' else 'DA_NHAN' end, received_at=coalesce(received_at, now()) where id=p_po;
  perform publish_event(po.farm_id, 'po.received', jsonb_build_object('po_id', p_po, 'supplier_id', po.supplier_id, 'lines', n));
  return n; end $$;
grant execute on function receive_po(text,text,jsonb) to app_user;
