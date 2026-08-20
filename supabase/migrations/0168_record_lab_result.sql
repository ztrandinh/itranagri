-- 0168 — record_lab_result: QA nhập kết quả lab → lab_samples(verdict) → T2.4 (0160) TỰ treo lô nếu FAIL
--
-- lab_samples MUTABLE (không phải bảng event append-only) → nhập qua ACTION (không qua /api/events).
-- Hàm sinh mã LAB, ghi 1 mẫu đã có kết quả (verdict + số đo + file ảnh phiếu lab) → trigger 0160 chạy.

create or replace function record_lab_result(
  p_farm text, p_by text, p_subject text, p_kind text, p_verdict text,
  p_value numeric default null, p_file text default null, p_note text default null
) returns text language plpgsql as $fn$
declare v_code text;
begin
  if p_verdict is null or p_verdict not in ('DAT','KHONG_DAT') then
    raise exception 'ERR_BAD_VERDICT: verdict phải DAT hoặc KHONG_DAT';
  end if;
  v_code := next_code(p_farm, 'LAB');
  insert into lab_samples(id, farm_id, code, kind, subject_ref, verdict, taken_by, taken_at, result_at, results, status)
  values (v_code, p_farm, v_code, coalesce(p_kind,'TA'), p_subject, p_verdict, p_by, now(), now(),
          jsonb_build_object('value', p_value, 'note', p_note, 'file', p_file), 'CO_KQ');
  return v_code;   -- KHONG_DAT trên 1 lô → trg_lab_result_enforce (0160) tự qc_hold + task
end $fn$;
grant insert on lab_samples to app_user;
grant execute on function record_lab_result(text,text,text,text,text,numeric,text,text) to app_user;
