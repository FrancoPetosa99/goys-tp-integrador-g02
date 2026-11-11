# Runbook — DB Scale Lab

Guía operativa del laboratorio: puesta en marcha, los tres escenarios, los cuatro experimentos ya corridos (Fases 3 y 4), failover manual y recuperación, y los problemas conocidos. Todo lo que describe este documento está implementado y fue medido en este repositorio; los números de los experimentos son los de `documento/resultados-experimento-1.md` y `documento/resultados-experimentos-2-3-4.md`.

## 1. Puesta en marcha

Requisitos: Docker Engine + Compose, las imágenes de `.ai/conocimiento/entorno.md` ya descargadas (incluidas `dbscale/router:0.1.0` y `dbscale/api:0.1.0`, que se construyen con `docker compose build` si no existen), Ansible instalado en el host, y un archivo `.env` en la raíz del repo (copiado de `.env.example`, con contraseñas reales).

```bash
cp .env.example .env   # completar con contraseñas reales; nunca versionar .env
make preflight         # Docker/Compose, imágenes, puertos 3000/9091, RAM/CPU, ruteo
```

`make preflight` corre `ansible/playbooks/01-preflight.yml`. Funciona tanto con el stack abajo (usa temporalmente el perfil `test-red` de la Fase 1, y lo repliega al terminar) como arriba (reutiliza el flujo de negocio ya permitido por el firewall, `sc-api -> pg-primary:5432`, sin crear contenedores nuevos). Ver D32 en `decisiones-tecnicas.md`.

## 2. Los tres escenarios

| Escenario | Comando | `READ_DB_HOSTS` | Réplicas |
|---|---|---|---|
| Base única | `make up-base` | `10.20.1.10` (el propio primario) | ninguna |
| Una réplica | `make up-r1` | `10.30.1.10` | `pg-replica-1` |
| Dos réplicas | `make up-r2` | `10.30.1.10,10.31.1.10` | `pg-replica-1` y `pg-replica-2` |

Los tres comandos corren `docker compose up -d` desde `demo/` con `--env-file ../.env` y sin lista de servicios (así sube también `router`, que no tiene `profile`). En `r1`/`r2` se exporta además `READ_FALLBACK_TO_PRIMARY=false` explícito, para no depender del valor que tenga `.env` en ese momento (ver el problema conocido §5.1).

Para bajar todo: `make down` (nunca usa `-v`: los volúmenes de datos de PostgreSQL quedan intactos). Para volver al estado inicial de datos (10 categorías, 500.000 productos) en cualquier escenario: `make reset SCENARIO=base|r1|r2` (por defecto `r2`), que ejecuta `demo/scripts/reset-estado.sh`.

## 3. Pruebas de carga

`make test` sube `k6`/`sc-k6` (perfil `carga`) si no están arriba y corre, contra el escenario que esté activo en ese momento, las tres pruebas estándar de `demo/k6/` en secuencia: `carga-base.js` (20 VUs constantes, 5 min), `estres.js` (rampa escalonada 0→300 VUs, 8 min) y `pico.js` (spike 10→300→10 VUs, 3 min). Las métricas quedan en Prometheus (remote write, D14) con las etiquetas `escenario` y `prueba`, visibles en el dashboard "DB Scale Lab" de Grafana (`localhost:3000`).

Antes de cada corrida que se quiera comparar con las demás hay que dejar los datos en el mismo estado inicial: `make reset SCENARIO=<escenario>` (D12/A3.6). Los scripts de experimentos específicos (`escritura-intensiva.js`, `read-after-write.js`) no están en `make test` — se corren a mano como se describe en §4.

## 4. Experimentos 1 a 4 (Fases 3 y 4)

### Experimento 1 — Curva de escalado (0, 1 y 2 réplicas)

9 corridas: `carga-base`/`estres`/`pico` × `base`/`r1`/`r2`. Antes de cada corrida: `demo/scripts/reset-estado.sh <escenario>`. Resultados medidos (CPU en núcleos, vía cAdvisor):

| Escenario / prueba | Throughput | p95 | CPU primario | CPU réplica1 | CPU réplica2 |
|---|---|---|---|---|---|
| base / carga-base | 18.85 req/s | 429.82 ms | 0.73 | — | — |
| base / estrés | 43.02 req/s | 8.82 s | 1.60 | — | — |
| base / pico | 29.62 req/s | 14.34 s | 1.10 | — | — |
| r1 / carga-base | 19.35 req/s | 228.33 ms | 0.01 | 0.45 | — |
| r1 / estrés | 42.71 req/s | 8.88 s | 0.01 | 1.55 | — |
| r1 / pico | 26.73 req/s | 14.38 s | 0.01 | 1.07 | — |
| r2 / carga-base | 19.34 req/s | 230.55 ms | 0.01 | 0.23 | 0.22 |
| r2 / estrés | **72.81 req/s** | **5.05 s** | 0.02 | 1.20 | 0.75 |
| r2 / pico | **45.43 req/s** | **7.12 s** | 0.01 | 0.58 | 1.02 |

Con 1 réplica el cuello de botella solo se traslada (ningún cambio real bajo estrés/pico); con 2 réplicas, +~70% de throughput y p95 entre 43% y 50% más bajo. Detalle completo: `documento/resultados-experimento-1.md`.

### Experimento 2 — Caída de una réplica en plena carga

```bash
make up-r2 && make reset SCENARIO=r2
# en una terminal: demo/scripts/corte-replica.sh replica2 stop   (durante carga-base.js)
# luego: demo/scripts/corte-replica.sh replica2 start
```

`api_reads_by_node_total` a `10.31.1.10` cae a 0 req/s de inmediato; `10.30.1.10` absorbe el resto. `api_reader_host_healthy{host="10.31.1.10"}` pasa de 1 a 0 tras 3 fallos consecutivos y vuelve a 1 cada `READER_RECHECK_INTERVAL_SECONDS` (5 s). La alerta `ReplicaCaida` pasa a firing en ~32 s y vuelve a inactive en menos de 8 s tras restaurar. `http_req_failed` se mantuvo en 0,00% durante el corte (el pico de latencia observado, 3 s, coincide con `DB_GET_TIMEOUT_SECONDS=3`).

### Experimento 3 — Efecto de la red (latencia hacia `pg-replica-2`)

```bash
demo/scripts/netem.sh add 20   # o 50 / 100
demo/scripts/netem.sh show     # confirma el delay aplicado y el RTT real
demo/scripts/netem.sh del      # vuelve a latencia 0
```

- **RTT**: 0 ms → 0,164 ms de ida y vuelta; 50 ms configurados → 50,383 ms medidos (confirma que `netem` solo afecta el tráfico de salida del router hacia `net-db-remota`).
- **Lag de replicación** (medido con `pg_stat_replication_pg_wal_lsn_diff` contra el primario — D26, nunca `pg_replication_lag_seconds` — bajo `escritura-intensiva.js`, ~800 escrituras/s): a 0 ms, réplica1/réplica2 ≈ 182,7 KB/182,7 KB; a 20 ms ≈ 10,4/16,8 KB; a 50 ms ≈ 32,9/418,9 KB; a 100 ms ≈ 0,3/113,9 KB. La tendencia confirma el efecto cualitativamente, no de forma monótona (hardware compartido + ventana de scrape de Prometheus de 15 s).
- **Read-after-write** (`demo/k6/read-after-write.js`, requiere `make test` adaptado o correrlo a mano con `docker compose exec -T k6 k6 run /scripts/read-after-write.js`): con `READ_FALLBACK_TO_PRIMARY=true` las lecturas "ausentes" bajan a 0, pero las "viejas" no mejoran (el fallback de `GET /products/{id}` solo reintenta si la réplica devuelve 0 filas, no si devuelve un valor desactualizado).

### Experimento 4 — Failover manual

```bash
make up-r2 && make reset SCENARIO=r2
docker stop dbscale-pg-primary
demo/scripts/promote-replica-1.sh
# después de medir: make reset SCENARIO=r2 (ver problema conocido §5.4)
```

Tiempo de punta a punta (`docker stop` → primera escritura exitosa) medido en la corrida limpia: **2,8 s**. `pg-replica-2` nunca se reconecta al nuevo primario (D8: sin Patroni/repmgr, sin reincorporación automática).

## 5. Failover y recuperación — secuencia

1. `docker stop dbscale-pg-primary` (o corte real).
2. `demo/scripts/promote-replica-1.sh`: comprueba `pg_is_in_recovery()`, promueve `pg-replica-1` con `pg_ctl promote -D ... -u postgres` (D7/D8), espera a que salga de modo standby, y reapunta el DNAT de la VIP (`10.20.1.100:5432`) de `10.20.1.10` a `10.30.1.10` directamente con `iptables` en el router (no toca `firewall.sh`).
3. La app reconecta sola contra la VIP; no hace falta recrearla.
4. Para volver a un estado conocido después de medir: `make reset SCENARIO=r2` (recrea el primario desde cero, vuelve a levantar las réplicas y reaplica el DNAT original vía `firewall.sh`).

## 6. Problemas conocidos

1. **Recrear `api` sin pasar juntas `READ_DB_HOSTS` y `READ_FALLBACK_TO_PRIMARY` invalida la corrida.** Si se recrea el contenedor `api` pasando solo una de las dos variables, la que se omite vuelve al valor de `.env` (base única / `false`), no al del escenario activo. Por eso `make up-r1`/`up-r2` siempre exportan ambas juntas. Pasó en la Fase 4 (Experimento 3.3) e invalidó 4 corridas de `read-after-write.js`, que hubo que repetir.
2. **Reiniciar el router revierte la VIP al primario original.** `docker compose restart router` (o recrearlo) vuelve a correr `firewall.sh`, que reconstruye el DNAT con `PG_PRIMARY=10.20.1.10` fijo (D28). Después de un failover manual, reiniciar el router sin antes correr `make reset` deja la VIP apuntando otra vez al primario viejo (posiblemente caído).
3. **La interfaz de `netem` varía entre levantadas del stack.** `demo/scripts/netem.sh` nunca asume un nombre de interfaz fijo (se vio `eth2` en una corrida): la detecta en runtime buscando cuál tiene la IP `10.31.1.254` (la del router hacia `net-db-remota`) con `ip -o addr show`.
4. **Tras un failover hay que correr `reset-estado.sh` antes de seguir con otra prueba.** El estado post-failover (primario viejo caído, DNAT apuntando a la réplica promovida, `pg-replica-2` desconectada) no es válido para arrancar otro experimento; `make reset SCENARIO=r2` es la forma documentada de volver a un estado limpio y conocido.
5. **`test-red` nunca puede correr junto al stack real.** El perfil `test-red` de la Fase 1 usa exactamente las mismas IPs fijas que los nodos reales (p. ej. `t-db`=`10.20.1.10`, igual que `pg-primary`). `ansible/playbooks/01-preflight.yml` lo resuelve detectando si el stack está arriba antes de decidir cómo probar el ruteo entre segmentos (D32): si está arriba, prueba con contenedores reales (`sc-api`); si está abajo, levanta `test-red` solo por el tiempo de la prueba y lo repliega con `docker compose --profile test-red down` (nunca `-v`).
