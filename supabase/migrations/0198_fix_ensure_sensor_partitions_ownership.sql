-- 0198 · Phát hiện khi live-verify alert engine (checklist batch2): ensure_sensor_partitions() thiếu
-- `security definer` — khác các hàm bảo trì cùng loại khác (itran_maintenance, refresh_farm_cache...).
-- app_user không phải chủ sở hữu sensor_reads nên CREATE TABLE ... PARTITION OF bên trong hàm lỗi
-- "must be owner of table sensor_reads". Vì runAlerts() gọi hàm này trong withCtx() (1 transaction),
-- lỗi cuối hàm làm ROLLBACK TOÀN BỘ alert/recon vừa ghi trong cùng lượt chạy — mất âm thầm mỗi khi
-- cần tạo partition tháng mới (không phải hiếm — xảy ra đều đặn hằng tháng).
alter function ensure_sensor_partitions() security definer;
