#!/bin/sh
# Chạy 1 lần khi container khởi động (còn là root): chỉnh quyền các volume bind-mount
# (host tạo mặc định thuộc root, uid 1000 "node" sẽ không ghi được nếu bỏ qua bước này),
# rồi hạ quyền hẳn xuống "node" bằng su-exec trước khi exec CMD thật (node server.js /
# migrate). App/migrate KHÔNG chạy bằng root ở bước cuối.
set -e
for d in /backups /uploads; do
  if [ -d "$d" ]; then chown -R node:node "$d" 2>/dev/null || true; fi
done
exec su-exec node "$@"
