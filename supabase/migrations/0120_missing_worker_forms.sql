-- 0120 — Bảng ghi cho các nghề đang KHÔNG có form (mục 3.1 biên bản 21)
--
-- Khối 0109–0119 nhường cho phiên "Tiếp tục ITRAN OS" (đã thống nhất), mình lấy từ 0120.
--
-- Ba nghề đang không ghi được việc chính của mình:
--   A14 Bếp   — không có chỗ ghi LƯU MẪU THỨC ĂN, mà đây là nghĩa vụ BẮT BUỘC theo ATTP
--               (lưu mẫu 24h, đủ khối lượng, có người lưu và người huỷ)
--   A16 Tài xế— không có chỗ ghi NHIỆT ĐỘ CHUỖI LẠNH trên đường; mất mắt xích này thì
--               cả chuỗi truy xuất lạnh đứt, hàng tới nơi không chứng minh được đạt nhiệt
--   A11 KTV   — bảng `calibrations` đã có sẵn và đúng khuôn bảng sự kiện, chỉ thiếu form
--
-- `trips` và `attendance` KHÔNG chuyển thành bảng sự kiện ở đây: chúng là bảng kế hoạch /
-- bảng tổng hợp, không phải sổ ghi append-only. Chấm công để lại, xử lý riêng.

-- ── Lưu mẫu thức ăn (ATTP) ───────────────────────────────────────────────────
create table if not exists food_samples (
  id            uuid primary key default gen_random_uuid(),
  farm_id       text not null,
  ts            timestamptz not null default now(),
  created_at    timestamptz default now(),
  created_by    text default app_staff(),
  source        text default 'APP',
  is_backfill   boolean default false,
  paper_serial  text,
  client_ref    text not null,
  supersedes_id uuid references food_samples(id),
  device_id     text,
  meal          text not null,                 -- SANG / TRUA / CHIEU / TIEC
  dish_name     text not null,                 -- tên món
  sample_gram   numeric not null,              -- khối lượng mẫu (ATTP yêu cầu tối thiểu 100g/món)
  stored_at     text,                          -- nơi lưu (tủ mẫu)
  temp_c        numeric,                       -- nhiệt độ tủ lưu mẫu
  keep_until    timestamptz,                   -- lưu tối thiểu 24h
  discarded_at  timestamptz,
  note          text,
  photo_urls    text[] default '{}'
);
create unique index if not exists ux_food_samples_ref on food_samples(farm_id, client_ref);
create index if not exists ix_food_samples_ts on food_samples(farm_id, ts desc);

-- ── Nhiệt độ chuỗi lạnh trên đường ───────────────────────────────────────────
create table if not exists cold_chain_logs (
  id            uuid primary key default gen_random_uuid(),
  farm_id       text not null,
  ts            timestamptz not null default now(),
  created_at    timestamptz default now(),
  created_by    text default app_staff(),
  source        text default 'APP',
  is_backfill   boolean default false,
  paper_serial  text,
  client_ref    text not null,
  supersedes_id uuid references cold_chain_logs(id),
  device_id     text,
  vehicle_id    text,                           -- xe đang chở
  leg           text not null,                  -- XEP_HANG / DOC_DUONG / GIAO_HANG
  temp_c        numeric not null,
  temp_max_c    numeric,                        -- ngưỡng cho phép của lô hàng
  door_open     boolean default false,
  location_note text,
  note          text,
  photo_urls    text[] default '{}'
);
create unique index if not exists ux_cold_chain_ref on cold_chain_logs(farm_id, client_ref);
create index if not exists ix_cold_chain_ts on cold_chain_logs(farm_id, ts desc);

-- ── Append-only + RLS, theo đúng luật 2 và luật 1 trong CLAUDE.md ────────────
do $$ declare t text; begin
  foreach t in array array['food_samples','cold_chain_logs'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_farm on %I', t);
    execute format($p$create policy p_farm on %I
        using (farm_id = any(string_to_array(current_setting('app.farm_ids', true), ',')))
        with check (farm_id = any(string_to_array(current_setting('app.farm_ids', true), ',')))$p$, t);
    execute format('grant select, insert on %I to app_user', t);
    -- append-only: cấm sửa/xoá, muốn sửa thì ghi bản mới với supersedes_id
    execute format('revoke update, delete on %I from app_user', t);
    execute format('drop trigger if exists %s_noupd on %I', t, t);
    execute format('create trigger %s_noupd before update or delete on %I for each row execute function itran_no_update_delete()', t, t);
  end loop;
end $$;

-- ── Bổ sung vào bộ form của nghề ─────────────────────────────────────────────
update positions_catalog set forms = '{food_sample,sale,stock_in,stock_out,incident,paper_submit}'  where code = 'A14';
update positions_catalog set forms = '{cold_chain,gate,stock_out,fuel_out,incident,paper_submit}'    where code = 'A16';
update positions_catalog set forms = '{calibration,checklist,stock_in,stock_out,incident,paper_submit}' where code = 'A11';
-- Trưởng nhóm sơ chế – kho lạnh cũng cần theo dõi chuỗi lạnh
update positions_catalog set forms = forms || '{cold_chain}' where code = 'T02' and not ('cold_chain' = any(forms));
-- Kỹ thuật trưởng công nghệ xem được phiếu hiệu chuẩn
update positions_catalog set forms = forms || '{calibration}' where code in ('K06','K07') and not ('calibration' = any(forms));

-- ── Khai vào sổ đăng ký mã ───────────────────────────────────────────────────
insert into code_registry (object_type, label, table_name, scope, prefix, width, level, note) values
  ('mau_thuc_an','Mẫu thức ăn lưu (ATTP)','food_samples','FARM','MTA',5,'CA_THE','Lưu tối thiểu 24h, tối thiểu 100g/món'),
  ('nhat_ky_lanh','Nhật ký chuỗi lạnh','cold_chain_logs','FARM','NKL',5,'CA_THE',null)
on conflict (object_type) do nothing;
