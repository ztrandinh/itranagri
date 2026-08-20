-- 0160 — T2.4: CƯỠNG CHẾ kết quả lab KHÔNG ĐẠT → tự GIỮ QC lô (chặn bán) + sinh việc QA
--
-- Bối cảnh (audit AUDIT-CHUAN-THE-GIOI §T2.4): lab_samples đã có `verdict` ('DAT'/'KHONG_DAT')
-- + `subject_ref`, NHƯNG thuần ghi chép — không nơi nào chặn dùng lô khi FAIL.
-- Hệ ĐÃ có qc_hold()/trg_sales_qc_hold (0094–0095) chặn bán lô GIU_QC. Migration này NỐI 2 cái:
-- lab KHÔNG ĐẠT trên 1 LÔ → tự qc_hold lô đó (tái dùng cơ chế chặn có sẵn) + sinh việc QA
-- (pattern task như 0139 recall). KHÔNG đẻ bảng mới, KHÔNG chạm incidents (có BI guard riêng).

create or replace function itran_lab_result_enforce()
returns trigger language plpgsql as $fn$
declare v_lot text; v_held int;
begin
  -- chỉ xử khi kết quả KHÔNG ĐẠT
  if new.verdict is distinct from 'KHONG_DAT' then return new; end if;
  -- trên UPDATE: chỉ khi verdict VỪA CHUYỂN sang KHONG_DAT (tránh chạy lại các update khác)
  if tg_op = 'UPDATE' and old.verdict is not distinct from new.verdict then return new; end if;

  -- subject_ref có trỏ tới 1 LÔ thật của trại không?
  select id into v_lot from lots where id = new.subject_ref and farm_id = new.farm_id;

  if v_lot is not null then
    -- idempotent: chỉ giữ nếu chưa có lệnh giữ đang hiệu lực
    select count(*) into v_held from qc_holds
      where farm_id = new.farm_id and lot_id = v_lot and status = 'GIU';
    if v_held = 0 then
      perform qc_hold(new.farm_id, 'LOT', v_lot,
                      'Lab KHÔNG ĐẠT: ' || coalesce(new.kind,'?') || ' — mẫu ' || new.code,
                      'NANG', coalesce(new.taken_by,'system'));
    end if;
  end if;

  -- luôn sinh việc QA (kể cả mẫu không gắn lô: nước/đất/xả thải) — audit trail + điều tra 5-why
  insert into tasks(farm_id, kind, title, detail, target_type, target_id,
                    role_hint, due_at, priority, source, ref_table, ref_id)
  values (new.farm_id, 'LAB_FAIL',
          'Lab KHÔNG ĐẠT: ' || coalesce(new.kind,'?') || ' — mẫu ' || new.code,
          jsonb_build_object('sample', new.code, 'kind', new.kind, 'verdict', new.verdict,
                             'lot', v_lot,
                             'note', 'Lô gắn mẫu đã GIỮ QC (nếu có); điều tra 5-why; quyết định loại/tái chế/giải toả'),
          case when v_lot is not null then 'LOT' else 'LAB' end,
          coalesce(v_lot, new.id),
          'tech_head', now() + interval '1 day', 'CAO', 'lab', 'lab_samples', new.id);

  return new;
end $fn$;

drop trigger if exists trg_lab_result_enforce on lab_samples;
create trigger trg_lab_result_enforce
  after insert or update of verdict on lab_samples
  for each row execute function itran_lab_result_enforce();
