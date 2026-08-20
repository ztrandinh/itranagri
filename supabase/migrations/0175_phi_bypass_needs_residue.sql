-- 0175 — bịt lỗ hổng ATTP: "bỏ qua PHI" (phi_ok=true) phải KÈM bằng chứng kiểm tồn dư (residue_test)
-- Trước: bất kỳ công nhân nào tick phi_ok=true là thu hoạch được rau/củ CÒN cách ly BVTV,
-- không cần residue test → dư lượng vượt MRL → xuất khẩu bị trả. 50/50 harvest seed đều phi_ok=true, 0 residue.
-- Sau: còn cách ly + phi_ok=false → chặn (như cũ); phi_ok=true nhưng thiếu residue_test → CHẶN mới (ERR_PHI_NEED_RESIDUE).
-- Chỉ REPLACE hàm trigger (an toàn, không đổi schema).

create or replace function public.itran_check_phi() returns trigger language plpgsql as $$
declare d date; begin
  select max(safe_after) into d from crop_inputs
   where farm_id = new.farm_id and status = 'ACTIVE' and plot_id = new.plot_id
     and safe_after is not null and safe_after > new.ts::date;
  if d is not null then
    if coalesce(new.phi_ok, false) = false then
      raise exception 'ERR_PHI_NOT_ELAPSED: ô % còn cách ly BVTV đến % — chưa được thu hoạch', new.plot_id, d;
    elsif new.residue_test is null or btrim(new.residue_test) = '' then
      raise exception 'ERR_PHI_NEED_RESIDUE: ô % còn cách ly đến % — "bỏ qua PHI" phải kèm mã/kết quả kiểm tồn dư (residue_test), không được tự bỏ qua', new.plot_id, d;
    end if;
  end if;
  return new;
end $$;
