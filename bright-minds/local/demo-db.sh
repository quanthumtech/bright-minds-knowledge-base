#!/bin/bash
# Postgres local descartável com dados FICTÍCIOS + o usuário cerebro_ro (mesmo SQL de produção).
#   demo-db.sh up | down
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME=bm-demo-pg
case "${1:-up}" in
  up)
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    docker run -d --name "$NAME" -e POSTGRES_PASSWORD=demo-local -p 55432:5432 postgres:17 >/dev/null
    until docker exec "$NAME" pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
    sleep 2
    docker exec -i "$NAME" psql -U postgres -d postgres -q -v ON_ERROR_STOP=1 < "$HERE/demo-seed.sql"
    docker exec -i "$NAME" psql -U postgres -d postgres -q -v ON_ERROR_STOP=1 -v ro_password=demo-ro-local -v allow_pii=off < "$HERE/../sql/cerebro-readonly.sql" >/dev/null
    echo "demo-db no ar: localhost:55432, usuario cerebro_ro, senha demo-ro-local"
    ;;
  down) docker rm -f "$NAME" ;;
esac
