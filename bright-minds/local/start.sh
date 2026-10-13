#!/bin/bash
# Roda o Cérebro localmente, sem Docker: sidecar FastAPI (8005) + backend (5005, serve o frontend compilado).
#   start.sh demo|staging      sobe (perfil = arquivo .env.<perfil> nesta pasta)
#   start.sh <perfil> sync     atualiza o catálogo de tabelas (nao sync) e sobe
#   start.sh stop              derruba os processos
# Requisitos: bun no PATH (ou BUN=...), venv do nao-core (NAO_PY=..., padrão ./.venv/bin/python),
# frontend compilado em apps/frontend/dist (build-frontend.sh).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
BUN="${BUN:-bun}"
NAO_PY="${NAO_PY:-$HERE/.venv/bin/python}"

if [ "${1:-}" = "stop" ]; then
  for f in "$HERE"/run-*/*.pid; do [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null || true; rm -f "$f"; done
  echo "parado"; exit 0
fi

PROFILE="${1:-demo}"
ENV_FILE="$HERE/.env.$PROFILE"
[ -f "$ENV_FILE" ] || { echo "falta $ENV_FILE (copie de .env.$PROFILE.example)"; exit 1; }
[ -d "$REPO/apps/frontend/dist" ] || { echo "falta apps/frontend/dist: rode bright-minds/local/build-frontend.sh"; exit 1; }
set -a; . "$ENV_FILE"; set +a

RUN="$HERE/run-$PROFILE"
mkdir -p "$RUN/context"
cp -a "$REPO/bright-minds/context/." "$RUN/context/"

export MODE=prod NODE_ENV=production POSTHOG_DISABLED=true
export NAO_CONTEXT_SOURCE=local NAO_DEFAULT_PROJECT_PATH="$RUN/context"
export DB_URI="sqlite:$RUN/db.sqlite" SERVER_PORT=5005 FASTAPI_PORT=8005
export BETTER_AUTH_URL="${BETTER_AUTH_URL:-http://localhost:5005}"
export PATH="$(dirname "$NAO_PY"):$PATH"

"$HERE/start.sh" stop >/dev/null 2>&1 || true

if [ "${2:-}" = "sync" ] || [ ! -d "$RUN/context/databases" ]; then
  echo "sincronizando o catálogo (nao sync)..."
  (cd "$RUN/context" && nao sync)
fi

cd "$REPO"
nohup "$NAO_PY" -m uvicorn apps.backend.fastapi.main:app --host 127.0.0.1 --port 8005 > "$RUN/fastapi.log" 2>&1 &
echo $! > "$RUN/fastapi.pid"
nohup "$BUN" run apps/backend/src/cli.ts serve --port 5005 > "$RUN/backend.log" 2>&1 &
echo $! > "$RUN/backend.pid"

for _ in $(seq 1 60); do
  curl -sf -o /dev/null http://localhost:5005/ && { echo "no ar: http://localhost:5005  (perfil $PROFILE, logs em $RUN)"; exit 0; }
  sleep 1
done
echo "o backend não respondeu em 60s; veja $RUN/backend.log"; tail -20 "$RUN/backend.log"; exit 1
