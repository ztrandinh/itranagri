-- 0130 — training_tests.sop_code: đổi khoá ngoại CỨNG sang trigger tự tạo SOP-stub
--
-- 0128 thêm khoá ngoại cứng training_tests.sop_code -> sops(code). Nhưng bản chất cột này là
-- MÃ CHỦ ĐỀ ĐÀO TẠO: thường là một SOP, nhưng hàm next_training_topic() sinh ra cả những mã
-- SOP chưa nằm trong danh mục (SOP-TY-01 thú y, SOP-KH-01 khảo hạch…). Khoá ngoại cứng làm
-- `pnpm db:seed:history` đứt giữa chừng ở NHIỀU file seed (seed-history-3, seed-career).
--
-- Cách đúng: chủ đề đào tạo là SOP thì PHẢI có trong danh mục — nhưng thay vì CHẶN, ta TỰ TẠO
-- một dòng SOP-stub (trạng thái BAN_HANH) khi lần đầu gặp. Danh mục vẫn đầy đủ, đối chiếu vẫn
-- được, mà không đứt seed lẫn không chặn runtime. Mã KHÔNG theo dạng SOP-* thì để nguyên
-- (chủ đề đào tạo tự do), không ép vào danh mục SOP.

alter table training_tests drop constraint if exists fk_training_tests_sop_code;

create or replace function trg_training_sop_stub() returns trigger language plpgsql as $$
begin
  if new.sop_code is not null and new.sop_code ~ '^SOP-'
     and not exists (select 1 from sops s where s.code = new.sop_code) then
    insert into sops(code, org_id, title, status, version)
    values (new.sop_code, 'ITRAN', new.sop_code, 'BAN_HANH', 1)
    on conflict (code) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists training_sop_stub on training_tests;
create trigger training_sop_stub before insert on training_tests
  for each row execute function trg_training_sop_stub();

comment on column training_tests.sop_code is
  'Mã CHỦ ĐỀ đào tạo — thường là SOP. Trigger training_sop_stub tự tạo dòng SOP nếu mã dạng SOP-* mà chưa có trong danh mục.';
