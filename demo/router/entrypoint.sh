#!/bin/sh
set -eu

echo "[entrypoint] router dbscale arrancando..."

if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
  echo "[entrypoint] ERROR: net.ipv4.ip_forward no está en 1." \
       "Revisar 'sysctls:' del servicio router en demo/docker-compose.yml (no se puede fijar desde adentro del contenedor, D4)." >&2
  exit 1
fi

/usr/local/bin/firewall.sh

echo "[entrypoint] firewall aplicado (FIREWALL_MODE=${FIREWALL_MODE:-strict}). router listo."
exec tail -f /dev/null
