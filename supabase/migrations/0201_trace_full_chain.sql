-- 0201 · Truy xuất TOÀN CHUỖI thật (quyết định chủ đầu tư: làm thật, không chỉ điều chỉnh truyền thông).
-- Trước đây `/api/public/trace/[lot]` (trang công khai /trace/{lot}, đúng nơi khách/auditor quét QR)
-- chỉ query trực tiếp v_trace_links 1 lần — đi được đúng 1 bước lùi, không bao giờ chạm nguồn gốc thật
-- (harvest/mua) hay điểm cuối thật (bán/cho ăn). Có sẵn 1 query nội bộ (`trace_lot` trong queries.ts,
-- dùng ở /xem/{type}/{id} 360) đã đệ quy qua nhiều batch_logs tới độ sâu 6 — nhưng CŨNG dừng ở biên
-- batch_logs, không chạm harvest/sales/feeding, và KHÔNG được API công khai dùng tới.
--
-- Hàm này đệ quy 2 chiều qua v_trace_links (tới độ sâu 10, đủ cho mọi chuỗi chế biến thật) rồi với
-- TOÀN BỘ tập lô trong chuỗi (gốc + tổ tiên + hậu duệ), tra thêm 4 loại điểm chốt thật:
-- harvests.dest_lot_id (nguồn gốc thu hoạch), inventory_moves reason=NHAP_MUA (nguồn gốc mua),
-- sales.lot_id (điểm bán cuối), inventory_moves reason=XUAT_CHO_AN (tiêu thụ làm thức ăn).
create or replace function trace_full_chain(p_farm text, p_lot text) returns jsonb language plpgsql as $$
declare v_ancestors text[]; v_descendants text[]; v_all text[];
begin
  with recursive back as (
    select input_lot, output_lot, batch_code, ts, 1 as depth from v_trace_links where farm_id=p_farm and output_lot=p_lot
    union
    select t.input_lot, t.output_lot, t.batch_code, t.ts, b.depth+1 from v_trace_links t join back b on t.output_lot=b.input_lot where b.depth<10
  )
  select array_agg(distinct input_lot) into v_ancestors from back where input_lot is not null;

  with recursive fwd as (
    select input_lot, output_lot, batch_code, ts, 1 as depth from v_trace_links where farm_id=p_farm and input_lot=p_lot
    union
    select t.input_lot, t.output_lot, t.batch_code, t.ts, f.depth+1 from v_trace_links t join fwd f on t.input_lot=f.output_lot where f.depth<10
  )
  select array_agg(distinct output_lot) into v_descendants from fwd where output_lot is not null;

  v_all := array_remove(array_cat(array_cat(coalesce(v_ancestors,'{}'), coalesce(v_descendants,'{}')), array[p_lot]), null);

  return jsonb_build_object(
    'lot', p_lot,
    'ancestors', to_jsonb(coalesce(v_ancestors,'{}'::text[])),
    'descendants', to_jsonb(coalesce(v_descendants,'{}'::text[])),
    'batches', (select coalesce(jsonb_agg(distinct jsonb_build_object('batch_code', x.batch_code, 'input_lot', x.input_lot, 'output_lot', x.output_lot, 'ts', x.ts)), '[]'::jsonb)
                from (select input_lot, output_lot, batch_code, ts from v_trace_links where farm_id=p_farm and (output_lot=any(v_all) or input_lot=any(v_all))) x),
    'origins_harvest', (select coalesce(jsonb_agg(jsonb_build_object('lot_id',dest_lot_id,'plot_id',plot_id,'crop',crop,'variety',variety,'ts',ts,'phi_ok',phi_ok,'harvest_lot',harvest_lot)), '[]'::jsonb)
                from harvests where farm_id=p_farm and dest_lot_id=any(v_all) and status='ACTIVE'),
    'origins_purchase', (select coalesce(jsonb_agg(jsonb_build_object('lot_id',lot_id,'ts',ts,'from',from_to,'qty',qty,'unit',unit)), '[]'::jsonb)
                from inventory_moves where farm_id=p_farm and lot_id=any(v_all) and reason='NHAP_MUA' and status='ACTIVE'),
    'exits_sale', (select coalesce(jsonb_agg(jsonb_build_object('lot_id',s.lot_id,'ts',s.ts,'qty',s.qty,'unit',s.unit,'partner',p.name,'channel',s.channel)), '[]'::jsonb)
                from sales s left join partners p on p.id=s.partner_id where s.farm_id=p_farm and s.lot_id=any(v_all) and s.status='ACTIVE'),
    'exits_feeding', (select coalesce(jsonb_agg(jsonb_build_object('lot_id',lot_id,'ts',ts,'dest',from_to,'qty',qty,'unit',unit)), '[]'::jsonb)
                from inventory_moves where farm_id=p_farm and lot_id=any(v_all) and reason='XUAT_CHO_AN' and status='ACTIVE')
  );
end $$;
grant execute on function trace_full_chain(text,text) to app_user;
