#!/usr/bin/env bash
# replica-entrypoint.sh — alta de una réplica de lectura por streaming físico
# (Fase 3). Reemplaza el ENTRYPOINT por defecto de postgres:17.11 en los
# servicios pg-replica-1/pg-replica-2. Corre con el mismo usuario por
# defecto de la imagen ("postgres", ver .ai/conocimiento/entorno.md: D5 no
# aplica acá porque este contenedor nunca necesita NET_ADMIN ni ip route).
set -Eeuo pipefail

PRIMARY_HOST="${PRIMARY_HOST:?falta PRIMARY_HOST}"
PRIMARY_PORT="${PRIMARY_PORT:-5432}"
REPLICATOR_USER="${REPLICATOR_USER:?falta REPLICATOR_USER}"
REPLICATOR_PASSWORD="${REPLICATOR_PASSWORD:?falta REPLICATOR_PASSWORD}"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"

MAX_RETRIES=30
RETRY_DELAY=2

log() { echo "[replica-entrypoint] $*"; }

if [ -z "$(ls -A "$PGDATA" 2>/dev/null)" ]; then
  log "PGDATA vacío: dando de alta la réplica con pg_basebackup contra ${PRIMARY_HOST}:${PRIMARY_PORT}"
  export PGPASSWORD="$REPLICATOR_PASSWORD"

  attempt=1
  until pg_basebackup \
      -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$REPLICATOR_USER" \
      -D "$PGDATA" -Fp -Xs -P -R; do
    if [ "$attempt" -ge "$MAX_RETRIES" ]; then
      log "pg_basebackup no pudo completarse tras ${MAX_RETRIES} intentos. Abandono."
      exit 1
    fi
    # No distinguimos si todavía falta la ruta por el router (el sidecar de
    # este mismo nodo aplica su "ip route replace" después de que el nodo
    # principal arranca) o si el primario todavía no está aceptando
    # conexiones: en ambos casos la respuesta es reintentar.
    log "intento ${attempt}/${MAX_RETRIES} falló, reintento en ${RETRY_DELAY}s..."
    attempt=$((attempt + 1))
    sleep "$RETRY_DELAY"
    # pg_basebackup puede dejar PGDATA a medio escribir: limpiar antes de
    # reintentar para no mezclar un basebackup parcial con el siguiente.
    find "$PGDATA" -mindepth 1 -delete
  done

  unset PGPASSWORD
  chmod 0700 "$PGDATA"
  log "basebackup completo. standby.signal y primary_conninfo quedaron escritos por -R."
else
  log "PGDATA no está vacío: nodo ya dado de alta, se reinicia el servidor existente."
fi

# docker-entrypoint.sh (oficial de la imagen) detecta PG_VERSION ya presente
# y arranca el servidor directo, sin volver a correr initdb.
exec docker-entrypoint.sh postgres \
  -c config_file=/etc/postgresql/postgresql.conf \
  -c hba_file=/etc/postgresql/pg_hba.conf
