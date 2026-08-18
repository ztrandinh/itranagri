-- 0028 · sửa metric ICFS theo đúng cột bảng
update standard_requirements set metric_sql='select count(*) from kpi_results where farm_id=$1 and month >= to_char(now()-interval ''1 month'',''YYYY-MM'')' where standard_code='ITRAN-STD' and clause='5.2';
update standard_requirements set metric_sql='select count(*) from lots where farm_id=$1 and status=''KHA_DUNG''' where standard_code='ITRAN-STD' and clause='6.3';
update standard_requirements set metric_sql='select count(*) from incidents where farm_id=$1 and status=''ACTIVE'' and closed_at is null and ts<now()-interval ''7 days''' where standard_code='ITRAN-STD' and clause='7.2';
update standard_requirements set metric_sql='select count(*) from kpi_results where farm_id=$1 and month >= (date_trunc(''month'',now())-interval ''1 month'')::date' where standard_code='ITRAN-STD' and clause='5.2';
