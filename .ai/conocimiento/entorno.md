# Entorno verificado (máquina de desarrollo y demo principal)

Relevado en solo lectura el 9/11/2026. Todo lo de abajo está **verificado**, salvo lo marcado.

## Sistema
- WSL2 (`6.18.33.2-microsoft-standard-WSL2`), 16 CPUs, ~18 GiB de RAM, 5 GiB de swap, ~939 GB de disco libre.
- Sin `.wslconfig` (sin límites explícitos).
- El agente **no tiene sudo**.
- Git 2.53.0. Remoto `origin` por HTTPS, sin `credential.helper`. Identidad global: `MartinEliseche <tinchoeliseche@gmail.com>`. Existe un par de claves SSH sin uso en este remoto.
- Desde la Fase 1, cada fase se trabaja en su propia rama (creada desde `main`, pusheada a `origin`) que se mergea a `main` al cerrarla.

## Docker
- Docker Engine 29.9.2 nativo en WSL2 (no Docker Desktop), Compose v5.6.1, cgroup v2, storage `overlayfs`.
- `iptables v1.8.11 (nf_tables)`. Host: `FORWARD` con política DROP, `br_netfilter` activo (`bridge-nf-call-iptables=1`), tabla `raw` vacía. No existe `/etc/docker/daemon.json`.
- Hay un stack ajeno: `goys-vuln-lab` (no tocar).

## Imágenes con versión fija (ya descargadas)
| Imagen | Tag |
|---|---|
| alpine | `3.24.4` |
| postgres | `17.11` |
| python | `3.12.16-slim` |
| grafana/k6 | `2.3.0` |
| prom/prometheus | `v3.16.0` |
| grafana/grafana | `13.3.0` |
| prometheuscommunity/postgres-exporter | `v0.20.1` |
| gcr.io/cadvisor/cadvisor | `v0.55.1` |

## Puertos del host
- Libres: 3000, 8000, 9090, 9091.
- **5432 ocupado** por un PostgreSQL nativo de WSL. No se publica ninguna base al host, así que no hay conflicto.

## Herramientas del host
- `make` 4.4.1 y `python3` 3.14.4 instalados (la app corre en contenedor, la versión del host no importa).
- **Ansible `2.20.1` ya instalado** (verificado en fase 5: la tarea manual de fase 0 se cumplió). **Sin `pip` ni `k6`** en el host; k6 sigue corriendo en contenedor, sin cambios ahí.

## Resultados de las pruebas de red
| Prueba | Resultado |
|---|---|
| `tc qdisc ... netem delay` con solo `NET_ADMIN` | Funciona (imagen alpine con `iproute2`). |
| `sysctl -w net.ipv4.ip_forward=1` dentro del contenedor | **Falla** (`Read-only file system`). Se fija con `sysctls:` en el Compose. |
| `iptables` FORWARD y DNAT (tabla nat) dentro del contenedor | Funciona con `NET_ADMIN`. |
| Ruteo entre dos redes vía contenedor router, red `nat` por defecto | **Falla** (100% de pérdida; el paquete no llega al router). |
| Ídem con `gateway_mode_ipv4=nat-unprotected` | Funciona. |
| Ídem con `nat-unprotected` + `enable_ip_masquerade=false` | Funciona. |
| Ídem con `gateway_mode_ipv4=routed` | Funciona. |
| `iptables -A FORWARD -j DROP` dentro del router (con la variante que funciona) | Corta el tráfico; al quitarla vuelve. El firewall del router tiene control real. |
| cAdvisor | Corre y reporta CPU por contenedor. |
| Publicación de puertos (`ports: "3000:80"`) en una red con `nat-unprotected` + `enable_ip_masquerade=false` | Funciona: `nc -zv -w2 localhost 3000` responde (fase 1, A1.8). |
| Salida a Internet desde nodos en esas redes | **No hay**: `ping -c1 -W2 1.1.1.1` falla desde `t-clientes`, `t-db` y el propio router (fase 1, A1.6). |

## Rutas por defecto en contenedores sin privilegios (fase 2, motivó D5)
| Imagen | Tiene `ip` | Usuario por defecto | `NET_ADMIN` + `ip route replace` |
|---|---|---|---|
| `postgres:17.11` | No | `postgres` | — (no aplica, además nunca se le da `NET_ADMIN`) |
| `python:3.12.16-slim` (base de `app/`) | No | configurable (`appuser`, no root) | — (no aplica) |
| `prom/prometheus:v3.16.0` | Sí | `nobody` (65534) | **Falla**: `Operation not permitted` |
| `prometheuscommunity/postgres-exporter:v0.20.1` | Sí | `nobody` (65534) | **Falla**: `Operation not permitted` |
| `grafana/grafana:13.3.0` | Sí | `472` (`grafana`) | **Falla**: `Operation not permitted` |
| `grafana/k6:2.3.0` | Sí | `12345` (`k6`) | **Falla**: `Operation not permitted` |
| `gcr.io/cadvisor/cadvisor:v0.55.1` | Sí | `root` (0) | **Funciona** |

Probado con un contenedor real y una red Docker descartable (misma config de `driver_opts` que el laboratorio): `cap_add: NET_ADMIN` no alcanza si el proceso no corre como root, aunque el binario `ip` esté presente. Consecuencia para D5: sidecar `alpine:3.24.4` (que sí corre como root) para todo nodo que cruce de subred y no sea `cadvisor`.

## cAdvisor sin `privileged: true` (fase 2, A2.6)
Con los mounts de solo lectura estándar (`/rootfs`, `/var/run`, `/sys`, `/var/lib/docker`, `/dev/disk`, `/var/run/docker.sock`) y `-docker_only=true`, cAdvisor en Docker Engine 29.9.2 (cgroup v2, overlayfs) **etiqueta correctamente por `container_name` real** (`container_cpu_usage_seconds_total{name="dbscale-pg-primary"}`, etc.) sin necesitar `privileged: true`.

## k6 2.3.0: nombre del output de Prometheus (D14)
`k6 run -o <inválido>` devuelve la lista de outputs soportados; incluye `experimental-prometheus-rw` (variable de entorno `K6_PROMETHEUS_RW_SERVER_URL`), sin cambios respecto a versiones anteriores de k6.

## `.env` fuera de `demo/` (D19)
`docker compose` resuelve `.env` según el directorio del **archivo compose**, no el directorio desde el que se invoca el comando. Probado con una red/compose descartable: un `.env` en el directorio padre de donde vive `docker-compose.yml` no se carga aunque la terminal esté parada ahí. Como `.env` vive en la raíz del repo, todo comando debe incluir `--env-file ../.env` (invocando desde `demo/`).

## Réplicas de lectura (fase 3)
- `pg_basebackup -R` desde `demo/postgres/replica-entrypoint.sh` funciona sin reintentos en condiciones normales (primario ya arriba y accesible por el router): alta completa en los pocos segundos que toma copiar ~500.000 filas en esta máquina.
- `demo/scripts/reset-estado.sh <escenario>` tarda, de punta a punta (parar servicios, borrar volúmenes, recrear primario, esperar seed de 500.000 productos, levantar réplicas y esperar `streaming`, `ANALYZE`, recrear `api`): ~33-35 s sin réplicas, ~55-59 s con 1 réplica, ~63-73 s con 2 réplicas. Medido en 7 corridas reales durante el Experimento 1 (`k6-results/experimento-1.log`).
- `pg_stat_replication` muestra `state=streaming` y `replay_lag` del orden de decenas de milisegundos en esta máquina (sin latencia de red inyectada: eso es fase 4) para ambas réplicas simultáneas.
- `rate(container_cpu_usage_seconds_total{name="dbscale-pg-primary"}[D])` en Prometheus (con `D` = duración de la corrida) es la forma usada para medir el CPU promedio de un nodo durante una corrida completa de k6; `cadvisor` sigue etiquetando por `container_name` real también para los nuevos nodos (réplicas y sus exporters), sin necesitar cambios.
- Con el límite de recursos de `.env.example` (PostgreSQL 2 CPUs, API y k6 4 CPUs cada uno), en ninguna de las 9 corridas del Experimento 1 la API o k6 se acercaron a su límite mientras PostgreSQL (primario o réplica) sí: no hizo falta ajustar D11 en esta fase.

## Réplicas de lectura, detección de fallos y red (fase 4)
- Interfaz del router hacia `net-db-remota` (IP `10.31.1.254`): resultó `eth2` en esta corrida. El orden de creación de interfaces de Docker **no coincide** con el orden de declaración de `networks:` en el compose; `netem.sh` la detecta siempre en runtime por IP, nunca por nombre fijo.
- `tc netem delay` en el qdisc raíz de una interfaz del router afecta solo el tráfico que esa interfaz **transmite** (egress): medido con `ping` real desde el router, 50ms configurado dio ~50.383ms de RTT (no ~100ms), confirmando que solo afecta un sentido.
- `postgres-exporter` v0.20.1 expone de fábrica (sin custom queries): `pg_up` (1/0, conexión del exporter a Postgres — distinto de `up`, que es la métrica de Prometheus sobre si el scrape HTTP tuvo éxito), `pg_replication_is_replica` (1/0, cambia solo tras un failover real), `pg_replication_lag_seconds` (lado réplica, no sirve para medir lag de red: crece sin escrituras nuevas), y `pg_stat_replication_pg_wal_lsn_diff` (lado primario, bytes de WAL sin confirmar por cada réplica — la métrica usada para el lag de la fase 4).
- `up{job="pg-exporter-X"}==0` solo refleja fallos de **scrape HTTP** del exporter; cuando la base caída es la que el exporter monitorea, `up` puede volver a 1 en segundos (el exporter sigue respondiendo) mientras `pg_up` se mantiene en 0 todo el tiempo que la base esté caída.
- Parar/arrancar manualmente **solo** el nodo principal de un par sidecar (sin tocar `sc-*`) puede dejar el namespace de red reconstruido sin la ruta de D5 hacia el router: el nodo queda "Up" pero aislado de otras subredes. Diagnosticado con `docker exec <sidecar> ip route` (vacío o sin `default via`); se corrige reiniciando el sidecar. Pasó dos veces en esta sesión (con `pg-primary` y con `prometheus`).
- Recrear `api` (`docker compose up -d --force-recreate api`) sin pasar explícitamente **tanto** `READ_DB_HOSTS` como `READ_FALLBACK_TO_PRIMARY` hace que la variable omitida vuelva al valor de `.env` (el de base única), no al del escenario activo.
- Sin `connect_timeout` en la conninfo de psycopg, una conexión hacia un host inalcanzable (contenedor parado) puede colgar hasta el timeout por defecto de `psycopg_pool` (~30s), bloqueando el worker de gunicorn que atendía ese request. Con `connect_timeout=2` + `timeout=3` a nivel pool, el peor caso medido por request bajo carga real (20 VUs) fue exactamente 3s.
- Promover una réplica (`pg_ctl promote`) vía `docker compose exec` necesita `-u postgres` explícito: el usuario por defecto de `exec` en la imagen oficial de `postgres:17.11` es `root` (el entrypoint oficial arranca como root y baja privilegios recién para el proceso del servidor con `gosu`); `pg_ctl` se niega a correr como root.
- Tiempo de failover manual (`docker stop pg-primary` → primera escritura exitosa, con `promote-replica-1.sh` ya corregido): 2,8s en la corrida limpia. `pg_ctl promote` + repunte del DNAT tardó 2,1-3,4s en las 3 corridas medidas; el resto del tiempo (variable, de casi 0 a 25s según la corrida) es reconexión del pool de la app, no de PostgreSQL.
- `pg_ctl: cannot be run as root` (ver arriba) es el único bug real encontrado en un script nuevo de esta fase; se corrigió antes de la medición final.

## Verificación Fase 6 — A6.3

Corrido hoy (12/11/2026), en esta máquina WSL2, 3 ciclos completos reales de `docker compose up`/`down` sobre el escenario r2 (2 réplicas), cada uno con `--pull never` (cero pulls de red en los 3 — confirma A1.6/D3 también a nivel de arranque del stack, no solo de ruteo) y sin usar `-v` en ningún `down`. El ciclo 3 incluyó además un failover real (`promote-replica-1.sh`), seguido de `reset-estado.sh r2` y `docker compose restart router` para dejar todo en el estado correcto (verificado: VIP de vuelta a `10.20.1.10`, ambas réplicas en `streaming`).

| Ciclo | `up -d --pull never` | Primario `pg_isready` (desde el `up`) | Ambas réplicas `streaming` (desde el `up`) | API responde 200 en `/products` (desde el `up`) | Secuencia de demo corta | `down` |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 905 ms | 1448 ms | 6683 ms | confirmado manualmente 200 OK (el chequeo automático de ese ciclo tenía un bug de medición con `curl`, corregido para los ciclos 2-3; el stack sí estaba sano) | 61620 ms (~62 s) | 24069 ms (~24 s) |
| 2 | 10948 ms | 11577 ms | 16547 ms | 17559 ms (~17,6 s) | 61635 ms (~62 s) | 24135 ms (~24 s) |
| 3 (con failover real) | 10669 ms | 11150 ms | 16133 ms | 17064 ms (~17 s) | 64026 ms (~64 s): 30 GET reales (~23 s), `netem add 50ms`+`show`+`del` (~5 s), `corte-replica.sh replica2 stop`+espera+`start`+espera (~33 s), `promote-replica-1.sh` | 24187 ms (~24 s) |

**Conclusión (WSL2):** con los volúmenes de datos ya existentes (ciclos 2 y 3), el stack queda sano (primario + 2 réplicas en `streaming` + API respondiendo) en **~17-18 segundos** desde el `up`. El `down` tarda siempre **~24 segundos**. Ningún ciclo intentó descargar nada de Internet. El procedimiento completo (incluida la recuperación tras el failover del ciclo 3) está detallado también en `documento/guia-demo-stand.md`.

**Pendiente de verificar — procedimiento para la laptop Linux del grupo (y repetición del corte físico de Wi-Fi):**

Correr, en la laptop Linux, la misma secuencia (3 ciclos de `up` → esperar salud → `down`, sin `-v`, con `--pull never`), cronometrando cada etapa con `date -Iseconds` antes y después (o con un cronómetro de mano si no se quiere instrumentar). Además, en **al menos un ciclo** (de los corridos en WSL2 o en la laptop Linux), cortar la Wi-Fi físicamente antes del `up` y confirmar que el stack arranca y queda sano igual, como prueba adicional de "sin Internet" más allá de `--pull never` (que ya prueba que no hace falta pull, pero no corta la conectividad real de la máquina). Completar esta tabla:

| Ciclo | Máquina | `up` → stack sano (tiempo) | `down` (tiempo) | ¿Wi-Fi cortada? | Resultado |
|---|---|---|---|---|---|
| 1 | Laptop Linux | | | Sí / No | |
| 2 | Laptop Linux | | | Sí / No | |
| 3 | Laptop Linux | | | Sí / No | |

## Pendiente de verificar
- Que la laptop Linux del grupo se comporte igual (versión de Docker, `br_netfilter`) — ver tabla de arriba, "Verificación Fase 6 — A6.3".
