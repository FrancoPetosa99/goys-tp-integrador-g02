#!/usr/bin/env bash
# netem.sh — Fase 4 (D6/Experimento 3): inyecta latencia con tc netem en la
# interfaz del router que da a net-db-remota (pg-replica-2), identificada en
# runtime por su IP (10.31.1.254), nunca por un nombre de interfaz fijo: el
# orden en que Docker crea las interfaces del router no coincide con el
# orden de declaración de `networks:` en el compose (verificado: la interfaz
# resultó ser eth2, no la 3ra declarada).
#
# netem en el qdisc raíz de una interfaz afecta el tráfico que ESA interfaz
# TRANSMITE (egress): como esta es la interfaz del router hacia
# net-db-remota, la latencia agregada es únicamente en el sentido
# router→pg-replica-2. No es un RTT: lo que se mide con ping (ver "show")
# es el efecto real medido, no una suposición.
#
# Uso:
#   demo/scripts/netem.sh add <ms>    agrega/reemplaza el delay (ms)
#   demo/scripts/netem.sh del         quita el qdisc (vuelve a 0ms)
#   demo/scripts/netem.sh show        muestra el qdisc actual y un ping real
#                                      router -> pg-replica-2 (10.31.1.10)
set -Eeuo pipefail

ACTION="${1:?uso: netem.sh <add|del|show> [ms]}"
ROUTER=dbscale-router
TARGET_IP=10.31.1.254
REPLICA2_IP=10.31.1.10

log() { echo "[netem] $*"; }

find_iface() {
  docker exec "$ROUTER" sh -c "ip -o addr show | grep '$TARGET_IP' | awk '{print \$2}'"
}

IFACE="$(find_iface)"
if [ -z "$IFACE" ]; then
  echo "[netem] no se encontró ninguna interfaz con IP ${TARGET_IP} en ${ROUTER}" >&2
  exit 1
fi
log "interfaz hacia net-db-remota: ${IFACE} (detectada por IP ${TARGET_IP})"

case "$ACTION" in
  add)
    MS="${2:?uso: netem.sh add <ms>}"
    case "$MS" in ''|*[!0-9]*) echo "[netem] ms inválido: $MS" >&2; exit 1 ;; esac
    log "aplicando delay=${MS}ms en ${IFACE} (router -> pg-replica-2, egress)"
    # 'replace' es idempotente: si ya había un qdisc netem, lo reemplaza sin
    # error; si no había ninguno, lo crea (A4.5: se puede correr dos veces).
    docker exec "$ROUTER" tc qdisc replace dev "$IFACE" root netem delay "${MS}ms"
    ;;
  del)
    log "quitando netem de ${IFACE} (vuelve a latencia base del enlace)"
    docker exec "$ROUTER" tc qdisc del dev "$IFACE" root 2>/dev/null \
      || log "no había ningún qdisc netem en ${IFACE} (nada que quitar)"
    ;;
  show)
    log "qdisc actual en ${IFACE}:"
    docker exec "$ROUTER" tc qdisc show dev "$IFACE"
    log "ping real router -> pg-replica-2 (${REPLICA2_IP}), 5 paquetes:"
    docker exec "$ROUTER" ping -c5 -W2 "$REPLICA2_IP"
    ;;
  *)
    echo "[netem] acción inválida: $ACTION (usar add|del|show)" >&2
    exit 1
    ;;
esac
