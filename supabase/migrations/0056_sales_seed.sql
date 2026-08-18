-- 0056 · price_for: thiếu giá thị trường → lấy giá sàn ×1.1 làm giá niêm yết; seed giá niêm yết, nhóm khách, chỉ tiêu, lịch giao HĐ mẫu (F01)
create or replace function price_for(p_farm text, p_partner text, p_sku text, p_qty numeric default 1) returns table(price numeric, list_price numeric, discount_pct numeric, source text, floor_price numeric, below_floor bool) language plpgsql stable as $$
declare v_grp text; v_list numeric; v_floor numeric; v_price numeric; v_disc numeric := 0; v_src text := 'THI_TRUONG'; r record; begin
  select customer_group into v_grp from partners where id=p_partner;
  select pl.price into v_list from price_list pl where pl.kind='THI_TRUONG' and pl.subject=p_sku and (pl.farm_id=p_farm or pl.farm_id is null) and pl.valid_from<=current_date and (pl.valid_to is null or pl.valid_to>=current_date) order by (pl.farm_id=p_farm) desc, pl.valid_from desc limit 1;
  select pl.price into v_floor from price_list pl where pl.kind='SAN' and pl.subject=p_sku and (pl.farm_id=p_farm or pl.farm_id is null) order by (pl.farm_id=p_farm) desc, pl.valid_from desc limit 1;
  if v_list is null then v_list := round(coalesce(v_floor,0)*1.1); if v_list>0 then v_src := 'SAN_x1.1'; end if; end if;
  v_price := v_list;
  select * into r from customer_prices cp where cp.farm_id=p_farm and cp.sku=p_sku and cp.active and cp.valid_from<=current_date and (cp.valid_to is null or cp.valid_to>=current_date) and p_qty>=coalesce(cp.min_qty,0)
    and (cp.partner_id=p_partner or (cp.partner_id is null and cp.customer_group is not null and cp.customer_group=v_grp)) order by (cp.partner_id is not null) desc, cp.priority, cp.min_qty desc limit 1;
  if found then
    if r.price is not null then v_price := r.price; v_src := case when r.partner_id is not null then 'GIA_RIENG_KHACH' else 'GIA_NHOM' end;
    elsif r.discount_pct is not null then v_disc := r.discount_pct; v_src := case when r.partner_id is not null then 'CK_RIENG_KHACH' else 'CK_NHOM' end; end if;
  end if;
  if v_src in ('THI_TRUONG','SAN_x1.1','CK_RIENG_KHACH','CK_NHOM') then
    select greatest(v_disc, coalesce(max(dt.discount_pct),0)) into v_disc from discount_tiers dt where dt.farm_id=p_farm and dt.active and (dt.sku=p_sku or dt.sku is null) and (dt.customer_group is null or dt.customer_group=v_grp) and p_qty>=dt.min_qty and dt.valid_from<=current_date and (dt.valid_to is null or dt.valid_to>=current_date);
    if v_disc>0 and v_src in ('THI_TRUONG','SAN_x1.1') then v_src := 'BAC_SO_LUONG'; end if;
  end if;
  price := round(coalesce(v_price,0) * (1 - coalesce(v_disc,0)/100)); list_price := v_list; discount_pct := v_disc; source := v_src; floor_price := v_floor; below_floor := v_floor is not null and price < v_floor;
  return next; end $$;
insert into price_list(org_id, farm_id, sku, kind, subject, price, unit, valid_from, source) values
 ('ITRAN','F01','SKU-TMR-25','THI_TRUONG','SKU-TMR-25',110000,'bao',current_date-30,'Niêm yết'),
 ('ITRAN','F01','SKU-TRUNG-10','THI_TRUONG','SKU-TRUNG-10',45000,'vi',current_date-30,'Niêm yết'),
 ('ITRAN','F01','SKU-PTR-25','THI_TRUONG','SKU-PTR-25',85000,'bao',current_date-30,'Niêm yết');
update partners set customer_group='DAI_LY', payment_terms='NET15' where id='KH-0001' and customer_group is null;
insert into discount_tiers(id, farm_id, sku, customer_group, min_qty, discount_pct, note) values ('DT-2','F01',null,'DAI_LY',200,8,'Đại lý ≥200 đv') on conflict do nothing;
insert into sales_targets(id, farm_id, staff_id, period, target_amount, commission_pct) values ('ST-1','F01','NS-002',to_char(current_date,'YYYY-MM'),300000000,1.5) on conflict do nothing;
select gen_contract_deliveries('F01-HD-0001', 14);
