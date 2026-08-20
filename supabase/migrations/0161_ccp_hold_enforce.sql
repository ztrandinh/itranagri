-- 0161 — T2.1 CCP ENGINE: điểm kiểm soát tới hạn vượt ngưỡng trong mẻ D5/chế biến
--         → tự GIỮ QC lô đầu ra (chặn bán) + sinh việc QA. + view giám sát.
--
-- Bối cảnh (audit §T2.1): sops có ccp/ccp_limit/ccp_action + batch_logs.ccp_readings, NHƯNG
-- không nơi nào so ngưỡng → "vượt ngưỡng dừng chuyền" mới là khai báo suông.
--
-- NGUYÊN TẮC AN TOÀN (theo phối hợp với điều phối — tránh phá DB dùng chung):
--   * KHÔNG hard-guard chặn ghi trên bảng sự kiện traffic cao (seed-history/phiên khác chèn liên tục).
--   * AFTER INSERT, SKIP source='IMPORT'/is_backfill, KHÔNG raise — chỉ TREO LÔ đầu ra
--     (chặn ở khâu BÁN qua trg_sales_qc_hold 0094). Ghi không bao giờ bị chặn → không phá rebuild.
--   * Trigger tên 'zz_' để chạy SAU batch_logs_stockmove (lô đầu ra đã được tạo mới treo được).
-- Phát hiện vượt: phần tử ccp_readings có ok=false, HOẶC value>limit (chỉ khi cả 2 là số — tránh cast lỗi).

create or replace function itran_ccp_hold_enforce()
returns trigger language plpgsql as $fn$
declare v_bad text; v_lot text; v_n int := 0;
begin
  if new.source = 'IMPORT' or new.is_backfill then return new; end if;
  if new.ccp_readings is null or new.ccp_readings = '[]'::jsonb then return new; end if;

  -- gom các CCP vượt ngưỡng (null = không vượt)
  select string_agg(distinct coalesce(e->>'ccp','?'), ', ')
    into v_bad
  from jsonb_array_elements(new.ccp_readings) e
  where (e->>'ok')::boolean is false
     or (jsonb_typeof(e->'value')='number' and jsonb_typeof(e->'limit')='number'
         and (e->>'value')::numeric > (e->>'limit')::numeric);

  if v_bad is null then return new; end if;

  -- treo mọi lô đầu ra của mẻ (lô do batch_logs_stockmove tạo trước đó trong cùng câu lệnh)
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

  -- sinh việc QA (kể cả khi mẻ chưa nhập kho / chưa có lô)
  insert into tasks(farm_id, kind, title, detail, target_type, target_id,
                    role_hint, due_at, priority, source, ref_table, ref_id)
  values (new.farm_id, 'CCP_FAIL',
          'CCP vượt ngưỡng mẻ '||coalesce(new.batch_code,new.id::text)||': '||v_bad,
          jsonb_build_object('batch', new.batch_code, 'ccp_bad', v_bad, 'lots_held', v_n,
            'note','Mẻ vượt điểm kiểm soát tới hạn; lô đầu ra đã GIỮ QC (nếu có); điều tra 5-why + xử lý lô'),
          'BATCH', coalesce(new.batch_code, new.id::text),
          'tech_head', now()+interval '1 day', 'CAO', 'ccp', 'batch_logs', new.id::text);

  return new;
end $fn$;

drop trigger if exists zz_ccp_hold_batch on batch_logs;
create trigger zz_ccp_hold_batch
  after insert on batch_logs
  for each row execute function itran_ccp_hold_enforce();

-- read-side: giám sát mẻ vượt CCP (dashboard/cảnh báo — không chặn gì)
create or replace view v_ccp_breach as
select b.farm_id, b.batch_code, b.line, b.ts,
       string_agg(distinct coalesce(e->>'ccp','?'), ', ') as ccp_bad
  from batch_logs b, jsonb_array_elements(b.ccp_readings) e
 where b.status = 'ACTIVE'
   and ((e->>'ok')::boolean is false
        or (jsonb_typeof(e->'value')='number' and jsonb_typeof(e->'limit')='number'
            and (e->>'value')::numeric > (e->>'limit')::numeric))
 group by b.farm_id, b.batch_code, b.line, b.ts;
