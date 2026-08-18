-- Seed marketing 6 tháng cho trại :'farm'
delete from mkt_mentions where farm_id=:'farm'; delete from mkt_contents where farm_id=:'farm'; delete from mkt_assets where farm_id=:'farm'; delete from mkt_campaigns where farm_id=:'farm';
insert into mkt_campaigns(farm_id, code, name, objective, channels, audience, product_focus, starts_on, ends_on, budget, kpi_target, status, owner_id, utm_code)
select :'farm', v.code, v.name, v.obj, v.ch::text[], v.aud, v.pf, v.s, v.e, v.b, v.k::jsonb, v.st, (select id from staff where login='tp-kd' limit 1), lower(v.code) from (values
 ('MK-2603','Bò tơ sạch Tết – đặt trước','Đơn đặt trước thịt bò/dê Tết','{FACEBOOK,ZALO,SU_KIEN}','Gia đình đô thị 30–55','Thịt bò tơ, dê', current_date-170, current_date-120, 15000000, '{"leads":120,"orders":80,"revenue":400000000}', 'XONG'),
 ('MK-2605','Trải nghiệm trại hè – tour học sinh','Booking tour hè','{FACEBOOK,TIKTOK,WEBSITE,BAO_CHI}','Trường học, gia đình có con 6–12','Tour trải nghiệm', current_date-110, current_date-40, 20000000, '{"leads":200,"bookings":60,"revenue":300000000}', 'XONG'),
 ('MK-2608','Trứng gà thảo mộc – kênh cửa hàng','Tăng khách quầy & online','{ZALO,FACEBOOK,POS}','Khách quen bán kính 15km','Trứng, rau, sữa', current_date-30, current_date+30, 8000000, '{"leads":80,"orders":150}', 'DANG_CHAY'),
 ('MK-2609','Nhận nuôi bò – chăm sóc hộ live','Hợp đồng nhận nuôi','{YOUTUBE,FACEBOOK,WEBSITE}','Nhà đầu tư nhỏ, gia đình','Nhận nuôi', current_date-7, current_date+60, 12000000, '{"leads":60,"contracts":15}', 'DANG_CHAY')) v(code,name,obj,ch,aud,pf,s,e,b,k,st);
-- Lịch nội dung: ~4 bài/tuần trong 16 tuần, đa kênh, có số đo
insert into mkt_contents(farm_id, campaign_id, planned_at, channel, kind, title, brief, status, author_id, approved_by, published_at, url, metrics, cost)
select :'farm', (select id from mkt_campaigns c where c.farm_id=:'farm' order by (c.starts_on <= d and c.ends_on >= d) desc, c.starts_on desc limit 1), d, ch, kd, t, 'Brief: '||t, case when d < current_date then 'DA_DANG' when d < current_date + 3 then 'DUYET' when d < current_date + 10 then 'CHO_DUYET' else 'Y_TUONG' end,
  (select id from staff where login='nvkd1' limit 1), case when d < current_date + 3 then (select id from staff where login='tp-kd' limit 1) end, case when d < current_date then d::timestamptz + interval '9 hours' end,
  case when d < current_date then 'https://fb.com/itranfarm/'||to_char(d,'YYMMDD') end,
  case when d < current_date then jsonb_build_object('reach', 800 + (random()*4000)::int, 'clicks', 20 + (random()*200)::int, 'likes', 30 + (random()*300)::int, 'comments', (random()*40)::int) else '{}'::jsonb end,
  case ch when 'FACEBOOK' then 150000 when 'TIKTOK' then 200000 when 'BAO_CHI' then 2000000 else 0 end
from (select current_date - 105 + (g*7 + k*2)::int as d, (array['FACEBOOK','ZALO','TIKTOK','WEBSITE','YOUTUBE','FACEBOOK','BAO_CHI'])[1 + ((g+k) % 7)] as ch, (array['BAI_VIET','VIDEO','LIVE','BAI_VIET','EVENT'])[1 + ((g*3+k) % 5)] as kd,
  (array['Một ngày ở trại: bê con chào đời','Cỏ Mombasa & khẩu phần TMR — vì sao thịt ngọt','Trứng gà thảo mộc: quy trình 30 ngày','Tour trải nghiệm: lịch tuần này','Nhận nuôi bò – xem live chuồng','Chứng nhận VietGAP & truy xuất QR','Rau nhà lưới – thu hoạch sáng nay','Khu D: trùn – BSF – biogas tuần hoàn'])[1 + ((g*2+k) % 8)] as t
  from generate_series(0,17) g, generate_series(0,3) k) x where d <= current_date + 21;
insert into mkt_assets(farm_id, kind, title, url, tags, version, approved, approved_by) values
 (:'farm','LOGO','Logo ITRAN FARM (bộ đầy đủ)','/assets/brand/logo.zip','{logo,brand}','v3',true,(select id from staff where login='tgd')),
 (:'farm','BO_NHAN_DIEN','Sổ tay nhận diện thương hiệu','/assets/brand/guideline.pdf','{brand,guideline}','v2',true,(select id from staff where login='tgd')),
 (:'farm','HINH_ANH','Ảnh trại – bộ 120 ảnh chuẩn 2026','/assets/photos/2026','{photo}','2026',true,(select id from staff where login='tp-kd')),
 (:'farm','VIDEO','Video giới thiệu 90s','/assets/video/intro90.mp4','{video,intro}','v1',true,(select id from staff where login='tp-kd')),
 (:'farm','CHUNG_NHAN','Giấy chứng nhận VietGAP / ATTP (bản dùng truyền thông)','/assets/certs','{cert}','2026',true,(select id from staff where login='tp-qa')),
 (:'farm','TAI_LIEU','FAQ trả lời khách & mẫu phản hồi khủng hoảng (SOP-KD-05)','/assets/docs/faq.pdf','{faq,crisis}','v1',false,null);
insert into mkt_mentions(farm_id, ts, channel, source_url, author, summary, sentiment, severity, status, handler_id, response, resolved_at)
select :'farm', now() - (g||' days')::interval, ch, 'https://'||lower(ch)||'.com/p/'||g, 'khách '||g, s, sen, sev, st, case when st<>'MOI' then (select id from staff where login='tp-kd' limit 1) end, case when st in ('DA_PHAN_HOI','DONG') then 'Cảm ơn anh/chị, chúng tôi đã kiểm tra và ...' end, case when st='DONG' then now() - (g||' days')::interval + interval '20 hours' end
from (values
 (2,'FACEBOOK','Thịt bò tơ ăn rất ngon, giao đúng giờ','TICH_CUC','THAP','DONG'),(4,'GOOGLE','Tour đông quá, hướng dẫn viên không đủ','TIEU_CUC','TRUNG','DA_PHAN_HOI'),(6,'ZALO','Hỏi giá nhận nuôi bò','TRUNG_TINH','THAP','DONG'),
 (9,'FACEBOOK','Trứng có 2 quả bị vỡ trong hộp','TIEU_CUC','TRUNG','DONG'),(15,'BAO_CHI','Bài báo: mô hình trại tuần hoàn ITRAN','TICH_CUC','THAP','DONG'),(21,'TIKTOK','Video bình luận nghi ngờ nguồn gốc thịt','TIEU_CUC','CAO','DONG'),
 (1,'FACEBOOK','Bình luận tố mùi hôi từ khu D lan sang xóm','TIEU_CUC','CAO','MOI')) v(g,ch,s,sen,sev,st);
-- Gắn nguồn: 40% lead 6 tháng gần đây có chiến dịch
update crm_leads l set campaign_id=(select id from mkt_campaigns c where c.farm_id=l.farm_id and c.starts_on <= l.created_at::date and coalesce(c.ends_on, current_date+365) >= l.created_at::date order by c.starts_on desc limit 1)
 where l.farm_id=:'farm' and l.created_at > current_date - 180 and random() < 0.4;
update sales s set campaign_id=(select id from mkt_campaigns c where c.farm_id=s.farm_id and c.starts_on <= s.ts::date and coalesce(c.ends_on, current_date+365) >= s.ts::date order by c.starts_on desc limit 1)
 where s.farm_id=:'farm' and s.ts > current_date - 180 and random() < 0.25;
update hosp_bookings b set campaign_id=(select id from mkt_campaigns c where c.farm_id=b.farm_id and c.code='MK-2605') where b.farm_id=:'farm' and b.check_in between current_date-110 and current_date-40 and random() < 0.6;
