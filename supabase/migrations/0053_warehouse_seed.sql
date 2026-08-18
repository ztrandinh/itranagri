-- 0053 · seed kho chi tiết F01: bin K1/K5/K6/K9, chính sách tồn (ROP) cho nguyên liệu lõi, 1 xe tải + 1 xe lạnh
insert into bins(id, farm_id, warehouse_id, code, zone, aisle, rack, level, kind, capacity_kg, pick_seq) values
 ('F01-BIN-K1-A01','F01','F01-K1','A-01-1','A','01','A','1','KE',200,10),('F01-BIN-K1-A02','F01','F01-K1','A-01-2','A','01','A','2','KE',200,11),('F01-BIN-K1-LANH','F01','F01-K1','TU-LANH-VX','VAC','','','','LANH',50,5),
 ('F01-BIN-K5-P01','F01','F01-K5','P-01','P','01','','','PALLET',1000,20),('F01-BIN-K5-P02','F01','F01-K5','P-02','P','02','','','PALLET',1000,21),('F01-BIN-K5-P03','F01','F01-K5','P-03','P','03','','','PALLET',1000,22),
 ('F01-BIN-K6-L01','F01','F01-K6','L-01','L','01','','','LANH',500,30),('F01-BIN-K6-L02','F01','F01-K6','L-02','L','02','','','LANH',500,31),('F01-BIN-K6-D01','F01','F01-K6','D-01','D','01','','','DONG',300,32),
 ('F01-BIN-K9-B01','F01','F01-K9','B-01','B','01','','','KE',300,40)
on conflict do nothing;
update bins set temp_min=2, temp_max=8 where kind='LANH'; update bins set temp_min=-20, temp_max=-15 where kind='DONG';
insert into stock_policies(id, farm_id, sku, method, rop_qty, max_qty, safety_qty, lead_time_days, moq, abc_class, count_cycle_days, preferred_supplier_id) values
 ('F01-SP-NL-ROM','F01','NL-ROM','ROP',5000,20000,2000,5,5000,'A',30,'NCC-0001'),
 ('F01-SP-NL-BA-BIA','F01','NL-BA-BIA','DAYS',null,null,null,2,null,'A',30,'NCC-0002'),
 ('F01-SP-NL-RI-MAT','F01','NL-RI-MAT','MIN_MAX',300,2000,null,7,500,'B',90,null),
 ('F01-SP-NL-KHOANG','F01','NL-KHOANG','ROP',100,600,50,10,100,'B',90,null),
 ('F01-SP-BB-BAO-25','F01','BB-BAO-25','MIN_MAX',200,2000,null,14,500,'C',180,null),
 ('F01-SP-BB-TEM','F01','BB-TEM','MIN_MAX',500,5000,null,14,1000,'C',180,null)
on conflict do nothing;
update stock_policies set min_days=5 where id='F01-SP-NL-BA-BIA';
insert into vehicles(id, farm_id, plate, kind, capacity_kg, refrigerated, temp_min, temp_max, owner, insurance_due, inspection_due, fuel_l_per_100km) values
 ('F01-XE-01','F01','89C-123.45','TAI',3500,false,null,null,'TRAI',current_date+120,current_date+40,14),
 ('F01-XE-02','F01','89C-678.90','LANH',1500,true,0,4,'TRAI',current_date+200,current_date+10,12)
on conflict do nothing;
