-- 0048 · fix chữ ký publish_event(farm, topic, payload) trong itran_pub_pest
create or replace function itran_pub_pest() returns trigger language plpgsql as $$
begin
  if new.density is not null and new.threshold is not null and new.density >= new.threshold then
    perform publish_event(new.farm_id, 'pest.over_threshold', jsonb_build_object('plot_id', new.plot_id, 'season_id', new.season_id, 'pest', new.pest, 'density', new.density, 'threshold', new.threshold, 'ipm_level', new.ipm_level, 'id', new.id, 'source_table', 'pest_scouting'));
  end if; return new; end $$;
update alert_rules set source='custom' where code in ('AL-WX-RAIN','AL-WX-HEAT','AL-PEST','AL-WATER-DEF');
