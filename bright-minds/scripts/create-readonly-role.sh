#!/bin/bash
# Cria/atualiza o usuário somente leitura `cerebro_ro` e o schema `cerebro` no banco do Supabase
# auto-hospedado. Roda no SERVIDOR (SSH), onde o Docker do Dokploy está.
#
#   DB=<container-do-banco> ./create-readonly-role.sh              # senha gerada e mostrada uma vez
#   DB=<container> CEREBRO_RO_PASSWORD=... ALLOW_PII=on ./create-readonly-role.sh
set -euo pipefail

DB="${DB:-$(docker ps --format '{{.Names}}' | grep -- '-db-1$' | head -n 1)}"
[ -n "$DB" ] || { echo "defina DB=<nome do container do banco>"; exit 1; }
DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS="${CEREBRO_RO_PASSWORD:-$(openssl rand -hex 16)}"
PII="${ALLOW_PII:-off}"

docker exec -i "$DB" psql -U supabase_admin -d postgres \
  -v ro_password="$PASS" -v allow_pii="$PII" < "$DIR/sql/cerebro-readonly.sql"

NET="$(docker inspect "$DB" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')"
echo
echo "Valores para o Environment do Dokploy (o serviço do Cérebro):"
echo "  CRM_DB_HOST=$DB"
echo "  CRM_DB_USER=cerebro_ro"
echo "  CRM_DB_PASSWORD=$PASS"
echo "  SUPABASE_NETWORK=<uma destas redes do container do banco: $NET>"
echo "(a rede do Supabase NÃO é 'dokploy-network' se o container tiver uma rede própria listada)"
