-- 0122 — Sổ đăng ký mã phủ TRỌN: thêm kiểu SEMANTIC bên cạnh AUTO
--
-- Chốt giữa hai phiên: mã SOP (`SOP-BO-08.1`) và quy trình (`P-QA-02`) GIỮ NGUYÊN, không đổi.
-- Lý do đứng từ phía người dùng:
--   · Đây là mã đối chiếu ra BỘ CHUẨN GIẤY (Quyển 3 §15). Công nhân cầm tờ SOP in ra đọc
--     'SOP-BO-08.1'; kiểm toán dò chéo giấy <-> số. Đổi mã = sổ giấy và sổ số nói hai thứ
--     khác nhau, người dùng chịu thiệt trực tiếp.
--   · Mã sinh tự động (ITRAN-SOP-00042) KHÔNG mang thông tin gì. 'SOP-BO-08.1' nói ngay:
--     chăn nuôi bò, quy trình 08, bước 1.
--
-- NHƯNG để không thành "hai hệ thống trong cùng một cái": thay vì để SOP/P nằm NGOÀI sổ đăng ký,
-- khai chúng VÀO sổ với kiểu SEMANTIC + mẫu kiểm tra. Khi đó sổ vẫn là NGUỒN SỰ THẬT DUY NHẤT;
-- mỗi loại đối tượng khai rõ quy tắc của nó — loại thì máy sinh, loại thì mã nghiệp vụ chuẩn.
-- check_code_compliance() kiểm được cả hai kiểu, không loại nào lọt sổ.

alter table code_registry add column if not exists scheme text not null default 'AUTO';  -- AUTO | SEMANTIC
alter table code_registry add column if not exists pattern text;      -- mẫu kiểm tra cho SEMANTIC
alter table code_registry add column if not exists pk_col text default 'id';  -- cột khoá của bảng

comment on column code_registry.scheme is 'AUTO = máy sinh {phạm vi}-{tiền tố}-{số}. SEMANTIC = mã nghiệp vụ chuẩn có sẵn, chỉ kiểm mẫu, không sinh lại.';

-- SOP và quy trình: mã có sẵn theo bộ chuẩn, khoá chính là `code` chứ không phải `id`.
update code_registry set scheme = 'SEMANTIC', pk_col = 'code',
       pattern = '^SOP-[A-Z]{2}-[0-9]{2}(\.[0-9]+)?$',
       note = 'Mã theo bộ chuẩn giấy Quyển 3 §15 — GIỮ NGUYÊN để sổ giấy và sổ số khớp nhau'
 where object_type = 'sop';

update code_registry set scheme = 'SEMANTIC', pk_col = 'code',
       pattern = '^P-[A-Z]{2,4}-[0-9]{2}$',
       note = 'Mã quy trình theo bộ chuẩn — GIỮ NGUYÊN'
 where object_type = 'quy_trinh';

-- Danh mục nghề và phòng ban cũng là mã có nghĩa, không nên đánh số máy.
update code_registry set scheme = 'SEMANTIC', pk_col = 'code',
       pattern = '^(A[0-9]{1,2}|T[0-9]{2}|K[0-9]{2}|G[0-9]{2}|C[0-9]{2}|Q[0-9]{2}|I[0-9]{2})$',
       note = 'Mã nghề đọc là biết cấp bậc — A công nhân, T trưởng nhóm, K kỹ thuật trưởng, G ban điều hành, C kế toán, Q chất lượng'
 where object_type = 'vi_tri_nghe';

update code_registry set scheme = 'SEMANTIC', pk_col = 'code',
       pattern = '^[A-Z]{2,5}$', note = 'Mã phòng ban viết tắt, dùng trong mã tài khoản {PHÒNG}-{CẤP BẬC}-{STT}'
 where object_type = 'phong_ban';

update code_registry set scheme = 'SEMANTIC', pk_col = 'code',
       pattern = '^[A-Z]{2,6}-[A-Z0-9-]+$', note = 'Mã tài khoản {PHÒNG}-{CẤP BẬC}-{STT}, bất biến theo chỗ ngồi'
 where object_type = 'tai_khoan';

-- ─────────────────────────────────────────────────────────────────────────────
-- Bộ soát: kiểm CẢ HAI kiểu. Trước đây chỉ soát bảng có khoá `id` kiểu text nên
-- sops/processes/positions_catalog/departments/job_accounts LỌT SỔ hoàn toàn.
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists check_code_compliance();
create or replace function check_code_compliance()
returns table(bang text, loai text, kieu text, tong bigint, dung_chuan bigint, con_lech bigint)
language plpgsql security definer as $$
declare r record; t bigint; ok bigint; pat text; pk text;
begin
  for r in select cr.* from code_registry cr
            where cr.active and cr.table_name is not null
              and to_regclass('public.' || cr.table_name) is not null loop
    pk := coalesce(r.pk_col, 'id');
    if not exists (select 1 from information_schema.columns c where c.table_schema='public'
                    and c.table_name=r.table_name and c.column_name=pk
                    and c.data_type in ('text','character varying')) then continue; end if;

    if r.scheme = 'SEMANTIC' then
      pat := r.pattern;
      if pat is null then continue; end if;
    else
      if r.width = 0 then continue; end if;
      pat := '^(F[0-9]+|ITRAN)-' || r.prefix || '-[0-9]{' || r.width || '}$';
    end if;

    execute format('select count(*), count(*) filter (where %I ~ %L) from %I where %s',
                   pk, pat, r.table_name, coalesce(r.filter_sql, 'true')) into t, ok;
    if t = 0 then continue; end if;
    bang := r.table_name; loai := r.object_type; kieu := r.scheme;
    tong := t; dung_chuan := ok; con_lech := t - ok;
    return next;
  end loop;
end $$;
grant execute on function check_code_compliance() to app_user;

-- Loại đối tượng nào chưa khai quy tắc — phải luôn rỗng, nếu không là có mã nằm ngoài sổ.
create or replace view v_code_unruled as
select object_type as loai, label as ten, table_name as bang, scheme as kieu
from code_registry
where active and ((scheme = 'SEMANTIC' and pattern is null) or (scheme = 'AUTO' and (prefix is null or prefix = '' or width = 0)));
grant select on v_code_unruled to app_user;
