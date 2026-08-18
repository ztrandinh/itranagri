#!/usr/bin/env bash
# Diễn tập phục hồi: restore dump mới nhất vào DB tạm và so đếm. Dùng: bash scripts/restore-drill.sh [container]
export MSYS_NO_PATHCONV=1
set -e; C=${1:-itranos_db}; D=$(ls -t backups/*.dump | head -1); echo "dump: $D"
docker exec $C psql -U postgres -c "drop database if exists itranos_restore" -c "create database itranos_restore" >/dev/null
cat "$D" | docker exec -i $C sh -c "cat > /var/lib/postgresql/r.dump" && docker exec $C pg_restore -U postgres -d itranos_restore --no-owner /var/lib/postgresql/r.dump 2>/dev/null || true
for t in animals animal_events inventory_moves sales journal_entries; do a=$(docker exec $C psql -U postgres -d itranos -Atc "select count(*) from $t"); b=$(docker exec $C psql -U postgres -d itranos_restore -Atc "select count(*) from $t"); echo "$t: live=$a restored=$b"; done
docker exec $C psql -U postgres -c "drop database itranos_restore" >/dev/null; echo "OK — ghi kết quả vào /tuan-thu (ITRAN-STD 6.4)"
