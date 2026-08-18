-- 0013 · bảng không có farm_id (animal_ownership, group_membership): RLS qua animals + grant
alter table animal_ownership enable row level security; alter table group_membership enable row level security;
drop policy if exists p_sel on animal_ownership; create policy p_sel on animal_ownership for select using (exists (select 1 from animals a where a.id=animal_id and can_see_farm(a.farm_id)));
drop policy if exists p_w on animal_ownership; create policy p_w on animal_ownership for all using (exists (select 1 from animals a where a.id=animal_id and a.farm_id=app_farm())) with check (exists (select 1 from animals a where a.id=animal_id and a.farm_id=app_farm()));
drop policy if exists p_sel on group_membership; create policy p_sel on group_membership for select using (exists (select 1 from animals a where a.id=animal_id and can_see_farm(a.farm_id)));
drop policy if exists p_w on group_membership; create policy p_w on group_membership for all using (exists (select 1 from animals a where a.id=animal_id and a.farm_id=app_farm())) with check (true);
grant select, insert, update on animal_ownership, group_membership to app_user;
