-- 0045: gộp 3 SOP seed cũ (SOP-TR-01.3, SOP-KHO-01.1, SOP-AN-01.1) vào thư viện L2/L3 chuẩn 0042 — không xóa (append-only tinh thần), chỉ chuẩn hóa l1_chain + trỏ l2_code + status LEGACY
update sops set l1_chain='CHUOI_SINH_HOC', l2_code='SOP-SH-01', status='THAY_THE' where code='SOP-TR-01.3';
update sops set l1_chain='CHUOI_HO_TRO', l2_code='SOP-HC-02', status='THAY_THE' where code='SOP-KHO-01.1';
update sops set l1_chain='CHUOI_AN_TOAN', l2_code='SOP-AT-01', status='THAY_THE' where code='SOP-AN-01.1';
