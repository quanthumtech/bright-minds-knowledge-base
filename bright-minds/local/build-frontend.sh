#!/bin/bash
# Compila o frontend (precisa de Node 22; o do host pode ser outro, então usa um contêiner) e
# coloca o resultado em apps/frontend/dist, que o backend serve em produção.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$(mktemp -d)"
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$REPO":/src:ro -v "$OUT":/out node:22-slim bash -lc '
  set -e; mkdir /tmp/w && cd /src && tar cf - --exclude=node_modules --exclude=.git --exclude=dist . | tar xf - -C /tmp/w
  cd /tmp/w && npm i -g --prefix /tmp/npm bun >/dev/null 2>&1 && export PATH=/tmp/npm/bin:$PATH
  bun install --ignore-scripts >/dev/null 2>&1 && cd apps/frontend && npx vite build >/dev/null 2>&1 && cp -r dist/. /out/'
rm -rf "$REPO/apps/frontend/dist" && mkdir -p "$REPO/apps/frontend/dist" && cp -r "$OUT"/. "$REPO/apps/frontend/dist/" && rm -rf "$OUT"
echo "frontend compilado em apps/frontend/dist"
