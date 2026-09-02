-- 0204 · gl_post(): chặn NGAY LÚC GHI kiểu lỗi "sai tên khóa jsonb" đã từng xảy ra thật ('acct' vs
-- 'account') trên journal_entries.lines — thay vì redesign toàn bộ sang bảng dòng riêng (rủi ro cao,
-- đổi schema tài chính, để sau — xem mục "Sổ cái GL lưu jsonb" TRUNG BÌNH). gl_post() là CHOKEPOINT
-- DUY NHẤT mọi dòng bút toán đi qua (mọi trigger tự động lẫn ghi tay đều gọi hàm này) — validate ở
-- đây chặn được toàn bộ nguồn ghi, không cần sửa từng nơi gọi.
--
-- Trước đây chỉ kiểm tổng nợ=có (ERR_GL_UNBALANCED) — không phát hiện khóa sai tên (vd 'account' thay
-- 'acct'): debit/credit vẫn cộng đúng nên vẫn cân, nhưng acct=NULL khiến dòng đó "vô hình" trong
-- v_trial_balance/v_gl_ledger (LEFT JOIN gl_accounts on a.code=l->>'acct' không khớp) — sổ cái lệch âm
-- thầm, không lỗi ở đâu cả.
create or replace function gl_post(p_farm text, p_ref_table text, p_ref_id text, p_memo text, p_lines jsonb, p_ts timestamptz default now(), p_by text default null) returns uuid language plpgsql security definer as $$
declare d numeric := 0; c numeric := 0; i uuid; v_line jsonb; begin
  if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'ERR_GL_INVALID_LINE: lines phải là mảng jsonb khác rỗng';
  end if;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    if not (v_line ? 'acct') or v_line->>'acct' is null or v_line->>'acct' = '' then
      raise exception 'ERR_GL_INVALID_LINE: thiếu/rỗng khóa "acct" (dòng %)', v_line;
    end if;
    if not exists (select 1 from gl_accounts where code = v_line->>'acct') then
      raise exception 'ERR_GL_INVALID_LINE: mã tài khoản "%" không tồn tại trong gl_accounts', v_line->>'acct';
    end if;
    if not (v_line ? 'debit') or not (v_line ? 'credit') then
      raise exception 'ERR_GL_INVALID_LINE: thiếu khóa "debit"/"credit" (dòng %)', v_line;
    end if;
    if (v_line->>'debit')::numeric < 0 or (v_line->>'credit')::numeric < 0 then
      raise exception 'ERR_GL_INVALID_LINE: debit/credit âm (dòng %)', v_line;
    end if;
    -- chặn khóa lạ (vd 'account' gõ nhầm từ 'acct') — chỉ cho phép đúng 4 khóa đã biết
    if (v_line - array['acct','debit','credit','cc']) <> '{}'::jsonb then
      raise exception 'ERR_GL_INVALID_LINE: có khóa lạ ngoài acct/debit/credit/cc (dòng %)', v_line;
    end if;
    d := d + (v_line->>'debit')::numeric; c := c + (v_line->>'credit')::numeric;
  end loop;
  if round(d,0) <> round(c,0) then raise exception 'ERR_GL_UNBALANCED: no % <> co %', d, c; end if;
  if exists (select 1 from journal_entries where ref_table=p_ref_table and ref_id=p_ref_id and reversed_of is null) then return null; end if;
  insert into journal_entries(farm_id,ts,period,ref_table,ref_id,memo,lines,total,posted_by) values (p_farm,p_ts,date_trunc('month',p_ts)::date,p_ref_table,p_ref_id,p_memo,p_lines,d,p_by) returning id into i; return i; end $$;
