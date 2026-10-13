#!/bin/bash
# Atualiza o catálogo de tabelas/colunas que o Cérebro enxerga (nao sync). Roda no SERVIDOR.
# Rode depois de reexecutar cerebro-readonly.sql (mudou o schema do CRM) e quando quiser renovar o catálogo.
set -euo pipefail
NAO="${NAO:-$(docker ps --format '{{.Names}}' | grep -E 'nao-1$|knowledge-base.*nao' | head -n 1)}"
[ -n "$NAO" ] || { echo "defina NAO=<nome do container do nao>"; exit 1; }
docker exec -u nao -w /app/context "$NAO" nao sync
