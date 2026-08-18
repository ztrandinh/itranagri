import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
/** TÌM MỌI ĐỐI TƯỢNG: gõ tên/mã bất kỳ → cá thể · đàn · ô thửa · cây · SKU · nhân sự · đối tác · thiết bị · hạ tầng · mùa vụ · phòng · khách · quy trình. Kết quả trỏ về trang 360 /xem/{type}/{id} */
export async function GET(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const q = (new URL(req.url).searchParams.get("q") ?? "").trim(); if (q.length < 1) return NextResponse.json({ rows: [] });
  const like = `%${q}%`; // so khớp không dấu qua noaccent()
  const sql = `
    select 'animal' as type, id, coalesce(visual_tag,'')||' '||id as title, species||' · '||coalesce(breed,'')||' · '||status||' · '||coalesce(location_id,'') as sub, farm_id from animals where farm_id=$1 and (noaccent(id||' '||coalesce(visual_tag,'')||' '||coalesce(rfid,'')||' '||coalesce(breed,'')) like noaccent($2))
    union all select 'group', id, name, species||' · '||coalesce(head_count::text,'')||' con · '||coalesce(location_id,''), farm_id from animal_groups where farm_id=$1 and (noaccent(id||' '||name||' '||species) like noaccent($2))
    union all select 'plot', id, name, coalesce(crop_code, current_crop,'')||' · '||coalesce(area_ha::text,'')||' ha', farm_id from plots where farm_id=$1 and noaccent(id||' '||name||' '||coalesce(current_crop,'')||' '||coalesce(crop_code,'')) like noaccent($2)
    union all select 'crop', code, name, group_name||' · '||life_cycle||' · '||coalesce(array_to_string(varieties,', '),''), null from crops where noaccent(code||' '||name||' '||array_to_string(varieties,' ')) like noaccent($2)
    union all select 'species', code, name, group_name||' · '||identify_level, null from species where noaccent(code||' '||name) like noaccent($2)
    union all select 'product', sku, name, kind||' · '||coalesce(unit,''), null from products where noaccent(sku||' '||name) like noaccent($2)
    union all select 'staff', id, full_name, role||' · '||coalesce(position,'')||' · '||coalesce(farm_id,'HQ'), farm_id from staff where (farm_id=$1 or farm_id is null or $1=any(farm_ids)) and noaccent(id||' '||full_name||' '||coalesce(position,'')||' '||coalesce(phone,'')) like noaccent($2)
    union all select 'partner', id, name, kind||' · '||coalesce(phone,''), farm_id from partners where (farm_id=$1 or farm_id is null) and noaccent(id||' '||name||' '||coalesce(phone,'')) like noaccent($2)
    union all select 'device', id, name, kind||' · '||coalesce(location_id,''), farm_id from devices where farm_id=$1 and noaccent(id||' '||name) like noaccent($2)
    union all select 'facility', id, name, kind||' · '||coalesce(area_m2::text,'')||' m²', farm_id from facilities where farm_id=$1 and noaccent(code||' '||name) like noaccent($2)
    union all select 'location', id, name, kind||' · '||coalesce(elevation_tier,''), farm_id from locations where farm_id=$1 and noaccent(code||' '||name) like noaccent($2)
    union all select 'warehouse', id, name, code, farm_id from warehouses where farm_id=$1 and noaccent(code||' '||name) like noaccent($2)
    union all select 'season', id, code||' · '||crop, coalesce(variety,'')||' · '||plot_id||' · '||status, farm_id from crop_seasons where farm_id=$1 and noaccent(code||' '||crop||' '||coalesce(variety,'')) like noaccent($2)
    union all select 'lot', id, id, coalesce(sku,'')||' · '||coalesce(status,''), farm_id from lots where farm_id=$1 and id ilike $2
    union all select 'process', code, name, coalesce(dept_code,'')||' · '||coalesce(status,''), null from processes where noaccent(code||' '||name) like noaccent($2)
    union all select 'department', code, name, coalesce(mission,''), null from departments where noaccent(code||' '||name) like noaccent($2)
    union all select 'booking', id, coalesce(guest_name,'')||' · '||code, check_in::text||' → '||check_out::text||' · '||status, farm_id from hosp_bookings where farm_id=$1 and noaccent(code||' '||coalesce(guest_name,'')||' '||coalesce(guest_phone,'')) like noaccent($2)
    limit 60`;
  try { const rows = await withCtx(s, async (c) => (await c.query(sql, [s.farmId, like])).rows); return NextResponse.json({ rows }); }
  catch (e) { return NextResponse.json({ error: "ERR_QUERY", detail: (e as Error).message }, { status: 500 }); }
}
