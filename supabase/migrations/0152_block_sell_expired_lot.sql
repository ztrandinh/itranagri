-- 0152 · CHẶN BÁN LÔ HẾT HẠN (an toàn thực phẩm) — mảnh còn thiếu khép vòng ATTP.
--
-- trg_sales_qc_hold (0094/0139) chỉ chặn lô GIU_QC/THU_HOI, KHÔNG chặn lô HẾT HẠN → hiện vẫn bán được
-- hàng quá hạn. Bổ sung chốt chặn: bán lô đã hết hạn → ERR_LOT_EXPIRED.
--
-- AN TOÀN có chủ đích (né phá seed/rebuild/phiên khác):
--   • Trigger RIÊNG (không sửa trigger QC của verifier → không đụng độ merge).
--   • SKIP is_backfill + source IMPORT/BACKFILL (198 đơn IMPORT lịch sử của seed vẫn vào được → rebuild sạch).
--   • Có OVERRIDE: detail->>'override_by' (người có thẩm quyền bán thanh lý có lý do — như guard ngưng thuốc).

create or replace function trg_sales_expiry_block() returns trigger language plpgsql as $$
declare exp date; begin
  if new.lot_id is not null
     and not coalesce(new.is_backfill, false)
     and coalesce(new.source, 'APP') not in ('IMPORT','BACKFILL')
     and coalesce(new.detail->>'override_by', '') = '' then
    select expiry_date into exp from lots where id = new.lot_id and farm_id = new.farm_id;
    if exp is not null and exp < new.ts::date then
      raise exception 'ERR_LOT_EXPIRED: lô % hết hạn ngày % — không được bán (cần override có lý do)', new.lot_id, exp;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists sales_expiry_block on sales;
create trigger sales_expiry_block before insert on sales for each row execute function trg_sales_expiry_block();
