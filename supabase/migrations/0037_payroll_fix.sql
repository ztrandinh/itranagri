-- 0037 · sửa approve_payroll (biến trùng tên cột)
create or replace function approve_payroll(p_run uuid, p_by text) returns void language plpgsql as $$
declare r record; v_g numeric; v_n numeric; v_ins numeric; v_pit numeric; v_emp numeric; begin
  select * into r from payroll_runs where id=p_run; if r is null then raise exception 'ERR_NOT_FOUND'; end if; if r.computed_by = p_by then raise exception 'ERR_SELF_APPROVE'; end if;
  select coalesce(sum(gross),0), coalesce(sum(net),0), coalesce(sum(bhxh+bhyt+bhtn),0), coalesce(sum(payslips.pit),0), coalesce(sum(employer_ins),0) into v_g,v_n,v_ins,v_pit,v_emp from payslips where run_id=p_run;
  perform gl_post(r.farm_id,'payroll_runs',p_run::text,'Lương tháng '||to_char(r.month,'MM/YYYY'), jsonb_build_array(jsonb_build_object('acct','622','debit',v_g+v_emp,'credit',0), jsonb_build_object('acct','334','debit',0,'credit',v_n), jsonb_build_object('acct','338','debit',0,'credit',v_ins+v_emp), jsonb_build_object('acct','333','debit',0,'credit',v_pit), jsonb_build_object('acct','111','debit',0,'credit',v_g-v_n-v_ins-v_pit)), now(), p_by);
  update payroll_runs set status='DUYET', approved_by=p_by, approved_at=now() where id=p_run;
  perform publish_event(r.farm_id,'payroll.approved',jsonb_build_object('run',p_run,'month',r.month,'net',v_n)); end $$;
