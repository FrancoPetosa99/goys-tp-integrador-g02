#!/usr/bin/env bash
# reset-estado.sh — D12/A3.6: vuelve PostgreSQL al mismo estado inicial
# (seed limpio de 10 categorías / 500.000 productos) antes de cada corrida
# del Experimento 1. Se corre antes de CADA una de las 9 corridas (no una
# vez por escenario), porque cada prueba de k6 deja escrituras que hay que
# borrar antes de la siguiente.
#
# Borra EXCLUSIVAMENTE los volúmenes de datos de PostgreSQL
# (dbscale_pg-primary-data, dbscale_pg-replica-1-data,
# dbscale_pg-replica-2-data). Nunca toca prometheus-data ni grafana-data:
# esas métricas son las que después se comparan entre corridas.
#
# Uso: demo/scripts/reset-estado.sh <base|r1|r2>
set -Eeuo pipefail

SCENARIO="${1:?uso: reset-estado.sh <base|r1|r2>}"
case "$SCENARIO" in
  base|r1|r2) ;;
  *) echo "[reset-estado] escenario inválido: $SCENARIO (usar base|r1|r2)" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$DEMO_DIR"

# Variables de credenciales/host (PG_SUPERUSER_USER, POSTGRES_DB, etc.) para
# uso operativo de este script. Se cargan sin imprimirlas nunca (CLAUDE.md:
# nunca mostrar el contenido de .env).
set -a
# shellcheck disable=SC1091
source ../.env
set +a

PG_SUPERUSER_USER="${PG_SUPERUSER_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-dbscale}"
# local (socket unix) también exige scram-sha-256 en pg_hba.conf: psql
# necesita PGPASSWORD, no alcanza con que la variable esté en el entorno
# con otro nombre.
export PGPASSWORD="$PG_SUPERUSER_PASSWORD"

COMPOSE=(docker compose --env-file ../.env)

log() { echo "[reset-estado] $*"; }

# epoch_ms: `date +%s%3N` asume GNU date; en este entorno `date` es uutils
# coreutils y el "%3N" no trunca (devuelve los 9 dígitos de nanosegundos
# completos). Se calcula a mano para que sea portable entre las dos.
epoch_ms() { echo $(( $(date +%s%N) / 1000000 )); }

psql_primary() {
  "${COMPOSE[@]}" exec -T -e PGPASSWORD="$PG_SUPERUSER_PASSWORD" pg-primary psql -U "$PG_SUPERUSER_USER" -d "$POSTGRES_DB" -tAc "$1"
}

case "$SCENARIO" in
  base) READ_DB_HOSTS_VALUE="10.20.1.10" ;;
  r1)   READ_DB_HOSTS_VALUE="10.30.1.10" ;;
  r2)   READ_DB_HOSTS_VALUE="10.30.1.10,10.31.1.10" ;;
esac

START_MS=$(epoch_ms)
log "escenario=${SCENARIO} · inicio $(date -Iseconds) (${START_MS} ms epoch)"

# --- 1. Parar y quitar los nodos de PostgreSQL, sus sidecars y api ---------
log "deteniendo pg-primary, réplicas, exporters, api y sus sidecars"
"${COMPOSE[@]}" --profile carga --profile r1 --profile r2 rm -f -s \
  pg-primary sc-pg-primary \
  pg-replica-1 sc-pg-replica-1 \
  pg-replica-2 sc-pg-replica-2 \
  pg-exporter-1 sc-pg-exporter-1 \
  pg-exporter-2 sc-pg-exporter-2 \
  api sc-api

# --- 2. Borrar SOLO los 3 volúmenes de datos de PostgreSQL -----------------
for vol in dbscale_pg-primary-data dbscale_pg-replica-1-data dbscale_pg-replica-2-data; do
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    log "borrando volumen ${vol}"
    docker volume rm "$vol" >/dev/null
  fi
done

# --- 3. Primario fresco: dispara init.sql/roles.sql/seed.sql ---------------
log "levantando pg-primary fresco (re-siembra 10 categorías / 500.000 productos)"
"${COMPOSE[@]}" up -d pg-primary sc-pg-primary

log "esperando a que el primario acepte conexiones..."
attempt=1
until "${COMPOSE[@]}" exec -T pg-primary pg_isready -U "$PG_SUPERUSER_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
  if [ "$attempt" -ge 60 ]; then
    log "el primario no respondió pg_isready tras 60 intentos. Abandono."
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 2
done
log "primario listo."

log "esperando a que el seed termine de insertar productos..."
count=0
attempt=1
while [ "$count" -lt 500000 ]; do
  if [ "$attempt" -ge 120 ]; then
    log "el seed no completó tras 120 intentos (último conteo: ${count}). Abandono."
    exit 1
  fi
  count="$(psql_primary 'select count(*) from products;' 2>/dev/null || echo 0)"
  attempt=$((attempt + 1))
  sleep 2
done
log "seed completo: ${count} productos."

# --- 4. Réplicas, si el escenario las necesita ------------------------------
if [ "$SCENARIO" = "r1" ] || [ "$SCENARIO" = "r2" ]; then
  log "levantando réplica(s) del escenario ${SCENARIO} (perfil ${SCENARIO})"
  "${COMPOSE[@]}" --profile "$SCENARIO" up -d

  if [ "$SCENARIO" = "r1" ]; then
    REPLICA_IPS="10.30.1.10"
  else
    REPLICA_IPS="10.30.1.10 10.31.1.10"
  fi

  for ip in $REPLICA_IPS; do
    log "esperando a que ${ip} aparezca como 'streaming' en pg_stat_replication..."
    state=""
    attempt=1
    while [ "$state" != "streaming" ]; do
      if [ "$attempt" -ge 60 ]; then
        log "${ip} no llegó a 'streaming' tras 60 intentos (último estado: ${state:-ninguno}). Abandono."
        exit 1
      fi
      state="$(psql_primary "select state from pg_stat_replication where client_addr = '${ip}';" 2>/dev/null || echo "")"
      attempt=$((attempt + 1))
      sleep 2
    done
    log "${ip} en streaming."
  done
fi

# --- 5. ANALYZE explícito en el primario ------------------------------------
log "ANALYZE en el primario"
"${COMPOSE[@]}" exec -T -e PGPASSWORD="$PG_SUPERUSER_PASSWORD" pg-primary psql -U "$PG_SUPERUSER_USER" -d "$POSTGRES_DB" -c "ANALYZE;" >/dev/null

# --- 6. Recrear api con el READ_DB_HOSTS del escenario ----------------------
log "recreando api con READ_DB_HOSTS=${READ_DB_HOSTS_VALUE}"
READ_DB_HOSTS="$READ_DB_HOSTS_VALUE" "${COMPOSE[@]}" up -d api sc-api

END_MS=$(epoch_ms)
DURATION_MS=$((END_MS - START_MS))
log "escenario=${SCENARIO} · fin $(date -Iseconds) (${END_MS} ms epoch) · duración ${DURATION_MS} ms (~$((DURATION_MS / 1000)) s)"
