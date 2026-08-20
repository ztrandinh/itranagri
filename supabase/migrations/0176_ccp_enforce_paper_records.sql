-- 0176 — CCP hold (HACCP) không được bỏ qua cho bản ghi PHIẾU GIẤY (is_backfill=true, source=PAPER)
-- Trước: itran_ccp_hold_enforce skip cả 'IMPORT' LẪN is_backfill → mẻ CCP-fail số hoá từ phiếu giấy
--        (is_backfill=true) KHÔNG sinh việc/giữ lô → mất kiểm soát ATTP đối với hồ sơ giấy thật.
-- Sau: chỉ skip source='IMPORT' (nạp seed/import hàng loạt). Phiếu giấy (PAPER) sẽ bị CCP enforce.
-- An toàn seed: seed-history*.sql chạy session_replication_role=replica (trigger TẮT);
--   simulate.ts nổ trigger nhưng ccp_readings đều ok:true → không sinh hold thừa.
-- LƯU Ý: với mẻ is_backfill, itran_batch_stockmove vẫn skip (tránh đếm đôi kho) nên chưa tạo lô đầu ra
--   → CCP với mẻ giấy sinh VIỆC QA (điều tra) nhưng chưa auto-hold lô; vẫn hơn hiện trạng (im lặng).
-- Chỉ REPLACE hàm enforcement, KHÔNG đụng trigger side-effect kho (feed_stockout/batch_stockmove).

create or replace function public.itran_ccp_hold_enforce() returns trigger language plpgsql as $function$
declare v_bad text; v_lot text; v_n int := 0;
begin
  if new.source = 'IMPORT' then return new; end if;
  if new.ccp_readings is null or new.ccp_readings = '[]'::jsonb then return new; end if;

  select string_agg(distinct coalesce(e->>'ccp','?'), ', ')
    into v_bad
  from jsonb_array_elements(new.ccp_readings) e
  where (e->>'ok')::boolean is false
     or (jsonb_typeof(e->'value')='number' and jsonb_typeof(e->'limit')='number'
         and (e->>'value')::numeric > (e->>'limit')::numeric);

  if v_bad is null then return new; end if;

  for v_lot in
    select distinct im.lot_id from inventory_moves im
     where im.ref_type='batch_logs' and im.ref_id = new.id::text
       and im.reason='NHAP_SX' and im.lot_id is not null
  loop
    if not exists(select 1 from qc_holds where farm_id=new.farm_id and lot_id=v_lot and status='GIU') then
      perform qc_hold(new.farm_id, 'LOT', v_lot,
        'CCP vượt ngưỡng: '||v_bad||' — mẻ '||coalesce(new.batch_code, new.id::text),
        'NANG', coalesce(new.created_by,'system'));
      v_n := v_n + 1;
    end if;
  end loop;

  insert into tasks(farm_id, kind, title, detail, target_type, target_id,
                    role_hint, due_at, priority, source, ref_table, ref_id)
  values (new.farm_id, 'CCP_FAIL',
          'CCP vượt ngưỡng mẻ '||coalesce(new.batch_code,new.id::text)||': '||v_bad,
          jsonb_build_object('batch', new.batch_code, 'ccp_bad', v_bad, 'lots_held', v_n,
            'note','Mẻ vượt điểm kiểm soát tới hạn; lô đầu ra đã GIỮ QC (nếu có); điều tra 5-why + xử lý lô'),
          'BATCH', coalesce(new.batch_code, new.id::text),
          'tech_head', now()+interval '1 day', 'CAO', 'ccp', 'batch_logs', new.id::text);

  return new;
end $function$;
