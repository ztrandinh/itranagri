-- 0073 · chặn BÁN vật nuôi đang ngưng thuốc ngay tại sales (detail.animal_id / animal_ids) — bổ sung cho chặn ở animal_events XUAT (control C-WITHDRAWAL)
create or replace function trg_sales_withdrawal() returns trigger language plpgsql as $$
declare ids text[]; w record; begin
  ids := array_remove(array[new.detail->>'animal_id'], null);
  if jsonb_typeof(new.detail->'animal_ids')='array' then select ids || array_agg(x) into ids from jsonb_array_elements_text(new.detail->'animal_ids') x; end if;
  if coalesce(cardinality(ids),0)=0 then return new; end if;
  select id, withdrawal_until into w from animals where id = any(ids) and withdrawal_until is not null and withdrawal_until > new.ts::date and coalesce(new.detail->>'override_by','')='' limit 1;
  if w.id is not null then raise exception 'ERR_WITHDRAWAL_ACTIVE: % đang ngưng thuốc đến %', w.id, w.withdrawal_until; end if;
  return new; end $$;
drop trigger if exists sales_withdrawal on sales; create trigger sales_withdrawal before insert on sales for each row execute function trg_sales_withdrawal();
