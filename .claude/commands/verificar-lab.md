---
description: Corre las pruebas de humo del laboratorio y reporta el resultado con evidencia
argument-hint: [fase opcional, por ejemplo 2]
---

Corré las pruebas de humo del laboratorio para la fase indicada en `$ARGUMENTS` (si está vacío, la fase actual según `.ai/plan/fases.md`). Cada prueba se ejecuta con comandos reales y se reporta como OK o FALLA con el comando y su salida resumida.

Pruebas disponibles (ejecutá solo las que correspondan a la fase y estén construidas):
- **Red:** ping entre segmentos pasando por el router, `traceroute`, `ip_forward=1` en el router, reglas de `iptables -S FORWARD` del router.
- **Segmentación:** conexión a 5432 desde `net-clientes` (debe fallar), sin salida a Internet (`ping -c1 -W2 1.1.1.1` debe fallar), VIP `10.20.1.100:5432` alcanzable desde `net-app`.
- **Base de datos:** `pg_stat_replication` en el primario, réplicas rechazan escrituras, `app_reader` no puede hacer `INSERT`, `monitor` no puede leer tablas.
- **App:** los 8 endpoints, `/health` y `/metrics`.
- **Monitoreo:** targets de Prometheus en `up`, dashboard provisionado en Grafana.

No modifiques archivos del repo. No uses `sudo`. Al final, listá qué falló y cuál sería el siguiente paso, sin corregir nada hasta que lo apruebe una persona.
