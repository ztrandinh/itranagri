-- ---------- SEED PHẦN 3: (J) created_at ≈ ts cho bản ghi IMPORT; (K) GIÁM SÁT & ĐÀO TẠO 30 tháng + chấm điểm 12 tuần + chốt thưởng 3 tháng ----------
set client_min_messages = warning;
select set_config('app.org_id','ITRAN',false), set_config('app.farm_id',:'farm',false), set_config('app.role','it_engineer',false), set_config('app.staff_id','NS-001',false);
set session_replication_role = replica;
update feed_logs set created_at = ts + ((5 + abs(hashtext(id::text))%35)||' minutes')::interval where farm_id=:'farm' and source='IMPORT' and created_at > ts + interval '1 day';
update animal_events set created_at = ts + ((5 + abs(hashtext(id::text))%35)||' minutes')::interval where farm_id=:'farm' and source='IMPORT' and created_at > ts + interval '1 day';
update crop_logs set created_at = ts + ((5 + abs(hashtext(id::text))%35)||' minutes')::interval where farm_id=:'farm' and source='IMPORT' and created_at > ts + interval '1 day';
update inventory_moves set created_at = ts + ((5 + abs(hashtext(id::text))%35)||' minutes')::interval where farm_id=:'farm' and source='IMPORT' and created_at > ts + interval '1 day';
update batch_logs set created_at = ts + ((5 + abs(hashtext(id::text))%35)||' minutes')::interval where farm_id=:'farm' and source='IMPORT' and created_at > ts + interval '1 day';
update checklist_runs set created_at = ts + ((5 + abs(hashtext(id::text))%35)||' minutes')::interval where farm_id=:'farm' and source='IMPORT' and created_at > ts + interval '1 day';
update gate_logs set created_at = ts + ((5 + abs(hashtext(id::text))%35)||' minutes')::interval where farm_id=:'farm' and source='IMPORT' and created_at > ts + interval '1 day';
set session_replication_role = origin;
do $$ declare F text := :'farm'; k int; r record; wk date; sc numeric; ex text; qa text; tsel record; begin
  qa := coalesce((select id from staff where role='auditor' and active order by id limit 1), (select id from staff where farm_id=F and role='tech_head' and active order by id limit 1));
  for r in select distinct dept from staff where farm_id=F and active and role='worker' loop
    insert into supervision_assignments(id, farm_id, supervisor_id, target_dept, scope, checks_per_week, from_date) values (F||'-GS-'||r.dept, F, coalesce((select id from staff s where s.farm_id=F and s.role='tech_head' and s.dept=r.dept and s.active order by id limit 1), qa), r.dept, 'SOP vị trí + ghi chép + hoàn thành việc', 5, current_date - 400) on conflict do nothing;
  end loop;
  insert into supervision_assignments(id, farm_id, supervisor_id, target_dept, scope, checks_per_week, from_date) values (F||'-GS-QA', F, qa, null, 'QA giám sát chéo toàn trại (kiểm tra người giám sát)', 3, current_date - 400) on conflict do nothing;
  for k in 0..(30*30/7) loop wk := (date_trunc('week', current_date) - (k*7||' days')::interval)::date; exit when wk < current_date - 900;
    for r in select s.id, s.manager_id, s.full_name from staff s where s.farm_id=F and s.active and s.manager_id is not null and coalesce(s.hired_on, current_date-1000) <= wk loop
      continue when exists (select 1 from training_sessions t where t.trainee_id=r.id and t.week_start=wk);
      ex := coalesce((select m.manager_id from staff m where m.id=r.manager_id), qa);
      select * into tsel from next_training_topic(r.id);
      insert into training_sessions(id, farm_id, week_start, trainer_id, trainee_id, topic_kind, topic_code, topic_title, planned_hours, held_at, actual_hours, method, status, trainee_ack)
      values (F||'-DT-'||to_char(wk,'YYMMDD')||'-'||r.id, F, wk, r.manager_id, r.id, 'SOP', tsel.sop_code, coalesce(tsel.sop_title,'Ôn tập quy trình vị trí'), 2.5, wk + 3 + time '15:00', case when (k+length(r.id))%10=0 then null else 2 + ((k*7)%3)*0.5 end, 'KEM_CAP', case when (k+length(r.id))%10=0 then 'BO_LO' else 'XONG' end, (k+length(r.id))%10<>0) on conflict do nothing;
      if (k+length(r.id))%10<>0 then
        sc := 70 + ((k*13 + length(r.id)*7) % 29);
        insert into training_tests(id, farm_id, session_id, trainee_id, examiner_id, sop_code, taken_at, score, passed) values (F||'-DT-'||to_char(wk,'YYMMDD')||'-'||r.id||'-T', F, F||'-DT-'||to_char(wk,'YYMMDD')||'-'||r.id, r.id, ex, tsel.sop_code, wk + 4 + time '16:00', sc, sc >= 80) on conflict do nothing;
        if sc >= 80 and tsel.sop_code is not null then
          insert into staff_competencies(farm_id, staff_id, sop_code, level, certified_at, certified_by, expires_on) values (F, r.id, tsel.sop_code, 'THUC_HANH', wk+4, ex, wk+4+365)
          on conflict (staff_id, sop_code) do update set level = case when staff_competencies.level='HOC' then 'THUC_HANH' when staff_competencies.level='THUC_HANH' then 'THUAN_THUC' else staff_competencies.level end, certified_at=excluded.certified_at;
        end if;
      end if;
    end loop;
  end loop;
  for k in 1..12 loop wk := (date_trunc('week', current_date) - (k*7||' days')::interval)::date;
    -- Bỏ cặp giám sát viên chấm CHÍNH PHÒNG của mình: trái thiết kế chống thông đồng (tuyến 2
    -- phải chấm chéo phòng) và bị trg_sup_check_guard chặn thẳng bằng ERR_SELF_DEPT, làm
    -- `pnpm db:seed:history` chết giữa chừng trên CSDL trắng.
    for r in select s.id as sid, s.dept, c.id as cid, c.name, a.supervisor_id
               from staff s
               join supervision_criteria c on c.method='MANUAL' and c.active and c.position_code=s.position_code
               join supervision_assignments a on a.farm_id=F and a.target_dept=s.dept and a.active
               join staff sup on sup.id = a.supervisor_id
              where s.farm_id=F and s.active and sup.dept is distinct from s.dept loop
      insert into supervision_checks(farm_id, ts, created_by, source, client_ref, supervisor_id, target_dept, target_staff_id, criteria_id, week_start, item, result, severity, note)
      values (F, wk + 2 + time '10:00', r.supervisor_id, 'IMPORT', 'h3-sc-'||k||'-'||r.sid||'-'||r.cid, r.supervisor_id, r.dept, r.sid, r.cid, wk, r.name, case when (k*31 + length(r.sid) + length(r.cid))%7=0 then 'LOI' else 'DAT' end, case when (k*31 + length(r.sid) + length(r.cid))%7=0 then (array['NHE','TRUNG','NANG'])[1+k%3] end, case when (k*31 + length(r.sid) + length(r.cid))%7=0 then 'Quan sát tại chỗ: chưa đạt — yêu cầu khắc phục trong ca' end) on conflict do nothing;
    end loop;
    perform run_supervision_auto(F, wk);
  end loop;
  for k in 1..3 loop perform close_bonus(F, to_char(current_date - (k||' months')::interval, 'YYYY-MM')); end loop;
end $$;
select 'training_sessions' t, count(*) from training_sessions where farm_id=:'farm' union all select 'training_tests', count(*) from training_tests where farm_id=:'farm' union all select 'competencies', count(*) from staff_competencies where farm_id=:'farm' union all select 'supervision_checks', count(*) from supervision_checks where farm_id=:'farm' union all select 'supervision_scores', count(*) from supervision_scores where farm_id=:'farm' union all select 'bonus_ledger', count(*) from bonus_ledger where farm_id=:'farm';
