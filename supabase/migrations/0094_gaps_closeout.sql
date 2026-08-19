-- 0094 · Đóng tồn: (A) bản đồ hồ sơ chuẩn cho mỗi form ghi · (B) định biên ↔ quỹ lương S&OP · (C) HOLD lô QC · (D) trả nhà cung cấp · (E) lãi gộp theo đơn · (F) sao kê ngân hàng + đối chiếu · (G) ký SOP + video

-- ================= A. BẢN ĐỒ HỒ SƠ CHUẨN (records_catalog.tables → form/table) =================
create or replace view v_record_for_table as
 select unnest(tables) as table_name, code, name, legal_basis, required_for from records_catalog;
grant select on v_record_for_table to app_user;

-- ================= B. ĐỊNH BIÊN ↔ QUỸ LƯƠNG TRONG KẾ HOẠCH NĂM (S&OP) =================
-- Ghi 1 dòng "LAO_DONG" (quỹ lương L1 theo định biên) vào plan_monthly cho 12 tháng của năm kế hoạch
create or replace function sync_labor_budget(p_farm text, p_year int, p_by text default null) returns int language plpgsql as $$
declare py record; monthly numeric; m int; n int := 0; v_ver int;
begin
  select * into py from plan_years where farm_id=p_farm and year=p_year order by version desc limit 1;
  if py is null then raise exception 'ERR_NO_PLAN_YEAR: chưa có kế hoạch năm % cho %', p_year, p_farm; end if;
  v_ver := py.version;
  -- quỹ lương tháng = tổng định biên × lương L1 (ưu tiên budget_month khai tay, else từ pay_base thực tế)
  select coalesce(sum(coalesce(h.budget_month, h.planned * nullif((select avg((pay_base(p_farm, s.id)->>'base')::numeric) from staff s where s.farm_id=p_farm and s.active and s.dept=h.dept and (h.position_code is null or s.position_code=h.position_code)), 0))), 0)
    into monthly from headcount_plans h where h.farm_id=p_farm and h.year=p_year;
  if monthly = 0 then
    -- chưa có định biên → suy từ quỹ lương thực tế tháng gần nhất
    select coalesce(sum((pay_base(p_farm, id)->>'base')::numeric),0) into monthly from staff where farm_id=p_farm and active;
  end if;
  delete from plan_monthly where farm_id=p_farm and plan_year_id=py.id and version=v_ver and line='LAO_DONG';
  for m in 1..12 loop
    insert into plan_monthly(farm_id, plan_year_id, version, month, line, value, unit, detail)
      values (p_farm, py.id, v_ver, make_date(p_year, m, 1), 'LAO_DONG', monthly, 'đ/tháng', jsonb_build_object('source','headcount×pay_base','by',p_by));
    n := n + 1;
  end loop;
  return n;
end $$;
grant execute on function sync_labor_budget(text,int,text) to app_user;
-- So quỹ lương kế hoạch (plan_monthly LAO_DONG) vs thực chi lương (payslips.gross + employer_ins) theo tháng
create or replace view v_labor_budget_vs_actual as
 with pm as (select pmn.farm_id, pmn.month, sum(pmn.value) as budget from plan_monthly pmn where pmn.line='LAO_DONG' group by 1,2),
 ac as (select ps.farm_id, ps.month, sum(ps.gross + coalesce(ps.employer_ins,0)) as actual, count(*) as headcount from payslips ps group by 1,2)
 select coalesce(pm.farm_id, ac.farm_id) as farm_id, coalesce(pm.month, ac.month) as month, coalesce(pm.budget,0) as budget, coalesce(ac.actual,0) as actual,
   coalesce(ac.actual,0) - coalesce(pm.budget,0) as variance, ac.headcount
 from pm full join ac on ac.farm_id=pm.farm_id and ac.month=pm.month;
grant select on v_labor_budget_vs_actual to app_user;

-- ================= C. HOLD LÔ QC (giữ lô không đạt, chặn xuất bán) =================
alter table lots drop constraint if exists lots_status_check;
alter table lots add constraint lots_status_check check (status in ('KHA_DUNG','CO_LAP','GIU_QC','THU_HOI','HET'));
create table if not exists qc_holds(
  id uuid primary key default gen_random_uuid(), farm_id text not null, ref_type text not null default 'LOT' check (ref_type in ('LOT','BATCH')), lot_id text, batch_code text,
  reason text not null, severity text default 'TRUNG' check (severity in ('NHE','TRUNG','NANG')), status text not null default 'GIU' check (status in ('GIU','GIAI_TOA','HUY_BO')),
  held_by text, held_at timestamptz default now(), released_by text, released_at timestamptz, disposition text, note text
);
alter table qc_holds enable row level security; drop policy if exists p_all on qc_holds; create policy p_all on qc_holds for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on qc_holds to app_user;
create or replace function qc_hold(p_farm text, p_ref_type text, p_ref text, p_reason text, p_sev text, p_by text) returns uuid language plpgsql as $$
declare i uuid; begin
  insert into qc_holds(farm_id, ref_type, lot_id, batch_code, reason, severity, held_by) values (p_farm, p_ref_type, case when p_ref_type='LOT' then p_ref end, case when p_ref_type='BATCH' then p_ref end, p_reason, coalesce(p_sev,'TRUNG'), p_by) returning id into i;
  if p_ref_type='LOT' then update lots set status='GIU_QC' where id=p_ref and farm_id=p_farm and status in ('KHA_DUNG','CO_LAP'); end if;
  insert into tasks(farm_id,kind,title,detail,target_type,target_id,role_hint,due_at,priority,source,ref_table,ref_id)
    values (p_farm,'QC_HOLD','Xử lý lô GIỮ QC: '||p_ref||' — '||left(p_reason,60), jsonb_build_object('note','Điều tra nguyên nhân, quyết định: giải tỏa / hủy / hạ cấp; không được xuất bán khi còn GIỮ'), p_ref_type, p_ref, 'tech_head', now()+interval '2 days','CAO','QC','qc_holds',i::text);
  perform publish_event(p_farm,'qc.hold',jsonb_build_object('id',i,'ref',p_ref,'type',p_ref_type,'severity',p_sev));
  return i;
end $$;
create or replace function qc_release(p_id uuid, p_by text, p_disposition text, p_status text default 'GIAI_TOA') returns void language plpgsql as $$
declare h record; begin
  select * into h from qc_holds where id=p_id; if h is null then raise exception 'ERR_NOT_FOUND'; end if;
  if h.held_by = p_by then raise exception 'ERR_SELF_APPROVE: người giữ lô không tự giải tỏa'; end if;
  update qc_holds set status=p_status, released_by=p_by, released_at=now(), disposition=p_disposition where id=p_id;
  if h.ref_type='LOT' then
    if p_status='GIAI_TOA' then update lots set status='KHA_DUNG' where id=h.lot_id and status='GIU_QC';
    else update lots set status='THU_HOI' where id=h.lot_id and status='GIU_QC'; end if;
  end if;
  update tasks set status='XONG', done_by=p_by, done_at=now() where farm_id=h.farm_id and ref_table='qc_holds' and ref_id=p_id::text and status<>'XONG';
end $$;
grant execute on function qc_hold(text,text,text,text,text,text), qc_release(uuid,text,text,text) to app_user;
-- Chặn xuất bán lô đang GIỮ QC / thu hồi
create or replace function trg_sales_qc_hold() returns trigger language plpgsql as $$
declare st text; begin
  if new.lot_id is not null and coalesce(new.detail->>'override_by','')='' then
    select status into st from lots where id=new.lot_id and farm_id=new.farm_id;
    if st in ('GIU_QC','THU_HOI') then raise exception 'ERR_LOT_HELD: lô % đang % — không được xuất bán', new.lot_id, st; end if;
  end if;
  return new; end $$;
drop trigger if exists sales_qc_hold on sales; create trigger sales_qc_hold before insert on sales for each row execute function trg_sales_qc_hold();

-- ================= D. TRẢ HÀNG NHÀ CUNG CẤP (supplier return / debit note) =================
create table if not exists supplier_returns(
  id text primary key, farm_id text not null, po_id text, supplier_id text, ts timestamptz default now(), sku text, lot_id text, qty numeric not null, unit_cost numeric,
  amount numeric, reason text, disposition text default 'TRA_LAI' check (disposition in ('TRA_LAI','DOI_HANG','GIAM_TRU')), status text not null default 'CHO' check (status in ('CHO','DUYET','TU_CHOI')),
  debit_note_no text, warehouse_id text, created_by text, approved_by text, note text, created_at timestamptz default now()
);
alter table supplier_returns enable row level security; drop policy if exists p_all on supplier_returns; create policy p_all on supplier_returns for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on supplier_returns to app_user;
create or replace function approve_supplier_return(p_id text, p_by text) returns void language plpgsql as $$
declare r record; wh text; begin
  select * into r from supplier_returns where id=p_id; if r is null then raise exception 'ERR_NOT_FOUND'; end if;
  if r.created_by = p_by then raise exception 'ERR_SELF_APPROVE'; end if;
  if r.status<>'CHO' then raise exception 'ERR_STATUS'; end if;
  -- xuất kho trả NCC (direction -1)
  if r.sku is not null and r.qty > 0 then
    wh := coalesce(r.warehouse_id, (select id from warehouses where farm_id=r.farm_id and code in ('K1','K2') order by code limit 1));
    insert into inventory_moves(farm_id,created_by,source,warehouse_id,sku,lot_id,direction,qty,unit_cost,reason,ref_type,ref_id,client_ref)
      values (r.farm_id,p_by,'APP',wh,r.sku,r.lot_id,-1,r.qty,r.unit_cost,'TRA_NCC','supplier_returns',p_id,'sret-'||p_id);
  end if;
  -- GL: Dr 331 (giảm phải trả NCC) / Cr 156 (giảm tồn) — trừ công nợ nhà cung cấp
  perform gl_post(r.farm_id,'supplier_returns',p_id,'Trả NCC '||coalesce(r.sku,''),
    jsonb_build_array(jsonb_build_object('acct','331','debit',coalesce(r.amount,0),'credit',0), jsonb_build_object('acct','156','debit',0,'credit',coalesce(r.amount,0))), now(), p_by);
  update supplier_returns set status='DUYET', approved_by=p_by, debit_note_no=coalesce(debit_note_no,'DN-'||to_char(now(),'YYMMDD')||'-'||right(p_id,4)) where id=p_id;
  -- giảm dư nợ phải trả trên PO (nếu có)
  if r.po_id is not null then update purchase_orders set paid_amount=coalesce(paid_amount,0) + coalesce(r.amount,0) where id=r.po_id; end if;
  perform publish_event(r.farm_id,'supplier_return.approved',jsonb_build_object('id',p_id,'supplier',r.supplier_id,'amount',r.amount));
end $$;
grant execute on function approve_supplier_return(text,text) to app_user;

-- ================= E. LÃI GỘP THEO ĐƠN (COGS từ giá vốn lô / mẻ) =================
-- Giá vốn 1 dòng bán = qty × (lots.avg_cost nếu có, else v_batch_cost.unit_cost cho SKU mẻ, else products.std_cost/last_cost)
alter table products add column if not exists last_cost numeric;
create or replace view v_sale_margin as
 with c as (select s.*, coalesce(l.avg_cost, (select last_cost from products p where p.sku=s.sku), (select avg(unit_cost) from inventory_moves im where im.sku=s.sku and im.direction=1 and im.unit_cost>0), 0) as unit_cost
   from sales s left join lots l on l.id=s.lot_id where s.status is null or s.status not in ('VOID','SUPERSEDED'))
 select c.farm_id, c.id as sale_id, c.order_id::text as order_id, c.ts, c.sku, c.lot_id, c.qty, c.price, c.amount as revenue, c.partner_id, c.channel_code, c.campaign_id,
   c.unit_cost, round(c.qty * c.unit_cost) as cogs, c.amount - round(c.qty * c.unit_cost) as gross_margin
 from c;
grant select on v_sale_margin to app_user;
create or replace view v_order_margin as
 select farm_id, coalesce(order_id, sale_id::text) as order_key, order_id, min(ts) as ts, max(partner_id) as partner_id, max(channel_code) as channel_code,
   sum(revenue) as revenue, sum(cogs) as cogs, sum(gross_margin) as gross_margin,
   case when sum(revenue) > 0 then round(100.0*sum(gross_margin)/sum(revenue),1) else null end as margin_pct
 from v_sale_margin group by 1, 2, 3;
grant select on v_order_margin to app_user;

-- ================= F. SAO KÊ NGÂN HÀNG + ĐỐI CHIẾU =================
-- bank_statement_lines đã có (0058). Thêm: matched_expense_id + auto-match + view đối chiếu
alter table bank_statement_lines add column if not exists matched_expense_id text, add column if not exists matched_kind text, add column if not exists reconciled boolean default false, add column if not exists reconciled_by text;
create or replace function import_bank_line(p_farm text, p_bank text, p_account text, p_date date, p_amount numeric, p_direction text, p_ref text, p_memo text, p_batch text, p_by text) returns uuid language plpgsql as $$
declare i uuid; begin
  -- idempotent theo (account, date, amount, ref)
  select id into i from bank_statement_lines where farm_id=p_farm and account=p_account and txn_date=p_date and amount=p_amount and coalesce(ref,'')=coalesce(p_ref,'');
  if i is not null then return i; end if;
  insert into bank_statement_lines(farm_id, bank, account, txn_date, amount, direction, ref, memo, import_batch, imported_by)
    values (p_farm, p_bank, p_account, p_date, p_amount, p_direction, p_ref, p_memo, p_batch, p_by) returning id into i;
  return i;
end $$;
-- Tự khớp: tiền VÀO ↔ bán thu tiền (amount, ±3 ngày); tiền RA ↔ đề nghị chi đã duyệt (amount)
create or replace function auto_match_bank(p_farm text) returns int language plpgsql as $$
declare n int := 0; b record; sid uuid; eid text; begin
  for b in select * from bank_statement_lines where farm_id=p_farm and not reconciled and matched_sale_id is null and matched_expense_id is null loop
    if b.direction='IN' or b.amount > 0 then
      select id into sid from sales s where s.farm_id=p_farm and s.paid and s.amount = abs(b.amount) and abs(s.ts::date - b.txn_date) <= 3
        and not exists (select 1 from bank_statement_lines x where x.matched_sale_id=s.id) order by abs(s.ts::date - b.txn_date) limit 1;
      if sid is not null then update bank_statement_lines set matched_sale_id=sid, matched_kind='SALE' where id=b.id; n := n+1; continue; end if;
    end if;
    if b.direction='OUT' or b.amount < 0 then
      select id into eid from expense_requests e where e.farm_id=p_farm and e.status='DUYET' and e.amount = abs(b.amount) and (e.paid_at is null or abs(e.paid_at::date - b.txn_date) <= 5)
        and not exists (select 1 from bank_statement_lines x where x.matched_expense_id=e.id) order by e.ts limit 1;
      if eid is not null then update bank_statement_lines set matched_expense_id=eid, matched_kind='EXPENSE' where id=b.id; n := n+1; continue; end if;
    end if;
  end loop;
  return n;
end $$;
grant execute on function import_bank_line(text,text,text,date,numeric,text,text,text,text,text), auto_match_bank(text) to app_user;
create or replace view v_bank_reconciliation as
 select b.farm_id, b.id, b.txn_date, b.bank, b.account, b.amount, b.direction, b.ref, b.memo, b.reconciled,
   b.matched_kind, coalesce(b.matched_sale_id::text, b.matched_expense_id) as matched_ref,
   (b.matched_sale_id is not null or b.matched_expense_id is not null) as matched
 from bank_statement_lines b;
grant select on v_bank_reconciliation to app_user;

-- ================= G. KÝ BAN HÀNH SOP + ĐỌC HIỂU + VIDEO =================
create table if not exists sop_acknowledgments(
  id uuid primary key default gen_random_uuid(), farm_id text, org_id text default 'ITRAN', sop_code text not null, sop_version int not null, staff_id text not null,
  kind text not null default 'DOC_HIEU' check (kind in ('BAN_HANH','DOC_HIEU','XEM_VIDEO')), acknowledged_at timestamptz default now(), score numeric, note text,
  unique (sop_code, sop_version, staff_id, kind)
);
alter table sop_acknowledgments enable row level security; drop policy if exists p_all on sop_acknowledgments; create policy p_all on sop_acknowledgments for all using (farm_id is null or can_see_farm(farm_id)) with check (true); grant select, insert on sop_acknowledgments to app_user;
create or replace function ack_sop(p_farm text, p_sop text, p_staff text, p_kind text, p_score numeric default null) returns void language plpgsql as $$
declare v int; begin
  select version into v from sops where code=p_sop;
  insert into sop_acknowledgments(farm_id, sop_code, sop_version, staff_id, kind, score) values (p_farm, p_sop, coalesce(v,1), p_staff, p_kind, p_score)
    on conflict (sop_code, sop_version, staff_id, kind) do update set acknowledged_at=now(), score=coalesce(excluded.score, sop_acknowledgments.score);
end $$;
grant execute on function ack_sop(text,text,text,text,numeric) to app_user;
-- Ai đã ký/đọc hiểu SOP nào (theo phòng chủ quản); % ký của SOP đã ban hành
create or replace view v_sop_signoff as
 select s.code, s.title, s.dept, s.version, s.owner_role, s.video_url, s.published_at,
   (select count(*) from staff st where st.active and (st.dept = s.dept or s.dept is null)) as need,
   (select count(distinct a.staff_id) from sop_acknowledgments a where a.sop_code=s.code and a.sop_version=s.version and a.kind='DOC_HIEU') as signed
 from sops s where s.status='BAN_HANH' and s.l3_no is null;
grant select on v_sop_signoff to app_user;
