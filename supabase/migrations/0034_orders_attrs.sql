-- 0034 · orders.attrs (nguồn online, mã đơn sàn, phí ship, COD) + notify order.created tới các phòng
alter table orders add column if not exists attrs jsonb default '{}'::jsonb;
create index if not exists orders_external on orders((attrs->>'source'), (attrs->>'external_id'));
insert into event_topics(topic,producer_dept,consumer_depts,description,source_table,wired) values ('order.created','KDM','{KDM,CCU,D5,TCKT}','Đơn mới (portal đối tác / sàn TMĐT / website / POS) → Kinh doanh xác nhận · Kho soạn FEFO · D5 lệnh SX nếu thiếu · Kế toán thu/COD/đối soát sàn','orders',true) on conflict (topic) do update set consumer_depts=excluded.consumer_depts, description=excluded.description, wired=true;
