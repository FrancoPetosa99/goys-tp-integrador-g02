#!/usr/bin/env bash
# corte-replica.sh — Fase 4 (Experimento 2): para/arranca una réplica de
# lectura (y su sidecar, que comparte su namespace de red) para simular una
# caída en plena carga. Imprime pg_stat_replication del primario antes y
# después, como evidencia de que la réplica realmente entró/salió de
# streaming.
#
# Uso: demo/scripts/corte-replica.sh <replica1|replica2> <stop|start>
set -Eeuo pipefail

REPLICA="${1:?uso: corte-replica.sh <replica1|replica2> <stop|start>}"
ACTION="${2:?uso: corte-replica.sh <replica1|replica2> <stop|start>}"

case "$REPLICA" in
  replica1) SERVICE=pg-replica-1; SIDECAR=sc-pg-replica-1; IP=10.30.1.10 ;;
  replica2) SERVICE=pg-replica-2; SIDECAR=sc-pg-replica-2; IP=10.31.1.10 ;;
  *) echo "[corte-replica] réplica inválida: $REPLICA (usar replica1|replica2)" >&2; exit 1 ;;
esac
case "$ACTION" in
  stop|start) ;;
  *) echo "[corte-replica] acción inválida: $ACTION (usar stop|start)" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$DEMO_DIR"

set -a
# shellcheck disable=SC1091
source ../.env
set +a
export PGPASSWORD="$PG_SUPERUSER_PASSWORD"

COMPOSE=(docker compose --env-file ../.env)
log() { echo "[corte-replica] $*"; }
epoch_ms() { echo $(( $(date +%s%N) / 1000000 )); }

show_replication() {
  log "pg_stat_replication en el primario (client_addr=${IP}):"
  "${COMPOSE[@]}" exec -T -e PGPASSWORD="$PG_SUPERUSER_PASSWORD" pg-primary \
    psql -U "${PG_SUPERUSER_USER:-postgres}" -d "${POSTGRES_DB:-dbscale}" \
    -c "SELECT client_addr, state, replay_lag FROM pg_stat_replication WHERE client_addr = '${IP}';" \
    || log "(sin filas: ${REPLICA} no está en pg_stat_replication)"
}

log "estado ANTES de ${ACTION} ${SERVICE}:"
show_replication

TS_MS=$(epoch_ms)
case "$ACTION" in
  stop)
    log "deteniendo ${SERVICE} y ${SIDECAR} ($(date -Iseconds), ${TS_MS} ms epoch)"
    docker stop "dbscale-${SERVICE}" "dbscale-${SIDECAR}" >/dev/null
    ;;
  start)
    log "arrancando ${SERVICE} ($(date -Iseconds), ${TS_MS} ms epoch)"
    # El sidecar se une al namespace de red del contenedor principal
    # (network_mode: service:<nodo>): tiene que estar corriendo primero, o
    # falla con "cannot join network namespace of a non running container".
    docker start "dbscale-${SERVICE}" >/dev/null
    docker start "dbscale-${SIDECAR}" >/dev/null
    ;;
esac

sleep 3
log "estado DESPUÉS de ${ACTION} ${SERVICE}:"
show_replication
