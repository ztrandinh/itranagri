-- 0109 · ICFS clause 2.1 bền với batch_logs.inputs KHÔNG phải mảng.
-- Lỗi: jsonb_array_elements(b.inputs) ném "cannot extract elements from an object" khi 1 batch_logs.inputs = {} (object rỗng)
--      → icfs_score('F01') clause 2.1 = ERR → test enterprise "ICFS chấm điểm" đỏ.
-- Guard: chỉ giải mảng khi inputs thực sự là array, ngược lại coi như rỗng. Không đổi logic chấm, chỉ chống crash trên data lệch.
update standard_requirements
  set metric_sql = replace(metric_sql,
    'jsonb_array_elements(b.inputs)',
    'jsonb_array_elements(case when jsonb_typeof(b.inputs)=''array'' then b.inputs else ''[]''::jsonb end)')
  where clause='2.1' and metric_sql like '%jsonb_array_elements(b.inputs)%';
