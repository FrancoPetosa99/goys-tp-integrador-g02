#!/bin/sh
set -eu

# FIREWALL_MODE=strict (default): solo las reglas de negocio de la propuesta §2.4.
# FIREWALL_MODE=permisivo: además habilita ICMP entre segmentos, SOLO para diagnóstico
# (A1.4, ping/traceroute entre segmentos). Nunca afloja las reglas de negocio.
# Correr a mano para cambiar de modo sin recrear el contenedor:
#   docker compose exec router sh -c 'FIREWALL_MODE=permisivo firewall.sh'
#   docker compose exec router firewall.sh   # vuelve a strict
MODE="${FIREWALL_MODE:-strict}"

API=10.10.1.10
PG_PRIMARY=10.20.1.10
PG_REPLICA1=10.30.1.10
PG_REPLICA2=10.31.1.10
CLIENTES=10.50.1.10
PROMETHEUS=10.40.1.20
EXPORTER_P=10.40.1.31
EXPORTER_R1=10.40.1.32
EXPORTER_R2=10.40.1.33
VIP=10.20.1.100

echo "[firewall] modo: $MODE"

# --- Cadenas propias: se crean si no existen, o se flushean si ya existen.
# Esto + reconstruirlas enteras en cada corrida es lo que hace idempotente el script
# (A1.9: "docker compose restart router" no duplica reglas). ---
iptables -N DBSCALE_FWD  2>/dev/null || iptables -F DBSCALE_FWD
iptables -N DBSCALE_DIAG 2>/dev/null || iptables -F DBSCALE_DIAG

# --- Reglas de negocio (propuesta §2.4), siempre presentes en ambos modos ---
iptables -A DBSCALE_FWD -p tcp -s "$CLIENTES"    -d "$API"        --dport 8000 -j ACCEPT
iptables -A DBSCALE_FWD -p tcp -s "$CLIENTES"    -d "$PROMETHEUS" --dport 9090 -j ACCEPT
iptables -A DBSCALE_FWD -p tcp -s "$API"         -d "$PG_PRIMARY"  --dport 5432 -j ACCEPT
iptables -A DBSCALE_FWD -p tcp -s "$API"         -d "$PG_REPLICA1" --dport 5432 -j ACCEPT
iptables -A DBSCALE_FWD -p tcp -s "$API"         -d "$PG_REPLICA2" --dport 5432 -j ACCEPT
iptables -A DBSCALE_FWD -p tcp -s "$PG_REPLICA1" -d "$PG_PRIMARY"  --dport 5432 -j ACCEPT
iptables -A DBSCALE_FWD -p tcp -s "$PG_REPLICA2" -d "$PG_PRIMARY"  --dport 5432 -j ACCEPT
for exporter in "$EXPORTER_P" "$EXPORTER_R1" "$EXPORTER_R2"; do
  for db in "$PG_PRIMARY" "$PG_REPLICA1" "$PG_REPLICA2"; do
    iptables -A DBSCALE_FWD -p tcp -s "$exporter" -d "$db" --dport 5432 -j ACCEPT
  done
done
iptables -A DBSCALE_FWD -p tcp -s "$PROMETHEUS" -d "$API" --dport 8000 -j ACCEPT

# --- Modo permisivo de diagnóstico: solo agrega ICMP ---
if [ "$MODE" = "permisivo" ]; then
  iptables -A DBSCALE_DIAG -p icmp -j ACCEPT
  echo "[firewall] PERMISIVO: ICMP habilitado entre segmentos (diagnóstico A1.4; no usar para A1.5 en adelante)"
fi

# --- Enganche en FORWARD: flush-and-rebuild completo, nunca se duplica ---
iptables -P FORWARD DROP
iptables -F FORWARD
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -j DBSCALE_DIAG
iptables -A FORWARD -j DBSCALE_FWD
# la política DROP de FORWARD descarta todo lo que no matcheó arriba

# --- VIP de escritura: DNAT sin SNAT (D7), cadena propia también flush-and-rebuild ---
iptables -t nat -N DBSCALE_DNAT 2>/dev/null || iptables -t nat -F DBSCALE_DNAT
iptables -t nat -A DBSCALE_DNAT -p tcp -d "$VIP" --dport 5432 -j DNAT --to-destination "$PG_PRIMARY":5432
# el salto desde PREROUTING se agrega una sola vez (no se flushea PREROUTING: ahí también viven reglas de Docker)
iptables -t nat -C PREROUTING -j DBSCALE_DNAT 2>/dev/null || iptables -t nat -A PREROUTING -j DBSCALE_DNAT

echo "[firewall] reglas aplicadas. FORWARD: $(iptables -S FORWARD | wc -l) líneas, DBSCALE_FWD: $(iptables -S DBSCALE_FWD | wc -l) líneas."
