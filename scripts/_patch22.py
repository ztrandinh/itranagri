import io
R="F:/ITRAN FARM/itran-os/"
def rw(p, fn): s=io.open(R+p,encoding="utf-8").read(); n=fn(s); assert n!=s, p; io.open(R+p,"w",encoding="utf-8",newline="\n").write(n); print("ok",p)
# events
def ev(s):
    s=s.replace("  harvests: z.object({", '''  irrigation_logs: z.object({ ...base, plot_id: z.string(), season_id: z.string().nullable().optional(), method: z.string().nullable().optional(), minutes: num.nullable().optional(), volume_m3: num.nullable().optional(), flow_m3h: num.nullable().optional(), water_source: z.string().nullable().optional(), pump_id: z.string().nullable().optional(), energy_kwh: num.nullable().optional(), ec_water: num.nullable().optional(), ph_water: num.nullable().optional(), note: z.string().nullable().optional() }),
  pest_scouting: z.object({ ...base, plot_id: z.string(), season_id: z.string().nullable().optional(), pest: z.string(), pest_kind: z.string().nullable().optional(), stage: z.string().nullable().optional(), density: num.nullable().optional(), unit: z.string().nullable().optional(), threshold: num.nullable().optional(), sample_points: num.nullable().optional(), incidence_pct: num.nullable().optional(), severity: num.nullable().optional(), natural_enemies: z.string().nullable().optional(), ipm_level: z.string().nullable().optional(), action: z.string().nullable().optional(), action_due: z.string().nullable().optional(), note: z.string().nullable().optional() }),
  harvests: z.object({''',1)
    s=s.replace('  crop_inputs: ["worker","team_lead","tech_head","director"], harvests:','  irrigation_logs: ["worker","team_lead","tech_head","director"], pest_scouting: ["worker","team_lead","tech_head","director"], crop_inputs: ["worker","team_lead","tech_head","director"], harvests:',1)
    return s
rw("src/lib/events.ts", ev)
rw("src/lib/admin.ts", lambda s: s.replace('  { table: "plots", pk: "id",', '''  { table: "weather_daily", pk: "day", label: "Thời tiết ngày (ET0 tự tính FAO-56)", group: "Trại", farmScoped: true, softDelete: null, writeRoles: OPS },
  { table: "soil_tests", pk: "id", label: "Phân tích đất theo ô", group: "Trại", farmScoped: true, softDelete: "status", writeRoles: OPS, codePrefix: "SOIL" },
  { table: "crop_rotation_plans", pk: "id", label: "Kế hoạch luân canh nhiều năm", group: "Trại", farmScoped: true, softDelete: "status", writeRoles: OPS, codePrefix: "ROT" },
  { table: "plot_contracts", pk: "id", label: "Hợp đồng liên kết hộ / thuê đất theo ô", group: "Trại", farmScoped: true, softDelete: "status", writeRoles: OPS, codePrefix: "PLC" },
  { table: "crop_kc", pk: "crop_code", label: "Hệ số cây trồng Kc (FAO-56)", group: "Danh mục", farmScoped: false, softDelete: null, writeRoles: OPS },
  { table: "plots", pk: "id",''',1).replace('export const IMPORT_EVENT_TABLES = ["inventory_moves",','export const IMPORT_EVENT_TABLES = ["irrigation_logs", "pest_scouting", "inventory_moves",',1))
rw("src/lib/queries.ts", lambda s: s.replace("  crop_inputs_recent: {", '''  weather_recent: { sql: "select * from weather_daily where farm_id=$1 order by day desc limit 120" },
  water_balance: { sql: "select * from v_water_balance where farm_id=$1 order by sow_date desc" },
  irrigation_recent: { sql: "select i.*, p.name as plot_name from irrigation_logs i left join plots p on p.id=i.plot_id where i.farm_id=$1 and i.status='ACTIVE' order by ts desc limit 300" },
  pest_recent: { sql: "select ps.*, p.name as plot_name from pest_scouting ps left join plots p on p.id=ps.plot_id where ps.farm_id=$1 and ps.status='ACTIVE' order by ts desc limit 300" },
  soil_tests: { sql: "select st.*, p.name as plot_name from soil_tests st left join plots p on p.id=st.plot_id where st.farm_id=$1 and st.status='ACTIVE' order by sampled_at desc" },
  rotation_check: { sql: "select * from v_rotation_check where farm_id=$1 order by plot_id, year, season_no" },
  plot_contracts: { sql: "select pc.*, p.name as plot_name, pt.name as partner_name from plot_contracts pc left join plots p on p.id=pc.plot_id left join partners pt on pt.id=pc.partner_id where pc.farm_id=$1 and pc.status<>'HUY' order by pc.end_date" },
  crop_kc: { sql: "select * from crop_kc order by crop_code, array_position(array['INI','DEV','MID','END'], stage)" },
  crop_inputs_recent: {''',1))
rw("src/lib/anychart.ts", lambda s: s.replace('  { table: "crop_logs", label:', '''  { table: "weather_daily", label: "Thời tiết ngày (tmin/tmax/mưa/ET0)", ts: "day", status: false },
  { table: "irrigation_logs", label: "Tưới (m3, phút, kWh)", ts: "ts", status: true },
  { table: "pest_scouting", label: "Điều tra dịch hại IPM (mật độ, % nhiễm)", ts: "ts", status: true },
  { table: "soil_tests", label: "Phân tích đất (pH, OM, N/P/K)", ts: "sampled_at", status: false },
  { table: "crop_logs", label:''',1))
