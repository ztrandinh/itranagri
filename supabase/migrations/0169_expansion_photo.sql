-- 0169 — thêm ẢNH (photo_urls) vào 5 bảng dòng mở rộng để đủ luật 2-bộ-hồ-sơ (giấy+ảnh+số)
-- Công nhân/KTV ghi giấy → chụp ảnh → đính vào bản ghi số. Không phá dữ liệu (chỉ ADD cột nullable).

alter table energy_logs      add column if not exists photo_urls text[] default '{}';
alter table biochar_batches  add column if not exists photo_urls text[] default '{}';
alter table carbon_credits   add column if not exists photo_urls text[] default '{}';
alter table cea_batches      add column if not exists photo_urls text[] default '{}';
alter table duckweed_batches add column if not exists photo_urls text[] default '{}';
