-- 0024 · task.created mang theo phòng ban (từ bước quy trình) để chỉ báo đúng người trong bộ phận
create or replace function itran_task_publish() returns trigger language plpgsql as $$
begin if new.priority in ('KHAN','CAO') then perform publish_event(new.farm_id, 'task.created', jsonb_build_object('task_id',new.id,'title',new.title,'role_hint',new.role_hint,'assignee',new.assignee_id,'priority',new.priority,'due',new.due_at,'dept',new.detail->>'dept','run_id',new.detail->>'run_id')); end if; return new; end $$;
