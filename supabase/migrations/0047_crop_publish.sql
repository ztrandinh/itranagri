-- 0047 · phát sự kiện tưới / dịch hại vượt ngưỡng lên event bus + cảnh báo thời tiết
create or replace function itran_pub_pest() returns trigger language plpgsql as $$
begin
  if new.density is not null and new.threshold is not null and new.density >= new.threshold then
    perform publish_event(new.farm_id, 'pest.over_threshold', jsonb_build_object('plot_id', new.plot_id, 'season_id', new.season_id, 'pest', new.pest, 'density', new.density, 'threshold', new.threshold, 'ipm_level', new.ipm_level, 'id', new.id), 'pest_scouting', new.id::text);
  end if; return new; end $$;
drop trigger if exists pub_pest on pest_scouting; create trigger pub_pest after insert on pest_scouting for each row execute function itran_pub_pest();
drop trigger if exists pub_irrig on irrigation_logs; create trigger pub_irrig after insert on irrigation_logs for each row execute function itran_generic_publish('irrigation.logged');
update event_topics set source_table='pest_scouting', wired=true where topic='pest.over_threshold';
update event_topics set source_table='irrigation_logs', wired=true where topic='irrigation.logged';
-- luật cảnh báo thời tiết cấu hình (alert_rules) — mưa >50mm/ngày, nắng nóng >37°C
insert into alert_rules(code, version, farm_id, name, source, expr, level, recipients, channels, cooldown_min, active) select v.code, v.version, v.farm_id, v.name, v.source, v.expr::jsonb, v.level, v.recipients::text[], v.channels::text[], v.cooldown_min, v.active from (values
 ('AL-WX-RAIN',1,'GLOBAL','Mưa lớn >50 mm/ngày','weather','{"type":"sql_rows","sql":"select farm_id, day::text as ref, rain_mm as value from weather_daily where farm_id=$1 and day>=current_date-1 and rain_mm>50","message":"Mưa {value} mm ngày {ref} — kiểm thoát nước, che hào ủ, van RAS, chuồng thấp"}','VANG','{tech_head,team_lead,director}','{app}',720,true),
 ('AL-WX-HEAT',1,'GLOBAL','Nắng nóng >37°C','weather','{"type":"sql_rows","sql":"select farm_id, day::text as ref, tmax as value from weather_daily where farm_id=$1 and day>=current_date-1 and tmax>37","message":"Nhiệt độ {value}°C ngày {ref} — phun mát chuồng, tăng nước uống, tưới sáng sớm"}','VANG','{tech_head,team_lead}','{app}',720,true),
 ('AL-PEST',1,'GLOBAL','Dịch hại vượt ngưỡng IPM 24h','crop','{"type":"sql_rows","sql":"select plot_id as ref, pest, density as value, threshold from pest_scouting where farm_id=$1 and status=''ACTIVE'' and ts>now()-interval ''24 hours'' and density>=threshold","message":"Ô {ref}: {pest} mật độ {value} ≥ ngưỡng {threshold} — xử lý theo bậc IPM (sinh học → cơ học → hóa học cục bộ có lệnh GĐ)"}','VANG','{tech_head,team_lead}','{app}',720,true),
 ('AL-WATER-DEF',1,'GLOBAL','Thiếu nước mùa vụ (mưa+tưới < 70% ETc)','crop','{"type":"sql_rows","sql":"select code as ref, round(rain_mm+coalesce(irrigation_mm,0)) as value, round(etc_mm) as etc from v_water_balance where farm_id=$1 and etc_mm>50 and (rain_mm+coalesce(irrigation_mm,0)) < 0.7*etc_mm and sow_date>current_date-200","message":"Mùa vụ {ref}: nước {value} mm < 70% ETc {etc} mm — lên lịch tưới"}','VANG','{tech_head,team_lead}','{app}',1440,true)
) as v(code, version, farm_id, name, source, expr, level, recipients, channels, cooldown_min, active) where not exists (select 1 from alert_rules a where a.code=v.code);
