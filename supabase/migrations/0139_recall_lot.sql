-- 0139 — Thu hồi lô (recall): sự cố nghiêm trọng → dừng bán + truy khách đã mua + sinh việc
--
-- Bối cảnh: hệ có qc_hold (giữ lô GIU_QC → chặn bán) nhưng CHƯA có "thu hồi" đúng nghĩa:
-- đặt lô THU_HOI + TRUY DANH SÁCH KHÁCH đã nhận lô (recall downstream) + sinh việc liên hệ.
-- sales.lot_id có sẵn (2638 đơn) nên truy được khách theo lô. QR trace (/api/public/trace)
-- đã trả lot.status nên người quét lô THU_HOI sẽ thấy.
--
-- Thêm: bảng recalls (nhật ký thu hồi), view khách bị ảnh hưởng, hàm recall_lot + action.

create table if not exists recalls(
  id             uuid primary key default gen_random_uuid(),
  farm_id        text not null,
  lot_id         text not null references lots(id),
  reason         text not null,
  severity       text not null default 'NANG',
  recalled_by    text,
  recalled_at    timestamptz not null default now(),
  affected_sales int not null default 0,
  affected_customers int not null default 0,
  affected_qty   numeric not null default 0,
  status         text not null default 'DANG_XU_LY'  -- DANG_XU_LY | HOAN_TAT
);
create index if not exists ix_recalls_lot on recalls(lot_id);

-- RLS (luật 1): bảng nghiệp vụ có farm_id phải bật RLS + policy theo trại.
alter table recalls enable row level security; drop policy if exists p_all on recalls;
create policy p_all on recalls for all using (can_see_farm(farm_id)) with check (true);
grant select, insert, update on recalls to app_user;  -- update: status DANG_XU_LY→HOAN_TAT (không append-only)

-- Khách đã nhận lô (truy downstream để liên hệ thu hồi)
create or replace view v_lot_recall_customers as
select s.farm_id, s.lot_id, s.partner_id, pt.name as customer, count(*) as n_sale,
       sum(s.qty) as qty, min(s.ts) as first_sold, max(s.ts) as last_sold
  from sales s left join partners pt on pt.id = s.partner_id
 where s.lot_id is not null and s.status = 'ACTIVE'
 group by s.farm_id, s.lot_id, s.partner_id, pt.name;

create or replace function recall_lot(p_farm text, p_lot text, p_reason text, p_by text, p_sev text default 'NANG')
returns uuid language plpgsql as $fn$
declare v_id uuid; v_sales int; v_cust int; v_qty numeric;
begin
  if not exists(select 1 from lots where id = p_lot and farm_id = p_farm) then
    raise exception 'ERR_LOT_NOT_FOUND: không thấy lô %', p_lot;
  end if;

  -- dừng bán ngay
  update lots set status = 'THU_HOI' where id = p_lot and farm_id = p_farm;

  -- truy phạm vi đã bán
  select count(*), count(distinct partner_id), coalesce(sum(qty),0)
    into v_sales, v_cust, v_qty
    from sales where lot_id = p_lot and farm_id = p_farm and status = 'ACTIVE';

  insert into recalls(farm_id, lot_id, reason, severity, recalled_by, affected_sales, affected_customers, affected_qty)
  values (p_farm, p_lot, p_reason, coalesce(p_sev,'NANG'), p_by, v_sales, v_cust, v_qty)
  returning id into v_id;

  -- sinh việc thu hồi cho phụ trách chất lượng
  insert into tasks(farm_id, kind, title, detail, target_type, target_id, role_hint, due_at, priority, source, ref_table, ref_id)
  values (p_farm, 'RECALL',
          'THU HỒI lô '||p_lot||' — liên hệ '||v_cust||' khách',
          jsonb_build_object('reason', p_reason, 'affected_sales', v_sales,
                             'affected_customers', v_cust, 'affected_qty', v_qty,
                             'note', 'Liên hệ từng khách thu hồi/đổi trả; ghi kết quả; đóng recall khi xong'),
          'LOT', p_lot, 'tech_head', now() + interval '1 day', 'CAO', 'recall', 'recalls', v_id::text);

  return v_id;
end $fn$;
