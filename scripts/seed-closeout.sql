-- seed-closeout · Dữ liệu mẫu cho 8 tính năng đóng tồn (chạy trong db:seed:history, sau seed-marketing).
-- Idempotent: chọn row THẬT bằng subquery; guard trùng bằng marker. Rỗng dữ liệu (vd F99) → không chèn gì.
-- chạy bằng postgres (như orchestrator seed-history.ts) — không đổi role; đặt app.* cho hàm đọc context
select set_config('app.org','ITRAN',true), set_config('app.farm',:'farm',true), set_config('app.role','owner',true),
       set_config('app.staff', coalesce((select id from staff where farm_id=:'farm' and active order by id limit 1),'system'), true);

-- ===== (D) VIDEO SOP: gán link video LMS (placeholder nội bộ) cho vài L2 SOP để nút "▶ video" hiện =====
update sops set video_url = 'https://lms.itranfarm.vn/sop/'||l2_code||'.mp4'
where l2_code in ('SOP-BO-01','SOP-AT-02','SOP-GA-01','SOP-TT-01','SOP-SH-01') and video_url is null;
-- một số l2_code có thể không tồn tại ở mọi bản seed → update chỉ chạm dòng khớp, an toàn

-- ===== (C1) SAO KÊ NGÂN HÀNG: dòng tiền VÀO khớp đơn bán đã thu + tiền RA khớp đề nghị chi đã duyệt =====
delete from bank_statement_lines where farm_id=:'farm' and import_batch='SEED-CLOSEOUT';
insert into bank_statement_lines(farm_id, bank, account, txn_date, amount, direction, ref, memo, import_batch, imported_by)
select :'farm','VCB','0111000066668', s.ts::date, s.amount, 'IN', 'TT'||right(s.id::text,5), 'Thu tien ban hang', 'SEED-CLOSEOUT', 'system'
from (select id, ts, amount from sales where farm_id=:'farm' and paid and amount>0 order by ts desc limit 6) s;
insert into bank_statement_lines(farm_id, bank, account, txn_date, amount, direction, ref, memo, import_batch, imported_by)
select :'farm','VCB','0111000066668', coalesce(e.paid_at::date, e.ts::date), -e.amount, 'OUT', 'UNC'||right(e.id,4), 'Chi: '||left(coalesce(e.purpose,'thanh toan'),30), 'SEED-CLOSEOUT', 'system'
from (select id, ts, amount, purpose, paid_at from expense_requests where farm_id=:'farm' and status='DUYET' and amount>0 order by ts desc limit 3) e;
-- thêm 1 dòng KHÔNG khớp (để demo dòng "chưa khớp" tô vàng)
insert into bank_statement_lines(farm_id, bank, account, txn_date, amount, direction, ref, memo, import_batch, imported_by)
values (:'farm','VCB','0111000066668', current_date, 137000, 'IN', 'NOSTRO', 'Lai tien gui chua ro nguon', 'SEED-CLOSEOUT', 'system');
select auto_match_bank(:'farm');

-- ===== (C2) KÝ SOP: cho mỗi phòng, 2 nhân sự đầu ký đọc–hiểu SOP đầu của phòng (coverage bộ phận, còn amber) =====
insert into sop_acknowledgments(farm_id, sop_code, sop_version, staff_id, kind)
select :'farm', v.code, v.version, st.id, 'DOC_HIEU'
from (select distinct on (dept) code, version, dept from v_sop_signoff where dept is not null order by dept, code) v
join lateral (select id from staff where farm_id=:'farm' and active and dept=v.dept order by id limit 2) st on true
on conflict (sop_code, sop_version, staff_id, kind) do nothing;

-- ===== (C3) GIỮ LÔ QC: 1 lô đang giữ (demo chặn xuất bán) =====
do $$ declare v_lot text; begin
  if not exists (select 1 from qc_holds where farm_id=:'farm' and note='SEED-CLOSEOUT') then
    select id into v_lot from lots where farm_id=:'farm' and status='KHA_DUNG' order by created_at desc limit 1;
    if v_lot is not null then
      perform qc_hold(:'farm','LOT',v_lot,'Kiểm mẫu vi sinh vượt ngưỡng — chờ tái kiểm (demo)','TRUNG',
        coalesce((select id from staff where farm_id=:'farm' and dept in ('KTCN','SH') and active limit 1),'system'));
      update qc_holds set note='SEED-CLOSEOUT' where lot_id=v_lot and note is null;
    end if;
  end if;
end $$;

-- ===== (C4) TRẢ NCC: 1 phiếu chờ duyệt (demo Nợ 331/Có 156 khi duyệt) =====
insert into supplier_returns(id, farm_id, po_id, supplier_id, sku, qty, unit_cost, amount, reason, disposition, created_by, status)
select 'SR-SEED-'||:'farm', :'farm', po.id, po.supplier_id, po.sku, 10, po.price, 10*po.price,
       'Hàng ẩm mốc, không đạt COA đầu vào (demo)', 'TRA_LAI',
       coalesce((select id from staff where farm_id=:'farm' and dept='CCU' and active limit 1),'system'), 'CHO'
from (select id, supplier_id, (lines->0->>'sku') as sku, coalesce((lines->0->>'price')::numeric,1000) as price
      from purchase_orders where farm_id=:'farm' and supplier_id is not null and jsonb_array_length(coalesce(lines,'[]'::jsonb))>0 order by ts desc limit 1) po
on conflict (id) do nothing;

-- ===== (C5) ĐỌC SỐ MÁY/CÔNG-TƠ: cấu hình chỉ số cho máy thật + 14 ngày số đọc (1 ngày điện nhảy vọt = bất thường) =====
insert into reading_metrics(id, farm_id, facility_id, code, name, unit, kind, freq, lo, hi, role_hint) values
 ('RM-ELEC-'||:'farm', :'farm', :'farm'||'-FC-TRAM-DIEN', 'DIEN_KWH', 'Điện tiêu thụ (công-tơ tổng)', 'kWh', 'METER', 'NGAY', null, 400, 'it_engineer'),
 ('RM-WATER-'||:'farm', :'farm', :'farm'||'-FC-GIENG', 'NUOC_M3', 'Nước bơm (công-tơ giếng)', 'm³', 'METER', 'NGAY', null, 60, 'it_engineer'),
 ('RM-BIOGAS-'||:'farm', :'farm', :'farm'||'-FC-BIOGAS', 'BIOGAS_M3', 'Biogas sinh ra', 'm³', 'METER', 'NGAY', null, 90, 'tech_head'),
 ('RM-D5OUT-'||:'farm', :'farm', :'farm'||'-FC-D5', 'SANLUONG_KG', 'Sản lượng viên D5', 'kg', 'METER', 'NGAY', null, 3000, 'team_lead')
on conflict (id) do nothing;
do $$
declare m record; dday int; val numeric; cref text; who text;
begin
  who := coalesce((select id from staff where farm_id=:'farm' and dept='CNTB' and active limit 1), 'system');
  delete from device_readings where farm_id=:'farm' and client_ref like 'seed-rd-%';
  for m in select * from (values
      ('RM-ELEC-'||:'farm', 52000::numeric, 180::numeric, 4::int),   -- điện: nhảy vọt 4 ngày trước
      ('RM-WATER-'||:'farm', 8400::numeric, 25::numeric, -1),
      ('RM-BIOGAS-'||:'farm', 12500::numeric, 40::numeric, -1),
      ('RM-D5OUT-'||:'farm', 0::numeric, 1200::numeric, -1)
    ) as t(mid, base, step, spikeday) loop
    val := m.base;
    for dday in reverse 13..0 loop
      val := val + (case when dday = m.spikeday then m.step*4 else m.step*(0.9 + (dday % 3)*0.05) end);
      cref := 'seed-rd-'||m.mid||'-'||dday;
      perform record_reading(:'farm', m.mid, round(val,1), (current_date - dday)::timestamptz + time '07:00',
        'SO-'||to_char(current_date-dday,'YYMMDD')||'-'||right(m.mid,4), 'Đọc ca sáng theo sổ giấy (demo)', who, cref, 'PAPER');
    end loop;
  end loop;
end $$;

-- ===== (C6) KHÂU GHI CHÉP BẮT BUỘC + CẢNH BÁO QUÊN CẬP NHẬT =====
insert into recording_obligations(id, farm_id, code, name, dept, role_hint, source_kind, freq, grace_hours, escalate_hours, severity) values
 ('RO-FEED-'||:'farm', :'farm', 'GHI_CHO_AN', 'Ghi cho ăn hằng ngày (bảng khẩu phần)', 'KTCN', 'team_lead', 'FEED', 'NGAY', 6, 24, 'NANG'),
 ('RO-METER-'||:'farm', :'farm', 'DOC_CONGTO', 'Đọc số điện/nước/biogas (công-tơ)', 'CNTB', 'it_engineer', 'METER', 'NGAY', 8, 30, 'TRUNG'),
 ('RO-CHECK-'||:'farm', :'farm', 'CHECKLIST_CA', 'Checklist đầu/cuối ca', 'KTCN', 'team_lead', 'CHECKLIST', 'NGAY', 6, 24, 'NANG'),
 ('RO-PAPER-'||:'farm', :'farm', 'SO_HOA_GIAY', 'Số hóa phiếu giấy ≤24h (đối chiếu seri)', 'HCNS', 'team_lead', 'PAPER', 'NGAY', 4, 6, 'NANG'),
 ('RO-STOCK-'||:'farm', :'farm', 'GHI_KHO', 'Ghi nhập/xuất kho trong ngày', 'CCU', 'worker', 'STOCK', 'NGAY', 8, 30, 'TRUNG'),
 ('RO-IRR-'||:'farm', :'farm', 'GHI_TUOI', 'Ghi tưới theo thửa', 'TT', 'worker', 'IRRIGATION', 'NGAY', 12, 36, 'TRUNG'),
 ('RO-PEST-'||:'farm', :'farm', 'SOI_SAU_BENH', 'Soi sâu bệnh (scouting) hằng tuần', 'TT', 'team_lead', 'PEST', 'TUAN', 24, 72, 'TRUNG'),
 ('RO-HARVEST-'||:'farm', :'farm', 'GHI_THU_HOACH', 'Ghi thu hoạch theo đợt', 'TT', 'team_lead', 'HARVEST', 'DOT', 24, 72, 'NHE')
on conflict (id) do nothing;
select gen_recording_alerts(:'farm');
