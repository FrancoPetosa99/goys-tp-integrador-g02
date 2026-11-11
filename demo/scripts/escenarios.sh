#!/usr/bin/env bash
# escenarios.sh — Fase 4: subir/bajar/consultar un escenario (base|r1|r2)
# sin tocar los datos (a diferencia de reset-estado.sh, que además borra y
# re-siembra los volúmenes de PostgreSQL). Útil para levantar el entorno
# entre experimentos o para los cortes de netem/corte-replica sin pagar el
# costo de un reset completo.
#
# Uso: demo/scripts/escenarios.sh <base|r1|r2> <up|down|status>
#   up     levanta router, pg-primary, api, monitoreo y, si corresponde, las
#          réplicas del escenario, con el READ_DB_HOSTS correcto.
#   down   baja todos los contenedores del laboratorio (perfiles r1 y r2
#          incluidos). Nunca usa `-v`: los volúmenes de datos quedan intactos.
#   status muestra `docker compose ps` filtrado a los servicios del lab.
set -Eeuo pipefail

SCENARIO="${1:?uso: escenarios.sh <base|r1|r2> <up|down|status>}"
ACTION="${2:?uso: escenarios.sh <base|r1|r2> <up|down|status>}"

case "$SCENARIO" in
  base|r1|r2) ;;
  *) echo "[escenarios] escenario inválido: $SCENARIO (usar base|r1|r2)" >&2; exit 1 ;;
esac
case "$ACTION" in
  up|down|status) ;;
  *) echo "[escenarios] acción inválida: $ACTION (usar up|down|status)" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$DEMO_DIR"

COMPOSE=(docker compose --env-file ../.env)
log() { echo "[escenarios] $*"; }

case "$SCENARIO" in
  base) READ_DB_HOSTS_VALUE="10.20.1.10" ;;
  r1)   READ_DB_HOSTS_VALUE="10.30.1.10" ;;
  r2)   READ_DB_HOSTS_VALUE="10.30.1.10,10.31.1.10" ;;
esac

case "$ACTION" in
  up)
    log "escenario=${SCENARIO} · subiendo (sin tocar datos)"
    if [ "$SCENARIO" = "base" ]; then
      READ_DB_HOSTS="$READ_DB_HOSTS_VALUE" "${COMPOSE[@]}" up -d
    else
      READ_DB_HOSTS="$READ_DB_HOSTS_VALUE" "${COMPOSE[@]}" --profile "$SCENARIO" up -d
    fi
    log "escenario=${SCENARIO} arriba. READ_DB_HOSTS=${READ_DB_HOSTS_VALUE}"
    ;;
  down)
    log "bajando todos los perfiles del laboratorio (sin -v: los datos quedan)"
    "${COMPOSE[@]}" --profile r1 --profile r2 --profile carga --profile test-red down
    log "laboratorio abajo."
    ;;
  status)
    "${COMPOSE[@]}" --profile r1 --profile r2 --profile carga ps
    ;;
esac
