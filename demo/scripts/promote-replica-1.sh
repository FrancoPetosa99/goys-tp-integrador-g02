#!/usr/bin/env bash
# promote-replica-1.sh — Fase 4 (Experimento 4, D7/D8): promueve pg-replica-1
# a primario (pg_ctl promote) y repunta el DNAT de la VIP de escritura
# (10.20.1.100:5432) hacia ella.
#
# Nunca toca demo/router/firewall.sh (es de Franco): repunta la cadena
# DBSCALE_DNAT directamente por `docker exec`, con el mismo patrón
# flush-and-rebuild que ya usa firewall.sh. Como firewall.sh tiene
# PG_PRIMARY=10.20.1.10 fijo y entrypoint.sh lo vuelve a correr en cada
# arranque del router, un "docker compose restart router" revierte la VIP al
# primario original — es el comportamiento esperado (documentado en
# decisiones-tecnicas.md), no un bug, y es la forma de volver al estado
# inicial junto con reset-estado.sh.
#
# D8: pg-replica-2 NO se reapunta al nuevo primario (sin Patroni/repmgr);
# sigue intentando conectarse al primario viejo (caído) hasta que se
# restaure el entorno.
#
# Idempotente (A4.5): si pg-replica-1 ya salió de recovery, no repite
# pg_ctl promote (fallaría con "not in standby mode"), pero siempre
# re-aplica el DNAT.
#
# Uso: demo/scripts/promote-replica-1.sh
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$DEMO_DIR"

set -a
# shellcheck disable=SC1091
source ../.env
set +a
export PGPASSWORD="$PG_SUPERUSER_PASSWORD"

COMPOSE=(docker compose --env-file ../.env)
ROUTER=dbscale-router
VIP=10.20.1.100
NEW_PRIMARY=10.30.1.10

log() { echo "[promote-replica-1] $*"; }
epoch_ms() { echo $(( $(date +%s%N) / 1000000 )); }

is_in_recovery() {
  "${COMPOSE[@]}" exec -T -e PGPASSWORD="$PG_SUPERUSER_PASSWORD" pg-replica-1 \
    psql -U "${PG_SUPERUSER_USER:-postgres}" -tAc "SELECT pg_is_in_recovery();" | tr -d '[:space:]'
}

START_MS=$(epoch_ms)
log "inicio $(date -Iseconds) (${START_MS} ms epoch)"

if [ "$(is_in_recovery)" = "t" ]; then
  log "pg-replica-1 está en standby: promoviendo (pg_ctl promote)"
  # -u postgres: el usuario por defecto de "docker compose exec" en la
  # imagen oficial de postgres es root (el entrypoint oficial arranca como
  # root y recién baja privilegios con gosu para el proceso del servidor);
  # pg_ctl se niega a correr como root.
  "${COMPOSE[@]}" exec -T -u postgres pg-replica-1 pg_ctl promote -D /var/lib/postgresql/data

  attempt=1
  until [ "$(is_in_recovery)" = "f" ]; do
    if [ "$attempt" -ge 30 ]; then
      log "pg-replica-1 no salió de recovery tras 30 intentos. Abandono."
      exit 1
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  PROMOTED_MS=$(epoch_ms)
  log "pg-replica-1 promovida a primario ($(date -Iseconds), ${PROMOTED_MS} ms epoch)"
else
  log "pg-replica-1 ya no está en recovery (promovida en una corrida anterior): no se repite pg_ctl promote"
fi

log "repuntando VIP ${VIP}:5432 -> ${NEW_PRIMARY}:5432 en ${ROUTER} (sin tocar firewall.sh)"
docker exec "$ROUTER" sh -c "
  iptables -t nat -F DBSCALE_DNAT
  iptables -t nat -A DBSCALE_DNAT -p tcp -d ${VIP} --dport 5432 -j DNAT --to-destination ${NEW_PRIMARY}:5432
"
DNAT_MS=$(epoch_ms)
log "VIP repuntada ($(date -Iseconds), ${DNAT_MS} ms epoch). pg-replica-2 sigue sin reapuntarse (D8)."

END_MS=$(epoch_ms)
log "fin $(date -Iseconds) (${END_MS} ms epoch) · duración total $((END_MS - START_MS)) ms"
