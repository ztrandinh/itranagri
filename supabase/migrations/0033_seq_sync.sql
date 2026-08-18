-- 0033 · next_code an toàn: bỏ qua mã đã tồn tại (dữ liệu seed/nhập CSV không qua sequence) + đồng bộ id_sequences từ animals/lots hiện có
create or replace function sync_id_sequence(p_farm text, p_type text, p_table text, p_col text default 'id') returns void language plpgsql as $$
declare mx bigint; begin
  execute format('select coalesce(max(nullif(regexp_replace(%I, ''^%s-%s-'', ''''), '''')::bigint),0) from %I where %I like %L', p_col, p_farm, p_type, p_table, p_col, p_farm||'-'||p_type||'-%') into mx;
  insert into id_sequences(farm_id,type,last_no) values (p_farm,p_type,mx) on conflict (farm_id,type) do update set last_no=greatest(id_sequences.last_no, excluded.last_no);
exception when others then null; end $$;
do $$ declare f record; sp record; begin
  for f in select id from farms loop
    for sp in select code from species where identify_level='CA_THE' loop perform sync_id_sequence(f.id, sp.code, 'animals'); end loop;
    perform sync_id_sequence(f.id,'LN','intake_lots'); perform sync_id_sequence(f.id,'FC','facilities'); perform sync_id_sequence(f.id,'CS','crop_seasons'); perform sync_id_sequence(f.id,'NS','staff'); perform sync_id_sequence(f.id,'PT','partners');
  end loop; end $$;
-- intake_herd: nếu mã sinh ra đã tồn tại thì lấy mã kế tiếp
create or replace function next_code_free(p_farm text, p_type text, p_table text, p_width int default 5) returns text language plpgsql as $$
declare c text; ex bool; i int := 0; begin
  loop c := next_code(p_farm, p_type, p_width); execute format('select exists(select 1 from %I where id=$1)', p_table) into ex using c; exit when not ex or i > 10000; i := i + 1; end loop; return c; end $$;
create or replace function intake_herd(p_farm text, p_by text, p_lot jsonb, p_animals jsonb) returns jsonb language plpgsql as $$
declare lot_id text; a jsonb; code text; ids text[] := '{}'; sp text; begin
  lot_id := coalesce(p_lot->>'id', next_code_free(p_farm, 'LN', 'intake_lots', 4));
  insert into intake_lots(id,farm_id,kind,date,source_partner_id,quarantine_until,vet_cert_no,price,head_count,note) values (lot_id,p_farm,coalesce(p_lot->>'kind','MUA'),coalesce((p_lot->>'date')::date,current_date),nullif(p_lot->>'source_partner_id',''),coalesce((p_lot->>'quarantine_until')::date,current_date+21),p_lot->>'vet_cert_no',(p_lot->>'price')::numeric,jsonb_array_length(p_animals),p_lot->>'note') on conflict (id) do update set head_count=intake_lots.head_count+jsonb_array_length(p_animals);
  for a in select * from jsonb_array_elements(p_animals) loop
    sp := coalesce(a->>'species', p_lot->>'species', 'BO'); code := coalesce(nullif(a->>'id',''), next_code_free(p_farm, sp, 'animals', 5));
    insert into animals(id,farm_id,species,breed,sex,birth_date,rfid,visual_tag,source,intake_lot_id,group_id,status,location_id,tag_pending,last_weight_kg,last_weight_at,unit_value,class_code,attrs)
    values (code,p_farm,sp,coalesce(a->>'breed',p_lot->>'breed'),a->>'sex',(a->>'birth_date')::date,nullif(a->>'rfid',''),nullif(a->>'visual_tag',''),'MUA',lot_id,nullif(coalesce(a->>'group_id',p_lot->>'group_id'),''),'CACH_LY',nullif(coalesce(a->>'location_id',p_lot->>'location_id'),''),(nullif(a->>'rfid','') is null and nullif(a->>'visual_tag','') is null),(a->>'weight_kg')::numeric,case when a->>'weight_kg' is not null then now() end,coalesce((a->>'unit_value')::numeric,(p_lot->>'price')::numeric),a->>'class_code',coalesce(a->'attrs','{}'::jsonb));
    if nullif(a->>'rfid','') is not null then insert into animal_tags(farm_id,animal_id,tag_type,value,created_by) values (p_farm,code,'RFID',a->>'rfid',p_by); end if;
    if nullif(a->>'visual_tag','') is not null then insert into animal_tags(farm_id,animal_id,tag_type,value,created_by) values (p_farm,code,'VISUAL',a->>'visual_tag',p_by); end if;
    insert into animal_events(farm_id,created_by,animal_id,event_type,value,unit,detail,client_ref) values (p_farm,p_by,code,'NHAP',(a->>'weight_kg')::numeric,'kg',jsonb_build_object('lot',lot_id,'source',p_lot->>'source_partner_id'),'intake-'||code);
    insert into animal_events(farm_id,created_by,animal_id,event_type,detail,client_ref) values (p_farm,p_by,code,'CACH_LY_VAO',jsonb_build_object('until',coalesce((p_lot->>'quarantine_until')::date,current_date+21)),'quar-'||code);
    ids := ids || code;
  end loop;
  perform publish_event(p_farm,'animal.intake',jsonb_build_object('table','intake_lots','id',lot_id,'n',array_length(ids,1),'by',p_by));
  return jsonb_build_object('lot_id',lot_id,'animals',to_jsonb(ids)); end $$;
grant execute on function next_code_free(text,text,text,int), sync_id_sequence(text,text,text,text) to app_user;
