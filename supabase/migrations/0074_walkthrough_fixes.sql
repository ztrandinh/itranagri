-- 0074 · sửa từ đợt đóng vai: kế toán tính lại lương (delete payslips kỳ cũ) cần quyền delete; hosp/others code tự sinh ở API
grant delete on payslips to app_user;
grant delete on payroll_runs to app_user;
