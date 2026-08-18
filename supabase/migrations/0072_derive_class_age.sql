-- 0072 · derive_class: hạng theo tuổi (bê/tơ/dê con) luôn tính lại theo tuổi hiện tại — bê lớn tự chuyển tơ → nái/vỗ béo (không kẹt ở class_code cũ)
create or replace function derive_class(p_species text, p_sex text, p_birth date, p_class text) returns text language sql immutable as $$
  select case
    when p_class is not null and p_class not in ('BO-BE','BO-TO','DE-CON') then p_class
    when p_species='BO' then case when p_birth is null then coalesce(p_class,'BO-CAI-SS') when current_date - p_birth <= 180 then 'BO-BE' when current_date - p_birth <= 540 then 'BO-TO' when p_sex='M' then 'BO-VO-BEO' else 'BO-CAI-SS' end
    when p_species='DE' then case when p_birth is not null and current_date - p_birth <= 120 then 'DE-CON' when p_sex='M' then 'DE-THIT' else 'DE-CAI-SS' end
    else coalesce(p_class, p_species) end $$;
