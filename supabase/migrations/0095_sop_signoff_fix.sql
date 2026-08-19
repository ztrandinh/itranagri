-- 0095 · Ký SOP theo SOP L2 (procedures) — dữ liệu seed dùng l2_code gom bước L3; ký ở cấp L2
create or replace view v_sop_signoff as
 with l2 as (
   select s.l2_code as code, coalesce(max(p.name), max(s.title)) as title, coalesce(max(p.dept_code), max(s.dept)) as dept,
     greatest(coalesce(max(s.version),1),1) as version, max(s.video_url) as video_url
   from sops s left join processes p on p.code=s.l2_code where s.l2_code is not null group by s.l2_code)
 select l2.code, l2.title, l2.dept, l2.version, null::text as owner_role, l2.video_url, null::timestamptz as published_at,
   (select count(*) from staff st where st.active and (st.dept=l2.dept or l2.dept is null)) as need,
   (select count(distinct a.staff_id) from sop_acknowledgments a where a.sop_code=l2.code and a.kind='DOC_HIEU') as signed
 from l2;
grant select on v_sop_signoff to app_user;
