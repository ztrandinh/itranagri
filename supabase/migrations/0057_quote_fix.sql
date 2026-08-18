-- 0057 · quote_to_order: orders.channel là số kênh (1=B2B)
create or replace function quote_to_order(p_quote text) returns text language plpgsql as $$
declare q record; v_id text; begin
  select * into q from quotes where id=p_quote; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  if q.status not in ('GUI','CHAP_NHAN','NHAP') then raise exception 'ERR_QUOTE_STATUS'; end if;
  v_id := next_code_free(q.farm_id, 'DH', 'orders');
  insert into orders(id, farm_id, partner_id, channel, order_date, deliver_date, lines, total, status, created_by, note, attrs)
  values (v_id, q.farm_id, q.partner_id, 1, current_date, coalesce(q.valid_until, current_date+3), q.lines, q.total, 'NHAP', app_staff(), 'Từ báo giá '||q.id, jsonb_build_object('quote_id', q.id));
  update quotes set status='THANH_DON', order_id=v_id, accepted_at=coalesce(accepted_at, now()) where id=p_quote;
  return v_id; end $$;
