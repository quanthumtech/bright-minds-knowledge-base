#!/bin/bash
# Entrypoint do Bright Minds Knowledge Base: copia o contexto versionado (nao_config.yaml, RULES.md)
# para o volume persistente e entrega ao entrypoint original do nao.
# O `nao sync` grava o catálogo em databases/ dentro do volume; a cópia abaixo não apaga esse catálogo.
set -e

SRC=/app/context-src
DST="${NAO_DEFAULT_PROJECT_PATH:-/app/context}"

mkdir -p "$DST"
cp -a "$SRC"/. "$DST"/
chown -R nao:nao "$DST"

exec /entrypoint.sh "$@"
