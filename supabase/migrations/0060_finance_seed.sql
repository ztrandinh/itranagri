-- 0060 · seed tài chính F01: khoản vay mẫu + lịch, bảo hiểm vật nuôi mẫu, kỳ hạn NCC
insert into loans(id, farm_id, lender, kind, contract_no, principal, rate_pct, start_date, term_months, method, grace_months, purpose) values
 ('F01-VAY-01','F01','Agribank Hưng Yên','NGAN_HANG','HĐTD-2026-0815',2000000000,8.5,'2026-08-01',36,'GOC_DEU',6,'Đầu tư chuồng bò 100 con + hệ D5')
on conflict do nothing;
select gen_loan_schedule('F01-VAY-01');
insert into insurance_policies(id, farm_id, insurer, policy_no, kind, subject_type, coverage, sum_insured, premium, start_date, end_date, note) values
 ('F01-BH-01','F01','Bảo Minh','BM-VN-2026-118','VAT_NUOI','group','Bò thịt chết do dịch bệnh/tai nạn/thiên tai theo NĐ 58/2018 (bảo hiểm nông nghiệp) — bồi thường theo giá trị sổ đàn','1500000000','45000000','2026-08-01','2027-07-31','Hỗ trợ phí theo NĐ 58/2018 nếu đủ điều kiện'),
 ('F01-BH-02','F01','PVI','PVI-TS-2026-2211','TAI_SAN','asset','Cháy nổ, giông lốc nhà xưởng D5, kho lạnh, ĐMT','3000000000','18000000','2026-01-15','2027-01-14',null),
 ('F01-BH-03','F01','Bảo Việt','BV-XE-2026-778','XE','vehicle','TNDS bắt buộc + vật chất xe lạnh 89C-678.90','800000000','9600000','2026-03-01','2027-02-28',null)
on conflict do nothing;
update partners set supplier_terms_days=15 where kind='NCC' and supplier_terms_days is null;
